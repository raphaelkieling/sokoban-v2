local json = require("vendor.json")

local Analytics = {}
Analytics.__index = Analytics

local SAVE_PATH = "analytics.json"

local function loveStorage()
	return {
		read = function(path) return love.filesystem.read(path) end,
		write = function(path, contents) return love.filesystem.write(path, contents) end,
	}
end

local function nonNegativeInteger(value)
	if type(value) ~= "number" or value < 0 then return 0 end
	return math.floor(value)
end

local function validPath(path)
	return type(path) == "string" and path ~= ""
end

function Analytics.new(events, storage)
	assert(events and type(events.on) == "function", "analytics requires an event emitter")
	local self = setmetatable({
		events = events,
		storage = storage or loveStorage(),
		stats = {
			sessions = 0,
			steps = 0,
			undos = 0,
			levelsStarted = 0,
			levelCompletions = 0,
			completedLevels = {},
			byLevel = {},
		},
		subscriptions = {},
	}, Analytics)
	self:load()
	self:subscribe()
	return self
end

function Analytics:load()
	local ok, contents = pcall(self.storage.read, SAVE_PATH)
	if not ok or type(contents) ~= "string" then return end
	local decoded, data = pcall(json.decode, contents)
	if not decoded or type(data) ~= "table" or type(data.stats) ~= "table" then return end

	local loaded = data.stats
	self.stats.sessions = nonNegativeInteger(loaded.sessions)
	self.stats.steps = nonNegativeInteger(loaded.steps)
	self.stats.undos = nonNegativeInteger(loaded.undos)
	self.stats.levelsStarted = nonNegativeInteger(loaded.levelsStarted)
	self.stats.levelCompletions = nonNegativeInteger(loaded.levelCompletions)
	for path, completed in pairs(type(loaded.completedLevels) == "table"
		and loaded.completedLevels or {}) do
		if validPath(path) and completed == true then
			self.stats.completedLevels[path] = true
		end
	end
	for path, record in pairs(type(loaded.byLevel) == "table" and loaded.byLevel or {}) do
		if validPath(path) and type(record) == "table" then
			self.stats.byLevel[path] = {
				steps = nonNegativeInteger(record.steps),
				undos = nonNegativeInteger(record.undos),
				starts = nonNegativeInteger(record.starts),
				completions = nonNegativeInteger(record.completions),
			}
		end
	end
end

function Analytics:recordLevel(levelPath)
	if not validPath(levelPath) then return nil end
	local record = self.stats.byLevel[levelPath]
	if not record then
		record = {steps = 0, undos = 0, starts = 0, completions = 0}
		self.stats.byLevel[levelPath] = record
	end
	return record
end

function Analytics:persist()
	local ok, contents = pcall(json.encode, {
		formatVersion = 1,
		stats = self.stats,
	})
	if not ok then return false end
	local wrote, success = pcall(self.storage.write, SAVE_PATH, contents)
	return wrote and success == true
end

function Analytics:subscribe()
	local function listen(eventName, callback)
		self.subscriptions[#self.subscriptions + 1] = self.events:on(eventName, callback)
	end

	listen("game.opened", function()
		self.stats.sessions = self.stats.sessions + 1
		self:persist()
	end)
	listen("level.started", function(payload)
		self.stats.levelsStarted = self.stats.levelsStarted + 1
		local record = self:recordLevel(payload.path)
		if record then record.starts = record.starts + 1 end
		self:persist()
	end)
	listen("player.moved", function(payload)
		if payload.stepTaken ~= true then return end
		self.stats.steps = self.stats.steps + 1
		local record = self:recordLevel(payload.level)
		if record then record.steps = record.steps + 1 end
		self:persist()
	end)
	listen("player.undo", function(payload)
		if payload.undone ~= true then return end
		self.stats.undos = self.stats.undos + 1
		local record = self:recordLevel(payload.level)
		if record then record.undos = record.undos + 1 end
		self:persist()
	end)
	listen("level.completed", function(payload)
		if not validPath(payload.level) then return end
		self.stats.levelCompletions = self.stats.levelCompletions + 1
		self.stats.completedLevels[payload.level] = true
		local record = self:recordLevel(payload.level)
		if record then record.completions = record.completions + 1 end
		self:persist()
	end)
end

function Analytics:completedLevelCount(levels)
	local count = 0
	for _, level in ipairs(levels or {}) do
		local path = level.key or level.path
		if self.stats.completedLevels[path] then count = count + 1 end
	end
	return count
end

return Analytics
