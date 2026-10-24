local CharacterClass = require("src.characters.CharacterClass")

local Sorcerer = CharacterClass:extend()
Sorcerer.id = "sorcerer"
Sorcerer.name = "Sorcerer"
Sorcerer.sprite = {x = 3, y = 4, scale = 2.25}

function Sorcerer:move(movement, actor, direction, destination)
    local target = movement:findInRay(destination.x, destination.y, direction, actor)
    if target then
        local position = movement:position(target)
        if position.x == destination.x and position.y == destination.y then return false end

        local recoilX = position.x - direction.x
        local recoilY = position.y - direction.y
        local destinationIsBlocked = recoilX == destination.x and recoilY == destination.y
			or not movement:canEnter(recoilX, recoilY, target)
            or movement:objectAt(recoilX, recoilY, actor)
        if destinationIsBlocked then
            movement:markBlocked(target)
            return false
        end
        movement:moveObject(target, recoilX, recoilY)
    end
    return movement:enter(actor, destination.x, destination.y)
end

return Sorcerer
