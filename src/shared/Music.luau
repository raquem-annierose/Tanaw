--!strict
-- Background music playlist (Tagalog songs), played as one radio for the whole server.
--
-- Only use audio that the game is allowed to play: tracks from the Creator Store published by
-- DistrokidOfficial / APMOfficial / MonstercatOfficial (licensed for Roblox), or audio uploaded by
-- NieRa Studios itself. Don't upload copyrighted OPM hits: Roblox takes them down and can moderate
-- the account. Private audio from other uploaders won't play in this game anyway.
--
-- To add a song: Creator Store → Audio → search, copy the number from the URL
-- (create.roblox.com/store/asset/<this number>), and add a line below. Seconds is the song's
-- length (shown on the Creator Store page); the server moves to the next song after that long.

export type Track = {
	Id: number,
	Title: string,
	Seconds: number,
}

local Music = {
	-- Sound volume when a player's slider is at 100%. Kept low so voice chat still comes through.
	MaxVolume = 0.4,
	-- Where each player's slider starts (0 to 1).
	DefaultLevel = 0.5,
	FadeSeconds = 1.5,
	-- Quiet gap between songs.
	GapSeconds = 2,
	-- If a player's song drifts this far from the server's, it jumps back in sync.
	MaxDriftSeconds = 2,

	-- The server keeps the current song on this folder in ReplicatedStorage as attributes:
	--   TrackId: number, Title: string, StartedAt: number (workspace:GetServerTimeNow())
	RadioFolder = "Radio",

	Playlist = {
		{ Id = 122136302706638, Title = "Sa Sunset Ng Buhay", Seconds = 288 },
		{ Id = 115848107927096, Title = "Sana Ako Na Lang", Seconds = 200 },
		{ Id = 75515706395423, Title = "Kilig", Seconds = 206 },
		{ Id = 116760152292892, Title = "Balik Tanaw", Seconds = 232 },
		{ Id = 139595055877224, Title = "Nakapagtataka", Seconds = 310 },
		{ Id = 90696126940624, Title = "Tahan Na", Seconds = 220 },
		{ Id = 108370050229944, Title = "Walang Pasabi", Seconds = 297 },
		{ Id = 97788054067271, Title = "Tapos Na Pala", Seconds = 252 },
		{ Id = 76548287449990, Title = "Ikaw at Ako sa Buhangin", Seconds = 200 },
		{ Id = 100927847170879, Title = "Mundo Ko'y Sumigla", Seconds = 222 },
		{ Id = 127292805764303, Title = "Ang Mga Ibon na Lumilipad (Lofi)", Seconds = 132 },
		{ Id = 101082283407538, Title = "Tara Na Magbyahe", Seconds = 213 },
	} :: { Track },
}

return Music
