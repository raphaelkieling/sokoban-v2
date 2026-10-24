local LevelLoader = require("src.game.LevelLoader")
local Scene = require("src.core.Scene")
local Keymap = require("src.settings.Keymap")
local UI = require("src.ui.Theme")
local I18n = require("src.i18n.I18n")

local LevelSelect = Scene:extend()
local PAGE_SIZE = 10

function LevelSelect:init(game)
    Scene.init(self, "LevelSelect", game)
    self.levels = LevelLoader.listLevels()
    self.selected = 1
    self.page = 1
end

function LevelSelect:draw()
    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)
    local rowHeight = 39 * scale
    UI.setColor("text")
    UI.setMenuFont(44, width, height)
    love.graphics.printf(string.upper(I18n.t("levels.title")), 0, height * 0.12, width, "center")
    local pageCount = math.max(1, math.ceil(#self.levels / PAGE_SIZE))
    local firstVisible = (self.page - 1) * PAGE_SIZE + 1
    local lastVisible = math.min(#self.levels, firstVisible + PAGE_SIZE - 1)
    local visibleCount = math.max(0, lastVisible - firstVisible + 1)
    local availableHeight = height * 0.66
    local rowY = height * 0.24 + math.max(0,
        (availableHeight - visibleCount * rowHeight) / 2)
    local selectorWidth = math.min(width * 0.76, 620 * scale)
    for index = firstVisible, lastVisible do
        local level = self.levels[index]
        local label = level.name or string.format("lvl_%d.txt", level.number)
        local number = string.format("%02d", index)
        UI.drawMenuItem(number .. "   /   " .. label, index == self.selected,
            rowY + (index - firstVisible) * rowHeight, width, height, 27,
            selectorWidth, selectorWidth)

        if self.game.levelProgress:isCompleted(level.key or level.path) then
            local x = width / 2 + selectorWidth / 2 - 13 * scale
            UI.setColor("accent")
            love.graphics.circle("fill", x, rowY + (index - firstVisible) * rowHeight,
                3.5 * scale)
        end
    end
    UI.setColor("muted")
    UI.setMenuFont(21, width, height)
    love.graphics.printf(string.upper(I18n.t("levels.page", self.page, pageCount)),
        0, height * 0.90, width, "center")
    self:drawChildren(nil, self)
end

function LevelSelect:keypressed(key)
    if Keymap.matches("cancel", key) then
        self.game.audio:play("uiClick")
        self.game.scenes:switch("menu")
    elseif Keymap.matches("menuUp", key) then
        self.selected = (self.selected - 2) % #self.levels + 1
        self.page = math.floor((self.selected - 1) / PAGE_SIZE) + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("menuDown", key) then
        self.selected = self.selected % #self.levels + 1
        self.page = math.floor((self.selected - 1) / PAGE_SIZE) + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("menuPagePrevious", key) or Keymap.matches("menuPageNext", key) then
        local pageCount = math.max(1, math.ceil(#self.levels / PAGE_SIZE))
        local direction = Keymap.matches("menuPagePrevious", key) and -1 or 1
        self.page = (self.page - 1 + direction) % pageCount + 1
        self.selected = (self.page - 1) * PAGE_SIZE + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("confirm", key) then
        if self.levels[self.selected] then
            self.game.audio:play("uiClick")
            self.game.scenes:switch("playing", self.selected)
        end
    end
end

return LevelSelect
