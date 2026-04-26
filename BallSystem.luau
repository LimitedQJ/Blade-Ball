-- BallSystem (ModuleScript) | ServerScriptService/Modules/BallSystem
-- Отвечает за создание, движение и физику мяча (Part).
-- Мяч всегда Anchored = true, движение через CFrame.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local assets       = ReplicatedStorage:WaitForChild("Assets")
local ballTemplate = assets:WaitForChild("Models"):WaitForChild("Ball")

-- Цвета
local COLOR_PASSIVE_BALL  = Color3.fromRGB(175, 175, 175)
local COLOR_ACTIVE_BALL   = Color3.fromRGB(175, 0, 0)
local COLOR_ACTIVE_HL     = Color3.fromRGB(255, 0, 0)
local COLOR_PASSIVE_HL    = Color3.fromRGB(220, 220, 220)
local COLOR_ACTIVE_TRAIL  = Color3.fromRGB(255, 45, 50)
local COLOR_PASSIVE_TRAIL = Color3.fromRGB(255, 255, 255)

local MAX_DT = 0.5 -- Защита от лагов (макс шаг времени) 0.5

local activeBall = nil
local selectionEffect = Instance.new("Highlight")
selectionEffect.FillTransparency = 0.5
selectionEffect.OutlineColor     = Color3.new(1, 1, 1)
selectionEffect.Name             = "BallTargetHighlight"

local BallSystem = {}

-- 1. Создание мяча
function BallSystem.createBall(spawnPoint)
	-- Если мяч уже есть, удаляем старый, чтобы не было дубликатов
	if activeBall then 
		activeBall:Destroy() 
		activeBall = nil
	end

	local ball = ballTemplate:Clone()
	ball.Name       = "Ball"
	ball.Anchored   = true      -- ВАЖНО: Мяч закреплен, физика не влияет
	ball.CanCollide = false     -- Мяч пролетает сквозь игроков, пока не сработает логика удара
	ball.Position   = spawnPoint
	ball.Parent     = workspace

	-- Добавляем Highlight для визуализации цели
	local hl = Instance.new("Highlight")
	hl.Name             = "BallVisualHighlight"
	hl.FillTransparency = 0.4
	hl.Parent           = ball

	-- Инициализация атрибутов для клиента (чтобы он сразу видел мяч)
	ball:SetAttribute("BallPos",         spawnPoint)
	ball:SetAttribute("CurrentVelocity", Vector3.new(0,0,0))
	ball:SetAttribute("TargetPos",       spawnPoint)

	activeBall = ball
	return ball
end

function BallSystem.getActiveBall()
	return activeBall
end

function BallSystem.updateSelectionEffect(target)
	if not selectionEffect.Parent or selectionEffect.Parent ~= target then
		selectionEffect.Parent = target
	end
end

-- 2. Управление цветами
function BallSystem.setBallColor(mainColor, trailColor)
	if not activeBall then return end
	activeBall.Color = mainColor
	local bh = activeBall:FindFirstChild("BallVisualHighlight")
	if bh then bh.FillColor = mainColor end

	for _, obj in pairs(activeBall:GetDescendants()) do
		if obj:IsA("Trail") then
			obj.Color = ColorSequence.new(trailColor)
		end
	end
end

function BallSystem.setActiveColors()
	BallSystem.setBallColor(COLOR_ACTIVE_BALL, COLOR_ACTIVE_TRAIL)
	if selectionEffect.Parent then selectionEffect.FillColor = COLOR_ACTIVE_HL end
end

function BallSystem.setPassiveColors()
	BallSystem.setBallColor(COLOR_PASSIVE_BALL, COLOR_PASSIVE_TRAIL)
	if selectionEffect.Parent then selectionEffect.FillColor = COLOR_PASSIVE_HL end
end

