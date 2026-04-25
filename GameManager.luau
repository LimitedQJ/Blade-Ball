-- GameManager (Script) | ServerScriptService
-- Оркестрирует все системы. Не содержит логику — только соединяет модули.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")
local PhysicsService    = game:GetService("PhysicsService")

-- Modules лежит как дочерний объект самого GameManager (Script)
local Modules = script:WaitForChild("Modules")

local GameConstants  = require(Modules:WaitForChild("GameConstants"))
local BallSystem     = require(Modules:WaitForChild("BallSystem"))
local BotSystem      = require(Modules:WaitForChild("BotSystem"))
local PlayerSystem   = require(Modules:WaitForChild("PlayerSystem"))
local VFXSystem      = require(Modules:WaitForChild("VFXSystem"))
local AbilitySystem  = require(Modules:WaitForChild("Abilities"):WaitForChild("InfinityAbilitySystem"))

local event        = ReplicatedStorage:WaitForChild("BlockEvent")
local abilityEvent = ReplicatedStorage:WaitForChild("AbilityEvent")

-- Конфиг из констант (одно место — GameConstants)
local Config = {
	IS_PLAYER_IMMORTAL = GameConstants.IS_PLAYER_IMMORTAL,
	IS_BOT_AUTO_BLOCK  = GameConstants.IS_BOT_AUTO_BLOCK,
	BASE_SPEED         = GameConstants.BASE_SPEED,
	ACCEL_INTERVAL     = GameConstants.ACCEL_INTERVAL,
	SPEED_INCREMENT    = GameConstants.SPEED_INCREMENT,
	SPEED_ON_PARRY     = GameConstants.SPEED_ON_PARRY,
	CURVE_LERP         = GameConstants.CURVE_LERP,
	CURVE_BLEND        = GameConstants.CURVE_BLEND,
	CURVE_DIST_MIN     = GameConstants.CURVE_DIST_MIN,
	CURVE_DIST_MAX     = GameConstants.CURVE_DIST_MAX,
	BLOCK_DISTANCE     = GameConstants.BLOCK_DISTANCE,
	KILL_DISTANCE      = GameConstants.KILL_DISTANCE,
	BLOCK_DURATION     = GameConstants.BLOCK_DURATION,
	PARRY_COOLDOWN     = GameConstants.PARRY_COOLDOWN,
	BOT_BLOCK_DIST     = GameConstants.BOT_BLOCK_DIST,
	BOT_BLOCK_DELAY    = GameConstants.BOT_BLOCK_DELAY,
	FLOOR_Y            = GameConstants.FLOOR_Y,
	SPAWN_POINT        = GameConstants.SPAWN_POINT,
	PLAYER_GROUP       = GameConstants.PLAYER_GROUP,
}

-- Регистрация коллизий
pcall(function() PhysicsService:RegisterCollisionGroup(Config.PLAYER_GROUP) end)
PhysicsService:CollisionGroupSetCollidable(Config.PLAYER_GROUP, Config.PLAYER_GROUP, false)

-- Состояние игры
local State = {
	botMoveEnabled   = false,
	blockingPlayers  = {},
	autoParryPlayers = {},
	playerCameraDir  = {},
	playerCooldowns  = {},
	ballLogicalPos   = Config.SPAWN_POINT,
	activeBall       = nil,
	target           = nil,
	botProcessing    = false,
	currentSpeed     = Config.BASE_SPEED,
	currentVelocity  = Vector3.new(0, 0, 1),
	curveDirection   = Vector3.new(0, 0, 1),
	accelTimer       = 0,
}

------------------------------------------------------------------------
-- Утилиты для поиска целей (игроки + боты в одном месте)
------------------------------------------------------------------------
local function getNearestTarget(excludeChar, fromPos)
	local nearest     = nil
	local nearestDist = math.huge

	local function checkChar(char)
		local root = char:FindFirstChild("HumanoidRootPart")
		if not root then return end
		local dist = (root.Position - fromPos).Magnitude
		if dist < nearestDist then
			nearestDist = dist
			nearest     = char
		end
	end

	for _, char in pairs(PlayerSystem.getAlivePlayers(excludeChar)) do checkChar(char) end
	for _, char in pairs(BotSystem.getAliveBots(excludeChar))        do checkChar(char) end

	return nearest
end

