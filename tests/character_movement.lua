local Board = require("src.game.Board")
local GameObject = require("src.core.GameObject")
local Character = require("src.components.Character")
local Component = require("src.core.Component")
local Transform = require("src.components.Transform")
local InteractiveObject = require("src.components.InteractiveObject")
local Player = require("src.components.Player")
local CharacterMovement = require("src.components.CharacterMovement")
local StateMachine = require("src.components.StateMachine")
local CharacterClasses = require("src.characters.Classes")
local PlayerStates = require("src.characters.PlayerStates")
local Box = require("src.components.Box")
local Sinkable = require("src.components.Sinkable")
local Shake = require("src.components.Shake")
local ActionHistory = require("src.game.ActionHistory")
local SpriteRenderer = require("src.components.SpriteRenderer")
local Animation = require("src.components.Animation")

local tests = {}

local function makeBoard(xStart, xEnd, y, walls)
    local board = Board(nil, xEnd - xStart + 1, 1)
    for x = xStart, xEnd do
        board:setCell(x, y, {walkable = not (walls and walls[x])})
    end
    return board
end

local function makeRectBoard(width, height, walls)
    local board = Board(nil, width, height)
    for y = 0, height - 1 do
        for x = 0, width - 1 do
            board:setCell(x, y, {walkable = not (walls and walls[x .. ":" .. y])})
        end
    end
    return board
end

local function spawnPlayer(board, x, y, classId)
    local player = GameObject("test-player")
    player:addComponent(Transform(x, y, 64, 3))
    player:addComponent(InteractiveObject())
    local character = Character()
    player:addComponent(character)
    local playerComponent = Player()
    character:addComponent(playerComponent)
    playerComponent:setClass(CharacterClasses.create(classId))
    character:addComponent(CharacterMovement())
    character:addComponent(StateMachine(PlayerStates, "idle"))
    board:addObject(player)
    return player
end

local function spawnBox(board, x, y)
    local box = GameObject("test-box")
    box:addComponent(Transform(x, y, 64, 2))
    box:addComponent(InteractiveObject())
    box:addComponent(Box())
    box:addComponent(Sinkable())
    board:addObject(box)
    return box
end

local function spawnGrass(board, x, y, state)
	board.assets = {
		tileAnimation = function(_, tileX, tileY)
			return {x = tileX, y = tileY, update = function() end}
		end,
		tileRenderer = function()
			return SpriteRenderer({}, 2, 1)
		end,
	}
	return board:addGrass(x, y, state or "grass")
end

local function pos(object)
    local transform = object:getComponent("Transform")
    return transform.gridX, transform.gridY
end

local function assertPosition(object, x, y)
    local actualX, actualY = pos(object)
    assert(actualX == x and actualY == y,
        string.format("expected (%d,%d), got (%d,%d)", x, y, actualX, actualY))
end

local function run(board, player, direction, history)
	return player:getComponent("CharacterMovement"):move(board, direction, history or ActionHistory())
end

