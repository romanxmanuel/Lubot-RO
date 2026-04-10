--!strict
-- ToolTester.lua
-- Component for Tool Tester GUI - allows developers to test tools in-game

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Knit = require(ReplicatedStorage.Packages.Knit)

local ToolTester = {}

local plr = Players.LocalPlayer
local playerGui

---- Utilities
local ToolHelpers

---- Knit Controllers
local ToolController

---- References
local gui
local mainFrame
local searchBox
local toolsList
local equipButton
local unequipButton
local closeButton

---- State
local selectedToolId = nil
local allTools = {}
local filteredTools = {}

--[=[
	Initialize GUI references
]=]
local function initializeGUI()
	-- Wait for PlayerGui
	playerGui = plr:WaitForChild("PlayerGui")
	
	-- Wait for our GUI (it starts in StarterGui and gets cloned to PlayerGui)
	gui = playerGui:WaitForChild("ToolTesterGUI", 10)
	
	if not gui then
		warn("[ToolTester] ToolTesterGUI not found in PlayerGui!")
		return false
	end
	
	-- Get references
	mainFrame = gui:WaitForChild("MainFrame")
	local contentFrame = mainFrame:WaitForChild("ContentFrame")
	searchBox = contentFrame:WaitForChild("SearchBox")
	toolsList = contentFrame:WaitForChild("ToolsList")
	
	local titleBar = mainFrame:WaitForChild("TitleBar")
	closeButton = titleBar:WaitForChild("CloseButton")
	
	local buttonsFrame = contentFrame:WaitForChild("ButtonsFrame")
	equipButton = buttonsFrame:WaitForChild("EquipButton")
	unequipButton = buttonsFrame:WaitForChild("UnequipButton")
	
	return true
end

