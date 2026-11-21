--!strict
-- Gives every player the welcome badge ("Unang Tanaw") when they join.
--
-- Badges belong to one experience, so DEV, STAGING and PROD each have their own badge ID
-- in Config.Badges.Welcome, keyed by universe ID. An ID of 0 means "not created yet", and
-- nothing is awarded. Roblox never awards badges in Studio playtests, only in live servers.

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local BadgeAwardService = {}

local function award(player: Player, badgeId: number)
	local ok, hasBadge = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
	if not ok then
		warn(`[Badges] Could not check badge {badgeId} for {player.Name}: {hasBadge}`)
		return
	end
	if hasBadge or not player.Parent then
		return
	end
	local awarded, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badgeId)
	if not awarded then
		warn(`[Badges] Could not award badge {badgeId} to {player.Name}: {err}`)
	end
end

function BadgeAwardService.start()
	local badgeId = Config.Badges.Welcome[game.GameId] or 0
	if badgeId == 0 then
		return
	end
	for _, player in Players:GetPlayers() do
		task.spawn(award, player, badgeId)
	end
	Players.PlayerAdded:Connect(function(player)
		award(player, badgeId)
	end)
end

return BadgeAwardService
