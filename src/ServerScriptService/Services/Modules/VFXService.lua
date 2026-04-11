--!strict

local VFXService = {}

function VFXService.emit(effectEvent: RemoteEvent, effectName: string, payload)
    effectEvent:FireAllClients(effectName, payload)
end

return VFXService
