local anim8 = require("vendor.anim8")
local SpriteRenderer = require("src.components.SpriteRenderer")

local Assets = {}
Assets.__index = Assets

local outlineShaderSource = [[
vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
    vec4 pixel = Texel(texture, textureCoordinates);
    return vec4(1.0, 1.0, 1.0, pixel.a) * color;
}
]]

local whiteFlashShaderSource = [[
vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec4 pixel = Texel(texture, textureCoordinates);
	return vec4(1.0, 1.0, 1.0, pixel.a) * color;
}
]]

local sweepOutlineShaderSource = [[
extern vec4 frameUV;
extern float sweepProgress;
extern float sweepOpacity;

vec4 effect(vec4 color, Image texture, vec2 textureCoordinates, vec2 screenCoordinates) {
	vec4 pixel = Texel(texture, textureCoordinates);
	if (pixel.a <= 0.0) return vec4(0.0);

	vec2 localUV = (textureCoordinates - frameUV.xy) / frameUV.zw;
	float angle = atan(localUV.y - 0.5, localUV.x - 0.5) / 6.28318530718;
	angle = mod(angle + 1.0, 1.0);
	float behindHead = mod(sweepProgress - angle + 1.0, 1.0);
	float trailLength = 0.16;
	float alpha = 1.0 - smoothstep(trailLength * 0.65, trailLength, behindHead);
	return vec4(0.92, 0.95, 1.0, alpha * sweepOpacity * color.a);
}
]]

function Assets.new()
    local tiles = love.graphics.newImage("assets/tiles.png")
    local players = love.graphics.newImage("assets/rogues.png")
    tiles:setFilter("nearest", "nearest")
    players:setFilter("nearest", "nearest")

    return setmetatable({
        tiles = tiles,
        players = players,
        tilesetImages = {},
        tilesetQuads = {},
        tileGrid = anim8.newGrid(32, 32, tiles:getWidth(), tiles:getHeight()),
        playerGrid = anim8.newGrid(32, 32, players:getWidth(), players:getHeight()),
        tileColumns = tiles:getWidth() / 32,
        outlineShader = love.graphics.newShader(outlineShaderSource),
		sweepOutlineShader = love.graphics.newShader(sweepOutlineShaderSource),
		whiteFlashShader = love.graphics.newShader(whiteFlashShaderSource),
    }, Assets)
end

function Assets:tileRenderer(scale, layer)
	return SpriteRenderer(self.tiles, scale or 2, layer, self.outlineShader,
		self.sweepOutlineShader, self.whiteFlashShader)
end

function Assets:tilesetImage(tileset)
    local path = assert(tileset and (tileset.imagePath or tileset.image),
        "tileset does not define an image")
    if not self.tilesetImages[path] then
        local image = love.graphics.newImage(path)
        image:setFilter("nearest", "nearest")
        self.tilesetImages[path] = image
    end
    return self.tilesetImages[path]
end

function Assets:tilesetRenderer(tileset, scale, layer)
	return SpriteRenderer(self:tilesetImage(tileset), scale or 2, layer,
		self.outlineShader, self.sweepOutlineShader, self.whiteFlashShader)
end

function Assets:tileAnimation(tileX, tileY)
    return anim8.newAnimation(self.tileGrid(tileX + 1, tileY + 1), 1)
end

function Assets:playerAnimation(tileX, tileY)
    return anim8.newAnimation(self.playerGrid(tileX + 1, tileY + 1), 1)
end

function Assets:bonfireAnimation(tileset, state)
    local image = self:tilesetImage(tileset)
    local grid = anim8.newGrid(
        tileset.tilewidth or 32,
        tileset.tileheight or 32,
        image:getWidth(),
        image:getHeight())
    if state == "unlit" then
        return anim8.newAnimation(grid(1, 1), 1)
    end
    return anim8.newAnimation(grid("1-6", 2), 0.12)
end

function Assets:tileQuad(tileId)
    local column = tileId % self.tileColumns
    local row = math.floor(tileId / self.tileColumns)
    return self.tileGrid(column + 1, row + 1)[1]
end

function Assets:mapTile(tileset, tileId)
	local image = self:tilesetImage(tileset)
	local tileWidth = tileset.tilewidth or 32
	local tileHeight = tileset.tileheight or 32
	local columns = tileset.columns or math.floor(image:getWidth() / tileWidth)
	local margin = tileset.margin or 0
	local spacing = tileset.spacing or 0
	local x = tileId % columns
	local y = math.floor(tileId / columns)
	local cacheKey = table.concat({tileset.image or tileset.imagePath, tileWidth,
		tileHeight, margin, spacing, tileId}, ":")
	local quad = self.tilesetQuads[cacheKey]
	if not quad then
		quad = love.graphics.newQuad(
			margin + x * (tileWidth + spacing),
			margin + y * (tileHeight + spacing),
			tileWidth, tileHeight, image:getWidth(), image:getHeight())
		self.tilesetQuads[cacheKey] = quad
	end
	return image, quad, tileWidth, tileHeight
end

function Assets:mapTileAt(tileset, sourceX, sourceY)
	local image = self:tilesetImage(tileset)
	local tileWidth = tileset.tilewidth or 32
	local tileHeight = tileset.tileheight or 32
	local cacheKey = table.concat({tileset.image or tileset.imagePath, tileWidth,
		tileHeight, sourceX, sourceY}, ":")
	local quad = self.tilesetQuads[cacheKey]
	if not quad then
		quad = love.graphics.newQuad(sourceX, sourceY, tileWidth, tileHeight,
			image:getWidth(), image:getHeight())
		self.tilesetQuads[cacheKey] = quad
	end
	return image, quad, tileWidth, tileHeight
end

function Assets:playerRenderer(scale, layer)
    return SpriteRenderer(self.players, scale or 2.25, layer or 3,
		self.outlineShader, self.sweepOutlineShader, self.whiteFlashShader)
end

return Assets
