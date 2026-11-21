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
-- Café cashier. Client -> server: ("Accept") the player said yes to the order question.
local CAFE = "Cafe"
-- Phone. Client -> server: ("Selfie", on: boolean) hold up / put away the selfie stick.
local PHONE = "Phone"

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

-- Client: the admin remote, or nil if it doesn't show up in time (e.g. in PROD it never does).
function Remotes.waitForAdmin(timeout: number): RemoteEvent?
	local parent = ReplicatedStorage:WaitForChild(FOLDER, timeout)
	local remote = parent and parent:WaitForChild(ADMIN, timeout)
	return if remote and remote:IsA("RemoteEvent") then remote else nil
end

return Remotes
