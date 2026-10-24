local Class = require("src.core.Class")

-- Shared parent/child lifecycle for scenes and world objects.
local Node = Class:extend()

function Node:init(name)
	self.name = name or "Node"
	self.parent = nil
	self.children = {}
	self.drawSpace = "world"
	self.active = true
end

function Node:addChild(child)
	assert(child and child ~= self, "a node cannot be its own child")
	assert(not child.parent, "node already has a parent")
	child.parent = self
	self.children[#self.children + 1] = child
	if child.onAttach then child:onAttach(self) end
	return child
end

function Node:removeChild(child)
	for index, candidate in ipairs(self.children) do
		if candidate == child then
			table.remove(self.children, index)
			child.parent = nil
			if child.onDetach then child:onDetach(self) end
			return true
		end
	end
	return false
end

function Node:updateChildren(dt)
	for _, child in ipairs(self.children) do
		if (child.active ~= false or child.visualOnly) and child.update then child:update(dt) end
	end
end

function Node:drawChildren(space, context)
	for _, child in ipairs(self.children) do
		if (child.active ~= false or child.visualOnly) and child.draw
			and (not space or child.drawSpace == space) then
			child:draw(context)
		end
	end
end

function Node:update(dt)
	self:updateChildren(dt)
end

function Node:draw(context)
	self:drawChildren(nil, context)
end

return Node
