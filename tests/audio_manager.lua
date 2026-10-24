local AudioManager = require("src.audio.AudioManager")

local tests = {}

function tests.mute_toggle_updates_all_audio_sources()
	local previousLove = love
	local createdSources = {}
	_G.love = {
		audio = {
			newSource = function(path, sourceType)
				local source = {
					path = path,
					type = sourceType,
					volume = nil,
					setVolume = function(self, volume) self.volume = volume end,
				}
				createdSources[#createdSources + 1] = source
				return source
			end,
		},
	}

	local manager = AudioManager.new({
		click = {file = "click.wav", volume = 0.6},
	})
	assert(createdSources[1].volume == 0.6)

	manager:setMuted(true)
	assert(createdSources[1].volume == 0, "muting should silence the source")
	manager:setMuted(false)
	assert(createdSources[1].volume == 0.6, "unmuting should restore the source volume")

	_G.love = previousLove
end

function tests.music_volume_controls_only_registered_music_sources()
	local previousLove = love
	_G.love = {audio = {}}
	local manager = AudioManager.new({})
	local source = {setVolume = function(self, volume) self.volume = volume end}
	manager:registerMusicSource(source, 0.8)
	assert(math.abs(source.volume - 0.6) < 0.000001)
	manager:setMusicVolume(0.25)
	assert(math.abs(source.volume - 0.2) < 0.000001)
	manager:setMuted(true)
	assert(source.volume == 0)
	manager:setMuted(false)
	assert(math.abs(source.volume - 0.2) < 0.000001)
	_G.love = previousLove
end

return tests
