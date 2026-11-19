--!strict
-- Shows a colored tag before staff names in chat, e.g. "[Owner] ywro: hello".
--
-- The server (ChatTagService) puts the player's community role in the "ChatTag" attribute;
-- this only reads it, so tags look the same for everyone. Tag text and colors are in
-- Config.ChatTags.
--
-- TextChatService allows one OnIncomingMessage callback per client. If another feature needs
-- it later, merge it into this one instead of assigning a second callback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TextChatService = game:GetService("TextChatService")

local Config = require(ReplicatedStorage.Shared.Config)

local ATTRIBUTE = "ChatTag"

local ChatTagController = {}

function ChatTagController.start()
	TextChatService.OnIncomingMessage = function(
		message: TextChatMessage
	): TextChatMessageProperties?
		local source = message.TextSource
		if not source then
			return nil
		end
		local player = Players:GetPlayerByUserId(source.UserId)
		local role = player and player:GetAttribute(ATTRIBUTE)
		local tag = if typeof(role) == "string" then Config.ChatTags[role] else nil
		if not tag then
			return nil
		end

		local properties = Instance.new("TextChatMessageProperties")
		properties.PrefixText =
			`<font color="#{tag.Color:ToHex()}">[{tag.Text}]</font> {message.PrefixText}`
		return properties
	end
end

return ChatTagController
