-- =====================================================================
-- Server — переключение режимов через elementData
-- =====================================================================
--
-- Клиент шлёт ("vehicle", "modeName"). Сервер инвертирует флаг и кладёт
-- его в elementData "vehicle:els:modes" — этот ключ синкается на всех
-- игроков, и render.lua на каждом клиенте сразу подхватывает изменения.
-- =====================================================================

local function getModes(vehicle)
    local t = getElementData(vehicle, "vehicle:els:modes")
    if type(t) ~= "table" then t = {} end
    return t
end

addEvent("emergencyLights:toggleMode", true)
addEventHandler("emergencyLights:toggleMode", root, function(vehicle, modeName)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    if getVehicleOccupant(vehicle, 0) ~= client then return end
    if type(modeName) ~= "string" or modeName == "" then return end

    local modes = getModes(vehicle)
    local new   = not modes[modeName]
    modes[modeName] = new or nil   -- nil чтобы не копились ложные ключи
    setElementData(vehicle, "vehicle:els:modes", modes)

    triggerClientEvent(client, "emergencyLights:notify", client, modeName, new == true)
end)

-- Сбрасываем мигалки при респавне (иначе зомби-мигалки на пустой машине)
addEventHandler("onVehicleRespawn", root, function()
    setElementData(source, "vehicle:els:modes", {})
end)

addEventHandler("onVehicleExit", root, function(player, seat)
    -- ничего не делаем — если водитель вышел, мигалки могут продолжать гореть
end)
