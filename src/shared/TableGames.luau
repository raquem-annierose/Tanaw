--!strict
-- Two-player table games in the Playground: Tic-Tac-Toe, Arm Wrestling and Bato-Bato Pick.
-- Used by the server (TableGameService) and the client (TableGameController).
--
-- In Studio, a table is a Model tagged `Tag` with a string attribute `Game` (a key of Titles) and
-- two Seats inside named "Seat1" and "Seat2", facing each other. Give the Seats CanTouch off so
-- players sit through the "Play" prompt, not by walking into them. The game starts when both
-- seats are taken and ends when someone stands up (jump).

local TableGames = {
	Tag = "TableGame",
	GameAttribute = "Game",

	Titles = {
		TicTacToe = "Tic-Tac-Toe",
		ArmWrestle = "Arm Wrestling",
		BatoBatoPick = "Bato-Bato Pick",
	} :: { [string]: string },

	-- How close a player must be to a seat to get its "Play" prompt.
	PromptDistance = 7,
	-- Seconds the result stays on screen before the next round starts.
	ResultSeconds = 4,

	ArmWrestle = {
		CountdownSeconds = 3,
		-- The server moves the arms this often (seconds), counting the taps since the last move.
		TickSeconds = 0.1,
		-- Taps counted per player per tick (2 per 0.1 s = 20 taps a second), so autoclickers
		-- don't win by default.
		MaxTapsPerTick = 2,
		-- How far one tap more than the opponent moves the arms. 1 = all the way to one side.
		Step = 0.05,
	},

	BatoBatoPick = {
		PickSeconds = 5,
		RevealSeconds = 2.5,
		-- Round wins needed to win the game (2 = best of 3).
		WinsNeeded = 2,
		Choices = { "Bato", "Papel", "Gunting" },
		Icons = { Bato = "✊", Papel = "✋", Gunting = "✌️" } :: { [string]: string },
		-- What each choice beats.
		Beats = { Bato = "Gunting", Gunting = "Papel", Papel = "Bato" } :: { [string]: string },
	},
}

return TableGames
