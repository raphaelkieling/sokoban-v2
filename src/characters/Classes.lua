local Classes = {
    DWARF = "dwarf",
    WIZARD = "wizard",
    WARRIOR = "warrior",
    TELEKINETIC = "telekinetic",
    SORCERER = "sorcerer",
    MYSTERIOUS_PRIEST = "mysterious_priest",
    FARMER = "farmer",
    PUPPETEER = "puppeteer",
}

local implementations = {
    [Classes.DWARF] = require("src.characters.classes.Dwarf"),
    [Classes.WIZARD] = require("src.characters.classes.Wizard"),
    [Classes.WARRIOR] = require("src.characters.classes.Warrior"),
    [Classes.TELEKINETIC] = require("src.characters.classes.Telekinetic"),
    [Classes.SORCERER] = require("src.characters.classes.Sorcerer"),
    [Classes.MYSTERIOUS_PRIEST] = require("src.characters.classes.MysteriousPriest"),
    [Classes.FARMER] = require("src.characters.classes.Farmer"),
    [Classes.PUPPETEER] = require("src.characters.classes.Puppeteer"),
}

function Classes.create(classId)
    local implementation = assert(implementations[classId], "unknown character class: " .. tostring(classId))
    return implementation()
end

function Classes.register(classId, implementation)
    assert(type(classId) == "string" and classId ~= "", "class id must be a non-empty string")
    assert(type(implementation) == "table" and implementation.id == classId
        and type(rawget(implementation, "move")) == "function",
        "class implementation must define the matching id and move method")
    implementations[classId] = implementation
end

return Classes
