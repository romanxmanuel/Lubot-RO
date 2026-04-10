--[[
WHAT THIS IS:
All real playable maps live here.

START HERE:
Duplicate TEMPLATE_MAP for a new map.
Build the real world inside that map's Map folder.

MAPBOX RULE:
MapBox is the real zone system.
You can use one or many MapBoxes in one map.
Put every MapBox somewhere inside that map package.
Use Priority if boxes overlap.
If priorities tie, the smaller box wins.
Use ZoneId for the real zone id.
Use ZoneLabel for the nice player-facing name.

MAPBOX CODE:
StarterPlayer.StarterPlayerScripts.Boot.
MapBoxController reads these MapBox parts.

DO NOT PUT HERE:
Temporary runtime enemies, drops, or FX.
Those go in Workspace.SpawnedDuringPlay.
]]

return {}
