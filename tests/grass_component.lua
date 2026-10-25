local Board = require("src.game.Board")
local SpriteRenderer = require("src.components.SpriteRenderer")

local tests = {}

local function makeBoard()
	local assets = {
		tileAnimation = function()
			return {update = function() end}
		end,
		tileRenderer = function()
			return SpriteRenderer({}, 2, 1, nil, nil, {})
		end,
	}
	local board = Board(assets, 2, 1)
	board:setCell(0, 0, {walkable = true})
	board:setCell(1, 0, {walkable = true})
	return board
end

function tests.grass_state_changes_flash_white_for_cutting_and_burning()
	local board = makeBoard()
	local grassObject = board:addGrass(0, 0, "tall_grass")
	local grass = grassObject:getComponent("Grass")
	local renderer = grassObject:getComponent("SpriteRenderer")

	assert(grass:setState("grass"), "cutting should change the grass state")
	assert(renderer.whiteFlash and renderer.whiteFlash.elapsed == 0,
		"cutting should start the component-owned white flash")

	renderer:update(0.2)
	assert(renderer.whiteFlash == nil, "the flash should end after its short duration")

	assert(grass:setState("tall"), "raising the grass should change its state")
	assert(renderer.whiteFlash and renderer.whiteFlash.elapsed == 0,
		"grass state changes caused by fire should use the same reusable flash")
end

return tests
