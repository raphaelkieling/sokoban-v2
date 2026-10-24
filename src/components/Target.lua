local Component = require("src.core.Component")
local Animation = require("src.components.Animation")

-- Owns a target's pressed/free state and the one-frame animation for each.
local Target = Component:extend()
Target.componentName = "Target"

function Target:init(board, assets, tileId)
	Component.init(self)
	self.board = board
	self.assets = assets
	self.tileId = tileId or (16 * assets.tileColumns + 9)
	self.state = "free"
	self.pulseDuration = 0.32
	self.pulseTime = 0
	self.components = {}
	self.componentOrder = {}

	local column = self.tileId % assets.tileColumns
	local row = math.floor(self.tileId / assets.tileColumns)
	self.freeAnimation = assets:tileAnimation(column, row)
	self.pressedAnimation = assets:tileAnimation(column + 1, row)
	self:addComponent(Animation(self.freeAnimation))
end

function Target:addComponent(component)
	assert(not self.components[component.componentName],
		"duplicate target component: " .. component.componentName)
	component.owner = self.owner
	self.components[component.componentName] = component
	self.componentOrder[#self.componentOrder + 1] = component
	component:onAttach(self.owner)
	return self
end

function Target:getNestedComponent(componentName)
	return self.components[componentName]
end

function Target:onAttach(owner)
	for _, component in ipairs(self.componentOrder) do
		component.owner = owner
		component:onAttach(owner)
	end
end

function Target:setState(state)
	if state == self.state then return end
	self.state = state
	self.pulseTime = state == "pressed" and self.pulseDuration or 0
	local animation = self.components.Animation
	animation:set(state == "pressed" and self.pressedAnimation or self.freeAnimation)
end

function Target:refreshState()
	local transform = self.owner:getComponent("Transform")
	local pressed = self.board:isBoxAt(transform.gridX, transform.gridY)
	self:setState(pressed and "pressed" or "free")
end

function Target:update(dt)
	self:refreshState()
	self.pulseTime = math.max(0, self.pulseTime - dt)
	for _, component in ipairs(self.componentOrder) do
		component:update(dt)
	end
end

function Target:draw()
	if self.pulseTime <= 0 or not love or not love.graphics then return end
	local transform = self.owner:getComponent("Transform")
	local progress = 1 - self.pulseTime / self.pulseDuration
	love.graphics.push("all")
	love.graphics.setColor(0.93, 0.78, 0.44, (1 - progress) * 0.78)
	love.graphics.setLineWidth(1.5 + (1 - progress) * 1.5)
	love.graphics.ellipse("line", transform.x, transform.y + 13,
		transform.cellSize * (0.2 + progress * 0.28),
		transform.cellSize * (0.08 + progress * 0.12))
	love.graphics.pop()
end

return Target
