local Fonts = {}
local cache = {}
local menuCache = {}
local logoCache = {}

function Fonts.get(size)
    assert(type(size) == "number" and size > 0, "font size must be positive")
    if not cache[size] then
        cache[size] = love.graphics.newFont("assets/monogram.ttf", size)
    end
    return cache[size]
end

function Fonts.set(size)
    love.graphics.setFont(Fonts.get(size))
end

function Fonts.getMenu(size)
    assert(type(size) == "number" and size > 0, "font size must be positive")
    if not menuCache[size] then
        menuCache[size] = love.graphics.newFont("assets/fonts/Jersey10-Regular.ttf", size)
    end
    return menuCache[size]
end

function Fonts.getLogo(size)
    assert(type(size) == "number" and size > 0, "font size must be positive")
    if not logoCache[size] then
        logoCache[size] = love.graphics.newFont("assets/fonts/Jacquard24-Regular.ttf", size)
    end
    return logoCache[size]
end

function Fonts.setMenu(size)
    love.graphics.setFont(Fonts.getMenu(size))
end

function Fonts.setLogo(size)
    love.graphics.setFont(Fonts.getLogo(size))
end

return Fonts
