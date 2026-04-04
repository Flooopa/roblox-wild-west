--[[
    M1 CLIENT
    StarterPlayer > StarterCharacterScripts
]]

-- -------------------------------
--           CONFIG
-- -------------------------------
local M1_STAMINA_COST = { 20, 20, 25, 30 }
local M1_REGEN_DELAY  = 1.0
local COMBO_WINDOW    = 1
local JUMP_LOCK_TIME  = 0.8
local COOLDOWN        = { 0.6, 0.6, 0.8, 1.2 }

local GROUND_ANIMS = {
	"rbxassetid://119354324294883",
	"rbxassetid://101758376070847",
	"rbxassetid://100832418817615",
	"rbxassetid://80136769942428",
}

local AIR_ANIMS = {
	"rbxassetid://119354324294883",
	"rbxassetid://101758376070847",
	"rbxassetid://139634318361426",
	"rbxassetid://128208733840855",
}

local HIT_REACT_IDS = {
	"rbxassetid://77006523468588",
	"rbxassetid://113489182813370",
	"rbxassetid://101189530929666",
	"rbxassetid://77006523468588",
}

-- -------------------------------
--           SERVICES
-- -------------------------------
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local animator  = humanoid:WaitForChild("Animator")

local Remotes      = ReplicatedStorage:WaitForChild("Remotes")
local M1Hit        = Remotes:WaitForChild("M1Hit")
local CancelAnims  = Remotes:WaitForChild("CancelAnims")
local PlayHitReact = Remotes:WaitForChild("PlayHitReact")
local StunEnd      = Remotes:WaitForChild("StunEnd")

-- -------------------------------
--        LOAD ANIMATIONS
-- -------------------------------
local function loadTrack(id, priority)
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Priority = priority or Enum.AnimationPriority.Action3
	track.Looped = false
	return track
end

local groundTracks   = {}
local airTracks      = {}
local hitReactTracks = {}

for i, id in ipairs(GROUND_ANIMS) do
	groundTracks[i] = loadTrack(id, Enum.AnimationPriority.Action3)
end

for i, id in ipairs(AIR_ANIMS) do
	airTracks[i] = loadTrack(id, Enum.AnimationPriority.Action3)
end

for i, id in ipairs(HIT_REACT_IDS) do
	hitReactTracks[i] = loadTrack(id, Enum.AnimationPriority.Action4)
end

-- -------------------------------
--           STATE
-- -------------------------------
local comboIndex     = 0
local lastHitTime    = 0
local canHit         = true
local isAirCombo     = false
local inCombo        = false
local isStunned      = false
local comboEndThread = nil

character:SetAttribute("IsM1Attacking", false)

-- -------------------------------
--         INPUT HANDLER
-- -------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType ~= Enum.UserInputType.MouseButton1
		and input.KeyCode ~= Enum.KeyCode.ButtonR2 then
		return
	end

	if not canHit then return end
	if humanoid.Health <= 0 then return end
	if isStunned then return end
	if character:FindFirstChildOfClass("Tool") then return end

	local now = tick()
	local spaceHeld = UserInputService:IsKeyDown(Enum.KeyCode.Space)

	if now - lastHitTime > COMBO_WINDOW then
		comboIndex = 0
		isAirCombo = false
	end

	comboIndex = (comboIndex % 4) + 1

	local currentStamina = character:GetAttribute("Stamina") or 0
	local staminaCost = M1_STAMINA_COST[comboIndex] or 0
	if currentStamina < staminaCost then
		return
	end

	character:SetAttribute("Stamina", currentStamina - staminaCost)
	character:SetAttribute("M1RegenDelay", M1_REGEN_DELAY)

	if comboIndex == 1 then
		isAirCombo = false
	elseif comboIndex == 2 and spaceHeld then
		isAirCombo = true
	end

	inCombo = true
	canHit = false
	lastHitTime = now

	character:SetAttribute("IsM1Attacking", true)

	if comboEndThread then
		task.cancel(comboEndThread)
	end

	comboEndThread = task.delay(JUMP_LOCK_TIME, function()
		inCombo = false
	end)

	local tracks = isAirCombo and airTracks or groundTracks
	tracks[comboIndex]:Play()

	M1Hit:FireServer(comboIndex, isAirCombo)

	task.delay(COOLDOWN[comboIndex], function()
		canHit = true
		character:SetAttribute("IsM1Attacking", false)
	end)
end)

-- -------------------------------
--       CANCEL ANIMS (stun)
-- -------------------------------
CancelAnims.OnClientEvent:Connect(function()
	for _, track in ipairs(groundTracks) do
		if track.IsPlaying then
			track:Stop()
		end
	end

	for _, track in ipairs(airTracks) do
		if track.IsPlaying then
			track:Stop()
		end
	end

	for _, track in ipairs(hitReactTracks) do
		if track.IsPlaying then
			track:Stop()
		end
	end

	isStunned = true
end)

-- -------------------------------
--         HIT REACT
-- -------------------------------
PlayHitReact.OnClientEvent:Connect(function(animId)
	for _, track in ipairs(groundTracks) do
		if track.IsPlaying then
			track:Stop()
		end
	end

	for _, track in ipairs(airTracks) do
		if track.IsPlaying then
			track:Stop()
		end
	end

	for _, track in ipairs(hitReactTracks) do
		if track.Animation.AnimationId == animId then
			track:Play()
			break
		end
	end
end)

-- -------------------------------
--         JUMP BLOCK
-- -------------------------------
RunService.Heartbeat:Connect(function()
	if inCombo then
		humanoid.JumpPower = 0
		humanoid.JumpHeight = 0
	else
		humanoid.JumpPower = 50
		humanoid.JumpHeight = 7.2
	end
end)

RunService.Heartbeat:Connect(function()
	if isStunned then
		for _, track in ipairs(groundTracks) do
			if track.IsPlaying then
				track:Stop()
			end
		end

		for _, track in ipairs(airTracks) do
			if track.IsPlaying then
				track:Stop()
			end
		end

		for _, track in ipairs(hitReactTracks) do
			if track.IsPlaying then
				track:Stop()
			end
		end
	end
end)

StunEnd.OnClientEvent:Connect(function()
	isStunned = false
end)

print("M1Client ready")
