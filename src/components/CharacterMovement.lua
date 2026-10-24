local Component = require("src.core.Component")
local MovementSession = require("src.game.MovementSession")

local CharacterMovement = Component:extend()
CharacterMovement.componentName = "CharacterMovement"

local function isCardinalDirection(direction)
	return direction and ((math.abs(direction.x) == 1 and direction.y == 0)
		or (math.abs(direction.y) == 1 and direction.x == 0))
end

local function startPlayerStates(changes, actor)
	local anotherObjectMoved = false
	for _, change in ipairs(changes) do
		if change.object ~= actor then
			anotherObjectMoved = true
			break
		end
	end

	for _, change in ipairs(changes) do
		local stateMachine = change.object:getComponent("StateMachine")
		if stateMachine then
			local stateName = change.object == actor and not anotherObjectMoved
				and "walking" or "pushing"
			stateMachine:change(stateName)
		end
	end
end

local function shakeBlockedObjects(session, direction)
	for _, object in ipairs(session.blockedObjects) do
		local shake = object:getComponent("Shake")
		if shake then shake:trigger(direction.x, direction.y) end
	end
end

function CharacterMovement:move(board, direction, history, effectSink)
	local actor = self.owner
	if not board or not actor:hasComponent("Player")
		or not actor:hasComponent("CharacterClass") or not isCardinalDirection(direction) then
		return false
	end

	local movement = MovementSession.new(board)
	local actorPosition = movement:position(actor)
	if not actorPosition then return false end

	local destination = {
		x = actorPosition.x + direction.x,
		y = actorPosition.y + direction.y,
	}
	local characterClass = actor:getComponent("CharacterClass")
	if not movement:canWalk(destination.x, destination.y)
		and not characterClass:canEnterBlockedTile(movement, destination, direction, actor) then
		return false
	end
	characterClass:move(movement, actor, direction, destination)
	local changes = movement:changedPositions()
	local componentChanges = movement:changedComponents()
	if #changes == 0 and #componentChanges == 0 then
		shakeBlockedObjects(movement, direction)
		return false
	end

	local snapshots = {}
	for _, change in ipairs(changes) do
		change.object:getComponent("Transform"):moveTo(change.toX, change.toY,
			change.object ~= actor)
		snapshots[#snapshots + 1] = {
			object = change.object,
			gridX = change.fromX,
			gridY = change.fromY,
			x = change.x,
			y = change.y,
		}
	end
	for _, change in ipairs(componentChanges) do
		local snapshot = {}
		for key, value in pairs(change) do snapshot[key] = value end
		snapshots[#snapshots + 1] = snapshot
	end
	if history then history:record(snapshots) end
	if #changes > 0 then
		startPlayerStates(changes, actor)
		local stateMachine = actor:getComponent("StateMachine")
		if stateMachine then
			stateMachine:dispatch("onMovement", {
				effects = effectSink or actor:getComponent("MovementEffects"),
				changes = changes,
				direction = direction,
			})
		end
	end
	return true, changes
end

return CharacterMovement
