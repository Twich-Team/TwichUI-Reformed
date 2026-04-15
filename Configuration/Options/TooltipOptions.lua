---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local OptionsRoot = ConfigurationModule.Options --[[@as any]]

local Clamp = _G.Clamp

local function RoundPixel(value)
    return math.floor((tonumber(value) or 0) + 0.5)
end

local function ClampValue(value, low, high)
    if type(Clamp) == "function" then
        return Clamp(value, low, high)
    end

    local numeric = tonumber(value) or low
    if numeric < low then
        return low
    end
    if numeric > high then
        return high
    end
    return numeric
end

---@class TooltipConfigurationOptions
local Options = OptionsRoot.Tooltip or {}
OptionsRoot.Tooltip = Options

local function GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    if not profile.tooltip then
        profile.tooltip = {
            enabled = true,
            debugEnabled = false,
            anchorMode = "default",
            anchorLocked = true,
            anchorX = 1050,
            anchorY = 260,
            scale = 1,
            headerFontSize = 13,
            bodyFontSize = 12,
            showAccent = true,
            usePlayerClassColors = true,
            showClassIcon = true,
            classIconStyle = "global",
            showHealthBar = true,
            statusBarHeight = 8,
            cursorOffsetX = 28,
            cursorOffsetY = 16,
            hideInCombat = false,
            enableFadeIn = true,
            showPlayerDetails = true,
            showFaction = true,
            showFactionIcon = true,
            showGuildRank = true,
            showMythicScore = true,
            showItemLevel = true,
            showTransmogStatus = true,
            useItemQualityBorder = true,
        }
    end
    return profile.tooltip
end

local function GetModule()
    return T:GetModule("Tooltip") --[[@as any]]
end

local function RefreshModule()
    local module = GetModule()
    if module and module:IsEnabled() and module.RefreshAllTooltips then
        module:RefreshAllTooltips()
    end
end

local function RefreshAnchor()
    local module = GetModule()
    if module and module:IsEnabled() and module.RefreshAnchor then
        module:RefreshAnchor()
    end
end

function Options:GetEnabled()
    return GetDB().enabled ~= false
end

function Options:SetEnabled(_, value)
    GetDB().enabled = value ~= false
    local module = GetModule()
    if value then
        module:Enable()
    else
        module:Disable()
    end
end

function Options:GetAnchorMode()
    local value = GetDB().anchorMode
    if value ~= "cursor" and value ~= "fixed" then
        return "default"
    end
    return value
end

function Options:SetAnchorMode(_, value)
    if value ~= "cursor" and value ~= "fixed" then
        value = "default"
    end
    GetDB().anchorMode = value
    RefreshAnchor()
end

function Options:GetAnchorLocked()
    return GetDB().anchorLocked ~= false
end

function Options:SetAnchorLocked(_, value)
    GetDB().anchorLocked = value ~= false
    RefreshAnchor()
end

function Options:GetAnchorX()
    return RoundPixel(GetDB().anchorX or 1050)
end

function Options:GetAnchorY()
    return RoundPixel(GetDB().anchorY or 260)
end

function Options:SetAnchorPosition(x, y)
    local db = GetDB()
    db.anchorX = RoundPixel(x or db.anchorX or 1050)
    db.anchorY = RoundPixel(y or db.anchorY or 260)
    RefreshAnchor()
end

function Options:ResetAnchorPosition()
    local db = GetDB()
    db.anchorX = 1050
    db.anchorY = 260
    RefreshAnchor()
end

function Options:GetScale()
    return tonumber(GetDB().scale) or 1
end

function Options:SetScale(_, value)
    GetDB().scale = ClampValue(tonumber(value) or 1, 0.8, 1.4)
    RefreshModule()
end

function Options:GetHeaderFontSize()
    return GetDB().headerFontSize or 13
end

function Options:SetHeaderFontSize(_, value)
    GetDB().headerFontSize = math.floor((tonumber(value) or 13) + 0.5)
    RefreshModule()
