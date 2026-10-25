local Keymap = require("src.settings.Keymap")
local Scene = require("src.core.Scene")
local UI = require("src.ui.Theme")
local GameConfig = require("src.settings.GameConfig")
local I18n = require("src.i18n.I18n")

local About = Scene:extend()
local REFERENCES = {
    {
        name = "LÖVE",
        detailKey = "credits.love_detail",
        source = "love2d.org",
    },
    {
        name = "32 Rogues",
        detailKey = "credits.rogues_detail",
        source = "sethbb.itch.io/32rogues",
    },
    {
        name = "Monogram",
        detailKey = "credits.monogram_detail",
        source = "datagoblin.itch.io/monogram",
    },
    {
        name = "Jersey 10 + Jacquard 24",
        detailKey = "credits.fonts_detail",
        source = "github.com/scfried/soft-type-jersey",
        source2 = "github.com/scfried/soft-type-jacquard",
    },
}

function About:init(game)
    Scene.init(self, "About", game)
    self.scrollOffset = 1
    self.visibleRows = #REFERENCES
end

function About:draw()
    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)
    UI.setColor("text")
    UI.setMenuFont(44, width, height)
    love.graphics.printf(I18n.t("credits.title"), 0, height * 0.08, width, "center")
    UI.setColor("muted")
    UI.setFont(18, width, height)
    love.graphics.printf(GameConfig.title:upper(), 0, height * 0.15, width, "center")

    UI.setColor("accent")
    UI.setMenuFont(24, width, height)
    love.graphics.printf(I18n.t("credits.references"),
        0, height * 0.21, width, "center")

    local listTop = height * 0.28
    local listBottom = height * 0.76
    local rowHeight = 78 * scale
    self.visibleRows = math.max(1, math.floor((listBottom - listTop) / rowHeight))
    local maxOffset = math.max(1, #REFERENCES - self.visibleRows + 1)
    self.scrollOffset = math.max(1, math.min(self.scrollOffset, maxOffset))
    local lastVisible = math.min(#REFERENCES, self.scrollOffset + self.visibleRows - 1)

    for index = self.scrollOffset, lastVisible do
        local reference = REFERENCES[index]
        local y = listTop + (index - self.scrollOffset) * rowHeight
        UI.setColor("text")
        UI.setMenuFont(24, width, height)
        love.graphics.printf(reference.name:upper(), 24 * scale, y,
            width - 48 * scale, "center")
        UI.setColor("muted")
        UI.setMenuFont(16, width, height)
        love.graphics.printf(I18n.t(reference.detailKey), 24 * scale, y + 24 * scale,
            width - 48 * scale, "center")
        UI.setMenuFont(15, width, height)
        love.graphics.printf(reference.source, 24 * scale, y + 44 * scale,
            width - 48 * scale, "center")
        if reference.source2 then
            love.graphics.printf(reference.source2, 24 * scale, y + 59 * scale,
                width - 48 * scale, "center")
        end
    end

    local hasMore = #REFERENCES > self.visibleRows
    UI.setColor("muted")
    UI.setFont(18, width, height)
    love.graphics.printf(I18n.t(hasMore and "credits.scroll" or "credits.back_hint"),
        0, height * 0.80, width, "center")
    UI.drawMenuItem(I18n.t("settings.back"), true, height * 0.89,
        width, height, 28, width * 0.35)
    self:drawChildren(nil, self)
end

function About:keypressed(key)
    if Keymap.matches("menuUp", key) then
        self.scrollOffset = math.max(1, self.scrollOffset - 1)
        self.game.audio:play("menuSelect")
    elseif Keymap.matches("menuDown", key) then
        self.scrollOffset = math.min(math.max(1, #REFERENCES - self.visibleRows + 1),
            self.scrollOffset + 1)
        self.game.audio:play("menuSelect")
    elseif Keymap.matches("cancel", key) or Keymap.matches("confirm", key) then
        self.game.audio:play("menuClick")
        self.game.scenes:switch("menu")
    end
end

return About
