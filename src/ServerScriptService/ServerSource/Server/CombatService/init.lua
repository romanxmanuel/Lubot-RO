local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local CombatService = Knit.CreateService({
	Name = "CombatService",
	Instance = script,
	Client = {},
})

-- Remote events
CombatService.Client.PlayHitSound = Knit.CreateSignal()
CombatService.Client.PlayPunchEffect = Knit.CreateSignal()
CombatService.Client.ApplyKnockback = Knit.CreateSignal()

---- Components
--- component utilities
local componentsInitializer = require(ReplicatedStorage.SharedSource.Utilities.ScriptsLoader.ComponentsInitializer)
--- component folders
local componentsFolder = script:WaitForChild("Components", 10)
CombatService.Components = {}
for _, v in pairs(componentsFolder:WaitForChild("Others", 10):GetChildren()) do
	CombatService.Components[v.Name] = require(v)
end
CombatService.GetComponent = require(componentsFolder["Get()"])
CombatService.SetComponent = require(componentsFolder["Set()"])

---- Knit Services

-- RemoteFunction-like entry
function CombatService.Client:PerformAttack(player)
	-- Delegate to Set component for implementation
	return CombatService.SetComponent:PerformAttack(player)
end

-- Client-reported hit on a server-physics NPC (for responsive hitbox detection)
function CombatService.Client:HitServerNPC(player, targetNPC)
	local NormalAttack = CombatService.Components.NormalAttack
	if NormalAttack and NormalAttack.HandleClientHitNPC then
		NormalAttack:HandleClientHitNPC(player, targetNPC)
	end
end

function CombatService:KnitStart()
	-- Post-initialization if needed
end

function CombatService:KnitInit()
	-- Initialize components
	componentsInitializer(script)
end

return CombatService
