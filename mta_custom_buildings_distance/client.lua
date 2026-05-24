-- =====================================================================
-- Custom buildings distance — клиентская часть
-- =====================================================================
--
-- Что мы делаем (по убыванию важности для видимости):
--
--   1. setElementStreamable(obj, false)
--      — снимает MTA-стримминг с КАЖДОГО кастомного `object`-элемента.
--        Это и есть то, чего не хватало: без этого MTA сам убирает
--        объект из сцены за ~300 м, и никакие LOD/far clip не помогут.
--
--   2. setFarClipDistance + setFogDistance
--      — растягиваем горизонт камеры. Без этого даже всегда-в-сцене
--        объект всё равно не нарисуется.
--
--   3. engineSetModelLODDistance(model, d, true)
--      — снимаем стоковый лимит 170 на конкретной модели.
--
-- FPS не страдает: ванильные `building`-элементы остаются с дефолтным
-- model LOD ~170, то есть весь Лос-Сантос по-прежнему отсекается на
-- 170 м. Видно далеко только то, что мы сами разрешили.
-- =====================================================================

local appliedModels      = {}     -- [modelId] = true
local streamedElements   = setmetatable({}, { __mode = "k" })  -- weak keys
local excludeSet         = {}
local totalModelsApplied = 0
local totalElementsSeen  = 0
local totalElementsForced= 0

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
-- Model-level LOD
-- ----------------------------------------------------------------------

local function applyModelLOD(modelId)
    if type(modelId) ~= "number" or modelId <= 0 then return false end
    if appliedModels[modelId] then return true end
    if excludeSet[modelId] then return false end
    if not engineSetModelLODDistance then return false end

    local ok, ret = pcall(engineSetModelLODDistance, modelId, Config.modelLODDistance, true)
    if not ok or ret == false then
        ok = engineSetModelLODDistance(modelId, Config.modelLODDistance)
    end
    if ok then
        appliedModels[modelId] = true
        totalModelsApplied = totalModelsApplied + 1
        dbg("model %d -> LOD %d", modelId, Config.modelLODDistance)
        return true
    end
    return false
end

-- ----------------------------------------------------------------------
-- Per-element: вырубаем MTA-стримминг (главный фикс)
-- ----------------------------------------------------------------------

local function forceAlwaysStreamed(el)
    if not isElement(el) then return false end
    if streamedElements[el] then return true end
    if excludeSet[getElementModel(el)] then return false end
    if not setElementStreamable then return false end

    if setElementStreamable(el, false) then
        streamedElements[el] = true
        totalElementsForced = totalElementsForced + 1
        return true
    end
    return false
end

-- ----------------------------------------------------------------------
-- Скан карты
-- ----------------------------------------------------------------------

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
            applyModelLOD(getElementModel(el))
            -- setElementStreamable имеет смысл только для object,
            -- ванильные building и так часть мира движка.
            if Config.forceObjectsAlwaysStreamed and et == "object" then
                forceAlwaysStreamed(el)
            end
        end
    end
    dbg("sweep: %d elements, %d models, %d forced",
        totalElementsSeen, totalModelsApplied, totalElementsForced)
end

-- ----------------------------------------------------------------------
-- Старт
-- ----------------------------------------------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    rebuildExclude()
    enforceFarClip()

    if not engineSetModelLODDistance then
        chatLog(255, 100, 0,
            "engineSetModelLODDistance недоступна — обнови MTA до 1.5.8+")
    end
    if Config.forceObjectsAlwaysStreamed and not setElementStreamable then
        chatLog(255, 100, 0,
            "setElementStreamable недоступна в этом MTA — кастомные объекты не покажутся дальше 300м")
    end

    if Config.applyOnResourceStart then
        applyAll()
    end

    setTimer(applyAll, 2000,  1)
    setTimer(applyAll, 5000,  1)
    setTimer(applyAll, 15000, 1)

    if Config.keepFarClipEnforced then
        setTimer(enforceFarClip, Config.enforceIntervalMs or 1000, 0)
    end

    setTimer(function()
        chatLog(0, 220, 120,
            "farClip=%d fog=%d modelLOD=%d target=%s | elements=%d models=%d forced=%d",
            Config.farClipDistance or 0,
            Config.fogDistance or 0,
            Config.modelLODDistance or 0,
            Config.target,
            totalElementsSeen,
            totalModelsApplied,
            totalElementsForced)
        if totalElementsSeen == 0 then
            chatLog(255, 200, 0,
                "Ни одного %s-элемента не найдено. Попробуй /blodtarget all.",
                Config.target)
        elseif totalElementsForced == 0 and Config.forceObjectsAlwaysStreamed then
            chatLog(255, 200, 0,
                "Ни одного объекта не зафорсили в сцену — возможно у тебя их нет как `object`. Попробуй /blodtarget all.")
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

        applyModelLOD(getElementModel(source))
        if Config.forceObjectsAlwaysStreamed and et == "object" then
            forceAlwaysStreamed(source)
        end
    end)
end

-- Ловим вновь созданные объекты (на любом клиенте)
addEventHandler("onClientElementCreate", root, function()
    local el = source
    local et = getElementType(el)
    if et ~= "object" and et ~= "building" then return end
    if Config.target == "object"   and et ~= "object"   then return end
    if Config.target == "building" and et ~= "building" then return end
    totalElementsSeen = totalElementsSeen + 1
    applyModelLOD(getElementModel(el))
    if Config.forceObjectsAlwaysStreamed and et == "object" then
        forceAlwaysStreamed(el)
    end
end)

-- ----------------------------------------------------------------------
-- API
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
    for id in pairs(appliedModels) do
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
    appliedModels = {}
    streamedElements = setmetatable({}, { __mode = "k" })
    totalModelsApplied = 0
    totalElementsForced = 0
    applyAll()
    return true
end

function setBuildingsForceStreamed(enabled)
    Config.forceObjectsAlwaysStreamed = (enabled == true) or (enabled == "on") or (enabled == "1")
    if Config.forceObjectsAlwaysStreamed then
        applyAll()
    else
        -- Вернуть нормальный стримминг
        for el in pairs(streamedElements) do
            if isElement(el) then
                setElementStreamable(el, true)
            end
        end
        streamedElements = setmetatable({}, { __mode = "k" })
        totalElementsForced = 0
    end
    return Config.forceObjectsAlwaysStreamed
end

function rescanBuildings()
    applyAll()
end

function getBuildingsStatus()
    return {
        farClipDistance         = Config.farClipDistance,
        fogDistance             = Config.fogDistance,
        modelLODDistance        = Config.modelLODDistance,
        target                  = Config.target,
        forceObjectsAlwaysStreamed = Config.forceObjectsAlwaysStreamed,
        elementsSeen            = totalElementsSeen,
        modelsApplied           = totalModelsApplied,
        elementsForced          = totalElementsForced,
    }
end
