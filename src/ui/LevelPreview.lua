local LevelPreview = {}

function LevelPreview.fit(viewWidth, viewHeight, mapWidth, mapHeight, padding)
	padding = padding or 0
	local availableWidth = math.max(0, viewWidth - padding * 2)
	local availableHeight = math.max(0, viewHeight - padding * 2)
	local scale = math.min(availableWidth / mapWidth, availableHeight / mapHeight)
	local width, height = mapWidth * scale, mapHeight * scale
	return (viewWidth - width) / 2, (viewHeight - height) / 2, scale
end

return LevelPreview
