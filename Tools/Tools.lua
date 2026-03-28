--[[
    Provides various utilities used throughout the addon
]]

local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)

---@class Tools
---@field Text TextTools
---@field Colors ColorTools
---@field Textures TexturesTool
---@field UI UISkins
---@field Quest QuestTools
---@field Game GameTool
---@field ErrorLog TwichUIErrorLog
local Tools = T.Tools or {}
T.Tools = Tools

---@class ToolFunctions
---@field Retry RetryModule
local functions = Tools.Functions or {}
Tools.Functions = functions
