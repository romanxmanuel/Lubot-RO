local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)
local Signal = require(ReplicatedStorage.Packages.Signal)

local LevelController = Knit.CreateController({
	Name = "LevelController",
	Instance = script,
	-- Signals for UI updates
	DataChanged = Signal.new(),
	LevelUp = Signal.new(),
	ExpGained = Signal.new(),
	Rebirthed = Signal.new()
})

---- Controllers
local DataController

---- Config
local LevelingConfig = require(ReplicatedStorage.SharedSource.Datas.LevelingConfig)

---- Internal State
local lastKnownLevels = {}

-- Public API Methods
function LevelController:GetLevelData(levelType)
	return LevelController.GetComponent:GetLevelData(levelType)
end

function LevelController:GetAllLevelData()
	return LevelController.GetComponent:GetAllLevelData()
end

function LevelController:GetProgressPercent(levelType)
	return LevelController.GetComponent:GetProgressPercent(levelType)
end

function LevelController:IsLevelType(levelType)
	return LevelController.GetComponent:IsLevelType(levelType)
end

-- Rebirth Methods
function LevelController:CanRebirth(levelType)
	return LevelController.GetComponent:CanRebirth(levelType)
end

function LevelController:GetMaxLevel(levelType)
	return LevelController.GetComponent:GetMaxLevel(levelType)
end

function LevelController:GetRebirthEligibility(levelType)
	return LevelController.GetComponent:GetRebirthEligibility(levelType)
end

function LevelController:PerformRebirth(levelType)
	local LevelService = Knit.GetService("LevelService")
	return LevelService:PerformRebirth(levelType)
end

-- UI Management Methods
function LevelController:BuildUI()
	local plr = game.Players.LocalPlayer
	local levelSystemTemplate = plr.PlayerGui:FindFirstChild("LevelSystemUI")
	if levelSystemTemplate then
		levelSystemTemplate:Destroy()
	end

	LevelController.Components.UI:BuildMainUI()
end

function LevelController:UpdateUI()
	LevelController.Components.UI:UpdateAllDisplays()
	if LevelController.Components.RebirthUI then
		LevelController.Components.RebirthUI:UpdateLevelTypeDisplay()
	end
end

function LevelController:ShowLevelUpEffect(levelType, newLevel)
	LevelController.Components.UI:ShowLevelUpEffect(levelType, newLevel)
end

-- Rebirth UI Methods
function LevelController:ShowRebirthUI(levelType)
	LevelController.Components.RebirthUI:ShowRebirthUI(levelType)
end

function LevelController:HideRebirthUI()
	if LevelController.Components.RebirthUI then
		local playerGui = game.Players.LocalPlayer:WaitForChild("PlayerGui")
		local rebirthUI = playerGui:FindFirstChild("RebirthSystemUI")
		if rebirthUI then
			rebirthUI.Enabled = false
		end
	end
end

-- Internal Methods
function LevelController:_CheckForLevelChanges()
	local currentData = self:GetAllLevelData()

	for levelType, data in pairs(currentData) do
		local lastLevel = lastKnownLevels[levelType]
		if lastLevel and lastLevel < data.Level then
			-- Level up detected!
			self.LevelUp:Fire(levelType, data.Level, lastLevel)
			self:ShowLevelUpEffect(levelType, data.Level)
		end
		lastKnownLevels[levelType] = data.Level
	end
end

function LevelController:_OnDataUpdate()
	-- Check for level changes first
	self:_CheckForLevelChanges()

	-- Fire general data change signal
	self.DataChanged:Fire()

	-- Update UI
	self:UpdateUI()
end

function LevelController:KnitStart()
	-- Wait for data to be available
	DataController:WaitUntilProfileLoaded()

	-- Initialize last known levels
	local initialData = self:GetAllLevelData()
	for levelType, data in pairs(initialData) do
		lastKnownLevels[levelType] = data.Level
	end

	-- Set up data change monitoring
	DataController.DataChanged = DataController.DataChanged or Signal.new()
	DataController.DataChanged:Connect(function()
		self:_OnDataUpdate()
	end)

	-- Connect to server level up signals
	local LevelService = Knit.GetService("LevelService")
	if LevelService and LevelService.LevelUp then
		LevelService.LevelUp:Connect(function(levelType, newLevel, oldLevel)
			self.LevelUp:Fire(levelType, newLevel, oldLevel)
			self:ShowLevelUpEffect(levelType, newLevel)
			print(string.format("[LevelController] LEVEL UP! %s: %d -> %d", levelType, oldLevel, newLevel))
		end)
	end

	-- Connect to server rebirth signals
	if LevelService and LevelService.Rebirthed then
		LevelService.Rebirthed:Connect(function(levelType, newRebirthCount)
			self.Rebirthed:Fire(levelType, newRebirthCount)
			print(string.format("[LevelController] REBIRTHED! %s - Count: %d", levelType, newRebirthCount))
		end)
	end

	-- Build initial UI
	self:BuildUI()

	-- R key removed - use individual rebirth buttons on each level type frame instead

	-- Connect to ProfileService data updates if available
	task.spawn(function()
		while true do
			local newData = DataController:GetPlayerData()
			if newData then
				self:_OnDataUpdate()
			end
			task.wait(0.1) -- Check for updates regularly
		end
	end)
end

function LevelController:KnitInit()
	DataController = Knit.GetController("DataController")
end

return LevelController
