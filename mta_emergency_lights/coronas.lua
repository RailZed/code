-- =====================================================================
-- Coronas — DX-шейдер очередь + fallback на dxDrawMaterialLine3D
-- =====================================================================

local coronas    = {}
local coronaTxt  = nil
local shader     = nil
local shaderErr  = nil
local triedShader = false

-- ----------------------------------------------------------------------
-- Инициализация ресурсов
-- ----------------------------------------------------------------------
local function ensureTexture()
    if isElement(coronaTxt) then return true end
    coronaTxt = dxCreateTexture("data/blast.png")
    if not coronaTxt then
        if Config.announce then
            outputChatBox("[ELS] Не удалось загрузить data/blast.png", 255, 80, 80)
        end
        return false
    end
    return true
end

local function ensureShader()
    if not ensureTexture() then return false end
    if isElement(shader) then return true end
    if triedShader and not shader then return false end
    triedShader = true

    local ok, err = dxCreateShader("data/corona.fx")
    if not ok then
        shader, shaderErr = nil, tostring(err)
        if Config.announce then
            outputChatBox(
                ("[ELS] Шейдер corona.fx не скомпилировался: %s"):format(shaderErr),
                255, 80, 80
            )
            outputChatBox("[ELS] Включаю fallback-рендер (без батчинга).", 255, 200, 0)
        end
        return false
    end
    shader = ok
    dxSetShaderValue(shader, "gCoronaTexture", coronaTxt)
    dxSetShaderValue(shader, "drawSize", Config.shaderDrawSize or 50)
    return true
end

function isShaderReady()  return isElement(shader) end
function isTextureReady() return isElement(coronaTxt) end

addEventHandler("onClientResourceStart", resourceRoot, function()
    ensureTexture()
    ensureShader()
end)

addEventHandler("onClientResourceStop", resourceRoot, function()
    if isElement(shader)    then destroyElement(shader) end
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
-- Шорткаты
-- ----------------------------------------------------------------------
local dxSetShaderValue           = dxSetShaderValue
local dxDrawMaterialLine3D       = dxDrawMaterialLine3D
local getScreenFromWorldPosition = getScreenFromWorldPosition
local getDistanceBetweenPoints3D = getDistanceBetweenPoints3D
local getCameraMatrix            = getCameraMatrix
local getFarClipDistance         = getFarClipDistance

local renderPos   = { [0] = {}, [1] = {}, [2] = {} }
local renderColor = { [0] = {}, [1] = {}, [2] = {} }

local function zeroBuffers()
    for line = 0, 2 do
        local p, c = renderPos[line], renderColor[line]
        for i = 1, 16 do p[i] = 0; c[i] = 0 end
    end
end

-- ----------------------------------------------------------------------
-- Fallback: рисуем каждую корону отдельным dxDrawMaterialLine3D с textuRE.
-- Медленнее, но не зависит от шейдера.
-- ----------------------------------------------------------------------
local function drawFallback()
    if not ensureTexture() then
        coronas = {}
        return
    end
    local cx, cy, cz = getCameraMatrix()
    local maxDist = Config.maxDrawDistance or 250
    for i = 1, #coronas do
        local c = coronas[i]
        local x, y, z = c[1], c[2], c[3]
        if getScreenFromWorldPosition(x, y, z, 0.1)
           and getDistanceBetweenPoints3D(x, y, z, cx, cy, cz) <= maxDist
        then
            local r, g, b, a = c[4], c[5], c[6], c[7]
            local color = tocolor(r, g, b, a)
            local size  = c.size * 2
            -- Простая билборд-линия "к камере"
            local dx, dy = cx - x, cy - y
            local len = math.sqrt(dx*dx + dy*dy)
            if len > 0 then dx, dy = dx/len, dy/len end
            local px, py = -dy, dx -- перпендикуляр в горизонтали
            dxDrawMaterialLine3D(
                x - px * size, y - py * size, z,
                x + px * size, y + py * size, z,
                coronaTxt, size * 2, color,
                x, y, z + 1
            )
        end
    end
    coronas = {}
end

-- ----------------------------------------------------------------------
-- Основной слив очереди
-- ----------------------------------------------------------------------
function drawCoronas()
    if #coronas == 0 then return end

    if not ensureShader() then
        return drawFallback()
    end

    local cx, cy, cz = getCameraMatrix()
    dxSetShaderValue(shader, "drawPos", cx, cy, cz)
    dxSetShaderValue(shader, "farClip", getFarClipDistance())

    local maxDist     = Config.maxDrawDistance or 250
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

        if pending and (renderIndex % 12 == 0 or i == count) then
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
