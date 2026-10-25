local CharacterClass = require("src.characters.CharacterClass")

local Wizard = CharacterClass:extend()
Wizard.id = "wizard"
Wizard.name = "Wizard"
Wizard.selectionVoiceSound = "wizardVoice"
Wizard.sprite = {x = 1, y = 4, scale = 2.25}

function Wizard:canEnterBlockedTile(movement, destination, direction, actor)
	-- Let the ability inspect across blocked terrain (such as passthrough cells), but only
    -- when it can actually swap with an object beyond it.
    return movement:findInRay(destination.x, destination.y, direction, actor) ~= nil
end

function Wizard:move(movement, actor, direction, destination)
    local target = movement:findInRay(destination.x, destination.y, direction, actor)
    if not target then
        return movement:enter(actor, destination.x, destination.y)
    end

    local actorPosition = movement:position(actor)
    local targetPosition = movement:position(target)
    movement:moveObject(target, actorPosition.x, actorPosition.y)
    movement:moveObject(actor, targetPosition.x, targetPosition.y)
    return true
end

function Wizard:playMovementEffect(effects, actor, changes)
	local actorMoved, swappedWithObject = false, false
	for _, change in ipairs(changes) do
		if change.object == actor then
			actorMoved = true
		else
			swappedWithObject = true
		end
	end

	if actorMoved and swappedWithObject then
		for _, change in ipairs(changes) do
			if change.object == actor then
				effects:characterTrail(actor, change.fromX, change.fromY, change.toX, change.toY)
				return
			end
		end
	end

	CharacterClass.playMovementEffect(self, effects, actor, changes)
end

return Wizard
