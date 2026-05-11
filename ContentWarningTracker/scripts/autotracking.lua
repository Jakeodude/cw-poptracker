-- scripts/autotracking.lua
-- Content Warning Archipelago Auto-Tracker
-- Uses PopTracker's built-in Archipelago client (requires PopTracker >= 0.26)

if not Archipelago then
    print("[CW Tracker] Archipelago API not available. Auto-tracking disabled.")
    return
end

print("[CW Tracker] Auto-tracking initializing...")

-- ============================================================
-- CONSTANTS
-- ============================================================
local BASE_ID = 98765000

-- ============================================================
-- HELPERS
-- ============================================================
local function setItem(code, stage)
    local item = Tracker:FindObjectForCode(code)
    if item then item.CurrentStage = stage end
end

local function addItem(code)
    local item = Tracker:FindObjectForCode(code)
    if item then
        if item.Type == "toggle" then
            item.Active = true
        elseif item.Type == "progressive" then
            item.CurrentStage = item.CurrentStage + 1
        else
            -- consumable: increase quantity
            item.AcquiredCount = (item.AcquiredCount or 0) + 1
        end
    end
end

local function clearLocation(sectionPath, toggleCode)
    -- Mark the section in the location tree
    local section = Tracker:FindObjectForCode(sectionPath)
    if section then
        section.AvailableChestCount = 0
    end
    -- Mark the toggle in the itemgrid
    if toggleCode then
        local toggle = Tracker:FindObjectForCode(toggleCode)
        if toggle then toggle.Active = true end
    end
end

-- ============================================================
-- ITEM ID → TRACKER CODE MAP
-- offset -> { code, type }
-- type: "progressive", "toggle", "consumable"
-- ============================================================
local ITEM_OFFSETS = {
    [0]  = { code = "ProgCamera",        type = "progressive" },
    [1]  = { code = "ProgOxygen",        type = "progressive" },
    [2]  = { code = "DivingBellO2",      type = "toggle"      },
    [3]  = { code = "DivingBellCharger", type = "toggle"      },
    [4]  = { code = "ProgViews",         type = "progressive" },
    [5]  = { code = "ProgStamina",       type = "progressive" },
    [6]  = { code = "ProgStaminaRegen",  type = "progressive" },
    [19] = { code = "Money50",           type = "consumable"  },
    [20] = { code = "Money100",          type = "consumable"  },
    [21] = { code = "Money200",          type = "consumable"  },
    [22] = { code = "Money300",          type = "consumable"  },
    [23] = { code = "Money400",          type = "consumable"  },
    [30] = { code = "MetaCoins500",      type = "consumable"  },
    [31] = { code = "MetaCoins1000",     type = "consumable"  },
    [32] = { code = "MetaCoins1500",     type = "consumable"  },
    [33] = { code = "MetaCoins2000",     type = "consumable"  },
    [40] = { code = "MonsterSpawnTrap",  type = "consumable"  },
    [41] = { code = "RagdollTrap",       type = "consumable"  },
}

-- ============================================================
-- LOCATION ID → { section_path, toggle_code } MAP
-- ============================================================

-- View milestone totals per day (matches VIEW_MILESTONES in locations.py)
local VIEW_TOTALS_BY_DAY = {
    [1]="1,000",  [2]="2,000",  [3]="3,000",
    [4]="16,000", [5]="29,000", [6]="42,000",
    [7]="84,667", [8]="127,333",[9]="170,000",
    [10]="278,333",[11]="386,667",[12]="495,000",
    [13]="709,667",[14]="924,333",[15]="1,139,000",
    [16]="1,505,667",[17]="1,872,333",[18]="2,239,000",
    [19]="2,839,000",[20]="3,439,000",[21]="4,039,000",
    [22]="4,639,000",[23]="5,239,000",[24]="5,839,000",
    [25]="6,472,333",[26]="7,105,667",[27]="7,739,000",
    [28]="8,372,333",[29]="9,005,667",[30]="9,639,000",
    [31]="10,305,667",[32]="10,972,333",[33]="11,639,000",
    [34]="12,305,667",[35]="12,972,333",[36]="13,639,000",
    [37]="14,305,667",[38]="14,972,333",[39]="15,639,000",
    [40]="16,339,000",[41]="17,039,000",[42]="17,739,000",
    [43]="18,439,000",[44]="19,139,000",[45]="19,839,000",
    [46]="20,572,333",[47]="21,305,667",[48]="22,039,000",
    [49]="22,772,333",[50]="23,505,667",[51]="24,239,000",
    [52]="25,005,667",[53]="25,772,333",[54]="26,539,000",
    [55]="27,305,667",[56]="28,072,333",[57]="28,839,000",
    [58]="29,639,000",[59]="30,439,000",[60]="31,239,000",
    [61]="32,072,333",[62]="32,905,667",[63]="33,739,000",
}

