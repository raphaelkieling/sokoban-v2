local SceneManager = require("src.core.SceneManager")

local function makeGame()
    return {events = {emit = function() end}}
end

local function makeScene(name)
    return {
        name = name,
        enter = function(self, value) self.enteredWith = value end,
    }
end

local tests = {}

function tests.scene_switch_waits_until_diagonal_wipe_covers_screen()
    local manager = SceneManager(makeGame())
    manager:register("menu", function() return makeScene("menu") end)
    manager:register("playing", function() return makeScene("playing") end)
    manager:switch("menu")
    manager:switch("playing", 7)

    assert(manager.currentName == "menu")
    manager:update(0.29)
    assert(manager.currentName == "menu")
    manager:update(0.02)
    assert(manager.currentName == "playing")
    assert(manager.current.enteredWith == 7)
    assert(manager.transition ~= nil)
    manager:update(0.3)
    assert(manager.transition == nil)
end

return tests
