-- =====================================================================
-- Client — бинды, состояние, диагностика
-- =====================================================================
--
-- Состояние мигалок хранится локально (localState). Это нужно чтобы
-- мигалки работали и на одиночном/тестовом сервере, где синк elementData
-- может отвалиться по правам.
--
-- Если сервер прислал свежий elementData "vehicle:els:modes" — он имеет
-- приоритет: так гарантируем что другие игроки видят то же, что и
-- водитель.
-- =====================================================================

local localState = setmetatable({}, { __mode = "k" })

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

-- ----------------------------------------------------------------------
-- Переключение
-- ----------------------------------------------------------------------

local function getMyVehicle()
    local veh = getPedOccupiedVehicle(localPlayer)
    if not veh then return nil end
    if getVehicleController(veh) ~= localPlayer then return nil end
    return veh
end

local function requestToggle(modeName)
    local vehicle = getMyVehicle()
    if not vehicle then
        if Config.announce then
            outputChatBox("[Мигалки] Сядь за руль", 255, 150, 0)
        end
        return
    end

    if not hasVehicleMode(vehicle, modeName) then
        if Config.announce then
            outputChatBox(("[Мигалки] Режим '%s' не настроен"):format(modeName),
                255, 150, 0)
        end
        return
    end

    -- Локально переключаем сразу — мгновенный отклик
    local current = (localState[vehicle] and localState[vehicle][modeName]) and true or false
    local newState = not current
    setLocalMode(vehicle, modeName, newState)

    -- Сервер пусть синканёт другим клиентам, но это не критично для рендера
    triggerServerEvent("emergencyLights:toggleMode", localPlayer, vehicle, modeName, newState)

    if Config.announce then
        outputChatBox(
            ("[Мигалки] %s — %s"):format(modeName, newState and "ВКЛ" or "выкл"),
            newState and 0 or 200, 220, newState and 255 or 0
        )
    end
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

-- /elsinfo — показать что вообще происходит
local function cmdInfo()
    local veh = getPedOccupiedVehicle(localPlayer)
    outputChatBox("--- ELS info ---", 255, 200, 0)

    if not veh then
        outputChatBox("Ты не в машине.", 255, 200, 0)
    else
        local model = getElementModel(veh)
        outputChatBox(("Машина: model=%d (%s)"):format(
            model, getVehicleName(veh) or "?"), 255, 200, 0)

        local hasCustom = isCustomLightModel(model)
        outputChatBox(("Конфиг для этой модели: %s"):format(
            hasCustom and "собственный" or "GENERIC (4 угла крыши)"),
            255, 200, 0)

        local modes = getVehicleModes(veh)
        local list = {}
        if modes then
            for name in pairs(modes) do list[#list+1] = name end
        end
        outputChatBox(("Доступные режимы: %s"):format(
            #list > 0 and table.concat(list, ", ") or "—"), 255, 200, 0)

        local active = getActiveModes(veh)
        local on = {}
        if active then
            for name, st in pairs(active) do
                if st then on[#on+1] = name end
            end
        end
        outputChatBox(("Сейчас включено: %s"):format(
            #on > 0 and table.concat(on, ", ") or "ничего"), 255, 200, 0)
    end

    -- Шейдер
    outputChatBox(("Шейдер: %s | текстура: %s"):format(
        isShaderReady() and "ОК" or "НЕ ЗАГРУЖЕН",
        isTextureReady() and "ОК" or "НЕ ЗАГРУЖЕНА"),
        255, 200, 0)
end

-- /elsapply [modelId] — добавить generic-конфиг для текущей или указанной
-- модели машины (на клиенте, без серверного синка)
local function cmdApply(_, modelArg)
    local model = tonumber(modelArg)
    if not model then
        local veh = getPedOccupiedVehicle(localPlayer)
        if veh then model = getElementModel(veh) end
    end
    if not model then
        outputChatBox("[ELS] /elsapply <modelId>  — или сядь за руль", 255, 150, 0)
        return
    end
    addCustomLights(model, genericLights)
    outputChatBox(("[ELS] Generic-мигалки навешены на model %d"):format(model),
        0, 220, 120)
end

-- /elstest — для текущей машины включить primary насильно
local function cmdTest()
    local veh = getMyVehicle()
    if not veh then
        outputChatBox("[ELS] Сядь за руль для /elstest", 255, 150, 0)
        return
    end
    setLocalMode(veh, "primary", true)
    outputChatBox("[ELS] primary включён локально", 0, 220, 120)
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
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    removeBinds()
end)
