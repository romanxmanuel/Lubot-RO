local Players = game:GetService("Players")
local module = {}

-- Utility function to get total damage dealt by a user to a target
-- Returns nil if user has not damaged target (no damage record exists)
-- Returns the damage amount (number) if user has damaged target
function module.GetDamageDealt(user, target)
	local targetHum = target:FindFirstChild("Humanoid")
	if not targetHum then
		-- Target has no humanoid, cannot have been damaged
		return nil
	end

	local damagerRecorders = targetHum:FindFirstChild("DamagerRecorders")
	if not damagerRecorders then
		-- No damage tracking folder exists, target has never been damaged
		return nil
	end

	local numVal = damagerRecorders:FindFirstChild(user.Name)
	if not numVal then
		-- User has not damaged this target
		return nil
	end

	-- User has damaged target, return the damage amount
	return numVal.Value
end

-- Returns a dictionary of all characters that damaged the target
-- Format: { [characterModel] = damageDealt }
-- Returns an empty table if no one has damaged the target
function module.GetAllDamagers(target)
	local damagers = {}

	local targetHum = target:FindFirstChild("Humanoid")
	if not targetHum then
		return damagers
	end

	local damagerRecorders = targetHum:FindFirstChild("DamagerRecorders")
	if not damagerRecorders then
		return damagers
	end

	-- Iterate through all NumberValues in DamagerRecorders
	for _, numVal in ipairs(damagerRecorders:GetChildren()) do
		if numVal:IsA("NumberValue") then
			-- Try to find the character by name (could be a player or NPC)
			local character = nil

			-- First check if it's a player's character
			local player = Players:FindFirstChild(numVal.Name)
			if player and player:IsA("Player") then
				character = player.Character
			end

			-- If not a player, try to find in workspace (NPCs, Rigs, etc.)
			if not character then
				character = workspace:FindFirstChild(numVal.Name)
			end

			-- Only add if character still exists
			if character then
				damagers[character] = numVal.Value
			end
		end
	end

	return damagers
end

function module.Start() end

function module.Init() end

return module
