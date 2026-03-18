--[[
    Provides standard color palette for the addon.
]]
---@type TwichUI
local TwichRx = _G.TwichRx
local T, W, I, C = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@class ColorTools
local Colors = Tools.Colors or {}
Tools.Colors = Colors

Colors.PRIMARY = "#19c9c7"
Colors.SECONDARY = "#7840df"
Colors.WHITE = "#FFFFFF"
Colors.BLACK = "#000000"
Colors.WARNING = "#d9a646"
Colors.GRAY = "#a6a6a6"
Colors.RED = "#b23a48"
Colors.GREEN = "#69FF3C"

---@class WarcraftColors
local WC = Colors.WarcraftColors or {}
Colors.WarcraftColors = WC

WC.Currency = {
    GOLD = "#FFD700",
    SILVER = "#C0C0C0",
    COPPER = "#B87333"
}
