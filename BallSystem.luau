-- BallSystem (ModuleScript) | ServerScriptService/Modules/BallSystem

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets       = ReplicatedStorage:WaitForChild("Assets")
local ballTemplate = assets:WaitForChild("Models"):WaitForChild("Ball")

local COLOR_PASSIVE_BALL  = Color3.fromRGB(175, 175, 175)
local COLOR_ACTIVE_BALL   = Color3.fromRGB(175, 0, 0)
local COLOR_ACTIVE_HL     = Color3.fromRGB(255, 0, 0)
local COLOR_PASSIVE_HL    = Color3.fromRGB(220, 220, 220)
local COLOR_ACTIVE_TRAIL  = Color3.fromRGB(255, 45, 50)
local COLOR_PASSIVE_TRAIL = Color3.fromRGB(255, 255, 255)

local MAX_DT = 0.05

local activeBall = nil

local selectionEffect = Instance.new("Highlight")
selectionEffect.FillTransparency = 0.5
selectionEffect.OutlineColor     = Color3.new(1, 1, 1)
selectionEffect.Name             = "BallTargetHighlight"

local BallSystem = {}

function BallSystem.createBall(spawnPoint)
	local ball      = ballTemplate:Clone()
	ball.Name       = "Ball"
	ball.Anchored   = true
	ball.CanCollide = false
	ball.Position   = spawnPoint
	ball.Parent     = workspace

	local hl = Instance.new("Highlight")
	hl.Name             = "BallVisualHighlight"
	hl.FillTransparency = 0.4
	hl.Parent           = ball

	activeBall = ball
	return ball
end

function BallSystem.getActiveBall()
	return activeBall
end

function BallSystem.updateSelectionEffect(target)
	selectionEffect.Parent = target
end

function BallSystem.setBallColor(mainColor, trailColor)
	if not activeBall then return end
	activeBall.Color = mainColor
	local bh = activeBall:FindFirstChild("BallVisualHighlight")
	if bh then bh.FillColor = mainColor end
	for _, t in pairs(activeBall:GetDescendants()) do
		if t:IsA("Trail") then
			t.Color = ColorSequence.new(trailColor)
		end
	end
end

function BallSystem.setActiveColors()
	BallSystem.setBallColor(COLOR_ACTIVE_BALL, COLOR_ACTIVE_TRAIL)
	selectionEffect.FillColor = COLOR_ACTIVE_HL
end

function BallSystem.setPassiveColors()
	BallSystem.setBallColor(COLOR_PASSIVE_BALL, COLOR_PASSIVE_TRAIL)
	selectionEffect.FillColor = COLOR_PASSIVE_HL
end

function BallSystem.updateBallPosition(State, Config, targetPart, distance, dt, infinityMult)
	dt = math.min(dt, MAX_DT)
	infinityMult = infinityMult or 1.0

	local ballLogicalPos = State.ballLogicalPos

	-- Защита от NaN когда мяч совпадает с целью
	local toTarget = targetPart.Position - ballLogicalPos
	if toTarget.Magnitude < 0.01 then return ballLogicalPos end
	local directDir = toTarget.Unit

	-- Инициализация curveDirection
	if State.curveDirection.Magnitude < 0.01 then
		State.curveDirection = directDir
	end

	-- Плавно тянем кривую к прямому направлению
	State.curveDirection = State.curveDirection:Lerp(
		directDir,
		math.clamp(Config.CURVE_LERP * dt, 0, 1)
	)

	-- Фактор дистанции: 0 вблизи цели, 1 на дальней
	local distanceFactor = math.clamp(
		(distance - Config.CURVE_DIST_MIN) / (Config.CURVE_DIST_MAX - Config.CURVE_DIST_MIN),
		0, 1
	)

	-- Итоговое направление
	local finalDir = directDir:Lerp(
		State.curveDirection,
		distanceFactor * Config.CURVE_BLEND
	).Unit

	local speed = State.currentSpeed

	-- Применяем Infinity: плавное замедление/остановка мяча
	local effectiveSpeed = speed * infinityMult
	State.currentVelocity = finalDir * effectiveSpeed

	local nextPos = ballLogicalPos + State.currentVelocity * dt

	-- Ограничение по полу
	if nextPos.Y < Config.FLOOR_Y then
		nextPos = Vector3.new(nextPos.X, Config.FLOOR_Y, nextPos.Z)
		if State.currentVelocity.Y < 0 then
			State.currentVelocity = Vector3.new(
				State.currentVelocity.X, 0, State.currentVelocity.Z
			).Unit * speed
		end
	end

	activeBall:SetAttribute("BallPos",         nextPos)
	activeBall:SetAttribute("CurrentVelocity", State.currentVelocity)
	activeBall:SetAttribute("TargetPos",       targetPart.Position)

	return nextPos
end

function BallSystem.resetBall(spawnPoint)
	if not activeBall then return end
	activeBall.Position = spawnPoint
	activeBall:SetAttribute("BallPos",         spawnPoint)
	activeBall:SetAttribute("CurrentVelocity", Vector3.zero)
	activeBall:SetAttribute("TargetPos",       spawnPoint)
end

return BallSystem