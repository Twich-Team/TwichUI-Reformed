---@diagnostic disable: undefined-field, undefined-global, inject-field
--[[
    TwichUI Aura Watcher — Spec Catalog

    Provides a per-spec list of "trackable" spells surfaced in the Aura Watcher
    Designer UI, so players immediately see the auras relevant to their current
    specialization rather than having to look them up manually.

    Expand CATALOG to add spells for more specializations.  Each entry:
        key      — Internal camelCase identifier (unique within the spec block)
        display  — Human-readable spell name shown in the Designer tiles
        spellIds — Array of spell IDs; first ID is the "primary" (used for icon lookup)
                   Additional IDs cover talent-swap variants or proc forms of the same buff.
        color    — {r, g, b} tile accent colour
]]

local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type UnitFramesModule
local UnitFrames = T:GetModule("UnitFrames")
if not UnitFrames then return end

local UnitClass         = _G.UnitClass
local GetSpecialization = _G.GetSpecialization

-- ============================================================
-- Spec key helper
-- Returns a string like "PALADIN_1", "DRUID_4", etc.
-- Matches the CLASS_SPECNUM keys used throughout the config.
-- ============================================================
local function GetPlayerSpecKey()
    local _, classToken = UnitClass("player")
    if not classToken then return nil end
    local specIdx = GetSpecialization and GetSpecialization() or 0
    if not specIdx or specIdx == 0 then return nil end
    return classToken .. "_" .. specIdx
end

-- ============================================================
-- Canonical spec-key → display name table
-- ============================================================
local SPEC_NAMES = {
    PALADIN_1     = "Holy Paladin",
    PALADIN_2     = "Protection Paladin",
    PALADIN_3     = "Retribution Paladin",
    DRUID_1       = "Balance Druid",
    DRUID_2       = "Feral Druid",
    DRUID_3       = "Guardian Druid",
    DRUID_4       = "Restoration Druid",
    PRIEST_1      = "Discipline Priest",
    PRIEST_2      = "Holy Priest",
    PRIEST_3      = "Shadow Priest",
    SHAMAN_1      = "Elemental Shaman",
    SHAMAN_2      = "Enhancement Shaman",
    SHAMAN_3      = "Restoration Shaman",
    MONK_1        = "Brewmaster Monk",
    MONK_2        = "Windwalker Monk",
    MONK_3        = "Mistweaver Monk",
    EVOKER_1      = "Devastation Evoker",
    EVOKER_2      = "Preservation Evoker",
    EVOKER_3      = "Augmentation Evoker",
    WARRIOR_1     = "Arms Warrior",
    WARRIOR_2     = "Fury Warrior",
    WARRIOR_3     = "Protection Warrior",
    DEATHKNIGHT_1 = "Blood Death Knight",
    DEATHKNIGHT_2 = "Frost Death Knight",
    DEATHKNIGHT_3 = "Unholy Death Knight",
    DEMONHUNTER_1 = "Havoc Demon Hunter",
    DEMONHUNTER_2 = "Vengeance Demon Hunter",
    MAGE_1        = "Arcane Mage",
    MAGE_2        = "Fire Mage",
    MAGE_3        = "Frost Mage",
    HUNTER_1      = "Beast Mastery Hunter",
    HUNTER_2      = "Marksmanship Hunter",
    HUNTER_3      = "Survival Hunter",
    ROGUE_1       = "Assassination Rogue",
    ROGUE_2       = "Outlaw Rogue",
    ROGUE_3       = "Subtlety Rogue",
    WARLOCK_1     = "Affliction Warlock",
    WARLOCK_2     = "Demonology Warlock",
    WARLOCK_3     = "Destruction Warlock",
}

