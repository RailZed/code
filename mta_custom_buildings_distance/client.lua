-- =====================================================================
-- Автоматическое применение LOD distance к моделям объектов на карте
-- =====================================================================

local applied = {}   -- [modelId] = true, чтобы не дёргать движок повторно
local excludeSet = {}
local totalApplied = 0

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
    if type(modelId) ~= "number" or modelId <= 0 then return end
    if applied[modelId] then return end
    if excludeSet[modelId] then return end
    if not engineSetModelLODDistance then return end

    if engineSetModelLODDistance(modelId, Config.distance) then
        applied[modelId] = true
        totalApplied = totalApplied + 1
        dbg("model %d -> LOD %d", modelId, Config.distance)
    end
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
    for _, et in ipairs(targetTypes()) do
        for _, el in ipairs(getElementsByType(et)) do
            applyModel(getElementModel(el))
        end
    end
    dbg("initial sweep: %d unique models", totalApplied)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    rebuildExclude()
    if Config.applyOnResourceStart then
        applyAll()
    end
end)

if Config.applyOnStreamIn then
    addEventHandler("onClientElementStreamIn", root, function()
        local et = getElementType(source)
        if Config.target == "object"   and et ~= "object"  then return end
        if Config.target == "building" and et ~= "building" then return end
        if Config.target == "all" and et ~= "object" and et ~= "building" then return end
        applyModel(getElementModel(source))
    end)
end

-- Экспортируемое API на случай если другой ресурс захочет руками задать дистанцию
function setBuildingsDistance(distance)
    distance = tonumber(distance)
    if not distance then return false end
    Config.distance = distance
    -- Переприменяем ко всем уже обработанным моделям
    for id in pairs(applied) do
        engineSetModelLODDistance(id, distance)
    end
    -- И досканируем карту на случай новых моделей
    applyAll()
    return true
end
