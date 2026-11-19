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

	-- The NieRa Studios community on Roblox.
	CommunityId = 597581586,

	-- Chat tags for staff, keyed by role name in the community (must match the role name exactly).
	-- Roles not listed here get no tag.
	ChatTags = {
		Owner = { Text = "Owner", Color = Color3.fromRGB(255, 200, 90) },
		Developer = { Text = "Developer", Color = Color3.fromRGB(255, 140, 70) },
		Moderator = { Text = "Moderator", Color = Color3.fromRGB(110, 170, 255) },
	} :: { [string]: { Text: string, Color: Color3 } },
	-- When someone holds several of these roles, the first one in this list is shown.
	ChatTagOrder = { "Owner", "Developer", "Moderator" },

	SpawnView = {
		-- Where the camera starts after spawning: this far behind the character, this much higher.
		CameraDistance = 12,
		CameraHeight = 4,
		-- Only spawns this close count as the one the player landed on.
		MaxSpawnDistance = 30,
	},
}

return Config