-- ============================================================
-- CATALOG
-- Auras worth tracking per spec. The Designer shows these as
-- clickable tiles. Each entry becomes one indicator slot when
-- assigned.  Additional specs can be added at any time.
-- ============================================================
local CATALOG = {
    -- ── Holy Paladin ────────────────────────────────────────
    PALADIN_1 = {
        { key = "BeaconOfLight",      display = "Beacon of Light",      spellIds = { 53563 }, color = { 1.00, 0.93, 0.47 } },
        { key = "BeaconOfFaith",      display = "Beacon of Faith",      spellIds = { 156910 }, color = { 1.00, 0.84, 0.28 } },
        { key = "BeaconOfVirtue",     display = "Beacon of Virtue",     spellIds = { 200025 }, color = { 1.00, 0.88, 0.37 } },
        { key = "BeaconOfTheSavior",  display = "Beacon of the Savior", spellIds = { 1244893 }, color = { 0.93, 0.80, 0.47 } },
        { key = "EternalFlame",       display = "Eternal Flame",        spellIds = { 156322 }, color = { 1.00, 0.60, 0.28 } },
        { key = "BlessingOfProtection", display = "Blessing of Protection", spellIds = { 1022 }, color = { 0.94, 0.82, 0.31 }, secret = true },
        { key = "BlessingOfSacrifice", display = "Blessing of Sacrifice", spellIds = { 6940 }, color = { 0.94, 0.50, 0.50 }, secret = true },
        { key = "BlessingOfFreedom",  display = "Blessing of Freedom",  spellIds = { 1044 }, color = { 0.56, 0.93, 0.56 }, secret = true },
        { key = "HolyArmaments",      display = "Holy Armaments",       spellIds = { 432502 }, color = { 0.81, 0.58, 0.93 }, secret = true },
        { key = "Dawnlight",          display = "Dawnlight",            spellIds = { 431381 }, color = { 1.00, 0.84, 0.28 }, secret = true },
        { key = "AuraMastery",        display = "Aura Mastery",         spellIds = { 31821 }, color = { 1.00, 0.95, 0.65 } },
        { key = "DevotionAura",       display = "Devotion Aura",        spellIds = { 465 }, color = { 0.94, 0.90, 0.70 } },
    },
    -- ── Protection Paladin ──────────────────────────────────
    PALADIN_2 = {
        { key = "BlessingOfProtection", display = "Blessing of Protection",  spellIds = { 1022 }, color = { 0.94, 0.82, 0.31 } },
        { key = "BlessingOfSacrifice",  display = "Blessing of Sacrifice",   spellIds = { 6940 }, color = { 0.94, 0.50, 0.50 } },
        { key = "BlessingOfFreedom",    display = "Blessing of Freedom",     spellIds = { 1044 }, color = { 0.56, 0.93, 0.56 } },
        { key = "ShieldOfTheRighteous", display = "Shield of the Righteous", spellIds = { 53600 }, color = { 1.00, 0.84, 0.28 } },
        { key = "ArdentDefender",       display = "Ardent Defender",         spellIds = { 31850 }, color = { 0.81, 0.58, 0.93 } },
        { key = "GuardianOfAncientKings", display = "Guardian of Ancient Kings", spellIds = { 86659 }, color = { 0.94, 0.90, 0.70 } },
    },
    -- ── Retribution Paladin ─────────────────────────────────
    PALADIN_3 = {
        { key = "BlessingOfProtection", display = "Blessing of Protection", spellIds = { 1022 }, color = { 0.94, 0.82, 0.31 } },
        { key = "BlessingOfSacrifice", display = "Blessing of Sacrifice", spellIds = { 6940 }, color = { 0.94, 0.50, 0.50 } },
        { key = "BlessingOfFreedom",  display = "Blessing of Freedom",  spellIds = { 1044 }, color = { 0.56, 0.93, 0.56 } },
        { key = "ExecutionSentence",  display = "Execution Sentence",   spellIds = { 343527 }, color = { 1.00, 0.60, 0.28 } },
        { key = "FinalVerdict",       display = "Final Verdict",        spellIds = { 383329 }, color = { 1.00, 0.84, 0.28 } },
    },
    -- ── Restoration Druid ───────────────────────────────────
    DRUID_4 = {
        { key = "Rejuvenation",        display = "Rejuvenation",         spellIds = { 774 }, color = { 0.51, 0.78, 0.52 } },
        { key = "Regrowth",            display = "Regrowth",             spellIds = { 8936 }, color = { 0.31, 0.76, 0.97 } },
        { key = "Lifebloom",           display = "Lifebloom",            spellIds = { 33763 }, color = { 0.56, 0.93, 0.56 } },
        { key = "Germination",         display = "Germination",          spellIds = { 155777 }, color = { 0.77, 0.89, 0.42 } },
        { key = "WildGrowth",          display = "Wild Growth",          spellIds = { 48438 }, color = { 0.81, 0.58, 0.93 } },
        { key = "SymbioticRelationship", display = "Symbiotic Relationship", spellIds = { 474754 }, color = { 0.40, 0.77, 0.74 } },
        { key = "IronBark",            display = "Ironbark",             spellIds = { 102342 }, color = { 0.65, 0.47, 0.33 }, secret = true },
    },
    -- ── Discipline Priest ───────────────────────────────────
    PRIEST_1 = {
        { key = "PowerWordShield", display = "PW: Shield",    spellIds = { 17 }, color = { 1.00, 0.84, 0.28 } },
        { key = "Atonement",     display = "Atonement",       spellIds = { 194384 }, color = { 0.94, 0.50, 0.50 } },
        { key = "PrayerOfMending", display = "Prayer of Mending", spellIds = { 41635 }, color = { 0.56, 0.93, 0.56 } },
        { key = "PainSuppression", display = "Pain Suppression", spellIds = { 33206 }, color = { 0.81, 0.58, 0.93 }, secret = true },
        { key = "PowerInfusion", display = "Power Infusion",  spellIds = { 10060 }, color = { 0.94, 0.82, 0.31 }, secret = true },
        { key = "Rapture",       display = "Rapture",         spellIds = { 47536 }, color = { 0.62, 0.47, 0.85 } },
    },
    -- ── Holy Priest ─────────────────────────────────────────
    PRIEST_2 = {
        { key = "Renew",          display = "Renew",             spellIds = { 139 }, color = { 0.56, 0.93, 0.56 } },
        { key = "EchoOfLight",    display = "Echo of Light",     spellIds = { 77489 }, color = { 1.00, 0.84, 0.28 } },
        { key = "PrayerOfMending", display = "Prayer of Mending", spellIds = { 41635 }, color = { 0.81, 0.58, 0.93 } },
        { key = "GuardianSpirit", display = "Guardian Spirit",   spellIds = { 47788 }, color = { 0.94, 0.50, 0.50 }, secret = true },
        { key = "PowerInfusion",  display = "Power Infusion",    spellIds = { 10060 }, color = { 0.94, 0.82, 0.31 }, secret = true },
        { key = "HolyWordSerenity", display = "Holy Word: Serenity", spellIds = { 2050 }, color = { 1.00, 0.95, 0.65 } },
    },
    -- ── Restoration Shaman ──────────────────────────────────
    SHAMAN_3 = {
        { key = "Riptide",         display = "Riptide",          spellIds = { 61295 },              color = { 0.31, 0.76, 0.97 } },
        { key = "EarthShield",     display = "Earth Shield",     spellIds = { 383648, 974 },        color = { 0.65, 0.47, 0.33 } },
        { key = "AncestralVigor",  display = "Ancestral Vigor",  spellIds = { 207400 },             color = { 0.56, 0.93, 0.56 } },
        { key = "EarthlivingWeapon", display = "Earthliving Weapon", spellIds = { 382024, 382021, 382022 }, color = { 0.47, 0.87, 0.47 } },
        { key = "Hydrobubble",     display = "Hydrobubble",      spellIds = { 444490 },             color = { 0.31, 0.76, 0.97 } },
        { key = "EarthenWallTotem", display = "Earthen Wall Totem", spellIds = { 198838 },          color = { 0.65, 0.47, 0.33 } },
    },
    -- ── Mistweaver Monk ─────────────────────────────────────
    MONK_3 = {
        { key = "RenewingMist",       display = "Renewing Mist",          spellIds = { 119611 }, color = { 0.56, 0.93, 0.56 } },
        { key = "EnvelopingMist",     display = "Enveloping Mist",        spellIds = { 124682 }, color = { 0.31, 0.76, 0.97 } },
        { key = "SoothingMist",       display = "Soothing Mist",          spellIds = { 115175 }, color = { 0.47, 0.87, 0.47 } },
        { key = "AspectOfHarmony",    display = "Aspect of Harmony",      spellIds = { 450769 }, color = { 0.81, 0.58, 0.93 } },
        { key = "LifeCocoon",         display = "Life Cocoon",            spellIds = { 116849 }, color = { 0.31, 0.76, 0.97 }, secret = true },
        { key = "StrengthOfTheBlackOx", display = "Strength of the Black Ox", spellIds = { 443113 }, color = { 0.40, 0.77, 0.74 }, secret = true },
    },
    -- ── Preservation Evoker ─────────────────────────────────
    EVOKER_2 = {
        { key = "Echo",         display = "Echo",          spellIds = { 364343 }, color = { 0.31, 0.76, 0.97 } },
        { key = "Reversion",    display = "Reversion",     spellIds = { 366155 }, color = { 0.51, 0.78, 0.52 } },
        { key = "EchoReversion", display = "Echo Reversion", spellIds = { 367364 }, color = { 0.40, 0.77, 0.74 } },
        { key = "DreamBreath",  display = "Dream Breath",  spellIds = { 355941 }, color = { 0.47, 0.87, 0.47 } },
        { key = "DreamFlight",  display = "Dream Flight",  spellIds = { 363502 }, color = { 0.81, 0.58, 0.93 } },
        { key = "Lifebind",     display = "Lifebind",      spellIds = { 373267 }, color = { 0.94, 0.50, 0.50 } },
        { key = "TimeDilation", display = "Time Dilation", spellIds = { 357170 }, color = { 0.94, 0.82, 0.31 }, secret = true },
        { key = "VerdantEmbrace", display = "Verdant Embrace", spellIds = { 409895 }, color = { 0.47, 0.87, 0.47 }, secret = true },
    },
    -- ── Augmentation Evoker ─────────────────────────────────
    EVOKER_3 = {
        { key = "Prescience",     display = "Prescience",       spellIds = { 410089 }, color = { 0.81, 0.58, 0.85 } },
        { key = "ShiftingSands",  display = "Shifting Sands",   spellIds = { 413984 }, color = { 1.00, 0.84, 0.28 } },
        { key = "BlisteringScales", display = "Blistering Scales", spellIds = { 360827 }, color = { 0.94, 0.50, 0.50 } },
        { key = "InfernosBlessing", display = "Inferno's Blessing", spellIds = { 410263 }, color = { 1.00, 0.60, 0.28 } },
        { key = "EbonMight",      display = "Ebon Might",       spellIds = { 395152 }, color = { 0.62, 0.47, 0.85 } },
        { key = "SourceOfMagic",  display = "Source of Magic",  spellIds = { 369459 }, color = { 0.31, 0.76, 0.97 } },
    },
    -- ── Protection Warrior ──────────────────────────────────
    WARRIOR_3 = {
        { key = "LastStand",       display = "Last Stand",       spellIds = { 12975 }, color = { 0.94, 0.82, 0.31 } },
        { key = "ShieldWall",      display = "Shield Wall",      spellIds = { 871 }, color = { 0.81, 0.58, 0.93 } },
        { key = "Rallying Cry",    display = "Rallying Cry",     spellIds = { 97462 }, color = { 0.56, 0.93, 0.56 } },
        { key = "IntimidatingShout", display = "Intimidating Shout", spellIds = { 5246 }, color = { 0.94, 0.50, 0.50 } },
        { key = "SpellReflection", display = "Spell Reflection", spellIds = { 23920 }, color = { 0.31, 0.76, 0.97 } },
    },
    -- ── Blood Death Knight ──────────────────────────────────
    DEATHKNIGHT_1 = {
        { key = "BloodShield",     display = "Blood Shield",     spellIds = { 77535 }, color = { 0.81, 0.20, 0.22 } },
        { key = "VampiricBlood",   display = "Vampiric Blood",   spellIds = { 55233 }, color = { 0.94, 0.50, 0.50 } },
        { key = "IceboundFortitude", display = "Icebound Fortitude", spellIds = { 48792 }, color = { 0.31, 0.76, 0.97 } },
        { key = "AntiMagicShell",  display = "Anti-Magic Shell", spellIds = { 48707 }, color = { 0.62, 0.47, 0.85 } },
        { key = "AntiMagicZone",   display = "Anti-Magic Zone",  spellIds = { 51052 }, color = { 0.81, 0.58, 0.93 } },
    },
    -- ── Vengeance Demon Hunter ──────────────────────────────
    DEMONHUNTER_2 = {
        { key = "DemonSpikes",     display = "Demon Spikes", spellIds = { 203819 }, color = { 0.81, 0.20, 0.22 } },
        { key = "MetamorphosisTank", display = "Metamorphosis", spellIds = { 187827 }, color = { 0.62, 0.47, 0.85 } },
        { key = "BurningAlive",    display = "Burning Alive", spellIds = { 207744 }, color = { 1.00, 0.60, 0.28 } },
        { key = "FierycBreath",    display = "Fiery Breath", spellIds = { 204021 }, color = { 1.00, 0.60, 0.28 } },
    },
    -- ── Brewmaster Monk ─────────────────────────────────────
    MONK_1 = {
        { key = "PurifyingBrew", display = "Purifying Brew", spellIds = { 119582 }, color = { 0.94, 0.82, 0.31 } },
        { key = "CelestialBrew", display = "Celestial Brew", spellIds = { 322507 }, color = { 0.31, 0.76, 0.97 } },
        { key = "FortifyingBrew", display = "Fortifying Brew", spellIds = { 115203 }, color = { 0.81, 0.58, 0.93 } },
        { key = "ZenMeditation", display = "Zen Meditation", spellIds = { 115176 }, color = { 0.47, 0.87, 0.47 } },
    },
    -- ── Guardian Druid ──────────────────────────────────────
    DRUID_3 = {
        { key = "BarkskinGuard",   display = "Barkskin",           spellIds = { 22812 }, color = { 0.65, 0.47, 0.33 } },
        { key = "Frenzied Regen",  display = "Frenzied Regen",     spellIds = { 22842 }, color = { 0.56, 0.93, 0.56 } },
        { key = "SurvivorInstincts", display = "Survivor's Instincts", spellIds = { 61336 }, color = { 0.51, 0.78, 0.52 } },
    },
}

