local cameraLib = require("vendor.hump.camera")
local Scene = require("src.core.Scene")
local StateMachine = require("src.core.StateMachine")
local ActionHistory = require("src.game.ActionHistory")
local PlayerSelector = require("src.game.PlayerSelector")
local LevelLoader = require("src.game.LevelLoader")
local TriggerRegistry = require("src.game.TriggerRegistry")
local Keymap = require("src.settings.Keymap")
local UndoHistoryOverlay = require("src.dev.UndoHistoryOverlay")
local PlayingHud = require("src.screens.PlayingHud")
local DiagonalWipe = require("src.ui.DiagonalWipe")
local I18n = require("src.i18n.I18n")
local PlayingStates = {
	entering = require("src.screens.playing_states.Entering"),
	playing = require("src.screens.playing_states.Playing"),
	paused = require("src.screens.playing_states.Paused"),
	transitioning = require("src.screens.playing_states.LevelTransition"),
	completed = require("src.screens.playing_states.Completed"),
}

local PlayingScene = Scene:extend()
local FOLLOW_ZOOM = 1.8
local CAMERA_SMOOTHING = 9
local MOVE_REPEAT_DELAY = 0.3
local MOVE_REPEAT_INTERVAL = 0.12
local UNDO_REPEAT_INTERVAL = 0.6

local function boxesOnTargets(board)
	local boxes = {}
	for _, box in ipairs(board.boxes) do
		local transform = box:getComponent("Transform")
		local cell = board:getCell(transform.gridX, transform.gridY)
		if cell and cell.target then boxes[box] = true end
	end
	return boxes
end

local function hasBoxArrivedOnTarget(board, previousBoxesOnTargets)
	for _, box in ipairs(board.boxes) do
		if not previousBoxesOnTargets[box] then
			local transform = box:getComponent("Transform")
			local cell = board:getCell(transform.gridX, transform.gridY)
			if cell and cell.target then return true end
		end
	end
	return false
end

function PlayingScene:init(game)
	Scene.init(self, "PlayingScene", game)
	self.mobileControls = game.mobileControls
	self.camera = cameraLib(0, 0, 1)
	self.history = ActionHistory()
	self.playerSelector = PlayerSelector()
	self.componentStateSubscription = self.game.events:on("component.state_changed", function(payload)
		if payload.cause ~= "flame" then return end
		local object = self.board and self.board.objects[payload.objectIndex]
		if object and payload.component then
			self.history:appendToLatest({{
				object = object,
				component = payload.component,
				state = payload.previousState,
			}})
		end
	end)
	self.levelIndex = 1
	self.transition = nil
	self.cameraIntro = nil
	self.heldMoveKey = nil
	self.moveRepeatTimer = 0
	self.heldUndoKey = nil
	self.undoRepeatTimer = 0
	self.pauseSelection = 1
	self.activeMessage = nil
	self.activeMessageTime = 0
	self.activeMessageArgs = nil
	self.activatedTriggers = {}
	self.states = StateMachine(self, PlayingStates)
	self.hud = self:addChild(PlayingHud(self))
end

function PlayingScene:enter(levelIndex)
    self.levels = LevelLoader.listLevels()
    self.levelIndex = levelIndex or 1
    self.cameraMode = "map"
    self.mobileControls:resetTouches()
    self:loadLevel()
    self.states:change("entering")
end

function PlayingScene:leave()
	self:clearHeldMovement()
	self.mobileControls:resetTouches()
	self.game.events:off(self.componentStateSubscription)
end

function PlayingScene:loadLevel()
    local level = assert(self.levels[self.levelIndex], "level index out of range")
    self.heldMoveKey = nil
    self.pendingDirection = nil
    self.mobileMoveDirection = nil
    self.moveRepeatTimer = 0
    self.levelPath = level.key
	self.activeMessage = nil
	self.activeMessageTime = 0
	self.activeMessageArgs = nil
	self.activatedTriggers = {}
    if self.board then self:removeChild(self.board) end
    self.board = LevelLoader.load(level.path, self.game.assets, self.game.events, level.identifier)
    self.board.drawSpace = "world"
    self:addChild(self.board)
    if self.game.console then
        self.game.console:applyToggles({game = self.game, scene = self, board = self.board})
    end
    self.game.events:emit("level.started", {
		level = level.name,
		path = level.key,
		index = self.levelIndex,
		players = #self.board.players,
	})
    self.history:clear()
	self.playerSelector:reset()
    self:snapCameraToTarget()
end

function PlayingScene:beginCameraIntro()
    local _, _, targetZoom = self:cameraTarget()
    local startZoom = targetZoom * 1.12
    self.camera.scale = startZoom
    self.cameraIntro = {
        elapsed = 0,
        duration = 0.5,
        startZoom = startZoom,
        targetZoom = targetZoom,
    }
