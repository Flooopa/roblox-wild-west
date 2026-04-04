--[[
	WILD WEST RUN SYSTEM
	Place this LocalScript inside StarterPlayer > StarterCharacterScripts
]]

-- -------------------------------
--           CONFIG
-- -------------------------------
local WALK_SPEED               = 16
local SPRINT_SPEED             = 30
local EXHAUSTED_SPEED          = 10
local MAX_STAMINA              = 250
local STAMINA_DRAIN            = 35
local STAMINA_REGEN            = 50
local EXHAUSTED_REGEN          = 5
local EXHAUSTED_THRESHOLD      = 20
local REGEN_DELAY_AFTER_SPRINT = 0.5

local SPRINT_ANIM_ID           = "rbxassetid://70521030612171"

-- -------------------------------
--           SERVICES
-- -------------------------------
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")
local camera    = workspace.CurrentCamera

-- -------------------------------
--           ANIMATION
-- -------------------------------
local animator = humanoid:WaitForChild("Animator")
local sprintAnim = Instance.new("Animation")
sprintAnim.AnimationId = SPRINT_ANIM_ID
local sprintTrack = animator:LoadAnimation(sprintAnim)
sprintTrack.Priority = Enum.AnimationPriority.Action

-- -------------------------------
--           STATE
-- -------------------------------
local stamina          = MAX_STAMINA
local isSprinting      = false
local isExhausted      = false
local regenBlockedUntil = 0

character:SetAttribute("Stamina", stamina)
character:SetAttribute("MaxStamina", MAX_STAMINA)
character:SetAttribute("M1RegenDelay", 0)

-- -------------------------------
--           GUI
-- -------------------------------
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("RunHUD") then
	playerGui.RunHUD:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RunHUD"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

local bg = Instance.new("Frame")
bg.Size = UDim2.new(0, 200, 0, 16)
bg.Position = UDim2.new(0.5, -100, 1, -50)
bg.BackgroundColor3 = Color3.fromRGB(30, 18, 8)
bg.BorderSizePixel = 0
bg.Visible = false
bg.Parent = screenGui
Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 5)

local stroke = Instance.new("UIStroke", bg)
stroke.Color = Color3.fromRGB(140, 90, 40)
stroke.Thickness = 1.5

local fill = Instance.new("Frame", bg)
fill.Size = UDim2.new(1, 0, 1, 0)
fill.BackgroundColor3 = Color3.fromRGB(210, 155, 60)
fill.BorderSizePixel = 0
Instance.new("UICorner", fill).CornerRadius = UDim.new(0, 5)

local label = Instance.new("TextLabel", bg)
label.Size = UDim2.new(1, 0, 0, 13)
label.Position = UDim2.new(0, 0, -1, -1)
label.BackgroundTransparency = 1
label.Text = "STAMINA"
label.TextColor3 = Color3.fromRGB(200, 160, 80)
label.Font = Enum.Font.Antique
label.TextSize = 11
label.TextXAlignment = Enum.TextXAlignment.Center

local exhaustLabel = Instance.new("TextLabel", screenGui)
exhaustLabel.Size = UDim2.new(0, 280, 0, 24)
exhaustLabel.Position = UDim2.new(0.5, -140, 1, -80)
exhaustLabel.BackgroundTransparency = 1
exhaustLabel.Text = "TOO TIRED"
exhaustLabel.TextColor3 = Color3.fromRGB(210, 80, 50)
exhaustLabel.Font = Enum.Font.Antique
exhaustLabel.TextSize = 15
exhaustLabel.Visible = false

-- -------------------------------
--         DUST PARTICLES
-- -------------------------------
local attachment = Instance.new("Attachment", rootPart)
attachment.Position = Vector3.new(0, -2.5, 0)

local dust = Instance.new("ParticleEmitter", attachment)
dust.Texture = "rbxassetid://242102981"
dust.Color = ColorSequence.new(Color3.fromRGB(180, 140, 90), Color3.fromRGB(210, 190, 150))
dust.Lifetime = NumberRange.new(0.3, 0.6)
dust.Rate = 0
dust.Speed = NumberRange.new(3, 8)
dust.Size = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(0.5, 0.8),
	NumberSequenceKeypoint.new(1, 0),
})
dust.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.4),
	NumberSequenceKeypoint.new(1, 1),
})
dust.SpreadAngle = Vector2.new(50, 50)
dust.RotSpeed = NumberRange.new(-60, 60)
dust.Rotation = NumberRange.new(0, 360)

