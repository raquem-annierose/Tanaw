--!strict
-- One radio for the whole server: picks the song and when it started, so every player hears the
-- same part of the same song (see client MusicController).
--
-- Songs play in shuffled order without repeats until the whole playlist has played.
--
-- Vote skip: players vote from the phone's Music app (Radio remote, "Skip"). The song changes for
-- everyone once Music.SkipVotesNeeded players have voted (or everyone, in a smaller server).
-- Voting again takes the vote back. Votes reset on every new song. Each vote is announced in chat.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Music = require(ReplicatedStorage.Shared.music.Music)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

type Track = Music.Track

-- Ignore votes closer together than this per player (spam protection).
local MIN_INTERVAL = 0.5

local RadioService = {}

local rng = Random.new()
local queue: { Track } = {}
local lastId: number? = nil
local folder: Folder? = nil
local remote: RemoteEvent? = nil
local current: Track? = nil
-- Bumped on every new song, so the timer of an old (skipped) song does nothing.
local songToken = 0
-- Players who voted to skip the current song, in vote order.
local voters: { Player } = {}
local lastVote: { [Player]: number } = {}

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

local function votesNeeded(): number
	return math.max(1, math.min(Music.SkipVotesNeeded, #Players:GetPlayers()))
end

-- Mirrors the vote on the radio folder so every phone can show it:
--   SkipVotes, SkipNeeded: numbers; SkipBy: display name of the first voter;
--   SkipVoters: comma-separated UserIds (so each client knows if it voted).
local function publishVotes()
	local f = folder
	if not f then
		return
	end
	local ids = {}
	for _, p in voters do
		table.insert(ids, tostring(p.UserId))
	end
	f:SetAttribute("SkipVotes", #voters)
	f:SetAttribute("SkipNeeded", votesNeeded())
	f:SetAttribute("SkipBy", if voters[1] then voters[1].DisplayName else "")
	f:SetAttribute("SkipVoters", table.concat(ids, ","))
end

local playNext: () -> ()

local function checkVotes(): boolean
	if #voters > 0 and #voters >= votesNeeded() then
		local skipped = current
		if remote and skipped then
			remote:FireAllClients("Skipped", skipped.Title)
		end
		playNext()
		return true
	end
	return false
end

playNext = function()
	local f = folder
	if not f then
		return
	end
	songToken += 1
	local token = songToken
	local track = nextTrack()
	current = track
	table.clear(voters)
	publishVotes()
	-- StartedAt is set last: clients start the song when it changes.
	f:SetAttribute("TrackId", track.Id)
	f:SetAttribute("Title", track.Title)
	f:SetAttribute("StartedAt", Workspace:GetServerTimeNow())
	task.delay(track.Seconds + Music.GapSeconds, function()
		if token == songToken then
			playNext()
		end
	end)
end

local function onVote(player: Player)
	local now = os.clock()
	if now - (lastVote[player] or 0) < MIN_INTERVAL then
		return
	end
	lastVote[player] = now

	local index = table.find(voters, player)
	if index then
		table.remove(voters, index)
		publishVotes()
		return
	end
	table.insert(voters, player)
	if not checkVotes() then
		publishVotes()
		if remote then
			remote:FireAllClients("SkipVote", player.DisplayName, #voters, votesNeeded())
		end
	end
end

function RadioService.start()
	if #Music.Playlist == 0 then
		return
	end

	local f = Instance.new("Folder")
	f.Name = Music.RadioFolder
	f.Parent = ReplicatedStorage
	folder = f

	local r = Remotes.radio()
	remote = r
	r.OnServerEvent:Connect(function(player: Player, action: unknown)
		if action == "Skip" then
			onVote(player)
		end
	end)

	-- Fewer players can mean fewer votes needed; a leaver's vote no longer counts.
	Players.PlayerAdded:Connect(publishVotes)
	Players.PlayerRemoving:Connect(function(player: Player)
		lastVote[player] = nil
		local index = table.find(voters, player)
		if index then
			table.remove(voters, index)
		end
		-- PlayerRemoving fires before the player is gone from GetPlayers().
		task.defer(function()
			if not checkVotes() then
				publishVotes()
			end
		end)
	end)

	playNext()
end

return RadioService
