--[[
    GUN CLIENT
    StarterCharacterScripts
]]

local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local TweenService      = game:GetService("TweenService")
local Debris            = game:GetService("Debris")
local SoundService      = game:GetService("SoundService")

local player    = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()
local humanoid  = character:WaitForChild("Humanoid")
local animator  = humanoid:WaitForChild("Animator")
local camera    = workspace.CurrentCamera

local Remotes     = ReplicatedStorage:WaitForChild("GunRemotes")
local GunFired    = Remotes:WaitForChild("GunFired")
local GunReload   = Remotes:WaitForChild("GunReload")
local GunHit      = Remotes:WaitForChild("GunHit")
local UpdateAmmo  = Remotes:WaitForChild("UpdateAmmo")
local RequestAmmo = Remotes:WaitForChild("RequestAmmo")
local GunConfig  = require(ReplicatedStorage:WaitForChild("GunConfig"))

-- ═══════════════════════════════
--           STATE
-- ═══════════════════════════════
local equippedGun   = nil
local currentAmmo   = 0
local reserveAmmo   = 0
local isADS         = false
local isReloading   = false
local canFire       = true
local mouseDown     = false
local normalFOV     = 70
local currentTracks = {}
local idleActive    = false

-- ═══════════════════════════════
--           GUI
-- ═══════════════════════════════
local playerGui = player:WaitForChild("PlayerGui")
if playerGui:FindFirstChild("GunHUD") then
	playerGui.GunHUD:Destroy()
end

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "GunHUD"
screenGui.ResetOnSpawn = false
screenGui.IgnoreGuiInset = true
screenGui.Enabled = false
screenGui.Parent = playerGui

-- FIX: Hit sound parented to SoundService so only the local player hears it.
-- Previously it was parented to playerGui but still played for all clients
-- because Sound objects in workspace/character broadcast spatially; keeping it
-- in SoundService (non-spatial) ensures it is strictly local.
local hitSound = Instance.new("Sound")
hitSound.SoundId = "rbxassetid://125235091454234"
hitSound.Volume = 0.5
hitSound.Parent = SoundService

-- ── Bottom right ammo counter ─────────────────────────────
local ammoFrame = Instance.new("Frame", screenGui)
ammoFrame.Size = UDim2.new(0, 120, 0, 50)
ammoFrame.Position = UDim2.new(1, -140, 1, -70)
ammoFrame.BackgroundTransparency = 1

local magLabel = Instance.new("TextLabel", ammoFrame)
magLabel.Size = UDim2.new(0, 60, 1, 0)
magLabel.Position = UDim2.new(0, 0, 0, 0)
magLabel.BackgroundTransparency = 1
magLabel.Text = "6"
magLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
magLabel.TextSize = 32
magLabel.Font = Enum.Font.GothamBold
magLabel.TextXAlignment = Enum.TextXAlignment.Right

local divider = Instance.new("TextLabel", ammoFrame)
divider.Size = UDim2.new(0, 10, 1, 0)
divider.Position = UDim2.new(0, 62, 0, 0)
divider.BackgroundTransparency = 1
divider.Text = "/"
divider.TextColor3 = Color3.fromRGB(160, 160, 160)
divider.TextSize = 22
divider.Font = Enum.Font.Gotham

local reserveLabel = Instance.new("TextLabel", ammoFrame)
reserveLabel.Size = UDim2.new(0, 45, 1, 0)
reserveLabel.Position = UDim2.new(0, 74, 0, 10)
reserveLabel.BackgroundTransparency = 1
reserveLabel.Text = "36"
reserveLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
reserveLabel.TextSize = 18
reserveLabel.Font = Enum.Font.Gotham

-- ── Crosshair ─────────────────────────────────────────────
local crosshair = Instance.new("Frame", screenGui)
crosshair.Size = UDim2.new(0, 4, 0, 4)
crosshair.Position = UDim2.new(0.5, -2, 0.5, -2)
crosshair.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
crosshair.BorderSizePixel = 0
crosshair.Visible = false
Instance.new("UICorner", crosshair).CornerRadius = UDim.new(1, 0)
Instance.new("UIStroke", crosshair).Color = Color3.fromRGB(0, 0, 0)

-- ── Hitmarker ─────────────────────────────────────────────
local hitmarker = Instance.new("Frame", screenGui)
hitmarker.Size = UDim2.new(0, 16, 0, 16)
hitmarker.Position = UDim2.new(0.5, -8, 0.5, -8)
hitmarker.BackgroundTransparency = 1
hitmarker.Visible = false

