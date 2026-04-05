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
		local light = Instance.new("PointLight", muzzle)
		light.Color = Color3.fromRGB(255, 140, 40)
		light.Brightness = 10
		light.Range = 24
		light.Shadows = true
		Debris:AddItem(light, 0.06)

		local flashAttach = Instance.new("Attachment", muzzle)

		local flash = Instance.new("ParticleEmitter", flashAttach)
		flash.Texture = "rbxassetid://13344777062"
		flash.LightEmission = 1
		flash.LightInfluence = 0
		flash.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 3.5),
			NumberSequenceKeypoint.new(1, 0),
		})
		flash.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		flash.Lifetime = NumberRange.new(0.06, 0.06)
		flash.Speed = NumberRange.new(0, 0)
		flash.SpreadAngle = Vector2.new(0, 0)
		flash.Rate = 0
		flash.Rotation = NumberRange.new(0, 360)
		flash.RotSpeed = NumberRange.new(0, 0)
		flash:Emit(1)

		Debris:AddItem(flashAttach, 0.3)
	end
end

return GunEffects
