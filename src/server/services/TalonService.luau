--!strict
-- Talon race rooms. A player hosts a room from the phone; players within Talon.JoinDistance studs
-- of the host see it and can join (up to Talon.MaxPlayers). The host taps Start: everyone runs the
-- same course (from one seed) on their own device. Hitting a spike or block sends you back to the
-- start; the first to reach the finish line wins and the round ends for everyone. The room stays
-- open for another race.
--
-- Each client runs its own race, so the server checks what it can: room membership, the distance
-- when joining, message rates, and that a finish isn't faster than the course allows.
--
-- Talon remote messages:
--   Client -> server:
--     ("Browse", on: boolean)  the Multiplayer screen is open: send me the nearby rooms
--     ("Host") | ("Join", hostUserId: number) | ("Leave") | ("Start")  (Start: host only)
--     ("Progress", x: number)  how far I am (pixels from the start line), a few times a second
--     ("Finish")               I crossed the finish line
--   Server -> client:
--     ("Rooms", { NearbyRoom })  rooms near you (while browsing)
--     ("Room", RoomInfo?)        the room you're in changed, or nil when you're not in one
--     ("Start", seed: number, startAt: number)  startAt is a Workspace:GetServerTimeNow() time
--     ("Progress", userId: number, x: number)
--     ("Winner", userId: number, name: string)  (0 / "" = nobody)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Remotes = require(ReplicatedStorage.Shared.Remotes)
local Talon = require(ReplicatedStorage.Shared.Talon)
local UnlockService = require(script.Parent.UnlockService)

-- Feature (shared Unlocks) needed to host, join or start a race room.
local FEATURE = "Games"

local MIN_INTERVAL = {
	Progress = 0.08,
	Room = 0.3,
}
local LIST_INTERVAL = 1
-- A finish must take at least this share of the fastest possible time (lag allowance).
local FINISH_TOLERANCE = 0.9

type Room = {
	host: Player,
	members: { Player },
	playing: boolean,
	startAt: number,
	round: number,
}

local TalonService = {}

local remote: RemoteEvent? = nil
local rng = Random.new()
local rooms: { Room } = {}
local roomOf: { [Player]: Room } = {}
local browsing: { [Player]: boolean } = {}
local lastList: { [Player]: string } = {}
local lastMessage: { [Player]: { [string]: number } } = {}

local finishX = Talon.RaceMeters * Talon.PixelsPerMeter
local fastest = Talon.fastestTime(finishX)

local function send(player: Player, ...: any)
	if remote and player.Parent then
		remote:FireClient(player, ...)
	end
end

local function sendToRoom(room: Room, ...: any)
	for _, member in room.members do
		send(member, ...)
	end
end

local function tooSoon(player: Player, kind: string): boolean
	local times = lastMessage[player]
	if not times then
		times = {}
		lastMessage[player] = times
	end
	local now = os.clock()
	if now - (times[kind] or 0) < MIN_INTERVAL[kind] then
		return true
	end
	times[kind] = now
	return false
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position else nil
end

local function isNear(a: Player, b: Player): boolean
	local pa, pb = rootPosition(a), rootPosition(b)
	return pa ~= nil and pb ~= nil and (pa - pb).Magnitude <= Talon.JoinDistance
end

local function sendRoom(room: Room)
	local members = {}
	for _, member in room.members do
		table.insert(members, { UserId = member.UserId, Name = member.DisplayName })
	end
	sendToRoom(room, "Room", {
		HostId = room.host.UserId,
		Members = members,
		Playing = room.playing,
	})
end

local function sendList(player: Player)
	local list = {}
	local keys = {}
	for _, room in rooms do
		if room.host ~= player and isNear(player, room.host) then
			table.insert(list, {
				HostId = room.host.UserId,
				HostName = room.host.DisplayName,
				Count = #room.members,
				Playing = room.playing,
			})
			table.insert(keys, `{room.host.UserId}:{#room.members}:{room.playing}`)
		end
	end
	local key = table.concat(keys, ",")
	if lastList[player] ~= key then
		lastList[player] = key
		send(player, "Rooms", list)
	end
end

