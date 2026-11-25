--!strict
-- Patong versus rooms. A player hosts a room from the phone; players within Patong.JoinDistance
-- studs of the host see it in their Multiplayer list and can join (up to Patong.MaxPlayers).
-- The host taps Start. Everyone plays their own board on their own device; the server passes
-- boards and garbage rows between them. The last player still playing wins, and the room stays
-- open for another round.
--
-- Each client runs its own game, so the server can't check the moves. It checks what it can: who
-- is in which room, the distance when joining, the size of each attack and how often messages come.
--
-- Patong remote messages:
--   Client -> server:
--     ("Browse", on: boolean)  the Multiplayer screen is open: send me the nearby rooms
--     ("Host") | ("Join", hostUserId: number) | ("Leave") | ("Start")  (Start: host only)
--     ("Board", packed: string)  my stack after a piece locked (PatongGame.pack)
--     ("Attack", rows: number)   I cleared rows: send garbage to someone
--     ("Out")                    my board filled up
--   Server -> client:
--     ("Rooms", { NearbyRoom })  rooms near you (while browsing)
--     ("Room", RoomInfo?)        the room you're in changed, or nil when you're not in one
--     ("Start", seed: number, startAt: number)  startAt is a Workspace:GetServerTimeNow() time
--     ("Board", userId: number, packed: string) | ("Garbage", rows: number, fromName: string)
--     ("Out", userId: number) | ("Winner", userId: number)  (0 = nobody)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Patong = require(ReplicatedStorage.Shared.games.Patong)
local Remotes = require(ReplicatedStorage.Shared.core.Remotes)
local UnlockService = require(script.Parent.Parent.progression.UnlockService)

-- Feature (shared Unlocks) needed to host, join or start a versus room.
local FEATURE = "Games"

local BOARD_LENGTH = Patong.Width * Patong.Height
-- Spam protection: ignore messages of one kind closer together than this per player (seconds).
local MIN_INTERVAL = {
	Board = 0.03,
	Attack = 0.1,
	Room = 0.3,
}
-- How often the nearby rooms list is refreshed for browsing players.
local LIST_INTERVAL = 1

type Room = {
	host: Player,
	members: { Player },
	playing: boolean,
	alive: { [Player]: boolean },
}

local PatongService = {}

local remote: RemoteEvent? = nil
local rng = Random.new()
local rooms: { Room } = {}
local roomOf: { [Player]: Room } = {}
local browsing: { [Player]: boolean } = {}
-- The last rooms list sent to each browsing player, so an unchanged list isn't sent again.
local lastList: { [Player]: string } = {}
local lastMessage: { [Player]: { [string]: number } } = {}

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
	return pa ~= nil and pb ~= nil and (pa - pb).Magnitude <= Patong.JoinDistance
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

-- Ends the round once one player (or nobody) is left.
local function finishIfDone(room: Room)
	if not room.playing then
		return
	end
	local count = 0
	local last: Player? = nil
	for _, member in room.members do
		if room.alive[member] then
			count += 1
			last = member
		end
	end
	if count > 1 then
		return
	end
	room.playing = false
	table.clear(room.alive)
	sendToRoom(room, "Winner", if last then last.UserId else 0)
	sendRoom(room)
end

local function knockOut(room: Room, player: Player)
	if room.playing and room.alive[player] then
		room.alive[player] = nil
		sendToRoom(room, "Out", player.UserId)
		finishIfDone(room)
	end
end

local function leave(player: Player)
	local room = roomOf[player]
	if not room then
		return
	end
	knockOut(room, player)
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
	sendRoom(room)
end

local function host(player: Player)
	local current = roomOf[player]
	if current and current.host == player then
		return
	end
	leave(player)
	local room: Room = { host = player, members = { player }, playing = false, alive = {} }
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
	if room.playing or #room.members >= Patong.MaxPlayers or not isNear(player, room.host) then
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
	for _, member in room.members do
		room.alive[member] = true
	end
	local seed = rng:NextInteger(1, 2 ^ 30)
	sendToRoom(room, "Start", seed, Workspace:GetServerTimeNow() + Patong.CountdownSeconds)
	sendRoom(room)
end

local function relayBoard(player: Player, packed: unknown)
	local room = roomOf[player]
	if not room or not room.alive[player] or typeof(packed) ~= "string" then
		return
	end
	if #packed ~= BOARD_LENGTH or not string.find(packed, "^[0-8]+$") then
		return
	end
	for _, member in room.members do
		if member ~= player then
			send(member, "Board", player.UserId, packed)
		end
	end
end

local function attack(player: Player, rows: unknown)
	local room = roomOf[player]
	if not room or not room.alive[player] or typeof(rows) ~= "number" then
		return
	end
	if rows ~= math.floor(rows) or rows < 1 or rows > Patong.Attack[#Patong.Attack] then
		return
	end
	local targets = {}
	for _, member in room.members do
		if member ~= player and room.alive[member] then
			table.insert(targets, member)
		end
	end
	if #targets > 0 then
		send(targets[rng:NextInteger(1, #targets)], "Garbage", rows, player.DisplayName)
	end
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
	elseif action == "Board" then
		if not tooSoon(player, "Board") then
			relayBoard(player, value)
		end
	elseif action == "Attack" then
		if not tooSoon(player, "Attack") then
			attack(player, value)
		end
	elseif action == "Out" then
		local room = roomOf[player]
		if room then
			knockOut(room, player)
		end
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

function PatongService.start()
	local r = Remotes.patong()
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

return PatongService
