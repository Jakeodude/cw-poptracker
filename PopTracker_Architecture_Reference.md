# PopTracker Archipelago Pack — Architecture Reference

> **Purpose:** A detailed architectural reference for the Content Warning AP PopTracker pack, derived from analysis of the SFA (Star Fox Adventures) and TTYD reference packs. Sections cover the correct boot sequence, identified issues causing the blank screen, proper layout nesting, and a prioritized fix checklist.

---

## Table of Contents

1. [Directory Structure](#1-directory-structure)
2. [manifest.json — Variant Key Convention](#2-manifestjson--variant-key-convention)
3. [Boot Sequence — Correct `init.lua` Load Order](#3-boot-sequence--correct-initlua-load-order)
4. [Missing Dependencies & Silent Crash Points](#4-missing-dependencies--silent-crash-points)
5. [Layout Structure — Tabbed Map Layout Nesting](#5-layout-structure--tabbed-map-layout-nesting)
6. [Root Layout Key Reference](#6-root-layout-key-reference)
7. [Location Section Codes vs Lua Auto-Tracking](#7-location-section-codes-vs-lua-auto-tracking)
8. [Image Asset Directory Requirements](#8-image-asset-directory-requirements)
9. [SFA vs CW Pack — Side-by-Side Diff](#9-sfa-vs-cw-pack--side-by-side-diff)
10. [Action Items Checklist](#10-action-items-checklist)
11. [PopTracker General Reference — Item Types & Layouts](#11-poptracker-general-reference--item-types--layouts)

---

## 1. Directory Structure

A well-formed AP PopTracker pack follows this layout:

```
ContentWarningTracker/            ← Pack root (this folder IS the pack)
├── manifest.json                 ← REQUIRED. Package metadata & variant definitions.
│
├── images/
│   ├── items/                    ← Item images (PNG). Referenced in items/*.json.
│   ├── maps/                     ← Map background images.
│   └── locations/                ← Location toggle images (PNG). Used by locationobjects.json.
│       ├── hats/
│       ├── artifacts/
│       ├── store/
│       └── emotes/
│
├── items/
│   ├── items.json                ← Key/progressive/consumable items.
│   ├── settings.json             ← In-tracker settings toggles (goal flags, slot data options).
│   └── locationobjects.json      ← Toggle stubs for every location check code.
│
├── locations/
│   ├── monsters.json             ← Monster filming check locations.
│   ├── hats.json                 ← Hat purchase check locations.
│   ├── general.json              ← Artifact, store, emote, sponsorship, chorby checks.
│   ├── days_quotas.json          ← Day extraction and quota check locations.
│   └── views.json                ← View milestone check locations.
│
├── layouts/
│   ├── tracker.json              ← Root layout. MUST define "tracker_horizontal" key.
│   ├── broadcast.json            ← Streaming overlay. MUST define "tracker_broadcast" key.
│   └── items.json                ← Itemgrid layout definitions (cw_*_grid keys).
│
├── maps/
│   └── maps.json                 ← Map image definitions.
│
└── scripts/
    ├── init.lua                  ← REQUIRED entry point. PopTracker auto-discovers this.
    └── autotracking.lua          ← Archipelago event handlers.
```

### Key Rules

- **`scripts/init.lua` is the ONLY file PopTracker auto-discovers.** Everything else must be explicitly loaded from within it.
- **`images/` paths** in JSON are relative to the pack root (e.g., `"img": "images/items/my_item.png"`).
- **Variant subdirectories** (`var_*`) are optional override folders. If a variant key uses the `var_` prefix, a corresponding subdirectory **must** exist.

---

## 2. `manifest.json` — Variant Key Convention

This is the **#1 root cause of the blank screen**. PopTracker interprets variant keys differently based on their naming:

### How Variant Keys Work

| Key Pattern | Behavior |
|---|---|
| `"standard"` (no prefix) | Uses all files from the pack root directory. No subdirectory needed. |
| `"var_Foo"` (var_ prefix) | Loads root files, then **overlays files from `ContentWarningTracker/var_Foo/`**. The subdirectory **must exist**. |

### SFA Reference (correct):
```json
{
    "variants": {
        "standard": {
            "display_name": "Map Tracker v0.1.2",
            "flags": ["ap"]
        }
    }
}
```
→ No `var_` prefix. Uses root directory. No subdirectory required. ✅

### CW Pack (broken):
```json
{
    "variants": {
        "var_Standard": {
            "display_name": "Standard",
            "flags": ["ap"]
        }
    }
}
```
→ Has `var_` prefix. PopTracker looks for `ContentWarningTracker/var_Standard/` directory.
→ That directory **does not exist**.
→ Result: **blank screen or silent variant load failure**. ❌

### Fix:
```json
{
    "variants": {
        "standard": {
            "display_name": "Standard",
            "flags": ["ap"]
        }
    }
}
```

---

## 3. Boot Sequence — Correct `init.lua` Load Order

PopTracker processes `init.lua` linearly. Each `Tracker:Add*` and `ScriptHost:LoadScript` call must reference files/data that are already fully loaded. The correct order:

```
1. ITEMS        → codes must exist before layouts reference them in itemgrids
2. MAPS         → must exist before location map_locations reference map names  
3. LAYOUTS      → must exist before locations use layout keys (and before tracker renders)
4. LOCATIONS    → reference item codes (access_rules), map names, layout keys
5. AUTOTRACKING → needs items + locations already loaded; registers AP event handlers
```

### CW `scripts/init.lua` — Current (Correct Order ✅):
```lua
-- 1. ITEMS
Tracker:AddItems("items/items.json")
Tracker:AddItems("items/settings.json")
Tracker:AddItems("items/locationobjects.json")

-- 2. MAPS
Tracker:AddMaps("maps/maps.json")

-- 3. LAYOUTS
Tracker:AddLayouts("layouts/items.json")
Tracker:AddLayouts("layouts/tracker.json")
Tracker:AddLayouts("layouts/broadcast.json")

-- 4. LOCATIONS
Tracker:AddLocations("locations/monsters.json")
Tracker:AddLocations("locations/hats.json")
Tracker:AddLocations("locations/general.json")
Tracker:AddLocations("locations/days_quotas.json")
Tracker:AddLocations("locations/views.json")

-- 5. AUTOTRACKING
ScriptHost:LoadScript("scripts/autotracking.lua")
```

The CW init.lua load order is **architecturally correct**. This is not a source of the blank screen.

### SFA `scripts/init.lua` — For Comparison:
```lua
-- SFA loads Lua utility scripts first (before Add* calls)
require("scripts.utils")
require("scripts.variable_definitions")
require("scripts.logic.logic")
require("scripts.locations")       -- helper script
require("scripts.autotracking")    -- config flags

-- Then loads data files
Tracker:AddItems("items/items.jsonc")
Tracker:AddItems("items/pack_settings.jsonc")
Tracker:AddMaps("maps/maps.jsonc")
Tracker:AddLayouts("layouts/item_grids.jsonc")
Tracker:AddLayouts("layouts/tracker_layouts.jsonc")
```

Note: SFA uses `require()` notation for Lua scripts. CW uses `ScriptHost:LoadScript()`. Both are valid in PopTracker ≥ 0.26. The `ScriptHost:LoadScript()` method is the modern preferred form.

---

## 4. Missing Dependencies & Silent Crash Points

### Files that `init.lua` loads — Status Check

| File | Referenced In | Exists? |
|---|---|---|
| `items/items.json` | init.lua line 10 | ✅ |
| `items/settings.json` | init.lua line 11 | ✅ |
| `items/locationobjects.json` | init.lua line 12 | ✅ |
| `maps/maps.json` | init.lua line 17 | ✅ |
| `layouts/items.json` | init.lua line 22 | ✅ |
| `layouts/tracker.json` | init.lua line 23 | ✅ |
| `layouts/broadcast.json` | init.lua line 24 | ✅ |
| `locations/monsters.json` | init.lua line 29 | ✅ |
| `locations/hats.json` | init.lua line 30 | ✅ |
| `locations/general.json` | init.lua line 31 | ✅ |
| `locations/days_quotas.json` | init.lua line 32 | ✅ |
| `locations/views.json` | init.lua line 33 | ✅ |
| `scripts/autotracking.lua` | init.lua line 38 | ✅ |

**All JSON and Lua files referenced in `init.lua` exist on disk.** The blank screen is not caused by a missing file error.

### Layout Keys Referenced — Status Check

These layout keys are used in `tracker.json` via `"type": "layout", "key": "..."`:

| Layout Key | Defined In | Status |
|---|---|---|
| `cw_hats_grid` | layouts/items.json | ✅ |
| `cw_artifacts_grid` | layouts/items.json | ✅ |
| `cw_store_grid` | layouts/items.json | ✅ |
| `cw_emotes_grid` | layouts/items.json | ✅ |
| `cw_sponsorships_grid` | layouts/items.json | ✅ |
| `cw_chorby_grid` | layouts/items.json | ✅ |
| `cw_quotas_grid` | layouts/items.json | ✅ |
| `cw_days_grid` | layouts/items.json | ✅ |
| `cw_views_grid` | layouts/items.json | ✅ |
| `cw_goals_grid` | layouts/items.json | ✅ |
| `cw_options_grid` | layouts/items.json | ✅ |
| `cw_key_items_grid` | layouts/items.json | ✅ |
| `cw_money_grid` | layouts/items.json | ✅ |

All layout key references resolve correctly.

### Image Assets — Status Check

The file tree shows `images/maps/` as a subdirectory but **`images/items/` and `images/locations/` are not confirmed present**. Every item in `items.json`, `settings.json`, and `locationobjects.json` references images in these directories.

```
images/items/prog_camera.png         ← referenced by items.json
images/items/setting_on.png          ← referenced by settings.json
images/locations/any_extraction.png  ← referenced by locationobjects.json
images/locations/hats/bought_*.png   ← referenced by locationobjects.json
```

If these directories or files are absent, **all items render with broken/missing images** but the tracker UI itself should still load (PopTracker handles missing images gracefully with a placeholder). This would not cause a blank screen by itself but makes the tracker visually unusable.

---

## 5. Layout Structure — Tabbed Map Layout Nesting

### Correct Pattern for Tabbed Layout (PopTracker ≥ 0.26)

The `"tabbed"` element type uses a `"content"` array (NOT `"tabs"`). Each element in the array is a tab object with `"title"` and `"content"` fields.

```json
{
    "tracker_horizontal": {
        "type": "container",
        "background": "#1a1a2e",
        "content": {
            "type": "tabbed",
            "content": [
                {
                    "title": "Tab 1 Name",
                    "content": {
                        "type": "map",
                        "maps": ["map_name_from_maps_json"]
                    }
                },
                {
                    "title": "Tab 2 Name",
                    "content": {
                        "type": "container",
                        "background": "#1a1a2e",
                        "content": {
                            "type": "array",
                            "orientation": "vertical",
                            "content": [
                                {
                                    "type": "group",
                                    "header": "Section Header",
                                    "content": {
                                        "type": "layout",
                                        "key": "my_itemgrid_key"
                                    }
                                }
                            ]
                        }
                    }
                }
            ]
        }
    }
}
```

> ⚠️ **SFA uses `"tabs": [...]`** (older pre-0.26 syntax). The CW pack correctly uses `"content": [...]`. Do NOT change CW to use `"tabs"`.

### The Map Tab Pattern (from SFA `tracker_layouts.jsonc`)

SFA wraps the tabbed maps in a `dock` layout, with items on the left and the tabbed maps filling the rest:

```json
"tracker_default": {
    "type": "container",
    "background": "#212121",
    "content": {
        "type": "dock",
        "dropshadow": true,
        "content": [
            {
                "type": "layout",
                "key": "item_grid",
                "dock": "left"
            },
            {
                "type": "group",
                "v_alignment": "stretch",
                "header": "Maps",
                "content": {
                    "type": "tabbed",
                    "tabs": [
                        {
                            "title": "Region Name",
                            "content": {
                                "type": "map",
                                "maps": ["map_key"]
                            }
                        }
                    ]
                }
            }
        ]
    }
}
```

The CW pack's approach (tabbed directly inside the container, without a dock wrapper or item sidebar) is also valid for a tab-only layout. The nesting itself is not causing the blank screen.

---

## 6. Root Layout Key Reference

PopTracker recognizes these specific top-level layout keys:

| Key | Purpose | Required? |
|---|---|---|
| `tracker_horizontal` | Main window — horizontal/default orientation | **Yes** (or `tracker_default`) |
| `tracker_vertical` | Main window — vertical orientation | No (falls back to horizontal) |
| `tracker_broadcast` | Streaming overlay window | Recommended |
| `tracker_default` | Older alias for main window (SFA style) | Accepted, but use `tracker_horizontal` in new packs |
| `settings_popup` | Settings modal opened from the tracker menu | Recommended |

**The CW pack correctly defines `tracker_horizontal`, `tracker_vertical`, and `tracker_broadcast`.** The root layout keys are not causing the blank screen.

### Missing: `settings_popup`

Neither the CW pack's existing layout files define a `settings_popup` key. If a user opens the tracker's settings panel, PopTracker will fail to find this layout. This should be added as a minimal stub.

---

## 7. Location Section Codes vs Lua Auto-Tracking

### The Conflict in `locations/monsters.json`

The CW `locations/monsters.json` uses PopTracker's **built-in direct AP location code format**:

```json
{
    "name": "Filmed Slurper",
    "map_locations": [{"map": "Monsters", "x": 1172, "y": 483}],
    "sections": [
        {"name": "Filmed Slurper", "item_count": 1, "code": [98765300]},
        {"name": "Filmed Slurper 2", "item_count": 1, "code": [98765330], ...},
        {"name": "Filmed Slurper 3", "item_count": 1, "code": [98765351], ...}
    ]
}
```

The `"code": [98765300]` field tells PopTracker's internal AP client to **automatically mark this section when location ID 98765300 is received from the AP server**, without any Lua code.

**However**, `scripts/autotracking.lua` **also** registers:
```lua
Archipelago:AddLocationHandler("CW_LocationChecked", function(location_id, ...)
    -- Also handles 98765300 via LOCATION_MAP[300] = { sec = "@Monsters/Filmed Slurper/Filmed Slurper" }
```

This creates a **dual-tracking conflict**:
1. PopTracker's built-in system marks `@Monsters/Filmed Slurper/Filmed Slurper` when it sees AP ID `98765300`
2. The Lua `AddLocationHandler` fires for the same ID and also tries to mark the same section via `Tracker:FindObjectForCode("@Monsters/...")`

The result is either redundant double-marking (harmless) or, in some PopTracker versions, a conflict where one handler's state gets overwritten by the other.

### Recommendation

**Choose one approach** — do not use both. The SFA and TTYD reference packs exclusively use Lua-based handlers. The `"code": [...]` field in sections is a newer feature. For consistency with the rest of the CW location files (which do NOT use `"code"` fields), **remove the `"code": [...]` fields from `monsters.json` sections** and let `autotracking.lua` manage all location IDs.

The other location files (`general.json`, `hats.json`, `days_quotas.json`, `views.json`) correctly omit the `"code"` field and rely entirely on the Lua handler. Only `monsters.json` has this inconsistency.

---

## 8. Image Asset Directory Requirements

The following directories must exist with the referenced PNG files:

```
images/
├── items/                         ← 20+ files from items.json
│   ├── prog_camera.png
│   ├── prog_oxygen.png
│   ├── prog_views.png
│   ├── prog_stamina.png
│   ├── prog_stamina_regen.png
│   ├── diving_bell_o2.png
│   ├── diving_bell_charger.png
│   ├── money_50.png  (through money_400.png)
│   ├── meta_coins_500.png  (through meta_coins_2000.png)
│   ├── monster_spawn_trap.png
│   ├── ragdoll_trap.png
│   ├── overlay_1.png (through overlay_12.png)
│   ├── section_header.png
│   ├── setting_on.png
│   └── setting_off.png
│
├── maps/
│   └── cw_monsters_map.png        ← confirmed needed by maps.json
│
└── locations/                     ← locationobjects.json images
    ├── any_extraction.png
    ├── viral_sensation_achieved.png
    ├── sponsorship_check.png
    ├── chorby_check.png
    ├── day_check.png
    ├── quota_check.png
    ├── views_check.png
    ├── hats/
    │   └── bought_*.png           ← 31 hat images
    ├── artifacts/
    │   └── filmed_*.png           ← 13 artifact images
    ├── store/
    │   └── bought_*.png           ← 17 store item images
    └── emotes/
        └── bought_*.png           ← 16 emote images
```

---

## 9. SFA vs CW Pack — Side-by-Side Diff

| Feature | SFA Pack | CW Pack | Issue? |
|---|---|---|---|
| Variant key naming | `"standard"` (no prefix) | `"var_Standard"` (var_ prefix) | 🔴 **Blank screen** — `var_` prefix requires a subdirectory that doesn't exist |
| Root layout key | `"tracker_default"` | `"tracker_horizontal"` | 🟢 Both are valid; CW uses the modern key |
| Tab element syntax | `"tabs": [...]` (old) | `"content": [...]` (new) | 🟢 CW syntax is correct for ≥0.32.1 |
| Container background | `"#212121"` | `"#00000000"` (transparent) | 🟡 Transparent background may hide content in some display modes |
| Section codes in JSON | Not used | `"code": [...]` in monsters.json only | 🟡 Conflicts with Lua auto-tracking handler |
| `settings_popup` layout | Defined ✅ | Not defined ❌ | 🟡 Settings panel will fail to open |
| Lua script loader | `require()` | `ScriptHost:LoadScript()` | 🟢 Both valid; CW uses modern form |
| Helper Lua scripts | `utils.lua`, `variable_definitions.lua`, `locations.lua` | None | 🟢 Not needed for CW's simpler architecture |
| Image assets | Present | Not confirmed | 🟡 Missing images degrade UI visually |
| `platform` in manifest | `"platform": "gcn"` | Not set | 🟢 Optional field, no functional impact |
| All JSON files present | ✅ | ✅ | 🟢 No missing stub files |
| init.lua load order | Correct | Correct | 🟢 Both follow Items→Maps→Layouts→Locations→AT |

---

## 10. Action Items Checklist

### Immediate (Blank Screen Fixes)

- [x] **Fix #1 — `manifest.json` variant key** *(DONE)*
  - Changed `"var_Standard"` → `"standard"`
  - This is the primary cause of the blank screen

- [x] **Fix #2 — `locations/monsters.json` section codes** *(DONE)*
  - Removed `"code": [...]` fields from all sections
  - Eliminates dual-tracking conflict with `autotracking.lua`

- [x] **Fix #3 — `layouts/tracker.json` transparent background** *(DONE)*
  - Changed `"background": "#00000000"` → `"background": "#1a1a2e"` in `tracker_horizontal`
  - Prevents transparent background from hiding content

### Recommended (UX Completeness)

- [x] **Fix #4 — Add `settings_popup` layout stub** *(DONE)*
  - Added minimal `settings_popup` key to avoid crash when opening tracker settings

- [ ] **Populate `images/items/` directory**
  - Create all PNG files referenced in `items.json` and `settings.json`
  - Minimum viable: `setting_on.png`, `setting_off.png`, `section_header.png`, one image per item type

- [ ] **Populate `images/locations/` directory**
  - Create all PNG files referenced in `locationobjects.json`
  - These are the toggle icons shown in the item grids for each location check

- [ ] **Verify `images/maps/cw_monsters_map.png` exists**
  - This is the background for the Monsters tab map
  - Without it, the Monsters tab will show nothing

### Future Architecture Improvements

- [ ] **Add `platform` field to `manifest.json`** (e.g., `"platform": "pc"`)
- [ ] **Consider splitting autotracking into a subdirectory** (`scripts/autotracking/`) with separate item_mapping, location_mapping files — follows TTYD pattern for maintainability

---

## 11. PopTracker General Reference — Item Types & Layouts

### Item Types

| Type | Click Behavior | Key Fields | Lua Property |
|---|---|---|---|
| `toggle` | On/off | `img`, `codes` | `.Active` (bool) |
| `progressive` | Cycles stages | `stages[]`, `initial_stage_idx` | `.CurrentStage` (int) |
| `consumable` | Counter | `max_quantity` | `.AcquiredCount` (int) |
| `static` | No interaction | `img`, `codes` | (display only) |

### Layout Element Types

| Type | Purpose | Key Fields |
|---|---|---|
| `container` | Wrapper with background | `background`, `content` |
| `dock` | Edge-relative positioning | `content[]` with `"dock": "left/right/top/bottom"` |
| `array` | Linear stack | `orientation: "horizontal/vertical"`, `content[]` |
| `tabbed` | Tab panel | `content[]` with tab objects `{title, content}` |
| `group` | Bordered panel with header | `header`, `header_background`, `content` |
| `itemgrid` | 2D item grid | `rows[][]`, `item_width`, `item_height`, `item_margin` |
| `layout` | Reference to named layout | `key` (must match a top-level key in any loaded layout file) |
| `map` | Map with location pins | `maps[]` (names must match `maps.json` entries) |

### `itemgrid` Special Values in `rows`

- **`"F"` or `"f"`** — Empty spacer cell (no item rendered)
- **`"?code"`** — Renders the item but with a dim/question-mark overlay if not active (optional hint display)

### Location Section Path Format

The Lua auto-tracker uses `@`-prefixed paths to find sections:
```
"@RegionName/ChildName/SectionName"
```
Each segment must **exactly match** the `"name"` fields in the corresponding location JSON file (case-sensitive).

Example from CW:
```lua
"@Monsters/Filmed Slurper/Filmed Slurper"
-- Matches: locations/monsters.json → "Monsters" → child "Filmed Slurper" → section "Filmed Slurper"

"@General/Artifacts/Filmed Ribcage"
-- Matches: locations/general.json → "General" → child "Artifacts" → section "Filmed Ribcage"

"@Days and Quotas/Day Extractions/Extracted Footage on Day 1"
-- Matches: locations/days_quotas.json → "Days and Quotas" → child "Day Extractions" → section "Extracted Footage on Day 1"
```

### Archipelago Handler Registration Pattern

```lua
-- Fired on AP connect and new game start — reset all state + apply slot_data
Archipelago:AddClearHandler("unique_name", function(slot_data) ... end)

-- Fired when an item is received from AP
Archipelago:AddItemHandler("unique_name", function(index, item_id, item_name, player_name) ... end)

-- Fired when a location is checked
Archipelago:AddLocationHandler("unique_name", function(location_id, location_name) ... end)
```

---

*Document generated from analysis of:*
- *`sfa_ap/` — Star Fox Adventures AP PopTracker Pack (reference)*
- *`TTYD-Reference/` — Paper Mario TTYD AP Tracker v1.1.3 (reference)*
- *`ContentWarningTracker/` — Content Warning AP Tracker (subject)*
- *PopTracker v0.32.x behavior and documentation*
