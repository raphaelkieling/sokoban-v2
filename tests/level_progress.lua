local LevelProgress = require("src.game.LevelProgress")

local tests = {}

local function memoryStorage(contents)
	local storage = {contents = contents}
	storage.read = function(_path) return storage.contents end
	storage.write = function(_path, value)
			storage.contents = value
			return true, #value
	end
	return storage
end

function tests.completed_levels_are_saved_and_restored()
	local storage = memoryStorage()
	local progress = LevelProgress.new(storage)

	assert(progress:markCompleted("maps-v2/Map.ldtk#Level_0"))
	assert(progress:isCompleted("maps-v2/Map.ldtk#Level_0"))

	local loadedProgress = LevelProgress.new(storage)
	assert(loadedProgress:isCompleted("maps-v2/Map.ldtk#Level_0"))
	assert(not loadedProgress:isCompleted("maps-v2/Map.ldtk#Level_1"))
end

function tests.invalid_save_data_is_ignored()
	local progress = LevelProgress.new(memoryStorage("not json"))
	assert(not progress:isCompleted("maps-v2/Map.ldtk#Level_0"))
end

function tests.levels_unlock_in_order_after_the_previous_level_is_completed()
	local progress = LevelProgress.new(memoryStorage())
	local levels = {
		{key = "level-1"},
		{key = "level-2"},
		{key = "level-3"},
	}

	assert(progress:isUnlocked(levels, 1), "the first level should start unlocked")
	assert(not progress:isUnlocked(levels, 2), "the next level should start locked")
	assert(progress:markCompleted("level-1"))
	assert(progress:isUnlocked(levels, 2), "completing a level should unlock its successor")
	assert(not progress:isUnlocked(levels, 3), "later levels should still require their direct predecessor")
	assert(progress:markCompleted("level-2"))
	assert(progress:isUnlocked(levels, 3))
end

function tests.nonexistent_levels_are_never_unlocked()
	local progress = LevelProgress.new(memoryStorage())
	assert(not progress:isUnlocked({{key = "level-1"}}, 0))
	assert(not progress:isUnlocked({{key = "level-1"}}, 2))
end

function tests.reset_clears_and_persists_completed_level_progress()
	local storage = memoryStorage()
	local progress = LevelProgress.new(storage)
	local sharedCompletedLevels = progress.completedLevels
	assert(progress:markCompleted("level-1"))
	assert(progress:markCompleted("level-2"))

	assert(progress:reset())
	assert(next(progress.completedLevels) == nil)
	assert(progress.completedLevels == sharedCompletedLevels,
		"reset should preserve references held by Game")
	local restored = LevelProgress.new(storage)
	assert(next(restored.completedLevels) == nil,
		"reset should persist an empty completed-level list")
end

function tests.mark_all_completed_persists_all_available_levels_in_one_write()
	local storage = memoryStorage()
	local writes = 0
	local write = storage.write
	storage.write = function(path, contents)
		writes = writes + 1
		return write(path, contents)
	end
	local progress = LevelProgress.new(storage)
	local sharedCompletedLevels = progress.completedLevels
	local saved, count = progress:markAllCompleted({
		{key = "level-1"},
		{path = "level-2"},
		{key = "level-1"},
	})
	assert(saved and count == 2)
	assert(progress:isCompleted("level-1") and progress:isCompleted("level-2"))
	assert(progress.completedLevels == sharedCompletedLevels)
	assert(writes == 1, "all completions should be persisted in one write")
end

return tests
