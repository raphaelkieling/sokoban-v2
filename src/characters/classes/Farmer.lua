local CharacterClass = require("src.characters.CharacterClass")

local Farmer = CharacterClass:extend()
Farmer.id = "farmer"
Farmer.name = "Farmer"
Farmer.selectionVoiceSound = "farmerVoice"
Farmer.sprite = {x = 2, y = 4, scale = 2.25}

function Farmer:move(movement, actor, _direction, destination)
	local grass = movement:componentAt(destination.x, destination.y, "Grass")
	if grass then
		local blocker = movement:objectAt(destination.x, destination.y, actor)
		if blocker then
			movement:markBlocked(blocker)
			return false
		end
		movement:setComponentState(grass, grass.state == "tall" and "grass" or "tall")
		return false
	end
	return movement:enter(actor, destination.x, destination.y)
end

function Farmer:canEnterBlockedTile(movement, destination)
	local grass = movement:componentAt(destination.x, destination.y, "Grass")
	return grass ~= nil and grass.state == "tall" and grass.walkableWhenShort
end

return Farmer
