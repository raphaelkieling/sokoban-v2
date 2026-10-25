local Component = require("src.core.Component")
local Animation = require("src.components.Animation")

-- Owns grass growth state and swaps its tile animation when trampled.
local Grass = Component:extend()
Grass.componentName = "Grass"

local SPRITES = {
	grass = {x = 4, y = 19},
	tall = {x = 5, y = 19},
}

function Grass:init(assets, board, x, y, state)
	Component.init(self)
	self.assets = assets
	self.board = board
	self.x = x
	self.y = y
	self.state = state or "grass"
	assert(SPRITES[self.state], "Grass state must be 'grass' or 'tall'")
	local cell = board:getCell(x, y)
	self.walkableWhenShort = cell and cell.walkable == true or false
	self.components = {}
	self.componentOrder = {}
	self:addComponent(Animation(self:stateAnimation(self.state)))
	self:updateWalkability()
end

function Grass:stateAnimation(state)
	local sprite = SPRITES[state]
	return self.assets:tileAnimation(sprite.x, sprite.y)
end

function Grass:addComponent(component)
	assert(not self.components[component.componentName],
		"duplicate grass component: " .. component.componentName)
	component.owner = self.owner
	self.components[component.componentName] = component
	self.componentOrder[#self.componentOrder + 1] = component
	component:onAttach(self.owner)
	return self
end

function Grass:getNestedComponent(componentName)
	return self.components[componentName]
end

function Grass:onAttach(owner)
	for _, component in ipairs(self.componentOrder) do
		component.owner = owner
		component:onAttach(owner)
	end
end

function Grass:setState(state)
	assert(SPRITES[state], "Grass state must be 'grass' or 'tall'")
	if state == self.state then return false end
	self.state = state
	self.components.Animation:set(self:stateAnimation(state))
	self:updateWalkability()
	local renderer = self.owner and self.owner:getComponent("SpriteRenderer")
	if renderer then renderer:playWhiteFlash() end
	return true
end

function Grass:updateWalkability()
	local cell = self.board:getCell(self.x, self.y)
	if not cell then return end
	cell.terrainKind = self.state == "tall" and "tall_grass" or "grass"
	cell.walkable = self.state == "grass" and self.walkableWhenShort and not cell.wall or false
end

function Grass:update(dt)
	for _, component in ipairs(self.componentOrder) do
		component:update(dt)
	end
end

return Grass