local function endRace(room: Room, winner: Player?)
	if not room.playing then
		return
	end
	room.playing = false
	sendToRoom(
		room,
		"Winner",
		if winner then winner.UserId else 0,
		if winner then winner.DisplayName else ""
	)
	sendRoom(room)
end

local function leave(player: Player)
	local room = roomOf[player]
	if not room then
		return
	end
	roomOf[player] = nil
	local index = table.find(room.members, player)
	if index then
		table.remove(room.members, index)
	end
	send(player, "Room", nil)

	if #room.members == 0 then
		local roomIndex = table.find(rooms, room)
		if roomIndex then
			table.remove(rooms, roomIndex)
		end
		return
	end
	if room.host == player then
		room.host = room.members[1]
	end
	-- The last racer left in a race wins it.
	if room.playing and #room.members == 1 then
		endRace(room, room.members[1])
	end
	sendRoom(room)
end

local function host(player: Player)
	local current = roomOf[player]
	if current and current.host == player then
		return
	end
	leave(player)
	local room: Room =
		{ host = player, members = { player }, playing = false, startAt = 0, round = 0 }
	table.insert(rooms, room)
	roomOf[player] = room
	sendRoom(room)
end

local function join(player: Player, hostId: unknown)
	if typeof(hostId) ~= "number" then
		return
	end
	local room: Room? = nil
	for _, candidate in rooms do
		if candidate.host.UserId == hostId then
			room = candidate
			break
		end
	end
	if not room or roomOf[player] == room then
		return
	end
	if room.playing or #room.members >= Talon.MaxPlayers or not isNear(player, room.host) then
		return
	end
	leave(player)
	table.insert(room.members, player)
	roomOf[player] = room
	sendRoom(room)
end

local function start(player: Player)
	local room = roomOf[player]
	if not room or room.host ~= player or room.playing or #room.members < 2 then
		return
	end
	room.playing = true
	room.round += 1
	room.startAt = Workspace:GetServerTimeNow() + Talon.CountdownSeconds
	sendToRoom(room, "Start", rng:NextInteger(1, 2 ^ 30), room.startAt)
	sendRoom(room)

	local round = room.round
	task.delay(Talon.CountdownSeconds + Talon.RaceTimeout, function()
		if room.playing and room.round == round then
			endRace(room, nil)
		end
	end)
end

local function progress(player: Player, x: unknown)
	local room = roomOf[player]
	if not room or not room.playing or typeof(x) ~= "number" or x ~= x then
		return
	end
	local clamped = math.clamp(x, 0, finishX)
	for _, member in room.members do
		if member ~= player then
			send(member, "Progress", player.UserId, clamped)
		end
	end
end

local function finish(player: Player)
	local room = roomOf[player]
	if not room or not room.playing then
		return
	end
	local elapsed = Workspace:GetServerTimeNow() - room.startAt
	if elapsed < fastest * FINISH_TOLERANCE then
		warn(`[Talon] {player.Name} finished too fast ({elapsed}s), ignored`)
		return
	end
	endRace(room, player)
end

local function onMessage(player: Player, action: unknown, value: unknown)
	if action == "Browse" then
		lastList[player] = nil
		if value == true then
			browsing[player] = true
			sendList(player)
		else
			browsing[player] = nil
		end
	elseif action == "Progress" then
		if not tooSoon(player, "Progress") then
			progress(player, value)
		end
	elseif action == "Finish" then
		finish(player)
	elseif not tooSoon(player, "Room") then
		if action ~= "Leave" and not UnlockService.isUnlocked(player, FEATURE) then
			return
		end
		if action == "Host" then
			host(player)
		elseif action == "Join" then
			join(player, value)
		elseif action == "Leave" then
			leave(player)
		elseif action == "Start" then
			start(player)
		end
	end
end

function TalonService.start()
	local r = Remotes.talon()
	remote = r
	r.OnServerEvent:Connect(onMessage)

	Players.PlayerRemoving:Connect(function(player: Player)
		leave(player)
		browsing[player] = nil
		lastList[player] = nil
		lastMessage[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(LIST_INTERVAL)
			for player in browsing do
				if not roomOf[player] then
					sendList(player)
				end
			end
		end
	end)
end

return TalonService
