-- =====================================================================
-- Custom buildings distance — клиентская часть
-- =====================================================================
--
-- ВАЖНО про две функции:
--   * setFarClipDistance(d)            — глобальный горизонт камеры.
--                                        БЕЗ этого никакой LOD не покажет
--                                        объект дальше 300 юнитов.
--   * engineSetModelLODDistance(m,d,t) — лимит конкретной модели.
--                                        Третий аргумент `true` снимает
--                                        стандартный потолок 170.
--
-- Сценарий «видно далеко + FPS не страдает»:
--   1) Поднимаем far clip до 1500.
--   2) Поднимаем LOD distance только у `object`-элементов.
--   3) Ванильные `building` остаются с дефолтным LOD ~170 — Лос-Сантос
--      сам себя оптимизирует.
-- =====================================================================

local applied            = {}    -- [modelId] = true
local excludeSet         = {}
local totalModelsApplied = 0
local totalElementsSeen  = 0

local function chatLog(r, g, b, fmt, ...)
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

-- ----------------------------------------------------------------------
-- Far clip + fog
-- ----------------------------------------------------------------------

local function enforceFarClip()
    if Config.farClipDistance and Config.farClipDistance > 0 then
        setFarClipDistance(Config.farClipDistance)
    end
    if Config.fogDistance and Config.fogDistance > 0 then
        setFogDistance(Config.fogDistance)
    end
end

-- ----------------------------------------------------------------------
-- Per-model LOD
-- ----------------------------------------------------------------------

local function applyModel(modelId)
    if type(modelId) ~= "number" or modelId <= 0 then return false end
    if applied[modelId] then return true end
    if excludeSet[modelId] then return false end
    if not engineSetModelLODDistance then return false end

    -- Третий аргумент `true` снимает лимит 170 (extendedRange).
    -- В старых MTA третьего аргумента нет — pcall защитит от падения.
    local ok, ret = pcall(engineSetModelLODDistance, modelId, Config.modelLODDistance, true)
    if not ok or ret == false then
        ok = engineSetModelLODDistance(modelId, Config.modelLODDistance)
    end

    if ok then
        applied[modelId] = true
        totalModelsApplied = totalModelsApplied + 1
        dbg("model %d -> LOD %d", modelId, Config.modelLODDistance)
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

-- ----------------------------------------------------------------------
-- Старт ресурса
-- ----------------------------------------------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    rebuildExclude()

    -- Сразу растягиваем горизонт — это даёт визуальный эффект мгновенно
    enforceFarClip()

    if not engineSetModelLODDistance then
        chatLog(255, 100, 0,
            "engineSetModelLODDistance недоступна — far clip поднят (%d), но дальние модели могут мерцать",
            Config.farClipDistance or 0)
    elseif Config.applyOnResourceStart then
        applyAll()
    end

    -- Повторные сканы — на случай, если объекты приходят позже
    setTimer(applyAll, 2000,  1)
    setTimer(applyAll, 5000,  1)
    setTimer(applyAll, 15000, 1)

    -- Периодически переустанавливаем far clip / fog, потому что
    -- погода и сторонние ресурсы их сбрасывают.
    if Config.keepFarClipEnforced then
        setTimer(enforceFarClip, Config.enforceIntervalMs or 1000, 0)
    end

    -- Отчёт в чат — чтобы было видно, что скрипт реально работает
    setTimer(function()
        chatLog(0, 220, 120,
            "farClip=%d fog=%d modelLOD=%d target=%s | elements=%d models=%d",
            Config.farClipDistance or 0,
            Config.fogDistance or 0,
            Config.modelLODDistance or 0,
            Config.target,
            totalElementsSeen,
            totalModelsApplied)
        if totalModelsApplied == 0 then
            chatLog(255, 200, 0,
                "Не нашёл ни одной модели для LOD. Попробуй /blodtarget all и /blodscan.")
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

-- ----------------------------------------------------------------------
-- API для команд / других ресурсов
-- ----------------------------------------------------------------------

function setBuildingsFarClip(distance)
    distance = tonumber(distance)
    if not distance then return false end
    Config.farClipDistance = distance
    Config.fogDistance = math.max(50, distance - 100)
    enforceFarClip()
    return true
end

function setBuildingsLOD(distance)
    distance = tonumber(distance)
    if not distance then return false end
    Config.modelLODDistance = distance
    for id in pairs(applied) do
        local ok = pcall(engineSetModelLODDistance, id, distance, true)
        if not ok then engineSetModelLODDistance(id, distance) end
    end
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

function getBuildingsStatus()
    return {
        farClipDistance  = Config.farClipDistance,
        fogDistance      = Config.fogDistance,
        modelLODDistance = Config.modelLODDistance,
        target           = Config.target,
        elementsSeen     = totalElementsSeen,
        modelsApplied    = totalModelsApplied,
    }
end
