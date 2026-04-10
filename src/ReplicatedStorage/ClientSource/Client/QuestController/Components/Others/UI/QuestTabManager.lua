--[[
	QuestTabManager.lua
	
	Manages the Main/Side quest tab switching in the QuestFrame.
	Handles visual feedback and content visibility when switching between tabs.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Knit = require(ReplicatedStorage.Packages.Knit)

---- Utilities
local Utilities = ReplicatedStorage:WaitForChild("SharedSource"):WaitForChild("Utilities", 10)
local SoundPlayer = require(Utilities:WaitForChild("Audio"):WaitForChild("SoundPlayer", 10))

---- Sound References
local Assets = ReplicatedStorage:WaitForChild("Assets", 10)
local Sounds = Assets:WaitForChild("Sounds", 10)
local ClickSound = Sounds:WaitForChild("Click", 10)

local QuestTabManager = {}

---- Player Reference
local player = Players.LocalPlayer

---- UI References
local questGui
local questFrame
local mainButton
local sideButton
local mainContent
local sideContent

---- Tab State
local activeTab = "Main" -- Default to Main tab

---- Knit Controllers
local QuestController

--[[
	Initializes UI references
]]
function QuestTabManager:InitializeUI()
	local playerGui = player:WaitForChild("PlayerGui")
	if not playerGui then
		warn("[QuestTabManager] PlayerGui not found")
		return
	end
	
	questGui = playerGui:FindFirstChild("QuestGui") or playerGui:WaitForChild("QuestGui")
	if not questGui then
		warn("[QuestTabManager] QuestGui not found")
		return
	end
	
	questFrame = questGui:FindFirstChild("QuestFrame")
	if not questFrame then
		warn("[QuestTabManager] QuestFrame not found")
		return
	end
	
	-- Get tab buttons
	local tabButtons = questFrame:FindFirstChild("TabButtons")
	if tabButtons then
		mainButton = tabButtons:FindFirstChild("MainButton")
		sideButton = tabButtons:FindFirstChild("SideButton")
	end
	
	-- Get content containers
	mainContent = questFrame:FindFirstChild("MainQuestContent")
	sideContent = questFrame:FindFirstChild("SideQuestContent")
	
	if not mainButton or not sideButton then
		warn("[QuestTabManager] Tab buttons not found")
		return
	end
	
	if not mainContent or not sideContent then
		warn("[QuestTabManager] Content containers not found")
		return
	end
	
	-- Setup button connections
	self:SetupButtonConnections()
	
	-- Initialize to Main tab
	self:SwitchToTab("Main")
end

--[[
	Sets up button click connections
]]
function QuestTabManager:SetupButtonConnections()
	if mainButton then
		mainButton.MouseButton1Click:Connect(function()
			-- Play click sound
			SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))
			
			self:SwitchToTab("Main")
		end)
	end
	
	if sideButton then
		sideButton.MouseButton1Click:Connect(function()
			-- Play click sound
			SoundPlayer.Play(ClickSound, { Volume = 0.5 }, player:WaitForChild("PlayerGui"))
			
			self:SwitchToTab("Side")
		end)
	end
end

--[[
	Switches to the specified tab
	
	@param tabName string - "Main" or "Side"
]]
function QuestTabManager:SwitchToTab(tabName)
	if activeTab == tabName then
		return -- Already on this tab
	end
	
	activeTab = tabName
	questFrame:SetAttribute("ActiveTab", tabName)
	
	if tabName == "Main" then
		-- Update button styles
		self:SetButtonActive(mainButton, true)
		self:SetButtonActive(sideButton, false)
		
		-- Show main content, hide side content
		mainContent.Visible = true
		sideContent.Visible = false
		
		-- Update main quest UI
		if QuestController and QuestController.Components.MainQuestUI then
			QuestController.Components.MainQuestUI:UpdateQuestDisplay()
		end
		
	elseif tabName == "Side" then
		-- Update button styles
		self:SetButtonActive(mainButton, false)
		self:SetButtonActive(sideButton, true)
		
		-- Show side content, hide main content
		mainContent.Visible = false
		sideContent.Visible = true
		
		-- Update side quest UI
		if QuestController and QuestController.Components.SideQuestUI then
			QuestController.Components.SideQuestUI:UpdateQuestsList()
		end
	end
end

--[[
	Updates button visual style based on active state
	
	@param button TextButton - The button to update
	@param isActive boolean - Whether the button is active
]]
function QuestTabManager:SetButtonActive(button, isActive)
	if not button then return end
	
	local tweenInfo = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	
	if isActive then
		-- Active button style
		local activeTween = TweenService:Create(button, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(45, 125, 255),
			TextColor3 = Color3.fromRGB(255, 255, 255)
		})
		activeTween:Play()
		
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			local strokeTween = TweenService:Create(stroke, tweenInfo, {
				Color = Color3.fromRGB(255, 255, 255),
				Transparency = 0.7
			})
			strokeTween:Play()
		end
	else
		-- Inactive button style
		local inactiveTween = TweenService:Create(button, tweenInfo, {
			BackgroundColor3 = Color3.fromRGB(70, 70, 70),
			TextColor3 = Color3.fromRGB(200, 200, 200)
		})
		inactiveTween:Play()
		
		local stroke = button:FindFirstChildOfClass("UIStroke")
		if stroke then
			local strokeTween = TweenService:Create(stroke, tweenInfo, {
				Color = Color3.fromRGB(150, 150, 150),
				Transparency = 0.7
			})
			strokeTween:Play()
		end
	end
end

--[[
	Gets the currently active tab
	
	@return string - "Main" or "Side"
]]
function QuestTabManager:GetActiveTab()
	return activeTab
end

function QuestTabManager.Start()
	-- Initialize UI after a brief delay to ensure GUI is loaded
	task.delay(0.5, function()
		QuestTabManager:InitializeUI()
	end)
end

function QuestTabManager.Init()
	-- Initialize controllers
	QuestController = Knit.GetController("QuestController")
end

return QuestTabManager
