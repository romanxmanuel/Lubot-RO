--[[
	NetworkOwnerManager
	
	Manages network ownership for NPCs to optimize physics calculations.
	Handles cancellation of previous ownership tasks to prevent conflicts
	when multiple players interact with the same NPC.
	
	Usage:
		NetworkOwnerManager.SetTemporaryOwner(npcModel, player, duration)
]]

local NetworkOwnerManager = {}

-- Store active ownership tasks per NPC
-- Key: Model, Value: { thread: thread, endTime: number }
NetworkOwnerManager._activeOwnership = {}

--[[
	Sets temporary network ownership of an NPC to a player.
	Automatically cancels any previous ownership task for the same NPC.
	
	@param npcModel Model - The NPC model to transfer ownership
	@param player Player - The player who will own the NPC
	@param duration number - How long the player maintains ownership (seconds)
]]
function NetworkOwnerManager.SetTemporaryOwner(npcModel: Model, player: Player, duration: number)
	if not npcModel or not player then
		warn("[NetworkOwnerManager] Invalid npcModel or player")
		return
	end
	
	-- Find the primary part (usually HumanoidRootPart)
	local primaryPart = npcModel.PrimaryPart or npcModel:FindFirstChild("HumanoidRootPart")
	if not primaryPart or not primaryPart:IsA("BasePart") then
		warn("[NetworkOwnerManager] NPC has no valid PrimaryPart/HumanoidRootPart")
		return
	end
	
	-- Cancel previous ownership task for this NPC if it exists
	local existing = NetworkOwnerManager._activeOwnership[npcModel]
	if existing and existing.thread then
		task.cancel(existing.thread)
		NetworkOwnerManager._activeOwnership[npcModel] = nil
	end
	
	-- Set network owner to the player
	local success, err = pcall(function()
		primaryPart:SetNetworkOwner(player)
	end)
	
	if not success then
		warn("[NetworkOwnerManager] Failed to set network owner:", err)
		return
	end
	
	-- Schedule ownership return to server after duration
	local thread = task.delay(duration, function()
		-- Return ownership to server
		local returnSuccess, returnErr = pcall(function()
			if primaryPart and primaryPart.Parent then
				primaryPart:SetNetworkOwner(nil)
			end
		end)
		
		if not returnSuccess then
			warn("[NetworkOwnerManager] Failed to return network owner to server:", returnErr)
		end
		
		-- Clean up tracking
		NetworkOwnerManager._activeOwnership[npcModel] = nil
	end)
	
	-- Track this ownership task
	NetworkOwnerManager._activeOwnership[npcModel] = {
		thread = thread,
		endTime = os.clock() + duration,
		player = player,
	}
end

--[[
	Immediately returns network ownership of an NPC to the server.
	Cancels any scheduled return task.
	
	@param npcModel Model - The NPC model to return ownership
]]
function NetworkOwnerManager.ReturnOwnershipToServer(npcModel: Model)
	if not npcModel then
		return
	end
	
	-- Cancel scheduled task if exists
	local existing = NetworkOwnerManager._activeOwnership[npcModel]
	if existing and existing.thread then
		task.cancel(existing.thread)
		NetworkOwnerManager._activeOwnership[npcModel] = nil
	end
	
	-- Return ownership immediately
	local primaryPart = npcModel.PrimaryPart or npcModel:FindFirstChild("HumanoidRootPart")
	if primaryPart and primaryPart:IsA("BasePart") then
		pcall(function()
			primaryPart:SetNetworkOwner(nil)
		end)
	end
end

--[[
	Checks if an NPC currently has a temporary owner.
	
	@param npcModel Model - The NPC model to check
	@return boolean - True if NPC has an active temporary owner
]]
function NetworkOwnerManager.HasTemporaryOwner(npcModel: Model): boolean
	local existing = NetworkOwnerManager._activeOwnership[npcModel]
	return existing ~= nil
end

--[[
	Gets the current temporary owner of an NPC.
	
	@param npcModel Model - The NPC model to check
	@return Player? - The player who owns the NPC, or nil
]]
function NetworkOwnerManager.GetTemporaryOwner(npcModel: Model): Player?
	local existing = NetworkOwnerManager._activeOwnership[npcModel]
	return existing and existing.player or nil
end

function NetworkOwnerManager.Init() end

function NetworkOwnerManager.Start() end

return NetworkOwnerManager
