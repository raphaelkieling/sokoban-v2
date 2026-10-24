local Component = require("src.core.Component")
local CoreStateMachine = require("src.core.StateMachine")

local StateMachine = Component:extend()
StateMachine.componentName = "StateMachine"

function StateMachine:init(states, initialState)
    Component.init(self)
    self.states = assert(states, "StateMachine needs a state registry")
    self.initialState = assert(initialState, "StateMachine needs an initial state")
    self.currentName = nil
    self.current = nil
    self.machine = nil
end

function StateMachine:onAttach(owner)
    self.owner = owner
    self.machine = CoreStateMachine(owner, self.states, self.initialState)
    self:sync()
end

function StateMachine:sync()
    if not self.machine then return end
    self.currentName = self.machine.currentName
    self.current = self.machine.current
end

function StateMachine:change(name, data)
    local changed = self.machine:change(name, data)
    self:sync()
    return changed
end

function StateMachine:update(dt)
    self.machine:update(dt)
    self:sync()
end

function StateMachine:dispatch(methodName, ...)
    local handled = self.machine:dispatch(methodName, ...)
    self:sync()
    return handled
end

function StateMachine:visualOffset()
    if not self.machine then return 0, 0, 0 end
    local rotation, offsetX, offsetY = self.machine:dispatch("visualOffset")
    return rotation or 0, offsetX or 0, offsetY or 0
end

function StateMachine:visualScale()
	if not self.machine then return 1, 1 end
	local scaleX, scaleY = self.machine:dispatch("visualScale")
	return scaleX or 1, scaleY or 1
end

return StateMachine
