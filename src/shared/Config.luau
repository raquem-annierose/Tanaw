--!strict
-- Shared settings used by both client and server.

local Config = {
	GameName = "Tanaw",
	GameTitle = "Tanaw: Café & City Lights",
	Studio = "NieRa Studios",

	Movement = {
		-- How fast the character speeds up / slows down. Higher = snappier, lower = floatier.
		Acceleration = 10,
		Deceleration = 12,
	},

	ShiftLock = {
		-- How far the camera sits to the right of the character while shift lock is on.
		CameraOffset = Vector3.new(1.75, 0, 0),
	},

	SpawnView = {
		-- Where the camera starts after spawning: this far behind the character, this much higher.
		CameraDistance = 12,
		CameraHeight = 4,
		-- Only spawns this close count as the one the player landed on.
		MaxSpawnDistance = 30,
	},
}

return Config
