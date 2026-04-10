--[[
	KillTargetsHandler.lua
	
	Client-side handler for highlighting kill quest targets (monsters/NPCs).
	Listens to TrackKillTargets signal from QuestService and creates Highlight instances.
	Also detects NPC deaths and reports kills to the server for quest progress.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

---- Knit Services
local QuestService

---- Client-physics NPC support (UseClientPhysics)
local OptimizationConfig = require(ReplicatedStorage.SharedSource.Datas.NPCs.OptimizationConfig)
local ClientPhysicsRenderer -- lazy-loaded when UseClientPhysics is active

local KillTargetsHandler = {}

-- Track highlighted monsters per task
-- { [taskIndex] = { [monster] = Highlight } }
KillTargetsHandler.ActiveHighlights = {}

-- Track death connections per task
-- { [taskIndex] = { [monster] = RBXScriptConnection } }
KillTargetsHandler.DeathConnections = {}

-- Track which monsters have already been reported as killed (prevent duplicates)
-- { [monster] = true }
KillTargetsHandler.ReportedKills = {}

local player = Players.LocalPlayer

--[[
	Return handler config for QuestTypeManager auto-discovery
	@return table - Handler configuration
]]
function KillTargetsHandler.GetHandlerConfig()
	return {
		TypeName = "KillNPC",
		SignalHandlers = {
			TrackKillTargets = "TrackKillTargets",
			ClearKillTargets = "ClearHighlights",
		},
		RequiresCleanup = true,
	}
end

--[[
	Cleanup all highlights (required by QuestTypeManager)
]]
function KillTargetsHandler:CleanupAll()
	self:ClearHighlights()
end

--[[
	Setup death detection for a monster.
	When the monster's Humanoid dies, report the kill to the server.
	@param monsterKey Model|string - The monster model (traditional) or NPC ID (UseClientPhysics)
	@param taskIndex number - The task index for this kill quest
	@param targetName string - The expected target name for validation
]]
function KillTargetsHandler:SetupDeathDetection(monsterKey, taskIndex, targetName)
	-- Initialize death connections table for this task if needed
	if not KillTargetsHandler.DeathConnections[taskIndex] then
		KillTargetsHandler.DeathConnections[taskIndex] = {}
	end

	-- Disconnect existing connection if any
	if KillTargetsHandler.DeathConnections[taskIndex][monsterKey] then
		KillTargetsHandler.DeathConnections[taskIndex][monsterKey]:Disconnect()
	end

	-- Callback when this NPC dies
	local function onDied()
		-- Prevent duplicate reports for the same monster
		if KillTargetsHandler.ReportedKills[monsterKey] then
			return
		end
		KillTargetsHandler.ReportedKills[monsterKey] = true

		-- Report the kill to the server
		if QuestService and QuestService.ReportKill then
			task.spawn(function()
				QuestService:ReportKill(targetName, taskIndex)
					:catch(function(err)
						warn("[KillTargetsHandler] Failed to report kill:", err)
					end)
			end)
		end

		-- Clear the highlight for this monster
		if KillTargetsHandler.ActiveHighlights[taskIndex] and KillTargetsHandler.ActiveHighlights[taskIndex][monsterKey] then
			local highlight = KillTargetsHandler.ActiveHighlights[taskIndex][monsterKey]
			if highlight then
				highlight:Destroy()
			end
			KillTargetsHandler.ActiveHighlights[taskIndex][monsterKey] = nil
		end

		-- Clean up death connection
		if KillTargetsHandler.DeathConnections[taskIndex] and KillTargetsHandler.DeathConnections[taskIndex][monsterKey] then
			KillTargetsHandler.DeathConnections[taskIndex][monsterKey]:Disconnect()
			KillTargetsHandler.DeathConnections[taskIndex][monsterKey] = nil
		end
	end

	if typeof(monsterKey) == "string" then
		-- UseClientPhysics mode: watch IsAlive value in ReplicatedStorage.ActiveNPCs
		local activeNPCsFolder = ReplicatedStorage:FindFirstChild("ActiveNPCs")
		local npcFolder = activeNPCsFolder and activeNPCsFolder:FindFirstChild(monsterKey)
		if npcFolder then
			local isAliveValue = npcFolder:FindFirstChild("IsAlive")
			if isAliveValue then
				if not isAliveValue.Value then
					-- Already dead
					onDied()
					return
				end
				KillTargetsHandler.DeathConnections[taskIndex][monsterKey] = isAliveValue.Changed:Connect(function(newValue)
					if not newValue then
						onDied()
					end
				end)
			end
		end
	else
		-- Traditional mode: watch Humanoid.Died
		local humanoid = monsterKey:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		KillTargetsHandler.DeathConnections[taskIndex][monsterKey] = humanoid.Died:Connect(function()
			onDied()
		end)
	end
end

--[[
	Resolve a monster entry to a highlightable model.
	For traditional NPCs, returns the model directly.
	For UseClientPhysics NPCs (string IDs), returns the client visual model.
	@param monsterEntry Model|string
	@return Model? - The model to highlight, or nil
]]
local function ResolveVisualModel(monsterEntry)
	if typeof(monsterEntry) == "string" then
		-- Lazy-load ClientPhysicsRenderer
		if not ClientPhysicsRenderer then
			local NPC_Controller = ReplicatedStorage:FindFirstChild("ClientSource")
				and ReplicatedStorage.ClientSource:FindFirstChild("Client")
				and ReplicatedStorage.ClientSource.Client:FindFirstChild("NPC_Controller")
			if NPC_Controller then
				local renderModule = NPC_Controller:FindFirstChild("Components")
					and NPC_Controller.Components:FindFirstChild("Others")
					and NPC_Controller.Components.Others:FindFirstChild("Rendering")
					and NPC_Controller.Components.Others.Rendering:FindFirstChild("ClientPhysicsRenderer")
				if renderModule then
					ClientPhysicsRenderer = require(renderModule)
				end
			end
		end
		if ClientPhysicsRenderer then
			return ClientPhysicsRenderer.GetVisualModel(monsterEntry)
		end
		return nil
	elseif typeof(monsterEntry) == "Instance" and monsterEntry:IsA("Model") then
		return monsterEntry
	end
	return nil
end

-- Track and highlight kill targets for a quest
function KillTargetsHandler:TrackKillTargets(trackData)
	local monsters = trackData.Monsters or {}
	local config = trackData.Config or {}
	local taskIndex = trackData.TaskIndex
	local targetName = trackData.TargetName

	self:ClearHighlights(taskIndex)

	if not KillTargetsHandler.ActiveHighlights[taskIndex] then
		KillTargetsHandler.ActiveHighlights[taskIndex] = {}
	end

	for _, monsterEntry in pairs(monsters) do
		if not monsterEntry then continue end

		-- Use the original entry (string ID or Model) as the tracking key
		local monsterKey = monsterEntry
		local visualModel = ResolveVisualModel(monsterEntry)

		if visualModel then
			local highlight = Instance.new("Highlight")
			highlight.Name = "QuestKillHighlight"

			highlight.FillColor = config.FillColor or Color3.fromRGB(255, 0, 0)
			highlight.OutlineColor = config.OutlineColor or Color3.fromRGB(255, 255, 255)
			highlight.FillTransparency = config.FillTransparency or 0.5
			highlight.OutlineTransparency = config.OutlineTransparency or 0
			highlight.DepthMode = config.DepthMode or Enum.HighlightDepthMode.Occluded

			highlight.Adornee = visualModel
			highlight.Parent = visualModel

			KillTargetsHandler.ActiveHighlights[taskIndex][monsterKey] = highlight
		end

		-- Setup death detection for kill registration (works even without visual model)
		self:SetupDeathDetection(monsterKey, taskIndex, targetName)
	end
end

--[[
	Clear death connections for a specific task or all tasks.
	@param taskIndex number|nil - The task index to clear, or nil to clear all
]]
function KillTargetsHandler:ClearDeathConnections(taskIndex)
	if taskIndex then
		if KillTargetsHandler.DeathConnections[taskIndex] then
			for monster, connection in pairs(KillTargetsHandler.DeathConnections[taskIndex]) do
				if connection then
					connection:Disconnect()
				end
				-- Clear reported kills for this monster
				KillTargetsHandler.ReportedKills[monster] = nil
			end
			KillTargetsHandler.DeathConnections[taskIndex] = nil
		end
	else
		for _, connections in pairs(KillTargetsHandler.DeathConnections) do
			for monster, connection in pairs(connections) do
				if connection then
					connection:Disconnect()
				end
			end
		end
		KillTargetsHandler.DeathConnections = {}
		KillTargetsHandler.ReportedKills = {}
	end
end

-- Clear highlights for a specific task or all tasks
function KillTargetsHandler:ClearHighlights(taskIndex)
	-- Also clear death connections when clearing highlights
	self:ClearDeathConnections(taskIndex)
	
	if taskIndex then
		if KillTargetsHandler.ActiveHighlights[taskIndex] then
			for monster, highlight in pairs(KillTargetsHandler.ActiveHighlights[taskIndex]) do
				if highlight then
					highlight:Destroy()
				end
			end

			KillTargetsHandler.ActiveHighlights[taskIndex] = nil
		end
	else
		for _, highlights in pairs(KillTargetsHandler.ActiveHighlights) do
			for _, highlight in pairs(highlights) do
				if highlight then
					highlight:Destroy()
				end
			end
		end

		KillTargetsHandler.ActiveHighlights = {}
	end
end

function KillTargetsHandler.Start()
	-- Signal connections are now handled by QuestTypeManager via GetHandlerConfig().SignalHandlers
	-- Only keep non-signal event connections here
	
	player.CharacterAdded:Connect(function()
		KillTargetsHandler:ClearHighlights()
	end)
end

function KillTargetsHandler.Init()
	QuestService = Knit.GetService("QuestService")
end

return KillTargetsHandler