end

function PlayingScene:mapCameraTarget()
    if not self.board then return 0, 0, 1 end
    local width, height = love.graphics.getDimensions()
	local worldWidth = self.board.mapWorldWidth or self.board.width * 64
	local worldHeight = self.board.mapWorldHeight or self.board.height * 64
	local zoom = math.min(width / worldWidth, height / worldHeight)
	return worldWidth / 2, worldHeight / 2, math.max(0.25, zoom)
end

function PlayingScene:cameraTarget()
    if self.cameraMode == "map" then
        return self:mapCameraTarget()
    end
    local player = self:currentPlayer()
    if player then
        local transform = player:getComponent("Transform")
        return transform.x, transform.y, FOLLOW_ZOOM
    end
    return self:mapCameraTarget()
end

function PlayingScene:snapCameraToTarget()
    local x, y, zoom = self:cameraTarget()
    self.camera:lookAt(x, y)
    self.camera.scale = zoom
end

function PlayingScene:currentPlayer()
    if #self.board.players == 0 then return nil end
    return self.board.players[self.playerSelector.activeIndex]
end

function PlayingScene:loadNextLevel()
	self.levelIndex = self.levelIndex + 1
	self:loadLevel()
end

function PlayingScene:restartLevel()
	self.pendingTransitionLevelIndex = self.levelIndex
	self.states:change("transitioning")
end

function PlayingScene:jumpToLevel(index, levels)
	self.levels = levels or self.levels
	self.levelIndex = index
	self.transition = nil
	self:loadLevel()
	self.states:change("entering")
end

function PlayingScene:completeLevel()
    self.game.levelProgress:markCompleted(self.levelPath)
	self.game.events:emit("level.completed", {level = self.levelPath, index = self.levelIndex})
    if self.levelIndex < #self.levels then
        self.states:change("transitioning")
    else
        self.states:change("completed")
    end
end

function PlayingScene:update(dt)
	self.states:update(dt)
	if self.activeMessage and self.states:is("playing") then
		self.activeMessageTime = self.activeMessageTime - dt
		if self.activeMessageTime <= 0 then
			self.activeMessage = nil
			self.activeMessageArgs = nil
		end
	end
	self:updateChildren(dt)
	if self.board then
		self:emitPlayerSwitch(self.playerSelector:ensureLivingPlayer(self.board.players))
	end
end

function PlayingScene:showMessage(messageKey, duration, ...)
	self.activeMessage = messageKey
	self.activeMessageTime = duration or 8
	self.activeMessageArgs = {...}
end

function PlayingScene:updatePlaying(dt)
	self:updateCamera(dt)
	self:updateBufferedMovement()
	if not self.states:is("playing") then return end
    self:updateHeldMovement(dt)
	if not self.states:is("playing") then return end
    self:updateHeldUndo(dt)
	if self.states:is("playing") and self.board and not self.board:isMoving()
		and self.board:allTargetsCovered() then
        self:completeLevel()
    end
end

function PlayingScene:updateCamera(dt)
	local targetX, targetY, targetZoom = self:cameraTarget()
	local smooth = 1 - math.exp(-CAMERA_SMOOTHING * dt)
	self.camera.x = self.camera.x + (targetX - self.camera.x) * smooth
	self.camera.y = self.camera.y + (targetY - self.camera.y) * smooth
	if self.cameraIntro then
		local intro = self.cameraIntro
		intro.elapsed = intro.elapsed + dt
		local progress = math.min(intro.elapsed / intro.duration, 1)
		local eased = 1 - (1 - progress) ^ 3
		self.camera.scale = intro.startZoom + (intro.targetZoom - intro.startZoom) * eased
		if progress >= 1 then self.cameraIntro = nil end
	else
		self.camera.scale = self.camera.scale + (targetZoom - self.camera.scale) * smooth
	end
end

function PlayingScene:movePlayer(direction)
	local player = self:currentPlayer()
	if not player then return false end
	local class = player:getComponent("CharacterClass")
	local previousBoxesOnTargets = boxesOnTargets(self.board)
	local moved, changes = player:getComponent("CharacterMovement"):move(
		self.board, direction, self.history)
	self.game.events:emit("player.moved", {
		level = self.levelPath,
		playerIndex = self.playerSelector.activeIndex,
		characterClass = class.id,
		directionX = direction.x,
		directionY = direction.y,
		moved = moved,
	})
	self.game.audio:play(moved and "move" or "invalidMovement")
	if moved and hasBoxArrivedOnTarget(self.board, previousBoxesOnTargets) then
		self.game.audio:play("target")
	end
	if moved then self:activateEnteredTriggers(changes) end
	return moved
end

