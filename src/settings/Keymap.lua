local Keymap = {
    bindings = {
        moveUp = {"w", "up"},
        moveDown = {"s", "down"},
        moveLeft = {"a", "left"},
        moveRight = {"d", "right"},
        switchPlayer = {"j"},
        undo = {"k"},
        toggleMapView = {"l"},
        pause = {"escape"},
        confirm = {"return", "kpenter"},
        cancel = {"escape"},
        menuUp = {"up", "w"},
        menuDown = {"down", "s"},
        menuPagePrevious = {"left", "a"},
        menuPageNext = {"right", "d"},
    },

    labels = {
        move = "WASD/Arrows",
        switchPlayer = "J",
        undo = "K",
        pause = "Esc",
    },
}

function Keymap.matches(action, key)
    for _, binding in ipairs(Keymap.bindings[action] or {}) do
        if binding == key then return true end
    end
    return false
end

function Keymap.direction(key)
    local directions = {
        {action = "moveUp", x = 0, y = -1},
        {action = "moveDown", x = 0, y = 1},
        {action = "moveLeft", x = -1, y = 0},
        {action = "moveRight", x = 1, y = 0},
    }
    for _, direction in ipairs(directions) do
        if Keymap.matches(direction.action, key) then
            return {x = direction.x, y = direction.y}
        end
    end
end

return Keymap
