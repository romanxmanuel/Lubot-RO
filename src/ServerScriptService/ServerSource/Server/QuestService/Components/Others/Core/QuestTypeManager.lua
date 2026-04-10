--[[
	QuestTypeManager.lua (Server)
	
	Auto-discovers quest type handlers from the Types/ folder and registers
	their signals and client methods with QuestService via Knit.
	
	This eliminates the need for hardcoded signal/method declarations in QuestService/init.lua.
	
	Handler Contract:
	- Each handler in Types/ must implement GetRegistration() returning:
		{
			Name = "PickUpItems",  -- Unique type identifier
			Signals = { "TrackPickupItems" },  -- Signals to create (server→client)
			ClientMethods = {
				{ Name = "ValidateItemPickup", Handler = "ValidateAndProcessPickup" },
			},
		}
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Knit = require(ReplicatedStorage.Packages.Knit)

local QuestTypeManager = {}

-- Store registered handlers
QuestTypeManager.RegisteredHandlers = {} -- { [typeName] = handlerModule }
QuestTypeManager.RegisteredSignals = {} -- { [signalName] = true }
QuestTypeManager.RegisteredMethods = {} -- { [methodName] = { handler, handlerMethodName } }

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
	Register a single handler's signals and methods
	@param handler table - The handler module
	@param registration table - The registration config from GetRegistration()
]]
function QuestTypeManager:RegisterHandler(handler, registration)
	local typeName = registration.Name
	
	if QuestTypeManager.RegisteredHandlers[typeName] then
		warn("[QuestTypeManager] Handler already registered:", typeName)
		return
	end
	
	-- Store handler reference
	QuestTypeManager.RegisteredHandlers[typeName] = handler
	
	-- Register signals
	if registration.Signals then
		for _, signalName in ipairs(registration.Signals) do
			if not QuestTypeManager.RegisteredSignals[signalName] then
				-- Register signal with Knit (available to client)
				local signal = Knit.RegisterClientSignal(QuestService, signalName)
				QuestTypeManager.RegisteredSignals[signalName] = signal
				print("[QuestTypeManager] Registered signal:", signalName)
			else
				warn("[QuestTypeManager] Signal already registered:", signalName)
			end
		end
	end
	
	-- Register client methods
	if registration.ClientMethods then
		for _, methodConfig in ipairs(registration.ClientMethods) do
			local methodName = methodConfig.Name
			local handlerMethodName = methodConfig.Handler
			
			if not QuestTypeManager.RegisteredMethods[methodName] then
				-- Store method routing info
				QuestTypeManager.RegisteredMethods[methodName] = {
					handler = handler,
					handlerMethodName = handlerMethodName,
				}
				
				-- Register method with Knit that routes to handler
				local remoteMethod = Knit.RegisterClientMethod(QuestService, methodName)
				remoteMethod.OnServerInvoke = function(self, player, ...)
					local routeInfo = QuestTypeManager.RegisteredMethods[methodName]
					if routeInfo and routeInfo.handler and routeInfo.handler[routeInfo.handlerMethodName] then
						return routeInfo.handler[routeInfo.handlerMethodName](routeInfo.handler, player, ...)
					else
						warn("[QuestTypeManager] No handler found for method:", methodName)
						return nil
					end
				end
				
				print("[QuestTypeManager] Registered client method:", methodName, "->", typeName .. ":" .. handlerMethodName)
			else
				warn("[QuestTypeManager] Method already registered:", methodName)
			end
		end
	end
	
	print("[QuestTypeManager] Successfully registered handler:", typeName)
end

--[[
	Scan the Types/ folder and register all handlers
]]
function QuestTypeManager:DiscoverAndRegisterHandlers()
	-- Navigate to the Types folder
	local typesFolder = script.Parent.Parent.TriggeredQuest:FindFirstChild("Types")
	if not typesFolder then
		warn("[QuestTypeManager] Types folder not found at script.Parent.Parent.TriggeredQuest.Types")
		return
	end
	
	-- Iterate through all modules in Types/
	for _, child in ipairs(typesFolder:GetChildren()) do
		if child:IsA("ModuleScript") then
			local success, handler = pcall(function()
				return require(child)
			end)
			
			if success and handler then
				-- Check if handler has GetRegistration function
				if typeof(handler.GetRegistration) == "function" then
					local regSuccess, registration = pcall(function()
						return handler.GetRegistration()
					end)
					
					if regSuccess and registration and registration.Name then
						self:RegisterHandler(handler, registration)
					else
						warn("[QuestTypeManager] GetRegistration() failed or invalid for:", child.Name)
					end
				else
					-- Handler doesn't implement GetRegistration - skip silently
					-- (this allows legacy handlers to coexist during migration)
					print("[QuestTypeManager] Handler missing GetRegistration(), skipping:", child.Name)
				end
			else
				warn("[QuestTypeManager] Failed to require handler:", child.Name)
			end
		end
	end
	
	print("[QuestTypeManager] Discovery complete. Registered", #self:GetRegisteredTypeNames(), "handlers")
end

--[[
	Initialize the QuestTypeManager
	Called by the component initializer during .Init() phase
]]
function QuestTypeManager.Init()
	-- Get QuestService reference
	QuestService = Knit.GetService("QuestService")
	
	-- Discover and register all handlers
	QuestTypeManager:DiscoverAndRegisterHandlers()
end

function QuestTypeManager.Start()
	-- Nothing to do in Start phase
end

return QuestTypeManager
