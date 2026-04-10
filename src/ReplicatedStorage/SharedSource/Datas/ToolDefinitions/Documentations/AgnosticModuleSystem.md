# Agnostic Module System & Server-Client Architecture

> **Navigation:** This is a detailed deep-dive document. For high-level overview, see [Architecture.md](./Architecture.md).

---

## Table of Contents

1. [Agnostic Module System Overview](#agnostic-module-system-overview)
2. [Full Mode (Server + Client Modules)](#1-full-mode-server--client-modules)
3. [Server-Only Mode](#2-server-only-mode)
4. [Client-Only Mode](#3-client-only-mode)
5. [Client-Server Architecture](#client-server-architecture)
6. [Deduplication Mechanism](#deduplication-mechanism)
7. [Design Decisions](#design-decisions)

---

## Agnostic Module System Overview

The Tool Framework supports three operational modes, each with different client-server responsibilities. This flexibility allows tools to be implemented with the appropriate level of complexity for their use case.

| Mode | Client Module | Server Module | Use Case |
|------|---------------|---------------|----------|
| **Full Mode** | ✅ Yes | ✅ Yes | Combat, complex abilities, multiplayer |
| **Server-Only** | ❌ No | ✅ Yes | Admin tools, simple utilities |
| **Client-Only** | ✅ Yes | ❌ No | Cosmetics, emotes, single-player effects |

---

## 1. Full Mode (Server + Client Modules)

**What it is:**
- Both server and client modules exist for the tool
- Client handles visual prediction, server handles authoritative logic

**Flow:**
```
User Click → InputHandler → Client Module (prediction) → RemoteFunction → Server validates → Server Module (authoritative)
```

**Responsibilities:**
| Side | Module | Responsibilities |
|------|--------|------------------|
| Client | `tool_id.lua` | Visual feedback, animations, sounds, effects |
| Server | `tool_id.lua` | Validation, damage calculation, state changes |

**Best for:** Combat tools, complex abilities, multiplayer games

---

## 2. Server-Only Mode

**What it is:**
- Only server module exists (no client module)
- Native Roblox `Tool.Activated` event triggers server processing

**Flow:**
```
User Click → Native Tool.Activated → Roblox Replication → Server NativeToolHandler → Server Module (authoritative)
```

**Responsibilities:**
| Side | Module | Responsibilities |
|------|--------|------------------|
| Client | None | No client-side handling |
| Server | `tool_id.lua` | All logic, validation, state changes |

**Best for:** Admin tools, simple utilities, server-authoritative items without visual prediction

---

## 3. Client-Only Mode

**What it is:**
- Only client module exists (no server module)
- No server communication occurs

**Flow:**
```
User Click → InputHandler → Client Module (visual only) → No server involvement
```

**Responsibilities:**
| Side | Module | Responsibilities |
|------|--------|------------------|
| Client | `tool_id.lua` | Animations, sounds, effects |
| Server | None | No server-side handling |

**Best for:** Cosmetic items, emotes, visual-only toys, single-player effects

---

## Client-Server Architecture

### Client Side: InputHandler (Sole Entry Point)

The `InputHandler` is the **only** component responsible for client-side tool input.

**Responsibilities:**
- Listens to `UserInputService` for mouse clicks and touch input
- Detects when equipped tool should activate
- Loads and calls client tool modules via `ToolModuleManager` (if module exists)
- Sends `RemoteFunction` to server for authoritative processing (Full Mode)
- Handles input debouncing and rate limiting

**Key Design Decision:** There is **no client-side NativeToolHandler**. The `InputHandler` handles all input scenarios, providing a single, consistent entry point for tool activation.

### Server Side: NativeToolHandler (Server-Only Mode Handler)

The `NativeToolHandler` exists **only on the server** and handles Server-Only Mode tools.

**Responsibilities:**
- Listens to native Roblox `Tool.Activated` events (replicated from client)
- Checks if client module exists using `HasClientModule()` function
- **Skips processing** if client module exists (Full Mode uses RemoteFunction)
- **Processes** if no client module exists (Server-Only Mode)

**Why server-only?** Roblox's native `Tool.Activated` event automatically replicates to the server, allowing Server-Only Mode tools to work without any client-side code.

---

## Deduplication Mechanism

A critical architectural consideration is preventing **double activation** in Full Mode. Without deduplication, a single click could trigger:
1. Client `InputHandler` → `RemoteFunction` → Server processes
2. Native `Tool.Activated` → Roblox replicates → Server `NativeToolHandler` processes

### Solution: Client Module Detection

The server `NativeToolHandler` checks if a client module exists before processing:

```lua
-- Server NativeToolHandler pseudocode
function OnToolActivated(player, tool, toolId, toolData)
    if HasClientModule(toolId, toolData) then
        -- Full Mode: Client InputHandler sends RemoteFunction
        -- Skip to avoid double activation
        return
    end
    
    -- Server-Only Mode: No client module, process here
    ActivationManager:Activate(player, toolId, targetData)
end
```

**Client Module Path:**
```
ClientSource/Client/ToolController/Tools/Categories/[Category]/[Subcategory]/[toolId].lua
```

### Detection Logic

| Client Module | Mode | NativeToolHandler Action | Who Processes |
|---------------|------|--------------------------|---------------|
| **EXISTS** | Full Mode | **SKIP** | Client sends RemoteFunction → Server |
| **DOES NOT EXIST** | Server-Only | **PROCESS** | NativeToolHandler → ActivationManager |

### Activation Flow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         TOOL ACTIVATION FLOW                                │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  User Clicks Tool                                                           │
│        │                                                                    │
│        │                                                                    │
│        ├───────────────────────────────────────────────────────┐            │
│        │                                                       │            │
│        ▼                                                       ▼            │
│  ┌──────────────────────────┐                    ┌──────────────────────┐   │
│  │      CLIENT SIDE         │                    │     SERVER SIDE      │   │
│  │      InputHandler        │                    │   NativeToolHandler  │   │
│  │      (Always Active)     │                    │   (Passive Listener) │   │
│  └────────────┬─────────────┘                    └──────────┬───────────┘   │
│               │                                             │               │
│               ▼                                             ▼               │
│  ┌──────────────────────────┐                    ┌──────────────────────┐   │
│  │ Has Client Module?       │                    │ HasClientModule()?   │   │
│  │                          │                    │                      │   │
│  │ YES: Load & call         │                    │ YES: SKIP (Full Mode)│   │
│  │      OnActivate()        │                    │      ↓               │   │
│  │      Send RemoteFunc ────┼────────────────────┼──► Server receives   │   │
│  │                          │                    │    via RemoteFunc    │   │
│  │ NO:  Skip client module  │                    │                      │   │
│  │      (Server-Only Mode)  │                    │ NO: PROCESS          │   │
│  │                          │                    │     (Server-Only)    │   │
│  └──────────────────────────┘                    └──────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Summary by Mode

| Mode | Client Action | Server Action | Result |
|------|---------------|---------------|--------|
| **Full Mode** | InputHandler → Client Module → RemoteFunction | NativeToolHandler skips, RemoteFunction processes | ✅ Single activation |
| **Server-Only** | Native Tool.Activated replicates | NativeToolHandler processes | ✅ Single activation |
| **Client-Only** | InputHandler → Client Module | No server involvement | ✅ Client-only effects |

---

## Design Decisions

### Why No Client-Side NativeToolHandler?

Earlier versions had a `NativeToolHandler` on both client and server. This was **removed from the client** for the following reasons:

1. **Redundancy**: The `InputHandler` already handles all client-side input detection
2. **Simplicity**: Single entry point (`InputHandler`) is easier to maintain and debug
3. **Consistency**: All three modes flow through the same client component
4. **No duplication risk**: Removing client NativeToolHandler eliminates potential double-firing

### Why Keep Server-Side NativeToolHandler?

The server `NativeToolHandler` is **essential** for Server-Only Mode:

1. **Native Replication**: Roblox automatically replicates `Tool.Activated` to server
2. **Zero Client Code**: Server-Only tools don't need any client-side scripting
3. **Deduplication**: The `HasClientModule()` check prevents double activation
4. **Flexibility**: Supports simple tools without requiring client modules

### Module Caching

Both `ActivationManager` (server) and `ToolModuleManager` (client) cache loaded modules:

```lua
-- Cache structure
_toolModuleCache = {
    ["sword_classic"] = <ModuleTable>,
    ["flashlight_standard"] = <ModuleTable>,
}

-- Client module existence cache (server only)
_clientModuleExistsCache = {
    ["sword_classic"] = true,
    ["admin_tool"] = false,
}
```

**Benefits:**
- Modules loaded once, reused on subsequent activations
- `ClearModuleCache()` available for hot-reloading during development
- `ClearClientModuleCache()` on server for development reloads

---

## Related Documentation

- [Architecture.md](./Architecture.md) - Main architecture overview
- [Activation_Types/](./Activation_Types/) - Click vs Hold tool patterns
- [ToolStateManager](#) - Automatic state cleanup utility