local function makeLine(rotation)
	local line = Instance.new("Frame", hitmarker)
	line.Size = UDim2.new(0, 14, 0, 2)
	line.Position = UDim2.new(0.5, -7, 0.5, -1)
	line.BackgroundColor3 = Color3.fromRGB(255, 80, 80)
	line.BorderSizePixel = 0
	line.Rotation = rotation
	return line
end

makeLine(45)
makeLine(-45)

local function showHitmarker()
	hitmarker.Visible = true
	hitSound:Play()
	task.delay(0.1, function()
		hitmarker.Visible = false
	end)
end

-- ── Semi circle ammo arc ──────────────────────────────────
local rootPart = character:WaitForChild("HumanoidRootPart")

local arcGui = Instance.new("BillboardGui")
arcGui.Parent = rootPart
arcGui.Name = "AmmoArc"
arcGui.Size = UDim2.new(0, 80, 0, 80)
arcGui.StudsOffset = Vector3.new(0, 3, 0)
arcGui.AlwaysOnTop = true
arcGui.Enabled = false

local arcFrame = Instance.new("Frame", arcGui)
arcFrame.Size = UDim2.new(1, 0, 1, 0)
arcFrame.BackgroundTransparency = 1

local arcSegments = {}

local function buildArc(maxAmmo)
	for _, s in ipairs(arcSegments) do s:Destroy() end
	arcSegments = {}

	local totalAngle = 160
	local startAngle = -80
	local radius     = 36

	for i = 1, maxAmmo do
		local angle = math.rad(startAngle + (totalAngle / math.max(maxAmmo - 1, 1)) * (i - 1))
		local x = 40 + radius * math.sin(angle)
		local y = 40 - radius * math.cos(angle)

		local dot = Instance.new("Frame", arcFrame)
		dot.Size = UDim2.new(0, 5, 0, 5)
		dot.Position = UDim2.new(0, x - 2.5, 0, y - 2.5)
		dot.BackgroundColor3 = Color3.fromRGB(255, 220, 80)
		dot.BorderSizePixel = 0
		Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
		table.insert(arcSegments, dot)
	end
end

local function updateArc(mag, maxMag)
	for i, seg in ipairs(arcSegments) do
		seg.BackgroundColor3 = i <= mag
			and Color3.fromRGB(255, 220, 80)
			or  Color3.fromRGB(60, 60, 60)
		seg.BackgroundTransparency = i <= mag and 0 or 0.4
	end
end

-- ═══════════════════════════════
--        ANIMATION HELPER
-- ═══════════════════════════════
local function loadGunAnims(cfg)
	local function load(id)
		if not id or id:find("YOUR_") then return nil end
		local anim = Instance.new("Animation")
		anim.AnimationId = id
		local track = animator:LoadAnimation(anim)
		track.Priority = Enum.AnimationPriority.Action3
		track.Looped = false
		return track
	end

	local idleTrack = nil
	if cfg.idleAnim and not cfg.idleAnim:find("YOUR_") then
		local anim = Instance.new("Animation")
		anim.AnimationId = cfg.idleAnim
		idleTrack = animator:LoadAnimation(anim)
		idleTrack.Priority = Enum.AnimationPriority.Action2
		idleTrack.Looped = true
	end

	return {
		fire   = load(cfg.fireAnim),
		reload = load(cfg.reloadAnim),
		ads    = load(cfg.adsAnim),
		idle   = idleTrack,
	}
end

-- ═══════════════════════════════
--           ADS
-- ═══════════════════════════════
local function enterADS()
	if not equippedGun then return end
	local cfg = GunConfig[equippedGun]
	isADS = true
	TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = cfg.adsFOV }):Play()
	if currentTracks.ads then currentTracks.ads:Play() end
end

local function exitADS()
	isADS = false
	TweenService:Create(camera, TweenInfo.new(0.15), { FieldOfView = normalFOV }):Play()
	if currentTracks.ads then currentTracks.ads:Stop() end
end

-- ═══════════════════════════════
--           BARREL ORIGIN
-- ═══════════════════════════════
local function getBarrelOrigin()
	local tool = character:FindFirstChildOfClass("Tool")
	if tool then
		local muzzle = tool:FindFirstChild("Muzzle")
		if muzzle then
			return muzzle.Position
		end
	end
	return camera.CFrame.Position
end

