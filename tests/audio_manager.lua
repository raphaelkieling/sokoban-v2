local AudioManager = require("src.audio.AudioManager")
local SoundCatalog = require("src.audio.SoundCatalog")

local tests = {}

function tests.menu_sounds_use_their_dedicated_assets()
	assert(SoundCatalog.menuSelect.file == "assets/sounds/menu_select.mp3")
	assert(SoundCatalog.menuClick.file == "assets/sounds/menu_click.mp3")
end

function tests.walking_uses_the_footstep_asset()
	assert(SoundCatalog.move.file == "assets/sounds/footstep.mp3")
end

function tests.farmer_grass_sound_uses_the_cut_and_grow_asset()
	assert(SoundCatalog.grassChange.file == "assets/sounds/grass_cut_grow.mp3")
end

function tests.fire_and_fall_sounds_use_their_dedicated_assets()
	assert(SoundCatalog.grassFire.file == "assets/sounds/grass_fire.mp3")
	assert(SoundCatalog.bodyFall.file == "assets/sounds/body_fall.mp3")
end

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

function tests.main_theme_streams_loops_and_starts_with_music_volume()
	local previousLove = love
	local createdSource
	_G.love = {
		audio = {
			newSource = function(path, sourceType)
				createdSource = {
					path = path,
					type = sourceType,
					setVolume = function(self, volume) self.volume = volume end,
					setLooping = function(self, looping) self.looping = looping end,
					play = function(self) self.playing = true end,
				}
				return createdSource
			end,
		},
	}

	local manager = AudioManager.new({})
	manager:playMusic("assets/music/Pixel 3.mp3")
	assert(createdSource.type == "stream", "music should use a streaming source")
	assert(createdSource.looping == true, "main theme should loop")
	assert(createdSource.playing == true, "main theme should start playing")
	assert(createdSource.volume == manager:getMusicVolume(), "music should use the music volume setting")

	_G.love = previousLove
end

return tests
