-- GunEffects (ModuleScript in ReplicatedStorage)
local Debris = game:GetService("Debris")

local GunEffects = {}

-- Visual-only effects (smoke + flash, no sound).
-- Called by the local player's GunClient which handles sound separately.
function GunEffects.playVisualEffects(muzzle, rootPart)
	GunEffects.playFireEffects(muzzle, rootPart, nil)
end

function GunEffects.playFireEffects(muzzle, rootPart, soundId)
	local smokeParent = muzzle or rootPart
	if not smokeParent then return end

	-- ── Fire sound ────────────────────────────────────────────
	if soundId and rootPart then
		local fireSound = Instance.new("Sound")
		fireSound.SoundId = soundId
		fireSound.Volume = 0.8
		fireSound.RollOffMaxDistance = 120
		fireSound.RollOffMinDistance = 8
		fireSound.Parent = rootPart
		fireSound:Play()
		Debris:AddItem(fireSound, 3)
	end

	-- ── Muzzle smoke ──────────────────────────────────────────
	local smokeAttach = Instance.new("Attachment", smokeParent)
	local puff = Instance.new("ParticleEmitter", smokeAttach)
	puff.Texture = "rbxassetid://1370319600"
	puff.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 200, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 80, 80)),
	})
	puff.LightEmission = 0.1
	puff.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.5, 0.8),
		NumberSequenceKeypoint.new(1, 0),
	})
	puff.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	puff.Lifetime = NumberRange.new(0.4, 0.8)
	puff.Speed = NumberRange.new(3, 8)
	puff.SpreadAngle = Vector2.new(30, 30)
	puff.Rate = 0
	puff.Rotation = NumberRange.new(0, 360)
	puff.RotSpeed = NumberRange.new(-30, 30)
	puff:Emit(10)
	Debris:AddItem(smokeAttach, 2)

	-- ── Muzzle flash ──────────────────────────────────────────
	if muzzle then
		-- Point light flash
		local light = Instance.new("PointLight", muzzle)
		light.Color = Color3.fromRGB(255, 140, 40)
		light.Brightness = 10
		light.Range = 24
		light.Shadows = true
		Debris:AddItem(light, 0.06)

		-- Random rotation so each shot looks different
		local rotation = CFrame.Angles(0, 0, math.rad(math.random(0, 360)))

		-- Orange mesh layer
		local orangePart = Instance.new("Part")
		orangePart.Size = Vector3.new(1, 1, 1)
		orangePart.Anchored = true
		orangePart.CanCollide = false
		orangePart.CanQuery = false
		orangePart.CastShadow = false
		orangePart.Transparency = 1
		orangePart.CFrame = muzzle.CFrame * rotation
		orangePart.Parent = workspace

		local orangeMesh = Instance.new("SpecialMesh", orangePart)
		orangeMesh.MeshType = Enum.MeshType.FileMesh
		orangeMesh.MeshId = "rbxassetid://437347603"
		orangeMesh.Scale = Vector3.new(3.5, 3.5, 3.5)
		orangeMesh.TextureId = ""

		-- White mesh layer (slightly larger)
		local whitePart = Instance.new("Part")
		whitePart.Size = Vector3.new(1, 1, 1)
		whitePart.Anchored = true
		whitePart.CanCollide = false
		whitePart.CanQuery = false
		whitePart.CastShadow = false
		whitePart.Transparency = 1
		whitePart.CFrame = muzzle.CFrame * rotation
		whitePart.Parent = workspace

		local whiteMesh = Instance.new("SpecialMesh", whitePart)
		whiteMesh.MeshType = Enum.MeshType.FileMesh
		whiteMesh.MeshId = "rbxassetid://5671930987"
		whiteMesh.Scale = Vector3.new(4.5, 4.5, 4.5)
		whiteMesh.TextureId = ""

		Debris:AddItem(orangePart, 0.06)
		Debris:AddItem(whitePart, 0.06)
	end
end

return GunEffects
