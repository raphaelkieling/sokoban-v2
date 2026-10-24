local GameObject = require("src.core.GameObject")
local Character = require("src.components.Character")
local Transform = require("src.components.Transform")
local InteractiveObject = require("src.components.InteractiveObject")
local Player = require("src.components.Player")
local CharacterMovement = require("src.components.CharacterMovement")
local StateMachine = require("src.components.StateMachine")
local Animation = require("src.components.Animation")
local MovementEffects = require("src.components.MovementEffects")
local Sinkable = require("src.components.Sinkable")
local CharacterClasses = require("src.characters.Classes")
local PlayerStates = require("src.characters.PlayerStates")

local CharacterFactory = {}

function CharacterFactory.create(classId, x, y, assets)
	local class = CharacterClasses.create(classId)
	local object = GameObject("Player " .. class.name)
	object:addComponent(Transform(x, y, 64, 3))
	object:addComponent(InteractiveObject())
	object:addComponent(Sinkable())

	local character = Character()
	object:addComponent(character)
	local player = Player()
	character:addComponent(player)
	player:setClass(class)
	character:addComponent(CharacterMovement())
	character:addComponent(StateMachine(PlayerStates, "idle"))
	character:addComponent(Animation(assets:playerAnimation(class.sprite.x, class.sprite.y)))
	character:addComponent(assets:playerRenderer(class.sprite.scale, 3))
	character:addComponent(MovementEffects())
	player:updateAppearance(class, assets)
	return object
end

return CharacterFactory