-- ============================================================
-- Generic filters (shown for all specs in the "Filters" section)
-- ============================================================
local GENERIC_ENTRIES = {
    { key = "HELPFUL",           display = "Helpful Auras",    source = "HELPFUL",           icon = 135987, color = { 0.56, 0.93, 0.56 } },
    { key = "HARMFUL",           display = "Harmful / Debuffs", source = "HARMFUL",          icon = 136116, color = { 0.94, 0.50, 0.50 } },
    { key = "DISPELLABLE",       display = "Dispellable",      source = "DISPELLABLE",       icon = 135939, color = { 0.94, 0.82, 0.31 } },
    { key = "DISPELLABLE_OR_BOSS", display = "Dispellable + Boss", source = "DISPELLABLE_OR_BOSS", icon = 135939, color = { 0.81, 0.58, 0.93 } },
    { key = "ALL",               display = "All Auras",        source = "ALL",               icon = 134400, color = { 0.50, 0.52, 0.58 } },
}

-- ============================================================
-- Public API
-- ============================================================

--- Returns the canonical CLASS_SPEC key for the current player.
function UnitFrames:AWGetSpecKey()
    return GetPlayerSpecKey()
end

--- Returns a human-readable display name for a spec key.
function UnitFrames:AWGetSpecName(specKey)
    return SPEC_NAMES[specKey] or specKey
