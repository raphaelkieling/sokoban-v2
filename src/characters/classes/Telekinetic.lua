local CharacterClass = require("src.characters.CharacterClass")

local Telekinetic = CharacterClass:extend()
Telekinetic.id = "telekinetic"
Telekinetic.name = "Telekinetic"
Telekinetic.sprite = {x = 2, y = 0, scale = 2.25}

function Telekinetic:move(movement, actor, direction, destination)
    local target = movement:findInRay(destination.x, destination.y, direction, actor)
    if target then
        local position = movement:position(target)
        local beyondX, beyondY = position.x + direction.x, position.y + direction.y
		if not movement:canEnter(beyondX, beyondY, target) then
            movement:markBlocked(target)
            return movement:enter(actor, destination.x, destination.y)
        end

        local blocker = movement:objectAt(beyondX, beyondY, actor)
        if blocker then
            movement:markBlocked(blocker)
            movement:markBlocked(target)
            return movement:enter(actor, destination.x, destination.y)
        end
        movement:moveObject(target, beyondX, beyondY)
    end
    return movement:enter(actor, destination.x, destination.y)
end

return Telekinetic
