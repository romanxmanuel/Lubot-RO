# Activation Types

This folder documents the two activation types supported by the Tool Framework.

## Overview

| Type | Description | Detection Method |
|------|-------------|------------------|
| **[Click](./Click.md)** | Single activation per click (default) | No `OnButtonDown` callback |
| **[Hold](./Hold.md)** | Continuous activation while held | Has `OnButtonDown` callback |

## Quick Reference

### Click (Default)
- One click = one activation
- Implement `Activate()` (server) and `OnActivate()` (client)
- Use for: Melee weapons, throwables, consumables, toggle items

### Hold
- Continuous action while button held
- Implement `OnButtonDown()` and `OnButtonUp()` on both client and server
- Use for: Spray tools, beam weapons, charge tools, mining tools

## Important Note

**The framework detects Hold tools by checking for the presence of `OnButtonDown` callback in the module, NOT by reading the `ActivationType` field in the tool definition.**

The `ActivationType` field is for documentation purposes only - it helps developers understand the intended behavior at a glance.

```lua
-- This makes it a Hold tool (callback presence):
function ToolModule:OnButtonDown(player, toolData)
    -- ...
end

-- NOT this (documentation only):
BehaviorConfig = {
    ActivationType = "Hold", -- This is just a hint for developers
}
```
