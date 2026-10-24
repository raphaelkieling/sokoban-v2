local DiagonalWipe = {}

function DiagonalWipe.draw(coverage)
    coverage = math.max(0, math.min(1, coverage or 0))
    if coverage <= 0 then return end

    local width, height = love.graphics.getDimensions()
    local threshold = coverage * 2
    local corners = {
        {x = 0, y = 0},
        {x = width, y = 0},
        {x = width, y = height},
        {x = 0, y = height},
    }
    local points = {}

    for index, current in ipairs(corners) do
        local following = corners[index % #corners + 1]
        local currentValue = current.x / width + current.y / height
        local followingValue = following.x / width + following.y / height
        local currentInside = currentValue <= threshold
        local followingInside = followingValue <= threshold

        if currentInside then
            points[#points + 1] = current.x
            points[#points + 1] = current.y
        end
        if currentInside ~= followingInside then
            local amount = (threshold - currentValue) / (followingValue - currentValue)
            points[#points + 1] = current.x + (following.x - current.x) * amount
            points[#points + 1] = current.y + (following.y - current.y) * amount
        end
    end

    if #points >= 6 then
        love.graphics.push("all")
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.polygon("fill", points)
        love.graphics.pop()
    end
end

return DiagonalWipe