--[=[
	Load all available tools from the registry
]=]
local function loadAllTools()
	allTools = {}
	
	-- Get tool registry
	local ToolRegistry = require(ReplicatedStorage.SharedSource.Datas.ToolDefinitions.ToolRegistry)
	
	-- Iterate through all categories and subcategories
	for categoryName, category in pairs(ToolRegistry) do
		for subcategoryName, subcategory in pairs(category) do
			for toolId, toolData in pairs(subcategory) do
				table.insert(allTools, {
					ToolId = toolId,
					Category = categoryName,
					Subcategory = subcategoryName,
					Data = toolData,
				})
			end
		end
	end
	
	-- Sort by ToolId
	table.sort(allTools, function(a, b)
		return a.ToolId < b.ToolId
	end)
	
	print(string.format("[ToolTester] Loaded %d tools", #allTools))
	
	return allTools
end

--[=[
	Create a tool button in the list
]=]
local function createToolButton(toolInfo)
	local button = Instance.new("TextButton")
	button.Name = toolInfo.ToolId
	button.Size = UDim2.new(1, -16, 0, 40)
	button.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
	button.AutoButtonColor = false
	button.Text = ""
	button.Parent = toolsList
	
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = button
	
	local stroke = Instance.new("UIStroke")
	stroke.Name = "SelectStroke"
	stroke.Color = Color3.fromRGB(80, 80, 95)
	stroke.Thickness = 1
	stroke.Transparency = 0.7
	stroke.Parent = button
	
	-- Tool ID label
	local idLabel = Instance.new("TextLabel")
	idLabel.Name = "IdLabel"
	idLabel.Size = UDim2.new(0.7, 0, 0.5, 0)
	idLabel.Position = UDim2.new(0.05, 0, 0.05, 0)
	idLabel.BackgroundTransparency = 1
	idLabel.Text = toolInfo.ToolId
	idLabel.Font = Enum.Font.GothamBold
	idLabel.TextSize = 13
	idLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	idLabel.TextXAlignment = Enum.TextXAlignment.Left
	idLabel.TextTruncate = Enum.TextTruncate.AtEnd
	idLabel.Parent = button
	
	-- Category label
	local categoryLabel = Instance.new("TextLabel")
	categoryLabel.Name = "CategoryLabel"
	categoryLabel.Size = UDim2.new(0.9, 0, 0.4, 0)
	categoryLabel.Position = UDim2.new(0.05, 0, 0.55, 0)
	categoryLabel.BackgroundTransparency = 1
	categoryLabel.Text = string.format("%s / %s", toolInfo.Category, toolInfo.Subcategory)
	categoryLabel.Font = Enum.Font.Gotham
	categoryLabel.TextSize = 11
	categoryLabel.TextColor3 = Color3.fromRGB(150, 150, 160)
	categoryLabel.TextXAlignment = Enum.TextXAlignment.Left
	categoryLabel.TextTruncate = Enum.TextTruncate.AtEnd
	categoryLabel.Parent = button
	
	-- Hover effects
	button.MouseEnter:Connect(function()
		if selectedToolId ~= toolInfo.ToolId then
			button.BackgroundColor3 = Color3.fromRGB(55, 55, 65)
		end
	end)
	
	button.MouseLeave:Connect(function()
		if selectedToolId ~= toolInfo.ToolId then
			button.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
		end
	end)
	
	-- Click to select
	button.MouseButton1Click:Connect(function()
		-- Deselect previous
		if selectedToolId then
			local prevButton = toolsList:FindFirstChild(selectedToolId)
			if prevButton then
				prevButton.BackgroundColor3 = Color3.fromRGB(45, 45, 55)
				local prevStroke = prevButton:FindFirstChild("SelectStroke")
				if prevStroke then
					prevStroke.Color = Color3.fromRGB(80, 80, 95)
					prevStroke.Transparency = 0.7
					prevStroke.Thickness = 1
				end
			end
		end
		
		-- Select this tool
		selectedToolId = toolInfo.ToolId
		button.BackgroundColor3 = Color3.fromRGB(70, 100, 180)
		stroke.Color = Color3.fromRGB(100, 140, 240)
		stroke.Transparency = 0
		stroke.Thickness = 2
		
		print(string.format("[ToolTester] Selected: %s", toolInfo.ToolId))
	end)
	
	return button
end

--[=[
	Update the tools list display
]=]
local function updateToolsList(toolsToShow)
	-- Clear existing buttons
	for _, child in ipairs(toolsList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	
	-- Create buttons for filtered tools
	for _, toolInfo in ipairs(toolsToShow) do
		createToolButton(toolInfo)
	end
	
	-- Update canvas size (handled by AutomaticCanvasSize but we'll trigger it)
	toolsList.CanvasSize = UDim2.new(0, 0, 0, 0)
end

--[=[
	Filter tools based on search query
]=]
local function filterTools(query: string)
	query = query:lower()
	
	if query == "" then
		return allTools
	end
	
	local results = {}
	
	for _, toolInfo in ipairs(allTools) do
		-- Search in ToolId, Category, and Subcategory
		local searchText = string.format("%s %s %s", 
			toolInfo.ToolId:lower(),
			toolInfo.Category:lower(),
			toolInfo.Subcategory:lower()
		)
		
		if searchText:find(query, 1, true) then
			table.insert(results, toolInfo)
		end
	end
	
	return results
end

--[=[
	Handle search box input
]=]
local function setupSearch()
	searchBox:GetPropertyChangedSignal("Text"):Connect(function()
		local query = searchBox.Text
		filteredTools = filterTools(query)
		updateToolsList(filteredTools)
	end)
end

--[=[
	Handle equip button click
]=]
local function setupEquipButton()
	equipButton.MouseButton1Click:Connect(function()
		if not selectedToolId then
			warn("[ToolTester] No tool selected!")
			return
		end
		
		print(string.format("[ToolTester] Equipping tool: %s", selectedToolId))
		
		-- Use ToolController to equip
		ToolController:EquipToolLocal(selectedToolId)
			:andThen(function(success)
				if success then
					print(string.format("[ToolTester] ✅ Successfully equipped: %s", selectedToolId))
				else
					warn(string.format("[ToolTester] ❌ Failed to equip: %s", selectedToolId))
				end
			end)
			:catch(function(err)
				warn(string.format("[ToolTester] ❌ Error equipping tool: %s", tostring(err)))
			end)
	end)
	
	-- Hover effects
	equipButton.MouseEnter:Connect(function()
		equipButton.BackgroundColor3 = Color3.fromRGB(80, 200, 100)
	end)
	
	equipButton.MouseLeave:Connect(function()
		equipButton.BackgroundColor3 = Color3.fromRGB(70, 180, 90)
	end)
end

--[=[
	Handle unequip button click
]=]
local function setupUnequipButton()
	unequipButton.MouseButton1Click:Connect(function()
		print("[ToolTester] Unequipping tool")
		
		-- Use ToolController to unequip
		ToolController:UnequipToolLocal()
			:andThen(function(success)
				if success then
					print("[ToolTester] ✅ Successfully unequipped tool")
				else
					warn("[ToolTester] ❌ Failed to unequip tool")
				end
			end)
			:catch(function(err)
				warn(string.format("[ToolTester] ❌ Error unequipping tool: %s", tostring(err)))
			end)
	end)
	
	-- Hover effects
	unequipButton.MouseEnter:Connect(function()
		unequipButton.BackgroundColor3 = Color3.fromRGB(240, 90, 80)
	end)
	
	unequipButton.MouseLeave:Connect(function()
		unequipButton.BackgroundColor3 = Color3.fromRGB(220, 80, 70)
	end)
end

--[=[
	Handle close button click
]=]
local function setupCloseButton()
	closeButton.MouseButton1Click:Connect(function()
		mainFrame.Visible = false
		print("[ToolTester] GUI closed")
	end)
	
	-- Hover effects
	closeButton.MouseEnter:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(255, 70, 70)
	end)
	
	closeButton.MouseLeave:Connect(function()
		closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
	end)
end

--[=[
	Toggle GUI visibility (for external use)
]=]
function ToolTester:ToggleGUI()
	if mainFrame then
		mainFrame.Visible = not mainFrame.Visible
		print(string.format("[ToolTester] GUI visibility: %s", tostring(mainFrame.Visible)))
	end
end

--[=[
	Show the GUI
]=]
function ToolTester:ShowGUI()
	if mainFrame then
		mainFrame.Visible = true
		print("[ToolTester] GUI shown")
	end
end

--[=[
	Hide the GUI
]=]
function ToolTester:HideGUI()
	if mainFrame then
		mainFrame.Visible = false
		print("[ToolTester] GUI hidden")
	end
end

--[=[
	Refresh the tools list (useful if tools are added/removed dynamically)
]=]
function ToolTester:RefreshToolsList()
	allTools = loadAllTools()
	filteredTools = filterTools(searchBox.Text)
	updateToolsList(filteredTools)
	print("[ToolTester] Tools list refreshed")
end

function ToolTester.Start()
	-- Only run on client
	if not RunService:IsClient() then
		return
	end
	
	-- Initialize GUI
	local success = initializeGUI()
	if not success then
		warn("[ToolTester] Failed to initialize GUI")
		return
	end
	
	-- Load all tools
	allTools = loadAllTools()
	filteredTools = allTools
	
	-- Populate initial list
	updateToolsList(filteredTools)
	
	-- Setup interactions
	setupSearch()
	setupEquipButton()
	setupUnequipButton()
	setupCloseButton()
	
	print("[ToolTester] Component started successfully!")
end

function ToolTester.Init()
	-- Initialize references
	ToolController = Knit.GetController("ToolController")
	ToolHelpers = require(ReplicatedStorage.SharedSource.Utilities.ToolHelpers)
end

return ToolTester
