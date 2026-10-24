local Component = require("src.core.Component")

local SpriteRenderer = Component:extend()
SpriteRenderer.componentName = "SpriteRenderer"

function SpriteRenderer:init(image, scale, renderLayer, outlineShader)
    Component.init(self)
    self.image = image
    self.scale = scale or 1
    self.renderLayer = renderLayer or 0
    self.outlineShader = outlineShader
	self.whiteShader = outlineShader
	self.undoFeedback = nil
end

function SpriteRenderer:playUndo(fromX, fromY, toX, toY)
	self.undoFeedback = {
		fromX = fromX, fromY = fromY, toX = toX, toY = toY,
		elapsed = 0, duration = 0.3,
	}
end

function SpriteRenderer:update(dt)
	local feedback = self.undoFeedback
	if not feedback then return end
	feedback.elapsed = feedback.elapsed + dt
	if feedback.elapsed >= feedback.duration then self.undoFeedback = nil end
end

function SpriteRenderer:draw(context)
    local transform = self.owner:getComponent("Transform")
    local animation = self.owner:getComponent("Animation")
    local x, y = transform.x, transform.y
    local rotation = 0
	local scaleX, scaleY = transform:visualScale()
    local stateMachine = self.owner:getComponent("StateMachine")
    if stateMachine then
        local swayRotation, offsetX, offsetY = stateMachine:visualOffset()
		local stateScaleX, stateScaleY = stateMachine:visualScale()
		scaleX, scaleY = scaleX * stateScaleX, scaleY * stateScaleY
        x, y = x + offsetX, y + offsetY
        rotation = swayRotation
    end
    local shake = self.owner:getComponent("Shake")
    if shake then
        local offsetX, offsetY = shake:offset()
        x, y = x + offsetX, y + offsetY
    end
	local sinkable = self.owner:getComponent("Sinkable")
	local alpha = 1
	if sinkable then
		local sinkX, sinkY, sinkScale, sinkAlpha = sinkable:visualTransform()
		if sinkX then x, y, scaleX, scaleY, alpha = sinkX, sinkY,
			scaleX * sinkScale, scaleY * sinkScale, sinkAlpha end
	end
	local feedback = self.undoFeedback
	love.graphics.push("all")
	if feedback then
		local progress = math.min(feedback.elapsed / feedback.duration, 1)
		local transform = self.owner:getComponent("Transform")
		for index = 3, 1, -1 do
			local ghostProgress = math.max(0, progress - index * 0.12)
			local gx = (feedback.fromX + (feedback.toX - feedback.fromX) * ghostProgress + 0.5)
			local gy = (feedback.fromY + (feedback.toY - feedback.fromY) * ghostProgress + 0.5)
			love.graphics.setColor(1, 1, 1, (1 - progress) * (0.2 - index * 0.035))
			if self.whiteShader then love.graphics.setShader(self.whiteShader) end
			animation:render(self.image, gx * transform.cellSize, gy * transform.cellSize,
				self.scale, nil, rotation, scaleX, scaleY)
			love.graphics.setShader()
		end
		local flash = math.max(0, 1 - progress * 4)
		if flash > 0 and self.whiteShader then
			love.graphics.setColor(1, 1, 1, flash * alpha)
			animation:render(self.image, x, y, self.scale, self.whiteShader,
				rotation, scaleX, scaleY)
		end
	end
	love.graphics.setColor(1, 1, 1, alpha)
	animation:render(self.image, x, y, self.scale,
		context and context.selected and self.outlineShader or nil, rotation, scaleX, scaleY)
	if context and context.selected then
		local pulse = (math.sin(love.timer.getTime() * 5) + 1) / 2
		love.graphics.setColor(0.95, 0.84, 0.52, 0.2 + pulse * 0.25)
		love.graphics.setLineWidth(1.5 + pulse)
		love.graphics.ellipse("line", x, y + transform.cellSize * 0.28,
			transform.cellSize * (0.31 + pulse * 0.025),
			transform.cellSize * (0.105 + pulse * 0.012))
	end
	love.graphics.pop()
end

function SpriteRenderer:setAppearance(image, scale, renderLayer, outlineShader)
    self.image = image or self.image
    self.scale = scale or self.scale
    self.renderLayer = renderLayer or self.renderLayer
    self.outlineShader = outlineShader or self.outlineShader
	self.whiteShader = outlineShader or self.whiteShader
end

return SpriteRenderer
