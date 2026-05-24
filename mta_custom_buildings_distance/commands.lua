-- =====================================================================
-- Удобные команды для подбора значения LOD без перезапуска ресурса
-- =====================================================================
--
--   /blod <modelId> <distance>   — задать LOD distance модели
--   /blodall <distance>          — применить ко всем моделям из конфига
--   /blodlist                    — показать что сейчас применено
--

addCommandHandler("blod", function(_, modelArg, distArg)
    local id   = tonumber(modelArg)
    local dist = tonumber(distArg)
    if not id or not dist then
        outputChatBox("Usage: /blod <modelId> <distance>", 255, 200, 0)
        return
    end
    if engineSetModelLODDistance(id, dist) then
        outputChatBox(("model %d -> LOD %d"):format(id, dist), 0, 255, 0)
    else
        outputChatBox(("failed for model %d"):format(id), 255, 0, 0)
    end
end)

addCommandHandler("blodall", function(_, distArg)
    local dist = tonumber(distArg) or Config.defaultLODDistance
    local n = 0
    for _, entry in ipairs(Config.models) do
        if engineSetModelLODDistance(entry.model, dist) then
            n = n + 1
        end
    end
    outputChatBox(("Applied LOD %d to %d models"):format(dist, n), 0, 255, 0)
end)

addCommandHandler("blodlist", function()
    if #Config.models == 0 then
        outputChatBox("Config.models is empty — добавь свои model ID в config.lua", 255, 200, 0)
        return
    end
    outputChatBox("Custom buildings LOD config:", 255, 255, 255)
    for _, e in ipairs(Config.models) do
        outputChatBox(("  model %d -> %d%s")
            :format(e.model, e.distance or Config.defaultLODDistance,
                    e.lodModel and (" (LOD model " .. e.lodModel .. ")") or ""),
            200, 200, 200)
    end
end)
