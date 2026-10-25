local CharacterClass = require("src.characters.CharacterClass")

local Dwarf = CharacterClass:extend()
Dwarf.id = "dwarf"
Dwarf.name = "Dwarf"
Dwarf.selectionVoiceSound = "dwarfVoice"
Dwarf.sprite = {x = 0, y = 0, scale = 2.25}

function Dwarf:move(movement, actor, direction, destination)
    return movement:pushChain(actor, destination, direction, 1, 1)
end

return Dwarf
