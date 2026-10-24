local Node = require("src.core.Node")
local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local Animation = require("src.components.Animation")
local InteractiveObject = require("src.components.InteractiveObject")
local Player = require("src.components.Player")
local Box = require("src.components.Box")
local Target = require("src.components.Target")
local Bonfire = require("src.components.Bonfire")
local Grass = require("src.components.Grass")
local Flameable = require("src.components.Flameable")
local FlameSource = require("src.components.FlameSource")
local Shake = require("src.components.Shake")
local Sinkable = require("src.components.Sinkable")
local CharacterFactory = require("src.characters.CharacterFactory")

local Board = Node:extend()

function Board:init(assets, width, height)
    Node.init(self, "Board")
    self.assets = assets
    self.width = width
    self.height = height
    self.cells = {}
    self.objects = {}
    self.players = {}
    self.boxes = {}
    self.triggers = {}
    self.targets = {}
    self.targetObjects = {}
    self.renderTiles = {}
    self.backgroundRenderLayers = {}
    self.foregroundRenderLayers = {}
    self.debugShowSolid = false
    self.debugShowUndoHistory = false
end

function Board:cellKey(x, y)
    return x .. ":" .. y
end

function Board:setCell(x, y, cell)
    self.cells[self:cellKey(x, y)] = cell
end


