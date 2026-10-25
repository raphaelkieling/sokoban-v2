local Component = require("src.core.Component")

local Highlight = Component:extend()
Highlight.componentName = "Highlight"

function Highlight:init(options)
	Component.init(self)
	options = options or {}
	self.interval = options.interval or 3.5
	self.duration = options.duration or 1
	self.velocity = options.velocity or 500
	self.elapsed = 0
	self.highlightElapsed = nil
end

function Highlight:update(dt)
	self.elapsed = self.elapsed + dt
	if self.highlightElapsed then
		self.highlightElapsed = self.highlightElapsed + dt
		if self.highlightElapsed >= self.duration then
			self.highlightElapsed = nil
		end
	end

	if self.elapsed >= self.interval then
		self.elapsed = self.elapsed % self.interval
		if not self.highlightElapsed then self.highlightElapsed = 0 end
	end
end

function Highlight:phase()
	if not self.highlightElapsed then return nil end
	return self.highlightElapsed * self.velocity / 360
end

function Highlight:opacity()
	if not self.highlightElapsed then return 0 end
	local progress = math.min(self.highlightElapsed / self.duration, 1)
	local fadeIn = math.max(0, math.min((progress - 0.02) / 0.16, 1))
	local fadeOut = math.max(0, math.min((0.98 - progress) / 0.18, 1))
	return fadeIn * fadeOut
end

return Highlight
