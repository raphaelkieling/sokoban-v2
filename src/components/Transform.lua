local Component = require("src.core.Component")

local Transform = Component:extend()
Transform.componentName = "Transform"

function Transform:init(gridX, gridY, cellSize, layer)
    Component.init(self)
    self.gridX = gridX
    self.gridY = gridY
    self.cellSize = cellSize or 64
    self.layer = layer or 0
    self.x = (gridX + 0.5) * self.cellSize
    self.y = (gridY + 0.5) * self.cellSize
    self.tween = nil
    self.landingSquash = nil
end

function Transform:isMoving()
    return self.tween ~= nil
end

function Transform:moveTo(gridX, gridY, pushed)
    local dx, dy = gridX - self.gridX, gridY - self.gridY
    if dx == 0 and dy == 0 then
        return false
    end
	self.landingSquash = nil

    local distance = math.max(math.abs(dx), math.abs(dy))
    self.tween = {
        startX = self.x,
        startY = self.y,
        targetX = (gridX + 0.5) * self.cellSize,
        targetY = (gridY + 0.5) * self.cellSize,
        elapsed = 0,
        duration = math.min(math.max(distance, 1) * 0.12, 0.36),
        pushed = pushed == true,
    }
    self.gridX, self.gridY = gridX, gridY
    return true
end

function Transform:restore(snapshot)
    local dx, dy = snapshot.gridX - self.gridX, snapshot.gridY - self.gridY
	self.landingSquash = nil
    local distance = math.max(math.abs(dx), math.abs(dy))
    self.tween = {
        startX = self.x,
        startY = self.y,
        targetX = snapshot.x,
        targetY = snapshot.y,
        elapsed = 0,
        duration = math.min(math.max(distance, 1) * 0.12, 0.36),
        pushed = false,
    }
    self.gridX, self.gridY = snapshot.gridX, snapshot.gridY
end

function Transform:visualScale()
	local tween = self.tween
	if tween then
		local progress = math.min(tween.elapsed / tween.duration, 1)
		local stretch = math.sin(progress * math.pi) * (tween.pushed and 0.075 or 0.035)
		if math.abs(tween.targetX - tween.startX) >= math.abs(tween.targetY - tween.startY) then
			return 1 + stretch, 1 - stretch * 0.55
		end
		return 1 - stretch * 0.55, 1 + stretch
	end
	local squash = self.landingSquash
	if not squash then return 1, 1 end
	local progress = math.min(squash.elapsed / squash.duration, 1)
	local amount = (1 - progress) * squash.amount
	if math.abs(squash.dx) >= math.abs(squash.dy) then
		return 1 + amount, 1 - amount * 0.65
	end
	return 1 - amount * 0.65, 1 + amount
end

function Transform:update(dt)
    local tween = self.tween
    if self.landingSquash then
		self.landingSquash.elapsed = self.landingSquash.elapsed + dt
		if self.landingSquash.elapsed >= self.landingSquash.duration then
			self.landingSquash = nil
		end
	end
	if not tween then return end

    tween.elapsed = tween.elapsed + dt
    local progress = math.min(tween.elapsed / tween.duration, 1)
    local eased = progress * progress * (3 - 2 * progress)
    self.x = tween.startX + (tween.targetX - tween.startX) * eased
    self.y = tween.startY + (tween.targetY - tween.startY) * eased
    if progress >= 1 then
        self.x, self.y = tween.targetX, tween.targetY
        self.tween = nil
		self.landingSquash = {
			elapsed = 0,
			duration = 0.14,
			amount = tween.pushed and 0.14 or 0.07,
			dx = tween.targetX - tween.startX,
			dy = tween.targetY - tween.startY,
		}
    end
end

return Transform
