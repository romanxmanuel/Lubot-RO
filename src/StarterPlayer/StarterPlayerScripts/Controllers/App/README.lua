return [[
App support modules for the main player UI controller.

Why this folder exists:
- AppController.lua became too large and was hitting Luau/editor limits.
- New UI helpers should be split into focused modules here instead of
  growing the main controller forever.

Use this folder for:
- tooltip UI helpers
- hotbar builders
- inventory / skills / equipment window builders
- dashboard / header builders
- other app-specific UI pieces

Do not put global gameplay logic here.
Shared gameplay logic belongs in Shared or server services.
]]