-- -------------------------------
--         HELPER FUNCTIONS
-- -------------------------------
local function updateBar()
	stamina = character:GetAttribute("Stamina") or stamina
	local pct = stamina / MAX_STAMINA
	fill.Size = UDim2.new(pct, 0, 1, 0)
	fill.BackgroundColor3 = isExhausted
		and Color3.fromRGB(160, 50, 30)
		or (pct < 0.3 and Color3.fromRGB(210, 100, 40) or Color3.fromRGB(210, 155, 60))
end

local function tweenFOV(target)
	TweenService:Create(camera, TweenInfo.new(0.3), {FieldOfView = target}):Play()
end

local function blockRegen(duration)
	regenBlockedUntil = math.max(regenBlockedUntil, tick() + duration)
end

local hideThread = nil

local function hideBarAfterDelay()
	if hideThread then
		task.cancel(hideThread)
	end

	hideThread = task.delay(3, function()
		TweenService:Create(bg, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
		TweenService:Create(fill, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.5), {Transparency = 1}):Play()
		TweenService:Create(label, TweenInfo.new(0.5), {TextTransparency = 1}):Play()
		task.wait(0.5)
		bg.Visible = false
	end)
end

local function showBarInstant()
	if hideThread then
		task.cancel(hideThread)
	end

	bg.BackgroundTransparency = 0
	fill.BackgroundTransparency = 0
	stroke.Transparency = 0
	label.TextTransparency = 0
	bg.Visible = true
end

-- -------------------------------
--         SPRINT LOGIC
-- -------------------------------
local function startSprint()
	isSprinting = true
	humanoid.WalkSpeed = SPRINT_SPEED
	dust.Rate = 20
	tweenFOV(85)
	showBarInstant()
	sprintTrack:Play()
end

local function stopSprint()
	isSprinting = false
	humanoid.WalkSpeed = isExhausted and EXHAUSTED_SPEED or WALK_SPEED
	dust.Rate = 0
	tweenFOV(70)
	sprintTrack:Stop()
	blockRegen(REGEN_DELAY_AFTER_SPRINT)

	if not isExhausted then
		hideBarAfterDelay()
	end
end

local function enterExhausted()
	isExhausted = true
	isSprinting = false
	humanoid.WalkSpeed = EXHAUSTED_SPEED
	dust.Rate = 0
	tweenFOV(70)
	showBarInstant()
	sprintTrack:Stop()
	exhaustLabel.Visible = true
end

local function exitExhausted()
	isExhausted = false
	exhaustLabel.Visible = false
	humanoid.WalkSpeed = WALK_SPEED
	hideBarAfterDelay()
end

-- -------------------------------
--           MAIN LOOP
-- -------------------------------
humanoid.WalkSpeed = WALK_SPEED

RunService.Heartbeat:Connect(function(dt)
	stamina = character:GetAttribute("Stamina") or stamina

	local shiftDown = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
	local isMoving = humanoid.MoveDirection.Magnitude > 0
	local isM1Attacking = character:GetAttribute("IsM1Attacking") == true
	local m1RegenDelay = character:GetAttribute("M1RegenDelay") or 0

	if m1RegenDelay > 0 then
		blockRegen(m1RegenDelay)
		character:SetAttribute("M1RegenDelay", 0)
	end

	if isM1Attacking and isSprinting then
		stopSprint()
	elseif shiftDown and isMoving and not isSprinting and not isExhausted and not isM1Attacking and stamina > 0 then
		startSprint()
	elseif (not shiftDown or not isMoving or isM1Attacking) and isSprinting then
		stopSprint()
	end

	if isSprinting and isMoving then
		stamina = math.max(0, stamina - STAMINA_DRAIN * dt)
		character:SetAttribute("Stamina", stamina)

		if stamina <= 0 then
			enterExhausted()
		end
	elseif isExhausted then
		if tick() >= regenBlockedUntil then
			stamina = math.min(MAX_STAMINA, stamina + EXHAUSTED_REGEN * dt)
			character:SetAttribute("Stamina", stamina)

			if stamina >= EXHAUSTED_THRESHOLD then
				exitExhausted()
			end
		end
	else
		if tick() >= regenBlockedUntil then
			stamina = math.min(MAX_STAMINA, stamina + STAMINA_REGEN * dt)
			character:SetAttribute("Stamina", stamina)
		end
	end

	updateBar()
end)

humanoid.Died:Connect(function()
	screenGui:Destroy()
	attachment:Destroy()
end)

print("[WildWestRunSystem] Loaded! Hold Shift to sprint, partner.")
