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

	Admin = {
		-- Community roles that get admin commands.
		Roles = { "Owner", "Developer" },
		-- Extra people by Roblox UserId (Profile URL: roblox.com/users/<UserId>/profile).
		UserIds = {} :: { number },
		-- Admin commands only exist in these experiences (DEV, STAGING), never in PROD.
		-- Studio playtests of an unpublished copy also count.
		UniverseIds = { 10777857627, 10777857441 },
		FlySpeed = 50,
		MaxWalkSpeed = 100,
	},

	SelfieStick = {
		-- Tool name. The phone's Camera app puts it in the player's hand in selfie mode; the client
		-- looks for this name to switch to the selfie camera.
		ToolName = "Selfie Stick",
		StickLength = 3.5,
		-- Camera field of view while taking a selfie (Roblox default is 70). Wider shows more city.
		FieldOfView = 80,
	},

	Cafe = {
		-- Parts tagged with this in Studio get an "Order" prompt (e.g. the Hiraya cashier spot).
		Tag = "CafeOrder",
		Question = "Hi! Gusto mo ng coffee?",
		ToolName = "Bubble Tea",
		-- How close a player must be to order, and to accept after being asked.
		PromptDistance = 13,
		AcceptDistance = 18,
		-- How long the question stays valid / on screen, in seconds.
		AnswerTimeout = 20,
		-- Click while holding the drink to sip: how long one sip takes, and the wait between sips.
		SipSeconds = 1.4,
		SipCooldown = 1.6,
		-- Character attribute holding the server time of the last sip (read by SipController).
		SipAttribute = "SipAt",
	},

	Badges = {
		-- "Unang Tanaw" welcome badge, given on join. Keyed by universe ID because each
		-- experience has its own badges. 0 = not created yet (paste the badge ID from Creator Hub).
		Welcome = {
			[10777857627] = 0, -- DEV
			[10777857441] = 0, -- STAGING
			[10777811003] = 0, -- PROD
		} :: { [number]: number },
	},

	Playtime = {
		-- Tag a Part with this in Studio to show the top players on its front face. Set a string
		-- attribute "Face" (Front, Back, Left, Right, Top, Bottom) to use another face.
		BoardTag = "PlaytimeBoard",
		-- Tag for the spots where the top players' avatars stand (with a "Rank" attribute).
		TopNpcTag = "PlaytimeTop",
		-- Dance (Emotes Id) each of the top players' avatars does, by rank. No dance = idle.
		TopDances = { "Dance1", "Dance2", "Dance3" } :: { string },
		-- OrderedDataStore with every player's total seconds in the game. Changing the name starts
		-- everyone from zero.
		StoreName = "Playtime_v1",
		-- How many players the board shows.
		TopCount = 10,
		-- Column in the player list (Tab) with each player's all-time minutes, and how often
		-- (seconds) it updates. The list puts the most minutes on top.
		StatName = "Minutes",
		StatInterval = 10,
		-- Seconds between saves of each player's new time, and between board refreshes.
		SaveInterval = 120,
		RefreshInterval = 60,
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
