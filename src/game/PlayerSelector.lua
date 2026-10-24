local Class = require("src.core.Class")

local PlayerSelector = Class:extend()

local function isSelectable(player)
	return player ~= nil and player.active ~= false
end

local function nextSelectableIndex(players, startIndex)
	for offset = 1, #players do
		local index = (startIndex - 1 + offset) % #players + 1
		if isSelectable(players[index]) then return index end
	end
end

function PlayerSelector:init()
	self.activeIndex = 1
	self.held = false
	self.usedDirection = false
end

function PlayerSelector:reset()
	self.activeIndex = 1
	self:cancel()
end

function PlayerSelector:cancel()
	self.held = false
	self.usedDirection = false
end

function PlayerSelector:isHeld()
	return self.held
end

function PlayerSelector:begin()
	if self.held then return false end
	self.held = true
	self.usedDirection = false
	return true
end

function PlayerSelector:selectNext(players)
	if #players == 0 then return nil end
	local previousIndex = self.activeIndex
	local nextIndex = nextSelectableIndex(players, previousIndex)
	if not nextIndex or nextIndex == previousIndex then return nil end
	self.activeIndex = nextIndex
	return {from = previousIndex, to = self.activeIndex}
end

function PlayerSelector:ensureLivingPlayer(players)
	if #players == 0 then return nil end
	local current = players[self.activeIndex]
	if isSelectable(current) then return nil end
	local sinkable = current and current:getComponent("Sinkable")
	if sinkable and sinkable.state ~= "lost" then return nil end
	return self:selectNext(players)
end

function PlayerSelector:selectInDirection(players, direction)
	if not self.held then return nil end
	self.usedDirection = true
	local current = players[self.activeIndex]
	if not current then return nil end
	local currentTransform = current:getComponent("Transform")
	local bestIndex, bestForward, bestSide

	for index, player in ipairs(players) do
		if index ~= self.activeIndex and isSelectable(player) then
			local transform = player:getComponent("Transform")
			local dx = transform.gridX - currentTransform.gridX
			local dy = transform.gridY - currentTransform.gridY
			local forward = dx * direction.x + dy * direction.y
			if forward > 0 then
				local side = math.abs(dx * direction.y - dy * direction.x)
				if not bestForward or side < bestSide or (side == bestSide and forward < bestForward) then
					bestIndex, bestForward, bestSide = index, forward, side
				end
			end
		end
	end

	local previousIndex = self.activeIndex
	if not bestIndex then
		if not isSelectable(current) then
			bestIndex = nextSelectableIndex(players, previousIndex)
		end
		if not bestIndex or bestIndex == previousIndex then return nil end
	end
	self.activeIndex = bestIndex
	return {from = previousIndex, to = self.activeIndex}
end

function PlayerSelector:finish(players)
	if not self.held then return nil end
	local shouldSelectNext = not self.usedDirection
	self:cancel()
	if shouldSelectNext then return self:selectNext(players) end
	return nil
end

return PlayerSelector
