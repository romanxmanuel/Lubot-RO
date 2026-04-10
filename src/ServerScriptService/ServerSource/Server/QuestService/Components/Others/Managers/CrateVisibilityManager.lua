--[[
	CrateVisibilityManager.lua
	
	Server-side component that manages the visibility of wood crates
	in the Pickup_Item_Quest_Test folder.
	
	Makes crates invisible at startup and provides functions to show/hide them.
]]

local CrateVisibilityManager = {}

-- Folder containing the test crates
local CRATES_FOLDER_NAME = "Pickup_Item_Quest_Test"

--[[
	Set visibility of all parts in a model
	@param model Model - The model containing parts
	@param visible boolean - True to show, false to hide
]]
local function setModelVisibility(model, visible)
	if not model then return end
	
	for _, descendant in pairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = visible and 0 or 1
			descendant.CanCollide = visible
		end
	end
end

--[[
	Ensure ProximityPrompt exists on a crate
	@param model Model - The wood crate model
]]
local function ensureProximityPrompt(model)
	if not model then return end
	
	-- Find the Center part or PrimaryPart
	local centerPart = model:FindFirstChild("Center") or model.PrimaryPart
	if not centerPart or not centerPart:IsA("BasePart") then
		warn("[CrateVisibilityManager] Could not find center part for", model.Name)
		return
	end
	
	-- Check if ProximityPrompt already exists
	local existingPrompt = centerPart:FindFirstChild("ProximityPrompt")
	if existingPrompt then
		return -- Already has prompt
	end
	
	-- Create ProximityPrompt
	local proximityPrompt = Instance.new("ProximityPrompt")
	proximityPrompt.Name = "ProximityPrompt"
	proximityPrompt.ActionText = "Pick Up"
	proximityPrompt.ObjectText = "Wood Crate"
	proximityPrompt.MaxActivationDistance = 8
	proximityPrompt.RequiresLineOfSight = false
	proximityPrompt.KeyboardKeyCode = Enum.KeyCode.E
	proximityPrompt.HoldDuration = 0.5
	proximityPrompt.Parent = centerPart
end

--[[
	Hide all wood crates in the test folder
]]
function CrateVisibilityManager:HideAllCrates()
	local cratesFolder = workspace:FindFirstChild(CRATES_FOLDER_NAME)
	
	if not cratesFolder then
		warn("[CrateVisibilityManager] Crates folder not found:", CRATES_FOLDER_NAME)
		return false
	end
	
	local crateCount = 0
	for _, child in pairs(cratesFolder:GetChildren()) do
		if child:IsA("Model") and child.Name:match("^Wood Crate") then
			-- Make invisible
			setModelVisibility(child, false)
			
			-- Disable ProximityPrompt
			local centerPart = child:FindFirstChild("Center") or child.PrimaryPart
			if centerPart then
				local prompt = centerPart:FindFirstChild("ProximityPrompt")
				if prompt then
					prompt.Enabled = false
				end
			end
			
			crateCount = crateCount + 1
		end
	end
	
	return true
end

--[[
	Show all wood crates in the test folder
]]
function CrateVisibilityManager:ShowAllCrates()
	local cratesFolder = workspace:FindFirstChild(CRATES_FOLDER_NAME)
	
	if not cratesFolder then
		warn("[CrateVisibilityManager] Crates folder not found:", CRATES_FOLDER_NAME)
		return false
	end
	
	local crateCount = 0
	for _, child in pairs(cratesFolder:GetChildren()) do
		if child:IsA("Model") and child.Name:match("^Wood Crate") then
			-- Ensure ProximityPrompt exists
			ensureProximityPrompt(child)
			
			-- Make visible
			setModelVisibility(child, true)
			
			-- Enable ProximityPrompt
			local centerPart = child:FindFirstChild("Center") or child.PrimaryPart
			if centerPart then
				local prompt = centerPart:FindFirstChild("ProximityPrompt")
				if prompt then
					prompt.Enabled = true
				end
			end
			
			crateCount = crateCount + 1
		end
	end
	
	return true
end

--[[
	Initialize - hide all crates at startup
]]
function CrateVisibilityManager.Init()
	-- Wait a moment for workspace to fully load
	task.wait(1)
	
	CrateVisibilityManager:HideAllCrates()
end

function CrateVisibilityManager.Start()
	-- Component started
end

return CrateVisibilityManager
