--[[
    CUSTOM SHIFT LOCK
    StarterPlayerScripts
]]

local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local rootPart  = character:WaitForChild("HumanoidRootPart")
local camera    = workspace.CurrentCamera

-- -------------------------------
--           CONFIG
-- -------------------------------
local CAMERA_OFFSET_X = 1.5
local CAMERA_OFFSET_Y = 0.5
local CAMERA_OFFSET_Z = 0

-- -------------------------------
--           STATE
-- -------------------------------
local shiftLocked   = false
local currentOffset = Vector3.new(0, 0, 0)
local side          = "Right"

-- -------------------------------
--           GUI
-- -------------------------------
local playerGui = player:WaitForChild("PlayerGui")

if playerGui:FindFirstChild("ShiftLockGui") then
	playerGui.ShiftLockGui:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "ShiftLockGui"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Parent = playerGui

local reticle = Instance.new("Frame")
reticle.Name = "Reticle"
reticle.Size = UDim2.new(0, 8, 0, 8)
reticle.Position = UDim2.new(0.5, -4, 0.5, -4)
reticle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
reticle.BorderSizePixel = 0
reticle.Visible = false
reticle.Parent = screenGui
Instance.new("UICorner", reticle).CornerRadius = UDim.new(1, 0)
local reticleOutline = Instance.new("UIStroke", reticle)
reticleOutline.Color = Color3.fromRGB(0, 0, 0)
reticleOutline.Thickness = 1.5

local settingsBtn = Instance.new("TextButton")
settingsBtn.Size = UDim2.new(0, 32, 0, 32)
settingsBtn.Position = UDim2.new(1, -50, 0, 10)
settingsBtn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
settingsBtn.BackgroundTransparency = 0.3
settingsBtn.Text = "?"
settingsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
settingsBtn.TextSize = 18
settingsBtn.Font = Enum.Font.GothamBold
settingsBtn.BorderSizePixel = 0
settingsBtn.Parent = screenGui
Instance.new("UICorner", settingsBtn).CornerRadius = UDim.new(0, 6)

local panel = Instance.new("Frame")
panel.Name = "SettingsPanel"
panel.Size = UDim2.new(0, 200, 0, 120)
panel.Position = UDim2.new(1, -260, 0, 48)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = screenGui
Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 8)
Instance.new("UIStroke", panel).Color = Color3.fromRGB(80, 80, 80)

local title = Instance.new("TextLabel", panel)
title.Size = UDim2.new(1, 0, 0, 30)
title.BackgroundTransparency = 1
title.Text = "Shift Lock Settings"
title.TextColor3 = Color3.fromRGB(220, 220, 220)
title.TextSize = 13
title.Font = Enum.Font.GothamBold

local sideLabel = Instance.new("TextLabel", panel)
sideLabel.Size = UDim2.new(1, -20, 0, 20)
sideLabel.Position = UDim2.new(0, 10, 0, 35)
sideLabel.BackgroundTransparency = 1
sideLabel.Text = "Camera Side"
sideLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
sideLabel.TextSize = 12
sideLabel.Font = Enum.Font.Gotham
sideLabel.TextXAlignment = Enum.TextXAlignment.Left

local leftBtn = Instance.new("TextButton", panel)
leftBtn.Size = UDim2.new(0, 80, 0, 30)
leftBtn.Position = UDim2.new(0, 10, 0, 62)
leftBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
leftBtn.Text = "Left"
leftBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
leftBtn.TextSize = 13
leftBtn.Font = Enum.Font.GothamBold
leftBtn.BorderSizePixel = 0
Instance.new("UICorner", leftBtn).CornerRadius = UDim.new(0, 6)

local rightBtn = Instance.new("TextButton", panel)
rightBtn.Size = UDim2.new(0, 80, 0, 30)
rightBtn.Position = UDim2.new(0, 110, 0, 62)
rightBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
rightBtn.Text = "Right"
rightBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rightBtn.TextSize = 13
rightBtn.Font = Enum.Font.GothamBold
rightBtn.BorderSizePixel = 0
Instance.new("UICorner", rightBtn).CornerRadius = UDim.new(0, 6)

