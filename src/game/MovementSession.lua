local MovementSession = {}
MovementSession.__index = MovementSession

function MovementSession.new(board)
    local self = setmetatable({
        board = board,
        positions = {},
        blockedObjects = {},
        blockedObjectSet = {},
        componentChanges = {},
    }, MovementSession)

    for _, object in ipairs(board.objects) do
        if object.active ~= false and object:hasComponent("InteractiveObject") then
            local transform = object:getComponent("Transform")
            self.positions[object] = {x = transform.gridX, y = transform.gridY}
        end
    end
    return self
end

function MovementSession:position(object)
    return self.positions[object]
end

function MovementSession:componentAt(x, y, componentName)
    for _, object in ipairs(self.board.objects) do
        local transform = object:getComponent("Transform")
        if object.active ~= false and transform.gridX == x and transform.gridY == y then
            local component = object:getComponent(componentName)
            if component then return component end
        end
    end
end

function MovementSession:setComponentState(component, state, metadata)
    if not component or component.state == state then return false end
	local change = {
        object = component.owner,
        component = component.componentName,
        state = component.state,
    }
	for key, value in pairs(metadata or {}) do change[key] = value end
	self.componentChanges[#self.componentChanges + 1] = change
    component:setState(state, metadata)
    return true
end

function MovementSession:canWalk(x, y)
    return self.board:canWalk(x, y)
end

function MovementSession:canEnter(x, y, object)
	if self:canWalk(x, y) then return true end
	local cell = self.board:getCell(x, y)
	return cell ~= nil and cell.passthrough == true
		and object ~= nil and object:hasComponent("Sinkable")
end

function MovementSession:objectAt(x, y, except)
    for _, object in ipairs(self.board.objects) do
        local position = self.positions[object]
        if object ~= except and position and position.x == x and position.y == y then
            return object
        end
    end
end

function MovementSession:moveObject(object, x, y)
	local cell = self.board:getCell(x, y)
	local sinkable = object:getComponent("Sinkable")
	if cell and cell.passthrough and sinkable then
		local position = self.positions[object]
		self:setComponentState(sinkable, "approaching", {
			sinkX = x,
			sinkY = y,
			originX = position and position.x,
			originY = position and position.y,
		})
		self.positions[object] = {x = x, y = y}
		return
	end
    self.positions[object] = {x = x, y = y}
end

function MovementSession:markBlocked(object)
    if not object or self.blockedObjectSet[object] then return end
    self.blockedObjectSet[object] = true
    self.blockedObjects[#self.blockedObjects + 1] = object
end

function MovementSession:enter(actor, x, y)
    if not self:canEnter(x, y, actor) then return false end
    local blocker = self:objectAt(x, y, actor)
    if blocker then
        self:markBlocked(blocker)
        return false
    end
    self:moveObject(actor, x, y)
    return true
end

function MovementSession:findInRay(startX, startY, direction, actor)
    local x, y = startX, startY
    while true do
        local cell = self.board:getCell(x, y)
		if not cell or cell.wall or (not cell.walkable and not cell.passthrough) then
			return nil
		end
        local target = self:objectAt(x, y, actor)
        if target then return target end
        x, y = x + direction.x, y + direction.y
    end
end

function MovementSession:pushChain(actor, destination, direction, maxDistance)
    local first = self:objectAt(destination.x, destination.y, actor)
    if not first then
        return self:enter(actor, destination.x, destination.y)
    end

    local chain = {}
    local x, y = destination.x, destination.y
    while self:canWalk(x, y) do
        local object = self:objectAt(x, y, actor)
        if not object then break end
        chain[#chain + 1] = object
        x, y = x + direction.x, y + direction.y
    end

    local lastObject = chain[#chain]
	local last = self:position(lastObject)
    local distance = 0
	while true do
		local nextX = last.x + direction.x * (distance + 1)
		local nextY = last.y + direction.y * (distance + 1)
		local nextCell = self.board:getCell(nextX, nextY)
		if not nextCell or nextCell.wall or self:objectAt(nextX, nextY, actor) then
			break
		end
		if nextCell.walkable or (nextCell.passthrough and lastObject:hasComponent("Sinkable")) then
			distance = distance + 1
		else
			break
		end
    end
    if maxDistance then distance = math.min(distance, maxDistance) end
    if distance == 0 then
        self:markBlocked(chain[#chain])
        return false
    end

    for index = #chain, 1, -1 do
        local object = chain[index]
        local position = self:position(object)
        self:moveObject(object, position.x + direction.x * distance,
            position.y + direction.y * distance)
    end
    return self:enter(actor, destination.x, destination.y)
end

function MovementSession:changedPositions()
    local changes = {}
    for _, object in ipairs(self.board.objects) do
        local after = self.positions[object]
        if after then
            local transform = object:getComponent("Transform")
            if transform.gridX ~= after.x or transform.gridY ~= after.y then
                changes[#changes + 1] = {
                    object = object,
                    fromX = transform.gridX,
                    fromY = transform.gridY,
                    x = transform.x,
                    y = transform.y,
                    toX = after.x,
                    toY = after.y,
                }
            end
        end
    end
    return changes
end

function MovementSession:changedComponents()
    return self.componentChanges
end

return MovementSession