local function buildLocationMap()
    local m = {}

    -- Offset 0: Any Extraction
    m[0] = { sec = "@General/Other/Any Extraction", tog = "loc_any_extraction" }

    -- Offsets 1-63: Day Extractions
    for d = 1, 63 do
        m[d] = {
            sec = "@Days and Quotas/Day Extractions/Extracted Footage on Day " .. d,
            tog = "loc_day_" .. d,
        }
    end

    -- Offsets 100-120: Quotas (base id offset = 99 + quota)
    for q = 1, 21 do
        m[99 + q] = {
            sec = "@Days and Quotas/Quotas/Met Quota " .. q,
            tog = "loc_quota_" .. q,
        }
    end

    -- Offsets 200-262: View Milestones (199 + day)
    for d = 1, 63 do
        local total = VIEW_TOTALS_BY_DAY[d]
        m[199 + d] = {
            sec = "@View Milestones/View Checks/Reached " .. total .. " Total Views",
            tog = "loc_views_day_" .. d,
        }
    end

    -- ---- Monsters ----
    -- Base checks (offsets 300-329)
    local MONSTER_OFFSETS = {
        [300]="Filmed Slurper",       [301]="Filmed Zombe",
        [302]="Filmed Worm",          [303]="Filmed Mouthe",
        [304]="Filmed Flicker",       [305]="Filmed Cam Creep",
        [306]="Filmed Infiltrator",   [307]="Filmed Button Robot",
        [308]="Filmed Puffo",         [309]="Filmed Black Hole Bot",
        [310]="Filmed Snatcho",       [311]="Filmed Whisk",
        [312]="Filmed Spider",        [313]="Filmed Ear",
        [314]="Filmed Jelly",         [315]="Filmed Weeping",
        [316]="Filmed Bomber",        [317]="Filmed Dog",
        [318]="Filmed Eye Guy",       [319]="Filmed Fire",
        [320]="Filmed Knifo",         [321]="Filmed Larva",
        [322]="Filmed Arms",          [323]="Filmed Harpooner",
        [324]="Filmed Mime",          [325]="Filmed Barnacle Ball",
        [326]="Filmed Snail Spawner", [327]="Filmed Big Slap",
        [328]="Filmed Streamer",      [329]="Filmed Ultra Knifo",
    }
    for offset, name in pairs(MONSTER_OFFSETS) do
        m[offset] = {
            sec = "@Monsters/" .. name .. "/" .. name,
            tog = nil,  -- monsters tracked via section only; map pin updates automatically
        }
    end

    -- Tier 2 (offsets 330-350, non-difficult; order matches locations.py)
    local TIER2_ORDER = {
        "Filmed Slurper","Filmed Zombe","Filmed Button Robot","Filmed Puffo",
        "Filmed Whisk","Filmed Arms","Filmed Worm","Filmed Mouthe","Filmed Spider",
        "Filmed Bomber","Filmed Dog","Filmed Eye Guy","Filmed Knifo","Filmed Larva",
        "Filmed Harpooner","Filmed Barnacle Ball","Filmed Snatcho","Filmed Jelly",
        "Filmed Fire","Filmed Mime","Filmed Streamer",
    }
    for i, name in ipairs(TIER2_ORDER) do
        m[329 + i] = { sec = "@Monsters/" .. name .. "/" .. name .. " 2", tog = nil }
    end

    -- Tier 3 (offsets 351-371)
    for i, name in ipairs(TIER2_ORDER) do
        m[350 + i] = { sec = "@Monsters/" .. name .. "/" .. name .. " 3", tog = nil }
    end

    -- Difficult Tier 2 (offsets 372-380)
    local DIFF_ORDER = {
        "Filmed Weeping","Filmed Flicker","Filmed Cam Creep","Filmed Infiltrator",
        "Filmed Black Hole Bot","Filmed Ear","Filmed Snail Spawner",
        "Filmed Big Slap","Filmed Ultra Knifo",
    }
    for i, name in ipairs(DIFF_ORDER) do
        m[371 + i] = { sec = "@Monsters/" .. name .. "/" .. name .. " 2", tog = nil }
    end
    -- Difficult Tier 3 (offsets 381-389)
    for i, name in ipairs(DIFF_ORDER) do
        m[380 + i] = { sec = "@Monsters/" .. name .. "/" .. name .. " 3", tog = nil }
    end

    -- ---- Artifacts ----
    local ARTIFACT_ORDER = {
        "Filmed Ribcage","Filmed Skull","Filmed Spine","Filmed Bone",
        "Filmed Brain on a Stick","Filmed Radio","Filmed Shroom",
        "Filmed Animal Statues","Filmed Radioactive Container",
        "Filmed Old Painting","Filmed Chorby","Filmed Apple","Filmed Reporter Mic",
    }
    local artifact_toggles = {
        "loc_filmed_ribcage","loc_filmed_skull","loc_filmed_spine","loc_filmed_bone",
        "loc_filmed_brain_on_a_stick","loc_filmed_radio","loc_filmed_shroom",
        "loc_filmed_animal_statues","loc_filmed_radioactive_container",
        "loc_filmed_old_painting","loc_filmed_chorby","loc_filmed_apple",
        "loc_filmed_reporter_mic",
    }
    for i, name in ipairs(ARTIFACT_ORDER) do
        m[399 + i] = { sec = "@General/Artifacts/" .. name, tog = artifact_toggles[i] }
    end
    -- Artifact Tier 2 (offsets 413-425)
    for i, name in ipairs(ARTIFACT_ORDER) do
        local tog = artifact_toggles[i]:gsub("(.+)", "%1_2")
        m[412 + i] = { sec = "@General/Artifact Tiers/" .. name .. " 2", tog = tog }
    end
    -- Artifact Tier 3 (offsets 426-438)
    for i, name in ipairs(ARTIFACT_ORDER) do
        local tog = artifact_toggles[i]:gsub("(.+)", "%1_3")
        m[425 + i] = { sec = "@General/Artifact Tiers/" .. name .. " 3", tog = tog }
    end

    -- ---- Store Purchases ----
    local STORE = {
        {500,"Bought Old Flashlight","loc_bought_old_flashlight"},
        {501,"Bought Flare","loc_bought_flare"},
        {502,"Bought Modern Flashlight","loc_bought_modern_flashlight"},
        {503,"Bought Long Flashlight","loc_bought_long_flashlight"},
        {504,"Bought Modern Flashlight Pro","loc_bought_modern_flashlight_pro"},
        {505,"Bought Long Flashlight Pro","loc_bought_long_flashlight_pro"},
        {506,"Bought Hugger","loc_bought_hugger"},
        {507,"Bought Defibrillator","loc_bought_defibrillator"},
        {508,"Bought Reporter Mic","loc_bought_reporter_mic"},
        {509,"Bought Boom Mic","loc_bought_boom_mic"},
        {510,"Bought Clapper","loc_bought_clapper"},
        {511,"Bought Sound Player","loc_bought_sound_player"},
        {512,"Bought Goo Ball","loc_bought_goo_ball"},
        {513,"Bought Rescue Hook","loc_bought_rescue_hook"},
        {514,"Bought Shock Stick","loc_bought_shock_stick"},
        {515,"Bought Sketch Pad","loc_bought_sketch_pad"},
        {570,"Bought Party Popper","loc_bought_party_popper"},
    }
    for _, e in ipairs(STORE) do
        m[e[1]] = { sec = "@General/Store Purchases/" .. e[2], tog = e[3] }
    end

    -- ---- Emotes ----
    local EMOTES = {
        {550,"Bought Applause","loc_bought_applause"},
        {551,"Bought Workout 1","loc_bought_workout_1"},
        {552,"Bought Confused","loc_bought_confused"},
        {553,"Bought Dance 103","loc_bought_dance_103"},
        {554,"Bought Dance 102","loc_bought_dance_102"},
        {555,"Bought Dance 101","loc_bought_dance_101"},
        {556,"Bought Backflip","loc_bought_backflip"},
        {557,"Bought Gymnastics","loc_bought_gymnastics"},
        {558,"Bought Caring","loc_bought_caring"},
        {559,"Bought Ancient Gestures 3","loc_bought_ancient_gestures_3"},
        {560,"Bought Ancient Gestures 2","loc_bought_ancient_gestures_2"},
        {561,"Bought Yoga","loc_bought_yoga"},
        {562,"Bought Workout 2","loc_bought_workout_2"},
        {563,"Bought Thumbnail 1","loc_bought_thumbnail_1"},
        {564,"Bought Thumbnail 2","loc_bought_thumbnail_2"},
        {565,"Bought Ancient Gestures 1","loc_bought_ancient_gestures_1"},
    }
    for _, e in ipairs(EMOTES) do
        m[e[1]] = { sec = "@General/Emotes/" .. e[2], tog = e[3] }
    end

    -- ---- Hats ----
    local HATS = {
        {600,"Bought Balaclava","loc_bought_balaclava"},
        {601,"Bought Beanie","loc_bought_beanie"},
        {602,"Bought Bucket Hat","loc_bought_bucket_hat"},
        {603,"Bought Cat Ears","loc_bought_cat_ears"},
        {604,"Bought Chefs Hat","loc_bought_chefs_hat"},
        {605,"Bought Floppy Hat","loc_bought_floppy_hat"},
        {606,"Bought Homburg","loc_bought_homburg"},
        {607,"Bought Curly Hair","loc_bought_curly_hair"},
        {608,"Bought Bowler Hat","loc_bought_bowler_hat"},
        {609,"Bought Cap","loc_bought_cap"},
        {610,"Bought Propeller Hat","loc_bought_propeller_hat"},
        {611,"Bought Clown Hair","loc_bought_clown_hair"},
        {612,"Bought Cowboy Hat","loc_bought_cowboy_hat"},
        {613,"Bought Crown","loc_bought_crown"},
        {614,"Bought Halo","loc_bought_halo"},
        {615,"Bought Horns","loc_bought_horns"},
        {616,"Bought Hotdog Hat","loc_bought_hotdog_hat"},
        {617,"Bought Jesters Hat","loc_bought_jesters_hat"},
        {618,"Bought Ghost Hat","loc_bought_ghost_hat"},
        {619,"Bought Milk Hat","loc_bought_milk_hat"},
        {620,"Bought News Cap","loc_bought_news_cap"},
        {621,"Bought Pirate Hat","loc_bought_pirate_hat"},
        {622,"Bought Sports Helmet","loc_bought_sports_helmet"},
        {623,"Bought Tooop Hat","loc_bought_tooop_hat"},
        {624,"Bought Top Hat","loc_bought_top_hat"},
        {625,"Bought Party Hat","loc_bought_party_hat"},
        {626,"Bought Shroom Hat","loc_bought_shroom_hat"},
        {627,"Bought Ushanka","loc_bought_ushanka"},
        {628,"Bought Witch Hat","loc_bought_witch_hat"},
        {629,"Bought Hard Hat","loc_bought_hard_hat"},
        {630,"Bought Savannah Hair","loc_bought_savannah_hair"},
    }
    for _, e in ipairs(HATS) do
        m[e[1]] = { sec = "@Hats/Hat Purchases/" .. e[2], tog = e[3] }
    end

    -- ---- Sponsorships (offset 699+s for s=1..20) ----
    for s = 1, 20 do
        m[699 + s] = {
            sec = "@General/Sponsorships/Completed Sponsorship " .. s,
            tog = "loc_completed_sponsorship_" .. s,
        }
    end

    -- ---- Found Chorby (offset 719+c for c=1..21) ----
    for c = 1, 21 do
        m[719 + c] = {
            sec = "@General/Found Chorby/Found Chorby " .. c,
            tog = "loc_found_chorby_" .. c,
        }
    end

    -- ---- Viral Sensation Achieved (offset 800) ----
    m[800] = {
        sec = "@General/Other/Viral Sensation Achieved",
        tog = "loc_viral_sensation_achieved",
    }

    return m
