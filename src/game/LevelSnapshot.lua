local LevelSnapshot = {}
local GameConfig = require("src.settings.GameConfig")

local function sortedCells(board)
	local cells = {}
	for key, cell in pairs(board.cells) do
		local x, y = key:match("^(-?%d+):(-?%d+)$")
		cells[#cells + 1] = {
			x = tonumber(x),
			y = tonumber(y),
			walkable = cell.walkable == true,
			wall = cell.wall == true,
			passthrough = cell.passthrough == true,
			target = cell.target == true,
		}
	end
	table.sort(cells, function(a, b)
		if a.y == b.y then return a.x < b.x end
		return a.y < b.y
	end)
	return cells
end

local function captureObjects(scene, board)
	local objects, indexes = {}, {}
	local activePlayer = scene.currentPlayer and scene:currentPlayer()
	for index, object in ipairs(board.objects) do indexes[object] = index end

	for index, object in ipairs(board.objects) do
		local transform = object:getComponent("Transform")
		local characterClass = object:getComponent("CharacterClass")
		local player = object:getComponent("Player")
		local stateMachine = player and player:getStateMachine()
		local entry = {
			index = index,
			name = object.name,
			kind = player and "player" or (object:hasComponent("Box") and "box"
				or (object:hasComponent("Grass") and "grass") or "object"),
			interactive = object:hasComponent("InteractiveObject"),
			grid = {x = transform.gridX, y = transform.gridY},
			world = {x = transform.x, y = transform.y},
			moving = transform:isMoving(),
			selected = object == activePlayer,
		}
		if characterClass then
			entry.characterClass = characterClass.id
			entry.characterClassName = characterClass.name
			if characterClass.id == "puppeteer" then
				entry.tetheredObjectIndexes = {}
				for _, object in ipairs(characterClass.tetheredObjects or {}) do
					if indexes[object] then
						entry.tetheredObjectIndexes[#entry.tetheredObjectIndexes + 1] = indexes[object]
					end
				end
			end
		end
		local grass = object:getComponent("Grass")
		if grass then entry.state = grass.state end
		if stateMachine then entry.characterState = stateMachine.currentName end
		if transform.tween then
			entry.tween = {
				elapsed = transform.tween.elapsed,
				duration = transform.tween.duration,
			}
		end
		objects[#objects + 1] = entry
	end

	return objects, indexes
end

local function captureTargets(board)
	local targets = {}
	for _, target in ipairs(board.targets) do
		local item = {x = target.x, y = target.y}
		local component = target.object and target.object:getComponent("Target")
		if component then
			item.tileId = component.tileId
			item.state = component.state
		end
		targets[#targets + 1] = item
	end
	return targets
end

local function captureHistory(scene, objectIndexes)
	local actions = {}
	for _, snapshots in ipairs(scene.history and scene.history.actions or {}) do
		local action = {}
		for _, snapshot in ipairs(snapshots) do
			if snapshot.component then
				local entry = {
					object = objectIndexes[snapshot.object],
					component = snapshot.component,
					state = snapshot.state,
				}
				if snapshot.restoreTetheredObjects then
					entry.restoreTetheredObjects = {}
					for _, object in ipairs(snapshot.restoreTetheredObjects) do
						if objectIndexes[object] then
							entry.restoreTetheredObjects[#entry.restoreTetheredObjects + 1] = objectIndexes[object]
						end
					end
				end
				action[#action + 1] = entry
			else
				action[#action + 1] = {
					object = objectIndexes[snapshot.object],
					x = snapshot.gridX,
					y = snapshot.gridY,
				}
			end
		end
		actions[#actions + 1] = action
	end
	return actions
end

function LevelSnapshot.capture(scene)
	assert(scene and scene.board, "cannot capture a level without an active board")
	local board = scene.board
	local objects, objectIndexes = captureObjects(scene, board)
	local renderTiles = {}
	for _, tile in ipairs(board.renderTiles) do
		renderTiles[#renderTiles + 1] = {x = tile.x, y = tile.y, tileId = tile.tileId}
	end

	return {
		format = GameConfig.snapshotFormat,
		formatVersion = 1,
		level = {
			path = scene.levelPath,
			index = scene.levelIndex,
			sceneState = scene.states and scene.states.currentName or nil,
		},
		activePlayerIndex = scene.playerSelector.activeIndex,
		board = {
			width = board.width,
			height = board.height,
			ldtkMap = board.ldtkMap == true,
			cells = sortedCells(board),
			renderTiles = renderTiles,
			targets = captureTargets(board),
			objects = objects,
			undoHistory = captureHistory(scene, objectIndexes),
		},
	}
end

return LevelSnapshot