-- ═══════════════════════════════
--           RELOAD
-- ═══════════════════════════════
local function reload()
	if not equippedGun then return end
	if isReloading then return end
	local cfg = GunConfig[equippedGun]
	if currentAmmo == cfg.magazineSize then return end
	if reserveAmmo <= 0 then return end

	isReloading = true
	canFire = false

	if currentTracks.reload then currentTracks.reload:Play() end

	local reloadSound = Instance.new("Sound")
	reloadSound.SoundId = cfg.reloadSound
	reloadSound.Parent = rootPart
	reloadSound:Play()
	Debris:AddItem(reloadSound, cfg.reloadTime + 1)

	GunReload:FireServer(equippedGun)

	task.delay(cfg.reloadTime, function()
		isReloading = false
		canFire = true
	end)
end

-- ═══════════════════════════════
--           FIRE
-- ═══════════════════════════════
local function fire()
	if not equippedGun then return end
	if not canFire then return end
	if isReloading then return end

	local cfg = GunConfig[equippedGun]

	if currentAmmo <= 0 then
		local s = Instance.new("Sound")
		s.SoundId = cfg.emptySound
		s.Parent = rootPart
		s:Play()
		Debris:AddItem(s, 2)
		return
	end

	canFire = false

	if currentTracks.fire and humanoid.MoveDirection.Magnitude < 0.1 then
		currentTracks.fire:Play()
	end

	local fireSound = Instance.new("Sound")
	fireSound.SoundId = cfg.fireSound
	fireSound.Parent = rootPart
	fireSound:Play()
	Debris:AddItem(fireSound, 3)

	local spread    = isADS and cfg.adsSpread or cfg.spread
	local spreadRad = math.rad(spread)
	local direction = camera.CFrame.LookVector

	local sx = (math.random() - 0.5) * 2 * spreadRad
	local sy = (math.random() - 0.5) * 2 * spreadRad
	direction = (CFrame.Angles(sx, sy, 0) * direction).Unit

	GunFired:FireServer(equippedGun, getBarrelOrigin(), direction)

	-- FIX: Muzzle smoke now parented to the muzzle Part directly.
	-- The original code created an Attachment at muzzle.Position (a world-space
	-- coordinate) and parented it to workspace.Terrain, which placed the smoke
	-- at that fixed world point but with no local-space offset — so it never
	-- visually appeared at the gun barrel. Attaching directly to the muzzle Part
	-- ensures the emitter moves with the gun and fires from the correct position.
	local tool = character:FindFirstChildOfClass("Tool")
	local muzzle = tool and tool:FindFirstChild("Muzzle")
	if muzzle then
		local puff = Instance.new("ParticleEmitter", muzzle)
		puff.Texture = "rbxassetid://1370319600"
		puff.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(180, 180, 180)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 80)),
		})
		puff.LightEmission = 0.2
		puff.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.3),
			NumberSequenceKeypoint.new(0.5, 0.8),
			NumberSequenceKeypoint.new(1, 0),
		})
		puff.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		puff.Lifetime = NumberRange.new(0.4, 0.8)
		puff.Speed = NumberRange.new(3, 8)
		puff.SpreadAngle = Vector2.new(30, 30)
		puff.Rate = 0
		puff.Rotation = NumberRange.new(0, 360)
		puff.RotSpeed = NumberRange.new(-60, 60)
		puff:Emit(12)
		Debris:AddItem(puff, 1)
	end

	currentAmmo = math.max(0, currentAmmo - 1)
	magLabel.Text = tostring(currentAmmo)
	updateArc(currentAmmo, cfg.magazineSize)

	task.delay(cfg.fireRate, function()
		canFire = true
		if currentAmmo <= 0 and reserveAmmo > 0 then
			reload()
		end
	end)
end

-- ═══════════════════════════════
--        EQUIP / UNEQUIP
-- ═══════════════════════════════
local function equipGun(gunName)
	local cfg = GunConfig[gunName]
	if not cfg then return end

	equippedGun   = gunName
	isReloading   = false
	canFire       = true
	currentTracks = loadGunAnims(cfg)

	screenGui.Enabled = true
	arcGui.Enabled    = true
	crosshair.Visible = true
	UserInputService.MouseIconEnabled = false

	if cfg.pulloutSound and not cfg.pulloutSound:find("YOUR_") then
		local s = Instance.new("Sound")
		s.SoundId = cfg.pulloutSound
		s.Parent = rootPart
		s:Play()
		Debris:AddItem(s, 3)
	end

	buildArc(cfg.magazineSize)

	-- Fetch real ammo from the server so re-equipping after spending
	-- ammo or draining reserves shows the correct counts immediately.
	local mag, reserve = RequestAmmo:InvokeServer(gunName)
	currentAmmo   = mag
	reserveAmmo   = reserve
	magLabel.Text     = tostring(currentAmmo)
	reserveLabel.Text = tostring(reserveAmmo)
	updateArc(currentAmmo, cfg.magazineSize)
