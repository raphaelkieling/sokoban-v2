local Fonts = require("src.ui.Fonts")

local Theme = {
    colors = {
        text = {0.94, 0.91, 0.84, 1},
        muted = {0.66, 0.63, 0.72, 1},
        accent = {0.93, 0.78, 0.44, 1},
        panel = {0.075, 0.068, 0.055, 0.96},
        selected = {0.96, 0.94, 0.88, 1},
        selectedText = {0.16, 0.12, 0.19, 1},
    },
}

function Theme.scale(width, height)
    return math.max(0.75, math.min(width / 1280, height / 720, 1.4))
end

function Theme.setColor(name, alpha)
    local color = Theme.colors[name]
    love.graphics.setColor(color[1], color[2], color[3], alpha or color[4])
end

function Theme.setFont(size, width, height)
    Fonts.set(math.max(14, math.floor(size * Theme.scale(width, height))))
end

function Theme.setMenuFont(size, width, height)
    Fonts.setMenu(math.max(14, math.floor(size * Theme.scale(width, height))))
end

function Theme.setLogoFont(size, width, height)
    Fonts.setLogo(math.max(14, math.floor(size * Theme.scale(width, height))))
end

function Theme.drawMenuItem(label, selected, centerY, width, height, fontSize, maxWidth, fixedWidth)
    Theme.setMenuFont(fontSize, width, height)
    local font = love.graphics.getFont()
    local text = string.upper(label)
    local scale = Theme.scale(width, height)
    local itemWidth = math.min(fixedWidth or maxWidth or width * 0.72,
        fixedWidth or (font:getWidth(text) + 34 * scale))
    local itemHeight = math.max(font:getHeight() + 6 * Theme.scale(width, height),
        34 * Theme.scale(width, height))
    local x = (width - itemWidth) / 2
    local y = centerY - itemHeight / 2

    if selected then
        love.graphics.setColor(Theme.colors.selected)
        love.graphics.rectangle("fill", x, y, itemWidth, itemHeight,
            2 * scale, 2 * scale, 4)
    end
    love.graphics.setColor(selected and Theme.colors.selectedText or Theme.colors.text)
    love.graphics.printf(text, x, y + (itemHeight - font:getHeight()) / 2,
        itemWidth, "center")
end

function Theme.drawPanel(x, y, width, height)
    love.graphics.push("all")
    Theme.setColor("panel")
    love.graphics.rectangle("fill", x, y, width, height)
    Theme.setColor("muted", 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 1, y + 1, width - 2, height - 2)
    love.graphics.pop()
end

function Theme.drawSelection(x, y, width, height)
    love.graphics.push("all")
    Theme.setColor("selected")
    love.graphics.rectangle("fill", x, y, width, height)
    Theme.setColor("accent")
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x + 1, y + 1, width - 2, height - 2)
    love.graphics.pop()
end

function Theme.drawDivider(x, y, width)
    love.graphics.push("all")
    Theme.setColor("muted", 0.85)
    love.graphics.setLineWidth(2)
    love.graphics.line(x, y, x + width, y)
    love.graphics.pop()
end

return Theme