end

function Options:GetBodyFontSize()
    return GetDB().bodyFontSize or 12
end

function Options:SetBodyFontSize(_, value)
    GetDB().bodyFontSize = math.floor((tonumber(value) or 12) + 0.5)
    RefreshModule()
end

function Options:GetShowAccent()
    return GetDB().showAccent ~= false
end

function Options:SetShowAccent(_, value)
    GetDB().showAccent = value ~= false
    RefreshModule()
end

function Options:GetUsePlayerClassColors()
    return GetDB().usePlayerClassColors ~= false
end

function Options:SetUsePlayerClassColors(_, value)
    GetDB().usePlayerClassColors = value ~= false
    RefreshModule()
end

function Options:GetShowClassIcon()
    return GetDB().showClassIcon ~= false
end

function Options:SetShowClassIcon(_, value)
    GetDB().showClassIcon = value ~= false
    RefreshModule()
end

function Options:GetClassIconStyle()
    local value = GetDB().classIconStyle
    if value == "default" or value == "fabled" or value == "pixel" then
        return value
    end
    return "global"
end

function Options:SetClassIconStyle(_, value)
    if value ~= "default" and value ~= "fabled" and value ~= "pixel" then
        value = "global"
    end
    GetDB().classIconStyle = value
    RefreshModule()
end

function Options:GetShowHealthBar()
    return GetDB().showHealthBar ~= false
end

function Options:SetShowHealthBar(_, value)
    GetDB().showHealthBar = value ~= false
    RefreshModule()
end

function Options:GetHideInCombat()
    return GetDB().hideInCombat == true
end

function Options:SetHideInCombat(_, value)
    GetDB().hideInCombat = value == true
    RefreshModule()
end

function Options:GetEnableFadeIn()
    return GetDB().enableFadeIn ~= false
end

function Options:SetEnableFadeIn(_, value)
    GetDB().enableFadeIn = value ~= false
    RefreshModule()
end

function Options:GetDebugEnabled()
    return GetDB().debugEnabled == true
end

function Options:SetDebugEnabled(_, value)
    GetDB().debugEnabled = value == true
    if value ~= true and T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole then
        T.Tools.UI.DebugConsole:ClearLogs("tooltip")
    end
end

function Options:GetShowPlayerDetails()
    return GetDB().showPlayerDetails ~= false
end

function Options:SetShowPlayerDetails(_, value)
    GetDB().showPlayerDetails = value ~= false
    RefreshModule()
end

function Options:GetShowFaction()
    return GetDB().showFaction ~= false
end

function Options:SetShowFaction(_, value)
    GetDB().showFaction = value ~= false
    RefreshModule()
end

function Options:GetShowFactionIcon()
    return GetDB().showFactionIcon ~= false
end

function Options:SetShowFactionIcon(_, value)
    GetDB().showFactionIcon = value ~= false
    RefreshModule()
end

function Options:GetShowGuildRank()
    return GetDB().showGuildRank ~= false
end

function Options:SetShowGuildRank(_, value)
    GetDB().showGuildRank = value ~= false
    RefreshModule()
end

function Options:GetShowMythicScore()
    return GetDB().showMythicScore ~= false
end

function Options:SetShowMythicScore(_, value)
    GetDB().showMythicScore = value ~= false
    RefreshModule()
end

function Options:GetShowItemLevel()
    return GetDB().showItemLevel ~= false
end

function Options:SetShowItemLevel(_, value)
    GetDB().showItemLevel = value ~= false
    RefreshModule()
end

function Options:GetShowTransmogStatus()
    return GetDB().showTransmogStatus ~= false
end

function Options:SetShowTransmogStatus(_, value)
    GetDB().showTransmogStatus = value ~= false
    RefreshModule()
end

function Options:GetUseItemQualityBorder()
    return GetDB().useItemQualityBorder ~= false
end

