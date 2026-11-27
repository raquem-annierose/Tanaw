--!strict
-- Every RemoteEvent in the game, in one place. The server creates them; clients wait for them.
--
-- Never trust what a client sends through a remote: the server checks it first.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FOLDER = "Remotes"

-- Server -> admin's client: turn an admin effect on/off, or show a notice in chat.
--   ("Fly", on: boolean) | ("Noclip", on: boolean) | ("Notice", text: string)
local ADMIN = "Admin"
-- Admin panel (RemoteFunction). Client -> server: (action: string, ...args) -> (ok, result).
-- The server checks the caller's level for every action (see AdminPanelService).
local ADMIN_PANEL = "AdminPanel"
-- Announcements, countdowns and polls for everyone. Server -> all clients:
--   ("Announce", text, author, seconds) | ("Countdown", "start", payload) | ("Countdown", "cancel")
--   | ("Poll", "start" | "update" | "end", data)
-- Client -> server: ("Vote", pollId: number, option: number)
local LIVE_EVENTS = "LiveEvents"
-- Café cashier. Client -> server: ("Accept") the player said yes to the order question.
local CAFE = "Cafe"
-- Phone. Client -> server: ("Selfie", on: boolean) hold up / put away the selfie stick.
local PHONE = "Phone"
-- Patong rooms and versus games (see PatongService for every message).
local PATONG = "Patong"
-- Table games. Client -> server: ("Move", cell) | ("Tap") | ("Pick", choice) for the table the
-- player sits at. Server -> client: ("State", state) | ("Closed") (see TableGameService).
local TABLE_GAME = "TableGame"
-- Radio vote skip. Client -> server: ("Skip") vote / take back a vote to skip the current song.
-- Server -> all clients: ("SkipVote", name: string, votes: number, needed: number)
--   | ("Skipped", title: string) - shown in chat.
local RADIO = "Radio"
-- Talon race rooms (see TalonService for every message).
local TALON = "Talon"
-- Freedom Wall. Client -> server: ("Post", text: string, anonymous: boolean).
-- Server -> client: ("Open") the player clicked the QR sign | ("Posted") | ("Error", message: string)
local FREEDOM_WALL = "FreedomWall"
-- Mirror Photobooth (the booth model is always the first argument after the kind).
-- Client -> server: ("Ready", booth) | ("Captured", booth) | ("Retake", booth) | ("Done", booth)
--   | ("Leave", booth)
-- Server -> client: ("Start", booth) | ("Countdown", booth, endsAt) | ("Preview", booth)
--   | ("End", booth, reason: string) | ("Error", message: string)
local PHOTOBOOTH = "Photobooth"
-- Wishing Sky Lanterns. Client -> server: ("Release", wish: string, colorIndex: number, anonymous: boolean).
-- Server -> client: ("Open") | ("Released") | ("Error", message: string) | ("Spawn", payload)
local SKY_LANTERN = "SkyLantern"
-- Street food stalls. Client -> server: ("Order", stallName: string, itemId: string).
-- Server -> client: ("Open", stallName: string) | ("Ordered", itemId: string)
--   | ("Notice", message: string) | ("Error", message: string)
local FOOD_STALL = "FoodStall"

local Remotes = {}

local function folder(): Instance
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(FOLDER)
		if existing then
			return existing
		end
		local created = Instance.new("Folder")
		created.Name = FOLDER
		created.Parent = ReplicatedStorage
		return created
	end
	return ReplicatedStorage:WaitForChild(FOLDER)
end

local function event(name: string): RemoteEvent
	local parent = folder()
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing and existing:IsA("RemoteEvent") then
			return existing
		end
		local created = Instance.new("RemoteEvent")
		created.Name = name
		created.Parent = parent
		return created
	end
	return parent:WaitForChild(name) :: RemoteEvent
end

local function func(name: string): RemoteFunction
	local parent = folder()
	if RunService:IsServer() then
		local existing = parent:FindFirstChild(name)
		if existing and existing:IsA("RemoteFunction") then
			return existing
		end
		local created = Instance.new("RemoteFunction")
		created.Name = name
		created.Parent = parent
		return created
	end
	return parent:WaitForChild(name) :: RemoteFunction
end

-- Both sides: the admin panel remote. On the client this waits until the server has made it.
function Remotes.adminPanel(): RemoteFunction
	return func(ADMIN_PANEL)
end

-- Both sides: announcements, countdowns and polls. On the client this waits for the server.
function Remotes.liveEvents(): RemoteEvent
	return event(LIVE_EVENTS)
end

-- Server: creates the admin remote. Only called where admin commands are on.
function Remotes.admin(): RemoteEvent
	return event(ADMIN)
end

-- Both sides: the café remote. On the client this waits until the server has made it.
function Remotes.cafe(): RemoteEvent
	return event(CAFE)
end

-- Both sides: the phone remote. On the client this waits until the server has made it.
function Remotes.phone(): RemoteEvent
	return event(PHONE)
end

-- Both sides: the Freedom Wall remote. On the client this waits until the server has made it.
function Remotes.freedomWall(): RemoteEvent
	return event(FREEDOM_WALL)
end

-- Both sides: the Mirror Photobooth remote. On the client this waits until the server has made it.
function Remotes.photobooth(): RemoteEvent
	return event(PHOTOBOOTH)
end

-- Both sides: the Patong remote. On the client this waits until the server has made it.
function Remotes.patong(): RemoteEvent
	return event(PATONG)
end

-- Both sides: the radio remote. On the client this waits until the server has made it.
function Remotes.radio(): RemoteEvent
	return event(RADIO)
end

-- Both sides: the Talon remote. On the client this waits until the server has made it.
function Remotes.talon(): RemoteEvent
	return event(TALON)
end

-- Both sides: the table games remote. On the client this waits until the server has made it.
function Remotes.tableGame(): RemoteEvent
	return event(TABLE_GAME)
end

-- Both sides: the Wishing Sky Lantern remote. On the client this waits until the server has made it.
function Remotes.skyLantern(): RemoteEvent
	return event(SKY_LANTERN)
end

-- Both sides: the Street Food Stalls remote. On the client this waits until the server has made it.
function Remotes.foodStall(): RemoteEvent
	return event(FOOD_STALL)
end

-- Client: the admin remote, or nil if it doesn't show up in time (e.g. in PROD it never does).
function Remotes.waitForAdmin(timeout: number): RemoteEvent?
	local parent = ReplicatedStorage:WaitForChild(FOLDER, timeout)
	local remote = parent and parent:WaitForChild(ADMIN, timeout)
	return if remote and remote:IsA("RemoteEvent") then remote else nil
end

return Remotes
