-- =====================================================================
-- Команды для подбора параметров вживую
-- =====================================================================
--
--   /bfar  <distance>   — горизонт камеры       (например /bfar 1500)
--   /blod  <distance>   — LOD distance моделей  (например /blod 1500)
--   /bscale <value>     — минимальный scale (мельче — без LOD)
--   /brebuild           — пересоздать все LOD'ы с новыми настройками
--   /binfo              — статус
--

addCommandHandler("bfar", function(_, distArg)
    local d = tonumber(distArg)
    if not d then
        outputChatBox("Usage: /bfar <distance>", 255, 200, 0)
        return
    end
    setBuildingsFarClip(d)
    outputChatBox(("farClip -> %d (fog %d)"):format(d, math.max(50, d - 100)), 0, 255, 0)
end)

addCommandHandler("blod", function(_, distArg)
    local d = tonumber(distArg)
    if not d then
        outputChatBox("Usage: /blod <distance>", 255, 200, 0)
        return
    end
    setBuildingsLOD(d)
    outputChatBox(("modelLOD -> %d"):format(d), 0, 255, 0)
end)

addCommandHandler("bscale", function(_, val)
    local v = tonumber(val)
    if not v then
        outputChatBox("Usage: /bscale <value>   (0=без фильтра, 1=по умолчанию, 2=только крупные)", 255, 200, 0)
        return
    end
    Config.minScale = v
    outputChatBox(("minScale -> %.2f (применится после /brebuild)"):format(v), 0, 255, 0)
end)

addCommandHandler("brebuild", function()
    outputChatBox("Rebuilding LODs...", 200, 220, 255)
    rebuildAllLODs()
end)

addCommandHandler("binfo", function()
    local s = getBuildingsStatus()
    outputChatBox(
        ("farClip=%d fog=%d modelLOD=%d minScale=%.2f | resources=%d models=%d created=%d skipped=%d")
        :format(s.farClipDistance, s.fogDistance, s.modelLODDistance, s.minScale,
                s.resources, s.models, s.created, s.skipped),
        200, 220, 255)
end)
