--!strict

local MonetizationService = {}

function MonetizationService.processReceipt(receiptInfo)
    -- TODO: grant bounded rewards and persist entitlements safely.
    return Enum.ProductPurchaseDecision.NotProcessedYet
end

return MonetizationService

