-- =====================================================================
-- Команды
-- =====================================================================
--
--   /badd <modelId>       — добавить ID в список (сразу применится)
--   /bdel <modelId>       — убрать ID
--   /bfar <distance>      — горизонт камеры
--   /blod <distance>      — LOD distance для всех ID
--   /bscan                — пересканировать (например после спавна новых)
--   /binfo                — статус
--

addCommandHandler("badd", function(_, idArg)
    local id = tonumber(idArg)
    if not id then
        outputChatBox("Usage: /badd <modelId>", 255, 200, 0)
        return
    end
    if addBuildingModel(id) then
        outputChatBox(("+ model %d added"):format(id), 0, 255, 0)
    else
        outputChatBox("failed", 255, 0, 0)
    end
end)

addCommandHandler("bdel", function(_, idArg)
    local id = tonumber(idArg)
    if not id then
        outputChatBox("Usage: /bdel <modelId>", 255, 200, 0)
        return
    end
    if removeBuildingModel(id) then
        outputChatBox(("- model %d removed"):format(id), 0, 255, 0)
    end
end)

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

addCommandHandler("bscan", function()
    rescanBuildings()
    outputChatBox("re-scanned", 0, 255, 0)
end)

addCommandHandler("binfo", function()
    local s = getBuildingsStatus()
    outputChatBox(
        ("farClip=%d fog=%d modelLOD=%d | ids=%d models=%d created=%d")
        :format(s.farClipDistance, s.fogDistance, s.modelLODDistance,
                s.idsConfigured, s.modelsApplied, s.lodCreated),
        200, 220, 255)
end)
