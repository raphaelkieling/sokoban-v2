local Settings = require("src.screens.Settings")
local I18n = require("src.i18n.I18n")

local tests = {}

function tests.settings_controls_update_and_persist_preferences()
    local previousLove = love
    local window = {fullscreen = false}
    _G.love = {
        window = {
            getFullscreen = function() return window.fullscreen end,
            setFullscreen = function(enabled)
                window.fullscreen = enabled
                return true
            end,
        },
    }

    local values = {fullscreen = false, musicVolume = 0.75, muted = false, language = "pt"}
    local game = {}
    game.preferences = {
        get = function(_, key) return values[key] end,
        set = function(_, key, value) values[key] = value return true end,
    }
    game.audio = {
        getMusicVolume = function(self) return self.volume or 0.75 end,
        setMusicVolume = function(self, value) self.volume = value end,
        isMuted = function(self) return self.muted == true end,
        setMuted = function(self, value) self.muted = value end,
        play = function() end,
    }
    game.scenes = {switch = function(_, name) game.switchedTo = name end}
    local screen = Settings(game)
    screen:keypressed("return")
    assert(values.fullscreen == true and window.fullscreen == true)
    screen.selected = 2
    screen:keypressed("left")
    assert(math.abs(values.musicVolume - 0.70) < 0.000001)
    screen.selected = 3
    screen:keypressed("return")
    assert(values.muted == true)
    screen.selected = 4
    screen:keypressed("right")
    assert(values.language == "en" and I18n.getLanguage() == "en")
    screen.selected = 5
    screen:keypressed("return")
    assert(game.switchedTo == "menu")

    I18n.setLanguage("pt")
    _G.love = previousLove
end

return tests
