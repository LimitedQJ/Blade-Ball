-- BotSystem (ModuleScript) | ServerScriptService/Modules/BotSystem

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets = ReplicatedStorage:WaitForChild("Assets")
local packs  = assets:WaitForChild("Packs")

local BOT_SLASH_NAME = "Bot_1Slash"
local SHIELD_NAME    = "PlayerShieldInstance"

-- Настройки ходьбы (из BotWalker)
local WALK_SPEED        = 26
local WALK_RADIUS       = 1500
local MIN_WALK_DISTANCE = 20
local MOVE_TIMEOUT      = 1.5

-- Анимации R6 (из Animation скрипта)
local ANIM_IDS = {
	idle  = "http://www.roblox.com/asset/?id=180435571",
	walk  = "http://www.roblox.com/asset/?id=180426354",
	jump  = "http://www.roblox.com/asset/?id=125750702",
	fall  = "http://www.roblox.com/asset/?id=180436148",
	climb = "http://www.roblox.com/asset/?id=180436334",
}

-- Состояние бота
local BotState = {
	currentTrack  = nil,
	currentAnim   = "",
	loadedAnims   = {},
	animator      = nil,
	walkThread    = nil,   -- текущая корутина ходьбы
	walkEnabled   = false,
	startPosition = nil,
}

local BotSystem = {}

------------------------------------------------------------------------
-- Утилиты
------------------------------------------------------------------------
function BotSystem.getBot(botName)
	return workspace:FindFirstChild(botName or "Bot_1")
end

local function playAnim(animName, speed)
	speed = speed or 1
	if BotState.currentAnim == animName then return end
	if not BotState.animator then return end

	if BotState.currentTrack then
		BotState.currentTrack:Stop(0.001)
	end

	if not BotState.loadedAnims[animName] then
		local anim = Instance.new("Animation")
		anim.AnimationId = ANIM_IDS[animName]
		BotState.loadedAnims[animName] = BotState.animator:LoadAnimation(anim)
	end

	BotState.currentTrack = BotState.loadedAnims[animName]
	BotState.currentTrack:Play(0.001)
	BotState.currentTrack:AdjustSpeed(speed)
	BotState.currentAnim = animName
end

-- Случайная точка на карте с raycast под поверхность
local function getRandomWalkPoint(bot, startPos)
	local angle    = math.random() * math.pi * 4
	local dist     = math.random() * WALK_RADIUS + MIN_WALK_DISTANCE
	local targetX  = startPos.X + math.cos(angle) * dist
	local targetZ  = startPos.Z + math.sin(angle) * dist

	local params = RaycastParams.new()
	params.FilterDescendantsInstances = {bot}
	params.FilterType = Enum.RaycastFilterType.Exclude

	local result = workspace:Raycast(
		Vector3.new(targetX, 200, targetZ),
		Vector3.new(0, -400, 0),
		params
	)

	if result then
		return result.Position
	end
	return Vector3.new(targetX, startPos.Y, targetZ)
end

------------------------------------------------------------------------
-- Цикл ходьбы (запускается как task.spawn, останавливается флагом)
------------------------------------------------------------------------
local function walkLoop(bot)
	local humanoid = bot:FindFirstChild("Humanoid")
	local rootPart = bot:FindFirstChild("HumanoidRootPart")
	if not humanoid or not rootPart then return end

	local startPos = BotState.startPosition or rootPart.Position

	while BotState.walkEnabled and bot.Parent do
		local target = getRandomWalkPoint(bot, startPos)

		humanoid:MoveTo(target)

		local startTime = tick()
		while BotState.walkEnabled and bot.Parent do
			task.wait(0.15)
			local dist = (rootPart.Position - target).Magnitude
			if dist < 3 or tick() - startTime > MOVE_TIMEOUT then
				break
			end
		end

		task.wait(0)
	end

	-- Стопим бота когда цикл закончился
	if bot.Parent and humanoid then
		humanoid:MoveTo(rootPart.Position)
	end
end

