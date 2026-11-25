--!strict
-- Mirror Photobooth sessions. One player per booth at a time; the server decides who has it
-- and when it is free again, so two players can't start it together and a client can't end
-- someone else's session. The client (PhotoboothController) does the camera, UI and capture.
--
-- Flow: prompt -> Preparing (client walks to the spot, says "Ready") -> Countdown -> client
-- takes the photo, says "Captured" -> Preview -> Retake (back to Preparing) or Done -> Thanks
-- -> Idle. Leaving, dying, respawning, leaving the server or the timeout end it early.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Photobooth = require(ReplicatedStorage.Shared.Photobooth)
local Remotes = require(ReplicatedStorage.Shared.Remotes)

-- The client's "Captured" may arrive a little before the server's clock reaches the end.
local CAPTURE_EARLY = 0.5

type Booth = {
	model: Model,
	prompt: ProximityPrompt,
	owner: Player?,
	-- Bumped on every state change so old delayed tasks know they're stale.
	token: number,
	-- Bumped for every new session (for the session timeout).
	session: number,
	countdownEnd: number,
	connections: { RBXScriptConnection },
}

local PhotoboothService = {}

local booths: { [Model]: Booth } = {}
local remote: RemoteEvent

local function setState(booth: Booth, state: Photobooth.State)
	booth.token += 1
	booth.model:SetAttribute("State", state)
	local busy = state ~= "Idle"
	booth.prompt.ActionText = if busy
		then Photobooth.Prompt.BusyText
		else Photobooth.Prompt.ActionText
end

local function disconnectAll(booth: Booth)
	for _, connection in booth.connections do
		connection:Disconnect()
	end
	table.clear(booth.connections)
end

-- Runs fn after `seconds` if the booth hasn't changed state since.
local function later(booth: Booth, seconds: number, fn: () -> ())
	local token = booth.token
	task.delay(seconds, function()
		if booth.token == token then
			fn()
		end
	end)
end

local function finish(booth: Booth, reason: string)
	local owner = booth.owner
	if not owner then
		return
	end
	booth.owner = nil
	disconnectAll(booth)
	booth.model:SetAttribute("OwnerName", "")
	if owner.Parent then
		remote:FireClient(owner, "End", booth.model, reason)
	end
	if reason == "Done" then
		setState(booth, "Thanks")
		later(booth, Photobooth.ThanksSeconds, function()
			setState(booth, "Idle")
		end)
	else
		setState(booth, "Idle")
	end
end

local function startCountdown(booth: Booth)
	local owner = booth.owner
	if not owner then
		return
	end
	setState(booth, "Countdown")
	local endsAt = Workspace:GetServerTimeNow() + Photobooth.Countdown
	booth.countdownEnd = endsAt
	booth.model:SetAttribute("CountdownEnd", endsAt)
	remote:FireClient(owner, "Countdown", booth.model, endsAt)
end

local function begin(booth: Booth, player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if booth.model:GetAttribute("State") ~= "Idle" then
		remote:FireClient(player, "Error", "May gumagamit pa ng photobooth. Saglit lang! 📸")
		return
	end
	for _, other in booths do
		if other.owner == player then
			return
		end
	end

	booth.owner = player
	booth.model:SetAttribute("OwnerName", player.DisplayName)
	setState(booth, "Preparing")
	remote:FireClient(player, "Start", booth.model)

	local function stop(reason: string)
		return function()
			if booth.owner == player then
				finish(booth, reason)
			end
		end
	end
	table.insert(booth.connections, humanoid.Died:Connect(stop("Died")))
	table.insert(booth.connections, player.CharacterRemoving:Connect(stop("Respawn")))

	-- Safety net: the whole session can't hold the booth forever.
	booth.session += 1
	local session = booth.session
	task.delay(Photobooth.SessionTimeout, function()
		if booth.owner == player and booth.session == session then
			finish(booth, "Timeout")
		end
	end)
end

local function onMessage(player: Player, kind: unknown, model: unknown)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	local booth = booths[model]
	-- Only the player using this booth can move it along.
	if not booth or booth.owner ~= player then
		return
	end
	local state = model:GetAttribute("State")

	if kind == "Ready" and state == "Preparing" then
		startCountdown(booth)
	elseif kind == "Captured" and state == "Countdown" then
		if Workspace:GetServerTimeNow() < booth.countdownEnd - CAPTURE_EARLY then
			return
		end
		setState(booth, "Preview")
		remote:FireClient(player, "Preview", model)
		later(booth, Photobooth.PreviewTimeout, function()
			finish(booth, "Done")
		end)
	elseif kind == "Retake" and state == "Preview" then
		setState(booth, "Preparing")
		later(booth, Photobooth.PrepSeconds, function()
			startCountdown(booth)
		end)
	elseif kind == "Done" and state == "Preview" then
		finish(booth, "Done")
	elseif kind == "Leave" then
		finish(booth, "Leave")
	end
end

local function setup(instance: Instance)
	if not instance:IsA("Model") or booths[instance] then
		return
	end
	local display = instance:FindFirstChild("TouchDisplay")
	if not display or not display:IsA("BasePart") then
		warn(`[Photobooth] {instance:GetFullName()} has no TouchDisplay part`)
		return
	end

	-- The prompt sits low on the mirror, about chest height.
	local anchor = Instance.new("Attachment")
	anchor.Name = "PromptAttachment"
	anchor.Position = Vector3.new(0, -display.Size.Y / 2 + 3, 0)
	anchor.Parent = display

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PhotoboothPrompt"
	prompt.ActionText = Photobooth.Prompt.ActionText
	prompt.ObjectText = Photobooth.Prompt.ObjectText
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = Photobooth.Prompt.Distance
	prompt.RequiresLineOfSight = false
	prompt.Parent = anchor

	local booth: Booth = {
		model = instance,
		prompt = prompt,
		owner = nil,
		token = 0,
		session = 0,
		countdownEnd = 0,
		connections = {},
	}
	booths[instance] = booth
	instance:SetAttribute("OwnerName", "")
	setState(booth, "Idle")

	prompt.Triggered:Connect(function(player: Player)
		begin(booth, player)
	end)
end

function PhotoboothService.start()
	remote = Remotes.photobooth()
	remote.OnServerEvent:Connect(onMessage)

	for _, instance in CollectionService:GetTagged(Photobooth.Tag) do
		setup(instance)
	end
	CollectionService:GetInstanceAddedSignal(Photobooth.Tag):Connect(setup)

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, booth in booths do
			if booth.owner == player then
				finish(booth, "Left")
			end
		end
	end)
end

return PhotoboothService