function PlayingScene:activateEnteredTriggers(changes)
	for _, change in ipairs(changes or {}) do
		local movedPlayer = change.object
		if movedPlayer:hasComponent("Player") then
			for _, trigger in ipairs(self.board:getTriggersAt(change.toX, change.toY)) do
				TriggerRegistry.activate(self, trigger, movedPlayer)
			end
		end
	end
end

function PlayingScene:undo()
	local undone = self.history:undo()
	if undone then self.game.audio:play("undo") end
	self.game.events:emit("player.undo", {level = self.levelPath, undone = undone})
	return undone
end

function PlayingScene:selectNextPlayer()
	self:emitPlayerSwitch(self.playerSelector:selectNext(self.board.players))
end

function PlayingScene:emitPlayerSwitch(change)
	if change then
		self.game.events:emit("player.switched", change)
	end
end

function PlayingScene:updateBufferedMovement()
	if not self.pendingDirection or self.states:is("transitioning") or self.board:isMoving() then return end
	local direction = self.pendingDirection
	self.pendingDirection = nil
	self:movePlayer(direction)
	self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function PlayingScene:updateHeldMovement(dt)
	if self.playerSelector:isHeld() then return end
	if self.heldMoveKey then
		if not love.keyboard.isDown(self.heldMoveKey) then
			self.heldMoveKey = nil
			self.moveRepeatTimer = 0
		else
			self:updateKeyboardMovement(dt)
			return
		end
	end
	self:updateMobileMovement(dt)
end

function PlayingScene:updateKeyboardMovement(dt)
	self.moveRepeatTimer = self.moveRepeatTimer - dt
	if self.moveRepeatTimer > 0 or self.states:is("transitioning") or self.board:isMoving() then return end

    local direction = Keymap.direction(self.heldMoveKey)
	if direction then self:movePlayer(direction) end
	self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function PlayingScene:updateMobileMovement(dt)
	local direction = self.mobileControls:getDirection()
	if not direction then
		self.mobileMoveDirection = nil
		self.moveRepeatTimer = 0
		return
	end
	local directionKey = direction.x .. ":" .. direction.y
	if directionKey ~= self.mobileMoveDirection then
		self.mobileMoveDirection = directionKey
		self.moveRepeatTimer = MOVE_REPEAT_DELAY
		if not self.states:is("transitioning") and not self.board:isMoving() then
			self:movePlayer(direction)
		elseif self.board:isMoving() and not self.states:is("transitioning") then
			self.pendingDirection = direction
		end
		return
	end
	self.moveRepeatTimer = self.moveRepeatTimer - dt
	if self.moveRepeatTimer > 0 or self.states:is("transitioning") or self.board:isMoving() then return end
	self:movePlayer(direction)
	self.moveRepeatTimer = MOVE_REPEAT_INTERVAL
end

function PlayingScene:updateHeldUndo(dt)
	if not self.heldUndoKey then return end
	if not love.keyboard.isDown(self.heldUndoKey) then
		self.heldUndoKey = nil
		self.undoRepeatTimer = 0
		return
	end

	if #self.history.actions == 0 then
		self.heldUndoKey = nil
		self.undoRepeatTimer = 0
		return
	end

	self.undoRepeatTimer = self.undoRepeatTimer - dt
	if self.undoRepeatTimer > 0 or self.board:isMoving() then return end

	if not self:undo() then
		self.heldUndoKey = nil
		self.undoRepeatTimer = 0
		return
	end
	self.undoRepeatTimer = UNDO_REPEAT_INTERVAL
end

function PlayingScene:clearHeldMovement()
    self.heldMoveKey = nil
	self.playerSelector:cancel()
    self.moveRepeatTimer = 0
	self.pendingDirection = nil
	self.mobileMoveDirection = nil
	self.heldUndoKey = nil
	self.undoRepeatTimer = 0
end

function PlayingScene:draw()
    if not self.board then return end
    self.camera:attach()
    self:drawChildren("world", self)
    local undoPaths
    if self.board.debugShowUndoHistory then
        undoPaths = UndoHistoryOverlay.drawWorld(self.board, self.history.actions)
    end
    self.camera:detach()

    self:drawChildren("screen", self)
    if undoPaths then UndoHistoryOverlay.drawLegend(undoPaths) end
    if self.transition then
        local progress = self.transition.elapsed / self.transition.duration
        local coverage = progress <= 0.5 and progress * 2 or (1 - progress) * 2
        DiagonalWipe.draw(coverage)
    end
end

function PlayingScene:mobileAction(action)
	if self.states:is("paused") or self.states:is("completed") then
		self.states:dispatch("mobileAction", action)
		return
	end
	if not self.states:is("playing") then return end
	if action == "b" then
		if not self.board:isMoving() then self:undo() end
		return
	end
	self.game.audio:play("uiClick")
	if action == "a" then
		if not self.board:isMoving() and #self.board.players > 0 then
			self:selectNextPlayer()
		end
	end
