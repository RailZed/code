-- =====================================================================
-- Автоматическое применение LOD distance к моделям объектов на карте
-- =====================================================================
--
-- ВАЖНО: engineSetModelLODDistance БЕЗ третьего аргумента `true`
-- обрезает значение до 170 (стандартный лимит SA). Поэтому без
-- extendedRange ничего визуально не менялось. Третий параметр
-- `true` разрешает выйти за этот лимит — это и есть фикс.
-- =====================================================================

local applied  = {}      -- [modelId] = true
local excludeSet = {}
local totalModelsApplied = 0
local totalElementsSeen  = 0

local function notify(r, g, b, fmt, ...)
    outputChatBox("[buildings-distance] " .. fmt:format(...), r, g, b)
end

local function dbg(fmt, ...)
    if Config.debug then
        outputDebugString("[buildings-distance] " .. fmt:format(...), 3)
    end
end

local function rebuildExclude()
    excludeSet = {}
    for _, id in ipairs(Config.exclude or {}) do
        excludeSet[id] = true
    end
end

local function applyModel(modelId)
    if type(modelId) ~= "number" or modelId <= 0 then return false end
    if applied[modelId] then return true end
    if excludeSet[modelId] then return false end
    if not engineSetModelLODDistance then return false end

    -- Третий аргумент `true` — extendedRange (обходим лимит 170).
    -- Если функция не поддерживает 3-й аргумент (очень старый MTA),
    -- pcall защитит от падения и мы упадём в фолбэк.
    local ok, ret = pcall(engineSetModelLODDistance, modelId, Config.distance, true)
    if not ok or ret == false then
        -- Фолбэк: вызов без extendedRange — значение будет clamp'нуто,
        -- но хотя бы не упадёт. Обнови MTA до 1.5.8+, чтобы работало по-настоящему.
        ok = engineSetModelLODDistance(modelId, Config.distance)
    end

    if ok then
        applied[modelId] = true
        totalModelsApplied = totalModelsApplied + 1
        dbg("model %d -> LOD %d", modelId, Config.distance)
        return true
    end
    return false
end

local function targetTypes()
    if Config.target == "all" then
        return { "object", "building" }
    elseif Config.target == "building" then
        return { "building" }
    else
        return { "object" }
    end
end

local function applyAll()
    totalElementsSeen = 0
    for _, et in ipairs(targetTypes()) do
        for _, el in ipairs(getElementsByType(et)) do
            totalElementsSeen = totalElementsSeen + 1
            applyModel(getElementModel(el))
        end
    end
    dbg("sweep: %d elements, %d unique models", totalElementsSeen, totalModelsApplied)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    rebuildExclude()

    if not engineSetModelLODDistance then
        notify(255, 0, 0, "engineSetModelLODDistance недоступна — обнови MTA")
        return
    end

    if Config.applyOnResourceStart then
        applyAll()
    end

    -- Несколько повторных сканов: объекты из других ресурсов могут
    -- появиться чуть позже стартового тика.
    setTimer(applyAll, 2000,  1)
    setTimer(applyAll, 5000,  1)
    setTimer(applyAll, 15000, 1)

    -- Покажем итог в чат, чтобы было видно, что скрипт реально отработал
    setTimer(function()
        notify(0, 220, 120,
            "distance=%d, target=%s, elements=%d, models=%d",
            Config.distance, Config.target, totalElementsSeen, totalModelsApplied)
        if totalModelsApplied == 0 then
            notify(255, 200, 0,
                "Ни одной модели не найдено. Попробуй /blodtarget all, или проверь что объекты заспавнены.")
        end
    end, 5500, 1)
end)

if Config.applyOnStreamIn then
    addEventHandler("onClientElementStreamIn", root, function()
        local et = getElementType(source)
        local want = Config.target
        if want == "object"   and et ~= "object"   then return end
        if want == "building" and et ~= "building" then return end
        if want == "all" and et ~= "object" and et ~= "building" then return end
        applyModel(getElementModel(source))
    end)
end

-- =====================================================================
-- Публичное API
-- =====================================================================

function setBuildingsDistance(distance)
    distance = tonumber(distance)
    if not distance then return false end
    Config.distance = distance
    -- Переприменяем ко всем обработанным
    for id in pairs(applied) do
        local ok, _ = pcall(engineSetModelLODDistance, id, distance, true)
        if not ok then engineSetModelLODDistance(id, distance) end
    end
    -- И досканируем
    applyAll()
    return true
end

function setBuildingsTarget(target)
    if target ~= "object" and target ~= "building" and target ~= "all" then
        return false
    end
    Config.target = target
    applied = {}
    totalModelsApplied = 0
    applyAll()
    return true
end

function rescanBuildings()
    applyAll()
end
