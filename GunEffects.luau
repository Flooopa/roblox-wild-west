-- GunEffects (ModuleScript in ReplicatedStorage)
local Debris = game:GetService("Debris")

local GunEffects = {}

-- Visual-only effects (smoke + flash, no sound).
-- Called by the local player's GunClient which handles sound separately.
function GunEffects.playVisualEffects(muzzle, rootPart)
	GunEffects.playFireEffects(muzzle, rootPart, nil)
end

function GunEffects.playFireEffects(muzzle, rootPart, soundId)
	if not muzzle and not rootPart then return end

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
	local smokeParent2 = muzzle or rootPart
	if smokeParent2 then
		local smokeAttach = Instance.new("Attachment", smokeParent2)
		local puff = Instance.new("ParticleEmitter", smokeAttach)
		puff.Texture = "rbxassetid://1370319600"
		puff.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(210, 210, 210)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 60, 60)),
		})
		puff.LightEmission = 0.05
		puff.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.4),
			NumberSequenceKeypoint.new(0.4, 0.9),
			NumberSequenceKeypoint.new(1, 0),
		})
		puff.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		puff.Lifetime = NumberRange.new(0.35, 0.7)
		puff.Speed = NumberRange.new(3, 9)
		puff.SpreadAngle = Vector2.new(25, 25)
		puff.Rate = 0
		puff.Rotation = NumberRange.new(0, 360)
		puff.RotSpeed = NumberRange.new(-40, 40)
		puff:Emit(8)
		Debris:AddItem(smokeAttach, 2)
	end
end

return GunEffects
