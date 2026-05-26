-- =====================================================================
-- Render — поиск активных машин, расчёт оффсетов, отрисовка
-- =====================================================================

local getMatrix   = getElementMatrix
local getTickCount = getTickCount

-- ----------------------------------------------------------------------
-- Утилиты
-- ----------------------------------------------------------------------

local function angleDiff(a, b)
    local d = (a - b) % 360
    if d > 180 then d = d - 360 end
    return d
end

local function isInAngle(current, angles)
    if not angles then return true end
    for i = 1, #angles do
        local v = angles[i]
        if current >= v[1] and current <= v[2] then
            return true
        end
    end
    return false
end

-- offset point через матрицу машины -> мировые координаты
local function applyOffset(m, ox, oy, oz)
    local x = ox * m[1][1] + oy * m[2][1] + oz * m[3][1] + m[4][1]
    local y = ox * m[1][2] + oy * m[2][2] + oz * m[3][2] + m[4][2]
    local z = ox * m[1][3] + oy * m[2][3] + oz * m[3][3] + m[4][3]
    return x, y, z
end

-- ----------------------------------------------------------------------
-- Рисуем все активные лампочки одной машины
-- ----------------------------------------------------------------------

local function drawVehicleLights(veh)
    local lightSet = getVehicleLights(veh)
    if not lightSet then return end

    local modes = getVehicleModes(veh)
    if not modes then return end

    local activeModes = getActiveModes(veh)
    if type(activeModes) ~= "table" then return end

    -- Хоть один режим включён?
    local anyActive = false
    for _, on in pairs(activeModes) do
        if on then anyActive = true; break end
    end
    if not anyActive then return end

    if veh == getPedOccupiedVehicle(localPlayer) and not Config.drawForDriver then
        return
    end

    local m = getMatrix(veh)
    if not m then return end

    local _, _, rz  = getElementRotation(veh)
    local _, _, crz = getElementRotation(getCamera())
    local relAngle  = angleDiff(crz, rz)

    local tick = getTickCount()

    -- Прокручиваем кадры всех включённых режимов
    for name, mode in pairs(modes) do
        if activeModes[name] then
            if (mode.last or 0) < tick then
                mode.last  = tick + (mode.delay or 100)
                mode.index = (mode.index or 0) + 1
                if mode.index > #mode then mode.index = 1 end
            end
        end
    end

    -- Сначала "blasts" (большие гало), потом "lights" (точечные)
    for pass = 1, 2 do
        local list = (pass == 1) and lightSet.blasts or lightSet.lights
        if list then
            local drawn = {}
            for name, mode in pairs(modes) do
                if activeModes[name] and mode.index and mode[mode.index] then
                    local frame = mode[mode.index]
                    for i = 1, #list do
                        local d = list[i]
                        if not drawn[i] then
                            local pos    = d[1]
                            local color  = d[2]
                            local size   = d[3]
                            local group  = d[4] or 1
                            local angles = d[5]
                            if frame[group] and isInAngle(relAngle, angles) then
                                local wx, wy, wz = applyOffset(m, pos[1], pos[2], pos[3])
                                queueCorona(wx, wy, wz, size, color)
                                drawn[i] = true
                            end
                        end
                    end
                end
            end
        end
    end
end

-- ----------------------------------------------------------------------
-- Главный рендер-цикл
-- ----------------------------------------------------------------------

local function onRender()
    local vehicles = getElementsByType("vehicle", root, true) -- streamed-in
    for i = 1, #vehicles do
        drawVehicleLights(vehicles[i])
    end
    drawCoronas()
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    addEventHandler("onClientPreRender", root, onRender)
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    removeEventHandler("onClientPreRender", root, onRender)
end)