function Board:addRenderLayer(name, opacity, foreground)
	local layer = {name = name, opacity = opacity == nil and 1 or opacity, tiles = {}}
	local layers = foreground and self.foregroundRenderLayers or self.backgroundRenderLayers
	layers[#layers + 1] = layer
	return layer
end

function Board:addMapTile(x, y, tileset, tileId, gridSize, renderLayer, flipFlags, alpha,
		sourceX, sourceY)
	local image, quad, tileWidth, tileHeight
	if sourceX ~= nil and sourceY ~= nil then
		image, quad, tileWidth, tileHeight = self.assets:mapTileAt(tileset, sourceX, sourceY)
	else
		image, quad, tileWidth, tileHeight = self.assets:mapTile(tileset, tileId)
	end
	gridSize = gridSize or 32
	flipFlags = flipFlags or 0
	local tile = {
		x = x / gridSize + tileWidth / (2 * gridSize) - 0.5,
		y = y / gridSize + tileHeight / (2 * gridSize) - 0.5,
		tileId = tileId,
		image = image,
		quad = quad,
		scaleX = 64 / gridSize,
		scaleY = 64 / gridSize,
		tileWidth = tileWidth,
		tileHeight = tileHeight,
		flipX = flipFlags % 2 == 1,
		flipY = math.floor(flipFlags / 2) % 2 == 1,
		alpha = alpha == nil and 1 or alpha,
	}
	self.renderTiles[#self.renderTiles + 1] = tile
	if renderLayer then renderLayer.tiles[#renderLayer.tiles + 1] = tile end
	return tile
end

local function drawRenderLayers(layers)
	if #layers == 0 then return end
	love.graphics.push("all")
	for _, layer in ipairs(layers) do
		for _, tile in ipairs(layer.tiles) do
			love.graphics.setColor(1, 1, 1, layer.opacity * tile.alpha)
			love.graphics.draw(tile.image, tile.quad,
				(tile.x + 0.5) * 64, (tile.y + 0.5) * 64, 0,
				tile.flipX and -tile.scaleX or tile.scaleX,
				tile.flipY and -tile.scaleY or tile.scaleY,
				tile.tileWidth / 2, tile.tileHeight / 2)
		end
	end
	love.graphics.pop()
end

function Board:addTarget(x, y, tileId)
    local object = GameObject("Target")
    object:addComponent(Transform(x, y, 64, 1))
    object:addComponent(Target(self, self.assets, tileId))
    object:addComponent(self.assets:tileRenderer(2, 1))
    self.targets[#self.targets + 1] = {x = x, y = y, object = object}
    self.targetObjects[#self.targetObjects + 1] = object
    self:addChild(object)
    return object
end

function Board:addTrigger(name, x, y)
	local trigger = {name = name, x = x, y = y}
	self.triggers[#self.triggers + 1] = trigger
	return trigger
end

function Board:getTriggersAt(x, y)
	local matches = {}
	for _, trigger in ipairs(self.triggers) do
		if trigger.x == x and trigger.y == y then
			matches[#matches + 1] = trigger
		end
	end
	return matches
end

function Board:addBonfire(x, y, tileset, state)
    local object = GameObject("Bonfire")
    object:addComponent(Transform(x, y, 64, 1))
    object:addComponent(InteractiveObject())
    object:addComponent(Bonfire(self.assets, tileset, state))
    object:addComponent(FlameSource("Bonfire", "lit", 1))
    object:addComponent(Sinkable())
    object:addComponent(self.assets:tilesetRenderer(tileset, 2, 1))
    return self:addObject(object)
end

function Board:addGrass(x, y, state)
    local object = GameObject("Grass")
    object:addComponent(Transform(x, y, 64, 1))
    object:addComponent(Grass(self.assets, self, x, y,
        state == "tall_grass" and "tall" or "grass"))
    object:addComponent(Flameable("Grass", "grass"))
    object:addComponent(self.assets:tileRenderer(2, 1))
    return self:addObject(object)
end

function Board:refreshTargetStates()
    for _, object in ipairs(self.targetObjects) do
        object:getComponent("Target"):refreshState()
    end
end

function Board:getCell(x, y)
    return self.cells[self:cellKey(x, y)]
end

function Board:getFilledBounds()
    local minX, minY, maxX, maxY
    for key in pairs(self.cells) do
        local x, y = key:match("^(-?%d+):(-?%d+)$")
        x, y = tonumber(x), tonumber(y)
        minX = minX and math.min(minX, x) or x
        minY = minY and math.min(minY, y) or y
        maxX = maxX and math.max(maxX, x) or x
        maxY = maxY and math.max(maxY, y) or y
    end
    if not minX then return nil end
    return minX, minY, maxX, maxY
end

function Board:canWalk(x, y)
    local cell = self:getCell(x, y)
    return cell ~= nil and cell.walkable == true and not cell.wall
end

function Board:addObject(object)
    if object:hasComponent("InteractiveObject")
        and object:hasComponent("SpriteRenderer")
        and not object:hasComponent("Shake") then
        object:addComponent(Shake())
    end
    self.objects[#self.objects + 1] = object
    self:addChild(object)
    if object:hasComponent("Player") then
        self.players[#self.players + 1] = object
    elseif object:hasComponent("Box") then
        self.boxes[#self.boxes + 1] = object
    end
    return object
end

function Board:spawnPlayer(classId, x, y)
    return self:addObject(CharacterFactory.create(classId, x, y, self.assets))
end

function Board:spawnBox(x, y, tileId)
    tileId = tileId or (6 + 17 * 17)
    local tileX = tileId % 17
    local tileY = math.floor(tileId / 17)
    local object = GameObject("Box")
    object:addComponent(Transform(x, y, 64, 2))
    object:addComponent(InteractiveObject())
    object:addComponent(Box())
    object:addComponent(Sinkable())
    object:addComponent(Animation(self.assets:tileAnimation(tileX, tileY)))
    object:addComponent(self.assets:tileRenderer(2, 2))
    return self:addObject(object)
end

function Board:getInteractiveAt(x, y, positions, except)
    for _, object in ipairs(self.objects) do
        if object.active ~= false and object ~= except and object:hasComponent("InteractiveObject") then
            local position = positions and positions[object]
            if not position then
                local transform = object:getComponent("Transform")
                position = {x = transform.gridX, y = transform.gridY}
            end
            if position.x == x and position.y == y then
                return object
            end
        end
    end
    return nil
end

function Board:isMoving()
    for _, object in ipairs(self.objects) do
		if (object.active ~= false or object.visualOnly)
			and (object:getComponent("Transform"):isMoving()
				or (object.visualOnly and object:getComponent("Sinkable"))) then
            return true
        end
    end
    return false
end

function Board:isBoxAt(x, y)
    for _, box in ipairs(self.boxes) do
        local transform = box:getComponent("Transform")
        if box.active ~= false and transform.gridX == x and transform.gridY == y then
            return true
        end
    end
    return false
end

function Board:update(dt)
    self:updateChildren(dt)
end

function Board:draw(activePlayer)
    if activePlayer and type(activePlayer.currentPlayer) == "function" then
        activePlayer = activePlayer:currentPlayer()
    end
    if self.ldtkMap then
        drawRenderLayers(self.backgroundRenderLayers)
    else
        local floorQuad = self.assets.tileGrid(1, 1)[1]
        local wallQuad = self.assets.tileGrid(2, 1)[1]
        for y = 0, self.height - 1 do
            for x = 0, self.width - 1 do
                local cell = self:getCell(x, y)
                if cell then
                    local screenX, screenY = (x + 0.5) * 64, (y + 0.5) * 64
                    if cell.walkable then
                        love.graphics.draw(self.assets.tiles, floorQuad, screenX, screenY, 0, 2, 2, 16, 16)
                    elseif cell.wall then
                        love.graphics.draw(self.assets.tiles, wallQuad, screenX, screenY, 0, 2, 2, 16, 16)
                    end
                end
            end
        end
    end

    if activePlayer then
        local characterClass = activePlayer:getComponent("CharacterClass")
        if characterClass and characterClass.id == Player.Classes.MYSTERIOUS_PRIEST then
            local transform = activePlayer:getComponent("Transform")
            local pulse = (math.sin(love.timer.getTime() * 3.2) + 1) / 2
            local auraSize = transform.cellSize * 3 * (0.96 + pulse * 0.04)
            local cornerRadius = transform.cellSize * (0.12 + pulse * 0.02)
            love.graphics.push("all")
            love.graphics.setColor(0.35, 0.9, 1, 0.5 + pulse * 0.28)
            love.graphics.setLineWidth(1.5 + pulse * 1.1)
            love.graphics.rectangle("line",
                transform.x - auraSize / 2,
                transform.y - auraSize / 2,
                auraSize,
                auraSize,
                cornerRadius,
                cornerRadius,
                8)
            love.graphics.pop()
        end
    end

    local drawOrder = {}
	for _, object in ipairs(self.objects) do
		if object.active ~= false or object.visualOnly then drawOrder[#drawOrder + 1] = object end
    end
    for _, object in ipairs(self.targetObjects) do
        drawOrder[#drawOrder + 1] = object
    end
    table.sort(drawOrder, function(a, b)
        return a:getComponent("SpriteRenderer").renderLayer < b:getComponent("SpriteRenderer").renderLayer
    end)

    self.activePlayer = activePlayer or self.activePlayer
    for _, object in ipairs(drawOrder) do
        object:draw({selected = object == activePlayer})
    end

	if self.ldtkMap then drawRenderLayers(self.foregroundRenderLayers) end

    if self.debugShowSolid then
        love.graphics.push("all")
        love.graphics.setColor(1, 0.24, 0.18, 0.9)
        love.graphics.setLineWidth(2)
        for key, cell in pairs(self.cells) do
            if cell.wall then
                local x, y = key:match("^(-?%d+):(-?%d+)$")
                love.graphics.rectangle("line", tonumber(x) * 64 + 2, tonumber(y) * 64 + 2, 60, 60)
            end
        end
        for _, object in ipairs(self.objects) do
            if object:hasComponent("InteractiveObject") then
                local transform = object:getComponent("Transform")
                local size = transform.cellSize - 4
                love.graphics.rectangle("line", transform.x - size / 2, transform.y - size / 2, size, size)
            end
        end
        love.graphics.pop()
    end

end

function Board:allTargetsCovered()
    if #self.targets == 0 then return false end

    local occupiedPositions = {}
    for _, box in ipairs(self.boxes) do
        if box.active ~= false then
			local transform = box:getComponent("Transform")
			occupiedPositions[self:cellKey(transform.gridX, transform.gridY)] = true
		end
    end

    for _, target in ipairs(self.targets) do
        if not occupiedPositions[self:cellKey(target.x, target.y)] then
            return false
        end
    end
    return true
end

function Board:hasMovingObjects()
    return self:isMoving()
end

return Board