-- 3. Основная физика (Обновление позиции)
-- Вызывается из GameManager в цикле Heartbeat
function BallSystem.updateBallPosition(State, Config, targetPart, distance, dt, infinityMult, hitDirection)
	if not activeBall then return State.ballLogicalPos end

	dt = math.min(dt, MAX_DT)
	infinityMult = infinityMult or 1.0

	local currentPos = State.ballLogicalPos
	local targetPos = targetPart.Position

	-- Вектор к цели
	local toTarget = targetPos - currentPos
	local distMag = toTarget.Magnitude

	-- Если мяч почти у цели, останавливаем вычисления (чтобы не дергался)
	if distMag < 0.5 then 
		-- Принудительно ставим точно в цель, чтобы триггер сработал
		currentPos = targetPos
		State.ballLogicalPos = currentPos
		activeBall.CFrame = CFrame.new(currentPos)
		return currentPos
	end

	local directDir = toTarget.Unit

	-- --- ЛОГИКА КРИВЫХ (CURVE) ---

	-- Если получили новое направление удара (парирование), генерируем новую дугу
	if hitDirection and hitDirection.Magnitude > 0.1 then
		-- Генерируем случайный оффсет на основе времени и направления удара
		-- Это создает уникальную траекторию для каждого отбития
		local timeSeed = tick() * 0.8
		local heightVal = math.sin(timeSeed) * (Config.CURVE_HEIGHT or 8)
		local sideVal = math.cos(timeSeed) * (Config.CURVE_SIDE or 6)

		-- Вектор вверх + вектор вбок относительно направления удара
		local upVec = Vector3.new(0, 1, 0)
		local rightVec = hitDirection:Cross(upVec).Unit

		local curveOffset = (upVec * heightVal) + (rightVec * sideVal)

		-- Новое направление кривой = Прямое направление + Смещение
		State.curveDirection = (directDir + curveOffset.Unit * 0.6).Unit
	end

	-- Если кривая еще не задана, используем прямое направление
	if not State.curveDirection or State.curveDirection.Magnitude < 0.01 then
		State.curveDirection = directDir
	end

	-- Плавно возвращаем кривую к прямой линии по мере приближения к цели
	-- Чем ближе мяч, тем меньше влияние кривой (выпрямление)
	local t = math.clamp(Config.CURVE_LERP * dt, 0, 1)
	State.curveDirection = State.curveDirection:Lerp(directDir, t)

	-- Сила искривления зависит от дистанции
	-- Далеко = сильная дуга, Близко = прямо
	local distFactor = math.clamp(
		(distance - Config.CURVE_DIST_MIN) / math.max((Config.CURVE_DIST_MAX - Config.CURVE_DIST_MIN), 1),
		0, 1
	)

	-- Итоговое направление движения
	local finalDir = directDir:Lerp(State.curveDirection, distFactor * Config.CURVE_BLEND).Unit

	-- Расчет скорости
	local speed = State.currentSpeed
	local effectiveSpeed = speed * infinityMult

	State.currentVelocity = finalDir * effectiveSpeed

	-- Новая позиция
	local nextPos = currentPos + State.currentVelocity * dt

	-- Проверка пола (чтобы мяч не уходил под карту)
	if nextPos.Y < Config.FLOOR_Y then
		nextPos = Vector3.new(nextPos.X, Config.FLOOR_Y, nextPos.Z)
		-- При ударе об пол можно немного менять направление, но пока просто скользим
	end

	-- Обновляем логическую позицию в стейте
	State.ballLogicalPos = nextPos

	-- --- СИНХРОНИЗАЦИЯ С КЛИЕНТОМ ---
	-- 1. Двигаем сам Part (для тех, кто видит напрямую)
	activeBall.CFrame = CFrame.new(nextPos)

	-- 2. Обновляем атрибуты (для BallClient, который делает сглаживание)
	activeBall:SetAttribute("BallPos",         nextPos)
	activeBall:SetAttribute("CurrentVelocity", State.currentVelocity)
	activeBall:SetAttribute("TargetPos",       targetPos)

	return nextPos
end

-- 4. Сброс мяча
function BallSystem.resetBall(spawnPoint)
	if not activeBall then return end

	activeBall.CFrame = CFrame.new(spawnPoint)
	activeBall:SetAttribute("BallPos",         spawnPoint)
	activeBall:SetAttribute("CurrentVelocity", Vector3.new(0,0,0))
	activeBall:SetAttribute("TargetPos",       spawnPoint)

	-- Сброс стейта (если нужно, вызывается извне)
end

return BallSystem