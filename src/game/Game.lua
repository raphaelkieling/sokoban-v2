local SceneManager = require("src.core.SceneManager")
local Assets = require("src.game.Assets")
local CRT = require("src.rendering.CRT")
local MainMenu = require("src.screens.MainMenu")
local LevelSelect = require("src.screens.LevelSelect")
local About = require("src.screens.About")
local PlayingScene = require("src.screens.PlayingScene")
local Fonts = require("src.ui.Fonts")
local BuildConfig = require("src.settings.BuildConfig")
local MobileControls = require("src.input.MobileControls")
local AudioManager = require("src.audio.AudioManager")
local EventEmitter = require("src.core.EventEmitter")
local JsonLogger = require("src.core.JsonLogger")
local GameConfig = require("src.settings.GameConfig")
local LevelProgress = require("src.game.LevelProgress")
local Preferences = require("src.settings.Preferences")
local Settings = require("src.screens.Settings")
local I18n = require("src.i18n.I18n")
local Analytics = require("src.game.Analytics")
local AnalyticsScreen = require("src.screens.Analytics")

local Game = {}
Game.__index = Game

function Game.new()
    local self = setmetatable({}, Game)
    love.window.setTitle(GameConfig.title)
    self.preferences = Preferences.new()
    I18n.setLanguage(self.preferences:get("language"))
    love.window.setFullscreen(self.preferences:get("fullscreen"), "desktop")
    self.events = EventEmitter.new()
    self.logger = JsonLogger.new(self.events)
    self.analytics = Analytics.new(self.events)
    self.events:emit("game.opened", {})
    self.assets = Assets.new()
    self.mobileControls = MobileControls.new()
    self.audio = AudioManager.new(nil, self.preferences)
    self.audio:playMusicDirectory("assets/music", 0.12)
    self.scenes = SceneManager(self)
    self.crt = CRT()
    self.levelProgress = LevelProgress.new()
    self.completedLevels = self.levelProgress.completedLevels
    if BuildConfig.developmentMode then
        local Console = require("src.dev.Console")
        local ConsoleCommands = require("src.dev.ConsoleCommands")
        self.console = Console.new(self.events)
        ConsoleCommands.register(self.console)
        self.console:applyToggles({game = self})
    end
    self.scenes:register("menu", function(game) return MainMenu(game) end)
    self.scenes:register("levels", function(game) return LevelSelect(game) end)
    self.scenes:register("about", function(game) return About(game) end)
    self.scenes:register("analytics", function(game) return AnalyticsScreen(game) end)
    self.scenes:register("settings", function(game) return Settings(game) end)
    self.scenes:register("playing", function(game)
        return PlayingScene(game)
    end)
    Fonts.set(18)
    self.scenes:switch("menu")
    return self
end

function Game:update(dt)
    self.audio:update()
    if self.console then
        if self.console.open then return end
    end
    self.scenes:update(dt)
end

function Game:draw()
    self.crt:draw(function()
        self.scenes:draw()
        if self.console then self.console:draw() end
    end)
end

function Game:keypressed(key, scancode, isrepeat)
    if self.console then
        local currentScene = self.scenes.current
        local handled, action = self.console:keypressed(key, scancode, {
            board = currentScene and currentScene.board,
            scene = currentScene,
            game = self,
        })
        if handled then
            if action == "opened" and currentScene and currentScene.clearHeldMovement then
                currentScene:clearHeldMovement()
            end
            if action == "opened" and self.mobileControls then
                self.mobileControls:resetTouches()
            end
            return
        end
    end
    self.scenes:keypressed(key, scancode, isrepeat)
end

function Game:keyreleased(key, scancode)
	self.scenes:keyreleased(key, scancode)
end

function Game:textinput(text)
    if self.console and self.console.open then self.console:textinput(text) end
end
function Game:resize(width, height)
    self.crt:resize(width, height)
    self.scenes:resize(width, height)
end

function Game:touchpressed(id, x, y)
	if self.console and self.console.open then return end
	if self.scenes.current and self.scenes.current.touchpressed then
		self.scenes.current:touchpressed(id, x, y)
	end
end

function Game:touchmoved(id, x, y)
	if self.scenes.current and self.scenes.current.touchmoved then
		self.scenes.current:touchmoved(id, x, y)
	end
end

function Game:touchreleased(id)
	if self.scenes.current and self.scenes.current.touchreleased then
		self.scenes.current:touchreleased(id)
	end
end

function Game:mousepressed(x, y, button, isTouch)
	if isTouch or button ~= 1 or (self.console and self.console.open) then return end
	self:touchpressed("mouse", x, y)
end

function Game:mousemoved(x, y, dx, dy, isTouch)
	if isTouch then return end
	self:touchmoved("mouse", x, y)
end

function Game:mousereleased(x, y, button, isTouch)
	if isTouch or button ~= 1 then return end
	self:touchreleased("mouse")
end

return Game
