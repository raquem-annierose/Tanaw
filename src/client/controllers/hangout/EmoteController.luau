--!strict
-- Plays emotes from the phone's Emotes app on this player's character. Animations played on
-- your own character replicate to everyone, so no server code is needed.
--
-- An emote stops when the player walks, jumps or sits, or taps the same emote again.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Emotes = require(ReplicatedStorage.Shared.hangout.Emotes)

local EmoteController = {}

local changedEvent = Instance.new("BindableEvent")
-- Fires with (emoteId: string?) when an emote starts or stops.
EmoteController.Changed = changedEvent.Event

local player = Players.LocalPlayer
local currentId: string? = nil
local currentTrack: AnimationTrack? = nil
-- Loaded tracks for the current character, by emote id.
local tracks: { [string]: AnimationTrack } = {}

local function getHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

function EmoteController.getCurrent(): string?
	return currentId
end

function EmoteController.stop()
	if currentTrack then
		currentTrack:Stop(0.2)
	end
	currentTrack = nil
	if currentId then
		currentId = nil
		changedEvent:Fire(nil)
	end
end

function EmoteController.play(id: string)
	if currentId == id then
		EmoteController.stop()
		return
	end
	local emote = Emotes.ById[id]
	local humanoid = getHumanoid()
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not emote or not humanoid or not animator or humanoid.Sit or humanoid.Health <= 0 then
		return
	end
	if humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		return
	end

	EmoteController.stop()

	local playing = tracks[id]
	if not playing then
		local animation = Instance.new("Animation")
		animation.AnimationId = `rbxassetid://{emote.AnimationId}`
		local loaded = animator:LoadAnimation(animation)
		loaded.Priority = Enum.AnimationPriority.Action
		tracks[id] = loaded
		playing = loaded
	end
	playing.Looped = emote.Looped
	playing:Play(0.2)
	currentTrack = playing
	currentId = id
	changedEvent:Fire(id)

	if not emote.Looped then
		playing.Stopped:Once(function()
			if currentTrack == playing then
				currentTrack = nil
				currentId = nil
				changedEvent:Fire(nil)
			end
		end)
	end
end

local function watchCharacter(character: Model)
	table.clear(tracks)
	currentTrack = nil
	if currentId then
		currentId = nil
		changedEvent:Fire(nil)
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid:GetPropertyChangedSignal("MoveDirection"):Connect(function()
		if currentId and humanoid.MoveDirection.Magnitude > 0.1 then
			EmoteController.stop()
		end
	end)
	humanoid.StateChanged:Connect(function(_, new: Enum.HumanoidStateType)
		if
			currentId
			and (
				new == Enum.HumanoidStateType.Jumping
				or new == Enum.HumanoidStateType.Seated
				or new == Enum.HumanoidStateType.Dead
			)
		then
			EmoteController.stop()
		end
	end)
end

function EmoteController.start()
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

return EmoteController