end

local function unequipGun()
	if currentTracks.idle then
		currentTracks.idle:Stop()
	end
	idleActive  = false
	equippedGun = nil
	exitADS()
	screenGui.Enabled = false
	arcGui.Enabled    = false
	crosshair.Visible = false
	isReloading = false
	canFire = true
	UserInputService.MouseIconEnabled = true
end

-- ═══════════════════════════════
--      TOOL EQUIP DETECTION
-- ═══════════════════════════════
character.ChildAdded:Connect(function(child)
	if child:IsA("Tool") then
		if GunConfig[child.Name] then
			equipGun(child.Name)
		end
	end
end)

character.ChildRemoved:Connect(function(child)
	if child:IsA("Tool") and child.Name == equippedGun then
		unequipGun()
	end
end)

-- ═══════════════════════════════
--     AMMO UPDATE FROM SERVER
-- ═══════════════════════════════
UpdateAmmo.OnClientEvent:Connect(function(gunName, mag, reserve)
	if gunName ~= equippedGun then return end
	currentAmmo       = mag
	reserveAmmo       = reserve
	magLabel.Text     = tostring(currentAmmo)
	reserveLabel.Text = tostring(reserve)
	local cfg = GunConfig[gunName]
	updateArc(currentAmmo, cfg.magazineSize)
end)

-- ═══════════════════════════════
--         HIT DETECTION
-- ═══════════════════════════════
local function spawnWindTracer(origin, hitPos)
	local att0 = Instance.new("Attachment")
	att0.Position = origin
	att0.Parent = workspace.Terrain

	local att1 = Instance.new("Attachment")
	att1.Position = hitPos
	att1.Parent = workspace.Terrain

	local beam = Instance.new("Beam")
	beam.Attachment0 = att0
	beam.Attachment1 = att1
	beam.Texture = "rbxassetid://12402893521"
	beam.TextureSpeed = 0.5
	beam.TextureLength = 8
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.Width0 = 0.8
	beam.Width1 = 0.3
	beam.FaceCamera = true
	beam.LightEmission = 0
	beam.LightInfluence = 1
	beam.Segments = 10
	beam.CurveSize0 = 0
	beam.CurveSize1 = 0
	beam.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	beam.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0.2),
	})
	beam.Parent = workspace.Terrain

	local LINGER    = 0.3
	local FADE_TIME = 0.6

	task.delay(LINGER, function()
		local start = tick()
		local conn
		conn = RunService.Heartbeat:Connect(function()
			local alpha = (tick() - start) / FADE_TIME
			if alpha >= 1 then
				conn:Disconnect()
				beam:Destroy()
				att0:Destroy()
				att1:Destroy()
				return
			end
			local t = 0.2 + alpha * 0.8
			beam.Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, t),
				NumberSequenceKeypoint.new(1, t),
			})
			beam.Width0 = 0.8 * (1 - alpha)
			beam.Width1 = 0.3 * (1 - alpha)
		end)
	end)
end

GunHit.OnClientEvent:Connect(function(position, isEnvironment)
	if not isEnvironment then
		showHitmarker()
	end
	local tool   = character:FindFirstChildOfClass("Tool")
	local muzzle = tool and tool:FindFirstChild("Muzzle")
	local origin = muzzle and muzzle.Position or camera.CFrame.Position
	spawnWindTracer(origin, position)
end)

-- ═══════════════════════════════
--           INPUT
-- ═══════════════════════════════
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not equippedGun then return end

	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseDown = true
		fire()
	end

	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		enterADS()
	end

	if input.KeyCode == Enum.KeyCode.R then
		reload()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseDown = false
	end
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		exitADS()
	end
end)

RunService.Heartbeat:Connect(function()
	if not equippedGun then return end
	local cfg = GunConfig[equippedGun]
	if cfg.fireMode == "auto" and mouseDown then
		fire()
	end

	-- Revolver idle: play when standing still, stop when moving or airborne
	if currentTracks.idle then
		local state    = humanoid:GetState()
		local airborne = state == Enum.HumanoidStateType.Jumping
			or state == Enum.HumanoidStateType.Freefall
		local moving   = humanoid.MoveDirection.Magnitude > 0.1
		local shouldIdle = not moving and not airborne

		if shouldIdle and not idleActive then
			currentTracks.idle:Play()
			idleActive = true
		elseif not shouldIdle and idleActive then
			currentTracks.idle:Stop()
			idleActive = false
		end
	end
end)

print("GunClient loaded")
