local TriggerRegistry = require("src.game.TriggerRegistry")
local PlayingScene = require("src.screens.PlayingScene")

local tests = {}

function tests.first_tutorial_trigger_shows_its_localized_message_key()
	local shownMessage
	local shownDuration
	local emittedEvent
	local eventCount = 0
	local scene = {
		board = {},
		levelPath = "maps-v2/Map.ldtk#Level_0",
		showMessage = function(_, key, duration)
			shownMessage = key
			shownDuration = duration
		end,
		game = {
			events = {emit = function(_, eventName, payload)
				eventCount = eventCount + 1
				emittedEvent = {name = eventName, payload = payload}
			end},
		},
	}
	local trigger = {name = "first_tutorial", x = 7, y = 6}
	local player = {}

	assert(TriggerRegistry.activate(scene, trigger, player))
	assert(shownMessage == "tutorial.first_tutorial")
	assert(shownDuration == 8)
	assert(emittedEvent.name == "trigger.activated")
	assert(emittedEvent.payload.name == trigger.name)
	assert(emittedEvent.payload.x == trigger.x and emittedEvent.payload.y == trigger.y)
	assert(emittedEvent.payload.scene == nil and emittedEvent.payload.player == nil,
		"event payloads should stay serializable for the session logger")
	assert(emittedEvent.payload.level == scene.levelPath)
	assert(not TriggerRegistry.activate(scene, trigger, player),
		"a once trigger should not activate again during this level session")
	assert(eventCount == 1)
end

function tests.undo_tutorial_uses_the_configured_undo_key_and_is_one_shot()
	local received
	local scene = {
		showMessage = function(_, key, duration, keyLabel)
			received = {key = key, duration = duration, keyLabel = keyLabel}
		end,
		game = {events = {emit = function() end}},
	}
	local trigger = {name = "tutorial_undo", x = 4, y = 3}
	assert(TriggerRegistry.activate(scene, trigger))
	assert(received.key == "tutorial.undo")
	assert(received.duration == 8)
	assert(received.keyLabel == "K")
	assert(not TriggerRegistry.activate(scene, trigger),
		"the undo tutorial should only show once per placed trigger")
end

function tests.change_player_tutorial_uses_the_configured_switch_key()
	local received
	local scene = {
		showMessage = function(_, key, duration, keyLabel, repeatedKeyLabel)
			received = {key = key, duration = duration,
				keyLabel = keyLabel, repeatedKeyLabel = repeatedKeyLabel}
		end,
		game = {events = {emit = function() end}},
	}
	local trigger = {name = "tutorial_change_player", x = 2, y = 4}
	assert(TriggerRegistry.activate(scene, trigger))
	assert(received.key == "tutorial.change_player")
	assert(received.duration == 8)
	assert(received.keyLabel == "J" and received.repeatedKeyLabel == "J")
	assert(not TriggerRegistry.activate(scene, trigger))
end

function tests.registered_trigger_can_repeat_and_configure_message_duration()
	local activations = 0
	local receivedDuration
	TriggerRegistry.register("repeat_fixture", function(context)
		activations = activations + 1
		receivedDuration = context.duration
	end, {duration = 3.5, once = false})
	local scene = {game = {events = {emit = function() end}}}
	local trigger = {name = "repeat_fixture"}

	assert(TriggerRegistry.activate(scene, trigger))
	assert(TriggerRegistry.activate(scene, trigger))
	assert(activations == 2)
	assert(receivedDuration == 3.5)
end

function tests.unregistered_trigger_still_emits_an_event_for_other_listeners()
	local emitted = false
	local scene = {
		game = {events = {emit = function(_, eventName, payload)
			emitted = eventName == "trigger.activated" and payload.name == "future_trigger"
		end}},
	}
	assert(not TriggerRegistry.activate(scene, {name = "future_trigger"}))
	assert(emitted)
end

function tests.entering_a_trigger_tile_dispatches_its_registered_handler()
	local shownMessage
	local player = {hasComponent = function(_, name) return name == "Player" end}
	local trigger = {name = "first_tutorial", x = 7, y = 6}
	local scene = {
		board = {
			players = {player},
			getTriggersAt = function(_, x, y)
				return x == trigger.x and y == trigger.y and {trigger} or {}
			end,
		},
		levelPath = "maps-v2/Map.ldtk#Level_0",
		showMessage = function(_, key) shownMessage = key end,
		game = {events = {emit = function() end}},
	}

	PlayingScene.activateEnteredTriggers(scene, {{object = player, toX = 7, toY = 6}})
	assert(shownMessage == "tutorial.first_tutorial")
end

return tests
