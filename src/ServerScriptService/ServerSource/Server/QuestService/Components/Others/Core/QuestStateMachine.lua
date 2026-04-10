--[[
	QuestStateMachine.lua
	
	Manages atomic state transitions for quests.
	Ensures quest states change safely with rollback on failure.
]]

local QuestStateMachine = {}

-- Valid quest states
local QuestStates = {
	NotStarted = "NotStarted",
	InProgress = "InProgress",
	Completed = "Completed",
	Failed = "Failed",
	Expired = "Expired"
}

-- Valid state transitions
local validTransitions = {
	NotStarted = {
		InProgress = true
	},
	InProgress = {
		Completed = true,
		Failed = true
	},
	-- Completed and Failed are terminal states (no transitions out)
}

--[[
	Attempt to transition quest state atomically
	@param player Player
	@param quest QuestBase - Quest instance
	@param fromState string - Expected current state
	@param toState string - Desired new state
	@param callbacks table - {onSuccess = function(), onFailure = function(err)}
	@return boolean - Whether transition succeeded
]]
function QuestStateMachine:Transition(player, quest, fromState, toState, callbacks)
	callbacks = callbacks or {}
	
	-- Validate current state
	local currentState = quest:GetState()
	if currentState ~= fromState then
		local err = string.format(
			"State mismatch: quest is in '%s' but expected '%s'",
			currentState,
			fromState
		)
		if callbacks.onFailure then
			callbacks.onFailure(err)
		end
		return false
	end
	
	-- Validate transition is allowed
	if not validTransitions[fromState] or not validTransitions[fromState][toState] then
		local err = string.format(
			"Invalid transition: %s -> %s",
			fromState,
			toState
		)
		if callbacks.onFailure then
			callbacks.onFailure(err)
		end
		return false
	end
	
	-- Attempt atomic state change
	local success, err = pcall(function()
		-- Update quest state
		quest:SetState(toState)
		
		-- Execute success callback
		if callbacks.onSuccess then
			callbacks.onSuccess()
		end
	end)
	
	if not success then
		-- Rollback state on failure
		quest:SetState(fromState)
		
		if callbacks.onFailure then
			callbacks.onFailure(err)
		end
		
		warn("State transition failed and rolled back:", err)
		return false
	end
	
	return true
end

--[[
	Get valid transitions from a state
	@param fromState string
	@return table - Array of valid next states
]]
function QuestStateMachine:GetValidTransitions(fromState)
	local transitions = validTransitions[fromState]
	if not transitions then
		return {}
	end
	
	local result = {}
	for state, _ in pairs(transitions) do
		table.insert(result, state)
	end
	return result
end

return QuestStateMachine
