local Preferences = require("src.settings.Preferences")

local tests = {}

function tests.preferences_persist_valid_settings_and_clamp_music_volume()
    local saved
    local storage = {
        read = function() return saved end,
        write = function(_, contents) saved = contents return true end,
    }
    local preferences = Preferences.new(storage)
    assert(preferences:get("language") == "pt")
    assert(preferences:get("fullscreen") == false)

    assert(preferences:set("language", "es"))
    assert(preferences:set("musicVolume", 1.4))
    assert(preferences:set("fullscreen", true))
    assert(preferences:get("musicVolume") == 1)

    local restored = Preferences.new(storage)
    assert(restored:get("language") == "es")
    assert(restored:get("musicVolume") == 1)
    assert(restored:get("fullscreen") == true)
    assert(not restored:set("language", "fr"))
end

return tests
