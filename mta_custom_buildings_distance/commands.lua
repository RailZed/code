-- =====================================================================
-- Команды для подбора дистанции вживую (без перезапуска ресурса)
-- =====================================================================
--
--   /blod <distance>   — задать новую дистанцию для всех найденных моделей
--   /blodinfo          — показать текущую дистанцию и сколько моделей обработано
--

addCommandHandler("blod", function(_, distArg)
    local dist = tonumber(distArg)
    if not dist then
        outputChatBox("Usage: /blod <distance>   (например /blod 400)", 255, 200, 0)
        return
    end
    if setBuildingsDistance(dist) then
        outputChatBox(("Buildings LOD distance -> %d"):format(dist), 0, 255, 0)
    else
        outputChatBox("Не удалось применить", 255, 0, 0)
    end
end)

addCommandHandler("blodinfo", function()
    outputChatBox(("Buildings LOD: distance=%d, target=%s")
        :format(Config.distance, Config.target), 200, 220, 255)
end)
