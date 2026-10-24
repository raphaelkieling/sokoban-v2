local CharacterClass = require("src.characters.CharacterClass")

local Puppeteer = CharacterClass:extend()
Puppeteer.id = "puppeteer"
Puppeteer.name = "Puppeteer"
Puppeteer.sprite = {x = 0, y = 6, scale = 2.25}

local function copyTethers(tethers)
	local copy = {}
	for _, tether in ipairs(tethers or {}) do
		copy[#copy + 1] = {parent = tether.parent, child = tether.child}
	end
	return copy
end

local function sameTethers(first, second)
	if #first ~= #second then return false end
	for index, tether in ipairs(first) do
		local other = second[index]
		if not other or other.parent ~= tether.parent or other.child ~= tether.child then
			return false
		end
	end
	return true
end

local function tetherIndex(tethers, child)
	for index, tether in ipairs(tethers) do
		if tether.child == child then return index end
	end
end

function Puppeteer:init()
	CharacterClass.init(self)
	self.tethers = {}
	self.state = 0
end

function Puppeteer:setState(state, metadata)
	self.state = state
	if metadata and metadata.restoreTethers then
		self.tethers = copyTethers(metadata.restoreTethers)
	end
end

function Puppeteer:move(movement, actor, direction, destination)
	local originalTethers = copyTethers(self.tethers)
	local tethers = {}
	for _, tether in ipairs(originalTethers) do
		local parentIsAlive = tether.parent == actor or movement:position(tether.parent) ~= nil
		if parentIsAlive and movement:position(tether.child)
			and tether.child:hasComponent("Tetherable") then
			tethers[#tethers + 1] = tether
		end
	end

	local function attach(parent, child)
		if not child or child == actor or not child:hasComponent("Tetherable")
			or not movement:position(child) then
			return false
		end

		-- Refuse a link that would make a cycle in the string tree.
		local ancestor = parent
		while ancestor and ancestor ~= actor do
			if ancestor == child then return false end
			local index = tetherIndex(tethers, ancestor)
			ancestor = index and tethers[index].parent or nil
		end

		local index = tetherIndex(tethers, child)
		if index then
			if tethers[index].parent == parent then return false end
			tethers[index] = {parent = parent, child = child}
		else
			tethers[#tethers + 1] = {parent = parent, child = child}
		end
		return true
	end

	local function childrenOf(parent)
		local children = {}
		for _, tether in ipairs(tethers) do
			if tether.parent == parent then children[#children + 1] = tether.child end
		end
		return children
	end

	local function propagateFrom(parent, tryMove)
		for _, child in ipairs(childrenOf(parent)) do tryMove(child) end
	end

	local moving, results = {}, {}
	local tryMove
	tryMove = function(object)
		if results[object] ~= nil then return results[object] end
		if moving[object] then return false end
		moving[object] = true

		local position = movement:position(object)
		if not position then
			moving[object] = nil
			results[object] = false
			return false
		end

		local nextX, nextY = position.x + direction.x, position.y + direction.y
		local blocker = movement:objectAt(nextX, nextY, object)
		if blocker and blocker ~= actor and blocker:hasComponent("Tetherable") then
			attach(object, blocker)
			tryMove(blocker)
		end

		local moved = movement:canEnter(nextX, nextY, object)
			and movement:objectAt(nextX, nextY, object) == nil
		if moved then
			movement:moveObject(object, nextX, nextY)
		else
			movement:markBlocked(movement:objectAt(nextX, nextY, object) or object)
		end
		moving[object] = nil
		results[object] = moved

		-- A child follows only after its parent has actually moved.
		if moved then propagateFrom(object, tryMove) end
		return moved
	end

	local touched = movement:objectAt(destination.x, destination.y, actor)
	if touched and not touched:hasComponent("Tetherable") then
		movement:markBlocked(touched)
		return false
	end
	if touched then attach(actor, touched) end

	local actorCanMove = true
	if touched then
		actorCanMove = tryMove(touched)
		if actorCanMove then
			actorCanMove = movement:enter(actor, destination.x, destination.y)
		end
	else
		actorCanMove = movement:enter(actor, destination.x, destination.y)
	end

	if actorCanMove then
		propagateFrom(actor, tryMove)
	end

	if not sameTethers(originalTethers, tethers) then
		movement:setComponentState(self, (self.state or 0) + 1, {
			restoreTethers = originalTethers,
		})
		self.tethers = tethers
	end
	return actorCanMove or not sameTethers(originalTethers, tethers)
end

function Puppeteer:draw()
	if not love or not love.graphics or #self.tethers == 0 then return end
	love.graphics.push("all")
	for _, tether in ipairs(self.tethers) do
		if tether.parent.active ~= false and tether.child.active ~= false then
			local parentTransform = tether.parent:getComponent("Transform")
			local childTransform = tether.child:getComponent("Transform")
			local dx = childTransform.x - parentTransform.x
			local dy = childTransform.y - parentTransform.y
			local length = math.sqrt(dx * dx + dy * dy)
			if length > 0 then
				local nx, ny = -dy / length, dx / length
				-- A soft gray edge gives the white cord enough contrast on bright tiles.
				love.graphics.setColor(0.30, 0.31, 0.34, 0.92)
				love.graphics.setLineWidth(4)
				love.graphics.line(parentTransform.x, parentTransform.y,
					childTransform.x, childTransform.y)

				love.graphics.setColor(0.96, 0.95, 0.88, 1)
				love.graphics.setLineWidth(2)
				love.graphics.line(parentTransform.x, parentTransform.y,
					childTransform.x, childTransform.y)

				-- Short alternating gray twists make the tether read like braided rope.
				love.graphics.setColor(0.52, 0.54, 0.58, 0.95)
				love.graphics.setLineWidth(1.4)
				local spacing = 9
				for distance = spacing / 2, length - spacing / 2, spacing do
					local progress = distance / length
					local centerX = parentTransform.x + dx * progress
					local centerY = parentTransform.y + dy * progress
					local twist = (math.floor(distance / spacing) % 2 == 0) and 2.4 or -2.4
					local along = spacing * 0.30
					love.graphics.line(
						centerX - dx / length * along + nx * twist,
						centerY - dy / length * along + ny * twist,
						centerX + dx / length * along - nx * twist,
						centerY + dy / length * along - ny * twist)
				end
			end
		end
	end
	love.graphics.pop()
end

return Puppeteer