function tests.dwarf_walks_one_tile()
    local board = makeBoard(0, 4, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
end

function tests.farmer_cuts_tall_grass_without_stepping_onto_it_and_undo_restores_it()
	local board = makeBoard(0, 4, 0)
	local farmer = spawnPlayer(board, 1, 0, Player.Classes.FARMER)
	local grass = spawnGrass(board, 2, 0, "tall_grass")
	local history = ActionHistory()

	assert(farmer:getComponent("CharacterMovement"):move(board, {x = 1, y = 0}, history))
	assertPosition(farmer, 1, 0)
	assert(grass:getComponent("Grass").state == "grass")
	assert(board:canWalk(2, 0), "cut grass should be walkable")

	assert(history:undo())
	assertPosition(farmer, 1, 0)
	assert(grass:getComponent("Grass").state == "tall")
	assert(not board:canWalk(2, 0), "undo should restore the tall-grass obstacle")
end

function tests.farmer_raises_short_grass_without_stepping_onto_it_and_undo_restores_it()
	local board = makeBoard(0, 4, 0)
	local farmer = spawnPlayer(board, 1, 0, Player.Classes.FARMER)
	local grass = spawnGrass(board, 2, 0, "grass")
	local history = ActionHistory()

	assert(farmer:getComponent("CharacterMovement"):move(board, {x = 1, y = 0}, history))
	assertPosition(farmer, 1, 0)
	assert(grass:getComponent("Grass").state == "tall")
	assert(not board:canWalk(2, 0), "raised grass should block the tile")

	assert(history:undo())
	assert(grass:getComponent("Grass").state == "grass")
	assert(board:canWalk(2, 0), "undo should restore passable short grass")
end

function tests.tall_grass_blocks_other_players_and_boxes()
	local board = makeBoard(0, 4, 0)
	local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
	local grass = spawnGrass(board, 2, 0, "tall_grass")
	assert(not board:canWalk(2, 0))
	assert(not run(board, dwarf, {x = 1, y = 0}))
	assertPosition(dwarf, 1, 0)

	local boxBoard = makeBoard(0, 4, 0)
	local pusher = spawnPlayer(boxBoard, 1, 0, Player.Classes.DWARF)
	local box = spawnBox(boxBoard, 2, 0)
	spawnGrass(boxBoard, 3, 0, "tall_grass")
	assert(not run(boxBoard, pusher, {x = 1, y = 0}))
	assertPosition(pusher, 1, 0)
	assertPosition(box, 2, 0)
	assert(grass:getComponent("Grass").state == "tall")
end

function tests.farmer_cannot_push_a_box()
	local board = makeBoard(0, 4, 0)
	local farmer = spawnPlayer(board, 1, 0, Player.Classes.FARMER)
	local box = spawnBox(board, 2, 0)

	assert(not run(board, farmer, {x = 1, y = 0}))
	assertPosition(farmer, 1, 0)
	assertPosition(box, 2, 0)
end

function tests.grass_is_not_pushed_or_trampled_by_other_classes()
	local board = makeBoard(0, 4, 0)
	local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
	local grass = spawnGrass(board, 2, 0)

	assert(run(board, dwarf, {x = 1, y = 0}))
	assertPosition(dwarf, 2, 0)
	assert(grass:getComponent("Grass").state == "grass")
	assertPosition(grass, 2, 0)
end

function tests.dwarf_pushes_one_box_one_tile()
    local board = makeBoard(0, 4, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 2, 0)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(box, 3, 0)
end

function tests.dwarf_pushes_a_contiguous_chain()
    local board = makeBoard(0, 5, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local first = spawnBox(board, 2, 0)
    local second = spawnBox(board, 3, 0)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(first, 3, 0)
    assertPosition(second, 4, 0)
end

function tests.dwarf_cannot_push_into_wall_or_off_map()
    local board = makeBoard(0, 3, 0, {[3] = true})
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 2, 0)
    box:addComponent(Shake())
    assert(not run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 1, 0)
    assertPosition(box, 2, 0)
    assert(box:getComponent("Shake").elapsed == 0, "blocked box push should trigger its shake")
end

function tests.player_starts_idle_and_idle_state_applies_subtle_sway()
    local board = makeBoard(0, 4, 0)
    local player = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local stateMachine = player:getComponent("Player"):getStateMachine()

    assert(stateMachine.currentName == "idle")
    player:update(0.1)
    local rotation, offsetX, offsetY = stateMachine:visualOffset()
    assert(math.abs(rotation) + math.abs(offsetX) + math.abs(offsetY) > 0)
end

function tests.player_switches_from_walking_back_to_idle()
    local board = makeBoard(0, 4, 0)
    local player = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local stateMachine = player:getComponent("Player"):getStateMachine()

    assert(run(board, player, {x = 1, y = 0}))
    assert(stateMachine.currentName == "walking")
    player:update(0.2)
    assert(stateMachine.currentName == "idle")
end

function tests.movement_effect_is_dispatched_by_the_actors_walking_state()
    local board = makeBoard(0, 4, 0)
    local player = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local stateMachine = player:getComponent("Player"):getStateMachine()
    local effects = {}
    local effectState
    local behavior = player:getComponent("CharacterClass")
    behavior.playMovementEffect = function(_self, receivedEffects)
        effectState = stateMachine.currentName
        assert(receivedEffects == effects)
    end

    assert(player:getComponent("CharacterMovement"):move(board, {x = 1, y = 0}, ActionHistory(), effects))
    assert(effectState == "walking")
end

function tests.wizard_uses_dust_for_a_normal_walk()
    local board = makeBoard(0, 4, 0)
    local wizard = spawnPlayer(board, 1, 0, Player.Classes.WIZARD)
    local played = {}
    local effects = {
        dust = function() played[#played + 1] = "dust" end,
        characterTrail = function() played[#played + 1] = "wizard-trail" end,
    }

    assert(wizard:getComponent("CharacterMovement"):move(board, {x = 1, y = 0}, ActionHistory(), effects))
    assert(#played == 1 and played[1] == "dust")
end

function tests.wizard_uses_only_its_trail_when_swapping_with_an_object()
    local board = makeBoard(0, 5, 0)
    local wizard = spawnPlayer(board, 1, 0, Player.Classes.WIZARD)
    spawnBox(board, 4, 0)
    local played = {}
    local effects = {
        dust = function() played[#played + 1] = "dust" end,
        characterTrail = function() played[#played + 1] = "wizard-trail" end,
    }

    assert(wizard:getComponent("CharacterMovement"):move(board, {x = 1, y = 0}, ActionHistory(), effects))
    assert(#played == 1 and played[1] == "wizard-trail")
end

function tests.movement_effect_does_not_run_for_a_player_pushed_as_an_object()
    local board = makeBoard(0, 5, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local wizard = spawnPlayer(board, 2, 0, Player.Classes.WIZARD)
    local effects = {}
    local pushedPlayerEffectPlayed = false
    dwarf:getComponent("CharacterClass").playMovementEffect = function() end
    wizard:getComponent("CharacterClass").playMovementEffect = function()
        pushedPlayerEffectPlayed = true
    end

    assert(dwarf:getComponent("CharacterMovement"):move(board, {x = 1, y = 0}, ActionHistory(), effects))
    assert(not pushedPlayerEffectPlayed)
end

function tests.undo_uses_walking_state_until_the_tween_finishes()
    local board = makeBoard(0, 4, 0)
    local player = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local history = ActionHistory()
    local stateMachine = player:getComponent("Player"):getStateMachine()

    assert(player:getComponent("CharacterMovement"):move(board, {x = 1, y = 0}, history))
    assert(history:undo())
    assert(stateMachine.currentName == "walking")
    player:update(0.2)
    assertPosition(player, 1, 0)
    assert(stateMachine.currentName == "idle")
end

function tests.player_uses_pushing_state_during_a_push()
    local board = makeBoard(0, 4, 0)
    local player = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 2, 0)
    local stateMachine = player:getComponent("Player"):getStateMachine()

    assert(run(board, player, {x = 1, y = 0}))
    assert(stateMachine.currentName == "pushing")
	player:update(0.06)
	local scaleX, scaleY = stateMachine:visualScale()
	assert(scaleX > 1 and scaleY < 1,
		"the character pushing state should add directional squash-and-stretch")
    player:update(0.2)
    assert(stateMachine.currentName == "idle")
    assertPosition(box, 3, 0)
end

function tests.player_pushed_as_an_object_uses_pushing_state()
    local board = makeBoard(0, 5, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local wizard = spawnPlayer(board, 2, 0, Player.Classes.WIZARD)
    local stateMachine = wizard:getComponent("Player"):getStateMachine()

    assert(run(board, dwarf, {x = 1, y = 0}))
    assert(stateMachine.currentName == "pushing")
end

function tests.wizard_swaps_with_first_object_in_ray()
    local board = makeBoard(0, 6, 0)
    local wizard = spawnPlayer(board, 1, 0, Player.Classes.WIZARD)
    local box = spawnBox(board, 4, 0)
    assert(run(board, wizard, {x = 1, y = 0}))
    assertPosition(wizard, 4, 0)
    assertPosition(box, 1, 0)
end

function tests.wizard_can_swap_across_passthrough_cells_in_both_directions()
	local function makePassthroughBoard()
		local board = makeBoard(0, 8, 0)
		for x = 3, 5 do
			board:setCell(x, 0, {walkable = false, wall = false, passthrough = true})
		end
		return board
	end

	local rightwardBoard = makePassthroughBoard()
	local leftBankWizard = spawnPlayer(rightwardBoard, 2, 0, Player.Classes.WIZARD)
	local rightBankBox = spawnBox(rightwardBoard, 6, 0)
	assert(run(rightwardBoard, leftBankWizard, {x = 1, y = 0}))
	assertPosition(leftBankWizard, 6, 0)
	assertPosition(rightBankBox, 2, 0)

	local leftwardBoard = makePassthroughBoard()
	local rightBankWizard = spawnPlayer(leftwardBoard, 6, 0, Player.Classes.WIZARD)
	local leftBankBox = spawnBox(leftwardBoard, 2, 0)
	assert(run(leftwardBoard, rightBankWizard, {x = -1, y = 0}))
	assertPosition(rightBankWizard, 2, 0)
	assertPosition(leftBankBox, 6, 0)
end

function tests.player_can_change_class_and_use_the_new_ability()
    local board = makeBoard(0, 6, 0)
    local player = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 4, 0)
    player:getComponent("Player"):setClass(Player.Classes.WIZARD)
    assert(run(board, player, {x = 1, y = 0}))
    assertPosition(player, 4, 0)
    assertPosition(box, 1, 0)
end

function tests.character_accepts_an_independent_component()
    local board = makeBoard(0, 4, 0)
    local player = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local ExtraCharacterFeature = Component:extend()
    ExtraCharacterFeature.componentName = "TestCharacterFeature"
    function ExtraCharacterFeature:init()
        Component.init(self)
    end

    player:getComponent("Character"):addComponent(ExtraCharacterFeature())
    local feature = player:getComponent("TestCharacterFeature")
    assert(feature and feature.owner == player,
        "nested character components should be discoverable and attached to the object")
    assert(player:getComponent("CharacterClass").id == Player.Classes.DWARF,
        "adding an independent component should not alter the character class")
end

function tests.wizard_walks_when_ray_is_clear()
    local board = makeBoard(0, 4, 0)
    local wizard = spawnPlayer(board, 1, 0, Player.Classes.WIZARD)
    assert(run(board, wizard, {x = 1, y = 0}))
    assertPosition(wizard, 2, 0)
end

function tests.wizard_does_not_see_through_a_wall()
    local board = makeBoard(0, 5, 0, {[3] = true})
    local wizard = spawnPlayer(board, 1, 0, Player.Classes.WIZARD)
    local box = spawnBox(board, 4, 0)
    assert(run(board, wizard, {x = 1, y = 0}))
    assertPosition(wizard, 2, 0)
    assertPosition(box, 4, 0)
end

function tests.warrior_pushes_chain_as_far_as_possible()
    local board = makeBoard(0, 7, 0)
    local warrior = spawnPlayer(board, 1, 0, Player.Classes.WARRIOR)
    local first = spawnBox(board, 2, 0)
    local second = spawnBox(board, 3, 0)
    assert(run(board, warrior, {x = 1, y = 0}))
    assertPosition(warrior, 2, 0)
    assertPosition(first, 6, 0)
    assertPosition(second, 7, 0)
end

function tests.warrior_stops_the_chain_before_another_object()
    local board = makeBoard(0, 6, 0)
    local warrior = spawnPlayer(board, 1, 0, Player.Classes.WARRIOR)
    local first = spawnBox(board, 2, 0)
    local blocker = spawnBox(board, 4, 0)
    assert(run(board, warrior, {x = 1, y = 0}))
    assertPosition(warrior, 2, 0)
    assertPosition(first, 3, 0)
    assertPosition(blocker, 4, 0)
end

function tests.warrior_pushes_a_box_through_passthrough_when_it_can_land_on_floor()
	local board = makeBoard(0, 6, 0)
	board:setCell(3, 0, {walkable = false, wall = false, passthrough = true})
	board:setCell(4, 0, {walkable = false, wall = false, passthrough = true})
	board:setCell(6, 0, {walkable = false, wall = true})
	local warrior = spawnPlayer(board, 1, 0, Player.Classes.WARRIOR)
	local box = spawnBox(board, 2, 0)

	assert(run(board, warrior, {x = 1, y = 0}))
	assert(box:getComponent("Sinkable").state == "active")
	assert(box.active == true, "a box should survive if the push carries it through passthrough")
	assertPosition(warrior, 2, 0)
	assertPosition(box, 5, 0)
	local transform = box:getComponent("Transform")
	assert(transform.tween and transform.tween.pushed,
		"pushed boxes should carry squash-and-stretch feedback during movement")
end

function tests.warrior_marks_a_box_lost_if_the_push_stops_inside_passthrough()
	local board = makeBoard(0, 4, 0)
	board:setCell(3, 0, {walkable = false, wall = false, passthrough = true})
	board:setCell(4, 0, {walkable = false, wall = true})
	local warrior = spawnPlayer(board, 1, 0, Player.Classes.WARRIOR)
	local box = spawnBox(board, 2, 0)
	box:addComponent(Animation({draw = function() end, update = function() end}))
	box:addComponent(SpriteRenderer({}, 2, 2))
	local history = ActionHistory()

	assert(run(board, warrior, {x = 1, y = 0}, history))
	assert(box:getComponent("Sinkable").state == "sinking")
	assert(box.active == false and box.visualOnly,
		"a box in passthrough should enter its own temporary sinking visual state")
	assertPosition(warrior, 2, 0)
	box:update(0.4)
	assert(box:getComponent("Sinkable").state == "lost" and not box.visualOnly,
		"the box should finish sinking into its lost state")

	assert(history:undo())
	assert(box.active == true and box:getComponent("Sinkable").state == "active",
		"undo should restore a box lost in passthrough")
	assertPosition(box, 2, 0)
	assert(box:getComponent("Transform").tween,
		"undo should animate the box back from the passthrough tile")
	assert(box:getComponent("SpriteRenderer").undoFeedback ~= nil,
		"the box sprite should own its reverse trail and white-flash feedback")
end

function tests.sinkable_owns_and_advances_its_fall_state()
	local board = makeBoard(0, 3, 0)
	local box = spawnBox(board, 1, 0)
	local sinkable = box:getComponent("Sinkable")
	sinkable:setState("sinking", {originX = 1, originY = 0, sinkX = 2, sinkY = 0})
	assert(board:isMoving(), "the board should wait for a sinking object's visual state")
	local x, y, scale, alpha = sinkable:visualTransform()
	assert(x == 96 and y == 32 and scale == 1 and alpha == 1,
		"the fall should start at the box's own origin")
	sinkable:update(sinkable.sinkDuration / 2)
	x, y, scale, alpha = sinkable:visualTransform()
	assert(x > 96 and x < 160 and scale < 1 and alpha < 1,
		"the component should interpolate its sprite into the destination")
	sinkable:update(sinkable.sinkDuration)
	assert(sinkable.state == "lost" and not box.visualOnly,
		"the component should finish its own fall and stop rendering")
	assert(not board:isMoving(), "a completed fall should stop blocking board input")
end

function tests.transform_squashes_after_pushed_movement()
	local transform = Transform(1, 0, 64)
	transform:moveTo(2, 0, true)
	transform:update(0.12)
	local scaleX, scaleY = transform:visualScale()
	assert(scaleX > 1 and scaleY < 1,
		"a pushed object should compress horizontally on landing")
	transform:update(0.14)
	scaleX, scaleY = transform:visualScale()
	assert(scaleX == 1 and scaleY == 1, "the squash should settle back to normal")
end

function tests.telekinetic_pushes_the_first_object_one_cell()
    local board = makeBoard(0, 6, 0)
    local telekinetic = spawnPlayer(board, 1, 0, Player.Classes.TELEKINETIC)
    local box = spawnBox(board, 4, 0)
    assert(run(board, telekinetic, {x = 1, y = 0}))
    assertPosition(telekinetic, 2, 0)
    assertPosition(box, 5, 0)
end

function tests.telekinetic_walks_forward_when_a_distant_push_is_blocked()
    local board = makeBoard(0, 5, 0)
    local telekinetic = spawnPlayer(board, 1, 0, Player.Classes.TELEKINETIC)
    local box = spawnBox(board, 3, 0)
    local blocker = spawnBox(board, 4, 0)
    assert(run(board, telekinetic, {x = 1, y = 0}))
    assertPosition(telekinetic, 2, 0)
    assertPosition(box, 3, 0)
    assertPosition(blocker, 4, 0)
end

function tests.sorcerer_pulls_a_distant_object_back()
    local board = makeBoard(0, 6, 0)
    local sorcerer = spawnPlayer(board, 1, 0, Player.Classes.SORCERER)
    local box = spawnBox(board, 4, 0)
    assert(run(board, sorcerer, {x = 1, y = 0}))
    assertPosition(sorcerer, 2, 0)
    assertPosition(box, 3, 0)
end

function tests.sorcerer_cannot_pull_an_adjacent_object()
    local board = makeBoard(0, 4, 0)
    local sorcerer = spawnPlayer(board, 1, 0, Player.Classes.SORCERER)
    local box = spawnBox(board, 2, 0)
    assert(not run(board, sorcerer, {x = 1, y = 0}))
    assertPosition(sorcerer, 1, 0)
    assertPosition(box, 2, 0)
end

function tests.sorcerer_cannot_pull_onto_its_destination()
    local board = makeBoard(0, 4, 0)
    local sorcerer = spawnPlayer(board, 1, 0, Player.Classes.SORCERER)
    local box = spawnBox(board, 3, 0)
    assert(not run(board, sorcerer, {x = 1, y = 0}))
    assertPosition(sorcerer, 1, 0)
    assertPosition(box, 3, 0)
end

function tests.pushed_wizard_moves_as_a_block_without_using_its_ability()
    local board = makeBoard(0, 5, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local wizard = spawnPlayer(board, 2, 0, Player.Classes.WIZARD)
    local box = spawnBox(board, 4, 0)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(wizard, 3, 0)
    assertPosition(box, 4, 0)
end

function tests.pushed_wizard_with_clear_ray_walks_and_pusher_follows()
    local board = makeBoard(0, 4, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local wizard = spawnPlayer(board, 2, 0, Player.Classes.WIZARD)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(wizard, 3, 0)
end

function tests.pushing_a_player_through_a_box_chain_does_not_use_their_ability()
    local board = makeBoard(0, 5, 0)
    local dwarf = spawnPlayer(board, 1, 0, Player.Classes.DWARF)
    local box = spawnBox(board, 2, 0)
    local wizard = spawnPlayer(board, 3, 0, Player.Classes.WIZARD)
    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 0)
    assertPosition(box, 3, 0)
    assertPosition(wizard, 4, 0)
end

function tests.telekinetic_walks_forward_if_a_distant_box_cannot_move()
    local board = makeBoard(0, 6, 0, {[6] = true})
    local telekinetic = spawnPlayer(board, 1, 0, Player.Classes.TELEKINETIC)
    local box = spawnBox(board, 5, 0)
    assert(run(board, telekinetic, {x = 1, y = 0}))
    assertPosition(telekinetic, 2, 0)
    assertPosition(box, 5, 0)
end

function tests.telekinetic_pushes_a_player_as_a_block()
    local board = makeBoard(0, 7, 0)
    local telekinetic = spawnPlayer(board, 1, 0, Player.Classes.TELEKINETIC)
    local wizard = spawnPlayer(board, 4, 0, Player.Classes.WIZARD)
    local box = spawnBox(board, 6, 0)
    assert(run(board, telekinetic, {x = 1, y = 0}))
    assertPosition(telekinetic, 2, 0)
    assertPosition(wizard, 5, 0)
    assertPosition(box, 6, 0)
end

function tests.sorcerer_pulls_a_player_as_a_block()
    local board = makeBoard(0, 5, 0)
    local sorcerer = spawnPlayer(board, 1, 0, Player.Classes.SORCERER)
    local wizard = spawnPlayer(board, 4, 0, Player.Classes.WIZARD)
    assert(run(board, sorcerer, {x = 1, y = 0}))
    assertPosition(sorcerer, 2, 0)
    assertPosition(wizard, 3, 0)
end

function tests.mysterious_priest_moves_every_interactive_object_in_its_square_aura()
    local board = makeRectBoard(8, 8)
    local priest = spawnPlayer(board, 3, 3, Player.Classes.MYSTERIOUS_PRIEST)
    local forwardBox = spawnBox(board, 4, 3)
    local diagonalBox = spawnBox(board, 2, 2)
    local nearbyPlayer = spawnPlayer(board, 4, 4, Player.Classes.WIZARD)
    local outsideBox = spawnBox(board, 1, 1)

    assert(run(board, priest, {x = 1, y = 0}))
    assertPosition(priest, 4, 3)
    assertPosition(forwardBox, 5, 3)
    assertPosition(diagonalBox, 3, 2)
    assertPosition(nearbyPlayer, 5, 4)
    assertPosition(outsideBox, 1, 1)
end

function tests.mysterious_priest_continues_when_an_aura_object_is_blocked()
    local board = makeRectBoard(7, 7, {["4:2"] = true})
    local priest = spawnPlayer(board, 3, 3, Player.Classes.MYSTERIOUS_PRIEST)
    local blockedBox = spawnBox(board, 3, 2)
    local movingBox = spawnBox(board, 3, 4)

    assert(run(board, priest, {x = 1, y = 0}))
    assertPosition(priest, 4, 3)
    assertPosition(blockedBox, 3, 2)
    assertPosition(movingBox, 4, 4)
end

function tests.mysterious_priest_can_leave_a_cell_for_a_trailing_aura_object()
    local board = makeRectBoard(7, 5)
    local priest = spawnPlayer(board, 3, 2, Player.Classes.MYSTERIOUS_PRIEST)
    local trailingBox = spawnBox(board, 2, 2)

    assert(run(board, priest, {x = 1, y = 0}))
    assertPosition(priest, 4, 2)
    assertPosition(trailingBox, 3, 2)
end

function tests.mysterious_priest_does_not_overlap_a_trailing_object_if_blocked()
    local board = makeRectBoard(7, 5, {["5:2"] = true})
    local priest = spawnPlayer(board, 3, 2, Player.Classes.MYSTERIOUS_PRIEST)
    local blockedBox = spawnBox(board, 4, 2)
    local trailingBox = spawnBox(board, 2, 2)

    assert(not run(board, priest, {x = 1, y = 0}))
    assertPosition(priest, 3, 2)
    assertPosition(blockedBox, 4, 2)
    assertPosition(trailingBox, 2, 2)
end

function tests.mysterious_priest_does_not_move_objects_when_pushed_as_a_block()
    local board = makeRectBoard(7, 5)
    local dwarf = spawnPlayer(board, 1, 2, Player.Classes.DWARF)
    local priest = spawnPlayer(board, 2, 2, Player.Classes.MYSTERIOUS_PRIEST)
    local box = spawnBox(board, 2, 3)

    assert(run(board, dwarf, {x = 1, y = 0}))
    assertPosition(dwarf, 2, 2)
    assertPosition(priest, 3, 2)
    assertPosition(box, 2, 3)
end

function tests.warrior_pushes_a_player_and_box_chain_without_using_player_abilities()
    local board = makeBoard(0, 7, 0)
    local warrior = spawnPlayer(board, 1, 0, Player.Classes.WARRIOR)
    local wizard = spawnPlayer(board, 2, 0, Player.Classes.WIZARD)
    local box = spawnBox(board, 3, 0)
    assert(run(board, warrior, {x = 1, y = 0}))
    assertPosition(warrior, 2, 0)
    assertPosition(wizard, 6, 0)
    assertPosition(box, 7, 0)
end

return tests
