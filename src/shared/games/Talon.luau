--!strict
-- Talon, the one-button runner in the phone: physics, the obstacle patterns and the race course.
-- Shared so every racer gets the same course from the same seed, and so the server can tell how
-- fast a race can possibly be finished (TalonService).
--
-- Course coordinates are pixels: x grows to the right from the start line, y is the game view's
-- (Ground is the ground line, smaller y is higher up).

local Talon = {
	-- Multiplayer: how close (studs) a player must be to the host to see and join a room.
	JoinDistance = 20,
	-- Players per room, host included.
	MaxPlayers = 4,
	-- Seconds between the host tapping Start and the run starting.
	CountdownSeconds = 3,
	-- A race ends with no winner after this many seconds.
	RaceTimeout = 240,
	-- Race length in metres.
	RaceMeters = 240,

	PixelsPerMeter = 40,
	Ground = 262,
	-- Run speed (pixels/second): starts slow, speeds up, and resets when you respawn.
	StartSpeed = 190,
	MaxSpeed = 300,
	SpeedGain = 3.5,
	Gravity = 2700,
	JumpSpeed = 740,

	Spike = 24, -- size of the rotated square that draws a spike
	Block = 32,
	-- The first stretch of a run only uses the easy patterns.
	EasyStretch = 600,
}

export type Obstacle = {
	kind: string, -- "spike" | "block" | "finish"
	x: number, -- left edge
	w: number,
	top: number,
	bottom: number,
}

type Piece = { kind: string, dx: number, w: number, h: number, lift: number }

local function spike(dx: number): Piece
	return { kind = "spike", dx = dx, w = 0, h = 0, lift = 0 }
end
local function block(dx: number, w: number, h: number, lift: number): Piece
	return { kind = "block", dx = dx, w = w, h = h, lift = lift }
end

local B = Talon.Block
-- The first three are the easy ones.
local PATTERNS: { { pieces: { Piece }, width: number } } = {
	{ pieces = { spike(0) }, width = 24 },
	{ pieces = { spike(0), spike(24) }, width = 48 },
	{ pieces = { block(0, B, B, 0) }, width = B },
	{ pieces = { block(0, B * 2, B, 0), spike(B * 2 + 40) }, width = B * 2 + 64 },
	{ pieces = { block(0, B, B, 0), block(B, B, B * 2, 0) }, width = B * 2 },
	{ pieces = { spike(10), spike(34), spike(58), block(0, B * 3, 14, 58) }, width = B * 3 },
	{ pieces = { spike(0), block(90, B, B, 0), spike(B + 120) }, width = B + 144 },
}

-- Adds one random obstacle pattern starting at atX to `into`; returns the x where the next
-- pattern may start (pattern width plus a gap).
function Talon.addPattern(rng: Random, atX: number, into: { Obstacle }): number
	local easy = atX < Talon.EasyStretch + 400
	local pattern = PATTERNS[rng:NextInteger(1, if easy then 3 else #PATTERNS)]
	local ground = Talon.Ground
	for _, piece in pattern.pieces do
		if piece.kind == "spike" then
			-- Hitbox of the spike's visible triangle, centred 12 px into its slot.
			local half = Talon.Spike * 0.7
			table.insert(into, {
				kind = "spike",
				x = atX + piece.dx + 12 - half,
				w = half * 2,
				top = ground - half,
				bottom = ground,
			})
		else
			table.insert(into, {
				kind = "block",
				x = atX + piece.dx,
				w = piece.w,
				top = ground - piece.lift - piece.h,
				bottom = ground - piece.lift,
			})
		end
	end
	return atX + pattern.width + rng:NextInteger(170, 290) + 70
end

-- The race course for a seed: obstacles in x order, ending with the finish line.
function Talon.raceCourse(seed: number): ({ Obstacle }, number)
	local rng = Random.new(seed)
	local finishX = Talon.RaceMeters * Talon.PixelsPerMeter
	local course: { Obstacle } = {}
	local x = 320
	while x < finishX - 260 do
		x = Talon.addPattern(rng, x, course)
	end
	table.insert(course, { kind = "finish", x = finishX, w = 12, top = 0, bottom = Talon.Ground })
	return course, finishX
end

-- The fastest a run can cover `distance` pixels without dying (seconds).
function Talon.fastestTime(distance: number): number
	local v0, vMax, a = Talon.StartSpeed, Talon.MaxSpeed, Talon.SpeedGain
	local rampTime = (vMax - v0) / a
	local rampDistance = v0 * rampTime + a * rampTime * rampTime / 2
	if distance <= rampDistance then
		-- Solve v0 t + a t^2 / 2 = distance.
		return (-v0 + math.sqrt(v0 * v0 + 2 * a * distance)) / a
	end
	return rampTime + (distance - rampDistance) / vMax
end

return Talon
