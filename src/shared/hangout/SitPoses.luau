--!strict
-- Sitting poses for the pallet seats. One is picked at random each time a player sits.
--
-- Each pose sets R15 joint rotations in degrees (X, Y, Z), applied as CFrame.Angles.
-- Checked in a Studio playtest on the current R15 rig:
--   Hip / Shoulder X+  = swing the limb forward (and up)
--   Hip Y              = twist the thigh (used to turn the knees out for cross-legged)
--   Knee X-            = bend the knee
--   Elbow X+           = bend the forearm up
--   Shoulder Z         = LeftShoulder +Z / RightShoulder -Z bring the arm in toward the body
--   Root / Waist X+    = lean the body back
-- R6 avatars keep Roblox's normal sitting animation.

export type Pose = {
	Id: string,
	Joints: { [string]: Vector3 },
}

local Relax: Pose = {
	-- Leaning back on both hands, legs stretched out.
	Id = "Relax",
	Joints = {
		Root = Vector3.new(18, 0, 0),
		Waist = Vector3.new(0, 0, 0),
		LeftHip = Vector3.new(72, 0, 0),
		RightHip = Vector3.new(72, 0, 0),
		LeftKnee = Vector3.new(-8, 0, 0),
		RightKnee = Vector3.new(-8, 0, 0),
		LeftShoulder = Vector3.new(-40, 0, -14),
		RightShoulder = Vector3.new(-40, 0, 14),
		LeftElbow = Vector3.new(0, 0, 0),
		RightElbow = Vector3.new(0, 0, 0),
	},
}

local CrossLegged: Pose = {
	-- Indian sit: knees out, legs crossed in front, hands resting near the knees.
	Id = "CrossLegged",
	Joints = {
		Root = Vector3.new(0, 0, 0),
		Waist = Vector3.new(-6, 0, 0),
		LeftHip = Vector3.new(90, 70, 0),
		RightHip = Vector3.new(90, -70, 0),
		LeftKnee = Vector3.new(-115, 0, 0),
		RightKnee = Vector3.new(-115, 0, 0),
		LeftShoulder = Vector3.new(25, 0, 0),
		RightShoulder = Vector3.new(25, 0, 0),
		LeftElbow = Vector3.new(25, 0, 0),
		RightElbow = Vector3.new(25, 0, 0),
	},
}

local HugKnees: Pose = {
	-- Knees pulled up to the chest, arms wrapped around them.
	Id = "HugKnees",
	Joints = {
		Root = Vector3.new(8, 0, 0),
		Waist = Vector3.new(-14, 0, 0),
		LeftHip = Vector3.new(128, 0, 0),
		RightHip = Vector3.new(128, 0, 0),
		LeftKnee = Vector3.new(-140, 0, 0),
		RightKnee = Vector3.new(-140, 0, 0),
		LeftShoulder = Vector3.new(42, 0, 28),
		RightShoulder = Vector3.new(42, 0, -28),
		LeftElbow = Vector3.new(25, 0, 0),
		RightElbow = Vector3.new(25, 0, 0),
	},
}

local OneKneeUp: Pose = {
	-- One leg out, one knee up with an arm resting on it, other hand behind for support.
	Id = "OneKneeUp",
	Joints = {
		Root = Vector3.new(12, 0, 0),
		Waist = Vector3.new(0, 6, 0),
		LeftHip = Vector3.new(76, 0, 0),
		LeftKnee = Vector3.new(-6, 0, 0),
		RightHip = Vector3.new(122, 0, 0),
		RightKnee = Vector3.new(-120, 0, 0),
		LeftShoulder = Vector3.new(-38, 0, -16),
		LeftElbow = Vector3.new(0, 0, 0),
		RightShoulder = Vector3.new(36, 0, -10),
		RightElbow = Vector3.new(30, 0, 0),
	},
}

local SitPoses = {
	Order = { "Relax", "CrossLegged", "HugKnees", "OneKneeUp" },
	Poses = {
		Relax = Relax,
		CrossLegged = CrossLegged,
		HugKnees = HugKnees,
		OneKneeUp = OneKneeUp,
	} :: { [string]: Pose },
	-- Attribute set on the character by the server; every client reads it.
	Attribute = "SitPose",
	-- CollectionService tag on the Seat parts in Studio.
	SeatTag = "PoseSeat",
}

return SitPoses
