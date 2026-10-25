local AudioManager = require("src.audio.AudioManager")
local SoundCatalog = require("src.audio.SoundCatalog")

local tests = {}

function tests.menu_sounds_use_their_dedicated_assets()
	assert(SoundCatalog.menuSelect.file == "assets/sounds/menu_select.mp3")
	assert(SoundCatalog.menuClick.file == "assets/sounds/menu_click.mp3")
end

function tests.class_voice_catalogs_have_four_english_clips_per_character()
    local Classes = require("src.characters.Classes")
    local voicePools = {
        dwarf = {name = "dwarfVoice", directory = "dwarf"},
        wizard = {name = "wizardVoice", directory = "wizard"},
        warrior = {name = "warriorVoice", directory = "warrior"},
        farmer = {name = "farmerVoice", directory = "farmer"},
        mysterious_priest = {name = "mysteriousPriestVoice", directory = "mysterious_priest"},
        puppeteer = {name = "puppeteerVoice", directory = "puppeteer"},
    }

    for classId, voice in pairs(voicePools) do
        local pool = assert(SoundCatalog[voice.name])
        local files = assert(pool.localizedFiles.en,
            classId .. " should have an English fallback voice pool")
        assert(#files == 4, classId .. " should have four selection voice clips")
        assert(Classes.create(classId).selectionVoiceSound == voice.name,
            classId .. " should use its own selection voice pool")
        for _, file in ipairs(files) do
            assert(file:match("^assets/sounds/classes/en/" .. voice.directory .. "/.*%.mp3$"))
            local audio = assert(io.open(file, "rb"), "missing voice file: " .. file)
            audio:close()
        end
    end
end

function tests.wizard_voice_pool_uses_full_volume()
	assert(SoundCatalog.wizardVoice.volume == 1.0,
		"Wizard voice clips should use full volume to stay audible")
end

function tests.localized_voice_uses_current_language_and_falls_back_to_english()
	local previousLove = love
	local playedFiles = {}
	_G.love = {
		audio = {
			newSource = function(path)
				return {
					path = path,
					setVolume = function() end,
					isPlaying = function() return false end,
					play = function(self) playedFiles[#playedFiles + 1] = self.path end,
				}
			end,
		},
	}

	local manager = AudioManager.new({
		characterVoice = {
			localizedFiles = {
				en = {"english.mp3"},
				pt = {"portuguese.mp3"},
			},
		},
	}, {get = function(_, key) return key == "language" and "pt" or nil end})
	local currentLanguagePlayed = manager:playRandom("characterVoice")
	local fallbackPlayed = manager:playRandom("characterVoice", "es")
	_G.love = previousLove

	assert(currentLanguagePlayed and playedFiles[1] == "portuguese.mp3",
		"a translated pool should be used when it exists")
	assert(fallbackPlayed and playedFiles[2] == "english.mp3",
		"missing translations should use the English pool")
end

function tests.random_audio_does_not_repeat_the_previous_variant()
    local previousLove, previousRandom = love, math.random
    local playedPaths = {}
    local function makeSource(path)
        return {
            path = path,
            setVolume = function(self, volume) self.volume = volume end,
            isPlaying = function(self) return self.playing == true end,
            play = function(self)
                self.playing = true
                playedPaths[#playedPaths + 1] = self.path
            end,
            clone = function(self) return makeSource(self.path) end,
        }
    end
    _G.love = {audio = {newSource = function(path) return makeSource(path) end}}
    math.random = function() return 1 end

    local manager = AudioManager.new({
        voice = {files = {"one.mp3", "two.mp3", "three.mp3", "four.mp3"}},
    })
    assert(manager:playRandom("voice") == true)
    assert(manager:playRandom("voice") == true)
    assert(playedPaths[1] == "one.mp3")
    assert(playedPaths[2] == "two.mp3", "consecutive random selections should differ")
    assert(manager:playRandom("missing") == false)

    math.random = previousRandom
    _G.love = previousLove
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
