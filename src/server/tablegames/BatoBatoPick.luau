--!strict
-- Bato-bato pick (rock, paper, scissors). Each round both players pick within PickSeconds;
-- a player who doesn't pick gets a random choice. Draws replay the round. First to WinsNeeded
-- round wins takes the game.
--
-- State: Phase ("Picking" | "Reveal" | "Result"), Round, Scores ({ Seat1, Seat2 }),
-- Deadline (server time picking ends), Picked ({ bool, bool }: who has picked),
-- Picks ({ choice, choice }, only after picking), RoundWinner (0 = draw), Winner (0 = none yet).
-- Action: ("Pick", "Bato" | "Papel" | "Gunting") while picking.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local TableGames = require(ReplicatedStorage.Shared.TableGames)
local Types = require(script.Parent.Types)

local Settings = TableGames.BatoBatoPick

local BatoBatoPick = {}

function BatoBatoPick.start(ctx: Types.Context): Types.Match
	local rng = Random.new()
	local scores = { 0, 0 }
	local picks: { [number]: string } = {}
	local phase: string = "Picking"
	local round = 1
	local deadline = 0
	local roundWinner = 0
	local winner = 0

	local function publish()
		local revealed = phase ~= "Picking"
		ctx.publish({
			Phase = phase,
			Round = round,
			Scores = scores,
			Deadline = deadline,
			Picked = { picks[1] ~= nil, picks[2] ~= nil },
			Picks = if revealed then { picks[1] or "", picks[2] or "" } else nil,
			RoundWinner = roundWinner,
			Winner = winner,
		})
	end

	task.spawn(function()
		while ctx.alive() do
			scores = { 0, 0 }
			round = 1
			winner = 0
			while ctx.alive() and winner == 0 do
				picks = {}
				roundWinner = 0
				phase = "Picking"
				deadline = Workspace:GetServerTimeNow() + Settings.PickSeconds
				publish()
				while
					ctx.alive()
					and Workspace:GetServerTimeNow() < deadline
					and not (picks[1] and picks[2])
				do
					task.wait(0.1)
				end
				if not ctx.alive() then
					return
				end

				for i = 1, 2 do
					if not picks[i] then
						picks[i] = Settings.Choices[rng:NextInteger(1, #Settings.Choices)]
					end
				end
				if Settings.Beats[picks[1]] == picks[2] then
					roundWinner = 1
				elseif Settings.Beats[picks[2]] == picks[1] then
					roundWinner = 2
				end
				if roundWinner ~= 0 then
					scores[roundWinner] += 1
					if scores[roundWinner] >= Settings.WinsNeeded then
						winner = roundWinner
					end
				end
				phase = "Reveal"
				publish()
				task.wait(Settings.RevealSeconds)
				round += 1
			end
			if not ctx.alive() then
				return
			end
			phase = "Result"
			publish()
			task.wait(TableGames.ResultSeconds)
		end
	end)

	return {
		action = function(index: number, kind: string, value: unknown)
			if
				kind ~= "Pick"
				or phase ~= "Picking"
				or picks[index]
				or typeof(value) ~= "string"
			then
				return
			end
			local choice = value :: string
			if Settings.Beats[choice] then
				picks[index] = choice
				publish()
			end
		end,
	}
end

return BatoBatoPick
