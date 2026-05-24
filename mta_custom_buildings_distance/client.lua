-- =====================================================================
-- Custom buildings distance — режим «по ID»
-- =====================================================================
--
-- Работает ТОЛЬКО с model ID из Config.models. Всё остальное на карте
-- не трогаем — FPS остаётся как был.
--
-- Что делаем:
--   1. setFarClipDistance / setFogDistance — растягиваем горизонт.
--   2. Для каждого object на карте, чья модель есть в Config.models:
--        - создаём LOD-клон (setLowLODElement) — это и есть то, что
--          заставляет MTA рисовать его дальше 300 м.
--   3. engineSetModelLODDistance(model, Config.modelLODDistance, true)
--      только для этих model ID.
-- =====================================================================

local modelSet           = {}    -- [modelId] = true (из Config.models)
local lodClones          = setmetatable({}, { __mode = "k" })  -- [object] = lodObject
local appliedModels      = {}
local lodParent          = nil
local stats              = { created = 0, models = 0, missing = 0 }

local function chatLog(r, g, b, fmt, ...)
    outputChatBox("[buildings-distance] " .. fmt:format(...), r, g, b)
end

local function dbg(fmt, ...)
    if Config.debug then
        outputDebugString("[buildings-distance] " .. fmt:format(...), 3)
    end
end

local function rebuildModelSet()
    modelSet = {}
    for _, id in ipairs(Config.models or {}) do
        if type(id) == "number" and id > 0 then
            modelSet[id] = true
        end
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
-- Model-level LOD distance (для указанных в конфиге model ID)
-- ----------------------------------------------------------------------

local function applyModelLOD(modelId)
    if appliedModels[modelId] then return end
    if not engineSetModelLODDistance then return end

    local ok = pcall(engineSetModelLODDistance, modelId, Config.modelLODDistance, true)
    if not ok then
        engineSetModelLODDistance(modelId, Config.modelLODDistance)
    end
    appliedModels[modelId] = true
    stats.models = stats.models + 1
end

-- ----------------------------------------------------------------------
-- LOD-клон одного объекта
-- ----------------------------------------------------------------------

local function makeLOD(object)
    if not isElement(object) then return end
    if getElementType(object) ~= "object" then return end
    if lodClones[object] then return end

    local model = getElementModel(object)
    if not modelSet[model] then return end  -- не наш ID — игнорируем

    -- Лёгкий режим: не плодим клоны, опираемся только на
    -- engineSetModelLODDistance для самой модели.
    if not Config.useLODClones then
        applyModelLOD(model)
        return
    end

    -- Пропуск breakable — attachElements бьёт по FPS.
    if Config.skipBreakableLOD and isObjectBreakable(object) then
        applyModelLOD(model)
        return
    end

    local x, y, z    = getElementPosition(object)
    local rx, ry, rz = getElementRotation(object)

    local lod = createObject(model, x, y, z, rx, ry, rz, true)  -- low-LOD
    if not lod then return end

    if lodParent and isElement(lodParent) then
        setElementParent(lod, lodParent)
    end

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
    lodClones[object] = lod
    stats.created = stats.created + 1
end

-- ----------------------------------------------------------------------
-- Сканирование всех существующих object'ов
-- ----------------------------------------------------------------------

local function scanAll()
    if not next(modelSet) then return end
    for _, obj in ipairs(getElementsByType("object")) do
        makeLOD(obj)
    end
end

-- ----------------------------------------------------------------------
-- События стримминга / поломки (стандартная пара для LOD-клонов)
-- ----------------------------------------------------------------------

addEventHandler("onClientObjectBreak", root, function()
    local lod = getLowLODElement(source)
    if lod and lodClones[source] then
        setElementAlpha(lod, 0)
    end
end)

addEventHandler("onClientElementStreamOut", root, function()
    if getElementType(source) ~= "object" then return end
    if not isObjectBreakable(source) then return end
    local lod = getLowLODElement(source)
    if lod and lodClones[source] then
        setElementAlpha(lod, 255)
    end
end)

-- Ловим новые объекты, появившиеся после старта
if Config.applyOnStreamIn then
    addEventHandler("onClientElementStreamIn", root, function()
        if getElementType(source) ~= "object" then return end
        makeLOD(source)
    end)
end

addEventHandler("onClientElementCreate", root, function()
    if getElementType(source) ~= "object" then return end
    makeLOD(source)
end)

-- ----------------------------------------------------------------------
-- Старт ресурса
-- ----------------------------------------------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    rebuildModelSet()
    lodParent = createElement("buildingsLODParent")

    enforceFarClip()
    if Config.keepFarClipEnforced then
        setTimer(enforceFarClip, Config.enforceIntervalMs or 1000, 0)
    end

    if not next(modelSet) then
        chatLog(255, 200, 0,
            "Config.models пустой — впиши свои model ID в config.lua")
        return
    end

    -- Применим LOD distance ко всем заявленным model ID,
    -- даже если объекта пока нет на карте — модель станет «дальнобойной»
    -- сразу, как только заспавнится.
    for id in pairs(modelSet) do
        applyModelLOD(id)
    end

    if Config.applyOnResourceStart then
        scanAll()
        -- ещё пара проходов для ресурсов, которые стартуют позже
        setTimer(scanAll, 2000,  1)
        setTimer(scanAll, 5000,  1)
        setTimer(scanAll, 15000, 1)
    end

    if Config.announceInChat then
        setTimer(function()
            chatLog(0, 220, 120,
                "farClip=%d fog=%d modelLOD=%d | ids=%d models=%d created=%d",
                Config.farClipDistance, Config.fogDistance, Config.modelLODDistance,
                (function() local n=0 for _ in pairs(modelSet) do n=n+1 end return n end)(),
                stats.models, stats.created)
            if stats.created == 0 then
                chatLog(255, 200, 0,
                    "0 LOD создано — на карте нет ни одного object с указанными ID. Проверь Config.models.")
            end
        end, 6000, 1)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isElement(lodParent) then
        destroyElement(lodParent)
    end
end)

-- ----------------------------------------------------------------------
-- API
-- ----------------------------------------------------------------------

function addBuildingModel(modelId)
    modelId = tonumber(modelId)
    if not modelId then return false end
    if modelSet[modelId] then return true end
    modelSet[modelId] = true
    table.insert(Config.models, modelId)
    applyModelLOD(modelId)
    scanAll()
    return true
end

function removeBuildingModel(modelId)
    modelId = tonumber(modelId)
    if not modelId then return false end
    modelSet[modelId] = nil
    for i, id in ipairs(Config.models) do
        if id == modelId then table.remove(Config.models, i) break end
    end
    -- Удалим LOD'ы у объектов с этим ID
    for obj, lod in pairs(lodClones) do
        if isElement(obj) and getElementModel(obj) == modelId then
            setLowLODElement(obj, nil)
            if isElement(lod) then destroyElement(lod) end
            lodClones[obj] = nil
        end
    end
    return true
end

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

function rescanBuildings()
    scanAll()
end

function getBuildingsStatus()
    local idCount = 0
    for _ in pairs(modelSet) do idCount = idCount + 1 end
    return {
        farClipDistance  = Config.farClipDistance,
        fogDistance      = Config.fogDistance,
        modelLODDistance = Config.modelLODDistance,
        idsConfigured    = idCount,
        modelsApplied    = stats.models,
        lodCreated       = stats.created,
    }
end
