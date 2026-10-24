local PlayerSelector = require("src.game.PlayerSelector")

local tests = {}

local function player(x, y, active, sinkState)
	local transform = {gridX = x, gridY = y}
	local sinkable = sinkState and {state = sinkState} or nil
	return {
		active = active,
		getComponent = function(_, name)
			if name == "Transform" then return transform end
			if name == "Sinkable" then return sinkable end
		end,
	}
end

function tests.cycling_skips_lost_players()
	local selector = PlayerSelector()
	local players = {player(0, 0, false), player(1, 0, true), player(2, 0, false)}
	local change = selector:selectNext(players)
	assert(change and change.to == 2 and selector.activeIndex == 2)
end

function tests.directional_selection_never_picks_a_lost_player()
	local selector = PlayerSelector()
	local players = {player(0, 0, true), player(2, 0, false), player(0, 1, true)}
	selector:begin()
	local change = selector:selectInDirection(players, {x = 1, y = 0})
	assert(change == nil and selector.activeIndex == 1,
		"the dead player ahead should not be a directional selection candidate")
end

function tests.selection_recovers_when_the_current_player_is_lost()
	local selector = PlayerSelector()
	selector.activeIndex = 2
	local players = {player(0, 0, true), player(1, 0, false), player(2, 0, true)}
	local change = selector:selectNext(players)
	assert(change and change.to == 3 and selector.activeIndex == 3,
		"cycling from a lost player should move to the next living one")
end

function tests.automatic_selection_waits_until_the_fall_finishes()
	local selector = PlayerSelector()
	local players = {player(0, 0, false, "sinking"), player(1, 0, true)}
	assert(selector:ensureLivingPlayer(players) == nil and selector.activeIndex == 1,
		"keep the falling player selected until its animation finishes")

	players[1].getComponent = function(_, name)
		if name == "Transform" then return {gridX = 0, gridY = 0} end
		if name == "Sinkable" then return {state = "lost"} end
	end
	local change = selector:ensureLivingPlayer(players)
	assert(change and change.to == 2 and selector.activeIndex == 2,
		"after a player is lost, select the next living player automatically")
end

return tests
