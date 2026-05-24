-- =====================================================================
-- Custom buildings distance — клиентская часть
-- =====================================================================
--
-- Логика основана на классическом подходе IIYAMA (setLowLODElement),
-- но с фиксами FPS:
--   * engineSetModelLODDistance берётся из конфига (1500), а не 99000.
--   * Мелкие/прозрачные/исключённые модели НЕ дублируются.
--   * Создание LOD идёт чанками через корутину (нет фриза при старте).
--
-- Структура хранения:
--   resourcesData[res] = {
--     parent     = element,   -- родитель всех LOD'ов этого ресурса
--     lodObjects = {[obj]=lod},
--     coro       = coroutine,
--     timer      = timer,
--     stats      = {created=N, skipped=M},
--   }
-- =====================================================================

local resourcesData       = {}
local appliedModels       = {}
local excludeModelSet     = {}
local globalStats         = { created = 0, skipped = 0, models = 0, resources = 0 }

local function chatLog(r, g, b, fmt, ...)
    outputChatBox("[buildings-distance] " .. fmt:format(...), r, g, b)
end

local function dbg(fmt, ...)
    if Config.debug then
        outputDebugString("[buildings-distance] " .. fmt:format(...), 3)
    end
end

local function rebuildExclude()
    excludeModelSet = {}
    for _, id in ipairs(Config.excludeModels or {}) do
        excludeModelSet[id] = true
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
-- Model-level LOD limit
-- ----------------------------------------------------------------------

local function applyModelLOD(modelId)
    if type(modelId) ~= "number" or modelId <= 0 then return end
    if appliedModels[modelId] then return end
    if excludeModelSet[modelId] then return end
    if not engineSetModelLODDistance then return end

    local ok = pcall(engineSetModelLODDistance, modelId, Config.modelLODDistance, true)
    if not ok then
        engineSetModelLODDistance(modelId, Config.modelLODDistance)
    end
    appliedModels[modelId] = true
    globalStats.models = globalStats.models + 1
end

-- ----------------------------------------------------------------------
-- Создание LOD-клона для одного объекта
-- ----------------------------------------------------------------------

local function shouldSkip(object)
    if not isElement(object) then return true end
    if getElementType(object) ~= "object" then return true end

    local model = getElementModel(object)
    if excludeModelSet[model] then return true end

    if Config.skipTransparent and getElementAlpha(object) < 255 then
        return true
    end

    local scale = getObjectScale(object) or 1
    if scale < (Config.minScale or 1.0) then
        return true
    end

    return false
end

local function createLODFor(object, parentElement)
    if shouldSkip(object) then
        globalStats.skipped = globalStats.skipped + 1
        return nil
    end

    local model      = getElementModel(object)
    local x, y, z    = getElementPosition(object)
    local rx, ry, rz = getElementRotation(object)

    local lod = createObject(model, x, y, z, rx, ry, rz, true) -- true = low-LOD object
    if not lod then return nil end

    setElementParent(lod, parentElement)

    local interior = getElementInterior(object)
    if interior ~= 0 then setElementInterior(lod, interior) end
    local dimension = getElementDimension(object)
    if dimension ~= 0 then setElementDimension(lod, dimension) end
    if isElementDoubleSided(object) then setElementDoubleSided(lod, true) end

    local scale = getObjectScale(object) or 1
    if scale ~= 1 then setObjectScale(lod, scale) end

    if isObjectBreakable(object) then
        attachElements(lod, object)
        setObjectBreakable(lod, false)
    end

    setLowLODElement(object, lod)
    applyModelLOD(model)
    globalStats.created = globalStats.created + 1

    return lod
end

-- ----------------------------------------------------------------------
-- Корутина: обработка объектов одного ресурса чанками
-- ----------------------------------------------------------------------

local function processResourceCoroutine(res, parentElement, objects, lodMap)
    local budgetMs = math.max(1, Config.processBudgetMs or 2)
    local deadline = getTickCount() + budgetMs

    for i = 1, #objects do
        local obj = objects[i]
        if isElement(obj) and not lodMap[obj] then
            local lod = createLODFor(obj, parentElement)
            if lod then lodMap[obj] = lod end
        end

        if getTickCount() > deadline then
            coroutine.yield()
            deadline = getTickCount() + budgetMs
        end
    end
end

local function pumpResource(res)
    local data = resourcesData[res]
    if not data or not data.coro then return end

    if coroutine.status(data.coro) == "dead" then
        data.timer = nil
        return
    end

    local ok, err = coroutine.resume(data.coro)
    if not ok then
        outputDebugString("[buildings-distance] coroutine error: " .. tostring(err), 1)
        data.coro = nil
        return
    end

    if coroutine.status(data.coro) ~= "dead" then
        data.timer = setTimer(pumpResource, 50, 1, res)
    else
        data.timer = nil
        dbg("resource %s: done (created=%d, skipped=%d)",
            tostring(getResourceName(res) or "?"),
            globalStats.created, globalStats.skipped)
    end
end

-- ----------------------------------------------------------------------
-- Загрузка / выгрузка ресурса
-- ----------------------------------------------------------------------

