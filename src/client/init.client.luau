--!strict
-- Client entry point. Runs on each player's device when they join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local player = Players.LocalPlayer
print(`Welcome to {Config.GameName}, {player.DisplayName}!`)
