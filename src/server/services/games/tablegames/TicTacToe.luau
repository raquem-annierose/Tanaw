--!strict
-- Tic-Tac-Toe. Seat1 is X, Seat2 is O; who goes first swaps every round.
--
-- State: Phase ("Playing" | "Result"), Board (9 cells: 0 empty, 1 X, 2 O, row by row),
-- Turn (1 | 2), Winner (0 = draw), Line (the 3 winning cells), Scores ({ X wins, O wins }).
-- Action: ("Move", cell 1-9) on your turn.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TableGames = require(ReplicatedStorage.Shared.games.TableGames)
local Types = require(script.Parent.Types)

local LINES = {
	{ 1, 2, 3 },
	{ 4, 5, 6 },
	{ 7, 8, 9 },
	{ 1, 4, 7 },
	{ 2, 5, 8 },
	{ 3, 6, 9 },
	{ 1, 5, 9 },
	{ 3, 5, 7 },
}

local TicTacToe = {}

local function findLine(board: { number }, mark: number): { number }?
	for _, line in LINES do
		if board[line[1]] == mark and board[line[2]] == mark and board[line[3]] == mark then
			return line
		end
	end
	return nil
end

function TicTacToe.start(ctx: Types.Context): Types.Match
	local board: { number } = table.create(9, 0)
	local scores = { 0, 0 }
	local starter = 1
	local turn = 1
	local phase: string = "Playing"
	local winner = 0
	local line: { number }? = nil

	local function publish()
		ctx.publish({
			Phase = phase,
			Board = board,
			Turn = turn,
			Winner = winner,
			Line = line,
			Scores = scores,
		})
	end

	local function newRound()
		board = table.create(9, 0)
		turn = starter
		starter = 3 - starter
		phase = "Playing"
		winner = 0
		line = nil
		publish()
	end
	newRound()

	return {
		action = function(index: number, kind: string, value: unknown)
			if
				kind ~= "Move"
				or phase ~= "Playing"
				or index ~= turn
				or typeof(value) ~= "number"
			then
				return
			end
			local cell = value :: number
			if cell ~= math.floor(cell) or cell < 1 or cell > 9 or board[cell] ~= 0 then
				return
			end
			board[cell] = index
			line = findLine(board, index)
			local finished = line ~= nil or not table.find(board, 0)
			if line then
				winner = index
				scores[index] += 1
			end
			if finished then
				phase = "Result"
			else
				turn = 3 - turn
			end
			publish()
			if finished then
				task.delay(TableGames.ResultSeconds, function()
					if ctx.alive() then
						newRound()
					end
				end)
			end
		end,
	}
end

return TicTacToe
