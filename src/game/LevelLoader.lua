local Board = require("src.game.Board")
local Player = require("src.components.Player")
local json = require("vendor.json")

local LevelLoader = {}
local MAP_PATH = "maps-v2/Map.ldtk"
local BONFIRE_TILESET = {
	imagePath = "assets/animated-tiles.png",
	tilewidth = 32,
	tileheight = 32,
}

local PLAYER_CLASSES = {
	Dwarf = Player.Classes.DWARF,
	Wizard = Player.Classes.WIZARD,
	Warrior = Player.Classes.WARRIOR,
	Telekinetic = Player.Classes.TELEKINETIC,
	Sorcerer = Player.Classes.SORCERER,
	MysteriousPriest = Player.Classes.MYSTERIOUS_PRIEST,
	Farmer = Player.Classes.FARMER,
	Puppeteer = Player.Classes.PUPPETEER,
}

local function readProject(path)
	local contents, readError = love.filesystem.read(path)
	assert(contents, "failed to read LDtk project " .. path .. ": " .. tostring(readError))
	local project = json.decode(contents)
	assert(type(project.levels) == "table", "LDtk project has no levels: " .. path)
	return project
end

local function getField(instance, identifier)
	for _, field in ipairs(instance.fieldInstances or {}) do
		if field.__identifier == identifier then return field.__value end
	end
end

function LevelLoader.listLevels()
	local project = readProject(MAP_PATH)
	local orderedLevels = {}
	for index, level in ipairs(project.levels) do
		local order = getField(level, "Order")
		assert(type(order) == "number", string.format(
			"LDtk level %s must have a numeric Order field", tostring(level.identifier)))
		orderedLevels[#orderedLevels + 1] = {
			level = level,
			order = order,
			projectIndex = index,
		}
	end
	table.sort(orderedLevels, function(a, b)
		if a.order == b.order then
			return a.projectIndex < b.projectIndex
		end
		return a.order < b.order
	end)

	local levels = {}
	local previousOrder
	for index, entry in ipairs(orderedLevels) do
		local level = entry.level
		assert(entry.order ~= previousOrder, string.format(
			"LDtk levels must have unique Order values; duplicate Order %s at %s",
			tostring(entry.order), tostring(level.identifier)))
		previousOrder = entry.order
		levels[#levels + 1] = {
			number = index - 1,
			name = level.identifier,
			path = MAP_PATH,
			identifier = level.identifier,
			key = MAP_PATH .. "#" .. level.identifier,
		}
	end
	return levels
end

local function levelLayer(level, identifier)
	for _, layer in ipairs(level.layerInstances or {}) do
		if layer.__identifier == identifier then return layer end
	end
end

local function getLayerValueDefinitions(layerDefinition)
	local values, groups = {}, {}
	for _, group in ipairs(layerDefinition.intGridValuesGroups or {}) do
		groups[group.uid] = group.identifier
	end
	for _, value in ipairs(layerDefinition.intGridValues or {}) do
		values[value.value] = {
			identifier = value.identifier,
			group = groups[value.groupUid],
		}
	end
	return values
end

local function findLayerDefinition(project, layer)
	for _, definition in ipairs(project.defs.layers or {}) do
		if definition.uid == layer.layerDefUid then return definition end
	end
end

local function isWall(value, valueDefinitions)
	local definition = valueDefinitions[value]
	return definition and (definition.identifier == "Wall" or definition.group == "Collision") or false
end

