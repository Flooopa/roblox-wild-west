--[[
    GUN SERVER
    ServerScriptService
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Remotes    = ReplicatedStorage:WaitForChild("GunRemotes")
local GunFired   = Remotes:WaitForChild("GunFired")
local GunHit     = Remotes:WaitForChild("GunHit")
local GunReload  = Remotes:WaitForChild("GunReload")
local UpdateAmmo = Remotes:WaitForChild("UpdateAmmo")
local GunConfig  = require(ReplicatedStorage:WaitForChild("GunConfig"))

-- Created here so it exists before any client WaitForChild calls
local RequestAmmo = Remotes:FindFirstChild("RequestAmmo")
	or Instance.new("RemoteFunction", Remotes)
RequestAmmo.Name = "RequestAmmo"

print("GunServer loaded")

-- ── Ammo tracker ──────────────────────────────────────────
local ammoData = {}

local function getAmmo(player, gunName)
	if not ammoData[player] then ammoData[player] = {} end
	if not ammoData[player][gunName] then
		local cfg = GunConfig[gunName]
		ammoData[player][gunName] = {
			mag     = cfg.magazineSize,
			reserve = cfg.reserveAmmo,
		}
	end
	return ammoData[player][gunName]
end

-- ── Bullet simulation ─────────────────────────────────────
local function simulateBullet(origin, direction, speed, drop, size, color, shooter)
	local bullet = Instance.new("Part")
	bullet.Size = size
	bullet.Color = color
	bullet.Material = Enum.Material.Neon
	bullet.CastShadow = false
	bullet.CanCollide = false
	bullet.Anchored = false
	bullet.CFrame = CFrame.new(origin, origin + direction)
	bullet.AssemblyLinearVelocity = direction.Unit * speed
	bullet.Parent = workspace
	Debris:AddItem(bullet, 4)

	-- FIX: Tracers made longer and more visible.
	-- Changes from original:
	--   Lifetime: 0.08 → 0.25  (longer streak at all bullet speeds)
	--   WidthScale end: 0 → 0.4  (tail stays thick rather than tapering to nothing)
	--   LightEmission: 1 → 1 (kept max)
	--   Trail color start now uses the bullet's own color for consistency.
	local att0 = Instance.new("Attachment", bullet)
	att0.Position = Vector3.new(0, 0, size.Z / 2)
	local att1 = Instance.new("Attachment", bullet)
	att1.Position = Vector3.new(0, 0, -size.Z / 2)

	local trail = Instance.new("Trail", bullet)
	trail.Attachment0 = att0
	trail.Attachment1 = att1
	trail.Lifetime = 0.25
	trail.MinLength = 0
	trail.FaceCamera = true
	trail.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 200)),
	})
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.6),
	})
	trail.WidthScale = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(1, 0.4),
	})
	trail.LightEmission = 1

	local hitRegistered = false
	local startTime = tick()
	local initialVelocity = direction.Unit * speed

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not bullet or not bullet.Parent then
			conn:Disconnect()
			return
		end

		local elapsed = tick() - startTime

		if elapsed > 4 then
			conn:Disconnect()
			bullet:Destroy()
			return
		end

		local dropY = -drop * elapsed * elapsed * 0.01
		local newVelocity = Vector3.new(
			initialVelocity.X,
			initialVelocity.Y + dropY,
			initialVelocity.Z
		)
		bullet.AssemblyLinearVelocity = newVelocity

		local vel = bullet.AssemblyLinearVelocity
		if vel.Magnitude > 0 then
			bullet.CFrame = CFrame.new(bullet.Position, bullet.Position + vel)
		end
	end)

	-- impact detection
	bullet.Touched:Connect(function(hit)
		if hitRegistered then return end
		if not hit or not hit.Parent then return end

		local model = hit:FindFirstAncestorOfClass("Model")
		if model == shooter then return end

		hitRegistered = true
		conn:Disconnect()

		local impact = Instance.new("Part")
		impact.Size = Vector3.new(0.3, 0.3, 0.3)
		impact.Position = bullet.Position
		impact.Anchored = true
		impact.CanCollide = false
		impact.Material = Enum.Material.Neon
		impact.Color = Color3.fromRGB(255, 200, 80)
		impact.Parent = workspace
		Debris:AddItem(impact, 0.05)

		local isEnvironment = true
		local hum = model and model:FindFirstChildOfClass("Humanoid")
		if hum and hum.Health > 0 then
			isEnvironment = false
		end

		GunHit:FireAllClients(bullet.Position, isEnvironment)
		bullet:Destroy()
	end)

	return bullet
end

-- ── Fire handler ──────────────────────────────────────────
GunFired.OnServerEvent:Connect(function(player, gunName, origin, direction)
	if typeof(gunName) ~= "string" then return end
	if typeof(origin) ~= "Vector3" then return end
	if typeof(direction) ~= "Vector3" then return end

	local cfg = GunConfig[gunName]
	if not cfg then return end

	local character = player.Character
	if not character then return end

	local ammo = getAmmo(player, gunName)
	if ammo.mag <= 0 then
		UpdateAmmo:FireClient(player, gunName, ammo.mag, ammo.reserve)
		return
	end

	ammo.mag = ammo.mag - 1
	UpdateAmmo:FireClient(player, gunName, ammo.mag, ammo.reserve)

	local pellets = cfg.pellets or 1

	for i = 1, pellets do
		local spread   = math.rad(cfg.spread)
		local spreadX  = (math.random() - 0.5) * 2 * spread
		local spreadY  = (math.random() - 0.5) * 2 * spread
		local spreadDir = CFrame.Angles(spreadX, spreadY, 0) * direction.Unit
		spreadDir = Vector3.new(spreadDir.X, spreadDir.Y, spreadDir.Z)

		local bullet = simulateBullet(
			origin,
			spreadDir,
			cfg.bulletSpeed,
			cfg.bulletDrop,
			cfg.bulletSize,
			cfg.bulletColor,
			character
		)

		if bullet then
			local bulletHit = false
			bullet.Touched:Connect(function(hit)
				if bulletHit then return end
				local model = hit:FindFirstAncestorOfClass("Model")
				if model and model ~= character then
					local hum = model:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						bulletHit = true
						hum:TakeDamage(cfg.damage)
						bullet:Destroy()
					end
				end
			end)
		end
	end
end)

-- ── Reload handler ────────────────────────────────────────
GunReload.OnServerEvent:Connect(function(player, gunName)
	local cfg = GunConfig[gunName]
	if not cfg then return end

	local ammo = getAmmo(player, gunName)
	if ammo.reserve <= 0 then return end
	if ammo.mag == cfg.magazineSize then return end

	task.delay(cfg.reloadTime, function()
		local needed = cfg.magazineSize - ammo.mag
		local toAdd  = math.min(needed, ammo.reserve)
		ammo.mag     = ammo.mag + toAdd
		ammo.reserve = ammo.reserve - toAdd
		UpdateAmmo:FireClient(player, gunName, ammo.mag, ammo.reserve)
	end)
end)

-- ── Ammo sync on equip ───────────────────────────────────
RequestAmmo.OnServerInvoke = function(player, gunName)
	if typeof(gunName) ~= "string" then return 0, 0 end
	if not GunConfig[gunName] then return 0, 0 end
	local ammo = getAmmo(player, gunName)
	return ammo.mag, ammo.reserve
end

-- ── Cleanup ───────────────────────────────────────────────
Players.PlayerRemoving:Connect(function(player)
	ammoData[player] = nil
end)
