local LevelSelect = require("src.screens.LevelSelect")

local tests = {}

local function selectionScene(unlocked)
	local scene = {levels = {{key = "first"}, {key = "second"}}, selected = 2}
	local switched, clicked = {}, {}
	scene.game = {
		levelProgress = {
			isUnlocked = function(_, levels, index)
				return unlocked and levels[index] ~= nil
			end,
		},
		audio = {play = function(_, name) clicked[#clicked + 1] = name end},
		scenes = {switch = function(_, name, index)
			switched[#switched + 1] = {name = name, index = index}
		end},
	}
	return scene, switched, clicked
end

function tests.confirm_does_not_start_a_locked_level()
	local scene, switched, clicked = selectionScene(false)
	LevelSelect.keypressed(scene, "return")
	assert(#switched == 0, "locked levels must not start")
	assert(#clicked == 0, "confirming a locked level should not play the start sound")
end

function tests.confirm_starts_an_unlocked_level()
	local scene, switched, clicked = selectionScene(true)
	LevelSelect.keypressed(scene, "return")
	assert(switched[1].name == "playing" and switched[1].index == 2)
	assert(clicked[1] == "menuClick")
end

return tests
