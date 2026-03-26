---@diagnostic disable: undefined-field, inject-field
--[[
    Options handlers for the cross-module Theme system.
    Defines getters/setters for every theme property used by Configuration/Theme.lua.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

ConfigurationModule.Options.Theme = ConfigurationModule.Options.Theme or {}

---@class ThemeConfigurationOptions
local Options = ConfigurationModule.Options.Theme

-- ─── Helpers ───────────────────────────────────────────────────────────────

local function GetThemeModule()
    return T:GetModule("Theme", true)
end

local function GetDB()
    local theme = GetThemeModule()
    if not theme then return {} end
    return theme:GetDB()
end

local function DefaultColor(key)
    local theme = GetThemeModule()
    if not theme then return { 1, 1, 1 } end
    return theme.DEFAULT_THEME[key] or { 1, 1, 1 }
end

--- Broadcasts a theme change and triggers cascade refreshes in live modules.
local function BroadcastChange(key)
    local theme = GetThemeModule()
    if not theme then return end
    -- Notify all theme subscribers (Chat, RaidFrames, etc.)
    theme:SendMessage("TWICH_THEME_CHANGED", key)
    -- Refresh Standalone data panels so they pick up the new theme defaults
    local datatextModule = T:GetModule("Datatexts", true)
    if datatextModule and type(datatextModule.RefreshAllStandalonePanels) == "function" then
        datatextModule:RefreshAllStandalonePanels()
    end
end

-- ─── Color get/set ─────────────────────────────────────────────────────────

-- Generate a get/set pair for each named palette color.
local COLOR_KEYS = {
    "primaryColor", "accentColor", "backgroundColor", "borderColor",
    "textColor", "successColor", "warningColor", "dangerColor",
}

for _, colorKey in ipairs(COLOR_KEYS) do
    local capKey = colorKey:sub(1, 1):upper() .. colorKey:sub(2)
    Options["Get" .. capKey] = function(self, info)
        local db = GetDB()
        local color = db[colorKey]
        if type(color) ~= "table" then
            color = DefaultColor(colorKey)
        end
        return color[1] or 1, color[2] or 1, color[3] or 1, 1
    end
    Options["Set" .. capKey] = function(self, info, r, g, b, a)
        GetDB()[colorKey] = { r, g, b }
        BroadcastChange(colorKey)
    end
end

-- ─── Surface alphas ────────────────────────────────────────────────────────

function Options:GetBackgroundAlpha(info)
    return GetDB().backgroundAlpha or 0.94
end

function Options:SetBackgroundAlpha(info, value)
    GetDB().backgroundAlpha = value
    BroadcastChange("backgroundAlpha")
end

function Options:GetBorderAlpha(info)
    return GetDB().borderAlpha or 0.85
end

function Options:SetBorderAlpha(info, value)
    GetDB().borderAlpha = value
    BroadcastChange("borderAlpha")
end

-- ─── Config sounds ─────────────────────────────────────────────────────────

function Options:GetUISoundsEnabled(info)
    return GetDB().uiSoundsEnabled ~= false
end

function Options:SetUISoundsEnabled(info, value)
    GetDB().uiSoundsEnabled = value == true
end

function Options:GetSoundProfile(info)
    return GetDB().soundProfile or "Subtle"
end

function Options:SetSoundProfile(info, value)
    GetDB().soundProfile = value
end

-- ─── Section builder ───────────────────────────────────────────────────────

function Options:BuildConfiguration()
    local W = ConfigurationModule.Widgets
    local tab = W.NewConfigurationSection(25, "Theme")
    tab.args = {
        title       = W.TitleWidget(0, "Appearance"),
        description = W.Description(1,
            "Define a shared visual identity across TwichUI. The palette drives accent colors, " ..
            "surfaces, and borders for Data Panels, Chat, Unit Frames, and more."),

        palette     = W.IGroup(10, "Color Palette", {
            primaryColor = {
                type = "color",
                name = "Primary Color",
                desc = "Core brand color — used by chat chrome and primary borders.",
                order = 1,
                hasAlpha = false,
                handler = Options,
                get = "GetPrimaryColor",
                set = "SetPrimaryColor",
            },
            accentColor = {
                type = "color",
                name = "Accent Color",
                desc = "Highlight color — used by panel accents, active indicators, and hover effects.",
                order = 2,
                hasAlpha = false,
                handler = Options,
                get = "GetAccentColor",
                set = "SetAccentColor",
            },
            backgroundColor = {
                type = "color",
                name = "Background",
                desc = "Base surface color for panels and frames.",
                order = 3,
                hasAlpha = false,
                handler = Options,
                get = "GetBackgroundColor",
                set = "SetBackgroundColor",
            },
            borderColor = {
                type = "color",
                name = "Border",
                desc = "Default border color for panels and frames.",
                order = 4,
                hasAlpha = false,
                handler = Options,
                get = "GetBorderColor",
                set = "SetBorderColor",
            },
            textColor = {
                type = "color",
                name = "Text",
                desc = "Primary label text color.",
                order = 5,
                hasAlpha = false,
                handler = Options,
                get = "GetTextColor",
                set = "SetTextColor",
            },
            successColor = {
                type = "color",
                name = "Success",
                desc = "Used by enabled toggles and positive state indicators.",
                order = 6,
                hasAlpha = false,
                handler = Options,
                get = "GetSuccessColor",
                set = "SetSuccessColor",
            },
            warningColor = {
                type = "color",
                name = "Warning",
                desc = "Used for cautionary callouts and amber highlights.",
                order = 7,
                hasAlpha = false,
                handler = Options,
                get = "GetWarningColor",
                set = "SetWarningColor",
            },
            dangerColor = {
                type = "color",
                name = "Danger",
                desc = "Used by destructive actions and critical state indicators.",
                order = 8,
                hasAlpha = false,
                handler = Options,
                get = "GetDangerColor",
                set = "SetDangerColor",
            },
        }),

        surfaces    = W.IGroup(20, "Surfaces", {
            backgroundAlpha = {
                type = "range",
                name = "Background Opacity",
                desc = "How opaque panel backgrounds appear (0 = fully transparent, 1 = fully solid).",
                order = 1,
                min = 0,
                max = 1,
                step = 0.01,
                handler = Options,
                get = "GetBackgroundAlpha",
                set = "SetBackgroundAlpha",
            },
            borderAlpha = {
                type = "range",
                name = "Border Opacity",
                desc = "How visible panel borders are.",
                order = 2,
                min = 0,
                max = 1,
                step = 0.01,
                handler = Options,
                get = "GetBorderAlpha",
                set = "SetBorderAlpha",
            },
        }),

        sounds      = W.IGroup(30, "Config Sounds", {
            uiSoundsEnabled = {
                type = "toggle",
                name = "Enable Menu Sounds",
                desc = "Play subtle sounds when interacting with config elements.",
                order = 1,
                handler = Options,
                get = "GetUISoundsEnabled",
                set = "SetUISoundsEnabled",
            },
            soundProfile = {
                type = "select",
                name = "Sound Profile",
                desc = "Choose the style of sounds used during config interactions.",
                order = 2,
                disabled = function()
                    return not Options:GetUISoundsEnabled()
                end,
                values = {
                    None     = "None",
                    Subtle   = "Subtle  (built-in WoW UI sounds)",
                    Standard = "Standard  (TwichUI sounds)",
                },
                sorting = { "None", "Subtle", "Standard" },
                handler = Options,
                get = "GetSoundProfile",
                set = "SetSoundProfile",
            },
        }),

        resetGroup  = W.IGroup(40, "Reset", {
            resetPalette = {
                type = "execute",
                name = "Reset to Defaults",
                desc = "Restore the entire theme palette and sound settings to TwichUI defaults.",
                order = 1,
                func = function()
                    local theme = GetThemeModule()
                    if not theme then return end
                    theme:ResetToDefaults()
                    -- Refresh data panels
                    local datatextModule = T:GetModule("Datatexts", true)
                    if datatextModule and type(datatextModule.RefreshAllStandalonePanels) == "function" then
                        datatextModule:RefreshAllStandalonePanels()
                    end
                    -- Refresh the config page to reflect new defaults
                    local configUI = ConfigurationModule.StandaloneUI
                    if configUI and configUI.RequestRenderCurrentPage then
                        configUI:RequestRenderCurrentPage()
                    end
                end,
            },
        }),
    }

    return tab
end
