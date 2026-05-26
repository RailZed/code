-- =====================================================================
-- Client — бинды, состояние, диагностика
-- =====================================================================
--
-- Все сообщения в чат — БЕЗУСЛОВНЫЕ (не зависят от Config.announce),
-- чтобы при поломке пользователь видел ровно где обрывается цепочка.
-- =====================================================================

local localState = setmetatable({}, { __mode = "k" })

local function chat(text, r, g, b)
    outputChatBox("[ELS] " .. text, r or 200, g or 220, b or 255)
end

function getActiveModes(veh)
    if not isElement(veh) then return nil end
    local synced = getElementData(veh, "vehicle:els:modes")
    if type(synced) == "table" and next(synced) ~= nil then
        return synced
    end
    return localState[veh]
end

local function setLocalMode(veh, modeName, state)
    if not localState[veh] then localState[veh] = {} end
    if state then
        localState[veh][modeName] = true
    else
        localState[veh][modeName] = nil
    end
end

local function getMyVehicle()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then return nil, "не в машине" end
    if getVehicleController(veh) ~= localPlayer then return nil, "не водитель" end
    return veh
end

local function requestToggle(modeName)
    local vehicle, reason = getMyVehicle()
    if not vehicle then
        chat("toggle: " .. reason, 255, 150, 0)
        return
    end

    if not hasVehicleMode(vehicle, modeName) then
        chat(("режим '%s' не настроен для этой модели"):format(modeName), 255, 150, 0)
        return
    end

    local cur = (localState[vehicle] and localState[vehicle][modeName]) and true or false
    local newState = not cur
    setLocalMode(vehicle, modeName, newState)

    triggerServerEvent("emergencyLights:toggleMode", localPlayer, vehicle, modeName, newState)

    chat(
        ("%s — %s (model=%d)"):format(modeName, newState and "ВКЛ" or "выкл",
            getElementModel(vehicle)),
        newState and 0 or 200, 220, newState and 255 or 0
    )
end

-- ----------------------------------------------------------------------
-- Биндинги
-- ----------------------------------------------------------------------

local boundKeys = {}

local function applyBinds()
    for key, modeName in pairs(Config.binds or {}) do
        local fn = function() requestToggle(modeName) end
        bindKey(key, "down", fn)
        boundKeys[key] = fn
    end
end

local function removeBinds()
    for key, fn in pairs(boundKeys) do
        unbindKey(key, "down", fn)
    end
    boundKeys = {}
end

-- ----------------------------------------------------------------------
-- Команды
-- ----------------------------------------------------------------------

local function cmdEls(_, modeName)
    requestToggle(modeName or "primary")
end

local function cmdInfo()
    chat("--- info ---", 255, 200, 0)
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then
        chat("ты не в машине", 255, 200, 0)
    else
        local model = getElementModel(veh)
        chat(("машина model=%d (%s)"):format(model, getVehicleName(veh) or "?"), 255, 200, 0)
        local hasCustom = isCustomLightModel(model)
        chat(("конфиг: %s"):format(hasCustom and "СВОЙ" or "GENERIC"), 255, 200, 0)

        local modes = getVehicleModes(veh)
        local list = {}
        if modes then
            for name in pairs(modes) do list[#list+1] = name end
        end
        chat(("режимы: %s"):format(#list > 0 and table.concat(list, ", ") or "—"),
            255, 200, 0)

        local active = getActiveModes(veh)
        local on = {}
        if active then
            for name, st in pairs(active) do
                if st then on[#on+1] = name end
            end
        end
        chat(("сейчас включено: %s"):format(
            #on > 0 and table.concat(on, ", ") or "ничего"), 255, 200, 0)
    end

    chat(("шейдер: %s | текстура: %s"):format(
        isShaderReady() and "ОК" or "НЕТ",
        isTextureReady() and "ОК" or "НЕТ"), 255, 200, 0)

    -- сколько бинд-keys удалось зарегистрировать
    local n = 0
    for _ in pairs(boundKeys) do n = n + 1 end
    chat(("биндов активно: %d"):format(n), 255, 200, 0)
end

local function cmdApply(_, modelArg)
    local model = tonumber(modelArg)
    if not model then
        local veh = getPedOccupiedVehicle(localPlayer)
        if veh then model = getElementModel(veh) end
    end
    if not model then
        chat("/elsapply <modelId>  — или сядь за руль", 255, 150, 0)
        return
    end
    addCustomLights(model, genericLights)
    chat(("generic-мигалки навешены на model %d"):format(model), 0, 220, 120)
end

local function cmdTest()
    local veh, reason = getMyVehicle()
    if not veh then
        chat("test: " .. (reason or "?"), 255, 150, 0)
        return
    end
    setLocalMode(veh, "primary", true)
    chat("primary включён ЛОКАЛЬНО (без сервера)", 0, 220, 120)
end

-- ----------------------------------------------------------------------
-- Старт/стоп
-- ----------------------------------------------------------------------

addEventHandler("onClientResourceStart", resourceRoot, function()
    applyBinds()
    addCommandHandler("els",      cmdEls)
    addCommandHandler("siren",    function() requestToggle("primary") end)
    addCommandHandler("elsinfo",  cmdInfo)
    addCommandHandler("elsapply", cmdApply)
    addCommandHandler("elstest",  cmdTest)

    chat("ресурс запущен. /elsinfo — диагностика. /elstest — пробный режим.",
        0, 220, 120)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    removeBinds()
end)
