local Scene = require("src.core.Scene")
local Keymap = require("src.settings.Keymap")
local LevelLoader = require("src.game.LevelLoader")
local UI = require("src.ui.Theme")
local I18n = require("src.i18n.I18n")

local AnalyticsScreen = Scene:extend()

function AnalyticsScreen:init(game)
	Scene.init(self, "Analytics", game)
	self.levels = LevelLoader.listLevels()
end

function AnalyticsScreen:draw()
	local width, height = love.graphics.getDimensions()
	local scale = UI.scale(width, height)
	local stats = self.game.analytics.stats
	local totalLevels = #self.levels
	local completedLevels = self.game.analytics:completedLevelCount(self.levels)
	local completion = totalLevels > 0
		and math.floor(completedLevels / totalLevels * 100 + 0.5) or 0

	UI.setColor("text")
	UI.setMenuFont(44, width, height)
	love.graphics.printf(string.upper(I18n.t("analytics.title")),
		0, height * 0.10, width, "center")

	local rows = {
		{I18n.t("analytics.sessions"), stats.sessions},
		{I18n.t("analytics.steps"), stats.steps},
		{I18n.t("analytics.undos"), stats.undos},
		{I18n.t("analytics.levels_started"), stats.levelsStarted},
		{I18n.t("analytics.levels_completed"), string.format("%d / %d", completedLevels, totalLevels)},
		{I18n.t("analytics.completion"), string.format("%d%%", completion)},
	}
	local rowY = height * 0.25
	local rowSpacing = height * 0.075
	local contentWidth = math.min(width * 0.78, 650 * scale)
	local contentX = (width - contentWidth) / 2
	local padding = 18 * scale
	local labelWidth = contentWidth * 0.68
	UI.setMenuFont(25, width, height)
	local font = love.graphics.getFont()
	for index, row in ipairs(rows) do
		local centerY = rowY + (index - 1) * rowSpacing
		local textY = centerY - font:getHeight() / 2
		UI.setColor("text")
		love.graphics.printf(string.upper(row[1]), contentX + padding, textY,
			labelWidth - padding, "left")
		love.graphics.printf(tostring(row[2]), contentX + labelWidth, textY,
			contentWidth - labelWidth - padding, "right")
		if index < #rows then
			UI.drawDivider(contentX, centerY + font:getHeight() / 2 + 4 * scale,
				contentWidth, math.max(1, scale))
		end
	end

	UI.drawMenuItem(I18n.t("analytics.back"), true, height * 0.87,
		width, height, 28, width * 0.38)
	self:drawChildren(nil, self)
end

function AnalyticsScreen:keypressed(key)
	if Keymap.matches("cancel", key) or Keymap.matches("confirm", key) then
		self.game.audio:play("uiClick")
		self.game.scenes:switch("menu")
	end
end

return AnalyticsScreen
