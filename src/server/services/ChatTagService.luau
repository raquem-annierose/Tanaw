--!strict
-- Looks up each player's roles in the NieRa Studios community when they join and, if one of
-- them has a chat tag in Config.ChatTags, stores that role name as the "ChatTag" attribute on
-- the Player. ChatTagController reads the attribute on every client to show the tag in chat.
--
-- The lookup runs on the server so every client sees the same tag, and a client can't give
-- itself one. A member can hold several roles; the first match in Config.ChatTagOrder wins.

local GroupService = game:GetService("GroupService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local ATTRIBUTE = "ChatTag"
local RETRIES = 3

local ChatTagService = {}

-- Role names the player holds in the community. Errors are passed on to the caller.
local function roleNames(player: Player): { [string]: boolean }
	-- Shape: { IsMember = true, Roles = { { Id = ..., Name = "Owner", Rank = ... }, ... } }
	local result = GroupService:GetRolesInGroupAsync(player.UserId, Config.CommunityId)
	local names = {}
	if type(result) == "table" and type(result.Roles) == "table" then
		for _, role in result.Roles do
			if type(role) == "table" and type(role.Name) == "string" then
				names[role.Name] = true
			end
		end
	end
	return names
end

local function lookUp(player: Player)
	for attempt = 1, RETRIES do
		-- Calls a Roblox web API, which can fail now and then.
		local ok, names = pcall(roleNames, player)
		if ok then
			for _, role in Config.ChatTagOrder do
				if names[role] and Config.ChatTags[role] then
					if player.Parent then
						player:SetAttribute(ATTRIBUTE, role)
					end
					return
				end
			end
			return
		end
		task.wait(attempt * 2)
	end
end

function ChatTagService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(lookUp, player)
	end
	Players.PlayerAdded:Connect(lookUp)
end

return ChatTagService
