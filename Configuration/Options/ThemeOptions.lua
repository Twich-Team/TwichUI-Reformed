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
    if datatextModule and type(datatextModule.RefreshStandalonePanels) == "function" then
        datatextModule:RefreshStandalonePanels()
    end
    -- Refresh modules whose appearance depends on statusBarTexture or classIconStyle.
    if key == "statusBarTexture" or key == "classIconStyle" or key == nil then
        local mptOpts = ConfigurationModule.Options.MythicPlusTools
        if mptOpts and type(mptOpts.RefreshModuleAppearance) == "function" then
            pcall(mptOpts.RefreshModuleAppearance, mptOpts)
        end
        local preyOpts = ConfigurationModule.Options.PreyTweaks
        if preyOpts and type(preyOpts.RefreshModule) == "function" then
            pcall(preyOpts.RefreshModule, preyOpts)
        end
    end
    -- Refresh modules whose font settings fall back to globalFont.
    if key == "globalFont" or key == nil then
        local mptOpts = ConfigurationModule.Options.MythicPlusTools
        if mptOpts and type(mptOpts.RefreshModuleAppearance) == "function" then
            pcall(mptOpts.RefreshModuleAppearance, mptOpts)
        end
        local gatheringModule = T:GetModule("QualityOfLife", true)
        gatheringModule = gatheringModule and gatheringModule:GetModule("Gathering", true)
        if gatheringModule and type(gatheringModule.RefreshTrackerFrame) == "function" then
            pcall(gatheringModule.RefreshTrackerFrame, gatheringModule)
        end
    end
end

-- ─── Color get/set ─────────────────────────────────────────────────────────

