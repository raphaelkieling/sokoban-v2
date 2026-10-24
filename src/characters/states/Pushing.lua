local MovementState = require("src.characters.states.MovementState")

local Pushing = MovementState:extend()

function Pushing:visualScale()
	local transform = self.owner:getComponent("Transform")
	local tween = transform and transform.tween
	if not tween then return 1, 1 end
	local progress = math.min(tween.elapsed / tween.duration, 1)
	local squash = math.sin(progress * math.pi) * 0.055
	if math.abs(tween.targetX - tween.startX) >= math.abs(tween.targetY - tween.startY) then
		return 1 + squash, 1 - squash * 0.6
	end
	return 1 - squash * 0.6, 1 + squash
end

return Pushing
