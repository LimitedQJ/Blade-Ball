-- BallClient (LocalScript) | StarterPlayerScripts
-- Отвечает за плавную визуализацию мяча (Part) на клиенте.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local LERP_SPEED = 10         -- Скорость сглаживания (выше = быстрее реакция, но может дергаться)
local MAX_SNAP_DIST = 10000    -- Дистанция телепортации без сглаживания
local LOOK_AHEAD_FACTOR = 0.03  -- Небольшое предсказание позиции

local ballPart = nil
local currentVisualPos = nil
local lastVelocity = Vector3.new(0, 0, 0) -- По умолчанию смотрит вверх

-- Функция поиска мяча
local function findBall()
	local obj = Workspace:FindFirstChild("Ball")
	if obj and obj:IsA("BasePart") then
		return obj
	end
	return nil
end

-- Инициализация
local function init()
	ballPart = findBall()

	if ballPart then
		currentVisualPos = ballPart.Position
		-- Отключаем физику на клиенте, чтобы сервер управлял позицией визуально
		ballPart.Anchored = true 
	else
		-- Ждем появления мяча
		local conn
		conn = Workspace.ChildAdded:Connect(function(child)
			if child.Name == "Ball" and child:IsA("BasePart") then
				ballPart = child
				currentVisualPos = ballPart.Position
				ballPart.Anchored = true
				conn:Disconnect()
			end
		end)
	end
end

-- Основной цикл отрисовки
RunService.RenderStepped:Connect(function(dt)
	-- Проверяем наличие мяча каждый кадр (на случай ресета)
	if not ballPart then
		ballPart = findBall()
		if not ballPart then return end
		if not currentVisualPos then currentVisualPos = ballPart.Position end
		-- Важно: на клиенте мяч должен быть закреплен, чтобы физика не мешала лерпу
		ballPart.Anchored = true 
	end

	-- Читаем атрибуты с сервера
	local serverPos = ballPart:GetAttribute("BallPos")
	local velocity = ballPart:GetAttribute("CurrentVelocity")

	-- Если сервер еще не прислал данные, используем текущую позицию части
	if not serverPos then 
		serverPos = ballPart.Position 
	end

	-- Обновляем вектор скорости для поворота
	if velocity and velocity.Magnitude > 0.1 then
		lastVelocity = velocity
	end

	-- 1. Проверка на телепортацию (если мяч резко переместили)
	local dist = (serverPos - currentVisualPos).Magnitude
	if dist > MAX_SNAP_DIST then
		currentVisualPos = serverPos
		ballPart.CFrame = CFrame.new(currentVisualPos)
		return
	end

	-- 2. Плавная интерполяция (Lerp)
	-- Добавляем микро-предсказание, чтобы компенсировать сетевую задержку
	local predictedPos = serverPos + (lastVelocity * LOOK_AHEAD_FACTOR)

	currentVisualPos = currentVisualPos:Lerp(predictedPos, math.clamp(LERP_SPEED * dt, 0, 1))

	-- 3. Вычисляем направление взгляда (CFrame)
	-- Мяч должен смотреть туда, куда летит
	local lookTarget = currentVisualPos + lastVelocity

	-- Защита от нулевого вектора (если мяч стоит)
	if lastVelocity.Magnitude < 0.1 then
		lookTarget = currentVisualPos + Vector3.new(0, 0, 1)
	end

	local newCFrame = CFrame.lookAt(currentVisualPos, lookTarget)

	-- Применяем позицию и поворот напрямую к Part
	ballPart.CFrame = newCFrame
end)

-- Запуск при старте скрипта
init()