end

local LOCATION_MAP = buildLocationMap()

-- CUR_INDEX tracks the highest AP item index processed so far.
-- Prevents re-processing items already seen when the AP server re-sends
-- the full item list on reconnect.
local CUR_INDEX = -1

-- ============================================================
-- CLEAR / RESET HANDLER
-- PopTracker calls this on connect and when the player starts a new game.
-- slot_data is the slot_data table from the AP server (may be nil).
-- ============================================================
Archipelago:AddClearHandler("CW_Clear", function(slot_data)
    print("[CW Tracker] Clearing all tracked state...")
    CUR_INDEX = -1

    -- Reset progressive items to stage 0
    local progressives = {"ProgCamera","ProgOxygen","ProgViews","ProgStamina","ProgStaminaRegen"}
    for _, code in ipairs(progressives) do
        local item = Tracker:FindObjectForCode(code)
        if item then item.CurrentStage = 0 end
    end

    -- Reset toggle items
    local toggles = {"DivingBellO2","DivingBellCharger"}
    for _, code in ipairs(toggles) do
        local item = Tracker:FindObjectForCode(code)
        if item then item.Active = false end
    end

    -- Reset consumables
    local consumables = {
        "Money50","Money100","Money200","Money300","Money400",
        "MetaCoins500","MetaCoins1000","MetaCoins1500","MetaCoins2000",
        "MonsterSpawnTrap","RagdollTrap",
        "ProgressMonsters","ProgressHats","ProgressQuotas","ProgressViews",
    }
    for _, code in ipairs(consumables) do
        local item = Tracker:FindObjectForCode(code)
        if item then item.AcquiredCount = 0 end
    end

    -- Reset all location toggles
    for _, entry in pairs(LOCATION_MAP) do
        if entry.tog then
            local tog = Tracker:FindObjectForCode(entry.tog)
            if tog then tog.Active = false end
        end
    end

    -- Reset all location sections
    for _, entry in pairs(LOCATION_MAP) do
        if entry.sec then
            local sec = Tracker:FindObjectForCode(entry.sec)
            if sec then sec.AvailableChestCount = 1 end
        end
    end

    -- Apply slot_data settings received from the AP server on connect.
    -- slot_data may be nil if the server doesn't send it (e.g. non-AP session).
    if slot_data then
        print("[CW Tracker] Parsing slot_data...")

        -- ----------------------------------------------------------------
        -- TYPE-SAFE HELPERS
        -- AP slot_data values can arrive as booleans, integers, or strings
        -- depending on the game world implementation. These helpers handle
        -- all three so we never crash on an unexpected type.
        -- ----------------------------------------------------------------

        -- toBool: returns true for boolean true, integer 1, or strings "1"/"true"
        local function toBool(v)
            if v == nil then return false end
            if v == true  then return true  end
            if v == false then return false end
            local n = tonumber(v)
            if n ~= nil  then return n ~= 0 end
            local s = tostring(v):lower()
            return s == "true" or s == "yes" or s == "on"
        end

        -- toNum: converts a value to a number; returns 0 on failure
        local function toNum(v)
            if v == nil then return 0 end
            return tonumber(v) or 0
        end

        -- ----------------------------------------------------------------
        -- BOOLEAN / TOGGLE SETTINGS
        -- Each entry drives a two-stage progressive item in settings.json:
        --   stage 0 = OFF  (SettingXxxOff code active)
        --   stage 1 = ON   (SettingXxxOn  code active  → visibility_rules fire)
        -- ----------------------------------------------------------------
        local bool_settings = {
            -- Goals
            { key = "viral_sensation",        code = "SettingViralSensation",       label = "Viral Sensation goal"         },
            { key = "views_goal",             code = "SettingViewsGoal",            label = "Views goal"                   },
            { key = "quota_goal",             code = "SettingQuotaGoal",            label = "Quota goal"                   },
            { key = "monster_hunter",         code = "SettingMonsterHunter",        label = "Monster Hunter goal"          },
            { key = "hat_collector",          code = "SettingHatCollector",         label = "Hat Collector goal"           },
            -- World options (drive map visibility_rules)
            { key = "views_checks",           code = "SettingViewsChecks",          label = "Views Checks enabled"         },
            { key = "quota_requirement",      code = "SettingQuotaReq",             label = "Quota Requirement"            },
            { key = "monster_tiers",          code = "SettingMonsterTiers",         label = "Monster Tiers (shows T2/T3)"  },
            { key = "difficult_monsters",     code = "SettingDifficultMonsters",    label = "Difficult Monsters included"  },
            { key = "multiplayer_mode",       code = "SettingMultiplayer",          label = "Multiplayer mode"             },
            { key = "include_sponsorships",   code = "SettingIncludeSponsorships",  label = "Sponsorships included"        },
            { key = "sponsor_filler",         code = "SettingSponsorFiller",        label = "Sponsor Filler only"          },
            { key = "filler_multi_sightings", code = "SettingFillerMultiSightings", label = "Filler Multi-Sightings"       },
        }

        for _, s in ipairs(bool_settings) do
            local raw = slot_data[s.key]
            if raw ~= nil then
                local bval  = toBool(raw)
                local stage = bval and 1 or 0
                local item  = Tracker:FindObjectForCode(s.code)
                if item then
                    item.CurrentStage = stage
                    print("AP: " .. s.label .. " = " .. tostring(bval) .. "  (raw=" .. tostring(raw) .. ")")
                else
                    print("AP: WARNING - could not find item for code '" .. s.code .. "' (key=" .. s.key .. ")")
                end
            else
                print("AP: " .. s.label .. " not present in slot_data (key=" .. s.key .. ")")
            end
        end

        -- ----------------------------------------------------------------
        -- NUMERIC GOAL TARGETS
        -- These drive the consumable counter items that display "X / Max"
        -- in the Goals & Settings tab.
        -- ----------------------------------------------------------------

        -- Views goal: how many total views the player must reach
        local views_goal_target = toNum(slot_data["views_goal_target"])
        print("AP: Parsed views_goal_target = " .. tostring(views_goal_target))
        local vgt = Tracker:FindObjectForCode("GoalViewsTarget")
        if vgt then vgt.AcquiredCount = views_goal_target end

        -- Quota goal: how many quotas the player must meet
        local quota_count = toNum(slot_data["quota_count"])
        print("AP: Parsed quota_count = " .. tostring(quota_count))
        local qc = Tracker:FindObjectForCode("GoalQuotaCount")
        if qc then qc.AcquiredCount = quota_count end

        -- Monster Hunter goal: how many unique monsters must be filmed
        local monster_count = toNum(slot_data["monster_hunter_count"])
        print("AP: Parsed monster_hunter_count = " .. tostring(monster_count))
        local mc = Tracker:FindObjectForCode("GoalMonsterCount")
        if mc then mc.AcquiredCount = monster_count end

        -- Hat Collector goal: how many hats must be bought
        local hat_count = toNum(slot_data["hat_collector_count"])
        print("AP: Parsed hat_collector_count = " .. tostring(hat_count))
        local hc = Tracker:FindObjectForCode("GoalHatCount")
        if hc then hc.AcquiredCount = hat_count end

        print("[CW Tracker] Slot data fully applied.")
    else
        print("[CW Tracker] No slot_data received (manual / offline session).")
    end
end)

