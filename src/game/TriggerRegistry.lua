local TriggerRegistry = {handlers = {}}
local Keymap = require("src.settings.Keymap")

function TriggerRegistry.register(name, handler, options)
	assert(type(name) == "string" and name ~= "", "trigger name must be a non-empty string")
	assert(type(handler) == "function", "trigger handler must be a function")
	options = options or {}
	assert(options.duration == nil or (type(options.duration) == "number" and options.duration > 0),
		"trigger duration must be a positive number")
	assert(options.once == nil or type(options.once) == "boolean",
		"trigger once option must be a boolean")
	TriggerRegistry.handlers[name] = {
		handler = handler,
		duration = options.duration,
		once = options.once == true,
	}
end

function TriggerRegistry.activate(scene, trigger, player)
	local context = {
		name = trigger.name,
		trigger = trigger,
		player = player,
		board = scene.board,
		level = scene.levelPath,
		scene = scene,
		game = scene.game,
	}
	local definition = TriggerRegistry.handlers[trigger.name]
	if definition and definition.once then
		scene.activatedTriggers = scene.activatedTriggers or {}
		if scene.activatedTriggers[trigger] then return false end
		scene.activatedTriggers[trigger] = true
	end

	if scene.game and scene.game.events then
		local eventData = {
			name = trigger.name,
			level = scene.levelPath,
			x = trigger.x,
			y = trigger.y,
			once = definition and definition.once or false,
		}
		if player and player.getComponent then
			local characterClass = player:getComponent("CharacterClass")
			if characterClass then eventData.characterClass = characterClass.id end
			for index, candidate in ipairs(scene.board and scene.board.players or {}) do
				if candidate == player then
					eventData.playerIndex = index
					break
				end
			end
		end
		scene.game.events:emit("trigger.activated", eventData)
	end
	if not definition then return false end
	context.duration = definition.duration
	definition.handler(context)
	return true
end

-- Add named behavior here, or register handlers from another game module.
TriggerRegistry.register("first_tutorial", function(context)
	context.scene:showMessage("tutorial.first_tutorial", context.duration)
end, { duration = 8, once = true })

TriggerRegistry.register("tutorial_undo", function(context)
	context.scene:showMessage("tutorial.undo", context.duration, Keymap.label("undo"))
end, { duration = 8, once = true })

TriggerRegistry.register("tutorial_change_player", function(context)
	context.scene:showMessage("tutorial.change_player", context.duration,
		Keymap.label("switchPlayer"), Keymap.label("switchPlayer"))
end, { duration = 8, once = true })


return TriggerRegistry
