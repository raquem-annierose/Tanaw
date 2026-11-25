--!strict
-- Mirror Photobooth on the SkyTerrace: walk up, press E, pose, 3-2-1, flash, preview, retake or
-- done. The server owns the session (one player at a time); each client draws the camera, UI
-- and the mirror's screen. Plan: .claude/[0]/to-do/mirror-photobooth/plan.md
--
-- The booth model (tag Tag) has these children, found by name:
--   TouchDisplay (SurfaceGui "Display"), PhotoSpot (where the player stands, facing the
--   mirror), CameraSpot, MainMirror, LEDFrame, RingLight.
-- Booth attributes set by the server, read by every client:
--   State        - one of the States below
--   OwnerName    - display name of the player using it ("" when free)
--   CountdownEnd - Workspace:GetServerTimeNow() when the photo is taken

export type State = "Idle" | "Preparing" | "Countdown" | "Preview" | "Thanks"

local Photobooth = {
	Tag = "Photobooth",
	-- Neon parts of the RGB frame and the ring light (client animates them).
	LedTag = "PhotoboothLED",
	RingTag = "PhotoboothRing",

	Prompt = {
		ActionText = "Use Photobooth",
		ObjectText = "Mirror Photobooth",
		BusyText = "In Use",
		Distance = 10,
	},

	-- Seconds.
	Countdown = 3,
	-- "Get Ready!" before a retake's countdown.
	PrepSeconds = 1.5,
	-- "Thank You!" on the mirror after Done.
	ThanksSeconds = 2.5,
	-- Max length of a whole session; the booth frees itself after this.
	SessionTimeout = 90,
	-- No answer on the preview for this long counts as Done.
	PreviewTimeout = 30,
	-- Walking to the photo spot gives up and snaps there after this.
	WalkTimeout = 2.5,

	-- Booth camera: sits at the CameraSpot part (top part of the mirror, like a real booth's lens)
	-- and aims so the whole avatar fits. FrameMargin = extra room around the avatar (1 = tight).
	FrameMargin = 1.3,
	MinFieldOfView = 40,
	MaxFieldOfView = 80,

	-- Live mirror: what the reflection shows. Static parts in front of the mirror (cloned once),
	-- and characters within CharacterRange. The reflection only renders while the camera is
	-- within RenderDistance studs, in front of the glass.
	Mirror = {
		RegionDepth = 40,
		RegionWidth = 48,
		RegionHeight = 28,
		MaxParts = 700,
		CharacterRange = 30,
		RenderDistance = 45,
	},

	Sounds = {
		Tick = "rbxasset://sounds/electronicpingshort.wav",
		Shutter = "rbxasset://sounds/clickfast.wav",
	},

	-- Pink-purple theme.
	Colors = {
		Ink = Color3.fromRGB(34, 20, 52),
		Panel = Color3.fromRGB(58, 34, 88),
		Pink = Color3.fromRGB(255, 120, 220),
		Lilac = Color3.fromRGB(236, 150, 255),
		Text = Color3.fromRGB(255, 236, 255),
		Warm = Color3.fromRGB(255, 226, 196),
	},

	-- Texts on the mirror.
	Screen = {
		Idle = "Touch\nHere\nto Start",
		Preparing = "Get Ready!",
		Preview = "Your Photo!",
		Thanks = "Thank You!",
		InUse = "Photobooth\nIn Use",
	},
}

return Photobooth
