--[[
    Module that contains data that must be manually entered and updated.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class DataModule : AceModule
---@field Mounts MountData mount data
local DataModule = T:NewModule("Data")
