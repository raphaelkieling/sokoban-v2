local LevelLoader = require("src.game.LevelLoader")
local LevelSnapshot = require("src.game.LevelSnapshot")
local json = require("vendor.json")

local ConsoleCommands = {}

local function findLevelIndex(levels, query)
    local normalized = query:lower()

    local numericLevel = tonumber(normalized)
    for index, level in ipairs(levels) do
        if numericLevel and level.number == numericLevel then
            return index, level
        end
    end

    for index, level in ipairs(levels) do
        local name = (level.name or ""):lower()
        local shortName = name:gsub("^level[_%-]?", "")
        if normalized == name or normalized == shortName
            or name:find(normalized, 1, true) then
            return index, level
        end
    end
end

local function shellQuote(value)
	return "'" .. value:gsub("'", "'\\''") .. "'"
end

function ConsoleCommands.register(console)
	console:registerCommand("copy-logger-path", "copy the current JSON log path", function(context)
		local game = context and context.game
		local logger = game and game.logger
		if not logger then return "Logger is unavailable." end
		if logger.lastError then
			return "Logger write failed: " .. tostring(logger.lastError)
		end
		if not love.filesystem.getInfo(logger.path) then
			return "Logger file has not been created: " .. logger:getPath()
		end

		local path = logger:getPath()
		local quotedPath = shellQuote(path)
		local copied, err = pcall(love.system.setClipboardText, quotedPath)
		if not copied then return "Could not copy logger path: " .. tostring(err) end
		return "Shell-quoted logger path copied: " .. quotedPath
	end)

	console:registerCommand("copy-level-state", "copy the current level state as JSON", function(context)
		local scene = context and context.scene
		if not scene or not scene.board then return "No active level to capture." end

		local ok, encoded = pcall(json.encode, LevelSnapshot.capture(scene))
		if not ok then return "Could not encode level state: " .. tostring(encoded) end
		local copied, err = pcall(love.system.setClipboardText, encoded)
		if not copied then return "Could not copy level state: " .. tostring(err) end
		return "Level state JSON copied (" .. #encoded .. " characters)."
	end)

	console:registerToggleCommand("muted", "mute or unmute game audio", function(context, enabled)
		local audio = context and context.game and context.game.audio
		if not audio then return "Audio is unavailable." end
		audio:setMuted(enabled)
		return "Audio " .. (enabled and "muted" or "unmuted") .. "."
	end)

	console:registerCommand("reset-save", "clear completed-level progress", function(context)
		local progress = context and context.game and context.game.levelProgress
		if not progress then return "Level progress is unavailable." end
		if not progress:reset() then return "Could not reset level progress save." end
		return "Level progress save reset."
	end)

	console:registerCommand("unlock-all-levels", "mark every available level as completed", function(context)
		local progress = context and context.game and context.game.levelProgress
		if not progress then return "Level progress is unavailable." end
		local ok, levels = pcall(LevelLoader.listLevels)
		if not ok then return "Could not load the level list." end
		local saved, count = progress:markAllCompleted(levels)
		if not saved then return "Could not update level progress save." end
		return string.format("All levels marked completed (%d new).", count)
	end)

	console:registerToggleCommand("show-undo-history", "show player paths for each undo", function(context, enabled)
		local board = context and context.board
		if board then board.debugShowUndoHistory = enabled end
		return "Undo history " .. (enabled and "on" or "off") .. "."
	end)

	console:registerToggleCommand("mobile-controls", "show or hide mobile touch controls", function(context, enabled)
		local game = context and context.game
		if game and game.mobileControls then
			game.mobileControls.enabled = enabled
			if not enabled then game.mobileControls:resetTouches() end
		end
		return "Mobile controls " .. (enabled and "on" or "off") .. "."
	end)

	console:registerCommand("force reload", "restart the game and reload assets and levels", function(context)
		if not context or not context.game or not love then
			return "Game reload is unavailable."
		end

		local Game = require("src.game.Game")
		love.game = Game.new()
	end)

	console:registerToggleCommand("show-solid", "toggle outlines for solid cells and objects", function(context, enabled)
        local board = context and context.board
        if board then board.debugShowSolid = enabled end
        return "Solid outlines " .. (enabled and "on" or "off") .. "."
    end)

    console:registerCommand("help", "list available commands", function(_, _, activeConsole)
        local names = {}
        for name in pairs(activeConsole.commands) do names[#names + 1] = name end
        table.sort(names)
        return "Commands: " .. table.concat(names, ", ")
    end)

    console:registerCommand("jump-to", "load a level by number or name", function(context, args)
        local query = args[1]
		if not query then return "Usage: jump-to <level number|name>" end

        local levels = LevelLoader.listLevels()
        local index, level = findLevelIndex(levels, query)
        if not index then return "Level not found: " .. query end

        local game = context and context.game
        if not game or not game.scenes then return "No game scene manager available." end
        local currentScene = context.scene
		if currentScene and currentScene.jumpToLevel then
			currentScene:jumpToLevel(index, levels)
        else
            game.scenes:switch("playing", index)
        end
        return "Jumped to " .. level.name .. "."
    end)

	console:registerCommand("next-level", "load the next level in the current queue", function(context)
		local scene = context and context.scene
		if not scene or not scene.jumpToLevel or not scene.levels then
			return "No active level queue."
		end

		local nextIndex = scene.levelIndex + 1
		local nextLevel = scene.levels[nextIndex]
		if not nextLevel then return "Already at the last level in the queue." end

		scene:jumpToLevel(nextIndex)
		return "Next level: " .. nextLevel.name .. "."
	end)
end

return ConsoleCommands
