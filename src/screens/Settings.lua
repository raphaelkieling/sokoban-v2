local Scene = require("src.core.Scene")
local Keymap = require("src.settings.Keymap")
local UI = require("src.ui.Theme")
local I18n = require("src.i18n.I18n")

local Settings = Scene:extend()
local LANGUAGES = {"pt", "en", "es"}

function Settings:init(game)
    Scene.init(self, "Settings", game)
    self.selected = 1
end

function Settings:toggleFullscreen()
    local desired = not love.window.getFullscreen()
    local ok, success = pcall(love.window.setFullscreen, desired, "desktop")
    if ok and success ~= false then
        self.game.preferences:set("fullscreen", desired)
    end
end

function Settings:adjustVolume(direction)
    local volume = math.max(0, math.min(1,
        self.game.audio:getMusicVolume() + direction * 0.05))
    self.game.audio:setMusicVolume(volume)
    self.game.preferences:set("musicVolume", volume)
end

function Settings:toggleMuted()
    local muted = not self.game.audio:isMuted()
    self.game.audio:setMuted(muted)
    self.game.preferences:set("muted", muted)
end

function Settings:changeLanguage(direction)
    local current = self.game.preferences:get("language") or I18n.getLanguage()
    local index = 1
    for i, language in ipairs(LANGUAGES) do
        if language == current then index = i break end
    end
    index = (index - 1 + direction) % #LANGUAGES + 1
    local language = LANGUAGES[index]
    self.game.preferences:set("language", language)
    I18n.setLanguage(language)
end

function Settings:toggleSelected()
    if self.selected == 1 then
        self:toggleFullscreen()
    elseif self.selected == 2 then
        self:adjustVolume(1)
    elseif self.selected == 3 then
        self:toggleMuted()
    elseif self.selected == 4 then
        self:changeLanguage(1)
    else
        self.game.scenes:switch("menu")
    end
end

function Settings:adjustSelected(direction)
    if self.selected == 1 then
        self:toggleFullscreen()
    elseif self.selected == 2 then
        self:adjustVolume(direction)
    elseif self.selected == 3 then
        self:toggleMuted()
    elseif self.selected == 4 then
        self:changeLanguage(direction)
    end
end

function Settings:draw()
    local width, height = love.graphics.getDimensions()
    local scale = UI.scale(width, height)
    UI.setColor("text")
    UI.setMenuFont(46, width, height)
    love.graphics.printf(string.upper(I18n.t("settings.title")), 0,
        height * 0.12, width, "center")

    local volume = self.game.audio:getMusicVolume()
    local languageKey = "settings.language_" .. (self.game.preferences:get("language") or "pt")
	local options = {
		{I18n.t("settings.fullscreen"), I18n.t(love.window.getFullscreen()
			and "settings.on" or "settings.off")},
		{I18n.t("settings.music_volume"), string.format("%d%%",
			math.floor(volume * 100 + 0.5))},
		{I18n.t("settings.muted"), I18n.t(self.game.audio:isMuted()
			and "settings.on" or "settings.off")},
		{I18n.t("settings.language"), I18n.t(languageKey)},
		{I18n.t("settings.back"), ""},
    }
    local firstRowY = height * 0.37
    local rowSpacing = 48 * scale
    local selectorWidth = math.min(width * 0.76, 620 * scale)
	for index, option in ipairs(options) do
		UI.drawTwoColumnMenuItem(option[1], option[2], index == self.selected,
			firstRowY + (index - 1) * rowSpacing, width, height, 29, selectorWidth)
    end

    UI.setColor("muted")
    UI.setMenuFont(21, width, height)
    love.graphics.printf(string.upper(I18n.t("settings.help")), 0,
        height * 0.90, width, "center")
    self:drawChildren(nil, self)
end

function Settings:keypressed(key)
    if Keymap.matches("cancel", key) then
        self.game.audio:play("uiClick")
        self.game.scenes:switch("menu")
    elseif Keymap.matches("menuUp", key) then
        self.selected = (self.selected - 2) % 5 + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("menuDown", key) then
        self.selected = self.selected % 5 + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("menuPagePrevious", key) then
        self:adjustSelected(-1)
        self.game.audio:play("uiClick")
    elseif Keymap.matches("menuPageNext", key) then
        self:adjustSelected(1)
        self.game.audio:play("uiClick")
    elseif Keymap.matches("confirm", key) then
        self:toggleSelected()
        self.game.audio:play("uiClick")
    end
end

return Settings
