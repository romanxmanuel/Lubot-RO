--[[
PLACE:
ReplicatedStorage.GameParts.ImportedAssets

WHAT THIS IS:
Raw marketplace imports that should keep their original scripts and structure.

RULES:
- Each imported asset gets its own folder.
- Keep the untouched source package inside SourcePackage.
- If the asset exposes a usable Tool, keep a clone as ToolTemplate.
- Runtime systems clone ToolTemplate into player backpacks.
- Do not rewrite or rebuild imported scripts unless Roman explicitly asks.
]]

return {}
