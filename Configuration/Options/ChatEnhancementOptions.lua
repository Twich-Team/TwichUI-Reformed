---@diagnostic disable: undefined-field
--[[
    Options for the ChatEnhancement module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class ChatEnhancementConfigurationOptions
local Options = ConfigurationModule.Options.ChatEnhancement or {}
ConfigurationModule.Options.ChatEnhancement = Options

local DEFAULT_SOUND = "TwichUI Chat Ping"
local DEFAULT_CHAT_FONT = "Inter"
local DEFAULT_TAB_FONT = "Exo2 SemiBold"
local DEFAULT_CHAT_FONT_SIZE = 13
local DEFAULT_TAB_FONT_SIZE = 12
local DEFAULT_ROW_GAP = 8
local DEFAULT_SHELL_ACCENT = { r = 0.10, g = 0.72, b = 0.74 }
local DEFAULT_TIMESTAMP_WIDTH = 58
local DEFAULT_BN_WHISPER_INFO = _G.ChatTypeInfo and _G.ChatTypeInfo.BN_WHISPER or nil
local DEFAULT_CHANNEL_COLORS = {
    addon = { r = 0.84, g = 0.48, b = 0.97 },
    battleNetWhisper = {
        r = DEFAULT_BN_WHISPER_INFO and DEFAULT_BN_WHISPER_INFO.r or 0.00,
        g = DEFAULT_BN_WHISPER_INFO and DEFAULT_BN_WHISPER_INFO.g or 0.75,
        b = DEFAULT_BN_WHISPER_INFO and DEFAULT_BN_WHISPER_INFO.b or 0.96,
    },
    general = { r = 0.91, g = 0.83, b = 0.46 },
    guild = { r = 0.24, g = 0.85, b = 0.53 },
    instance = { r = 0.96, g = 0.55, b = 0.29 },
    instanceLeader = { r = 0.99, g = 0.61, b = 0.31 },
    localDefense = { r = 0.91, g = 0.42, b = 0.42 },
    lookingForGroup = { r = 0.46, g = 0.74, b = 0.98 },
    newcomer = { r = 0.60, g = 0.82, b = 1.00 },
    officer = { r = 0.20, g = 0.75, b = 0.44 },
    party = { r = 0.64, g = 0.72, b = 1.00 },
    partyLeader = { r = 0.73, g = 0.82, b = 1.00 },
    raid = { r = 1.00, g = 0.48, b = 0.38 },
    raidLeader = { r = 1.00, g = 0.58, b = 0.45 },
    services = { r = 0.93, g = 0.72, b = 0.32 },
    say = { r = 1.00, g = 1.00, b = 1.00 },
    system = { r = 0.74, g = 0.74, b = 0.74 },
    trade = { r = 0.95, g = 0.68, b = 0.24 },
    whisper = { r = 0.93, g = 0.52, b = 0.89 },
    yell = { r = 1.00, g = 0.52, b = 0.52 },
    emote = { r = 1.00, g = 0.74, b = 0.60 },
}

local function CopyColor(color)
    return {
        r = color and color.r or 1,
        g = color and color.g or 1,
        b = color and color.b or 1,
    }
end

Options.DefaultAbbreviations = Options.DefaultAbbreviations or {
    guild = "G",
    officer = "O",
    party = "P",
    partyLeader = "PL",
    instance = "I",
    instanceLeader = "IL",
    raid = "R",
    raidLeader = "RL",
    general = "GEN",
    trade = "TRD",
    localDefense = "DEF",
    lookingForGroup = "LFG",
    services = "SVC",
    newcomer = "NEW",
}

local function Trim(value)
    return (tostring(value or ""):gsub("^%s*(.-)%s*$", "%1"))
end

local function GetChatStylingModule()
    local chatModule = T:GetModule("ChatEnhancements", true)
    ---@type ChatStylingModule|nil
    return chatModule and chatModule:GetModule("ChatStyling", true) or nil
end

local function GetChatRendererModule()
    local chatModule = T:GetModule("ChatEnhancements", true)
    ---@type ChatRendererModule|nil
    return chatModule and chatModule:GetModule("ChatRenderer", true) or nil
end

local function GetChatAlertsModule()
    local chatModule = T:GetModule("ChatEnhancements", true)
    ---@type ChatAlertsModule|nil
    return chatModule and chatModule:GetModule("ChatAlerts", true) or nil
end

local function GetDebugConsole()
    return T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil
end

function Options:RefreshChatStylingModule()
    local chatStylingModule = GetChatStylingModule()
    local chatRendererModule = GetChatRendererModule()

    if chatStylingModule then
        chatStylingModule:RefreshSettings()
    end
    if chatRendererModule then
        chatRendererModule:RefreshSettings()
    end

    if self:IsStylingEnabled() then
        if chatStylingModule and not chatStylingModule:IsEnabled() then
            chatStylingModule:Enable()
        elseif chatStylingModule then
            chatStylingModule:RefreshAllVisuals()
        end

        if chatRendererModule and not chatRendererModule:IsEnabled() then
            chatRendererModule:Enable()
        elseif chatRendererModule then
            chatRendererModule:RefreshAllFrames()
        end
    else
        if chatStylingModule and chatStylingModule:IsEnabled() then
            chatStylingModule:Disable()
        end
        if chatRendererModule and chatRendererModule:IsEnabled() then
            chatRendererModule:Disable()
        end
    end
end

function Options:RefreshChatAlertsModule()
    local chatAlertsModule = GetChatAlertsModule()
    if not chatAlertsModule then
        return
    end

    if self:IsAlertsEnabled() then
        if not chatAlertsModule:IsEnabled() then
            chatAlertsModule:Enable()
        else
            chatAlertsModule:RefreshKeywords()
            chatAlertsModule:RefreshEvents()
        end
    elseif chatAlertsModule:IsEnabled() then
        chatAlertsModule:Disable()
    end
end

---@return table chatEnhancementDB the profile-level chat enhancement configuration database.
function Options:GetChatEnhancementDB()
    if not ConfigurationModule:GetProfileDB().chatEnhancement then
        ConfigurationModule:GetProfileDB().chatEnhancement = {}
    end
    local db = ConfigurationModule:GetProfileDB().chatEnhancement
    -- Migration v4: adds chatFont to the purge list alongside v3 keys.
    if db._chatSchemaV ~= 4 then
        if not db._shellAccentExplicitlySet then db.shellAccentColor = nil end
        if not db._tabAccentExplicitlySet then db.tabAccentColor = nil end
        if not db._tabBorderExplicitlySet then db.tabBorderColor = nil end
        if not db._tabBgExplicitlySet then db.tabBgColor = nil end
        if not db._chatBgExplicitlySet then db.chatBgColor = nil end
        if not db._chatBorderExplicitlySet then db.chatBorderColor = nil end
        if not db._chatFontExplicitlySet then db.chatFont = nil end
        db._chatSchemaV = 4
    end
    return db
end

function Options:IsAlertsEnabled()
    return self:GetChatEnhancementDB().alertsEnabled or false
end

function Options:SetAlertsEnabled(info, value)
    self:GetChatEnhancementDB().alertsEnabled = value
    self:RefreshChatAlertsModule()
end

function Options:IsStylingEnabled()
    local db = self:GetChatEnhancementDB()
    if db.stylingEnabled == nil then
        return true
    end

    return db.stylingEnabled
end

function Options:SetStylingEnabled(info, value)
    self:GetChatEnhancementDB().stylingEnabled = value
    self:RefreshChatStylingModule()
end

function Options:GetDebugEnabled()
    return self:GetChatEnhancementDB().debugEnabled == true
end

function Options:SetDebugEnabled(info, value)
    self:GetChatEnhancementDB().debugEnabled = value == true

    if value ~= true then
        local debugConsole = GetDebugConsole()
        if debugConsole and debugConsole.ClearLogs then
            debugConsole:ClearLogs("chat")
        end
    end
end

function Options:OpenDebugConsole()
    local debugConsole = GetDebugConsole()
    if debugConsole and debugConsole.Show then
        debugConsole:Show("chat")
    end
end

function Options:AreTimestampsEnabled()
    local db = self:GetChatEnhancementDB()
    if db.timestampsEnabled == nil then
        return true
    end

    return db.timestampsEnabled
end

function Options:SetTimestampsEnabled(info, value)
    self:GetChatEnhancementDB().timestampsEnabled = value
    self:RefreshChatStylingModule()
end

function Options:GetTimestampFormat()
    return self:GetChatEnhancementDB().timestampFormat or "%H:%M"
end

function Options:SetTimestampFormat(info, value)
    self:GetChatEnhancementDB().timestampFormat = value
    self:RefreshChatStylingModule()
end

function Options:GetTimestampWidth()
    return self:GetChatEnhancementDB().timestampWidth or DEFAULT_TIMESTAMP_WIDTH
end

function Options:SetTimestampWidth(info, value)
    self:GetChatEnhancementDB().timestampWidth = value
    self:RefreshChatStylingModule()
end

function Options:ShouldShowAccentBar()
    local db = self:GetChatEnhancementDB()
    if db.showAccentBar == nil then
        return true
    end

    return db.showAccentBar
end

function Options:GetChatFont()
    local db = self:GetChatEnhancementDB()
    if db.chatFont then return db.chatFont end
    -- Fall back to the global font when set, otherwise the chat default.
    local theme = T:GetModule("Theme", true)
    local gf = theme and theme:Get("globalFont")
    if gf and gf ~= "__default" then return gf end
    return DEFAULT_CHAT_FONT
end

function Options:SetChatFont(info, value)
    local db = self:GetChatEnhancementDB()
    db.chatFont = value
    db._chatFontExplicitlySet = true
    self:RefreshChatStylingModule()
    -- RefreshChatStylingModule does not broadcast a theme change, so the
    -- ChatRenderer's own font cache won't be updated automatically.  Trigger a
    -- full renderer rebuild so existing messages re-render at once.
    local chatEnhancementsModule = T:GetModule("ChatEnhancements", true)
    local chatRendererModule = chatEnhancementsModule and chatEnhancementsModule:GetModule("ChatRenderer", true)
    if chatRendererModule and chatRendererModule.RebuildAllRenderers and chatRendererModule:IsEnabled() then
        chatRendererModule:RebuildAllRenderers()
    end
end

function Options:GetChatFontSize()
    return self:GetChatEnhancementDB().chatFontSize or DEFAULT_CHAT_FONT_SIZE
end

function Options:SetChatFontSize(info, value)
    self:GetChatEnhancementDB().chatFontSize = value
    self:RefreshChatStylingModule()
end

function Options:GetRowGap()
    return self:GetChatEnhancementDB().rowGap or DEFAULT_ROW_GAP
end

function Options:SetRowGap(info, value)
    self:GetChatEnhancementDB().rowGap = value
    self:RefreshChatStylingModule()
end

function Options:GetTabFont()
    return self:GetChatEnhancementDB().tabFont or DEFAULT_TAB_FONT
end

function Options:SetTabFont(info, value)
    self:GetChatEnhancementDB().tabFont = value
    self:RefreshChatStylingModule()
end

function Options:GetTabFontSize()
    return self:GetChatEnhancementDB().tabFontSize or DEFAULT_TAB_FONT_SIZE
end

function Options:SetTabFontSize(info, value)
    self:GetChatEnhancementDB().tabFontSize = value
    self:RefreshChatStylingModule()
end

function Options:AreAnimationsEnabled()
    local db = self:GetChatEnhancementDB()
    if db.animationsEnabled == nil then
        return true
    end

    return db.animationsEnabled
end

function Options:SetAnimationsEnabled(info, value)
    self:GetChatEnhancementDB().animationsEnabled = value
    self:RefreshChatStylingModule()
end

function Options:AreMessageFadesEnabled()
    local db = self:GetChatEnhancementDB()
    if db.messageFadesEnabled == nil then
        return false
    end

    return db.messageFadesEnabled
end

function Options:SetMessageFadesEnabled(info, value)
    self:GetChatEnhancementDB().messageFadesEnabled = value
    self:RefreshChatStylingModule()
end

function Options:GetMessageFadeDelay()
    return self:GetChatEnhancementDB().messageFadeDelay or 45
end

function Options:SetMessageFadeDelay(info, value)
    self:GetChatEnhancementDB().messageFadeDelay = value
    self:RefreshChatStylingModule()
end

function Options:GetMessageFadeDuration()
    return self:GetChatEnhancementDB().messageFadeDuration or 6
end

function Options:SetMessageFadeDuration(info, value)
    self:GetChatEnhancementDB().messageFadeDuration = value
    self:RefreshChatStylingModule()
end

function Options:GetShellAccentColor()
    -- Display the effective resolved color in the picker (tracks theme when not overridden).
    local c = self:GetResolvedShellAccentColor()
    return c.r, c.g, c.b, 1
end

function Options:SetShellAccentColor(info, r, g, b)
    local db = self:GetChatEnhancementDB()
    db.shellAccentColor = { r = r, g = g, b = b }
    db._shellAccentExplicitlySet = true
    self:RefreshChatStylingModule()
end

function Options:GetResolvedShellAccentColor()
    local db = self:GetChatEnhancementDB()
    if db.shellAccentColor then
        return CopyColor(db.shellAccentColor)
    end
    -- Fall back to the global theme accent color so chat chrome tracks Appearance changes.
    local theme = T:GetModule("Theme", true)
    if theme then
        local ac = theme:GetColor("accentColor")
        return { r = ac[1], g = ac[2], b = ac[3] }
    end
    return CopyColor(DEFAULT_SHELL_ACCENT)
end

function Options:GetChannelColor(key)
    local db = self:GetChatEnhancementDB()
    db.channelColors = db.channelColors or {}
    local color = db.channelColors[key] or DEFAULT_CHANNEL_COLORS[key] or DEFAULT_CHANNEL_COLORS.system
    return color.r, color.g, color.b, 1
end

function Options:SetChannelColor(key, r, g, b)
    local db = self:GetChatEnhancementDB()
    db.channelColors = db.channelColors or {}
    db.channelColors[key] = { r = r, g = g, b = b }
    self:RefreshChatStylingModule()
end

function Options:GetResolvedChannelColors()
    local resolved = {}
    local db = self:GetChatEnhancementDB()
    local custom = db.channelColors or {}
    for key, color in pairs(DEFAULT_CHANNEL_COLORS) do
        resolved[key] = CopyColor(custom[key] or color)
    end
    return resolved
end

function Options:IsAddonRedirectEnabled()
    local db = self:GetChatEnhancementDB()
    if db.addonRedirectEnabled == nil then
        return false
    end

    return db.addonRedirectEnabled
end

function Options:SetAddonRedirectEnabled(info, value)
    self:GetChatEnhancementDB().addonRedirectEnabled = value
    self:RefreshChatStylingModule()
end

function Options:SetShowAccentBar(info, value)
    self:GetChatEnhancementDB().showAccentBar = value
    self:RefreshChatStylingModule()
end

function Options:IsChromeAccentShown()
    local db = self:GetChatEnhancementDB()
    if db.showChromeAccent == nil then
        return true
    end
    return db.showChromeAccent
end

function Options:SetChromeAccentShown(info, value)
    self:GetChatEnhancementDB().showChromeAccent = value
    self:RefreshChatStylingModule()
end

function Options:AreAbbreviationsEnabled()
    local db = self:GetChatEnhancementDB()
    if db.abbreviationsEnabled == nil then
        return true
    end

    return db.abbreviationsEnabled
end

function Options:SetAbbreviationsEnabled(info, value)
    self:GetChatEnhancementDB().abbreviationsEnabled = value
    self:RefreshChatStylingModule()
end

function Options:GetAbbreviation(key)
    local db = self:GetChatEnhancementDB()
    db.abbreviations = db.abbreviations or {}

    return db.abbreviations[key] or self.DefaultAbbreviations[key] or ""
end

function Options:SetAbbreviation(key, value)
    local db = self:GetChatEnhancementDB()
    db.abbreviations = db.abbreviations or {}

    local normalized = Trim(value)
    if normalized == "" then
        db.abbreviations[key] = nil
    else
        db.abbreviations[key] = normalized
    end

    self:RefreshChatStylingModule()
end

function Options:GetResolvedAbbreviations()
    local resolved = {}
    local db = self:GetChatEnhancementDB()
    local custom = db.abbreviations or {}

    for key, value in pairs(self.DefaultAbbreviations) do
        resolved[key] = custom[key] or value
    end

    return resolved
end

function Options:IsBlizzardTellSoundSupressed()
    return self:GetChatEnhancementDB().supressBlizzardTellSound or false
end

function Options:SetBlizzardTellSoundSupressed(info, value)
    self:GetChatEnhancementDB().supressBlizzardTellSound = value

    ---@type ChatAlertsModule|nil
    local ChatAlertsModule = GetChatAlertsModule()

    if value and ChatAlertsModule then
        ChatAlertsModule:SupressBlizzardTellSound()
    else
        ConfigurationModule:PromptToReloadUI()
    end
end

function Options:IsBNChatAlertEnabled()
    return self:GetChatEnhancementDB().bnChatAlertEnabled or false
end

function Options:SetBNChatAlertEnabled(info, value)
    self:GetChatEnhancementDB().bnChatAlertEnabled = value
    self:RefreshChatAlertsModule()
end

function Options:GetBNSound()
    return self:GetChatEnhancementDB().bnSoundSelector or
        DEFAULT_SOUND
end

function Options:SetBNSound(info, value)
    self:GetChatEnhancementDB().bnSoundSelector = value
end

function Options:GetKeyWords()
    return self:GetChatEnhancementDB().keyWords or ""
end

function Options:SetKeyWords(info, value)
    self:GetChatEnhancementDB().keyWords = value
    local chatAlertsModule = GetChatAlertsModule()
    if chatAlertsModule and chatAlertsModule:IsEnabled() then
        chatAlertsModule:RefreshKeywords()
    end
end

function Options:IsKeywordAlertsEnabled()
    return self:GetChatEnhancementDB().keywordAlertsEnabled or false
end

function Options:SetKeywordAlertsEnabled(info, value)
    self:GetChatEnhancementDB().keywordAlertsEnabled = value
    local chatAlertsModule = GetChatAlertsModule()
    if chatAlertsModule and chatAlertsModule:IsEnabled() then
        chatAlertsModule:RefreshKeywords()
    end
end

function Options:GetKeywordMonitoringForChannel(channelName)
    return self:GetChatEnhancementDB()[channelName .. "KeywordMonitoring"] or false
end

function Options:GetKeyWordAlertSound()
    return self:GetChatEnhancementDB().keyWordAlertSound or
        DEFAULT_SOUND
end

function Options:SetKeyWordAlertSound(info, value)
    self:GetChatEnhancementDB().keyWordAlertSound = value
end

function Options:GetAlertSoundForChannel(channelName)
    return self:GetChatEnhancementDB()[channelName .. "SoundSelector"] or
        DEFAULT_SOUND
end

function Options:GetChannelMonitoringEnabled(channelName)
    return self:GetChatEnhancementDB()[channelName .. "ChatAlertEnabled"] or false
end

-- Minimum alpha that faded-out messages reach (0 = fully transparent, 1 = no fade)
function Options:GetMessageFadeMinAlpha()
    return self:GetChatEnhancementDB().messageFadeMinAlpha or 0.55
end

function Options:SetMessageFadeMinAlpha(info, value)
    self:GetChatEnhancementDB().messageFadeMinAlpha = value
    self:RefreshChatStylingModule()
end

-- Header area background color for the chrome drag region.
-- Default alpha is 0 so the header strip is invisible until the user explicitly sets a colour.
local DEFAULT_HEADER_BG = { r = 0.06, g = 0.09, b = 0.12, a = 0.9 }

function Options:IsHeaderHidden()
    return self:GetChatEnhancementDB().hideHeader == true
end

function Options:SetHeaderHidden(info, value)
    self:GetChatEnhancementDB().hideHeader = value == true
    self:RefreshChatStylingModule()
end

function Options:GetHeaderBgColor()
    local db = self:GetChatEnhancementDB()
    local c = db.headerBgColor or DEFAULT_HEADER_BG
    return c.r or DEFAULT_HEADER_BG.r, c.g or DEFAULT_HEADER_BG.g, c.b or DEFAULT_HEADER_BG.b,
        c.a ~= nil and c.a or DEFAULT_HEADER_BG.a
end

function Options:SetHeaderBgColor(info, r, g, b, a)
    self:GetChatEnhancementDB().headerBgColor = { r = r, g = g, b = b, a = a or 0 }
    self:RefreshChatStylingModule()
end

function Options:GetResolvedHeaderBgColor()
    local db = self:GetChatEnhancementDB()
    local c = db.headerBgColor or DEFAULT_HEADER_BG
    return {
        r = c.r or DEFAULT_HEADER_BG.r,
        g = c.g or DEFAULT_HEADER_BG.g,
        b = c.b or DEFAULT_HEADER_BG.b,
        a = c.a ~= nil and c.a or DEFAULT_HEADER_BG.a,
    }
end

-- Tab display style: "solid" (default pill buttons) or "transparent" (text + accent underline only)
function Options:GetTabStyle()
    return self:GetChatEnhancementDB().tabStyle or "solid"
end

function Options:SetTabStyle(info, value)
    self:GetChatEnhancementDB().tabStyle = value
    self:RefreshChatStylingModule()
end

-- Tab custom colors (nil = fall back to live theme defaults)
local DEFAULT_TAB_BG     = { r = 0.03, g = 0.05, b = 0.07 }
local DEFAULT_TAB_BORDER = { r = 0.10, g = 0.72, b = 0.74 } -- fallback only when theme unavailable
local DEFAULT_TAB_ACCENT = { r = 0.10, g = 0.72, b = 0.74 } -- fallback only when theme unavailable

local function GetThemePrimaryColor()
    local theme = T:GetModule("Theme", true)
    if theme then
        local c = theme:GetColor("primaryColor")
        return { r = c[1], g = c[2], b = c[3] }
    end
    return DEFAULT_TAB_ACCENT
end

local function GetThemeTabBg()
    local theme = T:GetModule("Theme", true)
    if theme then
        local c = theme:GetColor("backgroundColor")
        local a = theme:Get("backgroundAlpha") or 0.94
        -- Slightly darker than the panel bg for visual separation
        return { r = c[1] * 0.7, g = c[2] * 0.7, b = c[3] * 0.7 }
    end
    return DEFAULT_TAB_BG
end

function Options:GetTabBgColor()
    local db = self:GetChatEnhancementDB()
    local c = db.tabBgColor
    if c then return c.r, c.g, c.b, 1 end
    local def = GetThemeTabBg()
    return def.r, def.g, def.b, 1
end

function Options:SetTabBgColor(info, r, g, b)
    local db = self:GetChatEnhancementDB()
    db.tabBgColor = { r = r, g = g, b = b }
    db._tabBgExplicitlySet = true
    self:RefreshChatStylingModule()
end

function Options:GetResolvedTabBgColor()
    local db = self:GetChatEnhancementDB()
    if db.tabBgColor then return CopyColor(db.tabBgColor) end
    return GetThemeTabBg()
end

function Options:GetTabBorderColor()
    local db = self:GetChatEnhancementDB()
    local c = db.tabBorderColor
    if c then return c.r, c.g, c.b, 1 end
    local def = GetThemePrimaryColor()
    return def.r, def.g, def.b, 1
end

function Options:SetTabBorderColor(info, r, g, b)
    local db = self:GetChatEnhancementDB()
    db.tabBorderColor = { r = r, g = g, b = b }
    db._tabBorderExplicitlySet = true
    self:RefreshChatStylingModule()
end

function Options:GetResolvedTabBorderColor()
    local db = self:GetChatEnhancementDB()
    if db.tabBorderColor then return CopyColor(db.tabBorderColor) end
    return GetThemePrimaryColor()
end

function Options:GetTabAccentColor()
    local db = self:GetChatEnhancementDB()
    local c = db.tabAccentColor
    if c then return c.r, c.g, c.b, 1 end
    local def = GetThemePrimaryColor()
    return def.r, def.g, def.b, 1
end

function Options:SetTabAccentColor(info, r, g, b)
    local db = self:GetChatEnhancementDB()
    db.tabAccentColor = { r = r, g = g, b = b }
    db._tabAccentExplicitlySet = true
    self:RefreshChatStylingModule()
end

function Options:GetResolvedTabAccentColor()
    local db = self:GetChatEnhancementDB()
    if db.tabAccentColor then return CopyColor(db.tabAccentColor) end
    return GetThemePrimaryColor()
end

-- Edit box visual customisation
local DEFAULT_EDITBOX_BG = { r = 0.04, g = 0.05, b = 0.07, a = 0.95 }

function Options:GetEditBoxBgColor()
    local db = self:GetChatEnhancementDB()
    local c = db.editBoxBgColor or DEFAULT_EDITBOX_BG
    return c.r or DEFAULT_EDITBOX_BG.r, c.g or DEFAULT_EDITBOX_BG.g, c.b or DEFAULT_EDITBOX_BG.b,
        c.a ~= nil and c.a or DEFAULT_EDITBOX_BG.a
end

function Options:SetEditBoxBgColor(info, r, g, b, a)
    self:GetChatEnhancementDB().editBoxBgColor = { r = r, g = g, b = b, a = a ~= nil and a or 0.95 }
    self:RefreshChatStylingModule()
end

function Options:GetResolvedEditBoxBgColor()
    local db = self:GetChatEnhancementDB()
    local c = db.editBoxBgColor or DEFAULT_EDITBOX_BG
    return {
        r = c.r or DEFAULT_EDITBOX_BG.r,
        g = c.g or DEFAULT_EDITBOX_BG.g,
        b = c.b or DEFAULT_EDITBOX_BG.b,
        a = c.a ~= nil and c.a or DEFAULT_EDITBOX_BG.a,
    }
end

function Options:GetEditBoxFont()
    return self:GetChatEnhancementDB().editBoxFont or nil -- nil = inherit chat font
end

function Options:SetEditBoxFont(info, value)
    self:GetChatEnhancementDB().editBoxFont = value ~= "" and value or nil
    self:RefreshChatStylingModule()
end

function Options:GetEditBoxFontSize()
    return self:GetChatEnhancementDB().editBoxFontSize or 0 -- 0 = inherit chat font size
end

function Options:SetEditBoxFontSize(info, value)
    self:GetChatEnhancementDB().editBoxFontSize = value
    self:RefreshChatStylingModule()
end

function Options:GetEditBoxHeight()
    return self:GetChatEnhancementDB().editBoxHeight or 28
end

function Options:SetEditBoxHeight(info, value)
    self:GetChatEnhancementDB().editBoxHeight = value
    self:RefreshChatStylingModule()
end

function Options:GetEditBoxPaddingH()
    return self:GetChatEnhancementDB().editBoxPaddingH or 10
end

function Options:SetEditBoxPaddingH(info, value)
    self:GetChatEnhancementDB().editBoxPaddingH = value
    self:RefreshChatStylingModule()
end

function Options:GetEditBoxPaddingV()
    return self:GetChatEnhancementDB().editBoxPaddingV or 2
end

function Options:SetEditBoxPaddingV(info, value)
    self:GetChatEnhancementDB().editBoxPaddingV = value
    self:RefreshChatStylingModule()
end

function Options:GetEditBoxPosition()
    return self:GetChatEnhancementDB().editBoxPosition or "below"
end

function Options:SetEditBoxPosition(info, value)
    self:GetChatEnhancementDB().editBoxPosition = value
    self:RefreshChatStylingModule()
end

-- Lock: prevents moving/resizing the chat frame and hides drag/resize handles
function Options:IsChatLocked()
    local db = self:GetChatEnhancementDB()
    if db.chatLocked == nil then
        return false
    end
    return db.chatLocked
end

function Options:SetChatLocked(info, value)
    self:GetChatEnhancementDB().chatLocked = value
    self:RefreshChatStylingModule()
end

-- Exact frame position override.  X/Y are BOTTOMLEFT offsets from UIParent in screen pixels.
-- nil means no override (WoW manages placement).
function Options:GetChatPositionX()
    return self:GetChatEnhancementDB().chatPositionX
end

function Options:SetChatPositionX(info, value)
    local n = tonumber(value)
    self:GetChatEnhancementDB().chatPositionX = n
    self:RefreshChatStylingModule()
    local m = GetChatStylingModule()
    if m then m:ApplyPositionOverride() end
end

function Options:GetChatPositionY()
    return self:GetChatEnhancementDB().chatPositionY
end

function Options:SetChatPositionY(info, value)
    local n = tonumber(value)
    self:GetChatEnhancementDB().chatPositionY = n
    self:RefreshChatStylingModule()
    local m = GetChatStylingModule()
    if m then m:ApplyPositionOverride() end
end

function Options:GetChatPositionXStr()
    local v = self:GetChatEnhancementDB().chatPositionX
    return v and tostring(math.floor(v + 0.5)) or ""
end

function Options:GetChatPositionYStr()
    local v = self:GetChatEnhancementDB().chatPositionY
    return v and tostring(math.floor(v + 0.5)) or ""
end

function Options:ClearChatPosition()
    local db = self:GetChatEnhancementDB()
    db.chatPositionX = nil
    db.chatPositionY = nil
    self:RefreshChatStylingModule()
end

function Options:GetChatWidth()
    return self:GetChatEnhancementDB().chatWidth
end

function Options:GetChatHeight()
    return self:GetChatEnhancementDB().chatHeight
end

-- Message row background color (the per-row backdrop inside the renderer).
local DEFAULT_MSG_BG = { r = 0.03, g = 0.05, b = 0.07, a = 0.72 }

local function GetThemeLinkedMsgBg(self)
    local chatBg = self:GetResolvedChatBgColor()
    return {
        r = chatBg and chatBg.r or DEFAULT_MSG_BG.r,
        g = chatBg and chatBg.g or DEFAULT_MSG_BG.g,
        b = chatBg and chatBg.b or DEFAULT_MSG_BG.b,
        a = 0.30,
    }
end

function Options:GetMsgBgColor()
    local db = self:GetChatEnhancementDB()
    local c = db.msgBgColor or GetThemeLinkedMsgBg(self)
    return c.r or DEFAULT_MSG_BG.r, c.g or DEFAULT_MSG_BG.g, c.b or DEFAULT_MSG_BG.b,
        c.a ~= nil and c.a or DEFAULT_MSG_BG.a
end

function Options:SetMsgBgColor(info, r, g, b, a)
    self:GetChatEnhancementDB().msgBgColor = { r = r, g = g, b = b, a = a ~= nil and a or DEFAULT_MSG_BG.a }
    self:RefreshChatStylingModule()
end

function Options:GetResolvedMsgBgColor()
    local db = self:GetChatEnhancementDB()
    local c = db.msgBgColor or GetThemeLinkedMsgBg(self)
    return {
        r = c.r or DEFAULT_MSG_BG.r,
        g = c.g or DEFAULT_MSG_BG.g,
        b = c.b or DEFAULT_MSG_BG.b,
        a = c.a ~= nil and c.a or DEFAULT_MSG_BG.a,
    }
end

function Options:IsTabNameFadeEnabled()
    return self:GetChatEnhancementDB().tabNameFade == true
end

function Options:SetTabNameFadeEnabled(info, value)
    self:GetChatEnhancementDB().tabNameFade = value == true
    self:RefreshChatStylingModule()
end

-- Keyword row highlight: tint matching rows in the renderer.
function Options:IsKeywordHighlightEnabled()
    return self:GetChatEnhancementDB().keywordHighlightEnabled == true
end

function Options:SetKeywordHighlightEnabled(info, value)
    self:GetChatEnhancementDB().keywordHighlightEnabled = value == true
    self:RefreshChatStylingModule()
end

local DEFAULT_KW_HIGHLIGHT = { r = 0.95, g = 0.76, b = 0.26 }

function Options:GetKeywordHighlightColor()
    local db = self:GetChatEnhancementDB()
    local c = db.kwHighlightColor or DEFAULT_KW_HIGHLIGHT
    return c.r or DEFAULT_KW_HIGHLIGHT.r, c.g or DEFAULT_KW_HIGHLIGHT.g, c.b or DEFAULT_KW_HIGHLIGHT.b, 1
end

function Options:GetResolvedKeywordHighlightColor()
    local db = self:GetChatEnhancementDB()
    local c = db.kwHighlightColor or DEFAULT_KW_HIGHLIGHT
    return {
        r = c.r or DEFAULT_KW_HIGHLIGHT.r,
        g = c.g or DEFAULT_KW_HIGHLIGHT.g,
        b = c.b or DEFAULT_KW_HIGHLIGHT.b,
    }
end

function Options:SetKeywordHighlightColor(info, r, g, b)
    self:GetChatEnhancementDB().kwHighlightColor = { r = r, g = g, b = b }
    self:RefreshChatStylingModule()
end

--- Returns the parsed keyword list as a lowercase string array, or nil if disabled/empty.
--- Keywords are returned if *either* sound alerts or row highlight is enabled so both
--- systems can share the same parsed list without unnecessary coupling.
function Options:GetParsedKeywords()
    if not self:IsKeywordAlertsEnabled() and not self:IsKeywordHighlightEnabled() then return nil end
    local raw = self:GetKeyWords()
    if not raw or raw == "" then return nil end
    local t = {}
    for word in (raw .. ","):gmatch("([^,]+),") do
        word = word:match("^%s*(.-)%s*$")
        if word ~= "" then
            t[#t + 1] = word:lower()
        end
    end
    return #t > 0 and t or nil
end

-- Whisper tabs: automatically open per-sender tabs for incoming whispers.
function Options:IsWhisperTabEnabled()
    return self:GetChatEnhancementDB().whisperTabsEnabled == true
end

function Options:SetWhisperTabEnabled(info, value)
    self:GetChatEnhancementDB().whisperTabsEnabled = value == true
    self:RefreshChatStylingModule()
end

-- ─── Message Routing Rules ──────────────────────────────────────────────────
-- Stored as a table of {pattern, tab} objects at db.routingEntries.
-- A legacy raw-string field (routingRulesRaw) is migrated on first access.

local MAX_ROUTING_ENTRIES = 20

--- Returns the routing entries table, migrating from the legacy string format
--- if needed.  Always returns a real (possibly empty) table.
function Options:GetRoutingEntries()
    local db = self:GetChatEnhancementDB()
    if not db.routingEntries then
        db.routingEntries = {}
        -- Migrate legacy raw string format if present.
        local raw = db.routingRulesRaw or ""
        for line in raw:gmatch("[^\n]+") do
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" then
                local lastColon = trimmed:find(":[^:]*$")
                if lastColon then
                    local pattern = trimmed:sub(1, lastColon - 1):match("^%s*(.-)%s*$")
                    local tabName = trimmed:sub(lastColon + 1):match("^%s*(.-)%s*$")
                    if pattern and pattern ~= "" and tabName and tabName ~= "" then
                        db.routingEntries[#db.routingEntries + 1] = { pattern = pattern, tab = tabName }
                    end
                end
            end
        end
        db.routingRulesRaw = nil -- clear legacy field after migration
    end
    return db.routingEntries
end

function Options:AddRoutingEntry()
    local entries = self:GetRoutingEntries()
    if #entries >= MAX_ROUTING_ENTRIES then return end
    entries[#entries + 1] = { pattern = "", tab = "" }
    self:RefreshChatStylingModule()
end

function Options:RemoveRoutingEntry(index)
    local entries = self:GetRoutingEntries()
    if entries[index] then
        table.remove(entries, index)
        self:RefreshChatStylingModule()
    end
end

function Options:GetRoutingEntryPattern(index)
    local entries = self:GetRoutingEntries()
    return (entries[index] and entries[index].pattern) or ""
end

function Options:SetRoutingEntryPattern(index, value)
    local entries = self:GetRoutingEntries()
    if entries[index] then
        entries[index].pattern = value or ""
        self:RefreshChatStylingModule()
    end
end

function Options:GetRoutingEntryTab(index)
    local entries = self:GetRoutingEntries()
    return (entries[index] and entries[index].tab) or ""
end

function Options:SetRoutingEntryTab(index, value)
    local entries = self:GetRoutingEntries()
    if entries[index] then
        entries[index].tab = value or ""
        self:RefreshChatStylingModule()
    end
end

--- Returns a name→name table of all current chat tab names, suitable for an
--- AceConfig select widget.
function Options:GetAvailableChatTabs()
    local tabs = {}
    local CHAT_FRAMES = _G.CHAT_FRAMES or {}
    for _, frameName in ipairs(CHAT_FRAMES) do
        local frame = _G[frameName]
        local tab   = frame and _G[frameName .. "Tab"] or nil
        local text  = tab and type(tab.GetText) == "function" and tab:GetText() or nil
        if text and text ~= "" then
            -- Strip WoW markup from tab names.
            text = text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
            tabs[text] = text
        end
    end
    return tabs
end

--- Returns routing rules as an array of {pattern, tabName} for use by the
--- renderer.  Entries with empty pattern or tab are skipped.
function Options:GetParsedRoutingRules()
    local entries = self:GetRoutingEntries()
    local rules = {}
    for _, entry in ipairs(entries) do
        local pattern = entry.pattern and entry.pattern:match("^%s*(.-)%s*$") or ""
        local tabName = entry.tab and entry.tab:match("^%s*(.-)%s*$") or ""
        if pattern ~= "" and tabName ~= "" then
            rules[#rules + 1] = { pattern = pattern, tabName = tabName }
        end
    end
    return rules
end

-- Header Datatext Bar: one row of datatext cells embedded in the chat header.

function Options:GetHeaderDatatextDB()
    local db = self:GetChatEnhancementDB()
    if not db.headerDatatext then
        db.headerDatatext = {}
    end
    return db.headerDatatext
end

--- Returns a snapshot table used by ChatStylingModule.settings.headerDatatext.
function Options:GetHeaderDatatextSettings()
    local hdt = self:GetHeaderDatatextDB()
    local textColor = (hdt.useCustomTextColor and hdt.textColor) and hdt.textColor or nil
    return {
        enabled            = hdt.enabled == true,
        slotCount          = math.max(1, math.min(3, tonumber(hdt.slotCount) or 1)),
        slotWidth          = math.max(32, math.min(200, tonumber(hdt.slotWidth) or 68)),
        font               = (type(hdt.font) == "string" and hdt.font ~= "") and hdt.font or nil,
        fontSize           = math.max(8, math.min(18, tonumber(hdt.fontSize) or 11)),
        useCustomTextColor = hdt.useCustomTextColor == true,
        textColor          = textColor and { r = textColor.r or 0.92, g = textColor.g or 0.94, b = textColor.b or 0.96 } or
            nil,
        slots              = {
            hdt.slot1 or "NONE",
            hdt.slot2 or "NONE",
            hdt.slot3 or "NONE",
        },
    }
end

function Options:IsHeaderDatatextEnabled()
    return self:GetHeaderDatatextDB().enabled == true
end

function Options:SetHeaderDatatextEnabled(info, value)
    self:GetHeaderDatatextDB().enabled = value == true
    self:RefreshChatStylingModule()
end

function Options:GetHeaderDatatextSlotCount(info)
    return math.max(1, math.min(3, tonumber(self:GetHeaderDatatextDB().slotCount) or 1))
end

function Options:SetHeaderDatatextSlotCount(info, value)
    self:GetHeaderDatatextDB().slotCount = math.max(1, math.min(3, tonumber(value) or 1))
    self:RefreshChatStylingModule()
end

function Options:GetHeaderDatatextSlot(n)
    return self:GetHeaderDatatextDB()["slot" .. n] or "NONE"
end

function Options:SetHeaderDatatextSlot(n, name)
    self:GetHeaderDatatextDB()["slot" .. n] = (name ~= "NONE" and name) or "NONE"
    self:RefreshChatStylingModule()
end

function Options:GetHeaderDatatextFont()
    local hdt = self:GetHeaderDatatextDB()
    if type(hdt.font) == "string" and hdt.font ~= "" then
        return hdt.font
    end
    return self:GetTabFont()
end

function Options:SetHeaderDatatextFont(info, value)
    local hdt = self:GetHeaderDatatextDB()
    hdt.font = (type(value) == "string" and value ~= "") and value or nil
    self:RefreshChatStylingModule()
end

function Options:GetHeaderDatatextFontSize()
    return math.max(8, math.min(18, tonumber(self:GetHeaderDatatextDB().fontSize) or 11))
end

function Options:SetHeaderDatatextFontSize(info, value)
    self:GetHeaderDatatextDB().fontSize = math.max(8, math.min(18, tonumber(value) or 11))
    self:RefreshChatStylingModule()
end

function Options:GetHeaderDatatextSlotWidth()
    return math.max(32, math.min(200, tonumber(self:GetHeaderDatatextDB().slotWidth) or 68))
end

function Options:SetHeaderDatatextSlotWidth(info, value)
    self:GetHeaderDatatextDB().slotWidth = math.max(32, math.min(200, tonumber(value) or 68))
    self:RefreshChatStylingModule()
end

function Options:GetHeaderDatatextUseCustomTextColor()
    return self:GetHeaderDatatextDB().useCustomTextColor == true
end

function Options:SetHeaderDatatextUseCustomTextColor(info, value)
    self:GetHeaderDatatextDB().useCustomTextColor = value == true
    self:RefreshChatStylingModule()
end

function Options:GetHeaderDatatextTextColor()
    local c = self:GetHeaderDatatextDB().textColor or {}
    return c.r or 0.92, c.g or 0.94, c.b or 0.96
end

function Options:SetHeaderDatatextTextColor(info, r, g, b)
    self:GetHeaderDatatextDB().textColor = { r = r, g = g, b = b }
    self:RefreshChatStylingModule()
end

--- Returns a choices table {name → prettyName} for datatext slot dropdowns.
function Options:GetHeaderDatatextChoices()
    local DataTextMod = T:GetModule("Datatexts", true)
    if DataTextMod and DataTextMod.GetStandaloneDatatextChoices then
        return DataTextMod:GetStandaloneDatatextChoices()
    end
    return { NONE = "None" }
end

-- ────────────────────────────────────────────────────────────────────────────
-- Realm stripping
-- ────────────────────────────────────────────────────────────────────────────

function Options:IsClassIconsEnabled()
    local db = self:GetChatEnhancementDB()
    return db.showClassIcons == true
end

function Options:SetClassIconsEnabled(info, value)
    self:GetChatEnhancementDB().showClassIcons = value == true
    self:RefreshChatStylingModule()
end

function Options:GetClassIconStyle()
    local val = self:GetChatEnhancementDB().classIconStyle
    if val then return val end
    local theme = T:GetModule("Theme", true)
    return (theme and theme:Get("classIconStyle")) or "default"
end

function Options:SetClassIconStyle(info, value)
    self:GetChatEnhancementDB().classIconStyle = value
    self:RefreshChatStylingModule()
end

function Options:IsRealmHidden()
    return self:GetChatEnhancementDB().hideRealm == true
end

function Options:SetRealmHidden(info, value)
    self:GetChatEnhancementDB().hideRealm = value == true
    self:RefreshChatStylingModule()
end

-- ────────────────────────────────────────────────────────────────────────────
-- Chat history limit (max messages retained per frame)
-- ────────────────────────────────────────────────────────────────────────────

local DEFAULT_HISTORY_LIMIT = 350

function Options:GetChatHistoryLimit()
    return tonumber(self:GetChatEnhancementDB().chatHistoryLimit) or DEFAULT_HISTORY_LIMIT
end

function Options:SetChatHistoryLimit(info, value)
    local n = math.max(50, math.min(500, tonumber(value) or DEFAULT_HISTORY_LIMIT))
    self:GetChatEnhancementDB().chatHistoryLimit = n
    self:RefreshChatStylingModule()
end

-- ────────────────────────────────────────────────────────────────────────────
-- Frame (chrome) background and border colors
-- ────────────────────────────────────────────────────────────────────────────

-- Resolves the addon-wide theme background color+alpha, used as the chat bg
-- default so it follows the global appearance setting until overridden.
local function GetGlobalThemeBg()
    local theme = T:GetModule("Theme", true)
    if theme then
        local c = theme:GetColor("backgroundColor")
        local a = theme:Get("backgroundAlpha") or 0.94
        return { r = c[1] or 0.05, g = c[2] or 0.06, b = c[3] or 0.08, a = a }
    end
    return { r = 0.05, g = 0.06, b = 0.08, a = 0.94 }
end

-- Resolves the addon-wide theme border color+alpha, used as the chat border
-- default so it follows the global appearance setting until overridden.
local function GetGlobalThemeBorder()
    local theme = T:GetModule("Theme", true)
    if theme then
        local c = theme:GetColor("borderColor")
        local a = theme:Get("borderAlpha") or 0.85
        return { r = c[1] or 0.24, g = c[2] or 0.26, b = c[3] or 0.32, a = a }
    end
    return { r = 0.24, g = 0.26, b = 0.32, a = 0.85 }
end

function Options:GetChatBgColor()
    local db = self:GetChatEnhancementDB()
    local c = db.chatBgColor
    if c then
        return c.r or 0.05, c.g or 0.06, c.b or 0.08, c.a ~= nil and c.a or 0.94
    end
    local def = GetGlobalThemeBg()
    return def.r, def.g, def.b, def.a
end

function Options:SetChatBgColor(info, r, g, b, a)
    local db = self:GetChatEnhancementDB()
    db.chatBgColor = { r = r, g = g, b = b, a = a ~= nil and a or 0.94 }
    db._chatBgExplicitlySet = true
    self:RefreshChatStylingModule()
end

function Options:GetResolvedChatBgColor()
    local db = self:GetChatEnhancementDB()
    if db.chatBgColor then
        local c = db.chatBgColor
        return {
            r = c.r or 0.05,
            g = c.g or 0.06,
            b = c.b or 0.08,
            a = c.a ~= nil and c.a or 0.94,
        }
    end
    return GetGlobalThemeBg()
end

function Options:GetChatBorderColor()
    local db = self:GetChatEnhancementDB()
    local c = db.chatBorderColor
    if c then
        return c.r or 0.24, c.g or 0.26, c.b or 0.32, c.a ~= nil and c.a or 0.85
    end
    local def = GetGlobalThemeBorder()
    return def.r, def.g, def.b, def.a
end

function Options:SetChatBorderColor(info, r, g, b, a)
    local db = self:GetChatEnhancementDB()
    db.chatBorderColor = { r = r, g = g, b = b, a = a ~= nil and a or 0.85 }
    db._chatBorderExplicitlySet = true
    self:RefreshChatStylingModule()
end

function Options:GetResolvedChatBorderColor()
    local db = self:GetChatEnhancementDB()
    if db.chatBorderColor then
        local c = db.chatBorderColor
        return {
            r = c.r or 0.24,
            g = c.g or 0.26,
            b = c.b or 0.32,
            a = c.a ~= nil and c.a or 0.85,
        }
    end
    return GetGlobalThemeBorder()
end
