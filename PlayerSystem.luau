-- PlayerSystem (ModuleScript) | ServerScriptService/Modules
-- ќтвечает “ќЋ№ ќ за: игроков (не ботов), их настройку, блоки, коллизии

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local assets         = ReplicatedStorage:WaitForChild("Assets")
local packs          = assets:WaitForChild("Packs")
local shieldTemplate = packs:WaitForChild("BasePacksPlayer"):WaitForChild("PlayerShield")

local SLASH_NAME  = "PlayerSlash"
local SHIELD_NAME = "PlayerShieldInstance"

local PlayerSystem = {}

-- Ќастройка персонажа игрока (не бота)
-- ѕроверка: персонаж должен принадлежать реальному игроку
function PlayerSystem.setupCharacter(character)
	if not game.Players:GetPlayerFromCharacter(character) then return end  -- боты настраиваютс€ в BotSystem

	local rootPart = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:FindFirstChild("Humanoid")
	if not rootPart or not humanoid then return end

	humanoid.AutoRotate = true
	task.wait(0.2)

	-- ќчистка старых эффектов
	for _, name in pairs({SLASH_NAME, SHIELD_NAME}) do
		local old = character:FindFirstChild(name)
		if old then old:Destroy() end
	end

	-- Slash (эффект удара)
	local slashTemplate = packs:FindFirstChild(SLASH_NAME)
	if slashTemplate then
		local slash = slashTemplate:Clone()
		slash.Name   = SLASH_NAME
		slash.Parent = character
		slash.CFrame = rootPart.CFrame
		local weld   = Instance.new("WeldConstraint")
		weld.Part0   = rootPart
		weld.Part1   = slash
		weld.Parent  = slash
	end

	-- Shield (щит)
	local shield        = shieldTemplate:Clone()
	shield.Name         = SHIELD_NAME
	shield.Parent       = character
	shield.Transparency = 1
	shield.CFrame       = rootPart.CFrame
	local weld          = Instance.new("WeldConstraint")
	weld.Part0          = rootPart
	weld.Part1          = shield
	weld.Parent         = shield
end

-- —писок живых персонажей игроков (без ботов)
function PlayerSystem.getAlivePlayers(excludeChar)
	local result = {}
	for _, plr in pairs(game.Players:GetPlayers()) do
		if plr.Character and plr.Character ~= excludeChar then
			local hum  = plr.Character:FindFirstChild("Humanoid")
			local root = plr.Character:FindFirstChild("HumanoidRootPart")
			if hum and root and hum.Health > 0 then
				table.insert(result, plr.Character)
			end
		end
	end
	return result
end

-- ќбработка блока / смерти игрока
-- getNearestTargetFn Ч функци€ из GameManager (чтобы не было цикличных зависимостей)
function PlayerSystem.processPlayerBlock(State, Config, distance, event, VFXSystem, getNearestTargetFn, abilityEvent, AbilitySystem)
	local plr = game.Players:GetPlayerFromCharacter(State.target)
	if not plr then return end

	local blockData = State.blockingPlayers[plr]

	-- јвтопаррирование
	if State.autoParryPlayers[plr] and distance <= Config.BLOCK_DISTANCE then
		blockData = {
			Dir         = State.playerCameraDir[plr] or Vector3.new(0, 0, 1),
			IsAutoParry = true,
			Time        = tick(),
		}
	end

	local isBlockActive = blockData and (tick() - blockData.Time <= Config.BLOCK_DURATION)

	-- ”спешный отбив
	if isBlockActive and distance <= Config.BLOCK_DISTANCE then
		VFXSystem.triggerBlockVFX(State.target)
		VFXSystem.clearShieldVFX(State.target)
		State.blockingPlayers[plr] = nil

		State.target       = getNearestTargetFn(State.target, State.ballLogicalPos)
		State.currentSpeed += Config.SPEED_ON_PARRY

		-- «акрутка в направлении камеры игрока
		if typeof(blockData.Dir) == "Vector3" then
			local targetRoot = State.target and State.target:FindFirstChild("HumanoidRootPart")
			if targetRoot then
				local toTarget = (targetRoot.Position - State.ballLogicalPos).Unit
				State.curveDirection = blockData.Dir.Unit:Lerp(toTarget, 0.3)
			end
		end

		-- ? ѕри успешном парировании Ч кулдауна Ќ≈“ (логика Blade Ball)
		--  улдаун только при промахе (м€ч не прилетел за 0.5с)
		State.playerCooldowns[plr] = nil

		-- ≈сли у игрока был активен Infinity Ч emit блок VFX на м€че
		if abilityEvent and AbilitySystem and AbilitySystem.isInfinityActive(plr) then
			abilityEvent:FireClient(plr, "InfinityBlockEmit")
		end

		event:FireClient(plr, "UpdateScore")
		return
	end

	-- —мерть Ч если Infinity активен, полностью пропускаем проверку убийства
	if AbilitySystem and AbilitySystem.isInfinityActive(plr) then return end

	if distance <= Config.KILL_DISTANCE and not Config.IS_PLAYER_IMMORTAL then
		local hum = State.target:FindFirstChild("Humanoid")
		-- —брасываем кулдаун и блок умершего игрока
		-- иначе после респавна он не сможет блокировать
		State.blockingPlayers[plr] = nil
		State.playerCooldowns[plr] = nil
		-- —брасываем состо€ние м€ча
		State.currentSpeed    = Config.BASE_SPEED
		State.ballLogicalPos  = Config.SPAWN_POINT
		State.curveDirection  = Vector3.new(0, 0, 1)
		State.currentVelocity = Vector3.new(0, 0, 1)
		State.target          = nil
		-- —ообщаем клиенту что можно блокировать
		event:FireClient(plr, "ResetCooldown")
		if hum then
			task.spawn(function() hum.Health = 0 end)
		end
		return
	end

	-- ѕромах Ч окно 0.5с истекло, м€ч не прилетел > 2с кулдаун
	if blockData and (tick() - blockData.Time > Config.BLOCK_DURATION) then
		State.blockingPlayers[plr] = nil
		State.playerCooldowns[plr] = tick() + Config.PARRY_COOLDOWN
		event:FireClient(plr, "ParryMissed", Config.PARRY_COOLDOWN)
	end
end

-- —тандартные части тела R6 Ч им нужна коллизи€ чтобы работали стены
local BODY_PARTS = {
	["HumanoidRootPart"] = true,
	["Head"]             = true,
	["Torso"]            = true,
	["Left Arm"]         = true,
	["Right Arm"]        = true,
	["Left Leg"]         = true,
	["Right Leg"]        = true,
}

--  оллизии Ч тело сталкиваетс€ со стенами, прикреплЄнные объекты (щит, слэш, аксессуары) Ч нет
function PlayerSystem.updateCollisions(playerGroup)
	local function applyGroup(char)
		for _, part in pairs(char:GetDescendants()) do
			if part:IsA("BasePart") then
				part.CollisionGroup = playerGroup
				-- “олько части тела получают CanCollide = true
				-- ¬се остальное (щиты, слэши, аксессуары) Ч выключено
				if BODY_PARTS[part.Name] then
					part.CanCollide = true
				else
					part.CanCollide = false
				end
			end
		end
	end
	for _, plr in pairs(game.Players:GetPlayers()) do
		if plr.Character then applyGroup(plr.Character) end
	end
end

return PlayerSystem