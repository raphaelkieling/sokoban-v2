local CharacterClass = require("src.characters.CharacterClass")

local MysteriousPriest = CharacterClass:extend()
MysteriousPriest.id = "mysterious_priest"
MysteriousPriest.name = "Mysterious Priest"
MysteriousPriest.selectionVoiceSound = "mysteriousPriestVoice"
MysteriousPriest.sprite = {x = 6, y = 2, scale = 2.25}

function MysteriousPriest:move(movement, actor, direction, destination)
    local center = movement:position(actor)
    local auraRadius = 1
    local affected = {}

    for _, object in ipairs(movement.board.objects) do
        if object ~= actor and object:hasComponent("InteractiveObject") then
            local position = movement:position(object)
            if position and math.abs(position.x - center.x) <= auraRadius
                and math.abs(position.y - center.y) <= auraRadius then
                affected[#affected + 1] = object
            end
        end
    end

    table.sort(affected, function(a, b)
        local aPosition, bPosition = movement:position(a), movement:position(b)
        local aProjection = aPosition.x * direction.x + aPosition.y * direction.y
        local bProjection = bPosition.x * direction.x + bPosition.y * direction.y
        return aProjection > bProjection
    end)

    local trailingObjects = {}
    for _, object in ipairs(affected) do
        local position = movement:position(object)
        local nextX, nextY = position.x + direction.x, position.y + direction.y
        if nextX == center.x and nextY == center.y then
            trailingObjects[#trailingObjects + 1] = object
        else
            local blocker = movement:objectAt(nextX, nextY, object)
			if movement:canEnter(nextX, nextY, object) and not blocker then
                movement:moveObject(object, nextX, nextY)
            else
                movement:markBlocked(blocker or object)
            end
        end
    end

    local actorMoved = movement:enter(actor, destination.x, destination.y)
    for _, object in ipairs(trailingObjects) do
        local centerIsFree = movement:canWalk(center.x, center.y)
            and not movement:objectAt(center.x, center.y, actor)
        if actorMoved and centerIsFree then
            movement:moveObject(object, center.x, center.y)
        else
            movement:markBlocked(object)
        end
    end
    return actorMoved
end

return MysteriousPriest
