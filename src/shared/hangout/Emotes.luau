--!strict
-- Emotes in the phone's Emotes app. Roblox's default R15 emote animations, which every game
-- may use. R6 avatars can't play them.

export type Emote = {
	Id: string,
	Label: string,
	-- Section in the Emotes app list (shown in Groups order).
	Group: string,
	AnimationId: number,
	-- Looped emotes keep going until the player moves or taps the emote again.
	Looped: boolean,
}

local Groups = { "Gestures", "Dances" }

local List: { Emote } = {
	{ Id = "Wave", Label = "Wave", Group = "Gestures", AnimationId = 507770239, Looped = false },
	{ Id = "Point", Label = "Point", Group = "Gestures", AnimationId = 507770453, Looped = false },
	{ Id = "Cheer", Label = "Cheer", Group = "Gestures", AnimationId = 507770677, Looped = false },
	{ Id = "Laugh", Label = "Laugh", Group = "Gestures", AnimationId = 507770818, Looped = false },
	{ Id = "Dance1", Label = "Groove", Group = "Dances", AnimationId = 507771019, Looped = true },
	{ Id = "Dance2", Label = "Bounce", Group = "Dances", AnimationId = 507776043, Looped = true },
	{ Id = "Dance3", Label = "Sway", Group = "Dances", AnimationId = 507777268, Looped = true },
}

local ById: { [string]: Emote } = {}
for _, emote in List do
	ById[emote.Id] = emote
end

return {
	Groups = Groups,
	List = List,
	ById = ById,
}