-- ============================================================
-- ITEM RECEIVED HANDLER
-- index is the AP item index; used with CUR_INDEX to deduplicate
-- items that the server re-sends on reconnect.
-- ============================================================
Archipelago:AddItemHandler("CW_ItemReceived", function(index, item_id, item_name, player_name)
    if index <= CUR_INDEX then return end
    CUR_INDEX = index

    local offset = item_id - BASE_ID
    local mapping = ITEM_OFFSETS[offset]
    if not mapping then
        print("[CW Tracker] Unknown item offset: " .. offset .. " (id=" .. item_id .. ", name=" .. tostring(item_name) .. ")")
        return
    end

    local item = Tracker:FindObjectForCode(mapping.code)
    if not item then
        print("[CW Tracker] Could not find item: " .. mapping.code)
        return
    end

    if mapping.type == "progressive" then
        item.CurrentStage = item.CurrentStage + 1
        print("[CW Tracker] Received progressive: " .. mapping.code .. " -> stage " .. item.CurrentStage)
    elseif mapping.type == "toggle" then
        item.Active = true
        print("[CW Tracker] Received toggle: " .. mapping.code)
    elseif mapping.type == "consumable" then
        item.AcquiredCount = (item.AcquiredCount or 0) + 1
        print("[CW Tracker] Received consumable: " .. mapping.code .. " x" .. item.AcquiredCount)
    end
end)

