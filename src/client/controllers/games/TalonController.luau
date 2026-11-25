--!strict
-- Talon race rooms on the client: the rooms near this player, the room they are in, and the
-- messages during a race. TalonApp shows all of it; TalonService on the server decides.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = require(ReplicatedStorage.Shared.core.Remotes)

export type Member = { UserId: number, Name: string }
export type Room = { HostId: number, Members: { Member }, Playing: boolean }
export type NearbyRoom = { HostId: number, HostName: string, Count: number, Playing: boolean }

local TalonController = {}

local roomsEvent = Instance.new("BindableEvent")
-- Fires when the list of nearby rooms changes (see getNearby).
TalonController.NearbyChanged = roomsEvent.Event
local roomEvent = Instance.new("BindableEvent")
-- Fires when this player's room changes or they leave it (see getRoom).
TalonController.RoomChanged = roomEvent.Event
local raceEvent = Instance.new("BindableEvent")
-- Fires during a race with one of:
--   ("Start", seed: number, startAt: number) | ("Progress", userId: number, x: number)
--   | ("Winner", userId: number, name: string)  (0 = nobody)
TalonController.RaceMessage = raceEvent.Event

local remote: RemoteEvent? = nil
local nearby: { NearbyRoom } = {}
local room: Room? = nil

local function send(...: any)
	if remote then
		remote:FireServer(...)
	end
end

function TalonController.getNearby(): { NearbyRoom }
	return nearby
end

function TalonController.getRoom(): Room?
	return room
end

-- Ask for (or stop) the nearby rooms list, while the Multiplayer screen is open.
function TalonController.browse(on: boolean)
	send("Browse", on)
end

function TalonController.host()
	send("Host")
end

function TalonController.join(hostId: number)
	send("Join", hostId)
end

function TalonController.leave()
	send("Leave")
end

function TalonController.startRace()
	send("Start")
end

function TalonController.sendProgress(x: number)
	send("Progress", x)
end

function TalonController.sendFinish()
	send("Finish")
end

function TalonController.start()
	task.spawn(function()
		local r = Remotes.talon()
		remote = r
		r.OnClientEvent:Connect(function(kind: string, a: any, b: any)
			if kind == "Rooms" then
				nearby = a
				roomsEvent:Fire()
			elseif kind == "Room" then
				room = a
				roomEvent:Fire()
			else
				raceEvent:Fire(kind, a, b)
			end
		end)
	end)
end

return TalonController
