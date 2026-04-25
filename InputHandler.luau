-- InputHandler (LocalScript) | StarterPlayerScripts
-- Обработка ввода: блок, авто-паррирование, направление камеры

local UserInputService  = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local Players           = game:GetService("Players")

local event  = ReplicatedStorage:WaitForChild("BlockEvent")
local camera = workspace.CurrentCamera

-- Ждём пока сервер точно готов (персонаж заспавнился = сервер уже запущен)
local localPlayer = Players.LocalPlayer
if not localPlayer.Character then
	localPlayer.CharacterAdded:Wait()
end

-- ? Отправляем направление камеры не каждый кадр, а раз в 0.1 сек
-- Это снижает сетевой трафик в ~6 раз без потери качества
local CAM_DIR_INTERVAL = 0.1
local camDirTimer      = 0

RunService.Heartbeat:Connect(function(dt)
	camDirTimer += dt
	if camDirTimer >= CAM_DIR_INTERVAL then
		camDirTimer = 0
		event:FireServer("UpdateCameraDir", camera.CFrame.LookVector)
	end
end)

-- Блок: клавиши F, E или ЛКМ
local BLOCK_KEYS = {
	Enum.KeyCode.F,
	Enum.KeyCode.E,
}

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end

	-- Клавиатура
	for _, key in pairs(BLOCK_KEYS) do
		if input.KeyCode == key then
			event:FireServer("Block", camera.CFrame.LookVector)
			return
		end
	end

	-- ЛКМ
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		event:FireServer("Block", camera.CFrame.LookVector)
	end
end)

-- Мобильный тап
UserInputService.TouchTapInWorld:Connect(function(position, processed)
	if processed then return end
	event:FireServer("Block", camera.CFrame.LookVector)
end)