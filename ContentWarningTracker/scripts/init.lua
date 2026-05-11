-- scripts/init.lua
-- Entry point for the Content Warning AP Tracker.
-- PopTracker auto-discovers and executes this file on pack load.
-- Everything else must be explicitly loaded from here.
-- Load order matters: Items → Maps → Layouts → Locations → AutoTracking.

-- ============================================================
-- 1. ITEMS  (must exist before layouts reference their codes)
-- ============================================================
Tracker:AddItems("items/items.json")
Tracker:AddItems("items/settings.json")
Tracker:AddItems("items/locationobjects.json")

-- ============================================================
-- 2. MAPS  (must exist before locations reference map names)
-- ============================================================
Tracker:AddMaps("maps/maps.json")

-- ============================================================
-- 3. LAYOUTS  (must exist before locations use layout keys)
-- ============================================================
Tracker:AddLayouts("layouts/items.json")
Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/broadcast.json")

-- ============================================================
-- 4. LOCATIONS  (reference items, maps, and layout keys above)
-- ============================================================
Tracker:AddLocations("locations/monsters.json")
Tracker:AddLocations("locations/hats.json")
Tracker:AddLocations("locations/general.json")
Tracker:AddLocations("locations/days_quotas.json")
Tracker:AddLocations("locations/views.json")

-- ============================================================
-- 5. AUTO-TRACKING  (loaded last; needs items + locations ready)
-- ============================================================
ScriptHost:LoadScript("scripts/autotracking.lua")
