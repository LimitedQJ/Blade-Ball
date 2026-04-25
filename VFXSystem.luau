-- VFXSystem (ModuleScript) | ServerScriptService/Modules
-- Отвечает ТОЛЬКО за: визуальные эффекты (частицы, звуки, щиты)

local PLAYER_SLASH_NAME = "PlayerSlash"
local BOT_SLASH_NAME    = "Bot_1Slash"

local VFXSystem = {}

-- Получить handle эффекта удара (работает и для игрока и для бота)
local function getSlashHandle(character)
	return character:FindFirstChild(PLAYER_SLASH_NAME)
		or character:FindFirstChild(BOT_SLASH_NAME)
end

-- VFX блока / парирования (частицы + звук)
function VFXSystem.triggerBlockVFX(character)
	local handle = getSlashHandle(character)
	if not handle then return end

	local snd = handle:FindFirstChild("Ninja Slash")
	if snd then snd:Play() end

	for _, emitter in pairs(handle:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			local emitCount    = emitter:GetAttribute("EmitCount")    or 0
			local delayEmit    = emitter:GetAttribute("DelayEmit")    or 0
			local durationEmit = emitter:GetAttribute("DurationEmit") or 0

			-- Немедленный выброс
			if emitCount > 0 then
				emitter:Emit(emitCount)
			end

			-- Отложенный выброс
			if delayEmit > 0 then
				task.delay(delayEmit, function()
					emitter:Emit(emitCount)
				end)
			end

			-- Длительный выброс
			if durationEmit > 0 then
				task.spawn(function()
					local elapsed  = 0
					local rate     = emitCount / durationEmit
					while elapsed < durationEmit do
						task.wait(0.1)
						elapsed += 0.1
						emitter:Emit(math.floor(rate * 0.1))
					end
				end)
			end
		end
	end
end

-- Активация щита (частицы)
function VFXSystem.triggerShieldEmit(character)
	local shield = character:FindFirstChild("PlayerShieldInstance")
	if not shield then return end
	for _, emitter in pairs(shield:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter:Emit(emitter:GetAttribute("EmitCount") or 0)
		end
	end
end

-- Сброс частиц щита (после успешного блока)
function VFXSystem.clearShieldVFX(character)
	local shield = character:FindFirstChild("PlayerShieldInstance")
	if not shield then return end
	for _, emitter in pairs(shield:GetDescendants()) do
		if emitter:IsA("ParticleEmitter") then
			emitter:Clear()
		end
	end
end

return VFXSystem