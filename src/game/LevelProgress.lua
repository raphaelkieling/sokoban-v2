local json = require("vendor.json")

local LevelProgress = {}
LevelProgress.__index = LevelProgress

local SAVE_PATH = "level-progress.json"

local function loveStorage()
	return {
		read = function(path) return love.filesystem.read(path) end,
		write = function(path, contents) return love.filesystem.write(path, contents) end,
	}
end

local function saveCompletedLevels(self)
	local ok, contents = pcall(json.encode, {
		formatVersion = 1,
		completedLevels = self.completedLevels,
	})
	if not ok then return false end

	local wrote, success = pcall(self.storage.write, SAVE_PATH, contents)
	return wrote and success == true
end

function LevelProgress.new(storage)
	local self = setmetatable({
		storage = storage or loveStorage(),
		completedLevels = {},
	}, LevelProgress)
	self:load()
	return self
end

function LevelProgress:load()
	local ok, contents = pcall(self.storage.read, SAVE_PATH)
	if not ok or type(contents) ~= "string" then return end

	local decoded, data = pcall(json.decode, contents)
	if not decoded or type(data) ~= "table" or type(data.completedLevels) ~= "table" then return end

	for path, completed in pairs(data.completedLevels) do
		if type(path) == "string" and completed == true then
			self.completedLevels[path] = true
		end
	end
end

function LevelProgress:isCompleted(levelPath)
	return self.completedLevels[levelPath] == true
end

function LevelProgress:isUnlocked(levels, levelIndex)
	if type(levels) ~= "table" or type(levelIndex) ~= "number"
		or levelIndex % 1 ~= 0 or levelIndex < 1 or not levels[levelIndex] then
		return false
	end
	if levelIndex == 1 then return true end

	local previousLevel = levels[levelIndex - 1]
	local previousKey = previousLevel and (previousLevel.key or previousLevel.path)
	return previousKey ~= nil and self:isCompleted(previousKey)
end

function LevelProgress:markCompleted(levelPath)
	if type(levelPath) ~= "string" or levelPath == "" then return false end
	self.completedLevels[levelPath] = true
	return saveCompletedLevels(self)
end

function LevelProgress:markAllCompleted(levels)
	if type(levels) ~= "table" then return false, 0 end

	local previous = {}
	for levelPath, completed in pairs(self.completedLevels) do
		previous[levelPath] = completed
	end

	local count = 0
	for _, level in ipairs(levels) do
		local levelPath = level.key or level.path
		if type(levelPath) == "string" and levelPath ~= "" then
			if not self.completedLevels[levelPath] then count = count + 1 end
			self.completedLevels[levelPath] = true
		end
	end

	if saveCompletedLevels(self) then return true, count end
	for levelPath in pairs(self.completedLevels) do
		self.completedLevels[levelPath] = nil
	end
	for levelPath, completed in pairs(previous) do
		self.completedLevels[levelPath] = completed
	end
	return false, 0
end

function LevelProgress:reset()
	local ok, contents = pcall(json.encode, {
		formatVersion = 1,
		completedLevels = {},
	})
	if not ok then return false end

	local wrote, success = pcall(self.storage.write, SAVE_PATH, contents)
	if not wrote or success ~= true then return false end
	for levelPath in pairs(self.completedLevels) do
		self.completedLevels[levelPath] = nil
	end
	return true
end

return LevelProgress
