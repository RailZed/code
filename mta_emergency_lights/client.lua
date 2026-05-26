-- =====================================================================
-- Client — биндинг клавиш для переключения режимов
-- =====================================================================
--
-- Сам рендер живёт в render.lua + coronas.lua. Этот файл только ловит
-- нажатия и просит сервер переключить флаг режима на машине.
-- =====================================================================

local function requestToggle(modeName)
    local vehicle = getPedOccupiedVehicle(localPlayer)
    if not vehicle then return end
    if getVehicleController(vehicle) ~= localPlayer then return end
    if not getVehicleLights(vehicle) then
        if Config.announce then
            outputChatBox("[Мигалки] на этом транспорте мигалки не настроены", 255, 150, 0)
        end
        return
    end
    if not hasVehicleMode(vehicle, modeName) then
        if Config.announce then
            outputChatBox(("[Мигалки] режим '%s' недоступен для этой машины"):format(modeName),
                255, 150, 0)
        end
        return
    end
    triggerServerEvent("emergencyLights:toggleMode", localPlayer, vehicle, modeName)
end

local boundKeys = {}

addEventHandler("onClientResourceStart", resourceRoot, function()
    for key, modeName in pairs(Config.binds or {}) do
        local fn = function() requestToggle(modeName) end
        bindKey(key, "down", fn)
        boundKeys[key] = fn
    end

    -- Дублирующие команды
    addCommandHandler("els", function(_, modeName)
        requestToggle(modeName or "primary")
    end)
    addCommandHandler("siren", function()
        requestToggle("primary")
    end)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    for key, fn in pairs(boundKeys) do
        unbindKey(key, "down", fn)
    end
    boundKeys = {}
end)

-- Уведомление об изменении (от сервера)
addEvent("emergencyLights:notify", true)
addEventHandler("emergencyLights:notify", localPlayer, function(modeName, state)
    if not Config.announce then return end
    outputChatBox(
        ("[Мигалки] %s — %s"):format(modeName, state and "ВКЛ" or "выкл"),
        state and 0 or 200, state and 220 or 200, state and 255 or 0
    )
end)
