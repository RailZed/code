-- =====================================================================
-- Команды для подбора значений вживую
-- =====================================================================
--
--   /bfar  <distance>                  — горизонт камеры (главное!)
--   /blod  <distance>                  — LOD distance для кастомных моделей
--   /blodtarget <object|building|all>  — что обрабатывать
--   /blodscan                          — пересканировать карту
--   /blodinfo                          — текущее состояние
--

addCommandHandler("bfar", function(_, distArg)
    local dist = tonumber(distArg)
    if not dist then
        outputChatBox("Usage: /bfar <distance>   (например /bfar 1500)", 255, 200, 0)
        return
    end
    if setBuildingsFarClip(dist) then
        outputChatBox(("farClipDistance -> %d (fog %d)"):format(dist, math.max(50, dist - 100)),
            0, 255, 0)
    else
        outputChatBox("Не удалось применить", 255, 0, 0)
    end
end)

addCommandHandler("blod", function(_, distArg)
    local dist = tonumber(distArg)
    if not dist then
        outputChatBox("Usage: /blod <distance>   (например /blod 1000)", 255, 200, 0)
        return
    end
    if setBuildingsLOD(dist) then
        outputChatBox(("modelLODDistance -> %d"):format(dist), 0, 255, 0)
    else
        outputChatBox("Не удалось применить", 255, 0, 0)
    end
end)

addCommandHandler("blodtarget", function(_, target)
    if not target then
        outputChatBox("Usage: /blodtarget <object|building|all>", 255, 200, 0)
        return
    end
    if setBuildingsTarget(target) then
        outputChatBox(("target -> %s"):format(target), 0, 255, 0)
    else
        outputChatBox("Неверный target (object|building|all)", 255, 0, 0)
    end
end)

addCommandHandler("blodscan", function()
    rescanBuildings()
    outputChatBox("Buildings LOD: re-scanned", 0, 255, 0)
end)

addCommandHandler("blodinfo", function()
    local s = getBuildingsStatus()
    outputChatBox(("farClip=%d fog=%d modelLOD=%d target=%s elements=%d models=%d")
        :format(s.farClipDistance, s.fogDistance, s.modelLODDistance,
                s.target, s.elementsSeen, s.modelsApplied),
        200, 220, 255)
end)
