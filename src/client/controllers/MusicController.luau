--!strict
-- Plays the server's radio (see server RadioService): everyone hears the same song at the same
-- point, including players who join in the middle of it. Volume and mute only affect this player.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Music = require(ReplicatedStorage.Shared.Music)

local DRIFT_CHECK_SECONDS = 5

local MusicController = {}

local changedEvent = Instance.new("BindableEvent")
-- Fires with (title: string?, level: number, muted: boolean) when the song or volume changes.
MusicController.Changed = changedEvent.Event

local sound: Sound? = nil
local radio: Instance? = nil
local title: string? = nil
local level = Music.DefaultLevel
local muted = false
-- Bumped on every new song so work for an old song stops.
local playToken = 0
local fadeTween: Tween? = nil

local function fire()
	changedEvent:Fire(title, level, muted)
end

local function targetVolume(): number
	return if muted then 0 else Music.MaxVolume * level
end

local function stopFade()
	if fadeTween then
		fadeTween:Cancel()
		fadeTween = nil
	end
end

local function fadeTo(s: Sound, volume: number)
	stopFade()
	local t = TweenService:Create(s, TweenInfo.new(Music.FadeSeconds), { Volume = volume })
	fadeTween = t
	t:Play()
end

-- Where the song should be right now, in seconds from its start.
local function expectedPosition(): number?
	local startedAt = radio and radio:GetAttribute("StartedAt")
	if typeof(startedAt) ~= "number" then
		return nil
	end
	return Workspace:GetServerTimeNow() - startedAt
end

local function syncToRadio()
	local s = sound
	local r = radio
	if not s or not r then
		return
	end
	local trackId = r:GetAttribute("TrackId")
	if typeof(trackId) ~= "number" then
		return
	end

	playToken += 1
	local token = playToken
	local songTitle = r:GetAttribute("Title")
	title = if typeof(songTitle) == "string" then songTitle else nil
	fire()

	s:Stop()
	s.Volume = 0
	s.SoundId = `rbxassetid://{trackId}`
	if not s.IsLoaded then
		s.Loaded:Wait()
	end
	if token ~= playToken then
		return
	end

	local position = expectedPosition() or 0
	if position >= s.TimeLength then
		-- This song already ended; the next one is coming.
		return
	end
	s.TimePosition = math.max(position, 0)
	s:Play()
	fadeTo(s, targetVolume())
end

-- Pulls the song back in line if it drifted (lag spike, the game was in the background, etc.).
local function correctDrift()
	local s = sound
	local position = expectedPosition()
	if not s or not s.Playing or not position or position >= s.TimeLength then
		return
	end
	if math.abs(s.TimePosition - position) > Music.MaxDriftSeconds then
		s.TimePosition = position
	end
end

function MusicController.getCurrent(): (string?, number, boolean)
	return title, level, muted
end

-- Sets this player's volume, 0 to 1. Changes right away (no fade) so the slider feels direct.
function MusicController.setLevel(value: number)
	level = math.clamp(value, 0, 1)
	muted = level == 0
	if sound and sound.Playing then
		stopFade()
		sound.Volume = targetVolume()
	end
	fire()
end

function MusicController.setMuted(value: boolean)
	muted = value
	-- Unmuting a slider that was dragged to 0 brings it back to the default.
	if not muted and level == 0 then
		level = Music.DefaultLevel
	end
	if sound then
		fadeTo(sound, targetVolume())
	end
	fire()
end

function MusicController.toggleMute()
	MusicController.setMuted(not muted)
end

function MusicController.start()
	local s = Instance.new("Sound")
	s.Name = "BackgroundMusic"
	s.Looped = false
	s.Volume = 0
	s.Parent = SoundService
	sound = s

	task.spawn(function()
		local r = ReplicatedStorage:WaitForChild(Music.RadioFolder)
		radio = r
		-- The server sets StartedAt last, so this fires once per song.
		r:GetAttributeChangedSignal("StartedAt"):Connect(function()
			task.spawn(syncToRadio)
		end)
		task.spawn(syncToRadio)

		while true do
			task.wait(DRIFT_CHECK_SECONDS)
			correctDrift()
		end
	end)
end

return MusicController
