-- =====================================================================
-- Команды для подбора дистанции вживую (без перезапуска ресурса)
-- =====================================================================
--
--   /blod <distance>          — задать новую дистанцию (например /blod 500)
--   /blodtarget <object|building|all> — что обрабатывать
--   /blodscan                 — пересканировать карту прямо сейчас
--   /blodinfo                 — текущее состояние
--

addCommandHandler("blod", function(_, distArg)
    local dist = tonumber(distArg)
    if not dist then
        outputChatBox("Usage: /blod <distance>   (например /blod 500)", 255, 200, 0)
        return
    end
    if setBuildingsDistance(dist) then
        outputChatBox(("Buildings LOD distance -> %d"):format(dist), 0, 255, 0)
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
        outputChatBox(("Buildings LOD target -> %s"):format(target), 0, 255, 0)
    else
        outputChatBox("Неверный target (object|building|all)", 255, 0, 0)
    end
end)

addCommandHandler("blodscan", function()
    rescanBuildings()
    outputChatBox("Buildings LOD: re-scanned", 0, 255, 0)
end)

addCommandHandler("blodinfo", function()
    outputChatBox(("Buildings LOD: distance=%d, target=%s")
        :format(Config.distance, Config.target), 200, 220, 255)
end)
