--[[
    Provides various text-based utilities used throughout the addon
]]
---@type TwichUI_Redux
local TwichRx = _G.TwichRx
local T, W, I, C = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@class TextTools
local Text = Tools.Text or {}
Tools.Text = Text

local TEXT_COLOR_TEMPLATE = "|cff%s%s|r"
local ICON_TEMPLATE = "|T%s:16:16:0:0:64:64:4:60:4:60|t"


--- Normalizes a Hex color by striping the leading '#'
--- @param hex string a hex color value
local function NormalizeHexValue(hex)
    if not hex then return "FFFFFF" end
    if hex:sub(1, 1) == "#" then
        return hex:sub(2)
    end
    return hex
end

--- Takes an icon to produce a string with the icon it it.
--- @param path string the path to the icon
--- @return string formattedString the formatted string with the icon
function Text.Icon(path)
    return ICON_TEMPLATE:format(path)
end

--- Colors the provided text with the provided hex color. Default hex colors are provided via ToolsModule.Colors.*.
--- @param hex string a hex color value
--- @param text string the text to color.
--- @return string formattedString the formatted string. If the function was provided nil, an empty string will be returned.
function Text.Color(hex, text)
    if not text then return "" end
    if not hex then return text end

    hex = NormalizeHexValue(hex)
    return TEXT_COLOR_TEMPLATE:format(hex, text)
end

function Text.ColorRGB(r, g, b, text)
    return ("|cff%02x%02x%02x%s|r"):format(r * 255, g * 255, b * 255, text)
end

--- Converts a string to Title Case (first letter of each word uppercase, rest lowercase).
--- Words are split on whitespace; non-letter characters are preserved.
---@param s string|nil
---@return string
function Text.ToTitleCase(s)
    if type(s) ~= "string" or s == "" then
        return ""
    end

    local words = {}
    for word in s:gmatch("%S+") do
        local first = word:sub(1, 1)
        local rest = word:sub(2)
        words[#words + 1] = first:upper() .. rest:lower()
    end

    return table.concat(words, " ")
end

function Text.DumpTable(t, indent)
    indent = indent or ""
    if type(t) ~= "table" then
        T:Print(indent .. tostring(t))
        return
    end

    for k, v in pairs(t) do
        local key = "[" .. tostring(k) .. "]"
        if type(v) == "table" then
            T:Print(indent .. key .. " = {")
            Text.DumpTable(v, indent .. "  ")
            T:Print(indent .. "}")
        else
            T:Print(indent .. key .. " = " .. tostring(v))
        end
    end
end

function Text.GetElvUIFont()
    local E = unpack(ElvUI)
    if E and E.media and E.media.normFont then return E.media.normFont end
    return nil
end

--- Inserts thousands separators into an integer string (e.g. "88900" -> "88,900").
-- @param n number
-- @return string
local function FormatWithCommas(n)
    if not n then
        return "0"
    end

    local s = tostring(n)
    -- simple non‑locale grouping: 1234567 -> 1,234,567
    local k
    while true do
        s, k = s:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
        if k == 0 then break end
    end
    return s
end

function Text.FormatCopper(copper)
    if not copper or copper <= 0 then
        copper = 0
    end

    local gold         = math.floor(copper / (100 * 100))
    local silver       = math.floor((copper / 100) % 100)
    local cop          = math.floor(copper % 100)

    local COLOR_GOLD   = "|cff" .. NormalizeHexValue(Tools.Colors.WarcraftColors.Currency.GOLD)
    local COLOR_SILVER = "|cff" .. NormalizeHexValue(Tools.Colors.WarcraftColors.Currency.SILVER)
    local COLOR_COPPER = "|cff" .. NormalizeHexValue(Tools.Colors.WarcraftColors.Currency.COPPER)
    local COLOR_RESET  = "|r"

    local goldStr      = FormatWithCommas(gold)

    return string.format(
        "%s" .. COLOR_GOLD .. "g" .. COLOR_RESET ..
        " %d" .. COLOR_SILVER .. "s" .. COLOR_RESET ..
        " %d" .. COLOR_COPPER .. "c" .. COLOR_RESET,
        goldStr, silver, cop
    )
end

function Text.FormatCopperShort(copper)
    if not copper or copper <= 0 then
        copper = 0
    end

    local gold        = math.floor(copper / (100 * 100))

    local COLOR_GOLD  = "|cff" .. NormalizeHexValue(Tools.Colors.WarcraftColors.Currency.GOLD)
    local COLOR_RESET = "|r"

    local goldStr     = FormatWithCommas(gold)
    return goldStr .. COLOR_GOLD .. "g" .. COLOR_RESET
end
