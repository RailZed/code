-- =====================================================================
-- Emergency lights — серверная часть
-- =====================================================================
--
-- Вешает кастомные сирены (мигалки) на машины из Config.vehicleModels
-- и слушает запрос клиента на переключение.
--
-- API MTA:
--   addVehicleSirens(vehicle, count, type, 360, los, randomiser, silent)
--   setVehicleSirens(vehicle, idx, x, y, z, r, g, b, a, minAlpha)
--   setVehicleSirensOn(vehicle, bool)
-- =====================================================================

local applied = setmetatable({}, { __mode = "k" })  -- [vehicle] = true

local function dbg(fmt, ...)
    if Config.debug then
        outputDebugString("[emergency_lights] " .. fmt:format(...), 3)
    end
end

local function isEligible(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then
        return false
    end
    if Config.applyToAll then return true end
    return Config.vehicleModels[getElementModel(vehicle)] == true
end

local function applySirens(vehicle)
    if applied[vehicle] then return end
    if not isEligible(vehicle) then return end

    local count = math.min(#Config.lights, 8)
    if count < 1 then return end

    local ok = addVehicleSirens(
        vehicle, count, Config.sirenType,
        Config.use360, Config.useLOSCheck,
        Config.useRandomiser, Config.silent
    )
    if not ok then
        dbg("addVehicleSirens failed for model %d", getElementModel(vehicle))
        return
    end

    for i, light in ipairs(Config.lights) do
        if i > 8 then break end
        setVehicleSirens(
            vehicle, i,
            light[1], light[2], light[3],   -- x, y, z
            light[4], light[5], light[6],   -- r, g, b
            light[7], light[8]              -- alpha, minAlpha
        )
    end

    if Config.autoTurnOn then
        setVehicleSirensOn(vehicle, true)
    end

    applied[vehicle] = true
    dbg("sirens attached to vehicle model=%d", getElementModel(vehicle))
end

-- ----------------------------------------------------------------------
-- Старт: обработать всё, что уже есть на карте
-- ----------------------------------------------------------------------

addEventHandler("onResourceStart", resourceRoot, function()
    for _, v in ipairs(getElementsByType("vehicle")) do
        applySirens(v)
    end
end)

-- ----------------------------------------------------------------------
-- Новые машины + респавн
-- ----------------------------------------------------------------------

if Config.autoApply then
    addEventHandler("onElementCreate", root, function()
        if getElementType(source) == "vehicle" then
            applySirens(source)
        end
    end)

    addEventHandler("onVehicleRespawn", root, function()
        applied[source] = nil
        applySirens(source)
    end)
end

-- ----------------------------------------------------------------------
-- Переключение от клиента (водитель нажал клавишу)
-- ----------------------------------------------------------------------

addEvent("emergencyLights:toggle", true)
addEventHandler("emergencyLights:toggle", root, function(vehicle)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    if getVehicleOccupant(vehicle, 0) ~= client then return end
    if not isEligible(vehicle) then return end

    if not applied[vehicle] then
        applySirens(vehicle)
    end

    local on = not getVehicleSirensOn(vehicle)
    setVehicleSirensOn(vehicle, on)

    if Config.announce then
        outputChatBox(
            "[Мигалки] " .. (on and "включены" or "выключены"),
            client, on and 0 or 200, on and 200 or 200, on and 255 or 0
        )
    end
end)

-- ----------------------------------------------------------------------
-- API для других ресурсов
-- ----------------------------------------------------------------------

function attachEmergencyLights(vehicle)
    applied[vehicle] = nil
    applySirens(vehicle)
    return applied[vehicle] == true
end

function setEmergencyLights(vehicle, on)
    if not isElement(vehicle) then return false end
    if not applied[vehicle] then applySirens(vehicle) end
    return setVehicleSirensOn(vehicle, on and true or false)
end
