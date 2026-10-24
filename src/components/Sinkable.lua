local Component = require("src.core.Component")

-- Marks an interactive object that disappears when pushed into a passthrough cell.
local Sinkable = Component:extend()
Sinkable.componentName = "Sinkable"

function Sinkable:init()
	Component.init(self)
	self.state = "active"
	self.sinkDuration = 0.38
	self.sinkTime = 0
	self.sinkFromX, self.sinkFromY = nil, nil
	self.sinkToX, self.sinkToY = nil, nil
end

function Sinkable:setState(state, metadata)
	assert(state == "active" or state == "sinking" or state == "lost",
		"Sinkable state must be active, sinking, or lost")
	if self.state == state then return false end
	self.state = state
	if state == "sinking" then
		metadata = metadata or {}
		self.sinkFromX, self.sinkFromY = metadata.originX, metadata.originY
		self.sinkToX, self.sinkToY = metadata.sinkX, metadata.sinkY
		self.sinkTime = 0
	elseif state == "active" then
		self.sinkFromX, self.sinkFromY, self.sinkToX, self.sinkToY = nil, nil, nil, nil
		self.sinkTime = 0
	end
	if self.owner then
		self.owner.active = state == "active"
		self.owner.visualOnly = state == "sinking"
	end
	return true
end

function Sinkable:onAttach(owner)
	owner.active = self.state == "active"
	owner.visualOnly = self.state == "sinking"
end

function Sinkable:update(dt)
	if self.state ~= "sinking" then return end
	self.sinkTime = self.sinkTime + dt
	if self.sinkTime >= self.sinkDuration then
		self:setState("lost")
	end
end

function Sinkable:visualTransform()
	if self.state ~= "sinking" then return nil end
	local transform = self.owner:getComponent("Transform")
	local progress = math.min(self.sinkTime / self.sinkDuration, 1)
	local eased = progress * progress
	local fromX = ((self.sinkFromX or transform.gridX) + 0.5) * transform.cellSize
	local fromY = ((self.sinkFromY or transform.gridY) + 0.5) * transform.cellSize
	local toX = ((self.sinkToX or transform.gridX) + 0.5) * transform.cellSize
	local toY = ((self.sinkToY or transform.gridY) + 0.5) * transform.cellSize
	return fromX + (toX - fromX) * eased,
		fromY + (toY - fromY) * eased,
		1 - eased * 0.72,
		1 - eased
end

function Sinkable:draw()
	if self.state ~= "sinking" or not love or not love.graphics then return end
	local transform = self.owner:getComponent("Transform")
	local progress = math.min(self.sinkTime / self.sinkDuration, 1)
	love.graphics.push("all")
	love.graphics.setColor(0.08, 0.06, 0.12, (1 - progress) * 0.72)
	love.graphics.ellipse("fill", (self.sinkToX + 0.5) * transform.cellSize,
		(self.sinkToY + 0.5) * transform.cellSize + 12,
		transform.cellSize * (0.15 + progress * 0.22),
		transform.cellSize * (0.05 + progress * 0.1))
	love.graphics.pop()
end

return Sinkable
