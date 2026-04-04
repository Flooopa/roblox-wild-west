-- GunEffects (ModuleScript in ReplicatedStorage)
local Debris = game:GetService("Debris")

local GunEffects = {}

function GunEffects.playFireEffects(muzzle, rootPart, soundId)
	local smokeParent = muzzle or rootPart
	if not smokeParent then return end

	-- sound
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

	-- smoke
	local attachment = Instance.new("Attachment")
	attachment.Parent = smokeParent
	local puff = Instance.new("ParticleEmitter", attachment)
	puff.Texture = "rbxassetid://1370319600"
	puff.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(200, 200, 200)),
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
	puff:Emit(10)
	Debris:AddItem(attachment, 2)

	-- muzzle flash
	if muzzle then
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 200, 60)
		light.Brightness = 3
		light.Range = 12
		light.Parent = muzzle
		Debris:AddItem(light, 0.06)

		local flashAttach = Instance.new("Attachment", muzzle)
		local flash = Instance.new("ParticleEmitter", flashAttach)
		flash.Texture = "rbxassetid://243098098"
		flash.Color = ColorSequence.new(Color3.fromRGB(255, 220, 50))
		flash.LightEmission = 1
		flash.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		flash.Transparency = NumberSequence.new(0)
		flash.Lifetime = NumberRange.new(0.03, 0.06)
		flash.Speed = NumberRange.new(0, 2)
		flash.SpreadAngle = Vector2.new(30, 30)
		flash.Rate = 0
		flash.Rotation = NumberRange.new(0, 360)
		flash:Emit(6)
		Debris:AddItem(flashAttach, 0.5)
	end
end

return GunEffects