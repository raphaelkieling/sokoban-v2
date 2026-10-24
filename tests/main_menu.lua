local MainMenu = require("src.screens.MainMenu")

local tests = {}

function tests.analytics_is_an_independent_main_menu_destination()
	local switchedTo
	local game = {
		audio = {play = function() end},
		scenes = {switch = function(_, destination) switchedTo = destination end},
	}
	local menu = MainMenu(game)
	assert(menu.options[3] == "menu.analytics")
	menu.selected = 3
	menu:keypressed("return")
	assert(switchedTo == "analytics")
end

return tests
