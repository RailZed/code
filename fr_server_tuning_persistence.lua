-- =======================================================================
-- == СОХРАНЕНИЕ ТЮНИНГА ДЛЯ F3-МАШИН
-- == Вставить этот код в КОНЕЦ fr_server.lua вашего ресурса freeroam
-- == (или подключить отдельным файлом в meta.xml как server-скрипт)
-- =======================================================================

local TUNING_FILE = "vehicle_tuning.json"
local tuningData = {}

local function loadTuning()
    if not fileExists(TUNING_FILE) then return end
    local f = fileOpen(TUNING_FILE, true)
    local size = fileGetSize(f)
    if size > 0 then
        tuningData = fromJSON(fileRead(f, size)) or {}
    end
    fileClose(f)
end

local function saveTuning()
    if fileExists(TUNING_FILE) then fileDelete(TUNING_FILE) end
    local f = fileCreate(TUNING_FILE)
    fileWrite(f, toJSON(tuningData))
    fileClose(f)
end

local function captureTuning(vehicle)
    if not isElement(vehicle) then return end
    local id = getElementData(vehicle, "vehicle:ID")
    if not id then return end
    local r1,g1,b1, r2,g2,b2, r3,g3,b3, r4,g4,b4 = getVehicleColor(vehicle, true)
    local hr, hg, hb = getVehicleHeadLightColor(vehicle)
    tuningData[tostring(id)] = {
        colors    = {r1,g1,b1, r2,g2,b2, r3,g3,b3, r4,g4,b4},
        headlight = {hr, hg, hb},
        upgrades  = getVehicleUpgrades(vehicle) or {},
        paintjob  = getVehiclePaintjob(vehicle) or 0
    }
    saveTuning()
end

local function applyTuningTo(vehicle)
    if not isElement(vehicle) then return end
    local id = getElementData(vehicle, "vehicle:ID")
    if not id then return end
    local t = tuningData[tostring(id)]
    if not t then return end
    if t.colors and #t.colors == 12 then
        setVehicleColor(vehicle, unpack(t.colors))
    end
    if t.headlight then
        setVehicleHeadLightColor(vehicle, t.headlight[1], t.headlight[2], t.headlight[3])
    end
    if t.paintjob then
        setVehiclePaintjob(vehicle, t.paintjob)
    end
    if t.upgrades then
        for _, upg in ipairs(t.upgrades) do
            addVehicleUpgrade(vehicle, upg)
        end
    end
end

addEventHandler("onResourceStart", resourceRoot, loadTuning)

-- Когда F3 ставит vehicle:ID на новую заспавненную машину — применяем тюнинг
addEventHandler("onElementDataChange", root,
    function(dataName, oldValue)
        if dataName ~= "vehicle:ID" then return end
        if getElementType(source) ~= "vehicle" then return end
        local newValue = getElementData(source, "vehicle:ID")
        if newValue and not oldValue then
            -- задержка, чтобы F3 успел применить собственные данные машины
            setTimer(applyTuningTo, 300, 1, source)
        end
    end
)

-- Оборачиваем тюнинг-функции — автоматически сохраняем состояние F3-машин
local _setVehicleColor = setVehicleColor
function setVehicleColor(vehicle, ...)
    local r = _setVehicleColor(vehicle, ...)
    if isElement(vehicle) and getElementData(vehicle, "vehicle:ID") then
        captureTuning(vehicle)
    end
    return r
end

local _setVehicleHeadLightColor = setVehicleHeadLightColor
function setVehicleHeadLightColor(vehicle, ...)
    local r = _setVehicleHeadLightColor(vehicle, ...)
    if isElement(vehicle) and getElementData(vehicle, "vehicle:ID") then
        captureTuning(vehicle)
    end
    return r
end

local _addVehicleUpgrade = addVehicleUpgrade
function addVehicleUpgrade(vehicle, ...)
    local r = _addVehicleUpgrade(vehicle, ...)
    if isElement(vehicle) and getElementData(vehicle, "vehicle:ID") then
        captureTuning(vehicle)
    end
    return r
end

local _removeVehicleUpgrade = removeVehicleUpgrade
function removeVehicleUpgrade(vehicle, ...)
    local r = _removeVehicleUpgrade(vehicle, ...)
    if isElement(vehicle) and getElementData(vehicle, "vehicle:ID") then
        captureTuning(vehicle)
    end
    return r
end

local _setVehiclePaintjob = setVehiclePaintjob
function setVehiclePaintjob(vehicle, ...)
    local r = _setVehiclePaintjob(vehicle, ...)
    if isElement(vehicle) and getElementData(vehicle, "vehicle:ID") then
        captureTuning(vehicle)
    end
    return r
end
