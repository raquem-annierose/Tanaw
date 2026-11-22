--!strict
-- Server entry point. Runs once when the server starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminService = require(script.services.AdminService)
local BadgeAwardService = require(script.services.BadgeAwardService)
local CafeService = require(script.services.CafeService)
local ChatTagService = require(script.services.ChatTagService)
local Config = require(ReplicatedStorage.Shared.Config)
local NpcService = require(script.services.NpcService)
local PatongService = require(script.services.PatongService)
local PlaytimeService = require(script.services.PlaytimeService)
local RadioService = require(script.services.RadioService)
local SelfieStickService = require(script.services.SelfieStickService)
local SitService = require(script.services.SitService)

Players.PlayerAdded:Connect(function(player: Player)
	print(`{player.Name} joined {Config.GameName}`)
end)

AdminService.start()
BadgeAwardService.start()
CafeService.start()
ChatTagService.start()
NpcService.start()
PatongService.start()
PlaytimeService.start()
RadioService.start()
SelfieStickService.start()
SitService.start()
