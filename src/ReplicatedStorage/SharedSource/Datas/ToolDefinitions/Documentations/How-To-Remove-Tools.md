# 🗑️ How to Remove Tools

This guide explains how to safely remove tools from your game's Tool Framework.

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Complete Removal Process](#complete-removal-process)
3. [Step-by-Step Instructions](#step-by-step-instructions)
4. [Common Scenarios](#common-scenarios)
5. [Important Warnings](#important-warnings)
6. [Troubleshooting](#troubleshooting)

---

## 🎯 Overview

The Tool Framework stores tool data in multiple locations. To completely remove a tool, you need to:

1. **Remove the tool definition** from the ToolRegistry
2. **Remove the tool asset** from ReplicatedStorage.Assets.Tools
3. **Remove the tool module** from the appropriate location (Client or Server)
4. **Clean up any references** in your code

---

## 🔄 Complete Removal Process

### Location Map

```
Tool Framework Structure:
├── 📁 Tool Definition (Data)
│   └── SharedSource/Datas/ToolDefinitions/ToolRegistry/Categories/[Category]/[Subcategory].lua
├── 📁 Tool Asset (Visual)
│   └── Assets/Tools/[Category]/[Subcategory]/[ToolName]
├── 📁 Tool Module (Client Behavior) - OPTIONAL
│   └── ClientSource/Client/ToolController/Tools/Categories/[Category]/[Subcategory]/[ToolId].lua
└── 📁 Tool Module (Server Behavior) - OPTIONAL
    └── ServerSource/Server/ToolService/Tools/Categories/[Category]/[Subcategory]/[ToolId].lua
```

---

## 📝 Step-by-Step Instructions

### Step 1: Identify the Tool to Remove

First, identify the tool's complete information:
- **ToolId**: The unique identifier (e.g., `sword_classic`)
- **Category**: Main category (e.g., `Weapons`)
- **Subcategory**: Sub-category (e.g., `Swords`)
- **Asset Name**: The Tool instance name (e.g., `ClassicSword`)

You can find this information:
1. Open the **Tool Tester GUI** (F8 to open console, type command to show GUI)
2. Search for your tool in the list
3. Note down the ToolId and path shown

### Step 2: Remove Tool Definition

**Location:** `SharedSource/Datas/ToolDefinitions/ToolRegistry/Categories/[Category]/[Subcategory].lua`

**Example:** To remove `sword_classic` from `Weapons/Swords`:

1. Navigate to: `SharedSource/Datas/ToolDefinitions/ToolRegistry/Categories/Weapons/Swords.lua`
2. Open the file in your code editor
3. Find the tool definition block:

```lua
sword_classic = {
    ToolId = "sword_classic",
    Category = "Weapons",
    Subcategory = "Swords",
    Stats = { ... },
    BehaviorConfig = { ... },
    -- ... other properties
},
```

4. **Delete the entire block** (including the comma after the closing brace)
5. Save the file

### Step 3: Remove Tool Asset

**Location:** `Assets/Tools/[Category]/[Subcategory]/[ToolName]`

**Example:** To remove the ClassicSword asset:

1. Open Roblox Studio
2. Navigate to: `ReplicatedStorage → Assets → Tools → Weapons → Swords`
3. Find the `ClassicSword` Tool instance
4. **Right-click → Delete** or press `Delete` key
5. The Tool instance will be removed from the Explorer

### Step 4: Remove Tool Module (If Exists)

**⚠️ Note:** Not all tools have custom modules. Only remove if the module exists.

#### Client Module Location
`ClientSource/Client/ToolController/Tools/Categories/[Category]/[Subcategory]/[ToolId].lua`

#### Server Module Location
`ServerSource/Server/ToolService/Tools/Categories/[Category]/[Subcategory]/[ToolId].lua`

**Example:** To remove `sword_classic` module:

1. Check if the file exists at: `ClientSource/Client/ToolController/Tools/Categories/Weapons/Swords/sword_classic.lua`
2. If it exists, **delete the file**
3. Check the server location and delete if exists: `ServerSource/Server/ToolService/Tools/Categories/Weapons/Swords/sword_classic.lua`

### Step 5: Clean Up Code References

Search your codebase for any hardcoded references to the removed tool:

```lua
-- Search for patterns like:
"sword_classic"
ToolHelpers.GetToolData("sword_classic")
ToolController:EquipToolLocal("sword_classic")
```

Remove or replace these references as needed.

### Step 6: Test the Removal

1. **Restart the game** in Roblox Studio (Stop and Play again)
2. Open the **Tool Tester GUI**
3. Search for the removed tool - it should NOT appear in the list
4. Try to equip it manually (if you have code that tries) - it should fail gracefully with a warning

---

## 🎯 Common Scenarios

### Removing an Entire Subcategory

If you want to remove all tools in a subcategory (e.g., all `Swords`):

1. **Delete the subcategory file**: `ToolRegistry/Categories/Weapons/Swords.lua`
2. **Delete the asset folder**: `Assets/Tools/Weapons/Swords/`
3. **Delete the modules folder** (if exists): 
   - Client: `ToolController/Tools/Categories/Weapons/Swords/`
   - Server: `ToolService/Tools/Categories/Weapons/Swords/`

### Removing an Entire Category

If you want to remove an entire category (e.g., all `Weapons`):

1. **Delete the category folder** in ToolRegistry: `ToolRegistry/Categories/Weapons/`
2. **Delete the asset folder**: `Assets/Tools/Weapons/`
3. **Delete the modules folder** (if exists):
   - Client: `ToolController/Tools/Categories/Weapons/`
   - Server: `ToolService/Tools/Categories/Weapons/`

### Temporarily Disabling a Tool

If you want to temporarily disable a tool without removing it:

1. Add a `Disabled = true` field to the tool definition:

```lua
sword_classic = {
    ToolId = "sword_classic",
    Category = "Weapons",
    Subcategory = "Swords",
    Disabled = true, -- Add this line
    -- ... rest of the definition
},
```

2. Modify your equip logic to check for the `Disabled` field:

```lua
local toolData = ToolHelpers.GetToolData(toolId)
if toolData and toolData.Disabled then
    warn("This tool is currently disabled")
    return false
end
```

---

## ⚠️ Important Warnings

### DO NOT Do These:

❌ **DON'T delete only the tool definition** - This will cause errors when the system tries to load the asset

❌ **DON'T delete only the tool asset** - This will cause errors when trying to equip the tool

❌ **DON'T forget to clean up references** - Hardcoded tool IDs in your code will cause warnings

❌ **DON'T remove tools while players have them equipped** - Always test in a development environment first

### DO These:

✅ **DO remove the complete set** - Definition, Asset, and Module (if exists)

✅ **DO restart the game** after removal to ensure clean state

✅ **DO test thoroughly** before pushing to production

✅ **DO backup your files** before making bulk removals

---

## 🔧 Troubleshooting

### "Tool not found" warnings after removal

**Cause:** Code still references the removed tool

**Solution:** Search your codebase for the tool ID and remove/replace references

### Tool still appears in Tool Tester

**Cause:** Game not restarted after removal

**Solution:** Stop and restart the game in Roblox Studio

### Error when equipping a different tool

**Cause:** Incomplete removal - asset exists but definition is missing (or vice versa)

**Solution:** Follow the complete removal process for all components

### ToolRegistry loading errors

**Cause:** Syntax error in the subcategory file after deletion (missing comma, extra comma)

**Solution:** Check the file for proper Lua syntax:

```lua
-- ✅ CORRECT:
return {
    tool_one = { ... },
    tool_two = { ... }, -- Comma after last entry is OK
}

-- ❌ INCORRECT:
return {
    tool_one = { ... },
    tool_two = { ... }
    tool_three = { ... }, -- Missing comma
}
```

---

## 📚 Related Documentation

- **Tool Framework Guide**: `documentations/codebase/Tool-Framework-Guide.md`
- **Architecture Overview**: `SharedSource/Datas/ToolDefinitions/Documentations/Architecture.md`
- **Adding New Tools**: See Tool Framework Guide for tool creation process

---

## 🎯 Quick Reference Checklist

Use this checklist when removing a tool:

- [ ] Identified ToolId, Category, Subcategory
- [ ] Removed tool definition from ToolRegistry
- [ ] Removed tool asset from Assets folder
- [ ] Removed tool module(s) from Client/Server (if exists)
- [ ] Searched and removed code references
- [ ] Restarted game in Studio
- [ ] Tested that tool no longer appears
- [ ] Verified no errors in output

---

## 💡 Best Practices

1. **Document removals**: Keep a changelog of removed tools for your team
2. **Use version control**: Commit before bulk removals so you can revert if needed
3. **Test in development**: Never remove tools directly in a live/production environment
4. **Communicate with team**: If working with others, notify them of tool removals
5. **Consider deprecation**: For tools in use, consider deprecating first before removing

---

**Last Updated:** 2025
**Framework Version:** SuperbulletFramework Tool System v1.0
