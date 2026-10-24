local Class = require("src.core.Class")

local LevelTransition = Class:extend()

function LevelTransition:init(scene, machine)
	self.scene = scene
	self.machine = machine
	self.elapsed = 0
	self.duration = 0.55
end

function LevelTransition:enter()
	self.scene.transition = {elapsed = 0, duration = self.duration}
end

function LevelTransition:update(dt)
	local previousElapsed = self.elapsed
	self.elapsed = self.elapsed + dt
	self.scene.transition.elapsed = self.elapsed
	if previousElapsed < self.duration / 2 and self.elapsed >= self.duration / 2 then
		if self.scene.pendingTransitionLevelIndex then
			self.scene.levelIndex = self.scene.pendingTransitionLevelIndex
			self.scene.pendingTransitionLevelIndex = nil
			self.scene:loadLevel()
		else
			self.scene:loadNextLevel()
		end
		self.scene:beginCameraIntro()
	end
	if self.elapsed >= self.duration / 2 then self.scene:updateCamera(dt) end
	if self.elapsed >= self.duration then
		self.scene.transition = nil
		self.machine:change("playing")
	end
end

return LevelTransition
