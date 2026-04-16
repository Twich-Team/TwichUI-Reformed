---@diagnostic disable: undefined-field, need-check-nil
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class GameTweaksModule : AceModule, AceEvent-3.0
local GT = QOL:NewModule("GameTweaks", "AceEvent-3.0")
GT:SetEnabledState(false)

local C_BattleNet = _G.C_BattleNet
local C_Bank = _G.C_Bank
local C_Club = _G.C_Club
local C_Container = _G.C_Container
local C_CurrencyInfo = _G.C_CurrencyInfo
local C_DeathInfo = _G.C_DeathInfo
local C_FriendList = _G.C_FriendList
local C_GossipInfo = _G.C_GossipInfo
local C_Item = _G.C_Item
local C_Map = _G.C_Map
local C_PetBattles = _G.C_PetBattles
local C_QuestSession = _G.C_QuestSession
local C_SummonInfo = _G.C_SummonInfo
local C_Timer = _G.C_Timer
local Enum = _G.Enum
local GetInstanceInfo = _G.GetInstanceInfo
local GetItemInfo = C_Item.GetItemInfo or _G.GetItemInfo
local GetNetStats = _G.GetNetStats
local CommunitiesUtil = _G["CommunitiesUtil"]
local EventToastManagerFrame = _G["EventToastManagerFrame"]
local hasanysecretvalues = _G.hasanysecretvalues
local IsCosmeticItem = C_Item.IsCosmeticItem
local IsEquippableItem = C_Item.IsEquippableItem
local IsUsableItem = C_Item.IsUsableItem
local ItemLocation = _G.ItemLocation
local RequestLoadItemDataByID = C_Item and C_Item.RequestLoadItemDataByID
local StaticPopupDialogs = _G["StaticPopupDialogs"]
local UIErrorsFrame = _G["UIErrorsFrame"]
local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
local UIParent = _G.UIParent
local max = math.max
local sort = table.sort
local tonumber = tonumber
local tostring = tostring
local ipairs = ipairs
local pairs = pairs
local select = select
local strfind = string.find
local strlower = string.lower
local strmatch = string.match
local strsplit = strsplit
local gsub = string.gsub

local hooksInstalled = false
local originalErrorHandler = nil
local errorFilterInstalled = false
local hiddenParent = CreateFrame("Frame")
hiddenParent:Hide()

local originalState = {
    ffxGlow = nil,
    ffxDeath = nil,
    ffxNether = nil,
    ffxVenari = nil,
    ffxLingeringVenari = nil,
    weatherDensity = nil,
    raidWeatherDensity = nil,
    cameraDistanceMaxZoomFactor = nil,
    emoteSounds = nil,
    pingSounds = nil,
    soundOutputDriverIndex = nil,
    quickJoinParent = nil,
    stanceParent = nil,
    playerRestTexture = nil,
}

local bodyguardIDs = { 1733, 1736, 1737, 1738, 1739, 1740, 1741 }
local bodyguardNames = nil
local mutedSoundBuckets = {
    game = {},
    toy = {},
    mount = {},
    custom = {},
}

local SOUND_PRESETS = {
    mount = {
        bikes = {
            "motorcyclevehicleattackthrown.ogg#569858", "motorcyclevehiclejumpend1.ogg#569863",
            "motorcyclevehiclejumpend2.ogg#569857", "motorcyclevehiclejumpend3.ogg#569855",
            "motorcyclevehiclejumpstart1.ogg#569856", "motorcyclevehiclejumpstart2.ogg#569862",
            "motorcyclevehiclejumpstart3.ogg#569860", "motorcyclevehicleloadthrown.ogg#569861",
            "motorcyclevehiclestand.ogg#569859", "motorcyclevehiclewalkrun.ogg#569854",
            "vehicle_ground_gearshift_1.ogg#598748", "vehicle_ground_gearshift_2.ogg#598736",
            "vehicle_ground_gearshift_3.ogg#569852", "vehicle_ground_gearshift_4.ogg#598745",
            "vehicle_ground_gearshift_5.ogg#569845",
            "veh_alliancechopper_revs01.ogg#1046321", "veh_alliancechopper_revs02.ogg#1046322",
            "veh_alliancechopper_revs03.ogg#1046323", "veh_alliancechopper_revs04.ogg#1046324",
            "veh_alliancechopper_revs05.ogg#1046325", "veh_alliancechopper_idle.ogg#1046320",
            "veh_alliancechopper_summon.ogg#1046327", "veh_alliancechopper_run_constant.ogg#1046326",
            "veh_hordechopper_rev01.ogg#1045061", "veh_hordechopper_rev02.ogg#1045062",
            "veh_hordechopper_rev03.ogg#1045063", "veh_hordechopper_rev04.ogg#1045064",
            "veh_hordechopper_rev05.ogg#1045065", "veh_hordechopper_idle.ogg#1046318",
            "veh_hordechopper_dismount.ogg#1045060", "veh_hordechopper_summon.ogg#1045070",
            "veh_hordechopper_jumpstart.ogg#1046319", "veh_hordechopper_run_constant.ogg#1045066",
            "veh_hordechopper_run_gearchange01.ogg#1045067", "veh_hordechopper_run_gearchange02.ogg#1045068",
            "veh_hordechopper_run_gearchange03.ogg#1045069",
        },
        brooms = {
            "broomstickmountland.ogg#545651", "broomstickmounttakeoff.ogg#545652", "summonbroomstick1.ogg#567986",
            "summonbroomstick3.ogg#569547", "summonbroomstick2.ogg#568335",
        },
        calamitousCarrion = {
            "12.ogg#7432748", "12.ogg#7432750", "12.ogg#7432752", "12.ogg#7432754", "12.ogg#7432756", "12.ogg#7432758",
        },
        dragonriding = {
            "fx_stone_rock_door_impact_01.ogg#1489050", "fx_stone_rock_door_impact_02.ogg#1489051",
            "fx_stone_rock_door_impact_03.ogg#1489052", "fx_stone_rock_door_impact_04.ogg#1489053",
            "spell_83_visions_evacuationprotocol_start_bad_base.ogg#3088094",
            "protodragonfire_boss_aggro_4634942.ogg#4634942", "protodragonfire_boss_aggro_4634944.ogg#4634944",
            "protodragonfire_boss_aggro_4634946.ogg#4634946",
            "mdprotodrakemount_battleshout_4663454.ogg#4663454", "mdprotodrakemount_battleshout_4663456.ogg#4663456",
            "mdprotodrakemount_battleshout_4663458.ogg#4663458", "mdprotodrakemount_battleshout_4663460.ogg#4663460",
            "mdprotodrakemount_battleshout_4663462.ogg#4663462", "mdprotodrakemount_battleshout_4663464.ogg#4663464",
            "mdprotodrakemount_battleshout_4663466.ogg#4663466",
            "companionserpent_aggro_5163128.ogg#5163128", "companionserpent_aggro_5163130.ogg#5163130",
            "companionserpent_aggro_5163132.ogg#5163132", "companionserpent_aggro_5163134.ogg#5163134",
            "companionserpent_aggro_5163136.ogg#5163136", "companionserpent_aggro_5163138.ogg#5163138",
            "companionserpent_aggro_5163140.ogg#5163140",
        },
        gyrocopters = {
            "mimironheadmount_jumpend.ogg#595097", "mimironheadmount_jumpstart.ogg#595103",
            "mimironheadmount_run.ogg#555364", "mimironheadmount_walk.ogg#595100",
            "gyrocopterfly.ogg#551390", "gyrocopterflyidle.ogg#551398", "gyrocopterflyup.ogg#551389",
            "gyrocoptergearshift1.ogg#551384", "gyrocoptergearshift2.ogg#551391", "gyrocoptergearshift3.ogg#551387",
            "gyrocopterjumpend.ogg#551396", "gyrocopterjumpstart.ogg#551399", "gyrocopterrun.ogg#551386",
            "gyrocoptershuffleleftorright1.ogg#551385", "gyrocoptershuffleleftorright2.ogg#551382",
            "gyrocoptershuffleleftorright3.ogg#551392", "gyrocopterstallinair.ogg#551395",
            "gyrocopterstallinairlong.ogg#551394", "gyrocopterstallongroundlong.ogg#551393", "gyrocopterstand.ogg#551383",
            "gyrocopterstandvar1_a.ogg#551388", "gyrocopterstandvar1_b.ogg#551397", "gyrocopterstandvar1_bnew.ogg#551400",
        },
        rabbits = {
            "01.ogg#2066758", "02.ogg#2066759", "03.ogg#2066760", "04.ogg#2066761", "05.ogg#2066762",
            "01#4508009", "02#4508011", "03#4508013", "01#4508015", "02#4508484", "03#4505418",
        },
        rockets = {
            "rocketmountfly.ogg#595154", "rocketmountjumpland1.ogg#559355", "rocketmountjumpland2.ogg#559352",
            "rocketmountjumpland3.ogg#559353", "rocketmountshuffleleft_right1.ogg#595151",
            "rocketmountshuffleleft_right2.ogg#595163", "rocketmountshuffleleft_right3.ogg#595160",
            "rocketmountshuffleleft_right4.ogg#595157", "rocketmountstand_idle.ogg#559354", "rocketmountwalk.ogg#595148",
            "rocketmountwalkup.ogg#559351",
        },
        travelers = {
            "vo_801_tortollan_male_04_m.ogg#1998112", "vo_801_tortollan_male_05_m.ogg#1998113",
            "vo_801_tortollan_male_06_m.ogg#1998114", "vo_801_tortollan_male_07_m.ogg#1998115",
            "vo_801_tortollan_male_08_m.ogg#1998116", "vo_801_tortollan_male_09_m.ogg#1998117",
            "vo_801_tortollan_male_10_m.ogg#1998118", "vo_801_tortollan_male_11_m.ogg#1998119",
            "npcdraeneimalestandardvendor01.ogg#557341", "npcdraeneimalestandardvendor02.ogg#557335",
            "npcdraeneimalestandardvendor03.ogg#557328", "npcdraeneimalestandardvendor04.ogg#557331",
            "npcdraeneimalestandardvendor05.ogg#557325", "npcdraeneimalestandardvendor06.ogg#557324",
            "npcdraeneimalestandardfarewell01.ogg#557342", "npcdraeneimalestandardfarewell02.ogg#557326",
            "npcdraeneimalestandardfarewell03.ogg#557322", "npcdraeneimalestandardfarewell05.ogg#557332",
            "npcdraeneimalestandardfarewell06.ogg#557338", "npcdraeneimalestandardfarewell08.ogg#557334",
            "vo_grummle_kooky_vendor_01.ogg#640180", "vo_grummle_kooky_vendor_02.ogg#640182",
            "vo_grummle_kooky_vendor_03.ogg#640184", "vo_grummle_kooky_farewell_01.ogg#640158",
            "vo_grummle_kooky_farewell_02.ogg#640160", "vo_grummle_kooky_farewell_03.ogg#640162",
            "vo_grummle_kooky_farewell_04.ogg#640164", "vo_grummle_standard_vendor_01.ogg#640336",
            "vo_grummle_standard_vendor_02.ogg#640338", "vo_grummle_standard_vendor_03.ogg#640340",
            "vo_grummle_standard_farewell_01.ogg#640314", "vo_grummle_standard_farewell_02.ogg#640316",
            "vo_grummle_standard_farewell_03.ogg#640318", "vo_grummle_standard_farewell_04.ogg#640320",
        },
    },
    toy = {
        anima = {
            "01_168901.ogg#3747233", "02_168901.ogg#3747235", "03_168901.ogg#3747237",
        },
        balls = {
            "2hmacehitstone1b.ogg#567794", "2hmacehitstone1c.ogg#567797", "2hmacehitstone1a.ogg#567804",
            "sound/spells/thrownet.ogg#569368",
        },
        harp = {
            "01.mp3#1506781", "02.mp3#1506780", "03.mp3#1506779", "04.mp3#1506778", "01.mp3#3885818", "02.mp3#3885820",
            "03.mp3#3885822", "04.mp3#3885824",
        },
        meerah = {
            "vo_835_meerah_jukebox_f.ogg#3169894",
        },
    },
}

