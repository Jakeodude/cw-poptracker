# PopTracker Archipelago Pack — Architecture Reference

> **Purpose:** A game-agnostic cheat sheet for building a new Archipelago PopTracker pack from scratch. All patterns are derived from analysis of the TTYD Randomizer AP Tracker v1.1.3. TTYD is cited as a concrete example; substitute your own game's items, locations, and IDs throughout.

---

## Table of Contents

1. [Directory Structure](#1-directory-structure)
2. [manifest.json](#2-manifestjson)
3. [Items (`items/`)](#3-items-items)
4. [Locations (`locations/`)](#4-locations-locations)
5. [Layouts (`layouts/`)](#5-layouts-layouts)
6. [Maps (`maps/`)](#6-maps-maps)
7. [Scripts Entry Point (`scripts/init.lua`)](#7-scripts-entry-point-scriptsinitlua)
8. [Auto-Tracking Architecture (`scripts/autotracking/`)](#8-auto-tracking-architecture-scriptsautotracking)
9. [Logic Functions (`scripts/logic/`)](#9-logic-functions-scriptslogic)
10. [Utility Helpers (`scripts/utils.lua`)](#10-utility-helpers-scriptsutilslua)
11. [Access Rule Syntax Cheat Sheet](#11-access-rule-syntax-cheat-sheet)
12. [Best Practices & Quirks](#12-best-practices--quirks)

---

## 1. Directory Structure

```
my_game_ap/                        ← Root of the pack (this folder IS the pack)
├── manifest.json                  ← REQUIRED. Package metadata & variant definitions.
│
├── images/                        ← All image assets.
│   ├── items/                     ← Item images (PNGs). Referenced in items/*.json.
│   ├── maps/                      ← Map background images (PNGs).
│   └── (other subfolders)         ← Any additional image categories you need.
│
├── items/                         ← Item definition JSONs. Loaded in init.lua.
│   ├── items.json                 ← Key items, progression items, consumable counters.
│   ├── settings.json              ← In-tracker setting toggles (e.g., logic options).
│   └── locationobjects.json       ← Minimal toggle stubs for every location check code.
│
├── locations/                     ← Location definition JSONs. Loaded in init.lua.
│   ├── Region_A.json
│   ├── Region_B.json
│   └── ...
│
├── layouts/                       ← UI layout JSONs. Loaded in init.lua.
│   ├── tracker.json               ← Root layout. MUST define "tracker_horizontal".
│   ├── broadcast.json             ← Streaming overlay. MUST define "tracker_broadcast".
│   ├── items.json                 ← Shared item grid layout definition(s).
│   └── settings_popup.json        ← Settings modal layout.
│
├── maps/
│   └── maps.json                  ← Map image definitions.
│
├── scripts/
│   ├── init.lua                   ← REQUIRED entry point. PopTracker auto-discovers this.
│   ├── utils.lua                  ← Helper functions (has, dump_table, etc.).
│   ├── layouts_import.lua         ← Calls Tracker:AddLayouts() for each layout file.
│   ├── locations_import.lua       ← Calls Tracker:AddLocations() for each location file.
│   ├── autotracking.lua           ← Config flags + loads archipelago.lua.
│   ├── autotracking/
│   │   ├── archipelago.lua        ← Core AP event handlers (onClear, onItem, onLocation).
│   │   ├── item_mapping.lua       ← ITEM_MAPPING table: AP ID → tracker code.
│   │   ├── location_mapping.lua   ← LOCATION_MAPPING table: AP ID → location path.
│   │   ├── settings_mapping.lua   ← SLOT_CODES table: slot_data key → tracker code.
│   │   └── map_mapping.lua        ← MAP_MAPPING: in-game room ID → tab name(s).
│   └── logic/
│       └── logic.lua              ← Custom Lua logic functions called by access_rules.
│
└── var_SomeVariant/               ← OPTIONAL variant override folder (see §2).
    ├── layouts/                   ← Only include files that differ from the base.
    └── images/                    ← Only include images that differ from the base.
```

### Key Rules
- **`scripts/init.lua` is the only auto-discovered file.** Everything else must be explicitly loaded from within it.
- **Variant folders** (`var_*`) are declared in `manifest.json`. PopTracker merges them with the base pack; files in a variant folder override the same-named file in the root. You only need to put the *differing* files in a variant folder.
- **`images/` paths** in JSON are relative to the pack root (e.g., `"img": "images/items/MyItem.png"`).

---

## 2. `manifest.json`

The single required metadata file. PopTracker reads this first.

```json
{
    "name": "My Game Key Item Tracker",
    "game_name": "My Game",
    "package_version": "1.0.0",
    "package_uid": "my_game_ap",
    "author": "YourName",
    "versions_url": "https://raw.githubusercontent.com/YourUser/YourRepo/main/versions.json",
    "variants": {
        "var_Default": {
            "display_name": "Standard",
            "flags": ["ap"]
        },
        "var_MapTracker": {
            "display_name": "Map Tracker",
            "flags": ["ap"]
        }
    },
    "min_poptracker_version": "0.32.1"
}
```

### Field Reference

| Field | Required | Notes |
|---|---|---|
| `name` | Yes | Display name shown in PopTracker's pack list. |
| `game_name` | Yes | The game identifier. |
| `package_uid` | Yes | Globally unique ID for update checking. Use a slug like `my_game_ap`. |
| `package_version` | Yes | Semantic version string, e.g. `"1.0.0"`. |
| `author` | No | Credit string. |
| `versions_url` | No | URL to a `versions.json` file for auto-update notifications. |
| `variants` | Yes | At least one variant is required. Each key is a folder name. |
| `variants[x].display_name` | Yes | Human-readable name shown in the variant selector. |
| `variants[x].flags` | Yes | **Must include `"ap"`** for Archipelago auto-tracking to be enabled in the UI. |
| `min_poptracker_version` | No | Minimum PopTracker version required. Recommended: `"0.32.1"`. |

> **Important:** The variant key (e.g., `"var_Default"`) must match either the root pack directory itself (for the base variant) or a subfolder named exactly that. If a variant has no overrides, it simply doesn't need a corresponding folder — PopTracker just uses the root files.

---

## 3. Items (`items/`)

Items are the interactive elements on the tracker. All item files are JSON arrays of item objects. They are loaded in `init.lua` via `Tracker:AddItems("items/myfile.json")`.

### 3.1 Item Types Overview

| Type | Behavior | Key Fields |
|---|---|---|
| `toggle` | Simple on/off. Click to activate, click again to deactivate. | `img`, `codes` |
| `progressive` | Cycles through ordered stages on click. Starts disabled. | `stages[]`, `initial_stage_idx` |
| `progressive_toggle` | Like `progressive`, but can also be toggled off as a group. | `stages[]` |
| `consumable` | A numeric counter. Right-click increments, left-click decrements. | `max_quantity` |
| `static` | A non-interactive display image. No click behavior. | `img`, `codes` |

---

### 3.2 `toggle` — Simple Binary Item

```json
{
    "name": "My Key Item",
    "type": "toggle",
    "img": "images/items/my_key_item.png",
    "img_mods": "",
    "codes": "MyKeyItem"
}
```

- `name`: Tooltip text shown on hover.
- `img`: Path to the item image, relative to the pack root.
- `img_mods`: Image modification string. Use `""` for none. For overlays, see §3.6.
- `codes`: **The tracker code string.** This is what logic rules, layout grids, and Lua scripts reference. Must be unique. Case-insensitive for matching.

When `Active = false`, PopTracker automatically grays out the image.

---

### 3.3 `progressive` — Multi-Stage Item

Used for items that upgrade (e.g., Boots → Super Boots → Ultra Boots) or stackable keys with a visual counter.

```json
{
    "name": "My Progressive Item",
    "type": "progressive",
    "initial_stage_idx": 0,
    "stages": [
        {
            "name": "Stage 1",
            "img": "images/items/my_item_stage1.png",
            "img_mods": "overlay|/images/items/Overlay1.png,",
            "codes": "MyItem1, MyItem",
            "inherit_codes": false
        },
        {
            "name": "Stage 2",
            "img": "images/items/my_item_stage2.png",
            "img_mods": "overlay|/images/items/Overlay2.png,",
            "codes": "MyItem2, MyItem",
            "inherit_codes": false
        }
    ]
}
```

- `initial_stage_idx`: Which stage index to start at when the item is first activated. `0` = first stage.
- `stages[]`: Ordered array of stage objects.
- `stages[x].codes`: Comma-separated list of codes **this specific stage** grants.
- `stages[x].inherit_codes`: Set to `false` to prevent PopTracker from accumulating codes from lower stages. **Almost always `false`** for AP packs to avoid logic bleed.

When the Lua script calls `item_obj.CurrentStage = item_obj.CurrentStage + 1`, it advances to the next stage.

---

### 3.4 `progressive_toggle` — Togglable Progressive

Identical in definition to `progressive`, but the item can be right-clicked off entirely (returns to disabled state). The Lua handler treats it the same way as `progressive`.

---

### 3.5 `consumable` — Counter

For items you can receive multiple copies of (e.g., "found 7 Star Pieces").

```json
{
    "name": "My Collectible",
    "type": "consumable",
    "max_quantity": 50,
    "img": "images/items/my_collectible.png",
    "img_mods": "",
    "codes": "MyCollectible"
}
```

- `max_quantity`: The maximum value the counter can reach.
- The displayed number shows `AcquiredCount`. Lua increments it with `item_obj.AcquiredCount = item_obj.AcquiredCount + item_obj.Increment`.
- `AcquiredCount = 0` causes the image to be grayed out (treated as "not obtained").

---

### 3.6 `img_mods` — Image Overlays

The `img_mods` string lets you composite a second image on top of the base image. This is used to show numbered overlays on progressive items.

```
"img_mods": "overlay|/images/items/Overlay2.png,"
```

- Format: `"overlay|/path/to/overlay.png,"`
- The trailing comma is required (it separates multiple modifier entries; even with one you need it).
- The path **must start with `/`** (pack root). Note the base `img` field does NOT start with `/`.
- Create a set of overlay images (e.g., `Overlay1.png`, `Overlay2.png`, ...) as small number badges that sit in the corner of your base item image.

---

### 3.7 `locationobjects.json` — Location State Stubs

This is a critical pattern: PopTracker needs a tracker object to exist for every code that Lua will call `Tracker:FindObjectForCode()` on. For location checks, you don't need a real visual item — just a minimal stub.

```json
[
    {"type": "toggle", "codes": "my_region_check_00"},
    {"type": "toggle", "codes": "my_region_check_01"},
    {"type": "toggle", "codes": "my_region_check_02"}
]
```

The `codes` here must exactly match the codes referenced in your `LOCATION_MAPPING` (without the `@` prefix). PopTracker uses these objects' `.Active` state to mark checks as done. The image can be omitted entirely.

---

### 3.8 Settings Items (`settings.json`)

Settings items use the same types but represent game options that auto-tracking reads from `slot_data`. They are typically placed in a dedicated settings popup layout, not the main item grid.

```json
{
    "name": "My Option",
    "type": "progressive",
    "allow_disabled": false,
    "stages": [
        {
            "name": "Option Off",
            "img": "images/items/option_off.png",
            "codes": "MyOptionOff, MyOption",
            "inherit_codes": false
        },
        {
            "name": "Option On",
            "img": "images/items/option_on.png",
            "codes": "MyOptionOn, MyOption",
            "inherit_codes": false
        }
    ]
}
```

- `allow_disabled: false` prevents the user from clicking it to a "no stage" state — it's always at one of the defined stages.
- `initial_active_state: true` on a `toggle` item makes it start checked by default (useful for settings that default to ON).
- The `static` type is for non-clickable display items (e.g., a Discord link image). It always renders at full opacity.

---

## 4. Locations (`locations/`)

Location files define the in-game checks the tracker monitors. They are JSON arrays of **region objects**, which contain **child regions**, which contain **sections** (individual checks).

All location files are loaded in `init.lua` (or a helper script) via `Tracker:AddLocations("locations/Region_A.json")`.

### 4.1 Full Structure Example

```json
[
    {
        "name": "My Region",
        "chest_unopened_img": "/images/items/Chest.png",
        "chest_opened_img": "/images/items/ChestOpen.png",
        "overlay_background": "#000000",
        "access_rules": ["$can_access_my_region"],
        "children": [
            {
                "name": "My Sub-Area",
                "access_rules": ["RequiredItem"],
                "sections": [
                    {
                        "name": "My Sub-Area - First Check",
                        "access_rules": [""],
                        "item_count": 1
                    },
                    {
                        "name": "My Sub-Area - Second Check",
                        "access_rules": ["ItemA,ItemB"],
                        "item_count": 1
                    }
                ],
                "map_locations": [
                    {
                        "map": "World Map",
                        "x": 350,
                        "y": 200
                    }
                ]
            }
        ]
    }
]
```

### 4.2 Region / Child Fields

| Field | Notes |
|---|---|
| `name` | Region name. Used in the tracker's location tree UI. |
| `access_rules` | Array of rule strings controlling when this area is accessible. See §11. |
| `visibility_rules` | Array of rule strings controlling when this area is *visible*. Useful for hiding optional content behind settings. |
| `chest_unopened_img` | Image shown on the map dot when checks remain. Defaults to a standard chest if omitted. |
| `chest_opened_img` | Image shown on the map dot when all checks are done. |
| `overlay_background` | Background color of the map dot label (hex color). |
| `children` | Array of sub-regions. |
| `sections` | Array of individual check objects (see §4.3). |
| `map_locations` | Array of `{map, x, y, size}` objects pinning this area to a map image. |

### 4.3 Section Fields

A section represents a single check (one item location in Archipelago).

```json
{
    "name": "Dungeon - Boss Reward",
    "access_rules": ["$can_reach_boss"],
    "visibility_rules": ["SomeSettingCode"],
    "item_count": 1,
    "chest_unopened_img": "/images/items/BigChest.png",
    "chest_opened_img": "/images/items/BigChestOpen.png"
}
```

| Field | Notes |
|---|---|
| `name` | **Must exactly match** the path string used in `LOCATION_MAPPING` (after the `@`). |
| `access_rules` | Rules for this specific check (stacked on top of parent region rules). |
| `visibility_rules` | Show/hide this section based on settings. |
| `item_count` | Number of checks at this spot. Almost always `1` for AP packs. |
| `chest_unopened_img` | Override the parent region's chest image for this specific section. |

### 4.4 The `ref` Shorthand

When a single map dot corresponds to exactly one section AND both share the same path, you can use `ref` inside a child to avoid restating the section name:

```json
{
    "children": [
        {
            "sections": [{"ref": "My Region/My Sub-Area/My Sub-Area - First Check"}],
            "map_locations": [{"map": "World Map", "x": 100, "y": 200}]
        }
    ]
}
```

The `ref` string is the full path to the section in the location tree: `"RegionName/ChildName/Section Name"`.

### 4.5 Location Codes and the `@` Prefix

In `LOCATION_MAPPING`, each AP location ID maps to a code string. The prefix determines how PopTracker handles it:

- **`@Region/Child/Section Name`** — "Chest-type" location. PopTracker tracks it via `AvailableChestCount`. Lua decrements `location_obj.AvailableChestCount` when checked. This is the **standard format** for map-based trackers.
- **`code_string` (no `@`)** — "Object-type" location. PopTracker looks up an item object with that code and sets `Active = true`. This requires a corresponding entry in `locationobjects.json`.

The `@Path` format is strongly preferred because it ties directly to the named sections in your location JSON files, avoiding a separate `locationobjects.json` entry. The path after `@` must exactly match the nested `name` fields: `@TopRegionName/ChildName/SectionName`.

---

## 5. Layouts (`layouts/`)

Layouts define the visual structure of the tracker UI. They are JSON objects where each top-level key is a **named layout** that can be referenced by other layouts or by PopTracker itself.

All layout files are loaded via `Tracker:AddLayouts("layouts/myfile.json")`.

### 5.1 Root Layout Keys

PopTracker looks for these specific top-level layout keys:

| Key | File | Purpose |
|---|---|---|
| `tracker_horizontal` | `tracker.json` | Main tracker window in horizontal orientation. |
| `tracker_vertical` | `tracker.json` | Main tracker window in vertical orientation (optional). |
| `tracker_broadcast` | `broadcast.json` | Streaming overlay window. |
| Any other key | Any file | Reusable layout fragments referenced via `"type": "layout"`. |

### 5.2 Layout Element Types

All layout elements share these optional properties: `margin`, `h_alignment` (`"left"`, `"center"`, `"right"`), `v_alignment`.

---

#### `container`
A simple wrapper. Usually the outermost element.

```json
{
    "type": "container",
    "background": "#00000000",
    "content": { ... }
}
```

---

#### `dock`
Positions children relative to edges. Each child specifies `"dock": "left"/"right"/"top"/"bottom"`. The last child fills the remaining space.

```json
{
    "type": "dock",
    "dropshadow": true,
    "content": [
        { "type": "...", "dock": "left", ... },
        { "type": "...", "dock": "bottom", ... }
    ]
}
```

---

#### `array`
Stacks children linearly. `"orientation": "horizontal"` or `"vertical"`.

```json
{
    "type": "array",
    "orientation": "horizontal",
    "margin": "0,0",
    "content": [ ... ]
}
```

---

#### `group`
A bordered panel with a header label.

```json
{
    "type": "group",
    "header": "Key Items",
    "header_background": "#3e4b57",
    "content": { ... }
}
```

---

#### `itemgrid`
**The primary way to display items.** Renders items in a 2D grid defined by `rows`.

```json
{
    "type": "itemgrid",
    "item_margin": "3,3",
    "item_width": 40,
    "item_height": 40,
    "h_alignment": "left",
    "item_h_alignment": "center",
    "item_v_alignment": "center",
    "rows": [
        ["ItemCode1", "ItemCode2", "ItemCode3"],
        ["ItemCode4", "ItemCode5", "ItemCode6"]
    ]
}
```

- Each string in `rows` is an item `codes` value. PopTracker looks up the item with that code.
- **`"F"` or `"f"`** is a special spacer/filler cell that renders as a blank space (no item). Use it to align grids with irregular numbers of items.
- `item_size` is a shorthand for `"item_size": "40,40"` instead of separate `item_width`/`item_height`.

---

#### `layout` (Key Reference)
References another named layout by its key. Enables reuse across different layout files.

```json
{
    "type": "layout",
    "key": "shared_item_grid_horizontal"
}
```

The referenced key must be defined somewhere in any layout file that has been loaded.

---

### 5.3 Complete `tracker.json` Example

```json
{
    "tracker_horizontal": {
        "type": "container",
        "background": "#00000000",
        "content": {
            "type": "dock",
            "dropshadow": true,
            "content": [
                {
                    "type": "group",
                    "header": "Key Items",
                    "dock": "left",
                    "margin": "0,0,3,0",
                    "content": {
                        "type": "layout",
                        "h_alignment": "center",
                        "v_alignment": "center",
                        "key": "my_item_grid"
                    }
                }
            ]
        }
    }
}
```

And in `items.json` (a separate layout file):

```json
{
    "my_item_grid": {
        "type": "itemgrid",
        "item_margin": "3,3",
        "item_width": 40,
        "item_height": 40,
        "rows": [
            ["KeyItem1", "KeyItem2", "KeyItem3"],
            ["KeyItem4", "F", "KeyItem5"]
        ]
    }
}
```

---

### 5.4 Tabs

Tabs are created using the `tabbed` element type (available in PopTracker ≥ 0.22). Each tab is a named child.

```json
{
    "type": "tabbed",
    "content": [
        {
            "title": "Chapter 1",
            "content": { "type": "layout", "key": "chapter1_locations" }
        },
        {
            "title": "Chapter 2",
            "content": { "type": "layout", "key": "chapter2_locations" }
        }
    ]
}
```

Tabs can be activated programmatically from Lua via `Tracker:UiHint("ActivateTab", "Tab Title String")`.

---

## 6. Maps (`maps/`)

### `maps/maps.json`

Defines the background map images that location pins are drawn on.

```json
[
    {
        "name": "World Map",
        "location_size": 16,
        "location_border_thickness": 2,
        "img": "images/maps/world_map.png"
    },
    {
        "name": "Dungeon 1",
        "location_size": 16,
        "location_border_thickness": 1,
        "img": "images/maps/dungeon1.png"
    }
]
```

| Field | Notes |
|---|---|
| `name` | Must match the `"map"` string used in location `map_locations` arrays. |
| `img` | Path to the map image, relative to pack root. |
| `location_size` | Radius in pixels of the location dot/pin on the map. |
| `location_border_thickness` | Thickness of the border ring on the dot. |

Location pins are automatically colored by PopTracker based on check status (green = all done, yellow = partial, red = inaccessible, etc.).

---

## 7. Scripts Entry Point (`scripts/init.lua`)

`init.lua` is the **only file PopTracker auto-discovers**. Everything must be loaded from here. The loading order matters.

```lua
ENABLE_DEBUG_LOG = false

-- 1. Load all item definitions first (items must exist before layouts reference them)
Tracker:AddItems("items/items.json")
Tracker:AddItems("items/settings.json")
Tracker:AddItems("items/locationobjects.json")

-- 2. Load helper utilities (must exist before logic.lua uses them)
ScriptHost:LoadScript("scripts/utils.lua")

-- 3. Load logic functions (must exist before locations reference them via $function)
ScriptHost:LoadScript("scripts/logic/logic.lua")

-- 4. Load map definitions
Tracker:AddMaps("maps/maps.json")

-- 5. Load layout definitions
ScriptHost:LoadScript("scripts/layouts_import.lua")

-- 6. Load location definitions (locations reference logic functions & layout keys)
ScriptHost:LoadScript("scripts/locations_import.lua")

-- 7. Load auto-tracking last (connects to AP, needs items+locations already loaded)
ScriptHost:LoadScript("scripts/autotracking.lua")
```

### `scripts/layouts_import.lua`
```lua
Tracker:AddLayouts("layouts/settings_popup.json")
Tracker:AddLayouts("layouts/items.json")
Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/broadcast.json")
```

### `scripts/locations_import.lua`
```lua
Tracker:AddLocations("locations/Region_A.json")
Tracker:AddLocations("locations/Region_B.json")
Tracker:AddLocations("locations/Region_C.json")
```

### `scripts/autotracking.lua`
```lua
AUTOTRACKER_ENABLE_ITEM_TRACKING = true
AUTOTRACKER_ENABLE_LOCATION_TRACKING = true
AUTOTRACKER_ENABLE_DEBUG_LOGGING = true and ENABLE_DEBUG_LOG

ScriptHost:LoadScript("scripts/autotracking/archipelago.lua")
```

---

## 8. Auto-Tracking Architecture (`scripts/autotracking/`)

### 8.1 The Four Core Files

```
scripts/autotracking/
├── archipelago.lua        ← Event handlers + handler registration
├── item_mapping.lua       ← Lua table: AP item ID → tracker code
├── location_mapping.lua   ← Lua table: AP location ID → location path
└── settings_mapping.lua   ← Lua table: slot_data key → tracker code + value map
```

---

### 8.2 `item_mapping.lua` — Item ID Table

Maps Archipelago item IDs (integers) to tracker item codes.

```lua
ITEM_MAPPING = {
    -- Format: [AP_ITEM_ID] = {"tracker_code", "item_type", initial_active_state}
    --
    -- "item_type" mirrors the JSON type: "toggle", "progressive", "consumable"
    -- initial_active_state (optional, boolean) only matters for "progressive" items
    -- that should start Active=true at stage 0 (e.g., base equipment you always have).

    [100001] = {"MySword",        "toggle"},
    [100002] = {"MyShield",       "toggle"},
    [100003] = {"MyUpgrade",      "progressive", true},  -- starts active at stage 0
    [100004] = {"MyCoin",         "consumable"},
    [100005] = {"MyKeyA",         "toggle"},
    [100006] = {"MyKeyB",         "toggle"},
}
```

> **Where do AP item IDs come from?** From the Archipelago game world definition (your `items.py` or equivalent). Every item in Archipelago has a unique numeric ID. You must match these exactly.

---

### 8.3 `location_mapping.lua` — Location ID Table

Maps Archipelago location IDs (integers) to the PopTracker location path string.

```lua
LOCATION_MAPPING = {
    -- Format: [AP_LOCATION_ID] = {"@RegionName/ChildName/Section Name"}
    -- The string after @ must exactly match the nested "name" fields in your location JSON.
    -- A single location ID can map to MULTIPLE codes (rare, but supported as additional entries).

    [200001] = {"@My Region/My Sub-Area/My Sub-Area - First Check"},
    [200002] = {"@My Region/My Sub-Area/My Sub-Area - Second Check"},
    [200003] = {"@My Region/Boss Room/Boss Room - Boss Reward"},
    [200004] = {"@My Region/Chest Cave/Chest Cave - Hidden Item"},
}
```

> **Where do AP location IDs come from?** From your `locations.py` or equivalent game world file. Each check has a unique numeric ID.

---

### 8.4 `settings_mapping.lua` — SlotData Parser

Maps `slot_data` keys (strings, as defined in your Archipelago game's `generate_early()` / `fill_slot_data()`) to tracker item codes, with a value translation table.

```lua
SLOT_CODES = {
    -- Key: the exact slot_data key name from your Archipelago game world
    -- code: the tracker item's "codes" value to control
    -- mapping: translates the slot_data integer value to a stage index (for progressive)
    --          or a stage code string (for progressive_toggle with string stages)

    my_option = {
        code = "MyOptionCode",
        mapping = {
            [0] = 0,  -- slot_data value 0 → stage index 0 (Off)
            [1] = 1,  -- slot_data value 1 → stage index 1 (On)
        }
    },

    difficulty = {
        code = "DifficultyCode",
        mapping = {
            [1] = 0,  -- Easy → stage 0
            [2] = 1,  -- Normal → stage 1
            [3] = 2,  -- Hard → stage 2
        }
    },

    -- For progressive_toggle items where stages use string codes, the mapping
    -- values are strings that get assigned to CurrentStage differently.
    -- Check the archipelago.lua onClear handler to see exactly how it's applied:
    -- item_obj.CurrentStage = value.mapping[setting_value]
}
```

---

### 8.5 `archipelago.lua` — Event Handler Lifecycle

This is the core of auto-tracking. It registers callbacks with the Archipelago connection.

```lua
-- Load all mapping tables first
ScriptHost:LoadScript("scripts/autotracking/item_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/location_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/settings_mapping.lua")
ScriptHost:LoadScript("scripts/autotracking/map_mapping.lua")

CUR_INDEX = -1
```

---

#### `onClear(slot_data)` — Connection / New Game Reset

**Fired when:** The player connects to an AP server or starts a new game.

**Purpose:** Reset everything to a blank state, then apply `slot_data` settings.

```lua
function onClear(slot_data)
    PLAYER_ID = Archipelago.PlayerNumber or -1
    TEAM_NUMBER = Archipelago.TeamNumber or 0
    CUR_INDEX = -1

    -- 1. Reset all locations to unchecked
    for _, location_array in pairs(LOCATION_MAPPING) do
        for _, location in pairs(location_array) do
            if location then
                local loc_obj = Tracker:FindObjectForCode(location)
                if loc_obj then
                    loc_obj.Highlight = Highlight.None
                    if location:sub(1, 1) == "@" then
                        loc_obj.AvailableChestCount = loc_obj.ChestCount  -- restore all chests
                    else
                        loc_obj.Active = false
                    end
                end
            end
        end
    end

    -- 2. Reset all tracked items to default state
    for _, item in pairs(ITEM_MAPPING) do
        local item_code     = item[1]
        local item_type     = item[2]
        local initial_state = item[3]
        local item_obj = Tracker:FindObjectForCode(item_code)
        if item_obj then
            if item_obj.Type == "toggle" then
                item_obj.Active = false
            elseif item_obj.Type == "progressive" then
                item_obj.CurrentStage = 0
                item_obj.Active = initial_state or false
            elseif item_obj.Type == "consumable" then
                item_obj.AcquiredCount = item_obj.MinCount or 0
            elseif item_obj.Type == "progressive_toggle" then
                item_obj.CurrentStage = 0
                item_obj.Active = initial_state or false
            end
        end
    end

    -- 3. Apply slot_data settings to tracker setting items
    for key, value in pairs(SLOT_CODES) do
        local setting_value = slot_data[key]
        if setting_value ~= nil then
            local item_obj = Tracker:FindObjectForCode(value.code)
            if item_obj then
                item_obj.CurrentStage = value.mapping[setting_value]
            end
        end
    end
end
```

---

#### `onItem(index, item_id, item_name, player_number)` — Item Received

**Fired when:** A new item is received by the player from the AP server.

**Purpose:** Update the tracker item's state based on its type.

```lua
function onItem(index, item_id, item_name, player_number)
    if index <= CUR_INDEX then
        return  -- already processed this item in a previous call; skip
    end
    CUR_INDEX = index

    local item = ITEM_MAPPING[item_id]
    if not item or not item[1] then return end

    local item_code = item[1]
    local item_obj = Tracker:FindObjectForCode(item_code)

    if item_obj then
        if item_obj.Type == "toggle" then
            item_obj.Active = true

        elseif item_obj.Type == "progressive" then
            if item_obj.Active then
                item_obj.CurrentStage = item_obj.CurrentStage + 1  -- advance to next stage
            else
                item_obj.Active = true  -- first receive: just activate at stage 0
            end

        elseif item_obj.Type == "consumable" then
            item_obj.AcquiredCount = item_obj.AcquiredCount + item_obj.Increment

        elseif item_obj.Type == "progressive_toggle" then
            if item_obj.Active then
                item_obj.CurrentStage = item_obj.CurrentStage + 1
            else
                item_obj.Active = true
            end
        end
    end
end
```

> **`CUR_INDEX` pattern:** The AP server sends ALL items from the beginning each time you reconnect. `CUR_INDEX` tracks the highest index processed so far; items with `index <= CUR_INDEX` are skipped as duplicates.

---

#### `onLocation(location_id, location_name)` — Location Checked

**Fired when:** The AP server reports that a location has been checked.

**Purpose:** Mark the corresponding tracker location as cleared.

```lua
function onLocation(location_id, location_name)
    local location_array = LOCATION_MAPPING[location_id]
    if not location_array or not location_array[1] then return end

    for _, location in pairs(location_array) do
        local loc_obj = Tracker:FindObjectForCode(location)
        if loc_obj then
            if location:sub(1, 1) == "@" then
                loc_obj.AvailableChestCount = loc_obj.AvailableChestCount - 1  -- chest type
            else
                loc_obj.Active = true  -- object type
            end
        end
    end
end
```

---

#### Handler Registration

At the bottom of `archipelago.lua`, register all handlers with the AP connection object:

```lua
Archipelago:AddClearHandler("clear handler", onClear)
Archipelago:AddItemHandler("item handler", onItem)
Archipelago:AddLocationHandler("location handler", onLocation)
```

Optional (for player position tracking / hint system):
```lua
Archipelago:AddSetReplyHandler("map_key", onMapChange)
Archipelago:AddRetrievedHandler("map_key", onMapChange)
```

---

### 8.6 `map_mapping.lua` — Auto-Tab Switching (Optional)

If your game sends the player's current room/map ID to AP's DataStorage, you can use this to automatically switch tracker tabs as the player moves.

```lua
MAP_MAPPING = {}

local mapData = {
    -- {room_prefix, range_start, range_end, {tab_names...}}
    {"dungeon1_room", 0, 15, {"Dungeon 1"}},
    {"dungeon2_room", 0, 20, {"Dungeon 2"}},
    {"overworld",     0, 5,  {"Overworld"}},
}

local function addMapIds(prefix, range_start, range_end, tabpath)
    for i = range_start, range_end do
        MAP_MAPPING[string.format("%s_%02d", prefix, i)] = tabpath
    end
end

for _, data in ipairs(mapData) do
    addMapIds(data[1], data[2], data[3], data[4])
end
```

In `onMapChange`, the room ID (from DataStorage) is used to look up the tab name list, and `Tracker:UiHint("ActivateTab", tab)` is called for each.

---

## 9. Logic Functions (`scripts/logic/`)

Logic functions are Lua functions called from location `access_rules` via the `$function_name` syntax. They return `true` (accessible) or `false` (inaccessible).

### `scripts/logic/logic.lua`

```lua
-- Core "has item" checks
function has_sword()
    return has("MySword")
end

function has_access_to_dungeon_2()
    return has("KeyA") and has("KeyB") and has_sword()
end

-- Quantity checks (uses has() with an amount argument)
function has_enough_coins(amount)
    return has("MyCoin", amount)
end

-- Combining conditions
function can_open_boss_door()
    return has("BossKey") and has_access_to_dungeon_2()
end

-- Settings-aware logic
function optional_area_accessible()
    -- "OptionOnCode" is the code set by a settings item when the option is enabled
    return has("OptionOnCode") and has("RequiredItem")
end
```

> The `has(code, amount)` function is defined in `utils.lua`. It calls `Tracker:ProviderCountForCode(code)` and returns `true` if the count meets the threshold.

---

## 10. Utility Helpers (`scripts/utils.lua`)

Copy this file verbatim into your pack. These functions are used everywhere.

```lua
-- Returns true if the player has acquired `item` (optionally at least `amount` times).
function has(item, amount)
    local count = Tracker:ProviderCountForCode(item)
    amount = tonumber(amount)
    if not amount then
        return count > 0
    else
        return count >= amount
    end
end

-- Checks if `val` exists in table `t`. Returns 1 (found) or 0 (not found).
function has_value(t, val)
    for i, v in ipairs(t) do
        if v == val then return 1 end
    end
    return 0
end

-- Checks if `item` exists in table `list`. Returns true/false.
function containsItem(list, item)
    if list and item then
        for _, value in pairs(list) do
            if value == item then return true end
        end
    end
    return false
end

-- Debug: serializes a Lua table to a string for print().
function dump_table(o, depth)
    if depth == nil then depth = 0 end
    if type(o) == 'table' then
        local tabs = ('\t'):rep(depth)
        local tabs2 = ('\t'):rep(depth + 1)
        local s = '{\n'
        for k, v in pairs(o) do
            if type(k) ~= 'number' then k = '"' .. k .. '"' end
            s = s .. tabs2 .. '[' .. k .. '] = ' .. dump_table(v, depth + 1) .. ',\n'
        end
        return s .. tabs .. '}'
    else
        return tostring(o)
    end
end
```

---

## 11. Access Rule Syntax Cheat Sheet

Access rules are strings in the `"access_rules"` arrays of location/section objects. An array of rules means **OR** (any one passing makes the check accessible). Comma-separated terms within a single string mean **AND** (all must pass).

| Syntax | Meaning | Example |
|---|---|---|
| `"ItemCode"` | Player must have this item (Active = true, count ≥ 1) | `"MySword"` |
| `"ItemA,ItemB"` | Player must have BOTH ItemA AND ItemB | `"MySword,MyShield"` |
| `["ruleA", "ruleB"]` | Player must satisfy ruleA OR ruleB (array) | `["MySword", "MagicStaff"]` |
| `"$function_name"` | Call a Lua function defined in logic.lua (no args) | `"$can_enter_dungeon"` |
| `"$function_name\|arg"` | Call a Lua function with one argument (string split at `\|`) | `"$has_enough_coins\|5"` |
| `"[ItemCode]"` | Optional/hinted check: item helps but isn't strictly required for accessibility logic (PopTracker uses this for color hints) | `"[$yoshi]"` |
| `"{ItemCode}"` | Glitch-logic only: accessible via glitch if player has the item | `"{GlitchSkip}"` |
| `""` or `" "` | Always accessible (no requirement) | `""` |

**Combining operators:**
```
"ItemA,$my_function"          → ItemA AND my_function() both true
["ItemA", "ItemB,$func"]      → ItemA  OR  (ItemB AND func())
"[$optional_item],RequiredItem" → RequiredItem required; $optional_item helpful
```

**Visibility rules** use the same syntax. When the rule passes, the location/section is shown; when it fails, it's hidden.

---

## 12. Best Practices & Quirks

### File & Naming
- **Image filenames** should be lowercase with no spaces (e.g., `my_key_item.png`, not `My Key Item.png`). PopTracker is case-sensitive on Linux; inconsistent casing will silently fail to load images.
- **`codes` strings** are case-insensitive for matching at runtime, but be consistent — pick a convention (PascalCase or camelCase) and stick with it across all JSON and Lua files.
- The `"img"` path in item JSON does **NOT** start with `/`. The `"img_mods"` overlay path **does** start with `/`. This asymmetry is a quirk of PopTracker's path resolution.

### Item JSON
- Every stage of a multi-stage progressive item should have `"inherit_codes": false` to prevent codes from lower stages being active at higher stages. Without this, a stage 2 item would grant codes from stages 0, 1, AND 2 simultaneously — usually wrong for AP logic.
- `"allow_disabled": false` on a progressive/settings item prevents the user from accidentally clicking it into a disabled state during manual tracking.
- When using `consumable` items as auto-tracked counters, poptracker will display `AcquiredCount / MaxCount`. Start with `AcquiredCount = 0` (which shows as grayed out at 0).

### Locations
- The section `"name"` field in location JSON must **exactly** match (including spaces, punctuation, and capitalization) the path string you put in `LOCATION_MAPPING`. Any mismatch silently breaks auto-tracking for that check.
- `"item_count": 1` is the standard for all AP locations. Use higher values only for multi-item chests that share a single AP ID (rare).
- `visibility_rules` are very useful for hiding optional content (e.g., Star Piece panels) unless the player has enabled the corresponding sanity setting. The rule passes when the code is Active.

### Layouts
- `"F"` (uppercase) and `"f"` (lowercase) are both valid spacer codes in `itemgrid` rows. Use them to align uneven rows to a consistent column width.
- Layout keys are global across all loaded layout files. Name them uniquely to avoid collisions (e.g., prefix with your game: `"mygame_item_grid"`).
- PopTracker **requires** `tracker_horizontal` to exist. If it's missing, the pack will fail to load without a clear error message.

### Scripts & Lua
- `scripts/init.lua` is the **only** filename PopTracker auto-discovers. If you rename it, nothing will load.
- **Load order in `init.lua` matters:** Items → Utils → Logic → Maps → Layouts → Locations → Autotracking. Reversing this order causes crashes because later stages depend on earlier ones being initialized.
- `Tracker:FindObjectForCode(code)` returns `nil` if the code doesn't exist. Always nil-check (`if item_obj then`) before accessing properties on the returned object.
- The `CUR_INDEX` pattern is critical. Without it, reconnecting to the AP server would fire `onItem` for every previously-received item and try to increment progressive items multiple times.
- `Tracker:ProviderCountForCode(code)` (used in `has()`) counts how many items with that code are active/acquired. For `toggle` items this is 0 or 1. For `consumable` items it returns `AcquiredCount`. For `progressive` items with multiple active codes, it sums them up.

### Archipelago-Specific
- The `"flags": ["ap"]` entry in **every** variant in `manifest.json` is mandatory for the Archipelago connection panel to appear. Without it, users can't connect.
- `package_uid` must be globally unique among all PopTracker packs. If two packs share a UID, PopTracker may confuse their update channels. Use a descriptive slug: `"my_game_name_ap"`.
- `slot_data` keys in `SLOT_CODES` must exactly match what your Archipelago game world puts in `slot_data` (the return value of `fill_slot_data()` in your world). Check your `options.py` / `__init__.py` for the exact key names.
- Location paths in `LOCATION_MAPPING` use the format `@TopLevel/Child/Section Name`. The `TopLevel` name is the `"name"` of the top-level object in your location JSON array. Each `/` separates one level of nesting.

### Variants
- Variant folders only need to contain files that differ from the root. A variant with zero differences doesn't need a folder at all.
- Common variant uses: different image sets (HD vs. SD sprites), layout-only variants (map vs. no-map), or logic variants (required-only vs. all items).
- The root pack files are used as the base; variant files are overlaid on top.
