local GameObject = require("src.core.GameObject")
local Bonfire = require("src.components.Bonfire")
local Board = require("src.game.Board")
local MovementSession = require("src.game.MovementSession")
local SpriteRenderer = require("src.components.SpriteRenderer")
local Transform = require("src.components.Transform")
local InteractiveObject = require("src.components.InteractiveObject")
local Player = require("src.components.Player")
local CharacterMovement = require("src.components.CharacterMovement")
local CharacterClasses = require("src.characters.Classes")
local ActionHistory = require("src.game.ActionHistory")
local EventEmitter = require("src.core.EventEmitter")
local Sinkable = require("src.components.Sinkable")

local tests = {}

function tests.bonfire_switches_between_lit_animation_and_static_unlit_frame()
	local tileset = {name = "animated tiles"}
	local assets = {
		bonfireAnimation = function(_, _, state)
			return {state = state, update = function() end}
		end,
	}
	local object = GameObject("test-bonfire")
	local bonfire = Bonfire(assets, tileset)
	object:addComponent(bonfire)

	local animation = object:getComponent("Animation")
	assert(bonfire.state == "lit")
	assert(animation.current.state == "lit")
	assert(bonfire.tileset == tileset)

	bonfire:setState("unlit")
	assert(bonfire.state == "unlit")
	assert(animation.current.state == "unlit")

	bonfire:setState("lit")
	assert(bonfire.state == "lit")
	assert(animation.current.state == "lit")
end

function tests.board_registers_bonfire_as_a_pushable_interactive_object()
	local assets = {
		bonfireAnimation = function()
			return {update = function() end}
		end,
		tilesetRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
	}
	local board = Board(assets, 8, 8)
	local tileset = {name = "animated tiles"}
	local bonfire = board:addBonfire(3, 4, tileset)
	local movement = MovementSession.new(board)

	assert(bonfire:hasComponent("InteractiveObject"))
	assert(bonfire:hasComponent("Sinkable"),
		"bonfires should be able to cross holes during a long push")
	assert(movement:objectAt(3, 4) == bonfire)
end

function tests.warrior_can_push_a_bonfire_across_passthrough_to_the_far_platform()
	local assets = {
		bonfireAnimation = function(_, _, state)
			return {state = state, update = function() end}
		end,
		tilesetRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
	}
	local board = Board(assets, 8, 1)
	for x = 0, 7 do
		board:setCell(x, 0, {walkable = x ~= 3 and x ~= 4, wall = x == 7,
			passthrough = x == 3 or x == 4})
	end
	local fire = board:addBonfire(2, 0, {})
	local warrior = GameObject("Warrior")
	warrior:addComponent(Transform(1, 0, 64, 3))
	warrior:addComponent(InteractiveObject())
	warrior:addComponent(Player())
	warrior:addComponent(CharacterClasses.create(Player.Classes.WARRIOR))
	warrior:addComponent(CharacterMovement())
	board:addObject(warrior)

	local moved = warrior:getComponent("CharacterMovement"):move(
		board, {x = 1, y = 0}, ActionHistory())
	assert(moved)
	assert(fire:getComponent("Transform").gridX == 6,
		"the Warrior should be able to throw the bonfire across the hole onto the far floor")
	assert(fire:getComponent("Sinkable").state == "active" and fire.active,
		"a bonfire landing on floor should not fall into the hole")
end

function tests.bonfire_sinks_when_a_push_stops_in_a_hole_and_undo_restores_it()
	local assets = {
		bonfireAnimation = function(_, _, state)
			return {state = state, update = function() end}
		end,
		tilesetRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
	}
	local board = Board(assets, 4, 1)
	for x = 0, 2 do board:setCell(x, 0, {walkable = true, wall = false}) end
	board:setCell(3, 0, {walkable = false, wall = false, passthrough = true})
	local fire = board:addBonfire(2, 0, {})
	local warrior = GameObject("Warrior")
	warrior:addComponent(Transform(1, 0, 64, 3))
	warrior:addComponent(InteractiveObject())
	warrior:addComponent(Player())
	warrior:addComponent(CharacterClasses.create(Player.Classes.WARRIOR))
	warrior:addComponent(CharacterMovement())
	board:addObject(warrior)
	local history = ActionHistory()

	assert(warrior:getComponent("CharacterMovement"):move(
		board, {x = 1, y = 0}, history))
	assert(fire:getComponent("Sinkable").state == "approaching",
		"the bonfire should move to the hole before it starts falling")
	board:update(0.13)
	assert(fire:getComponent("Sinkable").state == "sinking")
	board:update(fire:getComponent("Sinkable").sinkDuration)
	assert(fire:getComponent("Sinkable").state == "lost")

	assert(history:undo())
	assert(fire.active and fire:getComponent("Sinkable").state == "active")
	assert(fire:getComponent("Transform").tween,
		"undo should restore the bonfire from the hole")
end

