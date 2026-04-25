-- HUDController (LocalScript) | StarterPlayerScripts

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local UserInputService  = game:GetService("UserInputService")
local RunService        = game:GetService("RunService")

if not RunService:IsClient() then return end

local event        = ReplicatedStorage:WaitForChild("BlockEvent")
local abilityEvent = ReplicatedStorage:WaitForChild("AbilityEvent")
local localPlayer  = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()
local AbilitySystem = require(script.Parent:WaitForChild("InfinityAbilitySystem"))

local function addCorner(parent, radius)
	local c = Instance.new("UICorner", parent)
	c.CornerRadius = UDim.new(radius or 0.1, 0)
end

-- Create GameHUD once
local screenGui = localPlayer.PlayerGui:FindFirstChild("GameHUD")

if not screenGui then
	screenGui                = Instance.new("ScreenGui")
	screenGui.Name           = "GameHUD"
	screenGui.ResetOnSpawn   = false
	screenGui.IgnoreGuiInset = true
	screenGui.Parent         = localPlayer.PlayerGui

	-- Score
	local lbl = Instance.new("TextLabel", screenGui)
	lbl.Name = "ScoreLabel"; lbl.Size = UDim2.new(0,200,0,50)
	lbl.Position = UDim2.new(0,10,0,10); lbl.BackgroundColor3 = Color3.fromRGB(0,0,0)
	lbl.BackgroundTransparency = 0.5; lbl.TextColor3 = Color3.new(1,1,1)
	lbl.TextScaled = true; lbl.Font = Enum.Font.GothamBold
	lbl.Text = "0"; lbl.BorderSizePixel = 0; addCorner(lbl)

	-- Auto-Parry button
	local ap = Instance.new("TextButton", screenGui)
	ap.Name = "AutoParryButton"; ap.Size = UDim2.new(0,200,0,50)
	ap.Position = UDim2.new(0,10,0,70); ap.BackgroundColor3 = Color3.fromRGB(200,0,0)
	ap.BackgroundTransparency = 0.5; ap.TextColor3 = Color3.new(1,1,1)
	ap.TextScaled = true; ap.Font = Enum.Font.GothamBold
	ap.Text = "Auto-Parry: OFF [P]"; ap.BorderSizePixel = 0; addCorner(ap)

	-- Cooldown bar
	local cf = Instance.new("Frame", screenGui)
	cf.Name = "CooldownFrame"; cf.Size = UDim2.new(0,200,0,18)
	cf.Position = UDim2.new(0,10,0,130); cf.BackgroundColor3 = Color3.fromRGB(40,40,40)
	cf.BackgroundTransparency = 0.35; cf.BorderSizePixel = 0
	cf.ClipsDescendants = true; addCorner(cf, 0.5)

	local cb = Instance.new("Frame", cf)
	cb.Name = "CooldownBar"; cb.Size = UDim2.new(1,0,1,0)
	cb.BackgroundColor3 = Color3.fromRGB(0,180,80); cb.BorderSizePixel = 0; addCorner(cb, 0.5)

	local cl = Instance.new("TextLabel", cf)
	cl.Name = "CooldownLabel"; cl.Size = UDim2.new(1,0,1,0)
	cl.BackgroundTransparency = 1; cl.TextColor3 = Color3.new(1,1,1)
	cl.TextScaled = true; cl.Font = Enum.Font.GothamBold
	cl.Text = "READY"; cl.ZIndex = 2

	-- Bot Move button
	local bm = Instance.new("TextButton", screenGui)
	bm.Name = "BotMoveButton"; bm.Size = UDim2.new(0,200,0,50)
	bm.Position = UDim2.new(0,10,0,158); bm.BackgroundColor3 = Color3.fromRGB(80,80,80)
	bm.BackgroundTransparency = 0.5; bm.TextColor3 = Color3.new(1,1,1)
	bm.TextScaled = true; bm.Font = Enum.Font.GothamBold
	bm.Text = "Bot Move: OFF [B]"; bm.BorderSizePixel = 0; addCorner(bm)

	-- Infinity UI
	local inf = Instance.new("Frame", screenGui)
	inf.Name = "InfinityFrame"; inf.Size = UDim2.new(0,160,0,52)
	inf.Position = UDim2.new(0.5,-80,1,-90)
	inf.BackgroundColor3 = Color3.fromRGB(0,0,0); inf.BackgroundTransparency = 0.45
	inf.BorderSizePixel = 0; addCorner(inf)

	local it = Instance.new("TextLabel", inf)
	it.Name = "Title"; it.Size = UDim2.new(1,0,0.45,0)
	it.BackgroundTransparency = 1; it.TextColor3 = Color3.fromRGB(100,180,255)
	it.TextScaled = true; it.Font = Enum.Font.GothamBold; it.Text = "INFINITY  [Q]"

	local ibg = Instance.new("Frame", inf)
	ibg.Name = "InfBarBg"; ibg.Size = UDim2.new(0.9,0,0.28,0)
	ibg.Position = UDim2.new(0.05,0,0.64,0); ibg.BackgroundColor3 = Color3.fromRGB(40,40,40)
	ibg.BackgroundTransparency = 0.3; ibg.BorderSizePixel = 0
	ibg.ClipsDescendants = true; addCorner(ibg, 0.5)

	local ib = Instance.new("Frame", ibg)
	ib.Name = "InfBar"; ib.Size = UDim2.new(1,0,1,0)
	ib.BackgroundColor3 = Color3.fromRGB(0,180,80); ib.BorderSizePixel = 0; addCorner(ib, 0.5)

	local il = Instance.new("TextLabel", ibg)
	il.Name = "InfLabel"; il.Size = UDim2.new(1,0,1,0)
	il.BackgroundTransparency = 1; il.TextColor3 = Color3.new(1,1,1)
	il.TextScaled = true; il.Font = Enum.Font.GothamBold
	il.Text = "READY"; il.ZIndex = 2