local function getRandomTarget(excludeChar)
	local pool = {}
	for _, c in pairs(PlayerSystem.getAlivePlayers(excludeChar)) do table.insert(pool, c) end
	for _, c in pairs(BotSystem.getAliveBots(excludeChar))        do table.insert(pool, c) end
	if #pool == 0 then return nil end
	return pool[math.random(1, #pool)]
end

------------------------------------------------------------------------
-- Инициализация
------------------------------------------------------------------------
State.activeBall = BallSystem.createBall(Config.SPAWN_POINT)

------------------------------------------------------------------------
-- Входящие события от клиентов
------------------------------------------------------------------------
event.OnServerEvent:Connect(function(player, action, value)
	if action == "UpdateCameraDir" and typeof(value) == "Vector3" then
		State.playerCameraDir[player] = value

	elseif action == "ToggleAutoParry" then
		State.autoParryPlayers[player] = value

	elseif action == "ToggleBotMove" then
		State.botMoveEnabled = value
		BotSystem.setBotMovement(value)

	elseif action == "Block" and typeof(value) == "Vector3" and player.Character then
		-- Проверяем что персонаж жив
		local hum = player.Character:FindFirstChild("Humanoid")
		if not hum or hum.Health <= 0 then return end
		-- Блок на кулдауне
		local cd = State.playerCooldowns[player]
		if cd and tick() < cd then return end
		-- Блок уже активен — нельзя нажать повторно
		local existing = State.blockingPlayers[player]
		if existing and (tick() - existing.Time <= Config.BLOCK_DURATION) then return end
		VFXSystem.triggerShieldEmit(player.Character)
		State.blockingPlayers[player] = { Dir = value, Time = tick() }
		event:FireClient(player, "ShieldActivated", Config.BLOCK_DURATION)
	end
end)

-- AbilityEvent — отдельный канал для способностей
abilityEvent.OnServerEvent:Connect(function(player, action)
	-- Проверяем что игрок жив
	local char = player.Character
	local hum  = char and char:FindFirstChild("Humanoid")
	if not hum or hum.Health <= 0 then return end

	if action == "ActivateInfinity" then
		AbilitySystem.tryActivateInfinity(player, abilityEvent)
	end
end)

------------------------------------------------------------------------
-- Главный игровой цикл
------------------------------------------------------------------------
RunService.Heartbeat:Connect(function(dt)
	if not State.activeBall then return end

	-- Поиск первой цели
	if not State.target then
		State.target = getRandomTarget(nil)
	end
	if not State.target then return end

	-- Поворот бота
	BotSystem.updateBotFacing(GameConstants.BOT_NAME, State.ballLogicalPos)
	BallSystem.updateSelectionEffect(State.target)

	-- Ускорение каждые 0.001 сек
	State.accelTimer += dt
	if State.accelTimer >= Config.ACCEL_INTERVAL then
		State.currentSpeed += Config.SPEED_INCREMENT
		State.accelTimer = 0
	end

	local targetPart = State.target:FindFirstChild("HumanoidRootPart")
	if not targetPart then
		State.target = getRandomTarget(nil)
		return
	end

	local distance = (targetPart.Position - State.ballLogicalPos).Magnitude
	local isPlayer = game.Players:GetPlayerFromCharacter(State.target) ~= nil

	-- Обработка блоков
	if State.target.Name == GameConstants.BOT_NAME then
		BotSystem.processBotBlock(State, Config, distance, VFXSystem, getNearestTarget)
	elseif isPlayer then
		PlayerSystem.processPlayerBlock(State, Config, distance, event, VFXSystem, getNearestTarget, abilityEvent, AbilitySystem)
	end

	-- Infinity: замедляем мяч если цель — игрок с активным Infinity
	local infinityMult = 1.0
	if isPlayer then
		local plrTarget = game.Players:GetPlayerFromCharacter(State.target)
		if plrTarget then
			infinityMult = AbilitySystem.getInfinitySpeedMult(plrTarget, State.ballLogicalPos, targetPart.Position)
		end
	end

	-- Движение мяча
	local nextPos = BallSystem.updateBallPosition(State, Config, targetPart, distance, dt, infinityMult)
	State.ballLogicalPos = nextPos

	-- Цвет мяча
	if isPlayer then BallSystem.setActiveColors() else BallSystem.setPassiveColors() end
end)

-- Коллизии (оба модуля)
RunService.Stepped:Connect(function()
	PlayerSystem.updateCollisions(Config.PLAYER_GROUP)
	BotSystem.updateCollisions(Config.PLAYER_GROUP)
end)

-- Спавн персонажей
game.Players.PlayerAdded:Connect(function(plr)
	AbilitySystem.initPlayer(plr)
	plr.CharacterAdded:Connect(function(char)
		-- Сбрасываем кулдаун только если он реально висел
		-- и только ПОСЛЕ небольшой задержки чтобы не сбить ShieldActivated
		-- который может уйти клиенту почти одновременно
		local hadCooldown = State.playerCooldowns[plr] ~= nil or State.blockingPlayers[plr] ~= nil
		State.blockingPlayers[plr] = nil
		State.playerCooldowns[plr] = nil
		AbilitySystem.onPlayerRespawn(plr, abilityEvent)
		if hadCooldown then
			task.delay(0.2, function()
				event:FireClient(plr, "ResetCooldown")
			end)
		end
		PlayerSystem.setupCharacter(char)
	end)
end)

-- Сбрасываем данные игрока при выходе
game.Players.PlayerRemoving:Connect(function(plr)
	State.blockingPlayers[plr]  = nil
	State.playerCooldowns[plr]  = nil
	State.autoParryPlayers[plr] = nil
	State.playerCameraDir[plr]  = nil
	AbilitySystem.removePlayer(plr)
end)

-- Инициализация бота (он уже в Workspace, PlayerAdded на него не сработает)
local function setupBotIfExists()
	local bot = workspace:FindFirstChild(GameConstants.BOT_NAME)
	if bot then
		BotSystem.setupBot(bot)
	end
end

setupBotIfExists()
workspace.ChildAdded:Connect(function(child)
	if child.Name == GameConstants.BOT_NAME then
		task.wait(0.5)
		BotSystem.setupBot(child)
	end
end)