function Options:SetUseItemQualityBorder(_, value)
    GetDB().useItemQualityBorder = value ~= false
    RefreshModule()
end

function Options:GetStatusBarHeight()
    return GetDB().statusBarHeight or 8
end

function Options:SetStatusBarHeight(_, value)
    GetDB().statusBarHeight = math.floor(ClampValue(tonumber(value) or 8, 5, 16) + 0.5)
    RefreshModule()
end

function Options:GetCursorOffsetX()
    return GetDB().cursorOffsetX or 28
end

function Options:SetCursorOffsetX(_, value)
    GetDB().cursorOffsetX = math.floor(ClampValue(tonumber(value) or 28, -40, 120) + 0.5)
    RefreshModule()
end

function Options:GetCursorOffsetY()
    return GetDB().cursorOffsetY or 16
end

function Options:SetCursorOffsetY(_, value)
    GetDB().cursorOffsetY = math.floor(ClampValue(tonumber(value) or 16, -60, 80) + 0.5)
    RefreshModule()
end

function Options:ShowPreview()
    local module = GetModule()
    if module and module.ShowPreview then
        module:ShowPreview()
    end
end

function Options:OpenDebugConsole()
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if console and console.Show then
        console:Show("tooltip")
    end
end

function Options:CaptureDebugSnapshot()
    local module = GetModule()
    if module and module.CaptureDebugSnapshot then
        module:CaptureDebugSnapshot(true)
    end
end