local TRANSFORM_PRESETS = {
    blacksmithing = { 388658 },
    jewelcrafting = { 394015 },
    tailoring = { 391312 },
    engineering = { 394007 },
    enchanting = { 394008 },
    alchemy = { 394003 },
    inscription = { 394016 },
    leatherworking = { 394001 },
    herbalism = { 394005 },
    mining = { 394006 },
    skinning = { 394011 },
    cooking = { 391775 },
    fishing = { 394009 },
    aqir = { 318452 },
    atomic = { 399502 },
    atomGoblin = { 1215363 },
    blight = { 290224 },
    witch = { 279509 },
    spraybots = { 301892, 301893, 301894 },
    hallowed = {
        172010, 218132, 191703, 24732, 191210, 172015, 24735, 24736, 191698, 191700,
        172008, 24712, 24713, 191701, 191211, 24710, 24711, 191686, 191688, 24708,
        24709, 173958, 173959, 191682, 191683, 24723, 191702, 172003, 172020, 191208,
        24740,
    },
    lantern = { 44212 },
    nobleBunny = { 61734, 61716 },
    turkey = { 61781 },
    cursedPickaxe = { 454405 },
    noggenfogger = { 16593, 1223630, 16595, 1223629 },
}

local function GetOptions()
    local configurationModule = T:GetModule("Configuration")
    return (configurationModule.Options --[[@as any]]).GameTweaks
end

local function Value(path, defaultValue)
    return GetOptions():GetValue(path, defaultValue)
end

local function Feature(path)
    return GetOptions():GetEnabled() and Value(path, false) == true
end

local _gtDebugConsole = nil
local function GTLog(message)
    if not _gtDebugConsole then
        _gtDebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    end
    if _gtDebugConsole and type(_gtDebugConsole.Log) == "function" then
        _gtDebugConsole:Log("gametweaks", message, false)
    end
end

local PVP_AUTO_RELEASE_WORLD_MAPS = {
    [123] = true,  -- Wintergrasp
    [244] = true,  -- Tol Barad
    [588] = true,  -- Ashran
    [622] = true,  -- Ashran Alliance Base
    [624] = true,  -- Ashran Horde Base
    [1478] = true, -- Ashran PvP variant
}

local AUTOSELL_BAG_MAX = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or _G.NUM_BAG_SLOTS or 4
local AUTOSELL_SAFE_MODE_LIMIT = 12
local AUTOSELL_START_DELAY_SECONDS = 0.1
local AUTOSELL_ITEMDATA_RETRY_DELAY_SECONDS = 0.2
local AUTOSELL_ITEMDATA_MAX_RETRIES = 6
local AUTOSELL_EQUIPMENT_INVTYPE_EXCEPTIONS = {
    INVTYPE_FINGER = true,
    INVTYPE_NECK = true,
    INVTYPE_TRINKET = true,
    INVTYPE_HOLDABLE = true,
    INVTYPE_CLOAK = true,
}
local AUTOSELL_PRIMARY_ARMOR = {
    WARRIOR = Enum.ItemArmorSubclass.Plate,
    PALADIN = Enum.ItemArmorSubclass.Plate,
    DEATHKNIGHT = Enum.ItemArmorSubclass.Plate,
    HUNTER = Enum.ItemArmorSubclass.Mail,
    SHAMAN = Enum.ItemArmorSubclass.Mail,
    EVOKER = Enum.ItemArmorSubclass.Mail,
    ROGUE = Enum.ItemArmorSubclass.Leather,
    DRUID = Enum.ItemArmorSubclass.Leather,
    MONK = Enum.ItemArmorSubclass.Leather,
    DEMONHUNTER = Enum.ItemArmorSubclass.Leather,
    MAGE = Enum.ItemArmorSubclass.Cloth,
    PRIEST = Enum.ItemArmorSubclass.Cloth,
    WARLOCK = Enum.ItemArmorSubclass.Cloth,
}
local AUTOSELL_SHIELD_CLASSES = {
    PALADIN = true,
    SHAMAN = true,
    WARRIOR = true,
}
local AUTOSELL_WEAPON_PROFICIENCIES = {
    DEATHKNIGHT = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Axe2H] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Mace2H] = true,
        [Enum.ItemWeaponSubclass.Polearm] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Sword2H] = true,
    },
    DEMONHUNTER = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Fist] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Warglaive] = true,
    },
    DRUID = {
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Fist] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Mace2H] = true,
        [Enum.ItemWeaponSubclass.Polearm] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
    },
    EVOKER = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Fist] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
    },
    HUNTER = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Axe2H] = true,
        [Enum.ItemWeaponSubclass.Bows] = true,
        [Enum.ItemWeaponSubclass.Crossbow] = true,
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Fist] = true,
        [Enum.ItemWeaponSubclass.Guns] = true,
        [Enum.ItemWeaponSubclass.Polearm] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Sword2H] = true,
    },
    MAGE = {
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Wand] = true,
    },
    MONK = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Fist] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Polearm] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
    },
    PALADIN = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Axe2H] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Mace2H] = true,
        [Enum.ItemWeaponSubclass.Polearm] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Sword2H] = true,
    },
    PRIEST = {
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
        [Enum.ItemWeaponSubclass.Wand] = true,
    },
    ROGUE = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Bows] = true,
        [Enum.ItemWeaponSubclass.Crossbow] = true,
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Fist] = true,
        [Enum.ItemWeaponSubclass.Guns] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Thrown] = true,
    },
    SHAMAN = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Axe2H] = true,
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Fist] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Mace2H] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
    },
    WARLOCK = {
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
        [Enum.ItemWeaponSubclass.Wand] = true,
    },
    WARRIOR = {
        [Enum.ItemWeaponSubclass.Axe1H] = true,
        [Enum.ItemWeaponSubclass.Axe2H] = true,
        [Enum.ItemWeaponSubclass.Bows] = true,
        [Enum.ItemWeaponSubclass.Crossbow] = true,
        [Enum.ItemWeaponSubclass.Dagger] = true,
        [Enum.ItemWeaponSubclass.Fist] = true,
        [Enum.ItemWeaponSubclass.Guns] = true,
        [Enum.ItemWeaponSubclass.Mace1H] = true,
        [Enum.ItemWeaponSubclass.Mace2H] = true,
        [Enum.ItemWeaponSubclass.Polearm] = true,
        [Enum.ItemWeaponSubclass.Staff] = true,
        [Enum.ItemWeaponSubclass.Sword1H] = true,
        [Enum.ItemWeaponSubclass.Sword2H] = true,
        [Enum.ItemWeaponSubclass.Thrown] = true,
    },
}

local function GetAutoReleaseContext()
    local mapID = (C_Map and C_Map.GetBestMapForUnit and C_Map.GetBestMapForUnit("player")) or 0
    local instanceName, _, _, _, _, _, _, instanceMapID, instanceGroupSize, lfgDungeonID = GetInstanceInfo()
    local _, instanceType = GetInstanceInfo()

    return {
        mapID = mapID or 0,
        instanceName = tostring(instanceName or ""),
        instanceType = tostring(instanceType or "none"),
        instanceMapID = instanceMapID or 0,
        instanceGroupSize = instanceGroupSize or 0,
        lfgDungeonID = lfgDungeonID or 0,
    }
end

local function ShouldAutoReleaseInContext(ctx)
    if not ctx then
        return false, "no_context"
    end

    if ctx.instanceType == "pvp" or ctx.instanceType == "arena" then
        return true, "pvp_instance"
    end

    if PVP_AUTO_RELEASE_WORLD_MAPS[ctx.mapID] then
        return true, "pvp_world_zone"
    end

    return false, "non_pvp_context"
end

local function SaveOriginalCVar(slot, cvar)
    if originalState[slot] == nil then
        originalState[slot] = _G.GetCVar(cvar)
    end
end

local function ParseNumberList(value)
    local ids = {}
    local seen = {}
    if type(value) ~= "string" or value == "" then
        return ids
    end

    for match in value:gmatch("%d+") do
        local id = tonumber(match)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    return ids
