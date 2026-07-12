function RememberMe_InitDB()
    RememberMeDB = RememberMeDB or {}
end

function RememberMe_GetRecord(name)
    RememberMeDB[name] = RememberMeDB[name] or {
        score        = 0,
        interactions = {},
        lastSeen     = {},
    }
    return RememberMeDB[name]
end

function RememberMe_GetScore(name)
    if not RememberMeDB or not name then return 0 end
    local record = RememberMeDB[name]
    return record and record.score or 0
end

function RememberMe_AddInteraction(name, interactionType, weight)
    if not RememberMeDB or not name or name == "" then return end
    if name == UnitName("player") then return end

    local record = RememberMe_GetRecord(name)
    local now    = time()

    -- Rate limit: don't record the same interaction type more than once per cooldown window
    local last = record.lastSeen[interactionType] or 0
    if (now - last) < RememberMe_InteractionCooldown then return end
    record.lastSeen[interactionType] = now

    record.score = record.score + weight
    table.insert(record.interactions, {
        type      = interactionType,
        timestamp = now,
        weight    = weight,
    })
end
