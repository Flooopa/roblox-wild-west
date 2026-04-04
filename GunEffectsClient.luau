--[[
    GUN EFFECTS CLIENT
    StarterCharacterScripts
    Handles visual and audio replication of other players' gunfire.
    Kept separate from GunClient so concerns stay clean.
]]

local Players           = game:GetService("Players")
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
	local tool     = shooterChar:FindFirstChildOfClass("Tool")
	local muzzle   = tool and tool:FindFirstChild("Muzzle")

	GunEffects.playFireEffects(muzzle, rootPart, soundId)
end)