-- InfinityAbilitySystem (ModuleScript) | StarterPlayerScripts

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris            = game:GetService("Debris")

local localPlayer  = Players.LocalPlayer
local auraTemplate = ReplicatedStorage
	:WaitForChild("Assets")
	:WaitForChild("Abilities")
	:WaitForChild("Infinity")
	:WaitForChild("InfinityPlayerAura")

local ball       = workspace:WaitForChild("Ball", math.huge)
local activeAura = nil

------------------------------------------------------------------------
-- VFX на мяче
------------------------------------------------------------------------
local function setBallAura(enabled)
	local folder = ball:FindFirstChild("Infinity")
	if not folder then return end
	local aura = folder:FindFirstChild("InfBallAura")
	if not aura then return end
	for _, e in pairs(aura:GetDescendants()) do
		if e:IsA("ParticleEmitter") then e.Enabled = enabled end
	end
end

local function emitBallBlockVFX()
	local folder = ball:FindFirstChild("Infinity")
	if not folder then return end
	local aura = folder:FindFirstChild("InfBallAuraBlocking")
	if not aura then return end
	for _, e in pairs(aura:GetDescendants()) do
		if e:IsA("ParticleEmitter") then
			e:Emit(e:GetAttribute("EmitCount") or 20)
		end
	end
end

------------------------------------------------------------------------
-- Аура игрока
------------------------------------------------------------------------

-- Маппинг: имя Part в модели (R6 названия) > части тела R15 персонажа
local R15_MAP = {
	LeftArm          = {"LeftUpperArm", "LeftLowerArm", "LeftHand"},
	RightArm         = {"RightUpperArm", "RightLowerArm", "RightHand"},
	LeftLeg          = {"LeftUpperLeg", "LeftLowerLeg", "LeftFoot"},
	RightLeg         = {"RightUpperLeg", "RightLowerLeg", "RightFoot"},
	Torso            = {"UpperTorso", "LowerTorso"},
	Head             = {"Head"},
	HumanoidRootPart = {"HumanoidRootPart"},
}

local function attachPart(part, bodyPart, container)
	local clone         = part:Clone()
	clone.CanCollide    = false
	clone.Massless      = true
	clone.CFrame        = bodyPart.CFrame
	clone.Parent        = bodyPart

	local weld  = Instance.new("WeldConstraint")
	weld.Part0  = bodyPart
	weld.Part1  = clone
	weld.Parent = clone

	for _, e in pairs(clone:GetDescendants()) do
		if e:IsA("ParticleEmitter") then e.Enabled = true end
		if e:IsA("Beam") then e.Enabled = true end
		if e:IsA("Trail") then e.Enabled = true end
	end

	local ref  = Instance.new("ObjectValue")
	ref.Value  = clone
	ref.Parent = container
end

local function showPlayerAura()
	local character = localPlayer.Character
	if not character then return end

	-- Ждём HumanoidRootPart как сигнал что персонаж загружен
	character:WaitForChild("HumanoidRootPart", 10)

	if activeAura then
		activeAura:Destroy()
		activeAura = nil
	end

	local container  = Instance.new("Folder")
	container.Name   = "InfinityAura_Active"
	container.Parent = character
	activeAura       = container

	-- Звук
	local sound = auraTemplate:FindFirstChildWhichIsA("Sound", true)
	if sound then
		local hrp = character:FindFirstChild("HumanoidRootPart")
		local s   = sound:Clone()
		s.Parent  = hrp or character
		s:Play()
		Debris:AddItem(s, (s.TimeLength > 0 and s.TimeLength or 5) + 1)
	end

	for _, part in pairs(auraTemplate:GetChildren()) do
		if not part:IsA("BasePart") then continue end

		local names = R15_MAP[part.Name]
		if not names then
			warn("InfinityAura: нет маппинга для '"..part.Name.."'")
			continue
		end

		for _, bodyPartName in pairs(names) do
			local bodyPart = character:FindFirstChild(bodyPartName)
			if bodyPart then
				attachPart(part, bodyPart, container)
			end
		end
	end
end

local function setAllEnabled(container, enabled)
	for _, ref in pairs(container:GetChildren()) do
		if ref:IsA("ObjectValue") and ref.Value then
			for _, e in pairs(ref.Value:GetDescendants()) do
				if e:IsA("ParticleEmitter") then e.Enabled = enabled end
				if e:IsA("Beam") then e.Enabled = enabled end
				if e:IsA("Trail") then e.Enabled = enabled end
			end
		end
	end
end

local function destroyAll(container)
	for _, ref in pairs(container:GetChildren()) do
		if ref:IsA("ObjectValue") and ref.Value then
			pcall(function() ref.Value:Destroy() end)
		end
	end
	container:Destroy()
end

local function hidePlayerAura()
	if not activeAura then return end
	setAllEnabled(activeAura, false)
	local c = activeAura
	activeAura = nil
	task.delay(2, function() destroyAll(c) end)
end

local function clearAura()
	if not activeAura then return end
	local c = activeAura
	activeAura = nil
	destroyAll(c)
end

------------------------------------------------------------------------
-- Публичный API
------------------------------------------------------------------------
local AbilitySystem = {}

function AbilitySystem.onInfinityActivated()
	setBallAura(true)
	showPlayerAura()
end

function AbilitySystem.onInfinityDeactivated()
	setBallAura(false)
	hidePlayerAura()
end

function AbilitySystem.onInfinityBlockEmit()
	emitBallBlockVFX()
end

function AbilitySystem.onInfinityReset()
	setBallAura(false)
	clearAura()
end

function AbilitySystem.onCharacterRemoving()
	setBallAura(false)
	clearAura()
end

return AbilitySystem