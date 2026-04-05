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

	-- ── Muzzle smoke (dense burst at muzzle) ─────────────────
	if muzzle then
		local muzzleAttach = Instance.new("Attachment", muzzle)
		local muzzlePuff = Instance.new("ParticleEmitter", muzzleAttach)
		muzzlePuff.Texture = "rbxassetid://1370319600"
		muzzlePuff.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 220, 220)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 60, 60)),
		})
		muzzlePuff.LightEmission = 0.05
		muzzlePuff.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(0.4, 1.0),
			NumberSequenceKeypoint.new(1, 0),
		})
		muzzlePuff.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		muzzlePuff.Lifetime = NumberRange.new(0.3, 0.6)
		muzzlePuff.Speed = NumberRange.new(4, 10)
		muzzlePuff.SpreadAngle = Vector2.new(20, 20)
		muzzlePuff.Rate = 0
		muzzlePuff.Rotation = NumberRange.new(0, 360)
		muzzlePuff.RotSpeed = NumberRange.new(-45, 45)
		muzzlePuff:Emit(6)
		Debris:AddItem(muzzleAttach, 1.5)
	end
end

return GunEffects
