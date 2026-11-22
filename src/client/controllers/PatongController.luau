--!strict
-- Patong multiplayer on the client: the rooms near this player, the room they are in, and the
-- messages during a versus game. PatongApp shows all of it; PatongService on the server decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.Remotes)

export type Member = { UserId: number, Name: string }
export type Room = { HostId: number, Members: { Member }, Playing: boolean }
export type NearbyRoom = { HostId: number, HostName: string, Count: number, Playing: boolean }

local PatongController = {}

local roomsEvent = Instance.new("BindableEvent")
-- Fires when the list of nearby rooms changes (see getNearby).
PatongController.NearbyChanged = roomsEvent.Event
local roomEvent = Instance.new("BindableEvent")
-- Fires when this player's room changes or they leave it (see getRoom).
PatongController.RoomChanged = roomEvent.Event
local gameEvent = Instance.new("BindableEvent")
-- Fires during a versus game with one of:
--   ("Start", seed: number, startAt: number) | ("Board", userId: number, packed: string)
--   | ("Garbage", rows: number, fromName: string) | ("Out", userId: number)
--   | ("Winner", userId: number)  (0 = nobody)
PatongController.GameMessage = gameEvent.Event

local remote: RemoteEvent? = nil
local nearby: { NearbyRoom } = {}
local room: Room? = nil

local function send(...: any)
	if remote then
		remote:FireServer(...)
	end
end

function PatongController.getNearby(): { NearbyRoom }
	return nearby
end

function PatongController.getRoom(): Room?
	return room
end

-- Ask for (or stop) the nearby rooms list, while the Multiplayer screen is open.
function PatongController.browse(on: boolean)
	send("Browse", on)
end

function PatongController.host()
	send("Host")
end

function PatongController.join(hostId: number)
	send("Join", hostId)
end

function PatongController.leave()
	send("Leave")
end

function PatongController.startGame()
	send("Start")
end

function PatongController.sendBoard(packed: string)
	send("Board", packed)
end

function PatongController.sendAttack(rows: number)
	send("Attack", rows)
end

function PatongController.sendOut()
	send("Out")
end

function PatongController.start()
	task.spawn(function()
		local r = Remotes.patong()
		remote = r
		r.OnClientEvent:Connect(function(kind: string, a: any, b: any)
			if kind == "Rooms" then
				nearby = a
				roomsEvent:Fire()
			elseif kind == "Room" then
				room = a
				roomEvent:Fire()
			else
				gameEvent:Fire(kind, a, b)
			end
		end)
	end)
end

return PatongController
