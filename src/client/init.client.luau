--!strict
-- Client entry point. Runs on each player's device when they join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local MovementController = require(script.controllers.MovementController)
local ShiftLockController = require(script.controllers.ShiftLockController)
local ShiftLockButton = require(script.ui.ShiftLockButton)
local SitPoseController = require(script.controllers.SitPoseController)
local SpawnViewController = require(script.controllers.SpawnViewController)
local TimeOfDayController = require(script.controllers.TimeOfDayController)
local TimeOfDayMenu = require(script.ui.TimeOfDayMenu)

local player = Players.LocalPlayer
print(`Welcome to {Config.GameName}, {player.DisplayName}!`)

MovementController.start()
ShiftLockController.start()
ShiftLockButton.start()
SitPoseController.start()
SpawnViewController.start()
TimeOfDayController.start()
TimeOfDayMenu.start()