-- Generate a get/set pair for palette colors without a separate alpha channel.
local COLOR_KEYS = {
    "primaryColor", "accentColor",
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

-- backgroundColor and borderColor include alpha (stored separately as backgroundAlpha / borderAlpha).
function Options:GetBackgroundColor(info)
    local db = GetDB()
    local c = db.backgroundColor or DefaultColor("backgroundColor")
    local a = db.backgroundAlpha or 0.94
    return c[1] or 0.05, c[2] or 0.06, c[3] or 0.08, a
end

function Options:SetBackgroundColor(info, r, g, b, a)
    GetDB().backgroundColor = { r, g, b }
    GetDB().backgroundAlpha = a ~= nil and a or 0.94
    BroadcastChange("backgroundColor")
    BroadcastChange("backgroundAlpha")
end

function Options:GetBorderColor(info)
    local db = GetDB()
    local c = db.borderColor or DefaultColor("borderColor")
    local a = db.borderAlpha or 0.85
    return c[1] or 0.24, c[2] or 0.26, c[3] or 0.32, a
end

function Options:SetBorderColor(info, r, g, b, a)
    GetDB().borderColor = { r, g, b }
    GetDB().borderAlpha = a ~= nil and a or 0.85
    BroadcastChange("borderColor")
    BroadcastChange("borderAlpha")
end

-- ─── Surface alphas (kept for API compat; color pickers above are the primary UI) ──

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
    return GetDB().soundProfile or "Standard"
end

function Options:SetSoundProfile(info, value)
    GetDB().soundProfile = value
end

-- ─── Frame appearance ──────────────────────────────────────────────────────

function Options:GetStatusBarTexture(info)
    return GetDB().statusBarTexture or "TwichUI-Smooth"
end

function Options:SetStatusBarTexture(info, value)
    GetDB().statusBarTexture = value
    BroadcastChange("statusBarTexture")
end

function Options:GetClassIconStyle(info)
    return GetDB().classIconStyle or "default"
end

function Options:SetClassIconStyle(info, value)
    GetDB().classIconStyle = value
    BroadcastChange("classIconStyle")
end

-- ─── Global font ───────────────────────────────────────────────────────────

function Options:GetGlobalFont(info)
    return GetDB().globalFont or "__default"
end

function Options:SetGlobalFont(info, value)
    GetDB().globalFont = value
    BroadcastChange("globalFont")
end

-- ─── Sound volume ──────────────────────────────────────────────────────────

function Options:GetSoundVolume(info)
    local v = GetDB().soundVolume
    if v == nil then return 100 end
    return v
end

function Options:SetSoundVolume(info, value)
    GetDB().soundVolume = value
    BroadcastChange("soundVolume")
end

-- ─── Revert overrides ──────────────────────────────────────────────────────

--- Resets all per-frame style overrides so every frame falls back to global
--- Appearance defaults. Also re-broadcasts TWICH_THEME_CHANGED so every
--- subscribed module re-applies its visuals.
function Options:ResetAllFrameOverrides()
    local datatextOpts = ConfigurationModule.Options.Datatext
    if datatextOpts then
        if type(datatextOpts.ResetSharedStyle) == "function" then
            datatextOpts:ResetSharedStyle()
        end
        if type(datatextOpts.ResetAllPanelStyleOverrides) == "function" then
            datatextOpts:ResetAllPanelStyleOverrides()
        end
    end
    -- Clear explicit chat color overrides so chat falls back to global theme.
    local chatOpts = ConfigurationModule.Options.ChatEnhancement
    if chatOpts then
        local db                     = chatOpts:GetChatEnhancementDB()
        db.shellAccentColor          = nil; db._shellAccentExplicitlySet = nil
        db.tabAccentColor            = nil; db._tabAccentExplicitlySet = nil
        db.tabBorderColor            = nil; db._tabBorderExplicitlySet = nil
        db.tabBgColor                = nil; db._tabBgExplicitlySet = nil
        db.chatBgColor               = nil; db._chatBgExplicitlySet = nil
        db.chatBorderColor           = nil; db._chatBorderExplicitlySet = nil
        db.chatFont                  = nil; db._chatFontExplicitlySet = nil
        if type(chatOpts.RefreshChatStylingModule) == "function" then
            chatOpts:RefreshChatStylingModule()
        end
    end
    -- Re-broadcast to all other frame modules (Chat, RaidFrames, etc.)
    BroadcastChange(nil)
    -- Clear MythicPlusTools bar texture and font overrides so they fall back
    -- to the global statusBarTexture and globalFont settings.
    local mptOpts = ConfigurationModule.Options.MythicPlusTools
    if mptOpts then
        local mptDB = mptOpts:GetDB()
        mptDB.trackerFont                    = nil; mptDB._trackerFontExplicitlySet         = nil
        mptDB.statusTextFont                 = nil; mptDB._statusTextFontExplicitlySet      = nil
        mptDB.readyTextFont                  = nil; mptDB._readyTextFontExplicitlySet        = nil
        mptDB.trackerBarTexture              = nil; mptDB._trackerBarTextureExplicitlySet    = nil
        if type(mptOpts.ResetMythicPlusTimerAppearance) == "function" then
            mptOpts:ResetMythicPlusTimerAppearance()
        else
            mptOpts:RefreshModuleAppearance()
        end
        -- ResetMythicPlusTimerAppearance already calls RefreshModuleAppearance.
        -- Also refresh for the tracker-level resets above.
        if type(mptOpts.RefreshModuleAppearance) == "function" then
            pcall(mptOpts.RefreshModuleAppearance, mptOpts)
        end
    end
    -- Clear Gathering tracker font override so it falls back to globalFont.
    local gatheringOpts = ConfigurationModule.Options.Gathering
    if gatheringOpts then
        gatheringOpts:GetDB().trackerFont = nil
        local gatheringModule = T:GetModule("QualityOfLife", true)
        gatheringModule = gatheringModule and gatheringModule:GetModule("Gathering", true)
        if gatheringModule and type(gatheringModule.RefreshTrackerFrame) == "function" then
            pcall(gatheringModule.RefreshTrackerFrame, gatheringModule)
        end
    end
end

-- ─── Section builder ───────────────────────────────────────────────────────

function Options:BuildConfiguration()
    local W = ConfigurationModule.Widgets
    local tab = W.NewConfigurationSection(25, "Theme")
    tab.args = {
        title           = W.TitleWidget(0, "Appearance"),
        description     = W.Description(1,
            "Define a shared visual identity across TwichUI. The palette drives accent colors, " ..
            "surfaces, and borders for Data Panels, Chat, Unit Frames, and more."),

        palette         = W.IGroup(10, "Color Palette", {
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
                desc = "Base surface color for panels and frames. The alpha slider controls panel opacity.",
                order = 3,
                hasAlpha = true,
                handler = Options,
                get = "GetBackgroundColor",
                set = "SetBackgroundColor",
            },
            borderColor = {
                type = "color",
                name = "Border",
                desc = "Default border color for panels and frames. The alpha slider controls border opacity.",
                order = 4,
                hasAlpha = true,
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

        frameAppearance = W.IGroup(30, "Frame Appearance", {
            statusBarTexture = {
                type = "select",
                name = "Status Bar Texture",
                desc =
                "Default bar texture used by all status bars and timer bars across TwichUI frames. Individual frames can override this in their own settings.",
                order = 1,
                dialogControl = "LSM30_Statusbar",
                values = function()
                    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                    return LSM and LSM:HashTable("statusbar") or {}
                end,
                handler = Options,
                get = "GetStatusBarTexture",
                set = "SetStatusBarTexture",
            },
            classIconStyle = {
                type = "select",
                name = "Class Icon Style",
                desc =
                "Default style for class icons in chat, notifications, and tracking frames. Individual modules can override this in their own settings.",
                order = 2,
                values = function()
                    local Textures = T.Tools and T.Tools.Textures
                    local function IconLabel(style, label)
                        if Textures and Textures.GetPlayerClassTextureString then
                            local icon = Textures:GetPlayerClassTextureString(14, style)
                            if icon then return ("%s %s"):format(icon, label) end
                        end
                        return label
                    end
                    return {
                        default = IconLabel("default", "Default"),
                        fabled  = IconLabel("fabled", "Fabled"),
                        pixel   = IconLabel("pixel", "Pixel"),
                    }
                end,
                sorting = { "default", "fabled", "pixel" },
                handler = Options,
                get = "GetClassIconStyle",
                set = "SetClassIconStyle",
            },
            globalFont = {
                type = "select",
                name = "Global Font",
                desc =
                "Default font used across TwichUI data panels and frames. Individual frames can override this in their own settings. Choose \"Default\" to use the WoW system font.",
                order = 3,
                dialogControl = "LSM30_Font",
                values = function()
                    local LSM = LibStub and LibStub("LibSharedMedia-3.0", true)
                    local fonts = LSM and LSM:HashTable("font") or {}
                    fonts["__default"] = "Default (WoW System Font)"
                    return fonts
                end,
                handler = Options,
                get = "GetGlobalFont",
                set = "SetGlobalFont",
            },
        }),

        sounds          = W.IGroup(40, "Config Sounds", {
            soundVolume = {
                type = "range",
                name = "TwichUI Sound Volume",
                desc =
                "Controls TwichUI sound effects. Set to 0 to mute all TwichUI sounds.\n\nNote: WoW does not support per-addon volume gain — any value above 0 plays at native volume.",
                order = 0,
                min = 0,
                max = 100,
                step = 1,
                handler = Options,
                get = "GetSoundVolume",
                set = "SetSoundVolume",
            },
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

        resetGroup      = W.IGroup(50, "Reset", {
            resetPalette = {
                type = "execute",
                name = "Reset to Defaults",
                desc = "Restore the entire theme palette, appearance, and sound settings to TwichUI defaults.",
                order = 1,
                func = function()
                    local theme = GetThemeModule()
                    if not theme then return end
                    theme:ResetToDefaults()
                    -- Refresh data panels
                    local datatextModule = T:GetModule("Datatexts", true)
                    if datatextModule and type(datatextModule.RefreshStandalonePanels) == "function" then
                        datatextModule:RefreshStandalonePanels()
                    end
                    -- Refresh the config page to reflect new defaults
                    local configUI = ConfigurationModule.StandaloneUI
                    if configUI and configUI.RequestRenderCurrentPage then
                        configUI:RequestRenderCurrentPage()
                    end
                end,
            },
            revertOverrides = {
                type = "execute",
                name = "Revert Frame Overrides",
                desc =
                "Clears all individual frame style overrides so every frame falls back to the global Appearance defaults above.",
                order = 2,
                func = function()
                    Options:ResetAllFrameOverrides()
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
