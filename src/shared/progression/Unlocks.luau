--!strict
-- Feature unlocks: which features need something before players can use them, and the shared
-- rules for checking it. The server decides (UnlockService) and the client shows it
-- (UnlockController, phone LockedOverlay).
--
-- To lock a new feature: add it to Features, then
--   server: `if not UnlockService.isUnlocked(player, "MyFeature") then return end` where it acts
--   client: `UnlockController.status("MyFeature")` or `LockedOverlay.attach(page, "MyFeature")`.
--
-- Requirement kinds:
--   Playtime - the player's all-time minutes in Tanaw (PlaytimeService), so regulars don't wait again.
--   Coins    - (for later) bought with coins; the server marks it owned after a purchase.
-- Changing a feature from Playtime to Coins only needs a new Requirement here plus the purchase
-- flow; the checks above stay the same.

export type Requirement = {
	Kind: string, -- "Playtime" | "Coins"
	Minutes: number?, -- Playtime
	Price: number?, -- Coins
}

export type Feature = {
	Label: string,
	Requirement: Requirement,
}

-- What a check knows about the player.
export type Context = {
	playSeconds: number, -- all-time seconds in Tanaw
	owned: { [string]: boolean }?, -- features bought (Coins)
}

export type Status = {
	unlocked: boolean,
	-- Playtime: seconds left until it unlocks.
	remaining: number?,
	-- Coins: what it costs.
	price: number?,
	-- Short text for the lock screen, e.g. "Mag-stay muna ng 5 minuto sa Tanaw."
	message: string,
}

local Unlocks = {
	-- Player attribute set by the server: the server time their all-time playtime "started", i.e.
	-- Workspace:GetServerTimeNow() - playtime. Lets the client count playtime without messages.
	PlaytimeAttribute = "PlaytimeStart",
	-- Player attribute prefix set by the server for each feature: "Unlocked_<FeatureId>".
	AttributePrefix = "Unlocked_",

	Features = {
		Games = {
			Label = "Games",
			Requirement = { Kind = "Playtime", Minutes = 5 },
		},
		FreedomWall = {
			Label = "Freedom Wall",
			Requirement = { Kind = "Playtime", Minutes = 5 },
		},
	} :: { [string]: Feature },
}

function Unlocks.attribute(featureId: string): string
	return Unlocks.AttributePrefix .. featureId
end

-- "3:05" style countdown.
function Unlocks.formatTime(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

function Unlocks.check(featureId: string, context: Context): Status
	local feature = Unlocks.Features[featureId]
	if not feature then
		-- Not listed: nothing to unlock.
		return { unlocked = true, message = "" }
	end
	local req = feature.Requirement
	if req.Kind == "Playtime" then
		local minutes = req.Minutes or 0
		local remaining = minutes * 60 - context.playSeconds
		return {
			unlocked = remaining <= 0,
			remaining = math.max(0, remaining),
			message = `Play {minutes} minutes in Tanaw to unlock {feature.Label}.`,
		}
	elseif req.Kind == "Coins" then
		local owned = context.owned
		local price = req.Price or 0
		return {
			unlocked = owned ~= nil and owned[featureId] == true,
			price = price,
			message = `Buy {feature.Label} for {price} coins.`,
		}
	end
	warn(`[Unlocks] Unknown requirement kind "{req.Kind}" for {featureId}`)
	return { unlocked = false, message = "Locked." }
end

return Unlocks
