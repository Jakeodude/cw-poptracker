-- scripts/init.lua
-- MVP: Monsters Map only.
-- Loads maps, layouts, monster locations, and autotracking.
-- No items loaded — visibility rules stripped from monsters.json.

Tracker:AddMaps("maps/maps.json")

Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/monsters_map.json")

Tracker:AddLocations("locations/monsters.json")

ScriptHost:LoadScript("scripts/autotracking.lua")
