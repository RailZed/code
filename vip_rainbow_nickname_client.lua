-- =======================================================================
-- ==              VIP РАДУЖНЫЙ НИК НАД ГОЛОВОЙ (CLIENT)                ==
-- =======================================================================
-- Рисует ник игрока в 3D-пространстве над головой.
-- Для игроков с element data "vip:level" > 0 ник переливается радугой:
-- цвет каждой буквы вычисляется по HSV и сдвигается по времени,
-- создавая эффект бегущей волны.
--
-- VIP-уровни:
--   1 — радуга (классическая)
--   2 — радуга + золотая обводка
--   3 — радуга + золотая обводка + значок короны
-- =======================================================================

local RENDER_DISTANCE     = 40    -- метров, дальше ник не рисуется
local FADE_START_DISTANCE = 25    -- с этой дистанции начинает угасать
local HEIGHT_OFFSET       = 0.35  -- подъём над макушкой
local WAVE_SPEED          = 0.0015 -- скорость бегущей волны (циклов/мс)
local WAVE_LENGTH         = 6      -- длина волны в "буквах" (меньше = плотнее цвета)

-- =======================================================================
-- ==     HSV → RGB                                                     ==
-- =======================================================================

local function hsvToRgb(h, s, v)
    h = h % 1
    local i = math.floor(h * 6)
    local f = h * 6 - i
    local p = v * (1 - s)
    local q = v * (1 - f * s)
    local t = v * (1 - (1 - f) * s)
    local r, g, b = 0, 0, 0
    if     i == 0 then r, g, b = v, t, p
    elseif i == 1 then r, g, b = q, v, p
    elseif i == 2 then r, g, b = p, v, t
    elseif i == 3 then r, g, b = p, q, v
    elseif i == 4 then r, g, b = t, p, v
    elseif i == 5 then r, g, b = v, p, q
    end
    return math.floor(r * 255), math.floor(g * 255), math.floor(b * 255)
end

-- =======================================================================
-- ==     ВСПОМОГАТЕЛЬНЫЕ                                               ==
-- =======================================================================

local function getCameraDistanceTo(x, y, z)
    local cx, cy, cz = getCameraMatrix()
    local dx, dy, dz = x - cx, y - cy, z - cz
    return math.sqrt(dx*dx + dy*dy + dz*dz)
end

local function getFadeAlpha(distance)
    if distance >= RENDER_DISTANCE then return 0 end
    if distance <= FADE_START_DISTANCE then return 1 end
    return 1 - (distance - FADE_START_DISTANCE) / (RENDER_DISTANCE - FADE_START_DISTANCE)
end

local function drawOutlinedChar(char, x, y, color, scale, font, outlineColor)
    -- 4 прохода обводки
    for ox = -1, 1, 2 do
        for oy = -1, 1, 2 do
            dxDrawText(char, x + ox, y + oy, x + ox, y + oy,
                outlineColor, scale, font, "center", "center", false, false, false, true)
        end
    end
    dxDrawText(char, x, y, x, y, color, scale, font, "center", "center", false, false, false, true)
end

-- =======================================================================
-- ==     ОСНОВНАЯ ОТРИСОВКА                                            ==
-- =======================================================================

addEventHandler("onClientRender", root, function ()
    local time = getTickCount()
    local wavePhase = time * WAVE_SPEED

    for _, player in ipairs(getElementsByType("player", root, true)) do
        if player ~= localPlayer and not isPedDead(player) then
            local vipLevel = tonumber(getElementData(player, "vip:level")) or 0
            if vipLevel > 0 then
                local hx, hy, hz = getPedBonePosition(player, 8) -- bone 8 = head
                if hx then
                    local distance = getCameraDistanceTo(hx, hy, hz)
                    local alpha = getFadeAlpha(distance)
                    if alpha > 0 then
                        local sx, sy = getScreenFromWorldPosition(hx, hy, hz + HEIGHT_OFFSET, 0.06)
                        if sx then
                            local name = getPlayerName(player):gsub("#%x%x%x%x%x%x", "")
                            local prefix = (vipLevel >= 3) and "♛ " or ((vipLevel >= 2) and "★ " or "")
                            local fullText = prefix .. name

                            -- адаптивный масштаб от дистанции
                            local scale = math.max(0.6, 1.8 - distance * 0.035)
                            local font = "default-bold"

                            -- цвет обводки: золото для уровня 2+, иначе чёрный
                            local outlineColor
                            if vipLevel >= 2 then
                                outlineColor = tocolor(80, 60, 0, math.floor(220 * alpha))
                            else
                                outlineColor = tocolor(0, 0, 0, math.floor(220 * alpha))
                            end

                            -- ширина всей строки для центрирования
                            local totalWidth = dxGetTextWidth(fullText, scale, font)
                            local cursorX = sx - totalWidth / 2

                            -- рисуем посимвольно с HSV-сдвигом
                            for i = 1, #fullText do
                                local char = fullText:sub(i, i)
                                local charW = dxGetTextWidth(char, scale, font)
                                local centerX = cursorX + charW / 2

                                local hue = (wavePhase + i / WAVE_LENGTH) % 1
                                local r, g, b = hsvToRgb(hue, 0.85, 1.0)
                                local color = tocolor(r, g, b, math.floor(255 * alpha))

                                drawOutlinedChar(char, centerX, sy, color, scale, font, outlineColor)
                                cursorX = cursorX + charW
                            end

                            -- подложка-свечение для уровня 3 (большая корона мерцает)
                            if vipLevel >= 3 then
                                local glow = 0.5 + 0.5 * math.sin(time * 0.004)
                                local glowColor = tocolor(255, 215, 0, math.floor(120 * alpha * glow))
                                dxDrawText("♛", sx - totalWidth/2 + 8, sy - 1,
                                    sx - totalWidth/2 + 8, sy - 1,
                                    glowColor, scale * 1.3, font,
                                    "center", "center", false, false, false, true)
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- =======================================================================
-- ==     ЛОКАЛЬНАЯ ОТЛАДКА / ВЫДАЧА VIP                                ==
-- =======================================================================
-- Команда для теста на себе (только локально, без сервера):
--   /vipme 1  /vipme 2  /vipme 3  /vipme 0
-- Серверу для боевой выдачи: setElementData(player, "vip:level", N)
-- =======================================================================

addCommandHandler("vipme", function (_, level)
    level = tonumber(level) or 0
    setElementData(localPlayer, "vip:level", level)
    outputChatBox("VIP уровень: " .. level, 255, 215, 0)
end)
