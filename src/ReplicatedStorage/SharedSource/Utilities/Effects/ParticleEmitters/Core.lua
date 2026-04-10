--[[
	Core ParticleEmitter Operations
	Handles enable/disable/toggle operations with cleanup thread management
--]]

local Core = {}

-- Internal cleanup tracking
local activeCleanupThreads = {}

--[=[
	Cancels all active cleanup threads for a specific object
	@param object Instance -- The object to cancel cleanup for
]=]
local function cancelCleanupThreads(object: Instance)
	if activeCleanupThreads[object] then
		for _, thread in ipairs(activeCleanupThreads[object]) do
			task.cancel(thread)
		end
		activeCleanupThreads[object] = nil
	end
end

--[=[
	Tracks a cleanup thread for automatic cancellation
	@param object Instance -- The object associated with the thread
	@param thread thread -- The thread to track
]=]
local function trackCleanupThread(object: Instance, thread: thread)
	if not activeCleanupThreads[object] then
		activeCleanupThreads[object] = {}
	end
	table.insert(activeCleanupThreads[object], thread)
end

--[=[
	Disables all ParticleEmitters in an object and its descendants
	@param object Instance -- The object to disable emitters in
	@param dontDestroy boolean? -- If true, emitters won't be destroyed after lifetime
	@param includeObject boolean? -- If true, also checks the root object itself
]=]
function Core.DisableDescendants(object: Instance, dontDestroy: boolean?, includeObject: boolean?)
	if not object then
		warn("[ParticleEmitters] DisableDescendants: Invalid object provided")
		return
	end

	-- Cancel existing cleanup threads
	cancelCleanupThreads(object)

	-- Check the object itself if requested
	if includeObject and object:IsA("ParticleEmitter") then
		object.Enabled = false
		if not dontDestroy then
			local thread = task.delay(object.Lifetime.Max + 2, function()
				if object and object.Parent then
					object:Destroy()
				end
			end)
			trackCleanupThread(object, thread)
		end
	end

	-- Process all descendants
	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v.Enabled = false
			if not dontDestroy then
				local thread = task.delay(v.Lifetime.Max + 2, function()
					if v and v.Parent then
						v:Destroy()
					end
				end)
				trackCleanupThread(v, thread)
			end
		end
	end
end

--[=[
	Enables all ParticleEmitters in an object and its descendants
	@param object Instance -- The object to enable emitters in
	@param autoDisable boolean? -- If true, automatically disables and destroys after lifetime
	@param includeObject boolean? -- If true, also checks the root object itself
]=]
function Core.EnableDescendants(object: Instance, autoDisable: boolean?, includeObject: boolean?)
	if not object then
		warn("[ParticleEmitters] EnableDescendants: Invalid object provided")
		return
	end

	-- Cancel existing cleanup threads
	cancelCleanupThreads(object)

	-- Check the object itself if requested
	if includeObject and object:IsA("ParticleEmitter") then
		object.Enabled = true
		if autoDisable then
			local thread = task.delay(object.Lifetime.Max + 2, function()
				object.Enabled = false
				if object and object.Parent then
					object:Destroy()
				end
			end)
			trackCleanupThread(object, thread)
		end
	end

	-- Process all descendants
	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v.Enabled = true
			if autoDisable then
				local thread = task.delay(v.Lifetime.Max + 2, function()
					v.Enabled = false
					if v and v.Parent then
						v:Destroy()
					end
				end)
				trackCleanupThread(v, thread)
			end
		end
	end
end

--[=[
	Toggles ParticleEmitters and PointLights in an object
	@param object Instance -- The object to toggle effects in
	@param toggle boolean -- True to enable, false to disable
	@param includePointLights boolean? -- If false, only affects ParticleEmitters
]=]
function Core.ToggleEmitters(object: Instance, toggle: boolean, includePointLights: boolean?)
	if not object then
		warn("[ParticleEmitters] ToggleEmitters: Invalid object provided")
		return
	end

	includePointLights = includePointLights == nil and true or includePointLights

	for _, v in pairs(object:GetDescendants()) do
		if v:IsA("ParticleEmitter") then
			v.Enabled = toggle
		elseif includePointLights and v:IsA("PointLight") then
			v.Enabled = toggle
		end
	end
end

--[=[
	Cleans up all tracked cleanup threads
	Useful for preventing memory leaks when effects are destroyed externally
]=]
function Core.CleanupAllThreads()
	for _, threads in pairs(activeCleanupThreads) do
		for _, thread in ipairs(threads) do
			task.cancel(thread)
		end
	end
	activeCleanupThreads = {}
end

return Core
