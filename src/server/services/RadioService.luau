--!strict
-- One radio for the whole server: picks the song and when it started, so every player hears the
-- same part of the same song (see client MusicController).
--
-- Songs play in shuffled order without repeats until the whole playlist has played.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Music = require(ReplicatedStorage.Shared.Music)

type Track = Music.Track

local RadioService = {}

local rng = Random.new()
local queue: { Track } = {}
local lastId: number? = nil

local function refillQueue()
	queue = table.clone(Music.Playlist)
	rng:Shuffle(queue)
	-- Don't play the same song twice in a row across a reshuffle.
	if #queue > 1 and queue[#queue].Id == lastId then
		queue[1], queue[#queue] = queue[#queue], queue[1]
	end
end

local function nextTrack(): Track
	if #queue == 0 then
		refillQueue()
	end
	local track = table.remove(queue) :: Track
	lastId = track.Id
	return track
end

function RadioService.start()
	if #Music.Playlist == 0 then
		return
	end

	local folder = Instance.new("Folder")
	folder.Name = Music.RadioFolder
	folder.Parent = ReplicatedStorage

	task.spawn(function()
		while true do
			local track = nextTrack()
			-- StartedAt is set last: clients start the song when it changes.
			folder:SetAttribute("TrackId", track.Id)
			folder:SetAttribute("Title", track.Title)
			folder:SetAttribute("StartedAt", Workspace:GetServerTimeNow())
			task.wait(track.Seconds + Music.GapSeconds)
		end
	end)
end

return RadioService
