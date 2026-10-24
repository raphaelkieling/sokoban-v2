local Analytics = require("src.game.Analytics")
local EventEmitter = require("src.core.EventEmitter")
local json = require("vendor.json")

local tests = {}

local function memoryStorage(initialContents)
	local storage = {contents = initialContents, writes = 0}
	function storage.read() return storage.contents end
	function storage.write(_, contents)
		storage.contents = contents
		storage.writes = storage.writes + 1
		return true
	end
	return storage
end

function tests.analytics_records_gameplay_events_and_persists_aggregates()
	local storage = memoryStorage()
	local events = EventEmitter.new()
	local analytics = Analytics.new(events, storage)
	local observedMoves = 0
	events:on("player.moved", function() observedMoves = observedMoves + 1 end)

	events:emit("game.opened", {})
	events:emit("level.started", {path = "Map.ldtk#Level_0"})
	events:emit("player.moved", {level = "Map.ldtk#Level_0", moved = false, stepTaken = false})
	events:emit("player.moved", {level = "Map.ldtk#Level_0", moved = true, stepTaken = false})
	events:emit("player.moved", {level = "Map.ldtk#Level_0", moved = true, stepTaken = true})
	events:emit("player.undo", {level = "Map.ldtk#Level_0", undone = false})
	events:emit("player.undo", {level = "Map.ldtk#Level_0", undone = true})
	events:emit("level.completed", {level = "Map.ldtk#Level_0"})
	events:emit("level.completed", {level = "Map.ldtk#Level_0"})

	assert(analytics.stats.sessions == 1)
	assert(analytics.stats.levelsStarted == 1)
	assert(analytics.stats.steps == 1 and analytics.stats.undos == 1,
		"failed moves and failed undo attempts should not count")
	assert(analytics.stats.levelCompletions == 2,
		"replaying a level should count each completion event")
	assert(analytics.stats.byLevel["Map.ldtk#Level_0"].steps == 1
		and analytics.stats.byLevel["Map.ldtk#Level_0"].undos == 1)
	assert(analytics:completedLevelCount({
		{key = "Map.ldtk#Level_0"}, {key = "Map.ldtk#Level_1"},
	}) == 1, "completion percentage should use unique completed levels")
	assert(observedMoves == 3,
		"the analytics listener should not consume movement events from other listeners")

	local decoded = json.decode(storage.contents)
	assert(decoded.formatVersion == 1 and storage.writes > 0)
	local restored = Analytics.new(EventEmitter.new(), storage)
	assert(restored.stats.steps == 1 and restored.stats.undos == 1)
	assert(restored.stats.completedLevels["Map.ldtk#Level_0"] == true)
end

function tests.analytics_ignores_corrupt_saved_data()
	local analytics = Analytics.new(EventEmitter.new(), memoryStorage("{broken"))
	assert(analytics.stats.steps == 0 and analytics.stats.undos == 0)
	assert(next(analytics.stats.completedLevels) == nil)
end

return tests
