-- =====================================================================
-- Применение LOD distance к кастомным моделям
-- =====================================================================

local applied = {}  -- [modelId] = distance, чтобы не дёргать движок повторно

local function dbg(fmt, ...)
    if Config.debug then
        outputDebugString("[buildings-distance] " .. fmt:format(...), 3)
    end
end

local function applyOne(entry)
    local id = entry.model
    if type(id) ~= "number" then return false end

    local distance = entry.distance or Config.defaultLODDistance

    -- Привязка отдельной LOD-модели, если она указана
    if entry.lodModel and type(entry.lodModel) == "number" then
        -- engineSetModelLODDistance применится и к LOD-модели тоже,
        -- иначе она исчезнет раньше основной.
        if engineSetModelLODDistance then
            engineSetModelLODDistance(entry.lodModel, distance)
        end
    end

    if not engineSetModelLODDistance then
        dbg("engineSetModelLODDistance недоступна в этой версии MTA")
        return false
    end

    local ok = engineSetModelLODDistance(id, distance)
    if ok then
        applied[id] = distance
        dbg("model %d -> LOD distance %d", id, distance)
    else
        dbg("не удалось применить LOD для model %d", id)
    end
    return ok
end

local function applyAll()
    for _, entry in ipairs(Config.models) do
        applyOne(entry)
    end
end

-- Старт ресурса
addEventHandler("onClientResourceStart", resourceRoot, function()
    if Config.applyOnResourceStart then
        applyAll()
    end
end)

-- Переприменяем, когда модель реально стримится в память
-- (на случай, если другой ресурс сбрасывает LOD при перезамене модели)
if Config.applyOnModelLoad then
    addEventHandler("onClientElementStreamIn", root, function()
        local el = source
        local et = getElementType(el)
        if et ~= "object" and et ~= "building" then return end
        local id = getElementModel(el)
        for _, entry in ipairs(Config.models) do
            if entry.model == id and applied[id] ~= (entry.distance or Config.defaultLODDistance) then
                applyOne(entry)
                break
            end
        end
    end)
end

-- Экспортируемое API, если другой ресурс захочет управлять списком динамически
function setBuildingLODDistance(modelId, distance)
    if type(modelId) ~= "number" then return false end
    distance = tonumber(distance) or Config.defaultLODDistance
    return applyOne({ model = modelId, distance = distance })
end
