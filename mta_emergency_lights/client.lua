-- =====================================================================
-- Emergency lights — клиентская часть
-- =====================================================================
--
-- Биндит клавишу Config.toggleKey. Если игрок сидит за рулём машины,
-- на которую можно повесить мигалки — отправляет на сервер событие
-- переключения. Сами сирены создаются на сервере (см. server.lua).
-- =====================================================================

local function onToggleKey()
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then return end
    if getVehicleController(vehicle) ~= localPlayer then return end
    triggerServerEvent("emergencyLights:toggle", localPlayer, vehicle)
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    local key = Config and Config.toggleKey or "lshift"
    bindKey(key, "down", onToggleKey)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    local key = Config and Config.toggleKey or "lshift"
    unbindKey(key, "down", onToggleKey)
end)

-- Команда /siren — альтернатива клавише
addCommandHandler("siren", function()
    onToggleKey()
end)
