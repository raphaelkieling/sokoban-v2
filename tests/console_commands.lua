local ConsoleCommands = require("src.dev.ConsoleCommands")
local LevelLoader = require("src.game.LevelLoader")

local tests = {}

function tests.muted_console_toggle_changes_audio_state()
	local commands = {}
	local console = {}
	function console:registerCommand(name, description, callback)
		commands[name] = {description = description, callback = callback}
	end
	function console:registerToggleCommand(name, description, callback)
		self:registerCommand(name, description, callback)
		commands[name].toggle = true
	end

	ConsoleCommands.register(console)
	local command = assert(commands.muted, "muted command should be registered")
	assert(command.toggle, "muted should use the console toggle behavior")

	local muted
	local context = {game = {audio = {setMuted = function(_, enabled) muted = enabled end}}}
	assert(command.callback(context, true) == "Audio muted.")
	assert(muted == true)
	assert(command.callback(context, false) == "Audio unmuted.")
	assert(muted == false)
end

function tests.reset_save_console_command_clears_level_progress()
	local commands = {}
	local console = {
		registerCommand = function(_, name, description, callback)
			commands[name] = {description = description, callback = callback}
		end,
		registerToggleCommand = function(self, name, description, callback)
			self:registerCommand(name, description, callback)
		end,
	}
	ConsoleCommands.register(console)
	local resetCalled = false
	local context = {game = {levelProgress = {
		reset = function() resetCalled = true; return true end,
	}}}
	local command = assert(commands["reset-save"], "reset-save should be registered")
	assert(command.callback(context) == "Level progress save reset.")
	assert(resetCalled)
end

function tests.unlock_all_levels_command_marks_every_listed_level_completed()
	local commands = {}
	local console = {
		registerCommand = function(_, name, description, callback)
			commands[name] = {description = description, callback = callback}
		end,
		registerToggleCommand = function(self, name, description, callback)
			self:registerCommand(name, description, callback)
		end,
	}
	ConsoleCommands.register(console)
	local previousListLevels = LevelLoader.listLevels
	local testLevels = {{key = "level-1"}, {key = "level-2"}}
	LevelLoader.listLevels = function() return testLevels end
	local receivedLevels
	local context = {game = {levelProgress = {
		markAllCompleted = function(_, levels)
			receivedLevels = levels
			return true, #levels
		end,
	}}}
	local command = assert(commands["unlock-all-levels"], "unlock-all-levels should be registered")
	local result = command.callback(context)
	LevelLoader.listLevels = previousListLevels
	assert(receivedLevels == testLevels, "the command should mark levels from the loader's list")
	assert(result == "All levels marked completed (2 new).")
end

return tests