local function makeFireBoard(state)
	local assets = {
		bonfireAnimation = function(_, _, animationState)
			return {state = animationState, update = function() end}
		end,
		tileAnimation = function()
			return {update = function() end}
		end,
		tileRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
		tilesetRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
	}
	local board = Board(assets, 5, 1)
	for x = 0, 4 do board:setCell(x, 0, {walkable = true, wall = false}) end
	local grass = board:addGrass(3, 0, "tall_grass")
	local fire = board:addBonfire(state == "unlit" and 2 or 1, 0, {}, state)
	board.events = EventEmitter.new()
	return board, grass, fire
end

local function recordComponentChanges(board, history)
	board.events:on("component.state_changed", function(payload)
		if payload.cause ~= "flame" then return end
		local object = board.objects[payload.objectIndex]
		history:appendToLatest({{
			object = object,
			component = payload.component,
			state = payload.previousState,
		}})
	end)
end

function tests.unlit_bonfire_does_not_burn_tall_grass()
	local board, grass = makeFireBoard("unlit")
	board:update(0)
	assert(grass:getComponent("Grass").state == "tall")
	assert(not board:canWalk(3, 0))
end

function tests.lit_bonfire_burns_grass_and_undo_restores_it_when_pushed()
	local board, grass, fire = makeFireBoard("lit")
	local player = GameObject("Dwarf")
	player:addComponent(Transform(0, 0, 64, 3))
	player:addComponent(InteractiveObject())
	player:addComponent(Player())
	player:addComponent(CharacterClasses.create(Player.Classes.DWARF))
	player:addComponent(CharacterMovement())
	board:addObject(player)
	local history = ActionHistory()
	recordComponentChanges(board, history)

	local moved, changes = player:getComponent("CharacterMovement"):move(
		board, {x = 1, y = 0}, history)
	assert(moved)
	assert(fire:getComponent("Transform").gridX == 2)
	board:update(0)
	assert(grass:getComponent("Grass").state == "grass")
	assert(board:canWalk(3, 0))

	assert(history:undo())
	assert(fire:getComponent("Transform").gridX == 1)
	assert(grass:getComponent("Grass").state == "tall")
	assert(not board:canWalk(3, 0))
end

function tests.lit_bonfire_burns_flameable_grass_after_being_moved_by_a_wizard_swap()
	local board = Board({
		bonfireAnimation = function(_, _, state)
			return {state = state, update = function() end}
		end,
		tileAnimation = function()
			return {update = function() end}
		end,
		tileRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
		tilesetRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
	}, 6, 1)
	for x = 0, 4 do board:setCell(x, 0, {walkable = true, wall = false}) end
	board:setCell(5, 0, {walkable = true, wall = false})
	local grass = board:addGrass(0, 0, "tall_grass")
	local fire = board:addBonfire(4, 0, {}, "lit")
	local wizard = GameObject("Wizard")
	wizard:addComponent(Transform(1, 0, 64, 3))
	wizard:addComponent(InteractiveObject())
	wizard:addComponent(Player())
	wizard:addComponent(CharacterClasses.create(Player.Classes.WIZARD))
	wizard:addComponent(CharacterMovement())
	board:addObject(wizard)

	local moved = wizard:getComponent("CharacterMovement"):move(
		board, {x = 1, y = 0}, ActionHistory())
	assert(moved)
	assert(fire:getComponent("Transform").gridX == 1,
		"wizard swap should move the bonfire next to the grass tile")
	board:update(0)

	assert(grass:getComponent("Grass").state == "grass",
		"an active flame should burn any Flameable object it moves onto")
end

function tests.undo_reverses_farmer_and_fire_state_changes_in_reverse_order()
	local assets = {
		bonfireAnimation = function(_, _, state)
			return {state = state, update = function() end}
		end,
		tileAnimation = function()
			return {update = function() end}
		end,
		tileRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
		tilesetRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
	}
	local board = Board(assets, 3, 1)
	for x = 0, 2 do board:setCell(x, 0, {walkable = true, wall = false}) end
	local farmer = GameObject("Farmer")
	farmer:addComponent(Transform(0, 0, 64, 3))
	farmer:addComponent(InteractiveObject())
	farmer:addComponent(Player())
	farmer:addComponent(CharacterClasses.create(Player.Classes.FARMER))
	farmer:addComponent(CharacterMovement())
	board:addObject(farmer)
	board:addBonfire(2, 0, {}, "lit")
	local grass = board:addGrass(1, 0, "grass")
	local history = ActionHistory()
	board.events = EventEmitter.new()
	recordComponentChanges(board, history)

	local moved, changes = farmer:getComponent("CharacterMovement"):move(
		board, {x = 1, y = 0}, history)
	assert(moved and #changes == 0)
	board:update(0)
	assert(grass:getComponent("Grass").state == "grass",
		"the adjacent lit fire should burn the grass the farmer just raised")

	assert(history:undo())
	assert(grass:getComponent("Grass").state == "grass",
		"undo should restore the initial short-grass state")
end

return tests
