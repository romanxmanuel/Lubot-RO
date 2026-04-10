--[[
	EventMappings.lua
	
	Maps game events to quest progress events.
	Defines how to listen to game services and extract relevant data.
	
	Structure:
	{
		ProgressEventName = {
			ServiceName = "ServiceName",
			SignalName = "SignalName",
			DataMapper = function(...) -> eventData
		}
	}
	
	Each DataMapper function receives the signal's arguments and returns a table with:
	- Player: The player instance
	- Amount: Progress amount to increment
	- [Additional data]: Event-specific data for filtering
	
	If DataMapper returns nil, the event is ignored.
]]

local EventMappings = {
	--[[
		ItemCollected Event
		Triggered when player collects an item (crates, packages, etc.)
		Expected signal: QuestService or InventoryService fires this when items are collected
		
		Note: You need to fire this event from your pickup/collection system:
		- When player picks up a crate
		- When player completes a delivery
		- When any quest-related item is collected
	]]
	["ItemCollected"] = {
		ServiceName = "QuestService", -- Change to your service that handles item collection
		SignalName = "ItemCollected", -- Change to your actual signal name
		DataMapper = function(player, itemId, quantity)
			-- Validate player
			if not player or not player:IsA("Player") then
				return nil
			end

			return {
				Player = player,
				Amount = quantity or 1,
				ItemId = itemId,
			}
		end,
	},

	-- Add more event mappings as needed when you implement other systems:
	-- ["EnemyKilled"], ["LevelUp"], ["CurrencyEarned"], ["BossDefeated"], etc.
}

return EventMappings
