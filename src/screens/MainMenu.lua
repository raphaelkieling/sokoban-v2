local Scene = require("src.core.Scene")
local Keymap = require("src.settings.Keymap")
local UI = require("src.ui.Theme")
local GameConfig = require("src.settings.GameConfig")
local I18n = require("src.i18n.I18n")

local MainMenu = Scene:extend()

function MainMenu:init(game)
    Scene.init(self, "MainMenu", game)
    self.selected = 1
    self.options = {"menu.play", "menu.settings", "menu.analytics", "menu.credits", "menu.quit"}
end

function MainMenu:draw()
    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)
    UI.setLogoFont(116, width, height)
    love.graphics.setColor(0, 0, 0, 0.45)
    love.graphics.printf(GameConfig.title, 2 * scale, height * 0.17 + 4 * scale,
        width, "center")
    UI.setColor("accent")
    UI.setLogoFont(116, width, height)
    love.graphics.printf(GameConfig.title, 0, height * 0.17, width, "center")

    local rowY = height * 0.47
    local rowSpacing = 38 * scale
    for index, label in ipairs(self.options) do
        UI.drawMenuItem(I18n.t(label), index == self.selected,
            rowY + (index - 1) * rowSpacing, width, height, 32, width * 0.54)
    end
    self:drawChildren(nil, self)
end

function MainMenu:keypressed(key)
    if Keymap.matches("menuUp", key) or Keymap.matches("menuDown", key) then
        if Keymap.matches("menuUp", key) then
            self.selected = (self.selected - 2) % #self.options + 1
        else
            self.selected = self.selected % #self.options + 1
        end
        self.game.audio:play("uiClick")
    elseif Keymap.matches("confirm", key) then
        self.game.audio:play("uiClick")
        if self.selected == 1 then
            self.game.scenes:switch("levels")
        elseif self.selected == 2 then
            self.game.scenes:switch("settings")
        elseif self.selected == 3 then
            self.game.scenes:switch("analytics")
        elseif self.selected == 4 then
            self.game.scenes:switch("about")
        else
            love.event.quit()
        end
    end
end

return MainMenu
