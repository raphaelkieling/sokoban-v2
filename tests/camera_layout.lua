local PlayingScene = require("src.screens.PlayingScene")

local tests = {}

function tests.map_camera_fits_the_ldtk_world_without_content_bounds_or_padding()
	local previousLove = rawget(_G, "love")
	_G.love = {graphics = {getDimensions = function() return 1280, 720 end}}
	local ok, x, y, zoom = pcall(PlayingScene.mapCameraTarget, {
		board = {mapWorldWidth = 1280, mapWorldHeight = 720},
	})
	_G.love = previousLove
	assert(ok, x)
	assert(x == 640 and y == 360 and zoom == 1,
		"the default camera should show the complete 640x360 LDtk world at 16:9")
end

return tests
