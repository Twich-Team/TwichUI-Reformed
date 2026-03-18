--[[
    Data for utility mounts -- mounts that provide vendors, mailbox, auction house functionality

    This type of mount cannot be automatically detected, so IDs must be manually matched.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type DataModule
local DataModule = T:GetModule("Data")

---@class MountData
---@field Utility table<number, {capabilities: string[]}> List of Spell IDs for utility mounts
---@field Swimming number[] List of Spell IDs for swimming mounts
---@field Capabilities table<string, string> Capabilities that utility mounts can provide
local Mounts = {}
DataModule.Mounts = Mounts

local Capabilities = {
    VENDOR = "VENDOR",
    MAILBOX = "MAILBOX",
    AUCTION = "AUCTION",
    TRANSMOG = "TRANSMOG"
}
Mounts.Capabilities = Capabilities

-- These are Spell IDs
Mounts.Utility = {
    [122708] = { capabilities = { Capabilities.VENDOR, Capabilities.TRANSMOG } }, -- Grand Expedition Yak
    [457485] = { capabilities = { Capabilities.VENDOR, Capabilities.TRANSMOG } }, -- Grizzly Hills Packmaster
    [264058] = { capabilities = { Capabilities.AUCTION, Capabilities.MAILBOX } }, -- Mighty Caravan Brutosaur
    [465235] = { capabilities = { Capabilities.AUCTION, Capabilities.MAILBOX } }, -- Trader's Gilded Brutosaur
    [61447] = { capabilities = { Capabilities.VENDOR } },                        -- Traveler's Tundra Mammoth
}

-- https://www.wowhead.com/spells/mounts/aquatic-mounts
Mounts.Swimming = {
    223018, 300150, 64731, 98718, 359409, 376873, 376879, 30174, 75207, 1266248, 278803, 214791, 427222, 300154, 278979, 433281, 253711, 288711, 376875, 367826, 300153, 376913, 453255, 228919, 376910, 376898, 376880, 300151, 473861
}
