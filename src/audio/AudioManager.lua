local SoundCatalog = require("src.audio.SoundCatalog")
local AudioConfig = require("src.settings.AudioConfig")

local AudioManager = {}
AudioManager.__index = AudioManager

local SAMPLE_RATE = 22050

local function synthesize(profile)
    local sampleCount = math.floor(profile.duration * SAMPLE_RATE)
    local soundData = love.sound.newSoundData(sampleCount, SAMPLE_RATE, 16, 1)
    local frequencyChange = profile.endFrequency - profile.startFrequency
    local filteredNoise = 0

	for sample = 0, sampleCount - 1 do
		local time = sample / SAMPLE_RATE
		local progress = time / profile.duration
		local phase = 2 * math.pi * (profile.startFrequency * time
            + frequencyChange * time * time / (2 * profile.duration))
        local envelope = math.exp(-profile.decay * time) * math.min(1, time * 500)
        local tone = math.sin(phase) + math.sin(phase * 2.01) * profile.harmonic
        local noise = math.sin(sample * 12.9898) * math.sin(sample * 78.233)
        local value
        if profile.style == "plateClick" then
            local ring = math.sin(2 * math.pi * profile.startFrequency * time)
                    * math.exp(-profile.decay * time)
                + math.sin(2 * math.pi * profile.endFrequency * time)
                    * profile.harmonic * math.exp(-profile.decay * 1.35 * time)
            local transient = noise * profile.noise * math.exp(-profile.clickDecay * time)
            value = (ring + transient) * math.min(1, time * 500) * 0.68
        elseif profile.style == "rewind" then
            local cutoff = 3400 - 1900 * progress
            local filterAmount = math.min(1, 2 * math.pi * cutoff / SAMPLE_RATE)
            filteredNoise = filteredNoise + (noise - filteredNoise) * filterAmount
            local flutter = 0.78 + 0.22 * math.sin(2 * math.pi * profile.flutter * time)
            value = (tone * 0.18 + filteredNoise * profile.noise * (1 - progress))
                * envelope * flutter * 0.72
        elseif profile.style == "ui" then
            local attack = math.min(1, time * 75)
            local warmth = math.sin(phase) + math.sin(phase * 2) * profile.harmonic
            value = warmth * math.exp(-profile.decay * time) * attack * 0.52
        else
            value = (tone + noise * profile.noise) * envelope * 0.62
        end
        soundData:setSample(sample, math.max(-1, math.min(1, value)))
    end

    return soundData
end

local function createSource(definition)
    if definition.file then
        return love.audio.newSource(definition.file, "static")
    end
    return love.audio.newSource(synthesize(definition.synthesis))
end

