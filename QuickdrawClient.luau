--[[
    QUICKDRAW CLIENT
    StarterCharacterScripts
]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local animator  = humanoid:WaitForChild("Animator")
local camera    = workspace.CurrentCamera
local rootPart  = character:WaitForChild("HumanoidRootPart")

local GunConfig  = require(ReplicatedStorage:WaitForChild("GunConfig"))
local Remotes    = ReplicatedStorage:WaitForChild("GunRemotes")
local QuickdrawFired = Remotes:WaitForChild("QuickdrawFired")
local GunHit     = Remotes:WaitForChild("GunHit")
local ShiftLockControl = ReplicatedStorage:WaitForChild("ShiftLockControl")
local UpdateAmmo = Remotes:WaitForChild("UpdateAmmo")
local GunEffectsModule = require(ReplicatedStorage:WaitForChild("GunEffects"))

-- signal to GunClient to ignore tool events during quickdraw
local qdActive = Instance.new("BoolValue")
qdActive.Name = "QuickdrawActive"
qdActive.Value = false
qdActive.Parent = ReplicatedStorage

-- -------------------------------
--           CONFIG
-- -------------------------------
local QUICKDRAW_GUN  = "Revolver"
local MAX_SHOTS      = 3
local DRAW_TIME      = 0.3
local BETWEEN_SHOTS  = 0.165
local DRAW_ANIM_ID   = "rbxassetid://116444252199649"

-- -------------------------------
--           STATE
-- -------------------------------
local inQuickdraw    = false
local canShoot       = false
local shotsLeft      = 0
local lastShotTime   = 0
local rightHeld      = false
local drawTrack      = nil
local outOfAmmo      = false
local quickdrawClone = nil

-- Track actual revolver ammo so quickdraw respects real bullet count
local revolverMag     = 0
local revolverReserve = 0

-- Initialise from config (will be overwritten by first UpdateAmmo from server)
local revolverCfg = GunConfig[QUICKDRAW_GUN]
if revolverCfg then
	revolverMag     = revolverCfg.magazineSize or 0
	revolverReserve = revolverCfg.reserveAmmo  or 0
end

-- -------------------------------
--           GUI
-- -------------------------------
local playerGui = player:WaitForChild("PlayerGui")

local qdGui = Instance.new("ScreenGui")
qdGui.Name = "QuickdrawHUD"
qdGui.ResetOnSpawn = false
qdGui.IgnoreGuiInset = true
qdGui.Enabled = false
qdGui.Parent = playerGui

local pipFrame = Instance.new("Frame", qdGui)
pipFrame.Size = UDim2.new(0, 80, 0, 20)
pipFrame.Position = UDim2.new(0.5, -40, 0.5, 30)
pipFrame.BackgroundTransparency = 1

local pips = {}
for i = 1, MAX_SHOTS do
	local pip = Instance.new("Frame", pipFrame)
	pip.Size = UDim2.new(0, 14, 0, 14)
	pip.Position = UDim2.new(0, (i - 1) * 26, 0, 3)
	pip.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
	pip.BorderSizePixel = 0
	Instance.new("UICorner", pip).CornerRadius = UDim.new(1, 0)
	table.insert(pips, pip)
end

local qdLabel = Instance.new("TextLabel", qdGui)
qdLabel.Size = UDim2.new(0, 200, 0, 30)
qdLabel.Position = UDim2.new(0.5, -100, 0.5, 55)
qdLabel.BackgroundTransparency = 1
qdLabel.Text = "QUICKDRAW"
qdLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
qdLabel.TextSize = 16
qdLabel.Font = Enum.Font.GothamBold
qdLabel.TextXAlignment = Enum.TextXAlignment.Center

local function updatePips()
	for i, pip in ipairs(pips) do
		pip.BackgroundColor3 = i <= shotsLeft
			and Color3.fromRGB(255, 220, 80)
			or Color3.fromRGB(60, 60, 60)
		pip.BackgroundTransparency = i <= shotsLeft and 0 or 0.5
	end
end

-- -------------------------------
--        ENTER / EXIT
-- -------------------------------

local function exitQuickdraw()
	if not inQuickdraw then return end
	inQuickdraw = false
	canShoot    = false
	rightHeld   = false
	outOfAmmo   = false

	if drawTrack then
		drawTrack:Stop()
		drawTrack = nil
	end

	qdGui.Enabled = false

	humanoid.WalkSpeed  = 16
	humanoid.JumpPower  = 50
	humanoid.JumpHeight = 7.2

	humanoid:UnequipTools()
	task.delay(0.15, function()
		quickdrawClone = nil
		qdActive.Value = false
	end)

	ShiftLockControl:Invoke("disable")
	UserInputService.MouseBehavior    = Enum.MouseBehavior.Default
	UserInputService.MouseIconEnabled = true
end

local function enterQuickdraw()
	if inQuickdraw then return end

	local tool = character:FindFirstChildOfClass("Tool")
	if tool and GunConfig[tool.Name] then return end

	-- Check magazine ammo only — quickdraw uses what's loaded in the cylinder
	if revolverMag <= 0 then
		-- play empty click and bail
		local cfg = GunConfig[QUICKDRAW_GUN]
		if cfg then
			local emptySound = Instance.new("Sound")
			emptySound.SoundId = cfg.emptySound
			emptySound.Parent = rootPart
			emptySound:Play()
			Debris:AddItem(emptySound, 2)
		end
		return
	end

	inQuickdraw    = true
	canShoot       = false
	qdActive.Value = true

	-- Cap shots to the lesser of MAX_SHOTS and loaded magazine rounds
	shotsLeft = math.min(MAX_SHOTS, revolverMag)
	outOfAmmo = false

	humanoid.WalkSpeed  = 0
	humanoid.JumpPower  = 0
	humanoid.JumpHeight = 0

	ShiftLockControl:Invoke("enable")
	qdGui.Enabled = true
	updatePips()

	-- equip the revolver from backpack
	local revolverInBackpack = player.Backpack:FindFirstChild(QUICKDRAW_GUN)
	if revolverInBackpack then
		quickdrawClone = revolverInBackpack
		humanoid:EquipTool(revolverInBackpack)
	else
		warn("QuickdrawClient: Revolver not in backpack")
		exitQuickdraw()
		return
	end

	-- play draw animation after tool equips
	task.delay(0.05, function()
		if not inQuickdraw then return end
		local anim = Instance.new("Animation")
		anim.AnimationId = DRAW_ANIM_ID
		drawTrack = animator:LoadAnimation(anim)
		drawTrack.Priority = Enum.AnimationPriority.Action3
		drawTrack.Looped = false
		drawTrack:Play()

		drawTrack.Stopped:Connect(function()
			if inQuickdraw and drawTrack then
				drawTrack:AdjustSpeed(0)
				drawTrack:Play()
				drawTrack.TimePosition = drawTrack.Length
			end
		end)
	end)

	task.delay(DRAW_TIME, function()
		if inQuickdraw then
			canShoot = true
		end
	end)
end

-- -------------------------------
--        QUICKDRAW FIRE
-- -------------------------------

local function quickdrawFire()
	if not inQuickdraw then return end
	if not rightHeld then return end

	if outOfAmmo or not canShoot then
		if outOfAmmo then
			local cfg = GunConfig[QUICKDRAW_GUN]
			local emptySound = Instance.new("Sound")
			emptySound.SoundId = cfg.emptySound
			emptySound.Parent = rootPart
			emptySound:Play()
			Debris:AddItem(emptySound, 2)
		end
		return
	end

	if shotsLeft <= 0 then return end
	if tick() - lastShotTime < BETWEEN_SHOTS then return end

	lastShotTime = tick()
	shotsLeft = shotsLeft - 1
	updatePips()

	local cfg = GunConfig[QUICKDRAW_GUN]

	local fireSound = Instance.new("Sound")
	fireSound.SoundId = cfg.fireSound
	fireSound.Parent = rootPart
	fireSound:Play()
	Debris:AddItem(fireSound, 3)

	local direction = camera.CFrame.LookVector
	local spread    = math.rad(cfg.spread)
	local sx = (math.random() - 0.5) * 2 * spread
	local sy = (math.random() - 0.5) * 2 * spread
	direction = (CFrame.Angles(sx, sy, 0) * direction).Unit

	-- FIX: Always use camera origin for the server raycast so bullets
	-- land where the crosshair points, not offset by the gun model.
	local rayOrigin = camera.CFrame.Position

	QuickdrawFired:FireServer(rayOrigin, direction)

	-- muzzle smoke (visual only)
	GunEffectsModule.playFireEffects(muzzle, rootPart, cfg.fireSound)

	if shotsLeft <= 0 then
		outOfAmmo = true
	end
end

-- -------------------------------
--           INPUT
-- -------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightHeld = true
		local tool = character:FindFirstChildOfClass("Tool")
		if not (tool and GunConfig[tool.Name]) then
			enterQuickdraw()
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		if inQuickdraw then
			quickdrawFire()
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightHeld = false
		if inQuickdraw then
			exitQuickdraw()
		end
	end
end)

player.CharacterAdded:Connect(function(newChar)
	character   = newChar
	humanoid    = newChar:WaitForChild("Humanoid")
	animator    = humanoid:WaitForChild("Animator")
	rootPart    = newChar:WaitForChild("HumanoidRootPart")
	inQuickdraw = false
	canShoot    = false
	qdGui.Enabled  = false
	qdActive.Value = false

	-- Reset tracked ammo from config on respawn
	local cfg = GunConfig[QUICKDRAW_GUN]
	if cfg then
		revolverMag     = cfg.magazineSize or 0
		revolverReserve = cfg.reserveAmmo  or 0
	end
end)

-- Keep revolver ammo in sync with server at all times
UpdateAmmo.OnClientEvent:Connect(function(gunName, mag, reserve)
	if gunName ~= QUICKDRAW_GUN then return end
	revolverMag     = mag
	revolverReserve = reserve

	-- If mid-quickdraw and magazine is empty, force out-of-ammo
	-- (quickdraw only uses loaded cylinder rounds, not reserves)
	if inQuickdraw and mag <= 0 then
		outOfAmmo = true
		shotsLeft = 0
		updatePips()
	end
end)