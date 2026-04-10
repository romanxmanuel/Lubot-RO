--[[
    QuestUIManager.lua
    
    Manages quest UI state and animation queues.
    Prevents animation conflicts and manages UI visibility.
    
    Phase 11: Client UI Refactoring
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer

local QuestUIManager = {}

---- UI State
local isCurrentlyAnimating = false
local animationQueue = {}
local questGuiEnabled = true

---- Quest GUI Reference
local questGui

--[[
    Initializes the UI manager with the quest GUI reference
    
    @param gui ScreenGui - The quest GUI instance
]]
function QuestUIManager:Initialize(gui)
	questGui = gui
	if questGui then
		questGuiEnabled = questGui.Enabled
	end
end

--[[
    Checks if animations can currently be played
    
    @return boolean - True if animations can play
]]
function QuestUIManager:CanAnimate()
	return not isCurrentlyAnimating and questGuiEnabled and questGui and questGui.Enabled
end

--[[
    Queues an animation to be played later
    
    @param animationType string - The animation function name
    @param args table - Arguments for the animation
]]
function QuestUIManager:QueueAnimation(animationType, args)
	table.insert(animationQueue, {
		funcName = animationType,
		func = self[animationType],
		args = args or {},
	})

	-- Try to process queue if not animating
	if not isCurrentlyAnimating then
		self:ProcessQueue()
	end
end

--[[
    Processes the animation queue
]]
function QuestUIManager:ProcessQueue()
	if isCurrentlyAnimating then
		return
	end

	while #animationQueue > 0 and not isCurrentlyAnimating do
		local animData = table.remove(animationQueue, 1)

		if animData.func then
			isCurrentlyAnimating = true
			task.spawn(function()
				local success, err = pcall(function()
					animData.func(table.unpack(animData.args))
				end)

				if not success then
					warn("Animation failed:", err)
				end

				isCurrentlyAnimating = false

				-- Continue processing queue
				self:ProcessQueue()
			end)
		end
	end
end

--[[
    Plays an animation immediately or queues it
    
    @param animationType string - The animation function name
    @param ... any - Arguments for the animation
]]
function QuestUIManager:PlayAnimation(animationType, ...)
	if not self:CanAnimate() then
		self:QueueAnimation(animationType, { ... })
		return
	end

	local args = { ... } -- Capture varargs before nested functions
	isCurrentlyAnimating = true
	task.spawn(function()
		local success, err = pcall(function()
			if self[animationType] then
				self[animationType](table.unpack(args))
			else
				warn("Animation type not found:", animationType)
			end
		end)

		if not success then
			warn("Animation failed:", err)
		end

		isCurrentlyAnimating = false

		-- Process any queued animations
		self:ProcessQueue()
	end)
end

--[[
    Sets the UI enabled state
    
    @param enabled boolean - Whether UI should be enabled
]]
function QuestUIManager:SetUIEnabled(enabled)
	questGuiEnabled = enabled
	if questGui then
		questGui.Enabled = enabled
	end
end

--[[
    Gets the current UI enabled state
    
    @return boolean - Whether UI is enabled
]]
function QuestUIManager:IsUIEnabled()
	return questGuiEnabled and questGui and questGui.Enabled
end

--[[
    Clears all queued animations
]]
function QuestUIManager:ClearQueue()
	animationQueue = {}
	isCurrentlyAnimating = false
end

function QuestUIManager.Init()
	-- Try to find quest GUI
	task.spawn(function()
		local playerGui = player:WaitForChild("PlayerGui")
		if playerGui then
			local gui = playerGui:FindFirstChild("QuestGui") or playerGui:WaitForChild("QuestGui")
			if gui then
				QuestUIManager:Initialize(gui)
			else
				warn("QuestGui not found in PlayerGui")
			end
		end
	end)
end

function QuestUIManager.Start()
	-- Startup logic
end

return QuestUIManager
