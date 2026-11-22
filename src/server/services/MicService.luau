--!strict
-- Stage mic: when a player stands at a mic tagged "StageMic", their voice also plays
-- from the stage speakers (parts tagged "StageSpeaker") with an echo.
--
-- Uses the voice Audio API (VoiceChatService.UseAudioApi = Enabled): each voice-enabled
-- player has an AudioDeviceInput. We wire it into an AudioEcho -> AudioFader -> the
-- speaker AudioEmitters while they are in range, and unwire it when they walk away.
-- Their normal voice from their character keeps playing as usual.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local MIC_TAG = "StageMic"
local SPEAKER_TAG = "StageSpeaker"
local DEFAULT_RANGE = 3.5 -- studs from the mic stand (flat distance); mic attr "Range" overrides
local MAX_HEIGHT = 7
local CHECK_EVERY = 0.2

local MicService = {}

type MicState = {
	part: BasePart,
	echo: AudioEcho,
	wires: { [Player]: Wire },
}

local mics: { [BasePart]: MicState } = {}

local function speakerCurve(): { [number]: number }
	return { [0] = 1, [25] = 0.8, [70] = 0.35, [140] = 0 }
end

local function findSpeakers(mic: BasePart): { BasePart }
	local stage = mic:FindFirstAncestor("Stage")
	local result = {}
	for _, inst in CollectionService:GetTagged(SPEAKER_TAG) do
		if inst:IsA("BasePart") and (stage == nil or inst:IsDescendantOf(stage)) then
			table.insert(result, inst)
		end
	end
	return result
end

local function wire(source: Instance, target: Instance, parent: Instance): Wire
	local w = Instance.new("Wire")
	w.SourceInstance = source
	w.TargetInstance = target
	w.Parent = parent
	return w
end

local function setupMic(instance: Instance)
	if not instance:IsA("BasePart") or mics[instance] then
		return
	end
	local mic: BasePart = instance

	local echo = Instance.new("AudioEcho")
	echo.Name = "MicEcho"
	echo.DelayTime = 0.28
	echo.Feedback = 0.4
	echo.DryLevel = 0
	echo.WetLevel = -4
	echo.Parent = mic

	local fader = Instance.new("AudioFader")
	fader.Name = "MicVolume"
	fader.Volume = 1.4
	fader.Parent = mic
	wire(echo, fader, mic)

	for _, speaker in findSpeakers(mic) do
		local emitter = Instance.new("AudioEmitter")
		emitter.Name = "MicEmitter"
		emitter:SetDistanceAttenuation(speakerCurve())
		emitter.Parent = speaker
		wire(fader, emitter, speaker)
	end

	mics[mic] = { part = mic, echo = echo, wires = {} }
	mic.Destroying:Connect(function()
		mics[mic] = nil
	end)
end

local function isAtMic(player: Player, mic: BasePart): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local range = mic:GetAttribute("Range")
	local r = if typeof(range) == "number" then range else DEFAULT_RANGE
	local offset = root.Position - mic.Position
	return Vector3.new(offset.X, 0, offset.Z).Magnitude <= r and math.abs(offset.Y) <= MAX_HEIGHT
end

local function update()
	for _, state in mics do
		for _, player in Players:GetPlayers() do
			local input = player:FindFirstChildWhichIsA("AudioDeviceInput")
			local existing = state.wires[player]
			if input and isAtMic(player, state.part) then
				if not existing or existing.SourceInstance ~= input then
					if existing then
						existing:Destroy()
					end
					state.wires[player] = wire(input, state.echo, state.part)
				end
			elseif existing then
				existing:Destroy()
				state.wires[player] = nil
			end
		end
		state.part:SetAttribute("Live", next(state.wires) ~= nil)
	end
end

function MicService.start()
	for _, mic in CollectionService:GetTagged(MIC_TAG) do
		setupMic(mic)
	end
	CollectionService:GetInstanceAddedSignal(MIC_TAG):Connect(setupMic)

	Players.PlayerRemoving:Connect(function(player: Player)
		for _, state in mics do
			local w = state.wires[player]
			if w then
				w:Destroy()
				state.wires[player] = nil
			end
		end
	end)

	task.spawn(function()
		while true do
			update()
			task.wait(CHECK_EVERY)
		end
	end)
end

return MicService
