-- =====================================================================
-- Coronas — очередь и батчевый рендер через DX-шейдер
-- =====================================================================
--
-- Идея:
--   render.lua за кадр собирает все видимые лампочки (queueCorona),
--   а в конце кадра drawCoronas() заливает их пачками по 12 штук в
--   шейдер data/corona.fx и рендерит одним вызовом dxDrawMaterialLine3D.
--
-- Этот батчинг — главное, почему ELS не сажает FPS: за 1 материал-вызов
-- отрисовывается 12 корон, а не по одной на каждую лампочку.
-- =====================================================================

local coronas    = {}
local coronaTxt  = nil
local shader     = nil

local function ensureShader()
    if not coronaTxt then
        coronaTxt = dxCreateTexture("data/blast.png")
    end
    if not shader or not isElement(shader) then
        shader = dxCreateShader("data/corona.fx")
        if shader and coronaTxt then
            dxSetShaderValue(shader, "gCoronaTexture", coronaTxt)
            dxSetShaderValue(shader, "drawSize", Config.shaderDrawSize or 50)
        end
    end
    return shader ~= nil
end

addEventHandler("onClientResourceStart", resourceRoot, function()
    ensureShader()
    if Config.debug then
        outputDebugString("[emergency_lights] shader ok: " .. tostring(shader ~= nil), 3)
    end
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isElement(shader) then destroyElement(shader) end
    if isElement(coronaTxt) then destroyElement(coronaTxt) end
end)

-- ----------------------------------------------------------------------
-- API: добавить корону в очередь
-- ----------------------------------------------------------------------
function queueCorona(x, y, z, size, color)
    coronas[#coronas + 1] = {
        x, y, z,
        color[1], color[2], color[3], color[4] or 255,
        size = size,
    }
end

-- ----------------------------------------------------------------------
-- Локальные шорткаты (минус JIT-промахи)
-- ----------------------------------------------------------------------
local dxSetShaderValue       = dxSetShaderValue
local dxDrawMaterialLine3D   = dxDrawMaterialLine3D
local getScreenFromWorldPosition = getScreenFromWorldPosition
local getDistanceBetweenPoints3D = getDistanceBetweenPoints3D
local getCameraMatrix        = getCameraMatrix
local getFarClipDistance     = getFarClipDistance

-- Буферы для шейдер-констант (12 корон = 3 "линии" по 4 точки)
local renderPos   = { [0] = {}, [1] = {}, [2] = {} }
local renderColor = { [0] = {}, [1] = {}, [2] = {} }

local function zeroBuffers()
    for line = 0, 2 do
        local p, c = renderPos[line], renderColor[line]
        for i = 1, 16 do p[i] = 0; c[i] = 0 end
    end
end

-- ----------------------------------------------------------------------
-- Слив очереди в шейдер
-- ----------------------------------------------------------------------
function drawCoronas()
    if not ensureShader() then
        coronas = {}
        return
    end

    local cx, cy, cz = getCameraMatrix()
    dxSetShaderValue(shader, "drawPos",  cx, cy, cz)
    dxSetShaderValue(shader, "farClip",  getFarClipDistance())

    local maxDist = Config.maxDrawDistance or 250

    local renderIndex = 0
    local pending     = false
    local vectorStart = Vector3(cx, cy, cz + 50)
    local vectorEnd   = Vector3(cx, cy, cz - 50)
    local vectorFace  = Vector3(cx, cy + 1, cz)

    zeroBuffers()

    local count = #coronas
    for i = 1, count do
        local c = coronas[i]
        if c then
            local x, y, z = c[1], c[2], c[3]
            if getScreenFromWorldPosition(x, y, z, 0.1)
               and getDistanceBetweenPoints3D(x, y, z, cx, cy, cz) <= maxDist
            then
                local slot  = renderIndex % 4
                local line  = math.floor((renderIndex / 4)) % 3
                local index = slot * 4 + 1
                local p, col = renderPos[line], renderColor[line]
                p[index]     = x
                p[index + 1] = y
                p[index + 2] = z
                p[index + 3] = c.size
                col[index]     = c[4]
                col[index + 1] = c[5]
                col[index + 2] = c[6]
                col[index + 3] = c[7]
                renderIndex = renderIndex + 1
                pending = true
            end
        end

        -- Каждые 12 корон или на последней итерации — flush
        if pending and (renderIndex % 12 == 0 or i == count) then
            -- Добиваем пустыми, если не до конца
            while renderIndex % 12 ~= 0 do
                local slot  = renderIndex % 4
                local line  = math.floor((renderIndex / 4)) % 3
                local index = slot * 4 + 1
                local p, col = renderPos[line], renderColor[line]
                p[index]     = 0
                p[index + 1] = 0
                p[index + 2] = 0
                p[index + 3] = 0
                col[index]     = 0
                col[index + 1] = 0
                col[index + 2] = 0
                col[index + 3] = 0
                renderIndex = renderIndex + 1
            end

            dxSetShaderValue(shader, "coronaPos0",   renderPos[0])
            dxSetShaderValue(shader, "coronaColor0", renderColor[0])
            dxSetShaderValue(shader, "coronaPos1",   renderPos[1])
            dxSetShaderValue(shader, "coronaColor1", renderColor[1])
            dxSetShaderValue(shader, "coronaPos2",   renderPos[2])
            dxSetShaderValue(shader, "coronaColor2", renderColor[2])

            dxDrawMaterialLine3D(vectorStart, vectorEnd, shader, 100, 0xFFFFFFFF, vectorFace)

            zeroBuffers()
            pending = false
        end
    end

    coronas = {}
end