end

-- References
local scoreLabel      = screenGui:WaitForChild("ScoreLabel")
local autoParryButton = screenGui:WaitForChild("AutoParryButton")
local cooldownFrame   = screenGui:WaitForChild("CooldownFrame")
local cooldownBar     = cooldownFrame:WaitForChild("CooldownBar")
local cooldownLabel   = cooldownFrame:WaitForChild("CooldownLabel")
local botMoveButton   = screenGui:WaitForChild("BotMoveButton")
local infFrame        = screenGui:WaitForChild("InfinityFrame")
local infBar          = infFrame:WaitForChild("InfBarBg"):WaitForChild("InfBar")
local infLabel        = infFrame:WaitForChild("InfBarBg"):WaitForChild("InfLabel")

-- Block cooldown state
local shieldPhaseEnd   = 0
local cooldownEnd      = 0
local shieldDuration   = 0.5
local cooldownDuration = 2
local phase            = "ready"

local function setReady()
	phase                        = "ready"
	cooldownBar.Size             = UDim2.new(1,0,1,0)
	cooldownBar.BackgroundColor3 = Color3.fromRGB(0,180,80)
	cooldownLabel.Text           = "READY"
end

-- Infinity state
local infPhase       = "ready"
local infActiveEnd   = 0
local infCooldownEnd = 0
local infActiveDur   = 10
local infCooldownDur = 22

local function setInfReady()
	infPhase                = "ready"
	infBar.Size             = UDim2.new(1,0,1,0)
	infBar.BackgroundColor3 = Color3.fromRGB(0,180,80)
	infLabel.Text           = "READY"
end

