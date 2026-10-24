local Node = require("src.core.Node")
local BuildConfig = require("src.settings.BuildConfig")
local UI = require("src.ui.Theme")
local I18n = require("src.i18n.I18n")

local PlayingHud = Node:extend()

function PlayingHud:init(scene)
	Node.init(self, "PlayingHud")
	self.scene = scene
	self.drawSpace = "screen"
end

function PlayingHud:draw()
	local scene = self.scene
	if not scene.board then return end
	local paused = scene.states:is("paused")
	local completed = scene.states:is("completed")
	if not paused and not completed then self:drawLevelTimeline() end
	if paused or completed then self:drawPause(completed) end
	self:drawDevelopmentFilename()
	scene.mobileControls:draw()
	self:drawChildren("screen", scene)
end

function PlayingHud:drawDevelopmentFilename()
	local scene = self.scene
	if not BuildConfig.developmentMode or not scene.levelPath then return end
	local width, height = love.graphics.getDimensions()
	local scale = UI.scale(width, height)
	local filename = scene.levelPath:match("([^/]+)$") or scene.levelPath
	UI.setColor("muted", 0.8)
	UI.setFont(16, width, height)
	love.graphics.printf(filename, 16 * scale, height - 34 * scale,
		width - 32 * scale, "right")
end

function PlayingHud:drawLevelTimeline()
	local scene = self.scene
	local count = #scene.levels
	if count == 0 then return end

	local width, height = love.graphics.getDimensions()
	local availableWidth = math.max(0, width - 64)
	local spacing = count > 1 and math.min(28, availableWidth / (count - 1)) or 0
	local firstX = (width - spacing * (count - 1)) / 2
	local y = height - 26
	local radius = math.min(6, spacing > 0 and spacing * 0.24 or 6)

	love.graphics.push("all")
	if count > 1 then
		love.graphics.setColor(0.43, 0.40, 0.34, 0.85)
		love.graphics.setLineWidth(3)
		love.graphics.line(firstX, y, firstX + spacing * (count - 1), y)
	end

	for index, level in ipairs(scene.levels) do
		local x = firstX + spacing * (index - 1)
		love.graphics.setColor(0, 0, 0, 1)
		love.graphics.circle("fill", x, y, radius + 2)
		if scene.game.completedLevels[level.key or level.path] then
			UI.setColor("accent")
			love.graphics.circle("fill", x, y, radius)
		else
			local alpha = index == scene.levelIndex and 1 or 0.58
			UI.setColor("text", alpha)
			love.graphics.setLineWidth(2)
			love.graphics.circle("line", x, y, radius)
		end
	end
	love.graphics.pop()
end

function PlayingHud:drawPause(completed)
	local scene = self.scene
	local width, height = love.graphics.getDimensions()
	local scale = UI.scale(width, height)
	love.graphics.setColor(0, 0, 0, 0.78)
	love.graphics.rectangle("fill", 0, 0, width, height)
	local options = scene:getPauseOptions(completed)
	local rowHeight = 46 * scale
	local headerHeight = completed and 48 * scale or 0
	local listHeight = #options * rowHeight
	local firstRowY = (height - listHeight - headerHeight) / 2 + headerHeight
	if completed then
		UI.setColor("text")
		UI.setMenuFont(34, width, height)
		love.graphics.printf(string.upper(I18n.t("pause.all_complete")), 0,
			firstRowY - headerHeight - 8 * scale,
			width, "center")
	end

	for index, label in ipairs(options) do
		local y = firstRowY + (index - 1) * rowHeight
		UI.drawMenuItem(label, index == scene.pauseSelection, y,
			width, height, 29, width * 0.55)
	end
end

return PlayingHud
