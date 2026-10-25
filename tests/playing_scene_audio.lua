local PlayingScene = require("src.screens.PlayingScene")

local tests = {}

function tests.selecting_a_class_has_a_forty_percent_chance_to_play_its_voice()
	local previousRandom = math.random
	math.random = function() return 0.39 end
	local played, emitted = {}, {}
	local selectedPlayer = {
		getComponent = function(_, name)
			if name == "CharacterClass" then
				return {selectionVoiceSound = "wizardVoice"}
			end
		end,
	}
	local scene = {
		board = {players = {selectedPlayer}},
		game = {
			audio = {playRandom = function(_, sound) played[#played + 1] = sound end},
			events = {emit = function(_, name, payload)
				emitted[#emitted + 1] = {name = name, payload = payload}
			end},
		},
	}

	local change = {from = 1, to = 1}
	PlayingScene.emitPlayerSwitch(scene, change)
	math.random = previousRandom
	assert(played[1] == "wizardVoice")
	assert(emitted[1].name == "player.switched")
end

function tests.selecting_a_class_can_skip_its_voice_without_skipping_selection_event()
	local previousRandom = math.random
	math.random = function() return 0.4 end
	local played, emitted = {}, {}
	local selectedPlayer = {
		getComponent = function(_, name)
			if name == "CharacterClass" then
				return {selectionVoiceSound = "wizardVoice"}
			end
		end,
	}
	local scene = {
		board = {players = {selectedPlayer}},
		game = {
			audio = {playRandom = function(_, sound) played[#played + 1] = sound end},
			events = {emit = function(_, name, payload)
				emitted[#emitted + 1] = {name = name, payload = payload}
			end},
		},
	}

	PlayingScene.emitPlayerSwitch(scene, {from = 1, to = 1})
	math.random = previousRandom
	assert(#played == 0, "the voice should be skipped when the random roll is outside the 40% chance")
	assert(emitted[1].name == "player.switched", "selection event should always be emitted")
end

function tests.wizard_swap_plays_teleport_sound()
	local played = {}
	local player = {}
	local class = {id = "wizard"}
	local otherObject = {}
	local movement = {
		move = function()
			return true, {
				{object = player, fromX = 1, fromY = 1, toX = 2, toY = 1},
				{object = otherObject, fromX = 2, fromY = 1, toX = 1, toY = 1},
			}
		end,
	}
	function player:getComponent(name)
		if name == "CharacterClass" then return class end
		if name == "CharacterMovement" then return movement end
	end

	local scene = {
		board = {boxes = {}, getCell = function() return nil end},
		game = {
			audio = {play = function(_, name) played[#played + 1] = name end},
			events = {emit = function() end},
		},
		levelPath = "test-level",
		playerSelector = {activeIndex = 1},
		currentPlayer = function() return player end,
		activateEnteredTriggers = function() end,
	}

	local moved = PlayingScene.movePlayer(scene, {x = 1, y = 0})
	assert(moved == true)
	assert(played[1] == "teleport", "wizard swaps should play the teleport sound")
end

function tests.farmer_grass_action_plays_grass_sound_instead_of_footsteps()
	local played = {}
	local player = {}
	local class = {id = "farmer"}
	local movement = {move = function() return true, {} end}
	function player:getComponent(name)
		if name == "CharacterClass" then return class end
		if name == "CharacterMovement" then return movement end
	end

	local scene = {
		board = {boxes = {}, getCell = function() return nil end},
		game = {
			audio = {play = function(_, name) played[#played + 1] = name end},
			events = {emit = function() end},
		},
		levelPath = "test-level",
		playerSelector = {activeIndex = 1},
		currentPlayer = function() return player end,
		activateEnteredTriggers = function() end,
	}

	local moved = PlayingScene.movePlayer(scene, {x = 1, y = 0})
	assert(moved == true)
	assert(played[1] == "grassChange", "farmer grass changes should play the grass sound")
end

function tests.burning_grass_plays_fire_sound_and_records_undo_state()
	local played, recorded = {}, {}
	local grass = {hasComponent = function() return false end}
	local scene = {
		board = {objects = {grass}},
		game = {audio = {play = function(_, name) played[#played + 1] = name end}},
		history = {appendToLatest = function(_, snapshots) recorded[#recorded + 1] = snapshots end},
	}

	PlayingScene.onComponentStateChanged(scene, {
		cause = "flame", objectIndex = 1, component = "Grass",
		previousState = "tall", state = "grass",
	})
	assert(played[1] == "grassFire", "burning grass should play its fire sound")
	assert(#recorded == 1, "burning grass should remain undoable")
end

function tests.character_sinking_plays_body_fall_sound()
	local played = {}
	local player = {hasComponent = function(_, name) return name == "Player" end}
	local scene = {
		board = {objects = {player}},
		game = {audio = {play = function(_, name) played[#played + 1] = name end}},
	}

	PlayingScene.onComponentStateChanged(scene, {
		cause = "sink", objectIndex = 1, component = "Sinkable",
		previousState = "approaching", state = "sinking",
	})
	assert(played[1] == "bodyFall", "a character entering the sinking state should play the fall sound")
end

return tests
