local Component = require("src.core.Component")

-- Owns the falling/lost lifecycle for any entity that can sink into passthrough.
local Sinkable = Component:extend()
Sinkable.componentName = "Sinkable"

function Sinkable:init()
	Component.init(self)
	self.state = "active"
	self.sinkDuration = 0.38
	self.sinkTime = 0
	self.sinkToX, self.sinkToY = nil, nil
end

function Sinkable:setState(state, metadata)
	assert(state == "active" or state == "approaching" or state == "sinking" or state == "lost",
		"Sinkable state must be active, approaching, sinking, or lost")
	if self.state == state then return false end
	self.state = state
	if state == "approaching" or state == "sinking" then
		if metadata then
			self.sinkToX, self.sinkToY = metadata.sinkX, metadata.sinkY
		end
		self.sinkTime = 0
	elseif state == "active" then
		self.sinkToX, self.sinkToY = nil, nil
		self.sinkTime = 0
	end
	if self.owner then
		self.owner.active = state == "active" or state == "approaching"
		self.owner.visualOnly = state == "sinking"
	end
	return true
end

function Sinkable:onAttach(owner)
	owner.active = self.state == "active" or self.state == "approaching"
	owner.visualOnly = self.state == "sinking"
end

function Sinkable:update(dt)
	if self.state == "approaching" then
		local transform = self.owner:getComponent("Transform")
		if not transform:isMoving() then self:setState("sinking") end
		return
	end
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
	return transform.x,
		transform.y + eased * transform.cellSize * 0.12,
		1 - eased * 0.72,
		1 - eased
end

function Sinkable:draw()
	if self.state ~= "sinking" or not love or not love.graphics then return end
	local transform = self.owner:getComponent("Transform")
	local progress = math.min(self.sinkTime / self.sinkDuration, 1)
	local sinkX, sinkY = self.sinkToX or transform.gridX, self.sinkToY or transform.gridY
	love.graphics.push("all")
	love.graphics.setColor(0.08, 0.06, 0.12, (1 - progress) * 0.72)
	love.graphics.ellipse("fill", (sinkX + 0.5) * transform.cellSize,
		(sinkY + 0.5) * transform.cellSize + 12,
		transform.cellSize * (0.15 + progress * 0.22),
		transform.cellSize * (0.05 + progress * 0.1))
	love.graphics.pop()
end

return Sinkable
