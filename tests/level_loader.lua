local json = require("vendor.json")
local LevelLoader = require("src.game.LevelLoader")

local tests = {}

function tests.list_levels_uses_ldtk_order_field()
	local project = {levels = {
		{identifier = "Later", fieldInstances = {{__identifier = "Order", __value = 20}}},
		{identifier = "First", fieldInstances = {{__identifier = "Order", __value = 1}}},
		{identifier = "Middle", fieldInstances = {{__identifier = "Order", __value = 10}}},
	}}
	local previousLove = rawget(_G, "love")
	_G.love = {filesystem = {read = function() return json.encode(project) end}}
	local ok, levels = pcall(LevelLoader.listLevels)
	_G.love = previousLove
	assert(ok, levels)
	assert(levels[1].identifier == "First")
	assert(levels[2].identifier == "Middle")
	assert(levels[3].identifier == "Later")
	assert(levels[1].number == 0 and levels[3].number == 2,
		"display numbering should follow the sorted sequence")
end

function tests.passthrough_entity_marks_a_cell_and_overrides_collision_wall()
	local project = {
		defs = {
			layers = {
				{
					uid = 1,
					identifier = "Collision",
					type = "IntGrid",
					intGridValuesGroups = {{uid = 1, identifier = "Collision"}},
					intGridValues = {{value = 1, identifier = "Wall", groupUid = 1}},
				},
				{uid = 2, identifier = "Ground", type = "Tiles"},
				{uid = 3, identifier = "Entities", type = "Entities"},
			},
			tilesets = {},
		},
		levels = {{
			identifier = "Fixture",
			layerInstances = {
				{
					layerDefUid = 3,
					__identifier = "Entities",
					__type = "Entities",
					__cWid = 3,
					__cHei = 1,
					__gridSize = 32,
					entityInstances = {
						{__identifier = "Passthrough", px = {32, 0}},
						{
							__identifier = "Trigger",
						px = {0, 0},
						fieldInstances = {{__identifier = "TriggerName", __value = "fixture_trigger"}},
						},
					},
				},
				{
					layerDefUid = 2,
					__identifier = "Ground",
					__type = "Tiles",
					__cWid = 3,
					__cHei = 1,
					__gridSize = 32,
					gridTiles = {{px = {0, 0}}},
				},
				{
					layerDefUid = 1,
					__identifier = "Collision",
					__type = "IntGrid",
					__cWid = 3,
					__cHei = 1,
					__gridSize = 32,
					intGridCsv = {0, 1, 0},
				},
			},
		}},
	}

	local previousLove = rawget(_G, "love")
	_G.love = {filesystem = {read = function() return json.encode(project) end}}
	local ok, board = pcall(LevelLoader.load, "fixture.ldtk", {}, nil, "Fixture")
	_G.love = previousLove
	assert(ok, board)

	assert(board:canWalk(0, 0), "Ground tiles should remain walkable")
	local passthrough = board:getCell(1, 0)
	assert(passthrough and passthrough.passthrough, "Passthrough entity should mark its cell")
	assert(not passthrough.walkable and not passthrough.wall,
		"Passthrough should be blocked for walking and override the collision wall")
	assert(board:getCell(2, 0) == nil,
		"an empty Ground cell without a Passthrough entity should remain void")
	assert(#board.triggers == 1 and board.triggers[1].name == "fixture_trigger",
		"Trigger entities should be loaded as invisible board metadata")
	assert(board.triggers[1].x == 0 and board.triggers[1].y == 0)
end

return tests
