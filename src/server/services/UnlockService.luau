--!strict
-- Decides which features each player has unlocked (rules in shared Unlocks). Other services ask
-- isUnlocked before doing a locked action, so a client can't skip the lock.
--
-- Playtime unlocks use the player's all-time playtime from PlaytimeService (saved total plus this
-- visit), so players who already spent the time don't wait again. Until their saved total loads
-- (or if DataStores are off, e.g. in Studio), only this visit counts.
--
-- Players get attributes the client reads:
--   PlaytimeStart          server time minus their playtime (for the countdown)
--   Unlocked_<FeatureId>   true once unlocked (checked every second)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local PlaytimeService = require(script.Parent.PlaytimeService)
local Unlocks = require(ReplicatedStorage.Shared.Unlocks)

local CHECK_INTERVAL = 1
-- Only move the PlaytimeStart attribute when it's off by more than this (seconds), so it isn't
-- re-sent every second for tiny clock differences.
local START_TOLERANCE = 2

local UnlockService = {}

local joinedAt: { [Player]: number } = {}
-- Features bought with coins, per player (for later; nothing fills it yet).
local owned: { [Player]: { [string]: boolean } } = {}

local function playSeconds(player: Player): number
	local total = PlaytimeService.totalSeconds(player)
	if total then
		return total
	end
	return Workspace:GetServerTimeNow() - (joinedAt[player] or Workspace:GetServerTimeNow())
end

local function context(player: Player): Unlocks.Context
	return {
		playSeconds = playSeconds(player),
		owned = owned[player],
	}
end

function UnlockService.status(player: Player, featureId: string): Unlocks.Status
	return Unlocks.check(featureId, context(player))
end

function UnlockService.isUnlocked(player: Player, featureId: string): boolean
	return UnlockService.status(player, featureId).unlocked
end

-- For a future coins purchase flow: mark a feature as owned by the player.
function UnlockService.grant(player: Player, featureId: string)
	local list = owned[player]
	if not list then
		list = {}
		owned[player] = list
	end
	list[featureId] = true
	player:SetAttribute(Unlocks.attribute(featureId), UnlockService.isUnlocked(player, featureId))
end

local function refresh(player: Player)
	local start = Workspace:GetServerTimeNow() - playSeconds(player)
	local current = player:GetAttribute(Unlocks.PlaytimeAttribute)
	if typeof(current) ~= "number" or math.abs(current - start) > START_TOLERANCE then
		player:SetAttribute(Unlocks.PlaytimeAttribute, start)
	end
	for featureId in Unlocks.Features do
		local unlocked = UnlockService.isUnlocked(player, featureId)
		local name = Unlocks.attribute(featureId)
		if player:GetAttribute(name) ~= unlocked then
			player:SetAttribute(name, unlocked)
		end
	end
end

function UnlockService.start()
	local function onJoin(player: Player)
		joinedAt[player] = Workspace:GetServerTimeNow()
		refresh(player)
	end
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(player: Player)
		joinedAt[player] = nil
		owned[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(CHECK_INTERVAL)
			for player in joinedAt do
				refresh(player)
			end
		end
	end)
end

return UnlockService
