--!strict
-- Settings for Patong, the falling-block game in the phone. Used by the client (PatongGame,
-- PatongApp) and the server (PatongService).

local Patong = {
	-- Board size in cells.
	Width = 10,
	Height = 20,

	-- Multiplayer: how close (studs) a player must be to the host to see and join a room.
	JoinDistance = 20,
	-- Players per room, host included.
	MaxPlayers = 4,
	-- Seconds between the host tapping Start and the first piece falling.
	CountdownSeconds = 3,

	-- Rows sent to an opponent for clearing 1, 2, 3 or 4 rows with one piece.
	Attack = { 0, 1, 2, 4 },
	-- Cell value of the grey rows an opponent sends you. 1-7 are the pieces, 0 is empty.
	Garbage = 8,
}

return Patong
