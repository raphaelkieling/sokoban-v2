local CharacterClass = require("src.characters.CharacterClass")

local Warrior = CharacterClass:extend()
Warrior.id = "warrior"
Warrior.name = "Warrior"
Warrior.selectionVoiceSound = "warriorVoice"
Warrior.sprite = {x = 4, y = 1, scale = 2.25}

function Warrior:move(movement, actor, direction, destination)
    return movement:pushChain(actor, destination, direction)
end

return Warrior
