--!strict

local EnhancementConfig = require(game:GetService('ReplicatedStorage').Shared.Config.EnhancementConfig)

local EnhancementAuditLog = {
    entries = {},
    playerWindows = {},
}

local function now()
    return os.clock()
end

function EnhancementAuditLog.record(eventType: string, payload)
    table.insert(EnhancementAuditLog.entries, {
        timestamp = os.time(),
        monotonic = now(),
        eventType = eventType,
        payload = payload,
    })
end

function EnhancementAuditLog.recordRequest(player, itemInstanceId: string)
    local userId = player.UserId
    local current = now()
    local state = EnhancementAuditLog.playerWindows[userId] or {
        windowStart = current,
        requestCount = 0,
    }

    if current - state.windowStart > EnhancementConfig.Audit.RepeatedRequestWindowSeconds then
        state.windowStart = current
        state.requestCount = 0
    end

    state.requestCount += 1
    EnhancementAuditLog.playerWindows[userId] = state

    EnhancementAuditLog.record('EnhancementRequest', {
        userId = userId,
        itemInstanceId = itemInstanceId,
        requestCount = state.requestCount,
    })

    if state.requestCount >= EnhancementConfig.Audit.RepeatedRequestThreshold then
        EnhancementAuditLog.record('SuspiciousEnhancementSpam', {
            userId = userId,
            itemInstanceId = itemInstanceId,
            requestCount = state.requestCount,
        })
    end
end

function EnhancementAuditLog.recordOutcome(player, result)
    EnhancementAuditLog.record('EnhancementOutcome', {
        userId = player.UserId,
        itemInstanceId = result.itemInstanceId,
        trackId = result.trackId,
        targetLevel = result.targetLevel,
        previousLevel = result.previousLevel,
        newLevel = result.newLevel,
        success = result.success,
        outcome = result.failureOutcome or 'Success',
        usedProtection = result.usedProtection,
    })
end

function EnhancementAuditLog.recordInvalidAttempt(player, reason: string, payload)
    EnhancementAuditLog.record('InvalidEnhancementAttempt', {
        userId = player.UserId,
        reason = reason,
        payload = payload,
    })
end

return EnhancementAuditLog
