local CharacterClass = require("src.characters.CharacterClass")

local Puppeteer = CharacterClass:extend()
Puppeteer.id = "puppeteer"
Puppeteer.name = "Puppeteer"
Puppeteer.sprite = {x = 0, y = 6, scale = 2.25}

local function copyObjects(objects)
	local copy = {}
	for _, object in ipairs(objects or {}) do copy[#copy + 1] = object end
	return copy
end

local function sameObjects(first, second)
	if #first ~= #second then return false end
	for index, object in ipairs(first) do
		if second[index] ~= object then return false end
	end
	return true
end

local function occupantAt(movement, positions, x, y, except)
	for _, object in ipairs(movement.board.objects) do
		if object ~= except and object.active ~= false and object:hasComponent("InteractiveObject") then
			local position = positions[object] or movement:position(object)
			if position and position.x == x and position.y == y then return object end
		end
	end
end

function Puppeteer:init()
	CharacterClass.init(self)
	self.tetheredObjects = {}
	self.state = 0
end

function Puppeteer:setState(state, metadata)
	self.state = state
	if metadata and metadata.restoreTetheredObjects then
		self.tetheredObjects = copyObjects(metadata.restoreTetheredObjects)
	end
end

function Puppeteer:move(movement, actor, direction, destination)
	local originalLinks = copyObjects(self.tetheredObjects)
	local linkedObjects, linkedSet = {}, {}
	local function addTetherable(object)
		if not object or not object:hasComponent("Tetherable")
			or not movement:position(object) or linkedSet[object] then
			return false
		end
		linkedSet[object] = true
		linkedObjects[#linkedObjects + 1] = object
		return true
	end

	-- Sunk boxes no longer have a position in the movement session and are
	-- therefore automatically removed from the living thread group.
	for _, object in ipairs(originalLinks) do addTetherable(object) end

	local touched = movement:objectAt(destination.x, destination.y, actor)
	if touched and not touched:hasComponent("Tetherable") then
		movement:markBlocked(touched)
		return false
	end
	if touched then addTetherable(touched) end

	-- Any tetherable object a moving thread would bump joins the group. Resolve
	-- the full set before moving so adjacent objects can vacate each other's cells.
	local index = 1
	while index <= #linkedObjects do
		local object = linkedObjects[index]
		local position = movement:position(object)
		local blocker = movement:objectAt(position.x + direction.x,
			position.y + direction.y, object)
		if blocker and blocker ~= actor and blocker:hasComponent("Tetherable") then
			addTetherable(blocker)
		end
		index = index + 1
	end

	-- Plan the tethered objects independently, front to back. A blocked thread stays put;
	-- it must not prevent the puppeteer or other unblocked threads from moving.
	table.sort(linkedObjects, function(a, b)
		local aPosition, bPosition = movement:position(a), movement:position(b)
		local aProjection = aPosition.x * direction.x + aPosition.y * direction.y
		local bProjection = bPosition.x * direction.x + bPosition.y * direction.y
		return aProjection > bProjection
	end)

	local plannedPositions = {}
	for _, object in ipairs(linkedObjects) do
		local position = movement:position(object)
		local nextX, nextY = position.x + direction.x, position.y + direction.y
		local blocker = occupantAt(movement, plannedPositions, nextX, nextY, object)
		local canMove = movement:canEnter(nextX, nextY, object)
			and (not blocker or blocker == actor)
		if canMove then
			plannedPositions[object] = {x = nextX, y = nextY}
		else
			plannedPositions[object] = position
			movement:markBlocked(blocker or object)
		end
	end

	-- The object in the player's destination must vacate that cell; other linked
	-- objects may stay behind without stopping the Puppeteer.
	if touched then
		local planned = plannedPositions[touched]
		local original = movement:position(touched)
		if not planned or (planned.x == original.x and planned.y == original.y) then
			return false
		end
	end

	for _, object in ipairs(linkedObjects) do
		local planned = plannedPositions[object]
		local original = movement:position(object)
		if planned.x ~= original.x or planned.y ~= original.y then
			movement:moveObject(object, planned.x, planned.y)
		end
	end
	if not movement:enter(actor, destination.x, destination.y) then return false end

	if not sameObjects(originalLinks, linkedObjects) then
		movement:setComponentState(self, (self.state or 0) + 1, {
			restoreTetheredObjects = originalLinks,
		})
		self.tetheredObjects = linkedObjects
	end
	return true
end

function Puppeteer:draw()
	if not love or not love.graphics or #self.tetheredObjects == 0 then return end
	local transform = self.owner:getComponent("Transform")
	love.graphics.push("all")
	love.graphics.setColor(0.91, 0.76, 1, 0.86)
	love.graphics.setLineWidth(1.5)
	for _, object in ipairs(self.tetheredObjects) do
		if object.active ~= false then
			local objectTransform = object:getComponent("Transform")
			love.graphics.line(transform.x, transform.y, objectTransform.x, objectTransform.y)
		end
	end
	love.graphics.pop()
end

return Puppeteer
