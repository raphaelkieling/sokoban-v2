local Component = require("src.core.Component")
local Animation = require("src.components.Animation")
local Highlight = require("src.components.Highlight")

-- Owns the bonfire's lit/unlit state and its matching sprite animation.
local Bonfire = Component:extend()
Bonfire.componentName = "Bonfire"

function Bonfire:init(assets, tileset, state)
	Component.init(self)
	self.assets = assets
	self.tileset = tileset
	self.state = state or "lit"
	assert(self.state == "lit" or self.state == "unlit", "Bonfire state must be 'lit' or 'unlit'")
	self.components = {}
	self.componentOrder = {}
    self:addComponent(Animation(assets:bonfireAnimation(tileset, self.state)))
	self:addComponent(Highlight())
end

function Bonfire:addComponent(component)
	assert(not self.components[component.componentName],
		"duplicate bonfire component: " .. component.componentName)
	component.owner = self.owner
	self.components[component.componentName] = component
	self.componentOrder[#self.componentOrder + 1] = component
	component:onAttach(self.owner)
	return self
end

function Bonfire:getNestedComponent(componentName)
	return self.components[componentName]
end

function Bonfire:onAttach(owner)
	for _, component in ipairs(self.componentOrder) do
		component.owner = owner
		component:onAttach(owner)
	end
end

function Bonfire:setState(state)
	assert(state == "lit" or state == "unlit", "Bonfire state must be 'lit' or 'unlit'")
	if state == self.state then return end
	self.state = state
	self.components.Animation:set(self.assets:bonfireAnimation(self.tileset, state))
end

function Bonfire:update(dt)
	for _, component in ipairs(self.componentOrder) do
		component:update(dt)
	end
end

return Bonfire