end

local function BuildIDLookup(value)
    local lookup = {}
    local ids = ParseNumberList(value)
    for index = 1, #ids do
        lookup[ids[index]] = true
    end
    return lookup
end

local function GetQualityKey(quality)
    local poorQuality = Enum.ItemQuality.Poor or 0
    if quality == poorQuality then
        return "poor"
    end

    local commonQuality = Enum.ItemQuality.Common or Enum.ItemQuality.Standard
    if quality == commonQuality then
        return "common"
    end

    local uncommonQuality = Enum.ItemQuality.Uncommon or Enum.ItemQuality.Good
    if quality == uncommonQuality then
        return "uncommon"
    end

    if quality == Enum.ItemQuality.Rare then
        return "rare"
    end

    if quality == Enum.ItemQuality.Epic then
        return "epic"
    end

    return nil
end

local function QualityValue(path, quality, defaultValue)
    local qualityKey = GetQualityKey(quality)
    if not qualityKey then
        return false
    end

    local n = #path
    local qualPath = {}
    for i = 1, n do
        qualPath[i] = path[i]
    end
    qualPath[n + 1] = qualityKey

    return Value(qualPath, defaultValue) == true
end

local function IsLocationBound(location)
    if not location or not C_Item then
        return false
    end

    local success, isBound = pcall(C_Item.IsBound, location)
    if success and isBound then
        return true
    end

    success, isBound = pcall(C_Item.IsBoundToAccountUntilEquip, location)
    return success and isBound or false
end

local function BuildEquipmentSetLookup()
    local lookup = {}
    local bagsModule = T:GetModule("Bags")
    if not bagsModule or type(bagsModule.ScanEquipmentSets) ~= "function" or type(bagsModule.equipmentSetByGUID) ~= "table" then
        return lookup
    end

    bagsModule:ScanEquipmentSets()
    for itemGUID in pairs(bagsModule.equipmentSetByGUID) do
        lookup[itemGUID] = true
    end

    return lookup
end

local function IsSellableEquipment(item)
    if not item.link or not IsEquippableItem or not IsEquippableItem(item.link) then
        return false
    end

    if IsCosmeticItem and IsCosmeticItem(item.link) then
        return false
    end

    if item.classID == Enum.ItemClass.Armor then
        if AUTOSELL_EQUIPMENT_INVTYPE_EXCEPTIONS[item.invType] then
            return true
        end

        return item.subclassID ~= Enum.ItemArmorSubclass.Generic and item.subclassID ~= Enum.ItemArmorSubclass.Cosmetic
    end

    if item.classID == Enum.ItemClass.Weapon then
        return item.subclassID ~= Enum.ItemWeaponSubclass.Generic and
            item.subclassID ~= Enum.ItemWeaponSubclass.Fishingpole
    end

    return false
end

local function IsArmorSuitableForPlayer(item, playerClass)
    if item.invType == "INVTYPE_CLOAK" or AUTOSELL_EQUIPMENT_INVTYPE_EXCEPTIONS[item.invType] then
        return true
    end

    if item.subclassID == Enum.ItemArmorSubclass.Shield then
        return AUTOSELL_SHIELD_CLASSES[playerClass] == true
    end

    return AUTOSELL_PRIMARY_ARMOR[playerClass] == item.subclassID
end

local function IsWeaponSuitableForPlayer(item, playerClass)
    local proficiency = AUTOSELL_WEAPON_PROFICIENCIES[playerClass]
    if proficiency and proficiency[item.subclassID] then
        return true
    end

    return IsUsableItem and select(1, IsUsableItem(item.link)) == true or false
end

local function IsItemSuitableForPlayer(item)
    if not item.isEquipment then
        return true
    end

    local _, playerClass = UnitClass("player")
    if not playerClass then
        return true
    end

    if item.classID == Enum.ItemClass.Armor then
        return IsArmorSuitableForPlayer(item, playerClass)
    end

    if item.classID == Enum.ItemClass.Weapon then
        return IsWeaponSuitableForPlayer(item, playerClass)
    end

    return true
end

local function IsItemWarbandEquipment(item, location)
    if not (item.isEquipment and C_Bank and C_Bank.IsItemAllowedInBankType and Enum.BankType and Enum.BankType.Account) then
        return false
    end

    local success, isWarband = pcall(C_Bank.IsItemAllowedInBankType, Enum.BankType.Account, location)
    return success and isWarband or false
end

local function IsArtifactRelic(item)
    return item.classID == Enum.ItemClass.Gem and Enum.ItemGemSubclass and
        item.subclassID == Enum.ItemGemSubclass.Artifactrelic
end

local function GetContainerItemLevel(location, link)
    if not (C_Item and C_Item.GetDetailedItemLevelInfo) then
        return 0
    end

    if location then
        local ok, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, location)
        if ok and type(itemLevel) == "number" and itemLevel > 0 then
            return itemLevel
        end
    end

    local ok, itemLevel = pcall(C_Item.GetDetailedItemLevelInfo, link)
    if ok and type(itemLevel) == "number" and itemLevel > 0 then
        return itemLevel
    end

    return 0
end

local function GetContainerSellItem(bagID, slotID, equipmentSetLookup)
    local containerInfo = C_Container.GetContainerItemInfo(bagID, slotID)
    if type(containerInfo) ~= "table" then
        return nil, false
    end

    -- Items explicitly flagged as unsellable by the game - skip immediately
    if containerInfo.hasNoValue then
        return nil, false
    end

    local itemID = containerInfo.itemID
    if not itemID then
        return nil, false
    end

    local link = containerInfo.hyperlink or C_Container.GetContainerItemLink(bagID, slotID)
    if not link then
        return nil, false
    end

    -- GetItemInfo is async; link-based lookup may return nil for uncached items.
    -- Fall back to numeric itemID which the game loads synchronously on bag open.
    local itemName, _, quality, _, _, _, _, _, invType, _, vendorPrice, classID, subclassID = GetItemInfo(link)
    if not itemName then
        itemName, _, quality, _, _, _, _, _, invType, _, vendorPrice, classID, subclassID = GetItemInfo(itemID)
    end

    -- containerInfo.quality is always available synchronously; use as authoritative fallback
    quality = quality or containerInfo.quality

    if vendorPrice == nil then
        if RequestLoadItemDataByID then
            RequestLoadItemDataByID(itemID)
        end
        return nil, true
    end

    if vendorPrice <= 0 then
        return nil, false
    end

    local location = ItemLocation and ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if not location then
        return nil, false
    end

    local item = {
        bagID = bagID,
        slotID = slotID,
        itemID = itemID,
        link = link,
        name = itemName or link,
        quality = quality or containerInfo.quality,
        itemLevel = GetContainerItemLevel(location, link),
        vendorPrice = vendorPrice,
        stackCount = containerInfo.stackCount or 1,
        totalPrice = vendorPrice * (containerInfo.stackCount or 1),
        classID = classID,
        subclassID = subclassID,
        invType = invType,
        isLocked = containerInfo.isLocked == true,
        isRefundable = false,
        isEquipment = false,
        isEquipmentSet = false,
        isBound = false,
        isSuitable = true,
        isWarbandEquipment = false,
    }

    local purchaseInfo = C_Container.GetContainerItemPurchaseInfo(bagID, slotID, false)
    item.isRefundable = purchaseInfo and purchaseInfo.refundSeconds and purchaseInfo.refundSeconds > 0 or false
    item.isEquipment = IsSellableEquipment(item)
    item.isBound = IsLocationBound(location)

    if C_Item and C_Item.GetItemGUID then
        local itemGUID = C_Item.GetItemGUID(location)
        item.isEquipmentSet = itemGUID and equipmentSetLookup[itemGUID] == true or false
    end

    if item.isEquipment then
        item.isSuitable = IsItemSuitableForPlayer(item)
        item.isWarbandEquipment = IsItemWarbandEquipment(item, location)
    end

    return item
end

-- Fire GetItemInfo for every occupied bag slot to warm the async item info cache.
-- This ensures vendorPrice is populated by the time we build the sell queue.
local function WarmItemInfoCache()
    for bagID = 0, AUTOSELL_BAG_MAX do
        for slotID = 1, C_Container.GetContainerNumSlots(bagID) do
            local itemID = C_Container.GetContainerItemID(bagID, slotID)
            if itemID then
                GetItemInfo(itemID)
            end
        end
    end
end

local function GetAutoSellSettings()
    return {
        includeLookup = BuildIDLookup(Value({ "automation", "autoSellIncludeList" }, "")),
        excludeLookup = BuildIDLookup(Value({ "automation", "autoSellExcludeList" }, "")),
        showSummary = Value({ "automation", "autoSellShowSummary" }, true) == true,
        safeMode = Value({ "automation", "autoSellSafeMode" }, false) == true,
        excludeEquipmentSets = Value({ "automation", "autoSellExcludeEquipmentSets" }, true) == true,
        excludeUnbound = Value({ "automation", "autoSellExcludeUnboundEquipment" }, false) == true,
        excludeWarband = Value({ "automation", "autoSellExcludeWarbandEquipment" }, false) == true,
        includeBelowEnabled = Value({ "automation", "autoSellIncludeBelowItemLevel", "enabled" }, false) == true,
        includeBelowValue = Value({ "automation", "autoSellIncludeBelowItemLevel", "value" }, 0) or 0,
        includeUnsuitable = Value({ "automation", "autoSellIncludeUnsuitableEquipment" }, false) == true,
        includeArtifactRelics = Value({ "automation", "autoSellIncludeArtifactRelics" }, false) == true,
        legacyKeepUnboundGrey = Value({ "automation", "autoSellExcludeGreyGear" }, false) == true,
    }
end