-- ============================================================
-- LOCATION CHECKED HANDLER
-- ============================================================
-- Track progress counters (reset on clear via CUR_INDEX / handler re-run)
local progress = { monsters = 0, hats = 0, quotas = 0, views = 0 }

local function isMonsterBaseSection(sec)
    -- Only tier-1 (base) monster checks count for Monster Hunter progress.
    -- Base checks are "@Monsters/Name/Name" — section name does NOT end in " 2" or " 3".
    if not sec:find("^@Monsters/") then return false end
    local last = sec:match(".+/(.+)$")
    return last and not last:match(" [23]$")
end

local function isHatSection(sec)
    return sec:find("^@Hats/Hat Purchases/Bought") ~= nil
end

local function isQuotaSection(sec)
    return sec:find("^@Days and Quotas/Quotas/Met Quota") ~= nil
end

local function isViewSection(sec)
    return sec:find("^@View Milestones/") ~= nil
end

Archipelago:AddLocationHandler("CW_LocationChecked", function(location_id, location_name)
    local offset = location_id - BASE_ID
    local entry = LOCATION_MAP[offset]
    if not entry then
        print("[CW Tracker] Unknown location offset: " .. offset)
        return
    end

    print("[CW Tracker] Checked location: " .. (entry.sec or "?"))

    -- Mark section and optional toggle
    clearLocation(entry.sec, entry.tog)

    -- Update live progress counters
    if isMonsterBaseSection(entry.sec) then
        progress.monsters = progress.monsters + 1
        local pm = Tracker:FindObjectForCode("ProgressMonsters")
        if pm then pm.AcquiredCount = progress.monsters end
    end
    if isHatSection(entry.sec) then
        progress.hats = progress.hats + 1
        local ph = Tracker:FindObjectForCode("ProgressHats")
        if ph then ph.AcquiredCount = progress.hats end
    end
    if isQuotaSection(entry.sec) then
        progress.quotas = progress.quotas + 1
        local pq = Tracker:FindObjectForCode("ProgressQuotas")
        if pq then pq.AcquiredCount = progress.quotas end
    end
    if isViewSection(entry.sec) then
        progress.views = progress.views + 1
        local pv = Tracker:FindObjectForCode("ProgressViews")
        if pv then pv.AcquiredCount = progress.views end
    end
end)

print("[CW Tracker] Auto-tracking ready. Waiting for AP connection...")
