package.path = "./?.lua;./?/init.lua;" .. package.path

local suites = {
    {name = "character_movement", tests = require("tests.character_movement")},
    {name = "board_win_condition", tests = require("tests.board_win_condition")},
    {name = "target_component", tests = require("tests.target_component")},
    {name = "bonfire_component", tests = require("tests.bonfire_component")},
    {name = "level_loader", tests = require("tests.level_loader")},
    {name = "triggers", tests = require("tests.triggers")},
    {name = "level_progress", tests = require("tests.level_progress")},
    {name = "console_commands", tests = require("tests.console_commands")},
    {name = "audio_manager", tests = require("tests.audio_manager")},
    {name = "scene_manager", tests = require("tests.scene_manager")},
    {name = "preferences", tests = require("tests.preferences")},
    {name = "i18n", tests = require("tests.i18n")},
    {name = "settings_screen", tests = require("tests.settings_screen")},
}
local passed, failed = 0, 0

for _, suite in ipairs(suites) do
    local names = {}
    for name in pairs(suite.tests) do
        names[#names + 1] = name
    end
    table.sort(names)
    for _, name in ipairs(names) do
        local ok, errorMessage = pcall(suite.tests[name])
        if ok then
            passed = passed + 1
            print("PASS " .. suite.name .. "." .. name)
        else
            failed = failed + 1
            io.stderr:write("FAIL " .. suite.name .. "." .. name .. ": " .. tostring(errorMessage) .. "\n")
        end
    end
end

print(string.format("\n%d tests passed, %d failed", passed, failed))
if failed > 0 then
    os.exit(1)
end