local function HasActiveAutoSellRule()
    if not GetOptions():GetEnabled() then
        return false
    end

    if Value({ "automation", "autoSellJunk" }, false) == true then
        return true
    end

    if Value({ "automation", "autoSellIncludeBelowItemLevel", "enabled" }, false) == true and
        (Value({ "automation", "autoSellIncludeBelowItemLevel", "value" }, 0) or 0) > 0 then
        return true
    end

    if Value({ "automation", "autoSellIncludeUnsuitableEquipment" }, false) == true then
        return true
    end

    if Value({ "automation", "autoSellIncludeArtifactRelics" }, false) == true then
        return true
    end

    local includeList = Value({ "automation", "autoSellIncludeList" }, "")
    return type(includeList) == "string" and strmatch(includeList, "%S") ~= nil
end

local function IsAutoSellItem(item, settings)
    if not item or item.isRefundable or item.isLocked or not item.itemID then
        return false
    end

    if settings.excludeLookup[item.itemID] then
        return false
    end

    if settings.includeLookup[item.itemID] then
        return true
    end

    if item.isEquipment and settings.excludeEquipmentSets and item.isEquipmentSet then
        return false
    end

    if item.isEquipment and not item.isBound then
        if settings.legacyKeepUnboundGrey and item.quality == Enum.ItemQuality.Poor then
            return false
        end

        if settings.excludeUnbound and QualityValue({ "automation", "autoSellExcludeUnboundEquipmentQualities" }, item.quality, false) then
            return false
        end
    end

    if item.isEquipment and settings.excludeWarband and item.isWarbandEquipment and
        QualityValue({ "automation", "autoSellExcludeWarbandEquipmentQualities" }, item.quality, false) then
        return false
    end

    if QualityValue({ "automation", "autoSellIncludeByQuality" }, item.quality, false) then
        return true
    end

    if item.isEquipment and settings.includeBelowEnabled and settings.includeBelowValue > 0 and item.itemLevel > 0 and
        item.itemLevel < settings.includeBelowValue and
        QualityValue({ "automation", "autoSellIncludeBelowItemLevel", "qualities" }, item.quality, false) then
        return true
    end

    if item.isEquipment and settings.includeUnsuitable and not item.isSuitable and
        QualityValue({ "automation", "autoSellIncludeUnsuitableEquipmentQualities" }, item.quality, false) then
        return true
    end

    if settings.includeArtifactRelics and IsArtifactRelic(item) then
        return true
    end

    return false
end