end

--- Returns the catalog entry list for a given spec key, or {} if none.
function UnitFrames:AWGetSpecCatalog(specKey)
    return CATALOG[specKey] or {}
end

--- Returns the catalog for the currently logged-in player's spec.
function UnitFrames:AWGetPlayerCatalog()
    local key = GetPlayerSpecKey()
    return CATALOG[key] or {}, key
end

--- Returns the generic filter entry list (same for all specs).
function UnitFrames:AWGetGenericEntries()
    return GENERIC_ENTRIES
end

--- Looks up a catalog entry by its spell key within a spec.
--- Returns the entry table or nil.
function UnitFrames:AWFindCatalogEntry(specKey, entryKey)
    local catalog = CATALOG[specKey]
    if not catalog then return nil end
    for _, entry in ipairs(catalog) do
        if entry.key == entryKey then return entry end
    end
    return nil
end

--- Returns the first spell ID from a catalog entry (used for icon lookup).
function UnitFrames:AWGetEntryIcon(entry)
    if not entry then return nil end
    local id = entry.spellIds and entry.spellIds[1]
    if not id or id == 0 then return nil end
    if _G.C_Spell and _G.C_Spell.GetSpellTexture then
        return _G.C_Spell.GetSpellTexture(id)
    elseif _G.GetSpellTexture then
        return _G.GetSpellTexture(id)
    end
    return nil
end
