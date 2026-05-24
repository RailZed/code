-- =====================================================================
-- Команды
-- =====================================================================
--
--   /bfar  <distance>                  — горизонт камеры
--   /blod  <distance>                  — LOD distance кастомных моделей
--   /blodtarget <object|building|all>  — что обрабатывать
--   /blodforce <on|off>                — форсить object'ы в сцену (главное!)
--   /blodscan                          — пересканировать
--   /blodinfo                          — статус
--

addCommandHandler("bfar", function(_, distArg)
    local dist = tonumber(distArg)
    if not dist then
        outputChatBox("Usage: /bfar <distance>   (например /bfar 1500)", 255, 200, 0)
        return
    end
    setBuildingsFarClip(dist)
    outputChatBox(("farClipDistance -> %d (fog %d)"):format(dist, math.max(50, dist - 100)),
        0, 255, 0)
end)

addCommandHandler("blod", function(_, distArg)
    local dist = tonumber(distArg)
    if not dist then
        outputChatBox("Usage: /blod <distance>   (например /blod 1400)", 255, 200, 0)
        return
    end
    setBuildingsLOD(dist)
    outputChatBox(("modelLODDistance -> %d"):format(dist), 0, 255, 0)
end)

addCommandHandler("blodtarget", function(_, target)
    if not target or not setBuildingsTarget(target) then
        outputChatBox("Usage: /blodtarget <object|building|all>", 255, 200, 0)
        return
    end
    outputChatBox(("target -> %s"):format(target), 0, 255, 0)
end)

addCommandHandler("blodforce", function(_, arg)
    if arg == nil then
        outputChatBox("Usage: /blodforce <on|off>", 255, 200, 0)
        return
    end
    local enabled = setBuildingsForceStreamed(arg == "on" or arg == "1" or arg == "true")
    outputChatBox(("forceObjectsAlwaysStreamed -> %s"):format(enabled and "ON" or "OFF"),
        0, 255, 0)
end)

addCommandHandler("blodscan", function()
    rescanBuildings()
    outputChatBox("Buildings: re-scanned", 0, 255, 0)
end)

addCommandHandler("blodinfo", function()
    local s = getBuildingsStatus()
    outputChatBox(
        ("farClip=%d fog=%d modelLOD=%d target=%s force=%s | elements=%d models=%d forced=%d")
        :format(s.farClipDistance, s.fogDistance, s.modelLODDistance,
                s.target, tostring(s.forceObjectsAlwaysStreamed),
                s.elementsSeen, s.modelsApplied, s.elementsForced),
        200, 220, 255)
end)