end

function PlayingScene:touchpressed(id, x, y)
	local action = self.mobileControls:touchpressed(id, x, y)
	if action then self:mobileAction(action) end
end

function PlayingScene:touchmoved(id, x, y)
	self.mobileControls:touchmoved(id, x, y)
end

function PlayingScene:touchreleased(id)
	self.mobileControls:touchreleased(id)
end

function PlayingScene:getPauseOptions(completed)
    if completed == nil then completed = self.states:is("completed") end
    if completed then
        return {I18n.t("pause.replay"), I18n.t("pause.level_select"),
            I18n.t("pause.main_menu"), I18n.t("pause.quit")}
    end
    return {I18n.t("pause.resume"), I18n.t("pause.restart"),
        I18n.t("pause.level_select"), I18n.t("pause.main_menu"), I18n.t("pause.quit")}
end

function PlayingScene:choosePauseOption(completed)
    if completed then
        if self.pauseSelection == 1 then
            self:restartLevel()
        elseif self.pauseSelection == 2 then
            self.game.scenes:switch("levels")
        elseif self.pauseSelection == 3 then
            self.game.scenes:switch("menu")
        else
            love.event.quit()
        end
        return
    end
    if self.pauseSelection == 1 then
        self.states:change("playing")
    elseif self.pauseSelection == 2 then
        self:restartLevel()
    elseif self.pauseSelection == 3 then
        self.game.scenes:switch("levels")
    elseif self.pauseSelection == 4 then
        self.game.scenes:switch("menu")
    else
        love.event.quit()
    end
end

function PlayingScene:handlePauseKey(key, completed)
    local optionCount = #self:getPauseOptions(completed)
    if Keymap.matches("menuUp", key) then
        self.pauseSelection = (self.pauseSelection - 2) % optionCount + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("menuDown", key) then
        self.pauseSelection = self.pauseSelection % optionCount + 1
        self.game.audio:play("uiClick")
    elseif Keymap.matches("confirm", key) then
        self.game.audio:play("uiClick")
        self:choosePauseOption(completed)
    elseif Keymap.matches("cancel", key) then
        self.game.audio:play("uiClick")
        if completed then self.game.scenes:switch("levels")
        else self.states:change("playing") end
    end
end

function PlayingScene:handlePauseAction(action, completed)
	self.game.audio:play("uiClick")
	if action == "a" then
		self:choosePauseOption(completed)
	elseif action == "b" then
		if completed then self.game.scenes:switch("levels")
		else self.states:change("playing") end
	end
end

function PlayingScene:handleCameraKey(key)
    if not Keymap.matches("toggleMapView", key) then return false end
    self.cameraIntro = nil
    self.cameraMode = self.cameraMode == "map" and "follow" or "map"
    return true
end

function PlayingScene:handlePlayingKey(key)
    if Keymap.matches("pause", key) then
		self:clearHeldMovement()
        self.game.audio:play("uiClick")
        self.states:change("paused")
        return
    end
    if self:handleCameraKey(key) then return end
    if Keymap.matches("switchPlayer", key) then
		if self.playerSelector:isHeld() then return end
        if not self.board:isMoving() and not self.states:is("transitioning") then
			self.heldMoveKey = nil
			self.pendingDirection = nil
			self.playerSelector:begin()
		end
		return
	end
    local direction = Keymap.direction(key)
    if direction then
		if self.playerSelector:isHeld() then
			self:emitPlayerSwitch(self.playerSelector:selectInDirection(self.board.players, direction))
			return
		end
        self.heldMoveKey = key
        self.moveRepeatTimer = MOVE_REPEAT_DELAY
        if self.states:is("transitioning") then return end
        if self.board:isMoving() then
			self.pendingDirection = direction
		else
			self.pendingDirection = nil
			self:movePlayer(direction)
        end
        return
    end
    if self.board:isMoving() or self.states:is("transitioning") then return end
    if Keymap.matches("undo", key) then
		if self.heldUndoKey ~= key then
			self.heldUndoKey = key
			self.undoRepeatTimer = UNDO_REPEAT_INTERVAL
			self:undo()
		end
    end
end

function PlayingScene:keypressed(key)
	self.states:dispatch("keypressed", key)
end

function PlayingScene:keyreleased(key)
	if not Keymap.matches("switchPlayer", key) or not self.playerSelector:isHeld() then return end
	if not self.board:isMoving() and self.states:is("playing") then
		self:emitPlayerSwitch(self.playerSelector:finish(self.board.players))
	else
		self.playerSelector:cancel()
	end
end

return PlayingScene