-- UI update loop
RunService.RenderStepped:Connect(function()
	local now = tick()

	-- Block bar
	if phase ~= "ready" then
		if phase == "shield" then
			local r = shieldPhaseEnd - now
			if r <= 0 then
				cooldownBar.Size = UDim2.new(0,0,1,0)
				cooldownBar.BackgroundColor3 = Color3.fromRGB(0,120,220)
				cooldownLabel.Text = "..."
			else
				local ratio = r / shieldDuration
				cooldownBar.Size = UDim2.new(ratio,0,1,0)
				cooldownBar.BackgroundColor3 = Color3.fromRGB(0,120,220)
				cooldownLabel.Text = "BLOCK"
			end
		elseif phase == "cooldown" then
			local r = cooldownEnd - now
			if r <= 0 then
				setReady()
			else
				local ratio = r / cooldownDuration
				cooldownBar.Size = UDim2.new(ratio,0,1,0)
				cooldownBar.BackgroundColor3 = Color3.fromRGB(
					math.floor(220*ratio), math.floor(180*(1-ratio)), 0)
				cooldownLabel.Text = string.format("%.1f", r)
			end
		end
	end

	-- Infinity bar
	if infPhase ~= "ready" then
		if infPhase == "active" then
			local r = infActiveEnd - now
			if r <= 0 then
				infBar.Size = UDim2.new(0,0,1,0)
				infBar.BackgroundColor3 = Color3.fromRGB(100,180,255)
				infLabel.Text = "..."
			else
				local ratio = r / infActiveDur
				infBar.Size = UDim2.new(ratio,0,1,0)
				infBar.BackgroundColor3 = Color3.fromRGB(100,180,255)
				infLabel.Text = string.format("%.1f", r)
			end
		elseif infPhase == "cooldown" then
			local r = infCooldownEnd - now
			if r <= 0 then
				setInfReady()
			else
				local ratio = r / infCooldownDur
				infBar.Size = UDim2.new(ratio,0,1,0)
				infBar.BackgroundColor3 = Color3.fromRGB(
					math.floor(200*ratio), math.floor(160*(1-ratio)), 0)
				infLabel.Text = string.format("%.1f", r)
			end
		end
	end
end)

-- Buttons
local score           = 0
local autoParryActive = false

local function setAutoParry(value)
	autoParryActive = value
	autoParryButton.Text             = autoParryActive and "Auto-Parry: ON [P]" or "Auto-Parry: OFF [P]"
	autoParryButton.BackgroundColor3 = autoParryActive and Color3.fromRGB(0,180,0) or Color3.fromRGB(200,0,0)
	event:FireServer("ToggleAutoParry", autoParryActive)
end

local botMoveEnabled = false
local function setBotMove(value)
	botMoveEnabled = value
	botMoveButton.Text             = botMoveEnabled and "Bot Move: ON [B]" or "Bot Move: OFF [B]"
	botMoveButton.BackgroundColor3 = botMoveEnabled and Color3.fromRGB(0,120,200) or Color3.fromRGB(80,80,80)
	event:FireServer("ToggleBotMove", botMoveEnabled)
end

autoParryButton.MouseButton1Click:Connect(function() setAutoParry(not autoParryActive) end)
botMoveButton.MouseButton1Click:Connect(function() setBotMove(not botMoveEnabled) end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.P then setAutoParry(not autoParryActive) end
	if input.KeyCode == Enum.KeyCode.B then setBotMove(not botMoveEnabled) end
	if input.KeyCode == Enum.KeyCode.Q then
		if infPhase ~= "ready" then return end
		abilityEvent:FireServer("ActivateInfinity")
	end
end)

-- BlockEvent
event.OnClientEvent:Connect(function(action, value)
	if action == "UpdateScore" then
		score += 1; scoreLabel.Text = tostring(score); setReady()
	elseif action == "ShieldActivated" then
		shieldDuration = value or 0.5
		shieldPhaseEnd = tick() + shieldDuration
		phase = "shield"
	elseif action == "ParryMissed" then
		cooldownDuration = value or 2
		cooldownEnd      = tick() + cooldownDuration
		phase = "cooldown"
	elseif action == "ResetCooldown" then
		setReady()
	end
end)

-- AbilityEvent
abilityEvent.OnClientEvent:Connect(function(action, v1, v2)
	if action == "InfinityActivated" then
		infActiveDur   = v1 or 10
		infCooldownDur = v2 or 22
		infActiveEnd   = tick() + infActiveDur
		-- cooldown starts AFTER active phase ends
		infCooldownEnd = tick() + infActiveDur + infCooldownDur
		infPhase       = "active"
		AbilitySystem.onInfinityActivated()

	elseif action == "InfinityDeactivated" then
		infCooldownDur = v1 or 22
		infCooldownEnd = tick() + infCooldownDur
		infPhase       = "cooldown"
		AbilitySystem.onInfinityDeactivated()

	elseif action == "InfinityBlockEmit" then
		AbilitySystem.onInfinityBlockEmit()

	elseif action == "InfinityReset" then
		AbilitySystem.onInfinityDeactivated()
		setInfReady()
	end
end)

localPlayer.CharacterRemoving:Connect(function()
	AbilitySystem.onCharacterRemoving()
end)

setReady()
setInfReady()
AbilitySystem.onInfinityReset()