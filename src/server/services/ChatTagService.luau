--!strict
-- For players who hold a staff role in the NieRa Studios community (Config.ChatTags), stores
-- that role name as the "ChatTag" attribute on the Player when they join. ChatTagController
-- reads the attribute on every client to show the tag in chat.
--
-- The lookup runs on the server so every client sees the same tag, and a client can't give
-- itself one. A member can hold several roles; the first match in Config.ChatTagOrder wins.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CommunityRoles = require(script.Parent.CommunityRoles)
local Config = require(ReplicatedStorage.Shared.Config)

local ATTRIBUTE = "ChatTag"

local ChatTagService = {}

local function lookUp(player: Player)
	local roles = CommunityRoles.get(player)
	for _, role in Config.ChatTagOrder do
		if roles[role] and Config.ChatTags[role] then
			if player.Parent then
				player:SetAttribute(ATTRIBUTE, role)
			end
			return
		end
	end
end

function ChatTagService.start()
	for _, player in Players:GetPlayers() do
		task.spawn(lookUp, player)
	end
	Players.PlayerAdded:Connect(lookUp)
end

return ChatTagService
