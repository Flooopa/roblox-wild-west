--[[
    GUN EFFECTS CLIENT
    StarterCharacterScripts
    Handles visual and audio replication of other players' gunfire.
    Kept separate from GunClient so concerns stay clean.
]]

local Players           = game:GetService("Players")
local Debris            = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player     = Players.LocalPlayer
local GunEffects = require(ReplicatedStorage:WaitForChild("GunEffects"))
local Remotes    = ReplicatedStorage:WaitForChild("GunRemotes")
local GunEffectsFired = Remotes:WaitForChild("GunEffectsFired")

GunEffectsFired.OnClientEvent:Connect(function(shooter, soundId)
	-- skip ourselves — GunClient already plays our own effects locally
	if shooter == player then return end

	local shooterChar = shooter.Character
	if not shooterChar then return end

	local rootPart = shooterChar:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- ── Gunshot sound ─────────────────────────────────────────
	-- Play directly here (not through GunEffects) so it can never
	-- be silently swallowed by a nil-guard inside the module.
	if soundId then
		local snd = Instance.new("Sound")
		snd.SoundId     = soundId
		snd.Volume      = 1
		snd.RollOffMode = Enum.RollOffMode.Linear
		snd.RollOffMinDistance = 10
		snd.RollOffMaxDistance = 250
		snd.Parent = rootPart
		snd:Play()
		Debris:AddItem(snd, 4)
	end

	-- ── Muzzle smoke (visual only) ────────────────────────────
	local tool   = shooterChar:FindFirstChildOfClass("Tool")
	local muzzle = tool and tool:FindFirstChild("Muzzle")
	GunEffects.playVisualEffects(muzzle, rootPart)
end)