local currentSideLabel = Instance.new("TextLabel", panel)
currentSideLabel.Size = UDim2.new(1, -20, 0, 20)
currentSideLabel.Position = UDim2.new(0, 10, 0, 96)
currentSideLabel.BackgroundTransparency = 1
currentSideLabel.Text = "Current: Right"
currentSideLabel.TextColor3 = Color3.fromRGB(140, 140, 140)
currentSideLabel.TextSize = 11
currentSideLabel.Font = Enum.Font.Gotham
currentSideLabel.TextXAlignment = Enum.TextXAlignment.Left

local function updateSideButtons()
	leftBtn.BackgroundColor3  = side == "Left"
		and Color3.fromRGB(80, 120, 200)
		or  Color3.fromRGB(60, 60, 60)
	rightBtn.BackgroundColor3 = side == "Right"
		and Color3.fromRGB(80, 120, 200)
		or  Color3.fromRGB(60, 60, 60)
	currentSideLabel.Text = "Current: " .. side
end

updateSideButtons()

-- -------------------------------
--         SHIFT LOCK LOGIC
-- -------------------------------
local function getOffset()
	local x = side == "Right" and CAMERA_OFFSET_X or -CAMERA_OFFSET_X
	return Vector3.new(x, CAMERA_OFFSET_Y, CAMERA_OFFSET_Z)
end

local function enableShiftLock()
	shiftLocked = true
	reticle.Visible = true
	UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
	UserInputService.MouseIconEnabled = false
	currentOffset = getOffset()
	humanoid.AutoRotate = false
end

local function disableShiftLock()
	shiftLocked = false
	reticle.Visible = false
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
	currentOffset = Vector3.new(0, 0, 0)
	humanoid.AutoRotate = true
end

-- -------------------------------
--         BINDABLE (for GunClient)
-- -------------------------------
local bindable = Instance.new("BindableFunction")
bindable.Name = "ShiftLockControl"
bindable.Parent = ReplicatedStorage
bindable.OnInvoke = function(action)
	if action == "enable" then
		enableShiftLock()
	elseif action == "disable" then
		disableShiftLock()
	end
end

-- -------------------------------
--         CAMERA UPDATE
-- -------------------------------
local targetOffset = Vector3.new(0, 0, 0)

RunService.RenderStepped:Connect(function()
	targetOffset = shiftLocked and getOffset() or Vector3.new(0, 0, 0)
	currentOffset = currentOffset:Lerp(targetOffset, 0.2)
	humanoid.CameraOffset = currentOffset
end)

RunService.Heartbeat:Connect(function()
	if not shiftLocked then return end
	local camCF    = camera.CFrame
	local flatLook = Vector3.new(camCF.LookVector.X, 0, camCF.LookVector.Z)
	if flatLook.Magnitude > 0.01 then
		rootPart.CFrame = CFrame.new(rootPart.Position, rootPart.Position + flatLook)
	end
end)

-- -------------------------------
--           INPUT
-- -------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.LeftControl
		or input.KeyCode == Enum.KeyCode.RightControl then
		if shiftLocked then
			disableShiftLock()
		else
			enableShiftLock()
		end
	end
end)

-- -------------------------------
--         SETTINGS BUTTONS
-- -------------------------------
settingsBtn.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
end)

leftBtn.MouseButton1Click:Connect(function()
	side = "Left"
	updateSideButtons()
	if shiftLocked then currentOffset = getOffset() end
end)

rightBtn.MouseButton1Click:Connect(function()
	side = "Right"
	updateSideButtons()
	if shiftLocked then currentOffset = getOffset() end
end)

UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		panel.Visible = false
	end
end)

player.CharacterAdded:Connect(function(newChar)
	character = newChar
	humanoid  = newChar:WaitForChild("Humanoid")
	rootPart  = newChar:WaitForChild("HumanoidRootPart")
	disableShiftLock()
end)

print("ShiftLockController loaded")