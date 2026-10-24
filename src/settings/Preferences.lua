local json = require("vendor.json")

local Preferences = {}
Preferences.__index = Preferences

local SAVE_PATH = "preferences.json"
local DEFAULTS = {
    fullscreen = false,
    musicVolume = 0.75,
    muted = false,
    language = "pt",
}
local LANGUAGES = {pt = true, en = true, es = true}

local function loveStorage()
    return {
        read = function(path) return love.filesystem.read(path) end,
        write = function(path, contents) return love.filesystem.write(path, contents) end,
    }
end

function Preferences.new(storage)
    local self = setmetatable({storage = storage or loveStorage(), values = {}}, Preferences)
    for key, value in pairs(DEFAULTS) do self.values[key] = value end
    self:load()
    return self
end

function Preferences:load()
    local ok, contents = pcall(self.storage.read, SAVE_PATH)
    if not ok or type(contents) ~= "string" then return end
    local decoded, data = pcall(json.decode, contents)
    if not decoded or type(data) ~= "table" then return end

    if type(data.fullscreen) == "boolean" then self.values.fullscreen = data.fullscreen end
    if type(data.muted) == "boolean" then self.values.muted = data.muted end
    if type(data.musicVolume) == "number" then
        self.values.musicVolume = math.max(0, math.min(1, data.musicVolume))
    end
    if LANGUAGES[data.language] then self.values.language = data.language end
end

function Preferences:get(key)
    return self.values[key]
end

function Preferences:set(key, value)
    if key == "fullscreen" or key == "muted" then
        if type(value) ~= "boolean" then return false end
    elseif key == "musicVolume" then
        value = tonumber(value)
        if not value then return false end
        value = math.max(0, math.min(1, value))
    elseif key == "language" then
        if not LANGUAGES[value] then return false end
    else
        return false
    end

    self.values[key] = value
    local ok, contents = pcall(json.encode, self.values)
    if not ok then return false end
    local wrote, success = pcall(self.storage.write, SAVE_PATH, contents)
    return wrote and success == true
end

return Preferences
