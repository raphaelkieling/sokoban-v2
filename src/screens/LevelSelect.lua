local LevelLoader = require("src.game.LevelLoader")
local Scene = require("src.core.Scene")
local Keymap = require("src.settings.Keymap")
local UI = require("src.ui.Theme")
local I18n = require("src.i18n.I18n")
local LevelPreview = require("src.ui.LevelPreview")

local LevelSelect = Scene:extend()
local PAGE_SIZE = 10
local PREVIEW_WIDTH, PREVIEW_HEIGHT = 480, 270

function LevelSelect:init(game)
    Scene.init(self, "LevelSelect", game)
    self.levels = LevelLoader.listLevels()
    self.selected = 1
    self.page = 1
    self.previewCanvas = nil
    self.previewKey = nil
    self.previewUnavailable = false
end

function LevelSelect:leave()
	if self.previewCanvas then
		self.previewCanvas:release()
		self.previewCanvas = nil
	end
end

function LevelSelect:preparePreview(level)
	local key = level.key or level.path .. "#" .. level.identifier
	if self.previewKey == key then return end
	self.previewKey = key
	self.previewUnavailable = false
	if self.previewCanvas then
		self.previewCanvas:release()
		self.previewCanvas = nil
	end

	local ok, board = pcall(LevelLoader.load, level.path, self.game.assets,
		self.game.events, level.identifier)
	if not ok then
		self.previewUnavailable = true
		return
	end

	local canvas = love.graphics.newCanvas(PREVIEW_WIDTH, PREVIEW_HEIGHT)
	canvas:setFilter("nearest", "nearest")
	local previousCanvas = love.graphics.getCanvas()
	love.graphics.push("all")
	love.graphics.setCanvas(canvas)
	love.graphics.origin()
	love.graphics.clear(0.045, 0.04, 0.032, 1)
	love.graphics.setColor(1, 1, 1, 1)
	local mapWidth = board.mapWorldWidth or board.width * 64
	local mapHeight = board.mapWorldHeight or board.height * 64
	local x, y, mapScale = LevelPreview.fit(PREVIEW_WIDTH, PREVIEW_HEIGHT,
		mapWidth, mapHeight, 8)
	love.graphics.translate(x, y)
	love.graphics.scale(mapScale)
	board:draw()
	love.graphics.setCanvas(previousCanvas)
	love.graphics.pop()
	self.previewCanvas = canvas
end

function LevelSelect:drawPreview(width, height, scale)
	local level = self.levels[self.selected]
	if not level then return end
	local unlocked = self.game.levelProgress:isUnlocked(self.levels, self.selected)

	local panelWidth = math.min(width * 0.44, 560 * scale)
	local panelHeight = panelWidth * PREVIEW_HEIGHT / PREVIEW_WIDTH + 24 * scale
	local panelX = width * 0.53
	local panelY = height * 0.31
	UI.drawPanel(panelX, panelY, panelWidth, panelHeight)
	if not unlocked then
		if self.previewCanvas then
			self.previewCanvas:release()
			self.previewCanvas = nil
		end
		self.previewKey = nil
		self.previewUnavailable = false
		UI.setColor("muted")
		UI.setMenuFont(20, width, height)
		local font = love.graphics.getFont()
		love.graphics.printf(I18n.t("levels.locked"), panelX + 12 * scale,
			panelY + (panelHeight - font:getHeight()) / 2,
			panelWidth - 24 * scale, "center")
		return
	end
	self:preparePreview(level)
	if not self.previewCanvas then
		if self.previewUnavailable then
			UI.setColor("muted")
			UI.setMenuFont(18, width, height)
			local font = love.graphics.getFont()
			love.graphics.printf(I18n.t("levels.preview_unavailable"), panelX + 12 * scale,
				panelY + (panelHeight - font:getHeight()) / 2,
				panelWidth - 24 * scale, "center")
		end
		return
	end

	local availableWidth = panelWidth - 24 * scale
	local availableHeight = panelHeight - 24 * scale
	local drawScale = math.min(availableWidth / PREVIEW_WIDTH,
		availableHeight / PREVIEW_HEIGHT)
	local drawWidth, drawHeight = PREVIEW_WIDTH * drawScale, PREVIEW_HEIGHT * drawScale
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(self.previewCanvas,
		panelX + (panelWidth - drawWidth) / 2,
		panelY + (panelHeight - drawHeight) / 2,
		0, drawScale, drawScale)
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
    local selectorWidth = math.min(width * 0.48, 590 * scale)
    local selectorCenter = width * 0.26
    for index = firstVisible, lastVisible do
        local level = self.levels[index]
        local label = level.name or string.format("lvl_%d.txt", level.number)
		local unlocked = self.game.levelProgress:isUnlocked(self.levels, index)
		local status = unlocked and "" or I18n.t("levels.locked")
		UI.drawTwoColumnMenuItem(label, status, index == self.selected,
			rowY + (index - firstVisible) * rowHeight, width, height, 27,
			selectorWidth, selectorCenter, not unlocked)

        if self.game.levelProgress:isCompleted(level.key or level.path) then
            local x = selectorCenter + selectorWidth / 2 - 13 * scale
            UI.setColor("accent")
            love.graphics.circle("fill", x, rowY + (index - firstVisible) * rowHeight,
                3.5 * scale)
        end
    end
    self:drawPreview(width, height, scale)
    UI.setColor("muted")
    UI.setMenuFont(21, width, height)
    love.graphics.printf(string.upper(I18n.t("levels.page", self.page, pageCount)),
        0, height * 0.90, width, "center")
    self:drawChildren(nil, self)
end

function LevelSelect:keypressed(key)
    if Keymap.matches("cancel", key) then
        self.game.audio:play("menuClick")
        self.game.scenes:switch("menu")
    elseif Keymap.matches("menuUp", key) then
        self.selected = (self.selected - 2) % #self.levels + 1
        self.page = math.floor((self.selected - 1) / PAGE_SIZE) + 1
        self.game.audio:play("menuSelect")
    elseif Keymap.matches("menuDown", key) then
        self.selected = self.selected % #self.levels + 1
        self.page = math.floor((self.selected - 1) / PAGE_SIZE) + 1
        self.game.audio:play("menuSelect")
    elseif Keymap.matches("menuPagePrevious", key) or Keymap.matches("menuPageNext", key) then
        local pageCount = math.max(1, math.ceil(#self.levels / PAGE_SIZE))
        local direction = Keymap.matches("menuPagePrevious", key) and -1 or 1
        self.page = (self.page - 1 + direction) % pageCount + 1
        self.selected = (self.page - 1) * PAGE_SIZE + 1
        self.game.audio:play("menuSelect")
    elseif Keymap.matches("confirm", key) then
		if self.levels[self.selected]
			and self.game.levelProgress:isUnlocked(self.levels, self.selected) then
            self.game.audio:play("menuClick")
            self.game.scenes:switch("playing", self.selected)
        end
    end
end

return LevelSelect
