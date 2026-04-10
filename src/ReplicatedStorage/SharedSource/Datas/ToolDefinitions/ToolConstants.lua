--!strict
-- ToolConstants.lua
-- Essential framework-wide constants (only what we actually use)

return {
	-- === RANGE ===
	MAX_TOOL_RANGE = 100, -- Maximum range for tool validation
	
	-- === TIMING ===
	DEFAULT_COOLDOWN = 1, -- Default cooldown in seconds
	
	-- === SECURITY ===
	MAX_ACTIVATIONS_PER_SECOND = 20, -- Rate limiting for anti-spam
}
