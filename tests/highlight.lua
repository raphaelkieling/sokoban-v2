local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local Highlight = require("src.components.Highlight")

local tests = {}

function tests.highlight_runs_on_a_configurable_interval_and_expires()
	local object = GameObject("test-object")
	local highlight = Highlight({interval = 6, duration = 0.4, velocity = 900})
	object:addComponent(Transform(1, 2, 64, 2))
	object:addComponent(highlight)

	highlight:update(5.9)
	assert(highlight:phase() == nil)
	highlight:update(0.1)
	assert(highlight:phase() == 0)
	highlight:update(0.2)
	assert(highlight:phase() == 0.5)
	highlight:update(0.2)
	assert(highlight:phase() == nil)
	highlight:update(5.6)
	assert(highlight:phase() == 0,
		"the next highlight should begin one interval after the previous one")
end

function tests.highlight_phase_uses_degrees_per_second_and_loops_until_expiry()
	local highlight = Highlight({interval = 10, duration = 1, velocity = 900})
	highlight.highlightElapsed = 0.5
	assert(highlight:phase() == 1.25,
		"the sprite outline should continue past one full rotation based on velocity")
	assert(highlight:opacity() == 1,
		"opacity should reach full strength independently of angular velocity")
	highlight.highlightElapsed = 0.1
	assert(highlight:opacity() > 0 and highlight:opacity() < 1,
		"the outline should fade in at the start of its sweep")
	highlight.highlightElapsed = 0.95
	assert(highlight:opacity() > 0 and highlight:opacity() < 1,
		"the outline should fade out at the end of its sweep")
end

return tests
