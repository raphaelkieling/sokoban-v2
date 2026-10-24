local GameObject = require("src.core.GameObject")
local Transform = require("src.components.Transform")
local Target = require("src.components.Target")

local tests = {}

function tests.target_owns_free_and_pressed_single_frame_animations()
	local occupied = false
	local board = {isBoxAt = function() return occupied end}
	local assets = {
		tileColumns = 17,
		tileAnimation = function(_, x, y)
			return {x = x, y = y, update = function() end}
		end,
	}
	local object = GameObject("test-target")
	object:addComponent(Transform(3, 4, 64, 1))
	local target = Target(board, assets, 16 * 17 + 9)
	object:addComponent(target)

	local animation = object:getComponent("Animation")
	assert(target.state == "free")
	assert(animation.current.x == 9 and animation.current.y == 16)

	occupied = true
	target:update(0)
	assert(target.state == "pressed")
	assert(target.pulseTime == target.pulseDuration,
		"pressing a target should start its pulse feedback")
	assert(animation.current.x == 10 and animation.current.y == 16)
	target:update(target.pulseDuration / 2)
	assert(target.pulseTime > 0 and target.pulseTime < target.pulseDuration)

	occupied = false
	target:update(0)
	assert(target.state == "free")
	assert(animation.current.x == 9 and animation.current.y == 16)
end

return tests
