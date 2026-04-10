--[[
PLACE:
ReplicatedStorage.GameParts.ImportedAssets

WHAT THIS IS:
Raw marketplace imports that should keep their original scripts and structure.

RULES:
- Each imported asset gets its own folder.
- Keep the untouched source package inside SourcePackage.
- If the asset exposes a usable Tool, keep a clone as ToolTemplate.
- Skin model imports should keep SourcePackage under a skin-specific folder.
- Skin templates used by CharacterSkinService should live in ReplicatedStorage.GameParts.PlayerCharacters.
- Runtime systems clone ToolTemplate into player backpacks.
- Do not rewrite or rebuild imported scripts unless Roman explicitly asks.

CURRENT SKIN IMPORT FOLDERS:
- Skins/GojoWhite_91131914057854
- Skins/Luffy_9465786796
- Skins/LuffyGear5_10039008438
]]

return {}
