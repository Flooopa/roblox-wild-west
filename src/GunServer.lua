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

-- Ensure RequestAmmo is a RemoteFunction (not a RemoteEvent).
local _existing = Remotes:FindFirstChild("RequestAmmo")
if _existing and not _existing:IsA("RemoteFunction") then
	_existing:Destroy()
	_existing = nil
end
local RequestAmmo = _existing or Instance.new("RemoteFunction", Remotes)
RequestAmmo.Name = "RequestAmmo"

local TracerFired = Remotes:FindFirstChild("TracerFired") or Instance.new("RemoteEvent", Remotes)
TracerFired.Name = "TracerFired"

local GunEffectsFired = Remotes:FindFirstChild("GunEffectsFired") or Instance.new("RemoteEvent", Remotes)
GunEffectsFired.Name = "GunEffectsFired"

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
-- Hit detection uses per-frame raycasting (prevPos → currentPos) instead
-- of Touched events. This eliminates tunneling at high bullet speeds and
-- provides exact surface positions/normals for bullet holes.
local function simulateBullet(origin, direction, speed, drop, size, color, shooter, damage, shooterPlayer, tracerOffset)
	local bullet = Instance.new("Part")
	bullet.Size = size
	bullet.Color = color
	bullet.Material = Enum.Material.Neon
	bullet.CastShadow = false
	bullet.CanCollide = false
	bullet.CanQuery = false
	bullet.Anchored = false
	bullet.CFrame = CFrame.new(origin, origin + direction)
	bullet.AssemblyLinearVelocity = direction.Unit * speed
	bullet.Parent = workspace
	Debris:AddItem(bullet, 5)

	-- Trail
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

	-- Raycast params: exclude shooter character and bullet itself
	local rayParams = RaycastParams.new()
	rayParams.FilterDescendantsInstances = { shooter, bullet }
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	local hitRegistered  = false
	local startTime      = tick()
	local initialVelocity = direction.Unit * speed
	local prevPos        = origin

	local conn
	conn = RunService.Heartbeat:Connect(function(dt)
		if not bullet.Parent then
			conn:Disconnect()
			return
		end

		local elapsed = tick() - startTime

		if elapsed > 5 then
			conn:Disconnect()
			bullet:Destroy()
			return
		end

		-- Update bullet velocity with gravity drop
		local dropY = -drop * elapsed * elapsed * 0.01
		local currentVel = Vector3.new(
			initialVelocity.X,
			initialVelocity.Y + dropY,
			initialVelocity.Z
		)
		bullet.AssemblyLinearVelocity = currentVel

		local currentPos = bullet.Position

		if currentVel.Magnitude > 0 then
			bullet.CFrame = CFrame.new(currentPos, currentPos + currentVel)
		end

		-- Sweep raycast from previous frame position to current
		-- This catches hits even when the bullet moves faster than one
		-- physics frame, eliminating tunneling entirely.
		if not hitRegistered then
			local sweepDir = currentPos - prevPos
			if sweepDir.Magnitude > 0.001 then
				local result = workspace:Raycast(prevPos, sweepDir, rayParams)
				if result then
					hitRegistered = true
					conn:Disconnect()

					-- Impact flash
					local impact = Instance.new("Part")
					impact.Size = Vector3.new(0.25, 0.25, 0.25)
					impact.Position = result.Position
					impact.Anchored = true
					impact.CanCollide = false
					impact.Material = Enum.Material.Neon
					impact.Color = Color3.fromRGB(255, 200, 80)
					impact.Parent = workspace
					Debris:AddItem(impact, 0.05)

					-- Damage check
					local isEnvironment = true
					local hitModel = result.Instance:FindFirstAncestorOfClass("Model")
					local hum = hitModel and hitModel:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						isEnvironment = false
						hum:TakeDamage(damage)
					end

					-- Bullet hole — result.Position and result.Normal are exact
					-- surface data from the raycast, no approximation needed
					if isEnvironment then
						local surfaceNormal = result.Normal
						local holePos = result.Position + surfaceNormal * 0.02

						local hole = Instance.new("Part")
						hole.Size = Vector3.new(0.5, 0.5, 0.01)
						hole.CFrame = CFrame.new(holePos, holePos + surfaceNormal)
						hole.Anchored = true
						hole.CanCollide = false
						hole.CanQuery = false
						hole.CastShadow = false
						hole.Material = Enum.Material.SmoothPlastic
						hole.Color = Color3.fromRGB(15, 10, 8)
						hole.Transparency = 0
						hole.Parent = workspace

						local decal = Instance.new("Decal", hole)
						decal.Texture = "rbxassetid://3696145217"
						decal.Face = Enum.NormalId.Front

						Debris:AddItem(hole, 60)
					end

					-- Tracer and hit events
					local tool = shooter:FindFirstChildOfClass("Tool")
					local muzzle = tool and tool:FindFirstChild("Muzzle")
					local tracerStart = (muzzle and muzzle.Position or origin)
						+ Vector3.new(0, tracerOffset or 0, 0)
					TracerFired:FireAllClients(tracerStart, result.Position)
					GunHit:FireClient(shooterPlayer, result.Position, isEnvironment)

					bullet:Destroy()
				end
			end
		end

		prevPos = currentPos
	end)
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
		local spread    = math.rad(cfg.spread)
		local spreadX   = (math.random() - 0.5) * 2 * spread
		local spreadY   = (math.random() - 0.5) * 2 * spread
		local spreadDir = CFrame.Angles(spreadX, spreadY, 0) * direction.Unit
		spreadDir = Vector3.new(spreadDir.X, spreadDir.Y, spreadDir.Z)

		simulateBullet(
			origin,
			spreadDir,
			cfg.bulletSpeed,
			cfg.bulletDrop,
			cfg.bulletSize,
			cfg.bulletColor,
			character,
			cfg.damage,
			player,
			cfg.tracerOriginOffset or 0
		)
	end

	-- Notify all clients so GunEffectsClient plays sound/effects for other players
	GunEffectsFired:FireAllClients(player, cfg.fireSound)
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
