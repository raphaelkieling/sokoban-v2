local CharacterClass = require("src.characters.CharacterClass")

local Puppeteer = CharacterClass:extend()
Puppeteer.id = "puppeteer"
Puppeteer.name = "Puppeteer"
Puppeteer.selectionVoiceSound = "puppeteerVoice"
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
		if movement:position(tether.child)
			and tether.child:hasComponent("Tetherable") then
			tethers[#tethers + 1] = {parent = actor, child = tether.child}
		end
	end

	local function attach(child)
		if not child or child == actor or not child:hasComponent("Tetherable")
			or not movement:position(child) then
			return false
		end
		for _, tether in ipairs(tethers) do
			if tether.child == child then return false end
		end
		tethers[#tethers + 1] = {parent = actor, child = child}
		return true
	end
	local function collectChain(x, y, except)
		local chain = {}
		local tetherable = true
		while movement:canWalk(x, y) do
			local object = movement:objectAt(x, y, except)
			if not object then break end
			if not object:hasComponent("Tetherable") then
				tetherable = false
				break
			end
			chain[#chain + 1] = object
			x, y = x + direction.x, y + direction.y
		end
		return chain, tetherable
	end

	local touched = movement:objectAt(destination.x, destination.y, actor)
	if touched and not touched:hasComponent("Tetherable") then
		movement:markBlocked(touched)
		return false
	end
	local actorCanMove
	local pushed = {}
	if touched then
		local chain, chainIsTetherable = collectChain(destination.x, destination.y, actor)
		for _, object in ipairs(chain) do attach(object) end
		if chainIsTetherable then
			actorCanMove = movement:pushChain(actor, destination, direction, 1)
			if actorCanMove then
				for _, object in ipairs(chain) do pushed[object] = true end
			end
		else
			movement:markBlocked(touched)
			actorCanMove = false
		end
	else
		actorCanMove = movement:enter(actor, destination.x, destination.y)
	end

	if actorCanMove then
		local following = {}
		for _, tether in ipairs(tethers) do
			if not pushed[tether.child] then following[#following + 1] = tether.child end
		end
		-- Let the foremost directly-tethered objects move first so a line of
		-- connected boxes can follow without one blocking the next. If a tether
		-- bumps a new tetherable object, it gets its own string to the Puppeteer.
		table.sort(following, function(first, second)
			local firstPosition = movement:position(first)
			local secondPosition = movement:position(second)
			return firstPosition.x * direction.x + firstPosition.y * direction.y
				> secondPosition.x * direction.x + secondPosition.y * direction.y
		end)
		local movedWithChain = {}
		for _, object in ipairs(following) do
			if not movedWithChain[object] then
				local position = movement:position(object)
				local nextX, nextY = position.x + direction.x, position.y + direction.y
				local chain, chainIsTetherable = collectChain(nextX, nextY, object)
				for _, child in ipairs(chain) do attach(child) end
				if chainIsTetherable then
					if movement:pushChain(object, {x = nextX, y = nextY}, direction, 1) then
						movedWithChain[object] = true
						for _, child in ipairs(chain) do movedWithChain[child] = true end
					end
				else
					movement:markBlocked(movement:objectAt(nextX, nextY, object) or object)
				end
			end
		end
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
