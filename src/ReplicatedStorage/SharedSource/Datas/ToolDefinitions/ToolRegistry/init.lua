--!strict
-- ToolRegistry/init.lua
-- Central registry loader for all tool definitions
-- Automatically loads ALL subcategory files from Categories/[Category]/[Subcategory].lua
-- Just add new .lua files to any category folder and they'll be auto-loaded!

local Categories = script.Categories

-- ==========================================
-- AUTO-LOADER: Automatically loads all subcategory files
-- ==========================================
local function autoLoadSubcategories()
	local registry = {}
	
	-- Iterate through all category folders (Weapons, Consumables, Utilities, etc.)
	for _, categoryFolder in pairs(Categories:GetChildren()) do
		if categoryFolder:IsA("Folder") then
			local categoryName = categoryFolder.Name
			registry[categoryName] = {}
			
			-- Iterate through all ModuleScript files in this category
			for _, subcategoryModule in pairs(categoryFolder:GetChildren()) do
				if subcategoryModule:IsA("ModuleScript") then
					local subcategoryName = subcategoryModule.Name
					
					-- Require the module and add it to the registry
					local success, result = pcall(require, subcategoryModule)
					
					if success then
						registry[categoryName][subcategoryName] = result
						print(string.format("✅ Loaded: %s/%s", categoryName, subcategoryName))
					else
						warn(string.format("❌ Failed to load %s/%s: %s", categoryName, subcategoryName, tostring(result)))
					end
				end
			end
		end
	end
	
	return registry
end

-- Auto-load all subcategories and return the complete registry
return autoLoadSubcategories()
