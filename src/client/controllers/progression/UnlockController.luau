--!strict
-- The local player's feature unlocks (rules in shared Unlocks, decided by UnlockService).
-- Unlocked comes from the server's attribute; the countdown is worked out here from the
-- PlaytimeStart attribute (all-time playtime) so it ticks smoothly without extra network traffic.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Unlocks = require(ReplicatedStorage.Shared.progression.Unlocks)

local UnlockController = {}

local changedEvent = Instance.new("BindableEvent")
-- Fires (featureId) when a feature is unlocked or locked again.
UnlockController.Changed = changedEvent.Event

function UnlockController.status(featureId: string): Unlocks.Status
	local player = Players.LocalPlayer
	local start = player:GetAttribute(Unlocks.PlaytimeAttribute)
	local status = Unlocks.check(featureId, {
		playSeconds = if typeof(start) == "number" then Workspace:GetServerTimeNow() - start else 0,
	})
	-- The server's word wins (it also knows about coin purchases).
	local fromServer = player:GetAttribute(Unlocks.attribute(featureId))
	if typeof(fromServer) == "boolean" then
		status.unlocked = fromServer
		if fromServer then
			status.remaining = 0
		elseif status.remaining == 0 then
			-- Counted down here but the server hasn't confirmed yet: show it as about to unlock.
			status.remaining = 1
		end
	end
	return status
end

function UnlockController.isUnlocked(featureId: string): boolean
	return UnlockController.status(featureId).unlocked
end

function UnlockController.start()
	local player = Players.LocalPlayer
	player.AttributeChanged:Connect(function(name: string)
		local prefix = Unlocks.AttributePrefix
		if string.sub(name, 1, #prefix) == prefix then
			changedEvent:Fire(string.sub(name, #prefix + 1))
		end
	end)
end

return UnlockController