local function findExterior(width, height, values, valueDefinitions)
	local outside, queue = {}, {}
	local function add(x, y)
		if x < 0 or y < 0 or x >= width or y >= height then return end
		local index = y * width + x + 1
		if not outside[index] and not isWall(values[index], valueDefinitions) then
			outside[index] = true
			queue[#queue + 1] = {x = x, y = y}
		end
	end

	for x = 0, width - 1 do
		add(x, 0)
		add(x, height - 1)
	end
	for y = 0, height - 1 do
		add(0, y)
		add(width - 1, y)
	end

	local cursor = 1
	while cursor <= #queue do
		local cell = queue[cursor]
		cursor = cursor + 1
		add(cell.x - 1, cell.y)
		add(cell.x + 1, cell.y)
		add(cell.x, cell.y - 1)
		add(cell.x, cell.y + 1)
	end
	return outside
end

local function collectGroundCells(level, gridSize, width, height)
	local layer = levelLayer(level, "Ground")
	if not layer or layer.__type ~= "Tiles" or #(layer.gridTiles or {}) == 0 then
		return nil
	end

	local cells = {}
	for _, tile in ipairs(layer.gridTiles) do
		local x = math.floor((tile.px[1] + (layer.__pxTotalOffsetX or 0)) / gridSize)
		local y = math.floor((tile.px[2] + (layer.__pxTotalOffsetY or 0)) / gridSize)
		if x >= 0 and y >= 0 and x < width and y < height then
			cells[y * width + x + 1] = true
		end
	end
	return cells
end

local function tilesetPath(projectPath, relativePath)
	local directory = projectPath:match("^(.*)/[^/]+$") or ""
	local joined = directory .. "/" .. relativePath
	local parts = {}
	for part in joined:gsub("\\", "/"):gmatch("[^/]+") do
		if part == ".." then
			if #parts > 0 then table.remove(parts) end
		elseif part ~= "." then
			parts[#parts + 1] = part
		end
	end
	return table.concat(parts, "/")
end

local function loadCollision(project, level, board, grassEntities)
	local layer = levelLayer(level, "Collision")
	assert(layer and layer.__type == "IntGrid", "LDtk level needs an IntGrid layer named Collision")
	local width, height = layer.__cWid, layer.__cHei
	local gridSize = layer.__gridSize
	assert(width and height and gridSize and gridSize > 0, "LDtk Collision layer has invalid dimensions")
	local values = layer.intGridCsv or {}
	assert(#values == width * height, "LDtk Collision layer has invalid IntGrid data")
	local layerDefinition = findLayerDefinition(project, layer)
	assert(layerDefinition, "LDtk project has no Collision layer definition")
	local valueDefinitions = getLayerValueDefinitions(layerDefinition)
	local groundCells = collectGroundCells(level, gridSize, width, height)
	local outside = not groundCells and findExterior(width, height, values, valueDefinitions) or nil

	board.width, board.height = width, height
	board.ldtkMap = true
	for y = 0, height - 1 do
		for x = 0, width - 1 do
			local index = y * width + x + 1
			local value = values[index]
			local wall = isWall(value, valueDefinitions)
			local grass = grassEntities[index] ~= nil
			local isInside
			if groundCells then
				isInside = groundCells[index] == true
			else
				isInside = not outside[index]
			end
			if isInside or wall then
				local cell = {
					walkable = isInside and not wall,
					wall = wall,
					terrainKind = wall and "solid" or (grass and "grass" or nil),
				}
				board:setCell(x, y, cell)
				if isInside and grass then
					local state = grassEntities[index] and grassEntities[index].tall and "tall_grass" or "grass"
					board:addGrass(x, y, state)
				end
			end
		end
	end
	return gridSize
end

local function findTilesetDefinition(project, uid)
	for _, definition in ipairs(project.defs.tilesets or {}) do
		if definition.uid == uid then return definition end
	end
end

local function loadRenderLayers(project, projectPath, level, gridSize, board)
	local entityLayerIndex
	for index, layer in ipairs(level.layerInstances or {}) do
		if layer.__type == "Entities" then entityLayerIndex = index end
	end

	local layers = level.layerInstances or {}
	-- LDtk exports layers top-most first, so add them back-to-front for drawing.
	for index = #layers, 1, -1 do
		local layer = layers[index]
		if layer.__type ~= "Entities" and (layer.__opacity or 1) > 0 then
			local definition = findLayerDefinition(project, layer)
			local tilesetUid = layer.__tilesetDefUid or layer.overrideTilesetUid
				or (definition and definition.tilesetDefUid)
			local tilesetDefinition = findTilesetDefinition(project, tilesetUid)
			local tiles = {}
			for _, tile in ipairs(layer.gridTiles or {}) do tiles[#tiles + 1] = tile end
			for _, tile in ipairs(layer.autoLayerTiles or {}) do tiles[#tiles + 1] = tile end
			if tilesetDefinition and #tiles > 0 then
				local relativePath = tilesetDefinition.relPath or layer.__tilesetRelPath
				if relativePath then
					local tileSize = tilesetDefinition.tileGridSize
					local tileset = {
						image = tilesetPath(projectPath, relativePath),
						tilewidth = tileSize,
						tileheight = tileSize,
						columns = math.floor(tilesetDefinition.pxWid / tileSize),
					}
					local renderLayer = board:addRenderLayer(layer.__identifier, layer.__opacity,
						entityLayerIndex and index < entityLayerIndex)
					for _, tile in ipairs(tiles) do
						board:addMapTile(
							tile.px[1] + (layer.__pxTotalOffsetX or 0),
							tile.px[2] + (layer.__pxTotalOffsetY or 0),
							tileset, tile.t, gridSize, renderLayer, tile.f, tile.a,
							tile.src[1], tile.src[2])
					end
				end
			end
		end
	end
end

local function collectGrassEntities(level, gridSize, width, height)
	local layer = levelLayer(level, "Entities")
	assert(layer and layer.__type == "Entities", "LDtk level needs an Entities layer")
	local grassEntities = {}
	for _, entity in ipairs(layer.entityInstances or {}) do
		if entity.__identifier == "Grass" then
			local x = math.floor((entity.px[1] + (layer.__pxTotalOffsetX or 0)) / gridSize)
			local y = math.floor((entity.px[2] + (layer.__pxTotalOffsetY or 0)) / gridSize)
			assert(x >= 0 and y >= 0 and x < width and y < height,
				"LDtk Grass entity is outside the Collision layer in " .. level.identifier)
			grassEntities[y * width + x + 1] = {
				tall = getField(entity, "Tall") == true,
			}
		end
	end
	return grassEntities
end

local function loadPassthroughEntities(level, gridSize, board)
	local layer = levelLayer(level, "Entities")
	for _, entity in ipairs(layer.entityInstances or {}) do
		if entity.__identifier == "Passthrough" then
			local x = math.floor((entity.px[1] + (layer.__pxTotalOffsetX or 0)) / gridSize)
			local y = math.floor((entity.px[2] + (layer.__pxTotalOffsetY or 0)) / gridSize)
			assert(x >= 0 and y >= 0 and x < board.width and y < board.height,
				"LDtk Passthrough entity is outside the Collision layer in " .. level.identifier)
			local cell = board:getCell(x, y) or {walkable = false}
			cell.walkable = false
			cell.wall = false
			cell.passthrough = true
			cell.terrainKind = "passthrough"
			board:setCell(x, y, cell)
		end
	end
end

local function loadEntities(level, gridSize, board)
	local layer = levelLayer(level, "Entities")
	for _, entity in ipairs(layer.entityInstances or {}) do
		local x = math.floor((entity.px[1] + (layer.__pxTotalOffsetX or 0)) / gridSize)
		local y = math.floor((entity.px[2] + (layer.__pxTotalOffsetY or 0)) / gridSize)
		if entity.__identifier == "Player" then
			local className = getField(entity, "Classes")
			local classId = PLAYER_CLASSES[className]
			assert(classId, "LDtk Player has an unknown Classes value: " .. tostring(className))
			assert(board:canWalk(x, y), string.format("player in %s must be on walkable ground", level.identifier))
			board:spawnPlayer(classId, x, y)
		elseif entity.__identifier == "Box" then
			assert(board:canWalk(x, y), string.format("box in %s must be on walkable ground", level.identifier))
			board:spawnBox(x, y)
		elseif entity.__identifier == "Target" then
			local cell = board:getCell(x, y)
			assert(cell and cell.walkable, string.format("target in %s must be on walkable ground", level.identifier))
			cell.target = true
			board:addTarget(x, y)
		elseif entity.__identifier == "Bonfire" then
			assert(board:canWalk(x, y), string.format("bonfire in %s must be on walkable ground", level.identifier))
			board:addBonfire(x, y, BONFIRE_TILESET)
		elseif entity.__identifier == "Trigger" then
			local triggerName = getField(entity, "TriggerName")
			assert(type(triggerName) == "string" and triggerName ~= "", string.format(
				"Trigger in %s must have a non-empty TriggerName", level.identifier))
			assert(x >= 0 and y >= 0 and x < board.width and y < board.height
				and board:canWalk(x, y), string.format(
				"Trigger %s in %s must be on walkable ground", triggerName, level.identifier))
			board:addTrigger(triggerName, x, y)
		end
	end
end

function LevelLoader.load(path, assets, events, levelIdentifier)
	local project = readProject(path)
	local level
	for _, candidate in ipairs(project.levels) do
		if candidate.identifier == levelIdentifier then
			level = candidate
			break
		end
	end
	assert(level, "LDtk level not found: " .. tostring(levelIdentifier))

	local entities = levelLayer(level, "Entities")
	assert(entities, "LDtk level needs an Entities layer")
	local board = Board(assets, entities.__cWid, entities.__cHei)
	board.events = events
	local collision = levelLayer(level, "Collision")
	assert(collision, "LDtk level needs a Collision layer")
	local gridSize = collision.__gridSize
	assert(gridSize and gridSize > 0, "LDtk Collision layer has invalid grid size")
	local grassEntities = collectGrassEntities(level, gridSize, collision.__cWid, collision.__cHei)
	loadCollision(project, level, board, grassEntities)
	local worldScale = 64 / gridSize
	board.mapWorldWidth = (level.pxWid or board.width * gridSize) * worldScale
	board.mapWorldHeight = (level.pxHei or board.height * gridSize) * worldScale
	loadRenderLayers(project, path, level, gridSize, board)
	loadPassthroughEntities(level, gridSize, board)
	loadEntities(level, gridSize, board)
	board:refreshTargetStates()
	return board
end

return LevelLoader