local function BuildAutoSellQueue()
    local settings = GetAutoSellSettings()
    local equipmentSetLookup = BuildEquipmentSetLookup()
    local items = {}
    local hasPendingItemData = false

    for bagID = 0, AUTOSELL_BAG_MAX do
        for slotID = 1, C_Container.GetContainerNumSlots(bagID) do
            local item, pendingItemData = GetContainerSellItem(bagID, slotID, equipmentSetLookup)
            if item and IsAutoSellItem(item, settings) then
                items[#items + 1] = item
            elseif pendingItemData then
                hasPendingItemData = true
            end
        end
    end

    sort(items, function(left, right)
        if left.totalPrice ~= right.totalPrice then
            return left.totalPrice < right.totalPrice
        end

        if left.quality ~= right.quality then
            return left.quality < right.quality
        end

        if left.name ~= right.name then
            return left.name < right.name
        end

        return left.stackCount < right.stackCount
    end)

    local truncated = false
    if settings.safeMode and #items > AUTOSELL_SAFE_MODE_LIMIT then
        while #items > AUTOSELL_SAFE_MODE_LIMIT do
            items[#items] = nil
        end
        truncated = true
    end

    return items, settings, truncated, hasPendingItemData
end

local function GetAutoSellIntervalSeconds()
    local _, _, homeLatency, worldLatency = GetNetStats()
    local configuredMs = Value({ "automation", "autoSellThrottleMs" }, 150) or 150
    return max(0.08, (configuredMs / 1000), max(homeLatency or 0, worldLatency or 0) / 1000)
end

local function IsMerchantVisible()
    return _G.MerchantFrame and _G.MerchantFrame:IsShown()
end

local function FormatMoney(copper)
    return T.Tools and T.Tools.Text and T.Tools.Text.FormatCopper(copper)
        or C_CurrencyInfo.GetCoinText(copper)
end

local function ParseSoundRefList(value)
    local ids = {}
    local seen = {}

    for index = 1, #(value or {}) do
        local ref = value[index]
        local soundID = type(ref) == "string" and ref:match("#(%d+)$")
        local id = soundID and tonumber(soundID)
        if id and not seen[id] then
            seen[id] = true
            ids[#ids + 1] = id
        end
    end

    return ids
end

local function AppendUniqueIDs(target, source)
    local seen = {}
    for index = 1, #target do
        seen[target[index]] = true
    end

    for index = 1, #source do
        local id = source[index]
        if not seen[id] then
            seen[id] = true
            target[#target + 1] = id
        end
    end
end

local function CollectPresetSoundIDs(pathKey, presetTable)
    local ids = {}
    for presetKey, soundRefs in pairs(presetTable) do
        if Value({ "system", pathKey, presetKey }, false) then
            AppendUniqueIDs(ids, ParseSoundRefList(soundRefs))
        end
    end
    return ids
end

local function CollectPresetNumberIDs(pathKey, presetTable)
    local ids = {}
    for presetKey, values in pairs(presetTable) do
        if Value({ "system", pathKey, presetKey }, false) then
            AppendUniqueIDs(ids, values)
        end
    end
    return ids
end

local function SetSoundBucket(bucketName, ids, enabled)
    local bucket = mutedSoundBuckets[bucketName]
    local desired = {}

    for index = 1, #ids do
        desired[ids[index]] = true
    end

    for soundID in pairs(bucket) do
        if not enabled or not desired[soundID] then
            _G.UnmuteSoundFile(soundID)
            bucket[soundID] = nil
        end
    end

    if enabled then
        for soundID in pairs(desired) do
            if not bucket[soundID] then
                _G.MuteSoundFile(soundID)
                bucket[soundID] = true
            end
        end
    end
end

local function IsInLFGQueue()
    return _G.GetLFGMode and _G.GetLFGMode(LE_LFG_CATEGORY_LFD) or false
end

local function NormalizeName(name)
    if not name then
        return nil
    end
    return strsplit("-", name, 2)
end

local function IsTrustedPlayer(name, guid)
    if not name then
        return false
    end

    if C_FriendList and C_FriendList.ShowFriends then
        C_FriendList.ShowFriends()
    end

    local shortName = NormalizeName(name)

    if C_FriendList and C_FriendList.GetNumFriends then
        for index = 1, C_FriendList.GetNumFriends() do
            local friendInfo = C_FriendList.GetFriendInfoByIndex(index)
            if friendInfo and NormalizeName(friendInfo.name) == shortName then
                if not guid or not friendInfo.guid or friendInfo.guid == guid then
                    return true
                end
            end
        end
    end

    if _G.BNGetNumFriends then
        for friendIndex = 1, _G.BNGetNumFriends() do
            local numAccounts = C_BattleNet and C_BattleNet.GetFriendNumGameAccounts and
                C_BattleNet.GetFriendNumGameAccounts(friendIndex) or 0
            for accountIndex = 1, numAccounts do
                local accountInfo = C_BattleNet.GetFriendGameAccountInfo(friendIndex, accountIndex)
                if accountInfo and accountInfo.clientProgram == "WoW" and NormalizeName(accountInfo.characterName) == shortName then
                    return true
                end
            end
        end
    end

    if Value({ "social", "friendlyGuild" }, false) and _G.GetNumGuildMembers then
        for guildIndex = 1, _G.GetNumGuildMembers() do
            local guildName, _, _, _, _, _, _, _, online, _, _, _, _, mobile, _, _, guildGUID = _G.GetGuildRosterInfo(
                guildIndex)
            if online and not mobile and NormalizeName(guildName) == shortName then
                if not guid or not guildGUID or guildGUID == guid then
                    return true
                end
            end
        end
    end

    if Value({ "social", "friendlyCommunities" }, false) and C_Club and CommunitiesUtil then
        local clubs = C_Club.GetSubscribedClubs() or {}
        for _, club in pairs(clubs) do
            if club.clubType == Enum.ClubType.Character then
                local memberIds = CommunitiesUtil.GetMemberIdsSortedByName(club.clubId)
                local members = CommunitiesUtil.GetMemberInfo(club.clubId, memberIds)
                for _, member in pairs(members or {}) do
                    if member and member.name and member.presence and member.presence ~= Enum.ClubMemberPresence.Offline and member.presence ~= Enum.ClubMemberPresence.OnlineMobile then
                        if NormalizeName(member.name) == shortName and (not guid or not member.guid or member.guid == guid) then
                            return true
                        end
                    end
                end
            end
        end
    end

    return false
end

local function EnsureBodyguardNames()
    if bodyguardNames then
        return
    end

    bodyguardNames = {}
    for index = 1, #bodyguardIDs do
        local reputationInfo = C_GossipInfo.GetFriendshipReputation and
            C_GossipInfo.GetFriendshipReputation(bodyguardIDs[index])
        if reputationInfo and reputationInfo.name then
            bodyguardNames[reputationInfo.name] = true
        end
    end
end

local function HideQuickJoinToast(enabled)
    if _G["QuickJoinToastButton"] then
        if not originalState.quickJoinParent then
            originalState.quickJoinParent = _G["QuickJoinToastButton"]:GetParent()
        end
        _G["QuickJoinToastButton"]:SetParent(enabled and hiddenParent or originalState.quickJoinParent or UIParent)
        if enabled then
            _G["QuickJoinToastButton"]:Hide()
        end
    end
end

function GT:ApplyFrameTweaks()
    if _G["BossBanner"] then
        if Feature({ "frames", "hideBossBanner" }) then
            _G["BossBanner"]:UnregisterEvent("ENCOUNTER_LOOT_RECEIVED")
            _G["BossBanner"]:UnregisterEvent("BOSS_KILL")
        else
            _G["BossBanner"]:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
            _G["BossBanner"]:RegisterEvent("BOSS_KILL")
        end
    end

    if _G.BagItemAutoSortButton then
        if Feature({ "frames", "hideCleanupBtns" }) then
            _G.BagItemAutoSortButton:Hide()
        else
            _G.BagItemAutoSortButton:Show()
        end
    end

    if _G.BankPanel and _G.BankPanel.AutoSortButton then
        if Feature({ "frames", "hideCleanupBtns" }) then
            _G.BankPanel.AutoSortButton:Hide()
        else
            _G.BankPanel.AutoSortButton:Show()
        end
    end

    if _G.StanceBar then
        if not originalState.stanceParent then
            originalState.stanceParent = _G.StanceBar:GetParent()
        end
        if Feature({ "frames", "noClassBar" }) then
            _G.StanceBar:SetParent(hiddenParent)
            _G.StanceBar:Hide()
        else
            _G.StanceBar:SetParent(originalState.stanceParent or UIParent)
            _G.StanceBar:Show()
        end
    end

    if _G.PlayerFrame and _G.PlayerFrame.PlayerFrameContent and _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual and _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PlayerRestLoop then
        local restTexture = _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PlayerRestLoop.RestTexture
        if restTexture then
            if not originalState.playerRestTexture then
                originalState.playerRestTexture = restTexture:GetTexture()
            end
            restTexture:SetTexture(Feature({ "frames", "noRestedSleep" }) and "" or originalState.playerRestTexture)
        end
    end

    HideQuickJoinToast(Feature({ "frames", "noAlerts" }))
end

local function UpdateRestedEmoteSetting()
    if originalState.emoteSounds == nil then
        originalState.emoteSounds = _G.GetCVar("Sound_EnableEmoteSounds")
    end

    local shouldMute = false
    if Feature({ "system", "noRestedEmotes" }) then
        local zone = _G.GetSubZoneText() or ""
        if IsResting() or C_PetBattles.IsInBattle() or zone == "The Halfhill Market" or zone == "The Grim Guzzler" or zone == "The Summer Terrace" then
            shouldMute = true
        end
    end

    _G.SetCVar("Sound_EnableEmoteSounds", shouldMute and "0" or tostring(originalState.emoteSounds or "1"))
end

local function ApplyCVars()
    SaveOriginalCVar("ffxGlow", "ffxGlow")
    SaveOriginalCVar("ffxDeath", "ffxDeath")
    SaveOriginalCVar("ffxNether", "ffxNether")
    SaveOriginalCVar("ffxVenari", "ffxVenari")
    SaveOriginalCVar("ffxLingeringVenari", "ffxLingeringVenari")
    SaveOriginalCVar("weatherDensity", "WeatherDensity")
    SaveOriginalCVar("raidWeatherDensity", "RAIDweatherDensity")
    SaveOriginalCVar("cameraDistanceMaxZoomFactor", "cameraDistanceMaxZoomFactor")
    SaveOriginalCVar("pingSounds", "Sound_EnablePingSounds")
    SaveOriginalCVar("soundOutputDriverIndex", "Sound_OutputDriverIndex")

    _G.SetCVar("ffxGlow", Feature({ "system", "noScreenGlow" }) and "0" or tostring(originalState.ffxGlow or "1"))

    if Feature({ "system", "noScreenEffects" }) then
        _G.SetCVar("ffxDeath", "0")
        _G.SetCVar("ffxNether", "0")
        _G.SetCVar("ffxVenari", "0")
        _G.SetCVar("ffxLingeringVenari", "0")
    else
        _G.SetCVar("ffxDeath", tostring(originalState.ffxDeath or "1"))
        _G.SetCVar("ffxNether", tostring(originalState.ffxNether or "1"))
        _G.SetCVar("ffxVenari", tostring(originalState.ffxVenari or "1"))
        _G.SetCVar("ffxLingeringVenari", tostring(originalState.ffxLingeringVenari or "1"))
    end

    if Feature({ "system", "setWeatherDensity" }) then
        local level = tostring(Value({ "system", "weatherLevel" }, 3))
        _G.SetCVar("WeatherDensity", level)
        _G.SetCVar("RAIDweatherDensity", level)
    else
        _G.SetCVar("WeatherDensity", tostring(originalState.weatherDensity or "3"))
        _G.SetCVar("RAIDweatherDensity", tostring(originalState.raidWeatherDensity or "3"))
    end

    _G.SetCVar("cameraDistanceMaxZoomFactor",
        Feature({ "system", "maxCameraZoom" }) and "2.6" or tostring(originalState.cameraDistanceMaxZoomFactor or "1.9"))

    if Feature({ "system", "keepAudioSynced" }) then
        _G.SetCVar("Sound_OutputDriverIndex", "0")
    else
        _G.SetCVar("Sound_OutputDriverIndex", tostring(originalState.soundOutputDriverIndex or "0"))
    end

    _G.SetCVar("Sound_EnablePingSounds",
        Feature({ "system", "mutePingSounds" }) and "0" or tostring(originalState.pingSounds or "1"))
end

local function ApplySoundMutes()
    local gameIDs = ParseNumberList(Value({ "system", "muteGameSoundIDs" }, ""))
    local toyIDs = ParseNumberList(Value({ "system", "muteToySoundIDs" }, ""))
    local mountIDs = ParseNumberList(Value({ "system", "muteMountSoundIDs" }, ""))

    AppendUniqueIDs(toyIDs, CollectPresetSoundIDs("presetToys", SOUND_PRESETS.toy))
    AppendUniqueIDs(mountIDs, CollectPresetSoundIDs("presetMounts", SOUND_PRESETS.mount))

    SetSoundBucket("game", gameIDs, Feature({ "system", "muteGameSounds" }))
    SetSoundBucket("toy", toyIDs, Feature({ "system", "muteToySounds" }))
    SetSoundBucket("mount", mountIDs, Feature({ "system", "muteMountSounds" }))
    SetSoundBucket("custom", ParseNumberList(Value({ "system", "muteCustomSoundIDs" }, "")),
        Feature({ "system", "muteCustomSounds" }))
end

local function BuildTransformSet()
    local set = {}
    if not Feature({ "system", "noTransforms" }) then
        return set
    end

    local presetIDs = CollectPresetNumberIDs("presetTransforms", TRANSFORM_PRESETS)
    for index = 1, #presetIDs do
        set[presetIDs[index]] = true
    end

    local custom = ParseNumberList(Value({ "system", "transformSpellIDs" }, ""))
    for index = 1, #custom do
        set[custom[index]] = true
    end

    return set
end

local cachedTransformSet
local cachedTransformSignature

local function GetSortedTransformPresetKeys()
    local keys = {}
    for key in pairs(TRANSFORM_PRESETS) do
        keys[#keys + 1] = key
    end
    table.sort(keys)
    return keys
end

local function BuildTransformSignature()
    if not Feature({ "system", "noTransforms" }) then
        return "disabled"
    end

    local parts = {
        tostring(Value({ "system", "transformSpellIDs" }, "") or ""),
    }

    local presetKeys = GetSortedTransformPresetKeys()
    for index = 1, #presetKeys do
        local key = presetKeys[index]
        parts[#parts + 1] = key .. ":" .. tostring(Value({ "system", "presetTransforms", key }, false) and 1 or 0)
    end

    return table.concat(parts, "|")
end

local function GetCachedTransformSet()
    local signature = BuildTransformSignature()
    if cachedTransformSignature ~= signature or not cachedTransformSet then
        cachedTransformSignature = signature
        cachedTransformSet = BuildTransformSet()
    end

    return cachedTransformSet
end

local function HasSecretValues(...)
    if type(hasanysecretvalues) == "function" then
        local ok, hasSecret = pcall(hasanysecretvalues, ...)
        if ok and hasSecret then
            return true
        end
    end

    return false
end

local function CancelBlockedTransforms()
    local blocked = GetCachedTransformSet()
    if not next(blocked) then
        return
    end

    local cancelUnitBuff = _G.CancelUnitBuff
    for index = 1, 40 do
        local aura = _G.C_UnitAuras and _G.C_UnitAuras.GetBuffDataByIndex and
            _G.C_UnitAuras.GetBuffDataByIndex("player", index)
        if aura then
            local spellID = aura.spellId
            if spellID and not HasSecretValues(spellID) and blocked[spellID] then
                if not _G.UnitAffectingCombat("player") and type(cancelUnitBuff) == "function" then
                    cancelUnitBuff("player", index)
                end
                return
            end
        end
    end
end

local function IsCriticalUiError(err)
    if HasSecretValues(err) then
        return true
    end

    return err == _G.ERR_INV_FULL
        or err == _G.ERR_QUEST_LOG_FULL
        or err == _G.ERR_RAID_GROUP_ONLY
        or err == _G.ERR_PLAYER_DEAD
        or err == _G.ERR_PET_SPELL_DEAD
        or err == _G.ERR_PARTY_LFG_TELEPORT_IN_COMBAT
end

local function InstallErrorFilter()
    if errorFilterInstalled then
        return
    end

    originalErrorHandler = originalErrorHandler or UIErrorsFrame:GetScript("OnEvent")
    UIErrorsFrame:SetScript("OnEvent", function(self, event, id, err, ...)
        if event == "UI_ERROR_MESSAGE" and Feature({ "text", "hideErrorMessages" }) then
            if Value({ "text", "showCriticalErrors" }, true) and IsCriticalUiError(err) then
                if originalErrorHandler then
                    return originalErrorHandler(self, event, id, err, ...)
                end
                return
            end
            return
        end

        if originalErrorHandler then
            return originalErrorHandler(self, event, id, err, ...)
        end
    end)
    errorFilterInstalled = true
    UIParent:UnregisterEvent("PING_SYSTEM_ERROR")
end

local function RemoveErrorFilter()
    if not errorFilterInstalled then
        return
    end

    UIErrorsFrame:SetScript("OnEvent", originalErrorHandler)
    errorFilterInstalled = false
    UIParent:RegisterEvent("PING_SYSTEM_ERROR")
end

local function InstallHooks()
    if hooksInstalled then
        return
    end
    hooksInstalled = true

    if EventToastManagerFrame then
        hooksecurefunc(EventToastManagerFrame, "Show", function()
            if Feature({ "frames", "hideEventToasts" }) and EventToastManagerFrame.currentDisplayingToast and not EventToastManagerFrame.HideButton:IsShown() then
                EventToastManagerFrame.currentDisplayingToast:OnAnimatedOut()
            end
        end)
    end

    if _G.TalkingHeadFrame then
        hooksecurefunc(_G.TalkingHeadFrame, "PlayCurrent", function(self)
            if Feature({ "frames", "hideTalkingFrame" }) then
                self:Hide()
            end
        end)
    end

    if _G.CinematicFrame then
        _G.CinematicFrame:HookScript("OnKeyDown", function(self, key)
            if key == "ESCAPE" and Feature({ "system", "fasterMovieSkip" }) and self.closeDialog and _G.CinematicFrameCloseDialog then
                _G.CinematicFrameCloseDialog:Hide()
            end
        end)
        _G.CinematicFrame:HookScript("OnKeyUp", function(self, key)
            if Feature({ "system", "fasterMovieSkip" }) and (key == "SPACE" or key == "ESCAPE" or key == "ENTER") and self.closeDialog and _G.CinematicFrameCloseDialogConfirmButton then
                _G.CinematicFrameCloseDialogConfirmButton:Click()
            end
        end)
    end

    if _G.MovieFrame then
        _G.MovieFrame:HookScript("OnKeyUp", function(self, key)
            if Feature({ "system", "fasterMovieSkip" }) and (key == "SPACE" or key == "ESCAPE" or key == "ENTER") and self.CloseDialog and self.CloseDialog.ConfirmButton then
                self.CloseDialog.ConfirmButton:Click()
            end
        end)
    end

    hooksecurefunc("StaticPopup_Show", function(dialogType)
        if Feature({ "system", "noConfirmLoot" }) then
            if dialogType == "SELL_ITEM" then
                _G.StaticPopup_Hide("SELL_ITEM")
                if _G.SELL_CURSOR_ITEM then
                    _G.SELL_CURSOR_ITEM()
                end
                return
            end

            if dialogType == "USE_BIND" then
                _G.StaticPopup_Hide("USE_BIND")
                return
            end
        end

        if dialogType ~= "DEATH" or not Feature({ "automation", "autoReleasePvP" }) then
            return
        end

        local ctx = GetAutoReleaseContext()
        local allowed, reason = ShouldAutoReleaseInContext(ctx)
        GTLog(string.format(
            "autoReleasePvP DEATH popup: allowed=%s reason=%s instanceType=%s instanceName=%s mapID=%s instanceMapID=%s lfgDungeonID=%s",
            tostring(allowed), tostring(reason), tostring(ctx.instanceType), tostring(ctx.instanceName),
            tostring(ctx.mapID), tostring(ctx.instanceMapID), tostring(ctx.lfgDungeonID)))

        if not allowed then
            return
        end

        if C_DeathInfo.GetSelfResurrectOptions() and #C_DeathInfo.GetSelfResurrectOptions() > 0 then
            GTLog("autoReleasePvP skipped: self-resurrect option available")
            return
        end

        local function shouldSkip(mapID)
            if mapID == 91 or mapID == 1537 then
                return Value({ "automation", "excludeAlterac" }, false)
            end
            if mapID == 123 or mapID == 1334 then
                return Value({ "automation", "excludeWintergrasp" }, false)
            end
            if mapID == 244 then
                return Value({ "automation", "excludeTolBarad" }, false)
            end
            if mapID == 588 or mapID == 622 or mapID == 624 or mapID == 1478 then
                return Value({ "automation", "excludeAshran" }, false)
            end
            return false
        end

        local mapID = C_Map.GetBestMapForUnit("player") or 0
        if shouldSkip(mapID) then
            GTLog(string.format("autoReleasePvP skipped: excluded mapID=%s", tostring(mapID)))
            return
        end

        local delay = (Value({ "automation", "releaseDelayMs" }, 0) or 0) / 1000
        GTLog(string.format("autoReleasePvP scheduled: delay=%.3f mapID=%s instanceType=%s", delay, tostring(mapID),
            tostring(ctx.instanceType)))
        C_Timer.After(delay, function()
            local dialog = _G.StaticPopup_Visible("DEATH")
            if dialog and not IsShiftKeyDown() then
                GTLog("autoReleasePvP executing: clicking DEATH popup")
                _G.StaticPopup_OnClick(_G[dialog], 1)
            elseif not dialog then
                GTLog("autoReleasePvP canceled: DEATH popup no longer visible")
            else
                GTLog("autoReleasePvP canceled: Shift held down")
            end
        end)
    end)

    if _G.QuestSessionManager and _G.QuestSessionManager.StartDialog then
        hooksecurefunc(_G.QuestSessionManager.StartDialog, "Show", function(self)
            if not Feature({ "social", "syncFromFriends" }) then
                return
            end
            local details = C_QuestSession.GetSessionBeginDetails()
            if not details then
                return
            end
            for _, unit in ipairs({ "player", "party1", "party2", "party3", "party4" }) do
                if UnitGUID(unit) == details.guid and IsTrustedPlayer(UnitName(unit), details.guid) then
                    self.ButtonContainer.Confirm:Click()
                    break
                end
            end
        end)
    end

    EventUtil.ContinueOnAddOnLoaded("Blizzard_PerksProgram", function()
        if _G.PerksProgramFrame and _G.PerksProgramFrame.FooterFrame then
            if _G.PerksProgramFrame.FooterFrame.ToggleAttackAnimation then
                hooksecurefunc(_G.PerksProgramFrame.FooterFrame.ToggleAttackAnimation, "SetChecked", function(self)
                    if Feature({ "system", "addOptNoCombatBox" }) and self:GetChecked() then
                        self:Click()
                    end
                end)
            end
            if _G.PerksProgramFrame.FooterFrame.ToggleMountSpecial then
                hooksecurefunc(_G.PerksProgramFrame.FooterFrame.ToggleMountSpecial, "SetChecked", function(self)
                    if Feature({ "system", "addOptNoMountBox" }) and self:GetChecked() then
                        self:Click()
                        if _G.PerksProgramFrame.SetMountSpecialPreviewOnClick then
                            _G.PerksProgramFrame:SetMountSpecialPreviewOnClick(false)
                        end
                    end
                end)
            end
        end
    end)
end

function GT:RefreshSettings()
    if not self:IsEnabled() then
        return
    end

    ApplyCVars()
    ApplySoundMutes()
    self:ApplyFrameTweaks()
    UpdateRestedEmoteSetting()

    if Feature({ "text", "hideErrorMessages" }) then
        InstallErrorFilter()
    else
        RemoveErrorFilter()
    end

    local shouldMerchant = HasActiveAutoSellRule() or Feature({ "automation", "autoRepairGear" })
    if shouldMerchant then
        self:RegisterEvent("MERCHANT_SHOW")
        self:RegisterEvent("MERCHANT_CLOSED")
        self:RegisterEvent("UI_ERROR_MESSAGE")
    else
        self:UnregisterEvent("MERCHANT_SHOW")
        self:UnregisterEvent("MERCHANT_CLOSED")
        self:UnregisterEvent("UI_ERROR_MESSAGE")
        self:AbortAutoSellSession()
    end

    if HasActiveAutoSellRule() then
        self:RegisterEvent("BAG_UPDATE_DELAYED")
    else
        self:UnregisterEvent("BAG_UPDATE_DELAYED")
    end

    local events = {
        { path = { "social", "acceptPartyFriends" },   name = "PARTY_INVITE_REQUEST" },
        { path = { "social", "noPartyInvites" },       name = "PARTY_INVITE_REQUEST" },
        { path = { "social", "noRequestedInvites" },   name = "GROUP_INVITE_CONFIRMATION" },
        { path = { "social", "noFriendRequests" },     name = "BN_FRIEND_INVITE_ADDED" },
        { path = { "social", "noDuelRequests" },       name = "DUEL_REQUESTED" },
        { path = { "social", "noPetDuels" },           name = "PET_BATTLE_PVP_DUEL_REQUESTED" },
        { path = { "social", "inviteFromWhisper" },    name = "CHAT_MSG_WHISPER" },
        { path = { "social", "autoConfirmRole" },      name = "LFG_ROLE_CHECK_SHOW" },
        { path = { "social", "noSharedQuests" },       name = "QUEST_ACCEPT_CONFIRM" },
        { path = { "automation", "autoAcceptSummon" }, name = "CONFIRM_SUMMON" },
        { path = { "automation", "autoAcceptRes" },    name = "RESURRECT_REQUEST" },
        { path = { "frames", "hideBodyguard" },        name = "GOSSIP_SHOW" },
        { path = { "system", "noTransforms" },         name = "UNIT_AURA" },
        { path = { "system", "noRestedEmotes" },       name = "PLAYER_UPDATE_RESTING" },
        { path = { "system", "noRestedEmotes" },       name = "ZONE_CHANGED_NEW_AREA" },
        { path = { "system", "noRestedEmotes" },       name = "ZONE_CHANGED" },
        { path = { "system", "noRestedEmotes" },       name = "ZONE_CHANGED_INDOORS" },
        { path = { "system", "keepAudioSynced" },      name = "VOICE_CHAT_OUTPUT_DEVICES_UPDATED" },
        { path = { "system", "noConfirmLoot" },        name = "CONFIRM_LOOT_ROLL" },
        { path = { "system", "noConfirmLoot" },        name = "CONFIRM_DISENCHANT_ROLL" },
    }

    local wanted = {}
    for index = 1, #events do
        if Feature(events[index].path) then
            wanted[events[index].name] = true
        end
    end

    if Feature({ "system", "noTransforms" }) then
        wanted.PLAYER_REGEN_ENABLED = true
        if Value({ "system", "presetTransforms", "fishing" }, false) then
            wanted.UNIT_SPELLCAST_CHANNEL_STOP = true
        end
    end
    wanted.PLAYER_ENTERING_WORLD = true

    for eventName in pairs(wanted) do
        self:RegisterEvent(eventName)
    end

    local known = {
        "PARTY_INVITE_REQUEST", "GROUP_INVITE_CONFIRMATION", "BN_FRIEND_INVITE_ADDED", "DUEL_REQUESTED",
        "PET_BATTLE_PVP_DUEL_REQUESTED", "CHAT_MSG_WHISPER", "LFG_ROLE_CHECK_SHOW", "QUEST_ACCEPT_CONFIRM",
        "CONFIRM_SUMMON", "RESURRECT_REQUEST", "GOSSIP_SHOW", "UNIT_AURA",
        "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA", "ZONE_CHANGED", "ZONE_CHANGED_INDOORS",
        "VOICE_CHAT_OUTPUT_DEVICES_UPDATED", "CONFIRM_LOOT_ROLL", "CONFIRM_DISENCHANT_ROLL", "PLAYER_REGEN_ENABLED",
        "UNIT_SPELLCAST_CHANNEL_STOP", "BAG_UPDATE_DELAYED",
        "PLAYER_ENTERING_WORLD"
    }
    for index = 1, #known do
        if not wanted[known[index]] then
            self:UnregisterEvent(known[index])
        end
    end
end

function GT:PLAYER_ENTERING_WORLD()
    self:RefreshSettings()
end

function GT:PLAYER_REGEN_ENABLED()
    if Feature({ "system", "noTransforms" }) then
        CancelBlockedTransforms()
    end
end

function GT:PARTY_INVITE_REQUEST(event, inviterName, _, _, _, _, inviterGUID)
    if Feature({ "social", "acceptPartyFriends" }) and IsTrustedPlayer(inviterName, inviterGUID) and not IsInLFGQueue() then
        _G.AcceptGroup()
        _G.StaticPopup_Hide("PARTY_INVITE")
        _G.StaticPopup_Hide("PARTY_INVITE_XREALM")
        if _G.QuestSessionManager and _G.QuestSessionManager.ConfirmInviteToGroupReceivedDialog and _G.QuestSessionManager.ConfirmInviteToGroupReceivedDialog.ButtonContainer.Confirm:IsShown() then
            _G.QuestSessionManager.ConfirmInviteToGroupReceivedDialog.ButtonContainer.Confirm:Click()
        end
        return
    end

    if Feature({ "social", "noPartyInvites" }) and not IsTrustedPlayer(inviterName, inviterGUID) then
        _G.DeclineGroup()
        _G.StaticPopup_Hide("PARTY_INVITE")
        _G.StaticPopup_Hide("PARTY_INVITE_XREALM")
        if _G.QuestSessionManager and _G.QuestSessionManager.ConfirmInviteToGroupReceivedDialog and _G.QuestSessionManager.ConfirmInviteToGroupReceivedDialog.ButtonContainer.Decline:IsShown() then
            _G.QuestSessionManager.ConfirmInviteToGroupReceivedDialog.ButtonContainer.Decline:Click()
        end
    end
end

function GT:GROUP_INVITE_CONFIRMATION()
    if not Feature({ "social", "noRequestedInvites" }) then
        return
    end
    local popup = _G.StaticPopup_FindVisible("GROUP_INVITE_CONFIRMATION")
    if popup and popup.data then
        local _, name, guid = _G.GetInviteConfirmationInfo(popup.data)
        if not IsTrustedPlayer(name, guid) then
            _G.RespondToInviteConfirmation(popup.data, false)
            _G.StaticPopup_Hide("GROUP_INVITE_CONFIRMATION")
        end
    end
end

function GT:BN_FRIEND_INVITE_ADDED()
    if not Feature({ "social", "noFriendRequests" }) or not _G.BNGetNumFriendInvites then
        return
    end
    for index = _G.BNGetNumFriendInvites(), 1, -1 do
        local inviteID = _G.BNGetFriendInviteInfo(index)
        if inviteID then
            _G.BNDeclineFriendInvite(inviteID)
        end
    end
end

function GT:DUEL_REQUESTED(_, challengerName)
    if Feature({ "social", "noDuelRequests" }) and not IsTrustedPlayer(challengerName) then
        _G.CancelDuel()
        _G.StaticPopup_Hide("DUEL_REQUESTED")
    end
end

function GT:PET_BATTLE_PVP_DUEL_REQUESTED(_, challengerName)
    if Feature({ "social", "noPetDuels" }) and not IsTrustedPlayer(challengerName) then
        C_PetBattles.CancelPVPDuel()
    end
end

function GT:CHAT_MSG_WHISPER(_, message, author)
    if not Feature({ "social", "inviteFromWhisper" }) then
        return
    end

    local keyword = strlower(Value({ "social", "inviteKeyword" }, "inv") or "inv")
    if strlower(message or "") ~= keyword then
        return
    end

    if Value({ "social", "inviteFriendsOnly" }, true) and not IsTrustedPlayer(author) then
        return
    end

    if _G.IsInGroup() and not _G.UnitIsGroupLeader("player") and not _G.UnitIsGroupAssistant("player") then
        return
    end

    if _G["InviteUnit"] then
        _G["InviteUnit"](author)
    end
end

function GT:LFG_ROLE_CHECK_SHOW()
    if Feature({ "social", "autoConfirmRole" }) and _G.CompleteLFGRoleCheck then
        _G.CompleteLFGRoleCheck(true)
    end
end

function GT:QUEST_ACCEPT_CONFIRM(_, sharerName)
    if Feature({ "social", "noSharedQuests" }) and not IsTrustedPlayer(sharerName) then
        _G.DeclineQuest()
        _G.StaticPopup_Hide("QUEST_ACCEPT")
    end
end

function GT:CONFIRM_SUMMON()
    if not Feature({ "automation", "autoAcceptSummon" }) or UnitAffectingCombat("player") then
        return
    end
    local summoner = C_SummonInfo.GetSummonConfirmSummoner()
    local areaName = C_SummonInfo.GetSummonConfirmAreaName()
    local delay = Value({ "automation", "summonDelay" }, 10) or 10
    C_Timer.After(delay, function()
        if Feature({ "automation", "autoAcceptSummon" }) and not UnitAffectingCombat("player") and C_SummonInfo.GetSummonConfirmSummoner() == summoner and C_SummonInfo.GetSummonConfirmAreaName() == areaName then
            C_SummonInfo.ConfirmSummon()
            _G.StaticPopup_Hide("CONFIRM_SUMMON")
        end
    end)
end

function GT:RESURRECT_REQUEST(_, casterName)
    if not Feature({ "automation", "autoAcceptRes" }) then
        return
    end
    if Value({ "automation", "resNoAfterlife" }, false) and UnitIsDead(casterName) then
        return
    end
    if Value({ "automation", "resNoCombat" }, true) and UnitAffectingCombat(casterName) then
        return
    end
    _G.AcceptResurrect()
    _G["StaticPopup_Hide"]("RESURRECT_NO_TIMER")
end

function GT:GOSSIP_SHOW()
    if not Feature({ "frames", "hideBodyguard" }) or IsShiftKeyDown() then
        return
    end
    EnsureBodyguardNames()
    local targetName = UnitName("target")
    if targetName and bodyguardNames and bodyguardNames[targetName] and UnitCanCooperate("target", "player") then
        C_GossipInfo.CloseGossip()
    end
end

function GT:UNIT_AURA(_, unit)
    if unit ~= "player" or not Feature({ "system", "noTransforms" }) then
        return
    end

    CancelBlockedTransforms()
end

function GT:UNIT_SPELLCAST_CHANNEL_STOP(_, unit, _, spellID)
    if unit ~= "player" or spellID ~= 131476 then
        return
    end

    if Feature({ "system", "noTransforms" }) and Value({ "system", "presetTransforms", "fishing" }, false) then
        CancelBlockedTransforms()
    end
end

function GT:PLAYER_UPDATE_RESTING()
    UpdateRestedEmoteSetting()
end

function GT:ZONE_CHANGED_NEW_AREA()
    UpdateRestedEmoteSetting()
end

function GT:ZONE_CHANGED()
    UpdateRestedEmoteSetting()
end

function GT:ZONE_CHANGED_INDOORS()
    UpdateRestedEmoteSetting()
end

function GT:VOICE_CHAT_OUTPUT_DEVICES_UPDATED()
    if Feature({ "system", "keepAudioSynced" }) and not (_G.CinematicFrame and _G.CinematicFrame:IsShown()) and not (_G.MovieFrame and _G.MovieFrame:IsShown()) then
        _G.SetCVar("Sound_OutputDriverIndex", "0")
        if _G.Sound_GameSystem_RestartSoundSystem then
            _G.Sound_GameSystem_RestartSoundSystem()
        end
    end
end

function GT:CONFIRM_LOOT_ROLL(_, rollID, rollType)
    if Feature({ "system", "noConfirmLoot" }) then
        _G.ConfirmLootRoll(rollID, rollType)
        _G.StaticPopup_Hide("CONFIRM_LOOT_ROLL")
    end
end

function GT:CONFIRM_DISENCHANT_ROLL(_, rollID, rollType)
    if Feature({ "system", "noConfirmLoot" }) then
        _G.ConfirmLootRoll(rollID, rollType)
        _G.StaticPopup_Hide("CONFIRM_DISENCHANT_ROLL")
    end
end

function GT:AbortAutoSellSession()
    self.autoSellToken = (self.autoSellToken or 0) + 1

    if self.autoSellTicker then
        self.autoSellTicker:Cancel()
        self.autoSellTicker = nil
    end

    self.autoSellQueue = nil
    self.autoSellTotalPrice = 0
    self.autoSellSoldCount = 0
    self.autoSellSafeModeTruncated = false
    self.autoSellSettings = nil
    self.autoSellPendingItemData = false
    self.autoSellRetryCount = 0
end

function GT:FinishAutoSellSession()
    local totalPrice = self.autoSellTotalPrice or 0
    local soldCount = self.autoSellSoldCount or 0
    local truncated = self.autoSellSafeModeTruncated == true
    local settings = self.autoSellSettings

    self:AbortAutoSellSession()

    if settings and settings.showSummary then
        if totalPrice > 0 then
            local summary = string.format("|cff69b86f[TwichUI]|r Sold %d junk %s for %s.", soldCount,
                soldCount == 1 and "slot" or "slots", FormatMoney(totalPrice))
            if truncated then
                summary = summary .. " Safe mode capped this visit at 12 slots."
            end
            DEFAULT_CHAT_FRAME:AddMessage(summary)
        elseif soldCount == 0 then
            DEFAULT_CHAT_FRAME:AddMessage("|cff69b86f[TwichUI]|r No junk found to sell.")
        end
    end
end

function GT:ScheduleAutoSellContinuation()
    if self.autoSellTicker then
        self.autoSellTicker:Cancel()
        self.autoSellTicker = nil
    end

    local token = self.autoSellToken
    C_Timer.After(AUTOSELL_ITEMDATA_RETRY_DELAY_SECONDS, function()
        if self.autoSellToken ~= token or not self:IsEnabled() or not IsMerchantVisible() then
            return
        end

        self:ResumeAutoSellSession()
    end)
end

function GT:ContinueOrFinishAutoSellSession()
    if self.autoSellPendingItemData and (self.autoSellRetryCount or 0) < AUTOSELL_ITEMDATA_MAX_RETRIES then
        self:ScheduleAutoSellContinuation()
        return
    end

    self:FinishAutoSellSession()
end

function GT:ProcessAutoSellQueue()
    if not IsMerchantVisible() then
        self:AbortAutoSellSession()
        return
    end

    if not self.autoSellQueue or #self.autoSellQueue == 0 then
        self:ContinueOrFinishAutoSellSession()
        return
    end

    local item = table.remove(self.autoSellQueue, 1)
    if not item then
        self:FinishAutoSellSession()
        return
    end

    local containerInfo = C_Container.GetContainerItemInfo(item.bagID, item.slotID)
    if type(containerInfo) ~= "table" or containerInfo.itemID ~= item.itemID then
        if not self.autoSellQueue or #self.autoSellQueue == 0 then
            self:ContinueOrFinishAutoSellSession()
        end
        return
    end

    if containerInfo.isLocked then
        item.retryCount = (item.retryCount or 0) + 1
        if item.retryCount < 3 then
            self.autoSellQueue[#self.autoSellQueue + 1] = item
        end

        if #self.autoSellQueue == 0 then
            self:ContinueOrFinishAutoSellSession()
        end
        return
    end

    self.autoSellTotalPrice = (self.autoSellTotalPrice or 0) + item.totalPrice
    self.autoSellSoldCount = (self.autoSellSoldCount or 0) + 1
    C_Container.UseContainerItem(item.bagID, item.slotID)

    if #self.autoSellQueue == 0 then
        self:ContinueOrFinishAutoSellSession()
    end
end

function GT:StartAutoSellSession()
    if not IsMerchantVisible() then
        return
    end

    local queue, settings, truncated, pendingItemData = BuildAutoSellQueue()

    self.autoSellQueue = queue
    self.autoSellTotalPrice = 0
    self.autoSellSoldCount = 0
    self.autoSellSafeModeTruncated = truncated
    self.autoSellSettings = settings
    self.autoSellPendingItemData = pendingItemData
    self.autoSellRetryCount = 0

    if #queue == 0 then
        if pendingItemData then
            self:ScheduleAutoSellContinuation()
            return
        end

        self:FinishAutoSellSession()
        return
    end

    self:ProcessAutoSellQueue()
    if self.autoSellQueue and #self.autoSellQueue > 0 then
        self.autoSellTicker = C_Timer.NewTicker(GetAutoSellIntervalSeconds(), function()
            self:ProcessAutoSellQueue()
        end)
    end
end

function GT:ResumeAutoSellSession()
    if not IsMerchantVisible() then
        self:AbortAutoSellSession()
        return
    end

    local queue, _, truncated, pendingItemData = BuildAutoSellQueue()

    self.autoSellQueue = queue
    self.autoSellSafeModeTruncated = self.autoSellSafeModeTruncated == true or truncated == true
    self.autoSellPendingItemData = pendingItemData
    self.autoSellRetryCount = (self.autoSellRetryCount or 0) + 1

    if #queue == 0 then
        self:ContinueOrFinishAutoSellSession()
        return
    end

    self:ProcessAutoSellQueue()
    if self.autoSellQueue and #self.autoSellQueue > 0 then
        self.autoSellTicker = C_Timer.NewTicker(GetAutoSellIntervalSeconds(), function()
            self:ProcessAutoSellQueue()
        end)
    end
end

function GT:BAG_UPDATE_DELAYED()
    if HasActiveAutoSellRule() then
        WarmItemInfoCache()
    end
end

function GT:ScheduleAutoSellSession()
    self:AbortAutoSellSession()

    -- Pre-warm the GetItemInfo cache so vendorPrice is populated when we scan.
    -- BAG_UPDATE_DELAYED handles ongoing warm-up; this covers the vendor open case.
    WarmItemInfoCache()

    local token = self.autoSellToken
    C_Timer.After(AUTOSELL_START_DELAY_SECONDS, function()
        if self.autoSellToken ~= token or not self:IsEnabled() then
            return
        end

        self:StartAutoSellSession()
    end)
end

function GT:MERCHANT_SHOW()
    if IsShiftKeyDown() then
        return
    end

    if HasActiveAutoSellRule() then
        GTLog("MERCHANT_SHOW: scheduling auto-sell session")
        self:ScheduleAutoSellSession()
    else
        GTLog("MERCHANT_SHOW: auto-sell inactive, aborting session")
        self:AbortAutoSellSession()
    end

    if Feature({ "automation", "autoRepairGear" }) and _G.CanMerchantRepair and _G.CanMerchantRepair() then
        local repairCost, canRepair = _G.GetRepairAllCost()
        if canRepair then
            if Value({ "automation", "autoRepairGuildFunds" }, true) and _G.IsInGuild() and _G.CanGuildBankRepair and _G.CanGuildBankRepair() then
                _G.RepairAllItems(true)
            else
                _G.RepairAllItems()
            end
            if repairCost and repairCost > 0 and Value({ "automation", "autoRepairShowSummary" }, true) then
                DEFAULT_CHAT_FRAME:AddMessage("|cff69b86f[TwichUI]|r Repaired for " .. FormatMoney(repairCost) .. ".")
            end
        end
    end
end

function GT:MERCHANT_CLOSED()
    self:AbortAutoSellSession()
end

function GT:UI_ERROR_MESSAGE(_, _, message)
    if message == ERR_VENDOR_DOESNT_BUY or message == ERR_TOO_MUCH_GOLD then
        self:AbortAutoSellSession()
    end
end

function GT:OnEnable()
    InstallHooks()

    if Feature({ "system", "easyItemDestroy" }) and StaticPopupDialogs.DELETE_ITEM and StaticPopupDialogs.DELETE_GOOD_ITEM then
        local deleteLine = gsub(_G.DELETE_GOOD_ITEM, "[\r\n]", "@")
        _, deleteLine = strsplit("@", deleteLine, 2)
        local handlerFrame = CreateFrame("Frame")
        handlerFrame:RegisterEvent("DELETE_ITEM_CONFIRM")
        handlerFrame:SetScript("OnEvent", function()
            if _G.StaticPopup1EditBox and _G.StaticPopup1EditBox:IsShown() then
                _G.StaticPopup1EditBox:Hide()
                _G.StaticPopup1Button1:Enable()
                _G.StaticPopup1Text:SetText(gsub(_G.StaticPopup1Text:GetText(), gsub(deleteLine or "", "@", ""), ""))
            end
        end)
    end

    self:RefreshSettings()
end

function GT:OnDisable()
    self:UnregisterAllEvents()
    self:AbortAutoSellSession()
    RemoveErrorFilter()

    if originalState.ffxGlow ~= nil then _G.SetCVar("ffxGlow", tostring(originalState.ffxGlow)) end
    if originalState.ffxDeath ~= nil then _G.SetCVar("ffxDeath", tostring(originalState.ffxDeath)) end
    if originalState.ffxNether ~= nil then _G.SetCVar("ffxNether", tostring(originalState.ffxNether)) end
    if originalState.ffxVenari ~= nil then _G.SetCVar("ffxVenari", tostring(originalState.ffxVenari)) end
    if originalState.ffxLingeringVenari ~= nil then
        _G.SetCVar("ffxLingeringVenari",
            tostring(originalState.ffxLingeringVenari))
    end
    if originalState.weatherDensity ~= nil then _G.SetCVar("WeatherDensity", tostring(originalState.weatherDensity)) end
    if originalState.raidWeatherDensity ~= nil then
        _G.SetCVar("RAIDweatherDensity",
            tostring(originalState.raidWeatherDensity))
    end
    if originalState.cameraDistanceMaxZoomFactor ~= nil then
        _G.SetCVar("cameraDistanceMaxZoomFactor",
            tostring(originalState.cameraDistanceMaxZoomFactor))
    end
    if originalState.pingSounds ~= nil then _G.SetCVar("Sound_EnablePingSounds", tostring(originalState.pingSounds)) end
    if originalState.soundOutputDriverIndex ~= nil then
        _G.SetCVar("Sound_OutputDriverIndex",
            tostring(originalState.soundOutputDriverIndex))
    end
    if originalState.emoteSounds ~= nil then _G.SetCVar("Sound_EnableEmoteSounds", tostring(originalState.emoteSounds)) end

    SetSoundBucket("game", {}, false)
    SetSoundBucket("toy", {}, false)
    SetSoundBucket("mount", {}, false)
    SetSoundBucket("custom", {}, false)

    if originalState.quickJoinParent and _G["QuickJoinToastButton"] then
        _G["QuickJoinToastButton"]:SetParent(originalState.quickJoinParent)
    end

    if originalState.stanceParent and _G.StanceBar then
        _G.StanceBar:SetParent(originalState.stanceParent)
        _G.StanceBar:Show()
    end

    if originalState.playerRestTexture and _G.PlayerFrame and _G.PlayerFrame.PlayerFrameContent and _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual and _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PlayerRestLoop then
        _G.PlayerFrame.PlayerFrameContent.PlayerFrameContentContextual.PlayerRestLoop.RestTexture:SetTexture(
            originalState.playerRestTexture)
    end

    if _G["BossBanner"] then
        _G["BossBanner"]:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
        _G["BossBanner"]:RegisterEvent("BOSS_KILL")
    end
end
