-- GameConstants (ModuleScript) | ServerScriptService/Modules/GameConstants

local GameConstants = {}

-- Мяч
GameConstants.BASE_SPEED     = 0    -- начальная скорость (studs/s)
GameConstants.ACCEL_INTERVAL = 0.001  -- каждые 0.001 сек
GameConstants.SPEED_INCREMENT = 0.12 -- прирост за каждый тик
GameConstants.SPEED_ON_PARRY = 0.25    -- +0.5 за каждое парирование

-- Кривая
GameConstants.CURVE_LERP     = 1 -- 2
GameConstants.CURVE_BLEND    = 0.6
GameConstants.CURVE_DIST_MIN = 12
GameConstants.CURVE_DIST_MAX = 52

-- Блок / убийство
GameConstants.BLOCK_DISTANCE  = 12
GameConstants.KILL_DISTANCE   = 3 -- 3.75
GameConstants.BLOCK_DURATION  = 0.5
GameConstants.PARRY_COOLDOWN  = 2

-- Бот
GameConstants.BOT_NAME        = "Bot_1"
GameConstants.BOT_BLOCK_DIST  = 12
GameConstants.BOT_BLOCK_DELAY = 0.05 -- 0.05

-- Карта
GameConstants.FLOOR_Y         = 2.25
GameConstants.SPAWN_POINT     = Vector3.new(0, 4, 0)

-- Флаги
GameConstants.IS_PLAYER_IMMORTAL = false
GameConstants.IS_BOT_AUTO_BLOCK  = true

-- Коллизии
GameConstants.PLAYER_GROUP    = "PlayersGroup"

return GameConstants