--[[
    Configuration options for the AutoLoot module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class AutoLootConfigurationOptions
local Options = ConfigurationModule.Options.AutoLoot or {}
ConfigurationModule.Options.AutoLoot = Options

local SOUND_INV_FULL_DEFAULT = 44321

local function GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if not profile.autoLoot then
        profile.autoLoot = {}
    end
    return profile.autoLoot
end

local function GetModule()
    return T:GetModule("QualityOfLife"):GetModule("AutoLoot")
end

-- ---------------------------------------------------------------------------
-- Enabled
-- ---------------------------------------------------------------------------

function Options:GetEnabled()
    return GetDB().enabled == true
end

function Options:SetEnabled(info, value)
    GetDB().enabled = value == true
    local m = GetModule()
    if value then
        m:Enable()
    else
        m:Disable()
    end
end

-- ---------------------------------------------------------------------------
-- Fishing reel-in sound
-- ---------------------------------------------------------------------------

function Options:GetFishingSoundEnabled()
    local db = GetDB()
    return db.fishingSound ~= false -- default on
end

function Options:SetFishingSoundEnabled(info, value)
    GetDB().fishingSound = value ~= false
end

-- ---------------------------------------------------------------------------
-- Inventory-full sound
-- ---------------------------------------------------------------------------

function Options:GetInventorySoundEnabled()
    return GetDB().inventorySound == true
end

function Options:SetInventorySoundEnabled(info, value)
    GetDB().inventorySound = value == true
end

function Options:GetInventorySoundID()
    local db = GetDB()
    return (type(db.inventorySoundID) == "number" and db.inventorySoundID > 0)
        and db.inventorySoundID or SOUND_INV_FULL_DEFAULT
end

function Options:SetInventorySoundID(info, value)
    local id = tonumber(value)
    if id and id > 0 then
        GetDB().inventorySoundID = id
        _G.PlaySound(id, "Master")
    end
end
