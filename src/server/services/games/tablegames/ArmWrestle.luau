--!strict
-- Arm wrestling: after a countdown, both players tap as fast as they can. Every tick the arms
-- move toward whoever tapped more; the first to push them all the way wins the round.
--
-- State: Phase ("Countdown" | "Playing" | "Result"), StartAt (server time the tapping starts),
-- Position (-1..1, 1 = Seat1 won), Winner (1 | 2), Scores ({ Seat1 wins, Seat2 wins }).
-- Action: ("Tap") while playing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TableGames = require(ReplicatedStorage.Shared.games.TableGames)
local Types = require(script.Parent.Types)

local Settings = TableGames.ArmWrestle

local ArmWrestle = {}

function ArmWrestle.start(ctx: Types.Context): Types.Match
	local scores = { 0, 0 }
	local taps = { 0, 0 }
	local position = 0
	local phase: string = "Countdown"
	local winner = 0
	local startAt = 0

	local function publish()
		ctx.publish({
			Phase = phase,
			StartAt = startAt,
			Position = position,
			Winner = winner,
			Scores = scores,
		})
	end

	task.spawn(function()
		while ctx.alive() do
			position = 0
			winner = 0
			phase = "Countdown"
			startAt = Workspace:GetServerTimeNow() + Settings.CountdownSeconds
			publish()
			task.wait(Settings.CountdownSeconds)
			if not ctx.alive() then
				return
			end

			taps = { 0, 0 }
			phase = "Playing"
			publish()
			while ctx.alive() and phase == "Playing" do
				task.wait(Settings.TickSeconds)
				local a = math.min(taps[1], Settings.MaxTapsPerTick)
				local b = math.min(taps[2], Settings.MaxTapsPerTick)
				taps = { 0, 0 }
				if a ~= b then
					position = math.clamp(position + (a - b) * Settings.Step, -1, 1)
					if math.abs(position) >= 1 then
						winner = if position > 0 then 1 else 2
						scores[winner] += 1
						phase = "Result"
					end
					publish()
				end
			end
			if not ctx.alive() then
				return
			end
			task.wait(TableGames.ResultSeconds)
		end
	end)

	return {
		action = function(index: number, kind: string, _value: unknown)
			if kind == "Tap" and phase == "Playing" then
				taps[index] += 1
			end
		end,
	}
end

return ArmWrestle
