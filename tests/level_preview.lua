local LevelPreview = require("src.ui.LevelPreview")

local tests = {}

function tests.map_preview_fits_without_distorting_or_cropping()
	local x, y, scale = LevelPreview.fit(480, 270, 640, 360, 8)
	assert(math.abs(scale - 254 / 360) < 0.000001)
	assert(x > 8 and math.abs(y - 8) < 0.000001)

	local wideX, wideY, wideScale = LevelPreview.fit(480, 270, 1280, 360, 8)
	assert(math.abs(wideScale - 0.3625) < 0.000001)
	assert(math.abs(wideX - 8) < 0.000001 and wideY > 8,
		"wide maps should be centered and use the available width")
end

return tests
