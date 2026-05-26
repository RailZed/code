-- =====================================================================
-- Modes — анимации мигания
-- =====================================================================
--
-- Каждый "режим" — это таблица кадров. Анимация прокручивается по
-- кадрам через каждые `delay` миллисекунд (см. render.lua).
-- В каждом кадре указано: какие group-номера лампочек горят.
--
-- Пример кадра:  { [1] = true, [3] = true }  -- горят группы 1 и 3.
--
-- В lights.lua каждой лампочке назначена group. Тут мы и описываем
-- "цепочки" вспышек.
-- =====================================================================

-- Базовый "ELS"-режим: чередующиеся левая/правая стороны крыши + быстрые
-- двойные подмигивания. Используется на 596 (Premier) и совместимых.
local function premierMode()
    return {
        delay = 70,
        -- "right cluster" быстрая двойная вспышка
        { [1] = true, [3] = true, [4] = true },
        { },
        { [1] = true, [3] = true, [4] = true },
        { },
        { },
        -- "left cluster" быстрая двойная вспышка
        { [2] = true, [5] = true, [6] = true },
        { },
        { [2] = true, [5] = true, [6] = true },
        { },
        { },
    }
end

-- Простая "паника" — левая/правая, безостановочно
local function panicMode()
    return {
        delay = 110,
        { [1] = true },
        { [2] = true },
        { [1] = true },
        { [2] = true },
    }
end

-- Белый строб по крыше (group 7)
local function strobeMode()
    return {
        delay = 60,
        { [7] = true },
        { },
        { [7] = true },
        { },
        { },
        { },
    }
end

-- Передний "такдаун" — белые лампочки в бампере (group 3..6 у Premier;
-- для остальных моделей переиспользует те же группы, если они белые)
local function takedownMode()
    return {
        delay = 200,
        { [3] = true, [4] = true, [5] = true, [6] = true },
    }
end

-- Янтарные "стрелки" — последовательный бег слева-направо (группы 11-18)
local function arrowMode()
    return {
        delay = 90,
        { [11] = true, [12] = true },
        { [12] = true, [13] = true },
        { [13] = true, [14] = true },
        { [14] = true, [15] = true },
        { [15] = true, [16] = true },
        { [16] = true, [17] = true },
        { [17] = true, [18] = true },
        { [11] = true, [12] = true, [13] = true, [14] = true,
          [15] = true, [16] = true, [17] = true, [18] = true },
        { },
    }
end

-- ----------------------------------------------------------------------
-- Привязка режимов к моделям
-- ----------------------------------------------------------------------

local vehicleModes = {
    [596] = {
        primary   = premierMode(),
        secondary = strobeMode(),
        takedown  = takedownMode(),
        arrow     = arrowMode(),
    },
    [597] = {
        primary   = panicMode(),
        secondary = strobeMode(),
    },
    [598] = {
        primary   = panicMode(),
        secondary = strobeMode(),
    },
    [416] = {
        primary   = panicMode(),
        secondary = strobeMode(),
    },
    [407] = {
        primary   = panicMode(),
        secondary = strobeMode(),
    },
}

-- Каждой машине нужны *свои* счётчики анимации (last/index), иначе все
-- авто моргали бы синхронно. Поэтому при первом запросе клонируем
-- модочные данные на конкретный элемент.
local perVehicleModes = setmetatable({}, { __mode = "k" })

local function cloneModes(src)
    local dst = {}
    for name, def in pairs(src) do
        local frames = {}
        for i = 1, #def do
            frames[i] = def[i]
        end
        frames.delay = def.delay
        frames.index = 0
        frames.last  = 0
        dst[name] = frames
    end
    return dst
end

function getVehicleModes(veh)
    if not isElement(veh) then return nil end
    local cached = perVehicleModes[veh]
    if cached then return cached end

    local proto = vehicleModes[getElementModel(veh)]
    if not proto then return nil end

    local instance = cloneModes(proto)
    perVehicleModes[veh] = instance
    return instance
end

function hasVehicleMode(veh, modeName)
    local m = getVehicleModes(veh)
    return m and m[modeName] ~= nil
end