------------------------------------------------------------------------
-- Настройка бота при спавне
------------------------------------------------------------------------
function BotSystem.setupBot(character)
	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:FindFirstChildWhichIsA("Humanoid")
	if not rootPart or not humanoid then return end

	humanoid.AutoRotate = false
	humanoid.WalkSpeed  = WALK_SPEED

	-- Сохраняем стартовую позицию
	BotState.startPosition = rootPart.Position

	-- Очистка старых constraint
	for _, name in pairs({"BotAlignOrient", "BotAttach0", "BotBodyGyro"}) do
		local old = rootPart:FindFirstChild(name)
		if old then old:Destroy() end
	end

	-- AlignOrientation — плавный поворот к мячу
	local attach0 = Instance.new("Attachment")
	attach0.Name   = "BotAttach0"
	attach0.Parent = rootPart

	local align = Instance.new("AlignOrientation")
	align.Name               = "BotAlignOrient"
	align.Mode               = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0        = attach0
	align.Responsiveness     = 10
	align.MaxTorque          = 10^6
	align.MaxAngularVelocity = 20
	align.Parent             = rootPart

	-- Сброс состояния анимаций
	BotState.currentTrack = nil
	BotState.currentAnim  = ""
	BotState.loadedAnims  = {}
	BotState.walkEnabled  = false

	-- Animator
	task.wait(1)
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		animator = Instance.new("Animator")
		animator.Parent = humanoid
	end
	-- Сбрасываем все играющие треки
	for _, track in pairs(animator:GetPlayingAnimationTracks()) do
		track:Stop()
	end
	BotState.animator = animator

	-- ? Анимации через события Humanoid (как в образце)
	humanoid.Running:Connect(function(speed)
		if speed > 0.1 then
			local animSpeed = math.clamp(speed / 28, 1, 4)
			playAnim("walk", animSpeed)
		else
			playAnim("idle")
		end
	end)

	humanoid.Jumping:Connect(function()
		playAnim("jump")
	end)

	humanoid.FreeFalling:Connect(function()
		playAnim("fall")
	end)

	humanoid.Climbing:Connect(function()
		playAnim("climb")
	end)

	-- Стартуем с idle
	playAnim("idle")

	task.wait(0.1)

	-- Очистка старых VFX
	for _, name in pairs({BOT_SLASH_NAME, SHIELD_NAME}) do
		local old = character:FindFirstChild(name)
		if old then old:Destroy() end
	end

	-- Slash
	local slashTemplate = packs:FindFirstChild(BOT_SLASH_NAME)
	if slashTemplate then
		local slash = slashTemplate:Clone()
		slash.Name   = BOT_SLASH_NAME
		slash.Parent = character
		slash.CFrame = rootPart.CFrame
		local weld   = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = rootPart, slash, slash
	end

	-- Shield
	local basePacks      = packs:FindFirstChild("BasePacksPlayer")
	local shieldTemplate = basePacks and basePacks:FindFirstChild("PlayerShield")
	if shieldTemplate then
		local shield        = shieldTemplate:Clone()
		shield.Name         = SHIELD_NAME
		shield.Parent       = character
		shield.Transparency = 1
		shield.CFrame       = rootPart.CFrame
		local weld          = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1, weld.Parent = rootPart, shield, shield
	end
end

------------------------------------------------------------------------
-- Включение / выключение ходьбы (вызывается из GameManager)
------------------------------------------------------------------------
function BotSystem.setBotMovement(enabled)
	local bot = BotSystem.getBot()
	if not bot then return end

	if enabled and not BotState.walkEnabled then
		BotState.walkEnabled = true
		task.spawn(walkLoop, bot)

	elseif not enabled then
		BotState.walkEnabled = false
		-- MoveTo на месте чтобы остановить
		local hrp = bot:FindFirstChild("HumanoidRootPart")
		local hum = bot:FindFirstChild("Humanoid")
		if hrp and hum then
			hum:MoveTo(hrp.Position)
		end
	end
end

------------------------------------------------------------------------
-- Поворот к мячу (каждый кадр из GameManager)
------------------------------------------------------------------------
function BotSystem.updateBotFacing(botName, ballPos)
	local bot = BotSystem.getBot(botName)
	if not (bot and bot:FindFirstChild("HumanoidRootPart")) then return end

	local hrp   = bot.HumanoidRootPart
	local align = hrp:FindFirstChild("BotAlignOrient")
	if not align then return end

	local dir = (ballPos - hrp.Position) * Vector3.new(1, 0, 1)
	if dir.Magnitude < 0.1 then return end

	align.CFrame = CFrame.lookAt(Vector3.zero, dir.Unit)
end

------------------------------------------------------------------------
-- ИИ автоблока
------------------------------------------------------------------------
function BotSystem.processBotBlock(State, Config, distance, VFXSystem, getNearestTargetFn)
	if distance > Config.BOT_BLOCK_DIST then return end
	if State.botProcessing then return end
	if not Config.IS_BOT_AUTO_BLOCK then return end

	State.botProcessing = true

	task.delay(Config.BOT_BLOCK_DELAY, function()
		if not State.target then
			State.botProcessing = false
			return
		end

		VFXSystem.triggerBlockVFX(State.target)
		VFXSystem.triggerShieldEmit(State.target)

		State.target       = getNearestTargetFn(State.target, State.ballLogicalPos)
		State.currentSpeed += Config.SPEED_ON_PARRY

		local targetRoot = State.target and State.target:FindFirstChild("HumanoidRootPart")
		if targetRoot then
			local toTarget    = (targetRoot.Position - State.ballLogicalPos).Unit
			-- Такая же логика как у игрока: 70% к цели + 30% лёгкая случайность
			local randomCurve = Vector3.new(
				math.random(-3, 3), 0, math.random(-3, 3)
			)
			if randomCurve.Magnitude > 0 then
				State.curveDirection = toTarget:Lerp(randomCurve.Unit, 0.3).Unit
			else
				State.curveDirection = toTarget
			end
		end

		State.botProcessing = false
	end)
end

------------------------------------------------------------------------
-- Вспомогательные
------------------------------------------------------------------------
function BotSystem.getAliveBots(excludeChar)
	local result = {}
	local bot = BotSystem.getBot()
	if bot and bot ~= excludeChar then
		local hum  = bot:FindFirstChild("Humanoid")
		local root = bot:FindFirstChild("HumanoidRootPart")
		if hum and root and hum.Health > 0 then
			table.insert(result, bot)
		end
	end
	return result
end

local BOT_BODY_PARTS = {
	["HumanoidRootPart"] = true,
	["Head"]             = true,
	["Torso"]            = true,
	["Left Arm"]         = true,
	["Right Arm"]        = true,
	["Left Leg"]         = true,
	["Right Leg"]        = true,
}

function BotSystem.updateCollisions(playerGroup)
	local bot = BotSystem.getBot()
	if not bot then return end
	for _, part in pairs(bot:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CollisionGroup = playerGroup
			if BOT_BODY_PARTS[part.Name] then
				part.CanCollide = true
			else
				part.CanCollide = false
			end
		end
	end
end

return BotSystem