local function loadResource(res, thisResourceRoot)
    if resourcesData[res] then return end
    if not thisResourceRoot or not isElement(thisResourceRoot) then return end

    local parent = createElement("buildingsLODParent")
    local lodMap = {}
    local allObjects = {}

    -- Берём объекты из всех .map в ресурсе
    local mapRoots = getElementsByType("map", thisResourceRoot)
    if mapRoots and #mapRoots > 0 then
        for i = 1, #mapRoots do
            local objs = getElementsByType("object", mapRoots[i])
            for j = 1, #objs do allObjects[#allObjects + 1] = objs[j] end
        end
    end

    -- А также object'ы, созданные скриптами ресурса напрямую под рутом
    do
        local objs = getElementsByType("object", thisResourceRoot)
        for j = 1, #objs do allObjects[#allObjects + 1] = objs[j] end
    end

    if #allObjects == 0 then
        destroyElement(parent)
        return
    end

    local data = {
        parent     = parent,
        lodObjects = lodMap,
        coro       = coroutine.create(processResourceCoroutine),
    }
    resourcesData[res] = data
    globalStats.resources = globalStats.resources + 1

    -- Стартуем корутину
    local ok = coroutine.resume(data.coro, res, parent, allObjects, lodMap)
    if coroutine.status(data.coro) ~= "dead" then
        data.timer = setTimer(pumpResource, 50, 1, res)
    end
end

local function unloadResource(res)
    local data = resourcesData[res]
    if not data then return end
    resourcesData[res] = nil

    if data.timer and isTimer(data.timer) then
        killTimer(data.timer)
    end

    if isElement(data.parent) then
        destroyElement(data.parent)  -- удалит весь LOD-дочерний слой одним махом
    end
end

-- ----------------------------------------------------------------------
-- Поломка / стриминг (как у IIYAMA — чтобы LOD скрывался когда основной объект сломан, и появлялся когда тот выгружается)
-- ----------------------------------------------------------------------

addEventHandler("onClientObjectBreak", root, function()
    local lod = getLowLODElement(source)
    if lod and isElement(lod) then
        setElementAlpha(lod, 0)
    end
end)

addEventHandler("onClientElementStreamOut", root, function()
    if getElementType(source) ~= "object" then return end
    if not isObjectBreakable(source) then return end
    local lod = getLowLODElement(source)
    if lod and isElement(lod) then
        setElementAlpha(lod, 255)
    end
end)

-- ----------------------------------------------------------------------
-- Старт ресурса / стоп ресурса
-- ----------------------------------------------------------------------

addEventHandler("onClientResourceStart", root, function(res)
    if res == resource then
        rebuildExclude()
        enforceFarClip()
        if Config.keepFarClipEnforced then
            setTimer(enforceFarClip, Config.enforceIntervalMs or 1000, 0)
        end

        -- Подгружаем уже стартовавшие ресурсы
        local resourceRoots = getElementsByType("resource")
        for i = 1, #resourceRoots do
            local rRoot = resourceRoots[i]
            local rName = getElementID(rRoot)
            if rName then
                local r = getResourceFromName(rName)
                if r and r ~= resource and getResourceState(r) == "running" then
                    loadResource(r, rRoot)
                end
            end
        end

        if Config.announceInChat then
            setTimer(function()
                chatLog(0, 220, 120,
                    "farClip=%d fog=%d modelLOD=%d | resources=%d models=%d created=%d skipped=%d",
                    Config.farClipDistance, Config.fogDistance, Config.modelLODDistance,
                    globalStats.resources, globalStats.models,
                    globalStats.created, globalStats.skipped)
                if globalStats.created == 0 then
                    chatLog(255, 200, 0,
                        "Ни одного LOD не создано — нет .map с объектами в других ресурсах.")
                end
            end, 8000, 1)
        end
    else
        if Config.applyOnResourceStart then
            loadResource(res, source)
        end
    end
end)

addEventHandler("onClientResourceStop", root, function(res)
    if res == resource then
        -- Чистим всё
        for r in pairs(resourcesData) do unloadResource(r) end
    else
        unloadResource(res)
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
    return true
end

function rebuildAllLODs()
    -- На случай если хочется пересоздать все LOD'ы с новыми фильтрами
    for r in pairs(resourcesData) do unloadResource(r) end
    globalStats = { created = 0, skipped = 0, models = 0, resources = 0 }
    appliedModels = {}
    rebuildExclude()

    local resourceRoots = getElementsByType("resource")
    for i = 1, #resourceRoots do
        local rRoot = resourceRoots[i]
        local rName = getElementID(rRoot)
        if rName then
            local r = getResourceFromName(rName)
            if r and r ~= resource and getResourceState(r) == "running" then
                loadResource(r, rRoot)
            end
        end
    end
end

function getBuildingsStatus()
    return {
        farClipDistance  = Config.farClipDistance,
        fogDistance      = Config.fogDistance,
        modelLODDistance = Config.modelLODDistance,
        minScale         = Config.minScale,
        resources        = globalStats.resources,
        models           = globalStats.models,
        created          = globalStats.created,
        skipped          = globalStats.skipped,
    }
end
