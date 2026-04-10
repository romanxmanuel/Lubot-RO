--!strict

local ReplicatedStorage = game:GetService('ReplicatedStorage')

local EnhancementConfig = require(ReplicatedStorage.Shared.Config.EnhancementConfig)
local EnhancementFormula = require(ReplicatedStorage.Shared.Progression.EnhancementFormula)
local EnhancementAuditLog = require(script.Parent.EnhancementAuditLog)

local EnhancementSystem = {}

local function copyTable(source)
    local clone = {}
    for key, value in pairs(source) do
        clone[key] = value
    end
    return clone
end

local function hasRequiredMaterials(ownedMaterials, requirements)
    for itemId, amountNeeded in pairs(requirements) do
        if (ownedMaterials[itemId] or 0) < amountNeeded then
            return false, itemId
        end
    end

    return true, nil
end

local function buildPresentation(result)
    local spectacle = result.targetLevel >= EnhancementConfig.Presentation.SpectacleThreshold

    return {
        anticipationSeconds = EnhancementConfig.Presentation.AnticipationSeconds,
        resultRevealSeconds = EnhancementConfig.Presentation.ResultRevealSeconds,
        shouldBroadcastTown = spectacle and result.targetLevel >= EnhancementConfig.Presentation.BroadcastThreshold,
        shouldPulseTown = spectacle,
        playBigSuccess = spectacle and result.success,
        playBigFailure = spectacle and not result.success,
    }
end

function EnhancementSystem.validateRequest(player, request, dependencies)
    if type(request) ~= 'table' then
        return false, 'InvalidRequest'
    end

    local inventoryGateway = dependencies.inventoryGateway
    if not inventoryGateway then
        return false, 'MissingInventoryGateway'
    end

    local itemInstance = inventoryGateway.getEnhanceableItem(player, request.itemInstanceId)
    if not itemInstance then
        return false, 'ItemNotFound'
    end

    if itemInstance.destroyed then
        return false, 'ItemDestroyed'
    end

    local currentLevel = itemInstance.enhancementLevel or 0
    local targetLevel = currentLevel + 1

    if targetLevel > EnhancementConfig.MaximumEnhancementLevel then
        return false, 'MaxEnhancementReached'
    end

    local trackId = itemInstance.enhancementTrack
    if not trackId then
        return false, 'MissingEnhancementTrack'
    end

    local materials = EnhancementFormula.getMaterialRequirements(trackId, targetLevel)
    local ownedMaterials = inventoryGateway.getOwnedMaterials(player)
    local hasMaterials, missingItemId = hasRequiredMaterials(ownedMaterials, materials)
    if not hasMaterials then
        return false, 'MissingMaterials', { missingItemId = missingItemId }
    end

    local zenyCost = EnhancementFormula.getZenyCost(trackId, targetLevel)
    if inventoryGateway.getZeny(player) < zenyCost then
        return false, 'NotEnoughZeny'
    end

    local protectionItemId = request.protectionItemId
    local protectionRules = nil

    if protectionItemId then
        protectionRules = EnhancementConfig.Protection[protectionItemId]
        if not protectionRules then
            return false, 'InvalidProtectionItem'
        end

        if inventoryGateway.getConsumableCount(player, protectionItemId) <= 0 then
            return false, 'MissingProtectionItem'
        end
    end

    return true, nil, {
        itemInstance = itemInstance,
        trackId = trackId,
        currentLevel = currentLevel,
        targetLevel = targetLevel,
        materialRequirements = materials,
        zenyCost = zenyCost,
        protectionItemId = protectionItemId,
        protectionRules = protectionRules,
    }
end

function EnhancementSystem.tryEnhance(player, request, dependencies)
    EnhancementAuditLog.recordRequest(player, request.itemInstanceId)

    local valid, reason, payload = EnhancementSystem.validateRequest(player, request, dependencies)
    if not valid then
        EnhancementAuditLog.recordInvalidAttempt(player, reason, {
            itemInstanceId = request.itemInstanceId,
            detail = payload,
        })

        return {
            success = false,
            reason = reason,
            state = 'Error',
        }
    end

    local inventoryGateway = dependencies.inventoryGateway
    local statsGateway = dependencies.statsGateway
    local rng = if dependencies.rng then dependencies.rng else Random.new()
    local luckBonus = 0

    if statsGateway and statsGateway.getUpgradeLuckBonus then
        luckBonus = statsGateway.getUpgradeLuckBonus(player) or 0
    end

    local successRate = EnhancementFormula.getSuccessRate(payload.trackId, payload.targetLevel, luckBonus)
    local success = rng:NextNumber() <= successRate

    inventoryGateway.consumeMaterials(player, payload.materialRequirements)
    inventoryGateway.spendZeny(player, payload.zenyCost)

    if payload.protectionItemId and payload.protectionRules and payload.protectionRules.consumesOnUse then
        inventoryGateway.consumeConsumable(player, payload.protectionItemId, 1)
    end

    local result = {
        itemInstanceId = payload.itemInstance.instanceId or request.itemInstanceId,
        trackId = payload.trackId,
        previousLevel = payload.currentLevel,
        targetLevel = payload.targetLevel,
        successRate = successRate,
        success = success,
        usedProtection = payload.protectionItemId ~= nil,
        protectionItemId = payload.protectionItemId,
        consumedMaterials = copyTable(payload.materialRequirements),
        zenyCost = payload.zenyCost,
    }

    if success then
        inventoryGateway.setEnhancementLevel(player, request.itemInstanceId, payload.targetLevel)
        result.newLevel = payload.targetLevel
        result.state = 'Success'
    else
        local failureOutcome = EnhancementFormula.getFailureOutcome(payload.trackId, payload.targetLevel, payload.protectionRules)
        result.failureOutcome = failureOutcome

        if failureOutcome == 'Downgrade' then
            local downgradedLevel = math.max(payload.currentLevel - 1, 0)
            inventoryGateway.setEnhancementLevel(player, request.itemInstanceId, downgradedLevel)
            result.newLevel = downgradedLevel
            result.state = 'Failure'
        elseif failureOutcome == 'Destroy' then
            inventoryGateway.destroyEnhanceableItem(player, request.itemInstanceId)
            result.newLevel = -1
            result.state = 'Destroyed'
        else
            result.newLevel = payload.currentLevel
            result.state = 'Failure'
        end
    end

    result.presentation = buildPresentation(result)
    EnhancementAuditLog.recordOutcome(player, result)

    return result
end

return EnhancementSystem
