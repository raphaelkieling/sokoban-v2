local Class = require("src.core.Class")
local DiagonalWipe = require("src.ui.DiagonalWipe")

local TRANSITION_DURATION = 0.6
local unpackArgs = table.unpack or unpack

local SceneManager = Class:extend()

function SceneManager:init(game)
    self.game = game
    self.factories = {}
    self.current = nil
    self.currentName = nil
    self.transition = nil
end

function SceneManager:register(name, factory)
    self.factories[name] = factory
end

function SceneManager:switch(name, ...)
    local factory = assert(self.factories[name], "unknown scene: " .. tostring(name))
    local args = {...}
    if not self.current or self.currentName == name then
        self:switchImmediately(name, args)
        return
    end
    if self.transition then return end
    self.transition = {elapsed = 0, switched = false, name = name, args = args}
end

function SceneManager:switchImmediately(name, args)
    local factory = assert(self.factories[name], "unknown scene: " .. tostring(name))
    if self.current and self.current.leave then self.current:leave() end
    self.currentName = name
    self.current = factory(self.game)
    if self.current.enter then
        self.current:enter(unpackArgs(args or {}))
    end
    self.game.events:emit("screen.opened", {screen = name})
end

function SceneManager:update(dt)
    if self.transition then
        local transition = self.transition
        transition.elapsed = transition.elapsed + dt
        if not transition.switched and transition.elapsed >= TRANSITION_DURATION / 2 then
            self:switchImmediately(transition.name, transition.args)
            transition.switched = true
        end
        if transition.elapsed >= TRANSITION_DURATION then self.transition = nil end
        return
    end
    if self.current and self.current.update then
        self.current:update(dt)
    end
end

function SceneManager:draw()
    if self.current and self.current.draw then
        self.current:draw()
    end
    if self.transition then
        local progress = math.min(1, self.transition.elapsed / TRANSITION_DURATION)
        local coverage = self.transition.switched and (1 - progress) * 2 or progress * 2
        DiagonalWipe.draw(coverage)
    end
end

function SceneManager:keypressed(key)
    if self.transition then return end
    if self.current and self.current.keypressed then
        self.current:keypressed(key)
    end
end

function SceneManager:keyreleased(key)
	if self.current and self.current.keyreleased then
		self.current:keyreleased(key)
	end
end

function SceneManager:resize(width, height)
    if self.current and self.current.resize then
        self.current:resize(width, height)
    end
end

return SceneManager
