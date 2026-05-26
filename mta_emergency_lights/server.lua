-- =====================================================================
-- Server — синк включения мигалок другим игрокам
-- =====================================================================
--
-- Клиент стал authoritative: режимы переключаются у него локально.
-- Сюда он шлёт уже готовое состояние (modeName -> bool). Мы пишем
-- его в elementData с syncToOtherClients=true, чтобы другие игроки
-- тоже увидели мигалки.
--
-- Если в ACL запрещено setElementData — клиент всё равно увидит свои
-- мигалки (благодаря локальному состоянию), просто другие не увидят.
-- =====================================================================

local function getModes(vehicle)
    local t = getElementData(vehicle, "vehicle:els:modes")
    if type(t) ~= "table" then t = {} end
    return t
end

addEvent("emergencyLights:toggleMode", true)
addEventHandler("emergencyLights:toggleMode", root,
function(vehicle, modeName, newState)
    if not isElement(vehicle) or getElementType(vehicle) ~= "vehicle" then return end
    if getVehicleOccupant(vehicle, 0) ~= client then return end
    if type(modeName) ~= "string" or modeName == "" then return end

    local modes = getModes(vehicle)
    if newState then
        modes[modeName] = true
    else
        modes[modeName] = nil
    end
    setElementData(vehicle, "vehicle:els:modes", modes)
end)

addEventHandler("onVehicleRespawn", root, function()
    setElementData(source, "vehicle:els:modes", {})
end)