local function createVariants(files, definition)
    local variants = {}
    if files then
        for _, file in ipairs(files) do
            variants[#variants + 1] = {sources = {createSource({file = file})}}
        end
    elseif definition then
        variants[1] = {sources = {createSource(definition)}}
    end
    return variants
end

function AudioManager.new(catalog, preferences)
    local muted = AudioConfig.muted == true
    local musicVolume = AudioConfig.musicVolume or 1
    if preferences then
        muted = preferences:get("muted") == true
        musicVolume = preferences:get("musicVolume") or musicVolume
    end
    local self = setmetatable({
        sources = {},
        musicSources = {},
        musicPlaylist = nil,
        musicPlaylistIndex = nil,
        preferences = preferences,
        volume = math.max(0, math.min(1, AudioConfig.volume)),
        musicVolume = math.max(0, math.min(1, musicVolume)),
        muted = muted,
    }, AudioManager)
    for name, definition in pairs(catalog or SoundCatalog) do
        local baseVolume = definition.volume or 1
        local localizedVariants = {}
        if definition.localizedFiles then
            for language, files in pairs(definition.localizedFiles) do
                localizedVariants[language] = createVariants(files)
            end
        else
            localizedVariants.default = createVariants(definition.files, definition)
        end

        local defaultVariants = localizedVariants.default or localizedVariants.en
        if not defaultVariants then
            for _, variants in pairs(localizedVariants) do
                defaultVariants = variants
                break
            end
        end
        defaultVariants = defaultVariants or {}

        local sources = {}
        for _, variants in pairs(localizedVariants) do
            for _, variant in ipairs(variants) do
                local source = variant.sources[1]
                source:setVolume(baseVolume * self:_effectiveVolume())
                sources[#sources + 1] = source
            end
        end
        self.sources[name] = {
            sources = sources,
            variants = defaultVariants,
            localizedVariants = localizedVariants,
            baseVolume = baseVolume,
            lastRandomVariant = nil,
        }
    end
    return self
end

function AudioManager:_effectiveVolume()
    return self.muted and 0 or self.volume
end

function AudioManager:_applyVolume(pool)
    local volume = pool.baseVolume * self:_effectiveVolume()
    for _, source in ipairs(pool.sources) do source:setVolume(volume) end
end

function AudioManager:_applyMusicVolume(entry)
    entry.source:setVolume(entry.baseVolume * (self.muted and 0 or self.musicVolume))
end

function AudioManager:registerMusicSource(source, baseVolume)
    local entry = {source = source, baseVolume = baseVolume or 1}
    self.musicSources[#self.musicSources + 1] = entry
    self:_applyMusicVolume(entry)
    return source
end

function AudioManager:playMusic(file, baseVolume)
	self.musicPlaylist = nil
	self.musicPlaylistIndex = nil
    local source = love.audio.newSource(file, "stream")
    source:setLooping(true)
    self:registerMusicSource(source, baseVolume)
    source:play()
    return source
end

function AudioManager:playMusicPlaylist(files, baseVolume)
	if type(files) ~= "table" or #files == 0 then return false end
	for _, entry in ipairs(self.musicSources) do
		if entry.source.stop then entry.source:stop() end
	end
	self.musicSources = {}
	self.musicPlaylist = {}
	self.musicPlaylistIndex = 0
	for _, file in ipairs(files) do
		local source = love.audio.newSource(file, "stream")
		source:setLooping(false)
		self.musicPlaylist[#self.musicPlaylist + 1] = self:registerMusicSource(source, baseVolume)
	end
	self:_playNextMusicTrack()
	return true
end

function AudioManager:playMusicDirectory(directory, baseVolume)
	local files = {}
	local supportedExtensions = {mp3 = true, ogg = true, wav = true, flac = true}
	for _, name in ipairs(love.filesystem.getDirectoryItems(directory)) do
		local extension = name:lower():match("%.([%w]+)$")
		if supportedExtensions[extension] then
			files[#files + 1] = directory .. "/" .. name
		end
	end
	table.sort(files)
	return self:playMusicPlaylist(files, baseVolume)
end

function AudioManager:_playNextMusicTrack()
	if not self.musicPlaylist or #self.musicPlaylist == 0 then return false end
	self.musicPlaylistIndex = self.musicPlaylistIndex % #self.musicPlaylist + 1
	local source = self.musicPlaylist[self.musicPlaylistIndex]
	self.currentMusicSource = source
	source:play()
	return true
end

function AudioManager:update()
	if self.musicPlaylist and self.currentMusicSource
		and not self.currentMusicSource:isPlaying() then
		self:_playNextMusicTrack()
	end
end

function AudioManager:getVolume()
    return self.volume
end

function AudioManager:setVolume(volume)
    self.volume = math.max(0, math.min(1, tonumber(volume) or self.volume))
    for _, pool in pairs(self.sources) do self:_applyVolume(pool) end
end

function AudioManager:getMusicVolume()
    return self.musicVolume
end

function AudioManager:setMusicVolume(volume)
    self.musicVolume = math.max(0, math.min(1, tonumber(volume) or self.musicVolume))
    for _, entry in ipairs(self.musicSources) do self:_applyMusicVolume(entry) end
end

function AudioManager:isMuted()
    return self.muted
end

function AudioManager:setMuted(muted)
    self.muted = muted == true
    for _, pool in pairs(self.sources) do self:_applyVolume(pool) end
    for _, entry in ipairs(self.musicSources) do self:_applyMusicVolume(entry) end
end

function AudioManager:toggleMuted()
    self:setMuted(not self.muted)
end

function AudioManager:play(name)
    local entry = self.sources[name]
    local pool = entry and entry.sources
    if not pool then return false end

    for _, source in ipairs(pool) do
        if not source:isPlaying() then
            source:play()
            return true
        end
    end

    local source = pool[1]:clone()
    source:setVolume(entry.baseVolume * self:_effectiveVolume())
    pool[#pool + 1] = source
    source:play()
    return true
end

function AudioManager:playRandom(name, language)
    local entry = self.sources[name]
    if not entry then return false end
    language = language or (self.preferences and self.preferences:get("language"))
    local variants = entry.localizedVariants[language]
        or entry.localizedVariants.en
        or entry.localizedVariants.default
        or entry.variants
    if not variants or #variants == 0 then return false end

    local variantIndex
    if #variants == 1 then
        variantIndex = 1
    else
        variantIndex = math.random(#variants - 1)
        if entry.lastRandomVariant and variantIndex >= entry.lastRandomVariant then
            variantIndex = variantIndex + 1
        end
    end
    entry.lastRandomVariant = variantIndex

    local variant = variants[variantIndex]
    local source
    for _, candidate in ipairs(variant.sources) do
        if not candidate:isPlaying() then
            source = candidate
            break
        end
    end
    if not source then
        source = variant.sources[1]:clone()
        source:setVolume(entry.baseVolume * self:_effectiveVolume())
        variant.sources[#variant.sources + 1] = source
        entry.sources[#entry.sources + 1] = source
    end
    source:play()
    return true
end

return AudioManager
