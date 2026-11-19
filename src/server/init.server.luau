--!strict
-- Server entry point. Runs once when the server starts.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChatTagService = require(script.services.ChatTagService)
local Config = require(ReplicatedStorage.Shared.Config)
local SitService = require(script.services.SitService)

Players.PlayerAdded:Connect(function(player: Player)
	print(`{player.Name} joined {Config.GameName}`)
end)

ChatTagService.start()
SitService.start()
