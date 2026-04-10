--[[
	QuestTypeManager.lua (Client)
	
	Auto-discovers quest type handlers from the Components/Others folder
	and manages their lifecycle (signal subscriptions, cleanup).
	
	This eliminates the need for hardcoded signal connections and cleanup calls
	in QuestController/init.lua.
	
	Handler Contract:
	- Each handler ending with "Handler" should implement GetHandlerConfig() returning:
		{
			TypeName = "PickUpItems",  -- Must match server-side Name
			SignalHandlers = {
				TrackPickupItems = "TrackPickupItems",  -- signal name → method name
			},
			RequiresCleanup = true,  -- Include in cleanup cycle
		}
	- If RequiresCleanup = true, handler MUST implement :CleanupAll()
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestTypeManager = {}

-- Store registered handlers
QuestTypeManager.RegisteredHandlers = {} -- { [typeName] = handlerModule }
QuestTypeManager.HandlersRequiringCleanup = {} -- Array of handlers that need cleanup
QuestTypeManager.SignalConnections = {} -- Array of RBXScriptConnection objects

---- Knit Services (set in Init)
local QuestService

--[[
	Get a registered handler by type name
	@param typeName string - The quest type name (e.g., "PickUpItems", "Delivery")
	@return table | nil - The handler module or nil if not found
]]
function QuestTypeManager:GetHandler(typeName)
	return QuestTypeManager.RegisteredHandlers[typeName]
end

--[[
	Get all registered handler type names
	@return table - Array of type names
]]
function QuestTypeManager:GetRegisteredTypeNames()
	local names = {}
	for typeName in pairs(QuestTypeManager.RegisteredHandlers) do
		table.insert(names, typeName)
	end
	return names
end

--[[
	Cleanup all handlers that require cleanup
	Called by QuestController when quest ends or player leaves
]]
function QuestTypeManager:CleanupAllHandlers()
	for _, handler in ipairs(QuestTypeManager.HandlersRequiringCleanup) do
		if handler.CleanupAll then
			local success, err = pcall(function()
				handler:CleanupAll()
			end)
			if not success then
				warn("[QuestTypeManager] Cleanup failed for handler:", err)
			end
		end
	end
end

--[[
	Register a single handler's signal subscriptions
	@param handler table - The handler module
	@param config table - The config from GetHandlerConfig()
]]
function QuestTypeManager:RegisterHandler(handler, config)
	local typeName = config.TypeName
	
	if QuestTypeManager.RegisteredHandlers[typeName] then
		warn("[QuestTypeManager] Handler already registered:", typeName)
		return
	end
	
	-- Store handler reference
	QuestTypeManager.RegisteredHandlers[typeName] = handler
	
	-- Track if handler requires cleanup
	if config.RequiresCleanup then
		if handler.CleanupAll then
			table.insert(QuestTypeManager.HandlersRequiringCleanup, handler)
		else
			warn("[QuestTypeManager] Handler", typeName, "requires cleanup but has no CleanupAll() method!")
		end
	end
	
	-- Connect signal handlers (deferred to Start phase)
	-- Signal subscriptions are stored but not connected yet
	handler._QuestTypeManagerSignalConfig = config.SignalHandlers
	
	print("[QuestTypeManager] Successfully registered handler:", typeName)
end

--[[
	Connect all signal handlers for registered handlers
	Called during Start phase after QuestService is fully available
]]
function QuestTypeManager:ConnectSignalHandlers()
	for typeName, handler in pairs(QuestTypeManager.RegisteredHandlers) do
		local signalConfig = handler._QuestTypeManagerSignalConfig
		if signalConfig then
			for signalName, methodName in pairs(signalConfig) do
				-- Get the signal from QuestService
				local signal = QuestService[signalName]
				if signal and signal.Connect then
					local connection = signal:Connect(function(...)
						if handler[methodName] then
							handler[methodName](handler, ...)
						else
							warn("[QuestTypeManager] Handler", typeName, "missing method:", methodName)
						end
					end)
					table.insert(QuestTypeManager.SignalConnections, connection)
					print("[QuestTypeManager] Connected signal:", signalName, "->", typeName .. ":" .. methodName)
				else
					warn("[QuestTypeManager] Signal not found on QuestService:", signalName)
				end
			end
			-- Clear the temp config
			handler._QuestTypeManagerSignalConfig = nil
		end
	end
end

--[[
	Scan the Components/Others folder and register all handlers
]]
function QuestTypeManager:DiscoverAndRegisterHandlers()
	-- Get the Others folder (where this script lives)
	local othersFolder = script.Parent
	
	-- Iterate through all modules ending with "Handler"
	for _, child in ipairs(othersFolder:GetChildren()) do
		if child:IsA("ModuleScript") and child.Name:match("Handler$") then
			-- Skip self
			if child == script then
				continue
			end
			
			local success, handler = pcall(function()
				return require(child)
			end)
			
			if success and handler then
				-- Check if handler has GetHandlerConfig function
				if typeof(handler.GetHandlerConfig) == "function" then
					local configSuccess, config = pcall(function()
						return handler.GetHandlerConfig()
					end)
					
					if configSuccess and config and config.TypeName then
						self:RegisterHandler(handler, config)
					else
						warn("[QuestTypeManager] GetHandlerConfig() failed or invalid for:", child.Name)
					end
				else
					-- Handler doesn't implement GetHandlerConfig - skip silently
					-- (this allows legacy handlers to coexist during migration)
					print("[QuestTypeManager] Handler missing GetHandlerConfig(), skipping:", child.Name)
				end
			else
				warn("[QuestTypeManager] Failed to require handler:", child.Name)
			end
		end
	end
	
	print("[QuestTypeManager] Discovery complete. Registered", #self:GetRegisteredTypeNames(), "handlers")
end

--[[
	Disconnect all signal connections
	Called during cleanup or when QuestController is destroyed
]]
function QuestTypeManager:DisconnectAllSignals()
	for _, connection in ipairs(QuestTypeManager.SignalConnections) do
		if connection and connection.Disconnect then
			connection:Disconnect()
		end
	end
	QuestTypeManager.SignalConnections = {}
end

--[[
	Initialize the QuestTypeManager
	Called by the component initializer during .Init() phase
]]
function QuestTypeManager.Init()
	-- Get QuestService reference
	QuestService = Knit.GetService("QuestService")
	
	-- Discover and register all handlers (but don't connect signals yet)
	QuestTypeManager:DiscoverAndRegisterHandlers()
end

--[[
	Start the QuestTypeManager
	Called by the component initializer during .Start() phase
]]
function QuestTypeManager.Start()
	-- Now connect all signal handlers (QuestService signals are fully available)
	QuestTypeManager:ConnectSignalHandlers()
end

return QuestTypeManager
