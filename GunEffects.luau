-- GunEffects (ModuleScript in ReplicatedStorage)
local Debris = game:GetService("Debris")

local GunEffects = {}

function GunEffects.playFireEffects(muzzle, rootPart, soundId)
	local smokeParent = muzzle or rootPart
	if not smokeParent then return end

	-- ── Fire sound ────────────────────────────────────────────
	if rootPart then
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
		local flashAttach = Instance.new("Attachment", muzzle)

		-- Point light flash
		local light = Instance.new("PointLight", muzzle)
		light.Color = Color3.fromRGB(255, 140, 40)
		light.Brightness = 10
		light.Range = 24
		light.Shadows = true
		Debris:AddItem(light, 0.05)

		-- Orange starburst layer
		local orange = Instance.new("ParticleEmitter", flashAttach)
		orange.Texture = "rbxassetid://437347603"
		orange.LightEmission = 1
		orange.LightInfluence = 0
		orange.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 3.2),
			NumberSequenceKeypoint.new(0.7, 3.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		orange.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		orange.Lifetime = NumberRange.new(0.07, 0.07)
		orange.Speed = NumberRange.new(0, 0)
		orange.SpreadAngle = Vector2.new(0, 0)
		orange.Rate = 0
		orange.Rotation = NumberRange.new(0, 360)
		orange.RotSpeed = NumberRange.new(0, 0)
		orange:Emit(1)

		-- White starburst layer (slightly larger, behind the orange)
		local white = Instance.new("ParticleEmitter", flashAttach)
		white.Texture = "rbxassetid://5671930987"
		white.LightEmission = 1
		white.LightInfluence = 0
		white.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 4.5),
			NumberSequenceKeypoint.new(0.7, 4.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		white.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.6, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		white.Lifetime = NumberRange.new(0.07, 0.07)
		white.Speed = NumberRange.new(0, 0)
		white.SpreadAngle = Vector2.new(0, 0)
		white.Rate = 0
		white.Rotation = NumberRange.new(0, 360)
		white.RotSpeed = NumberRange.new(0, 0)
		white:Emit(1)

		Debris:AddItem(flashAttach, 0.3)
	end
end

return GunEffects
