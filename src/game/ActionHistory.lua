local Class = require("src.core.Class")

local ActionHistory = Class:extend()

function ActionHistory:init()
    self.actions = {}
end

function ActionHistory:record(snapshots)
    if #snapshots > 0 then
        self.actions[#self.actions + 1] = snapshots
    end
end

function ActionHistory:appendToLatest(snapshots)
	local action = self.actions[#self.actions]
	if not action then return false end
	for _, snapshot in ipairs(snapshots or {}) do
		action[#action + 1] = snapshot
	end
	return true
end

function ActionHistory:undo()
    local snapshots = table.remove(self.actions)
    if not snapshots then
        return false
    end
    for index = #snapshots, 1, -1 do
        local snapshot = snapshots[index]
        if snapshot.component then
			if snapshot.component == "Sinkable" and snapshot.state == "active"
				and snapshot.sinkX ~= nil and snapshot.originX ~= nil then
				local transform = snapshot.object:getComponent("Transform")
				transform.x = (snapshot.sinkX + 0.5) * transform.cellSize
				transform.y = (snapshot.sinkY + 0.5) * transform.cellSize
				transform.tween = nil
				transform:restore({
					gridX = snapshot.originX,
					gridY = snapshot.originY,
					x = (snapshot.originX + 0.5) * transform.cellSize,
					y = (snapshot.originY + 0.5) * transform.cellSize,
				})
				local renderer = snapshot.object:getComponent("SpriteRenderer")
				if renderer then
					renderer:playUndo(snapshot.sinkX, snapshot.sinkY,
						snapshot.originX, snapshot.originY)
				end
			end
            snapshot.object:getComponent(snapshot.component):setState(snapshot.state, snapshot)
        else
			local transform = snapshot.object:getComponent("Transform")
			local renderer = snapshot.object:getComponent("SpriteRenderer")
			if renderer then
				renderer:playUndo(transform.gridX, transform.gridY,
					snapshot.gridX, snapshot.gridY)
			end
			transform:restore(snapshot)
        end
        local player = snapshot.object:getComponent("Player")
        local stateMachine = player and player:getStateMachine()
        if stateMachine then
            stateMachine:change(#snapshots > 1 and "pushing" or "walking")
        end
    end
    return true
end

function ActionHistory:clear()
    self.actions = {}
end

return ActionHistory