function Options:BuildConfiguration()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Tooltip",
        order = 18,
        args = {
            overview = W.Description(1,
                "Reskins Blizzard tooltips with TwichUI chrome, theme-aware surfaces, and a movable fixed anchor that can also be tuned from the Interface Designer."),
            general = W.IGroup(10, "General", {
                enable = {
                    type = "toggle",
                    order = 1,
                    name = "Enable",
                    desc = "Enable the TwichUI tooltip module.",
                    handler = Options,
                    get = "GetEnabled",
                    set = "SetEnabled",
                },
                preview = {
                    type = "execute",
                    order = 2,
                    name = "Preview Tooltip",
                    desc = "Shows a sample tooltip using the current anchor and appearance settings.",
                    handler = Options,
                    func = "ShowPreview",
                    width = 1.5,
                },
                anchorMode = {
                    type = "select",
                    order = 3,
                    name = "Anchor Mode",
                    desc =
                    "Choose whether the primary tooltip uses Blizzard positioning, follows the cursor, or snaps to a fixed anchor you can move in the Interface Designer.",
                    handler = Options,
                    get = "GetAnchorMode",
                    set = "SetAnchorMode",
                    values = {
                        default = "Default",
                        cursor = "Cursor",
                        fixed = "Fixed Anchor",
                    },
                },
                scale = {
                    type = "range",
                    order = 4,
                    name = "Scale",
                    desc = "Overall scale applied to managed tooltips.",
                    min = 0.8,
                    max = 1.4,
                    step = 0.01,
                    handler = Options,
                    get = "GetScale",
                    set = "SetScale",
                },
            }),
            appearance = W.IGroup(20, "Appearance", {
                accent = {
                    type = "toggle",
                    order = 1,
                    name = "Accent Trim",
                    desc = "Show the TwichUI accent trim and soft glow around tooltips.",
                    handler = Options,
                    get = "GetShowAccent",
                    set = "SetShowAccent",
                },
                playerClassColors = {
                    type = "toggle",
                    order = 2,
                    name = "Class Tint Player Tooltips",
                    desc = "Tint player tooltip names and borders to class color, similar to Horizon Insight.",
                    handler = Options,
                    get = "GetUsePlayerClassColors",
                    set = "SetUsePlayerClassColors",
                },
                classIcons = {
                    type = "toggle",
                    order = 3,
                    name = "Show Class Icon",
                    desc = "Show a class icon on the player identity line.",
                    handler = Options,
                    get = "GetShowClassIcon",
                    set = "SetShowClassIcon",
                },
                classIconStyle = {
                    type = "select",
                    order = 4,
                    name = "Class Icon Style",
                    desc = "Use the global appearance class icon style or override it for tooltips.",
                    handler = Options,
                    get = "GetClassIconStyle",
                    set = "SetClassIconStyle",
                    values = {
                        global = "Global Appearance",
                        default = "Default",
                        fabled = "Fabled",
                        pixel = "Pixel",
                    },
                    disabled = function()
                        return not Options:GetShowClassIcon()
                    end,
                },
                headerFontSize = {
                    type = "range",
                    order = 5,
                    name = "Header Font Size",
                    min = 10,
                    max = 20,
                    step = 1,
                    handler = Options,
                    get = "GetHeaderFontSize",
                    set = "SetHeaderFontSize",
                },
                bodyFontSize = {
                    type = "range",
                    order = 6,
                    name = "Body Font Size",
                    min = 9,
                    max = 18,
                    step = 1,
                    handler = Options,
                    get = "GetBodyFontSize",
                    set = "SetBodyFontSize",
                },
                fadeIn = {
                    type = "toggle",
                    order = 7,
                    name = "Fade In",
                    desc = "Use a short cinematic fade when tooltips appear.",
                    handler = Options,
                    get = "GetEnableFadeIn",
                    set = "SetEnableFadeIn",
                },
                hideInCombat = {
                    type = "toggle",
                    order = 8,
                    name = "Hide In Combat",
                    desc = "Suppress managed tooltips during combat.",
                    handler = Options,
                    get = "GetHideInCombat",
                    set = "SetHideInCombat",
                },
            }),
            units = W.IGroup(30, "Unit Tooltips", {
                showHealthBar = {
                    type = "toggle",
                    order = 1,
                    name = "Show Health Bar",
                    desc = "Display and reskin the unit health bar on tooltips.",
                    handler = Options,
                    get = "GetShowHealthBar",
                    set = "SetShowHealthBar",
                },
                statusBarHeight = {
                    type = "range",
                    order = 2,
                    name = "Health Bar Height",
                    desc = "Height of the styled unit tooltip health bar.",
                    min = 5,
                    max = 16,
                    step = 1,
                    handler = Options,
                    get = "GetStatusBarHeight",
                    set = "SetStatusBarHeight",
                },
                playerDetails = {
                    type = "toggle",
                    order = 3,
                    name = "Show Player Details",
                    desc = "Append faction and available spec or class info to player tooltips.",
                    handler = Options,
                    get = "GetShowPlayerDetails",
                    set = "SetShowPlayerDetails",
                },
                faction = {
                    type = "toggle",
                    order = 4,
                    name = "Show Faction",
                    desc = "Show faction text on the player identity line.",
                    handler = Options,
                    get = "GetShowFaction",
                    set = "SetShowFaction",
                    disabled = function()
                        return not Options:GetShowPlayerDetails()
                    end,
                },
                factionIcon = {
                    type = "toggle",
                    order = 5,
                    name = "Show Faction Icon",
                    desc = "Show a faction icon on the player identity line.",
                    handler = Options,
                    get = "GetShowFactionIcon",
                    set = "SetShowFactionIcon",
                    disabled = function()
                        return not Options:GetShowPlayerDetails() or not Options:GetShowFaction()
                    end,
                },
                guildRank = {
                    type = "toggle",
                    order = 6,
                    name = "Show Guild Rank",
                    desc = "Append guild rank when available on player tooltips.",
                    handler = Options,
                    get = "GetShowGuildRank",
                    set = "SetShowGuildRank",
                    disabled = function()
                        return not Options:GetShowPlayerDetails()
                    end,
                },
                mythicScore = {
                    type = "toggle",
                    order = 7,
                    name = "Show Mythic+ Score",
                    desc = "Show the hovered player's current season Mythic+ rating when Blizzard provides it.",
                    handler = Options,
                    get = "GetShowMythicScore",
                    set = "SetShowMythicScore",
                    disabled = function()
                        return not Options:GetShowPlayerDetails()
                    end,
                },
                itemLevel = {
                    type = "toggle",
                    order = 8,
                    name = "Show Player Item Level",
                    desc = "Show your own item level in self tooltips.",
                    handler = Options,
                    get = "GetShowItemLevel",
                    set = "SetShowItemLevel",
                },
            }),
            items = W.IGroup(35, "Item Tooltips", {
                transmog = {
                    type = "toggle",
                    order = 1,
                    name = "Show Transmog Status",
                    desc = "Append appearance collection state to equippable item tooltips.",
                    handler = Options,
                    get = "GetShowTransmogStatus",
                    set = "SetShowTransmogStatus",
                },
                qualityBorder = {
                    type = "toggle",
                    order = 2,
                    name = "Use Item Quality Border",
                    desc = "Tint item tooltip borders by quality when item information is available.",
                    handler = Options,
                    get = "GetUseItemQualityBorder",
                    set = "SetUseItemQualityBorder",
                },
            }),
            anchor = W.IGroup(40, "Fixed Anchor", {
                lock = {
                    type = "toggle",
                    order = 1,
                    name = "Lock Anchor",
                    desc =
                    "Hide the live anchor badge when using fixed anchor mode. The anchor is still available through the Interface Designer.",
                    handler = Options,
                    get = "GetAnchorLocked",
                    set = "SetAnchorLocked",
                    disabled = function()
                        return Options:GetAnchorMode() ~= "fixed"
                    end,
                },
                reset = {
                    type = "execute",
                    order = 2,
                    name = "Reset Anchor Position",
                    desc = "Reset the fixed anchor to its default position.",
                    handler = Options,
                    func = "ResetAnchorPosition",
                    disabled = function()
                        return Options:GetAnchorMode() ~= "fixed"
                    end,
                },
                anchorInfo = {
                    type = "description",
                    order = 3,
                    name =
                    "Use the Interface Designer to drag the Tooltip Anchor in-world. Fixed mode makes the primary tooltip snap above that anchor.",
                },
            }),
            cursor = W.IGroup(50, "Cursor Mode", {
                cursorOffsetX = {
                    type = "range",
                    order = 1,
                    name = "Cursor Offset X",
                    min = -40,
                    max = 120,
                    step = 1,
                    handler = Options,
                    get = "GetCursorOffsetX",
                    set = "SetCursorOffsetX",
                    disabled = function()
                        return Options:GetAnchorMode() ~= "cursor"
                    end,
                },
                cursorOffsetY = {
                    type = "range",
                    order = 2,
                    name = "Cursor Offset Y",
                    min = -60,
                    max = 80,
                    step = 1,
                    handler = Options,
                    get = "GetCursorOffsetY",
                    set = "SetCursorOffsetY",
                    disabled = function()
                        return Options:GetAnchorMode() ~= "cursor"
                    end,
                },
            }),
            debug = W.IGroup(60, "Debug", {
                debugEnabled = {
                    type = "toggle",
                    order = 1,
                    name = "Enable Debug Capture",
                    desc = "Record tooltip debug events into the TwichUI debugger while you reproduce issues.",
                    handler = Options,
                    get = "GetDebugEnabled",
                    set = "SetDebugEnabled",
                },
                openDebugConsole = {
                    type = "execute",
                    order = 2,
                    name = "Open Tooltip Debugger",
                    desc = "Open the debugger directly on the tooltip source.",
                    handler = Options,
                    func = "OpenDebugConsole",
                },
                captureSnapshot = {
                    type = "execute",
                    order = 3,
                    name = "Capture Snapshot",
                    desc = "Emit a full tooltip state snapshot to the debugger so it can be copied and pasted.",
                    handler = Options,
                    func = "CaptureDebugSnapshot",
                },
            }),
        },
    }
end
