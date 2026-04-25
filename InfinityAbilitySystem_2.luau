-- InfinityAbilitySystem (ModuleScript) | ServerScriptService/GameManager/Modules/Abilities/InfinityAbilitySystem

local INFINITY = {
	ACTIVE_TIME    = 10,
	COOLDOWN       = 22,    -- starts AFTER ability ends
	SLOW_RADIUS    = 20,
	STOP_RADIUS    = 6,
	MIN_SPEED_MULT = 0.0,
}

local playerAbilities = {}
local AbilitySystem = {}

function AbilitySystem.initPlayer(player)
	playerAbilities[player] = {
		active      = false,
		endTime     = 0,
		cooldownEnd = 0,
	}
end

function AbilitySystem.removePlayer(player)
	playerAbilities[player] = nil
end

function AbilitySystem.tryActivateInfinity(player, abilityEvent)
	if not playerAbilities[player] then
		AbilitySystem.initPlayer(player)
	end

	local data = playerAbilities[player]
	local now  = tick()

	if now < data.cooldownEnd then return end
	if data.active then return end

	data.active      = true
	data.endTime     = now + INFINITY.ACTIVE_TIME
	data.cooldownEnd = now + INFINITY.ACTIVE_TIME + INFINITY.COOLDOWN

	abilityEvent:FireClient(player, "InfinityActivated", INFINITY.ACTIVE_TIME, INFINITY.COOLDOWN)

	task.delay(INFINITY.ACTIVE_TIME, function()
		if playerAbilities[player] and playerAbilities[player].active then
			AbilitySystem.deactivateInfinity(player, abilityEvent)
		end
	end)
end

function AbilitySystem.deactivateInfinity(player, abilityEvent)
	if not playerAbilities[player] then return end
	playerAbilities[player].active = false
	local remaining = math.max(0, playerAbilities[player].cooldownEnd - tick())
	abilityEvent:FireClient(player, "InfinityDeactivated", remaining)
end

function AbilitySystem.isInfinityActive(player)
	local data = playerAbilities[player]
	if not data then return false end
	return data.active and tick() < data.endTime
end

function AbilitySystem.getInfinityTimeLeft(player)
	local data = playerAbilities[player]
	if not data or not data.active then return 0 end
	return math.max(0, data.endTime - tick())
end

function AbilitySystem.getInfinitySpeedMult(player, ballPos, targetPos)
	if not AbilitySystem.isInfinityActive(player) then return 1.0 end

	local dist = (targetPos - ballPos).Magnitude

	if dist >= INFINITY.SLOW_RADIUS then
		return 1.0
	elseif dist <= INFINITY.STOP_RADIUS then
		return INFINITY.MIN_SPEED_MULT
	else
		local t = (dist - INFINITY.STOP_RADIUS) / (INFINITY.SLOW_RADIUS - INFINITY.STOP_RADIUS)
		return t * t
	end
end

function AbilitySystem.onPlayerRespawn(player, abilityEvent)
	if not playerAbilities[player] then
		AbilitySystem.initPlayer(player)
	else
		playerAbilities[player].active      = false
		playerAbilities[player].cooldownEnd = 0
		playerAbilities[player].endTime     = 0
	end
	abilityEvent:FireClient(player, "InfinityReset")
end

return AbilitySystem