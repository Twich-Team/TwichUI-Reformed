---@diagnostic disable: undefined-field, undefined-global
--[[
    TwichUI chat styling.
    Keeps Blizzard chat behavior intact while replacing the visible chrome with a
    more intentional TwichUI presentation: owned frame shells, styled tabs,
    a modern edit box, and a compact hover-only control strip.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local CHAT_FRAMES = _G.CHAT_FRAMES
local CreateFrame = _G.CreateFrame
local DEFAULT_CHAT_FRAME = _G.DEFAULT_CHAT_FRAME
local FCF_Close = _G.FCF_Close
local FCF_DockFrame = _G.FCF_DockFrame
local FCF_OpenNewWindow = _G.FCF_OpenNewWindow
local FCF_OpenTemporaryWindow = _G.FCF_OpenTemporaryWindow
local FCF_SelectDockFrame = _G.FCF_SelectDockFrame
local FCF_SavePositionAndDimensions = _G.FCF_SavePositionAndDimensions
local FCF_UnDockFrame = _G.FCF_UnDockFrame
local LibStub = _G.LibStub
local GENERAL = _G.GENERAL
local LOCAL_DEFENSE = _G.LOCAL_DEFENSE
local LOOKING_FOR_GROUP = _G.LOOKING_FOR_GROUP
local NEWCOMER_CHAT = _G.NEWCOMER_CHAT
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local SERVICES = _G.SERVICES
local TRADE = _G.TRADE
local UIParent = _G.UIParent
local ChatEdit_GetChannelTarget = _G.ChatEdit_GetChannelTarget
local IsSecureCmd = _G.IsSecureCmd
local hasanysecretvalues = _G.hasanysecretvalues
local format = string.format
local date = _G.date
local hooksecurefunc = _G.hooksecurefunc
local ipairs = _G.ipairs
local max = math.max
local min = math.min
local pairs = _G.pairs
local select = _G.select
local sort = table.sort
local tostring = _G.tostring
local type = _G.type
local LSM = T.Libs and T.Libs.LSM or (LibStub and LibStub("LibSharedMedia-3.0", true))

---@type ChatEnhancementModule
local ChatEnhancementModule = T:GetModule("ChatEnhancements")

---@class ChatStylingModule : AceModule
---@field settings table
---@field frameHooksInstalled boolean
local ChatStylingModule = ChatEnhancementModule:NewModule("ChatStyling", "AceEvent-3.0", "AceTimer-3.0")

local PRIMARY_BORDER = { 0.10, 0.72, 0.74 }
local PRIMARY_FILL = { 0.04, 0.08, 0.10 }
local PRIMARY_FILL_ACTIVE = { 0.08, 0.11, 0.14 }
local GOLD_ACCENT = { 0.95, 0.76, 0.26 }
local TEXT_ACTIVE = { 1.0, 0.95, 0.86 }
local TEXT_INACTIVE = { 0.68, 0.73, 0.80 }
local EDIT_BOX_HISTORY_LIMIT = 50
local CHAT_HISTORY_DEBUG_TO_CHAT = false
local EDIT_BOX_HISTORY_HOOKED = setmetatable({}, { __mode = "k" })

local function DescribeHistoryText(text)
    if type(text) ~= "string" then
        return tostring(text)
    end

    local normalized = text:gsub("\r", " "):gsub("\n", " ")
    if normalized == "" then
        return "<empty>"
    end

    if #normalized > 72 then
        normalized = normalized:sub(1, 69) .. "..."
    end

    return normalized
end

local function IterateChatEditBoxes()
    local editBoxes = {}

    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local editBox = _G[tostring(frameName) .. "EditBox"]
        if editBox then
            editBoxes[#editBoxes + 1] = editBox
        end
    end

    return editBoxes
end

-- Height of one header datatext row (pixels).
-- The bar sits in the existing 26px header inset zone so viewport top is unchanged.
local HEADER_DATATEXT_BAR_HEIGHT = 22
-- Y offset from frame top-left to the top of the non-unified datatext bar.
-- DragHandle is shrunken to this height; bar fills the remaining zone.
local HEADER_DATATEXT_BAR_TOP    = 4
-- Width per slot in the unified (right-aligned, in-chrome) bar.
local HEADER_DATATEXT_SLOT_WIDTH = 68

local CHANNEL_REF_TO_KEY = {
    GUILD = "guild",
    OFFICER = "officer",
    PARTY = "party",
    PARTY_LEADER = "partyLeader",
    INSTANCE_CHAT = "instance",
    INSTANCE_CHAT_LEADER = "instanceLeader",
    RAID = "raid",
    RAID_LEADER = "raidLeader",
}

local CUSTOM_CHANNEL_MATCHERS = {
    general = { GENERAL, "General" },
    trade = { TRADE, "Trade" },
    localDefense = { LOCAL_DEFENSE, "LocalDefense" },
    lookingForGroup = { LOOKING_FOR_GROUP, "LookingForGroup" },
    services = { SERVICES, "Services" },
    newcomer = { NEWCOMER_CHAT, "NewcomerChat" },
}

local DEFAULT_CONTROL_BUTTONS = {
    "ChatFrameMenuButton",
    "ChatFrameChannelButton",
    "ChatFrameToggleVoiceMuteButton",
    "ChatFrameToggleVoiceDeafenButton",
    "QuickJoinToastButton",
    "FriendsMicroButton",
}

local CHANNEL_TYPE_TO_KEY = {
    CHANNEL = "general",
    EMOTE = "emote",
    GUILD = "guild",
    INSTANCE_CHAT = "instance",
    INSTANCE_CHAT_LEADER = "instanceLeader",
    OFFICER = "officer",
    PARTY = "party",
    RAID = "raid",
    RAID_WARNING = "raidLeader",
    SAY = "say",
    WHISPER = "whisper",
    YELL = "yell",
}

-- Persistent tab utility context menu (same pattern as chatContextMenu in ChatRenderer).
local chatTabMenu = nil
local function GetChatTabMenu()
    if not chatTabMenu then
        chatTabMenu = T.Tools.UI.CreateSecureMenu("TwichUIChatTabMenu")
    end
    return chatTabMenu
end

-- Plays a registered TwichUI UI sound.
-- "TwichUI-Menu-Click"    — subtle hover, open-menu, or navigation sounds.
-- "TwichUI-Menu-Confirm"  — confirmations, selections, and action completions.
local function PlayMenuSound(soundKey)
    local uiTools = T.Tools and T.Tools.UI or nil
    if uiTools and uiTools.PlayTwichSound then
        uiTools.PlayTwichSound(soundKey)
    end
end

local function NormalizeMatcher(value)
    if not value or value == "" then
        return nil
    end

    return tostring(value):lower()
end

local function EnsureBackdropSupport(frame)
    if not frame or (frame.SetBackdrop and frame.SetBackdropColor and frame.SetBackdropBorderColor) then
        return frame
    end

    frame.__twichuiBackdrop = frame.__twichuiBackdrop or {}

    if not frame.__twichuiBackdrop.bg then
        local bg = frame:CreateTexture(nil, "BACKGROUND")
        bg:SetAllPoints(frame)
        frame.__twichuiBackdrop.bg = bg
    end

    if not frame.__twichuiBackdrop.border then
        local border = frame:CreateTexture(nil, "BORDER")
        border:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
        border:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
        frame.__twichuiBackdrop.border = border
    end

    if not frame.SetBackdrop then
        frame.SetBackdrop = function(self)
            return self
        end
    end

    if not frame.SetBackdropColor then
        frame.SetBackdropColor = function(self, r, g, b, a)
            if self.__twichuiBackdrop and self.__twichuiBackdrop.bg then
                self.__twichuiBackdrop.bg:SetColorTexture(r or 0, g or 0, b or 0, a or 0)
            end
        end
    end

    if not frame.SetBackdropBorderColor then
        frame.SetBackdropBorderColor = function(self, r, g, b, a)
            if self.__twichuiBackdrop and self.__twichuiBackdrop.border then
                self.__twichuiBackdrop.border:SetColorTexture(r or 0, g or 0, b or 0, a or 0)
            end
        end
    end

    return frame
end

local function CreateBackdrop(frame)
    EnsureBackdropSupport(frame)
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
end

local function SetVerticalGradient(texture, topR, topG, topB, topA, bottomR, bottomG, bottomB, bottomA)
    if not texture then
        return
    end

    if texture.SetGradientAlpha then
        texture:SetGradientAlpha("VERTICAL", topR, topG, topB, topA, bottomR, bottomG, bottomB, bottomA)
    else
        texture:SetColorTexture(topR, topG, topB, math.max(topA, bottomA))
    end
end

local function HideTexture(texture)
    if not texture then
        return
    end

    if texture.Hide then
        texture:Hide()
    end
    if texture.SetAlpha then
        texture:SetAlpha(0)
    end
end

local function ShowTexture(texture)
    if not texture then
        return
    end

    if texture.SetAlpha then
        texture:SetAlpha(1)
    end
    if texture.Show then
        texture:Show()
    end
end

local function ApplyFont(fontString, size, r, g, b)
    if not fontString then
        return
    end

    if fontString.SetTextColor then
        fontString:SetTextColor(r, g, b)
    end
    if fontString.SetShadowOffset then
        fontString:SetShadowOffset(1, -1)
    end
    if fontString.SetShadowColor then
        fontString:SetShadowColor(0, 0, 0, 0.9)
    end
    if fontString.SetSpacing then
        fontString:SetSpacing(1)
    end
    if fontString.SetWordWrap then
        fontString:SetWordWrap(false)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(false)
    end
    if size and fontString.GetFont and fontString.SetFont then
        local path, _, flags = fontString:GetFont()
        if path then
            fontString:SetFont(path, size, flags)
        end
    end
end

local function ResolveFontPath(fontName)
    if LSM and fontName and LSM.Fetch then
        local ok, fontPath = pcall(LSM.Fetch, LSM, "font", fontName, true)
        if ok and fontPath then
            return fontPath
        end
    end

    return STANDARD_TEXT_FONT
end

local function ApplyResolvedFont(fontString, fontName, size, r, g, b, flags)
    if not fontString then
        return
    end

    local resolvedFont = ResolveFontPath(fontName) or STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
    fontString:SetFont(resolvedFont, size or 12, flags or "")
    ApplyFont(fontString, size, r, g, b)
end

local function StripMarkup(text)
    if type(text) ~= "string" then
        return ""
    end

    if type(hasanysecretvalues) == "function" then
        local ok, hasSecret = pcall(hasanysecretvalues, text)
        if ok and hasSecret then
            return ""
        end
    end

    if text == "" then
        return text
    end

    return tostring(text)
        :gsub("|T.-|t", "")
        :gsub("|c%x%x%x%x%x%x%x%x", "")
        :gsub("|r", "")
        :gsub("|A.-|a", "")
end

local function GetSafeDisplayText(text)
    if type(text) ~= "string" then
        return ""
    end

    if type(hasanysecretvalues) == "function" then
        local ok, hasSecret = pcall(hasanysecretvalues, text)
        if ok and hasSecret then
            return ""
        end
    end

    return text
end

local function EnsureFadeAnimations(frame)
    if not frame or frame.TwichUIFadeAnimations then
        return
    end

    local fadeIn = frame:CreateAnimationGroup()
    fadeIn:SetToFinalAlpha(true)
    local fadeInAlpha = fadeIn:CreateAnimation("Alpha")
    fadeInAlpha:SetFromAlpha(0)
    fadeInAlpha:SetToAlpha(1)
    fadeInAlpha:SetDuration(0.16)
    fadeInAlpha:SetOrder(1)
    fadeIn:SetScript("OnPlay", function()
        frame:Show()
    end)

    local fadeOut = frame:CreateAnimationGroup()
    fadeOut:SetToFinalAlpha(true)
    local fadeOutAlpha = fadeOut:CreateAnimation("Alpha")
    fadeOutAlpha:SetFromAlpha(1)
    fadeOutAlpha:SetToAlpha(0)
    fadeOutAlpha:SetDuration(0.12)
    fadeOutAlpha:SetOrder(1)
    fadeOut:SetScript("OnFinished", function()
        frame:Hide()
    end)

    frame.TwichUIFadeAnimations = {
        fadeIn = fadeIn,
        fadeOut = fadeOut,
    }
end

local function SetAnimatedVisibility(frame, visible, animate)
    if not frame then
        return
    end

    if not animate then
        frame:SetAlpha(visible and 1 or 0)
        frame:SetShown(visible)
        return
    end

    EnsureFadeAnimations(frame)
    local animations = frame.TwichUIFadeAnimations
    if not animations then
        frame:SetShown(visible)
        return
    end

    animations.fadeIn:Stop()
    animations.fadeOut:Stop()
    if visible then
        if not frame:IsShown() or frame:GetAlpha() < 1 then
            animations.fadeIn:Play()
        else
            frame:Show()
            frame:SetAlpha(1)
        end
    elseif frame:IsShown() then
        animations.fadeOut:Play()
    else
        frame:SetAlpha(0)
        frame:Hide()
    end
end

local function GetFrameFromTab(tab)
    if not tab or not tab.GetName then
        return nil
    end

    local name = tab:GetName()
    if not name then
        return nil
    end

    return _G[name:gsub("Tab$", "")]
end

local function IterateStyledChatFrames()
    local frames = {}
    local seen = {}

    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        if frame and not seen[frame] then
            seen[frame] = true
            frames[#frames + 1] = frame
        end
    end

    local combatLogFrame = _G.ChatFrame2
    if combatLogFrame and not seen[combatLogFrame] then
        frames[#frames + 1] = combatLogFrame
    end

    return frames
end

local function GetTabFromFrame(frame)
    if not frame or not frame.GetName then
        return nil
    end

    local name = frame:GetName()
    if not name then
        return nil
    end

    return _G[name .. "Tab"]
end

local function GetFrameDisplayText(frame)
    local tab = GetTabFromFrame(frame)
    local text = tab and tab.GetText and tab:GetText() or nil
    text = StripMarkup(text)
    if text and text ~= "" then
        return text
    end

    return frame.name or frame:GetName() or "Chat"
end

local function ResolveTab(tabOrFrame)
    if not tabOrFrame or not tabOrFrame.GetName then
        return nil
    end

    local name = tabOrFrame:GetName()
    if not name then
        return nil
    end

    if name:find("Tab$") then
        return tabOrFrame
    end

    return GetTabFromFrame(tabOrFrame)
end

local function IsFrameSelected(frame)
    return frame and _G.SELECTED_CHAT_FRAME == frame
end

local function HideNamedRegion(name)
    local region = name and _G[name] or nil
    if not region then
        return
    end

    if region.GetObjectType and region:GetObjectType() == "Texture" then
        HideTexture(region)
    else
        if region.Hide then
            region:Hide()
        end
        if region.SetAlpha then
            region:SetAlpha(0)
        end
    end
end

local function MeasureFontStringWidth(fontString)
    if not fontString then
        return 0
    end

    if fontString.GetUnboundedStringWidth then
        return fontString:GetUnboundedStringWidth() or 0
    end

    return fontString:GetStringWidth() or 0
end

function ChatStylingModule:GetOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.ChatEnhancement
end

function ChatStylingModule:RefreshSettings()
    local options = self:GetOptions()

    self.settings = {
        abbreviations = options:GetResolvedAbbreviations(),
        abbreviationsEnabled = options:AreAbbreviationsEnabled(),
        animationsEnabled = options:AreAnimationsEnabled(),
        chatFont = options:GetChatFont(),
        chatFontSize = options:GetChatFontSize(),
        channelColors = options:GetResolvedChannelColors(),
        controlButtons = {
            copy = options:IsControlButtonEnabled("copy"),
            menu = options:IsControlButtonEnabled("menu"),
            voice = options:IsControlButtonEnabled("voice"),
        },
        editBoxBgColor = options:GetResolvedEditBoxBgColor(),
        editBoxFont = options:GetEditBoxFont(),
        editBoxFontSize = options:GetEditBoxFontSize(),
        editBoxHeight = options:GetEditBoxHeight(),
        editBoxPaddingH = options:GetEditBoxPaddingH(),
        editBoxPaddingV = options:GetEditBoxPaddingV(),
        editBoxPosition = options:GetEditBoxPosition(),
        headerBgColor = options:GetResolvedHeaderBgColor(),
        hideHeader = options:IsHeaderHidden(),
        locked = options:IsChatLocked(),
        chatBgColor = options:GetResolvedChatBgColor(),
        chatBorderColor = options:GetResolvedChatBorderColor(),
        shellAccent = options:GetResolvedShellAccentColor(),
        showAccentBar = options:ShouldShowAccentBar(),
        showChromeAccent = options:IsChromeAccentShown(),
        tabAccentColor = options:GetResolvedTabAccentColor(),
        tabBgColor = options:GetResolvedTabBgColor(),
        tabBorderColor = options:GetResolvedTabBorderColor(),
        tabFont = options:GetTabFont(),
        tabFontSize = options:GetTabFontSize(),
        tabNameFade = options:IsTabNameFadeEnabled(),
        tabStyle = options:GetTabStyle(),
        whisperTabsEnabled = options:IsWhisperTabEnabled(),
        positionX = options:GetChatPositionX(),
        positionY = options:GetChatPositionY(),
        chatWidth = options:GetChatWidth(),
        chatHeight = options:GetChatHeight(),
        timestampFormat = options:GetTimestampFormat(),
        timestampsEnabled = options:AreTimestampsEnabled(),
        headerDatatext = options:GetHeaderDatatextSettings(),
    }
    self:RefreshCopyFrame()
end

--- Applies a saved X/Y position and optional size override to ChatFrame1.
--- Uses BOTTOMLEFT → UIParent BOTTOMLEFT so 0,0 = bottom-left of screen.
function ChatStylingModule:ApplyPositionOverride()
    local s = self.settings or {}
    local x, y = s.positionX, s.positionY
    local w, h = s.chatWidth, s.chatHeight
    local frame = _G.ChatFrame1
    if not frame then return end

    local hasPos  = type(x) == "number" and type(y) == "number"
    local hasSize = type(w) == "number" and type(h) == "number" and w > 50 and h > 50
    if not hasPos and not hasSize then return end

    -- SetUserPlaced / SetSize both require the frame to be movable/resizable.
    -- The lock state is applied by ApplyFrameChrome; temporarily lift it here
    -- so we can reposition / resize, then restore the original state.
    local wasMovable   = frame:IsMovable()
    local wasResizable = frame:IsResizable()
    frame:SetMovable(true)
    frame:SetResizable(true)

    if hasPos then
        frame:ClearAllPoints()
        frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
        frame:SetUserPlaced(true)
    end
    if hasSize then
        frame:SetSize(w, h)
    end

    -- Restore whatever movable / resizable state the chrome set.
    if not wasMovable   then frame:SetMovable(false)   end
    if not wasResizable then frame:SetResizable(false) end

    -- Do NOT call FCF_SavePositionAndDimensions here: doing so would snapshot
    -- the frame's position at lifecycle-timer time into Blizzard's own storage,
    -- potentially overwriting a more recent drag-stop position with a stale value.
end

--- Gets the current BOTTOMLEFT position of ChatFrame1 as x, y integers.
function ChatStylingModule:CaptureCurrentPosition()
    local frame = _G.ChatFrame1
    if not frame then return nil, nil end
    local pointType, _, _, x, y = frame:GetPoint(1)
    if not x then
        -- Attempt to derive BOTTOMLEFT from absolute screen position
        local cx = frame:GetLeft()
        local cy = frame:GetBottom()
        return cx and math.floor(cx + 0.5), cy and math.floor(cy + 0.5)
    end
    local sx = frame:GetLeft()
    local sy = frame:GetBottom()
    return sx and math.floor(sx + 0.5), sy and math.floor(sy + 0.5)
end

--- Returns the DataTextModule if it is loaded and enabled.
local function GetDataTextModule()
    return T:GetModule("Datatexts", true)
end

--- Ensures the embedded datatext bar frame exists for a given chat frame.
--- Positioning, strata and levels are handled entirely in ApplyChatHeaderDatatextBar.
--- @param frame Frame The chat frame (e.g. ChatFrame1).
function ChatStylingModule:EnsureChatHeaderDatatextBar(frame)
    if not frame then return nil end
    local frameName = frame:GetName() or tostring(frame)
    local barID = "chatHeader_" .. frameName
    local DataTextMod = GetDataTextModule()
    if not DataTextMod then return nil end

    local bar = DataTextMod:EnsureEmbeddedDatatextBar(frame, barID, 3)
    if not bar then return nil end

    frame.__twichuiHeaderDatatextBarID = barID
    bar:Hide()
    return bar
end

--- KEY LEVEL NOTES (WoW frame hierarchy for ChatFrame1):
---  - ChatFrame1:          default MEDIUM strata, level N
---  - renderer:            MEDIUM, N+10  (explicit in EnsureRenderer)
---  - renderer.Viewport:   MEDIUM, N+11  (child default = parent+1)
---  - renderer.Content:    MEDIUM, N+12
---  - message rows:        MEDIUM, N+13
---  - row textures/labels: MEDIUM, N+14
--- Therefore we need bar/slots at N+20/N+21 in non-unified (MEDIUM).
--- In unified the bar shares strata/level with ProxyTabBar (TOOLTIP, max N+30/120).
--- IMPORTANT: WoW does NOT propagate SetFrameLevel to existing children.
--- We must explicitly set every slot's level here on every refresh.
--- @param frame Frame The chat frame.
function ChatStylingModule:ApplyChatHeaderDatatextBar(frame)
    if not frame then return end
    if not frame.__twichuiHeaderDatatextBarID then
        self:EnsureChatHeaderDatatextBar(frame)
    end
    local barID = frame.__twichuiHeaderDatatextBarID
    if not barID then return end

    local DataTextMod = GetDataTextModule()
    if not DataTextMod then return end

    local hdt      = self.settings and self.settings.headerDatatext or nil
    local isUnified = self.settings and self.settings.tabStyle == "unified"
    local hideHeader = self.settings and self.settings.hideHeader or false

    -- Hide when the datatext bar is disabled.
    if not (hdt and hdt.enabled) then
        DataTextMod:HideEmbeddedBar(barID)
        return
    end

    local bar = DataTextMod.embeddedPanels and DataTextMod.embeddedPanels[barID]
    if not bar then return end

    local slotCount = math.max(1, math.min(3, tonumber(hdt.slotCount) or 1))
    local slotWidth = math.max(32, math.min(200, tonumber(hdt.slotWidth) or HEADER_DATATEXT_SLOT_WIDTH))
    local frameLevel = frame:GetFrameLevel()

    -- ── Position, strata and level ──────────────────────────────────────────
    if isUnified then
        -- Unified: right-aligned in the chrome area, same row as tabs.
        -- ProxyTabBar is TOOLTIP at max(frameLevel+30, 120); match that.
        local anchor   = frame.TwichUIChrome or frame
        local barWidth = slotCount * slotWidth + 8
        local barLevel = math.max(frameLevel + 30, 120)
        bar:ClearAllPoints()
        bar:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -12, -4)
        bar:SetWidth(barWidth)
        bar:SetHeight(28)   -- same height as ProxyTabBar
        bar:SetFrameStrata("TOOLTIP")
        bar:SetFrameLevel(barLevel)
        for i = 1, (bar.maxSlots or 3) do
            local slot = bar.slots and bar.slots[i]
            if slot then
                slot:SetFrameStrata("TOOLTIP")
                slot:SetFrameLevel(barLevel + 1)
            end
        end
    else
        -- Non-unified: occupies the 26px header inset zone at frame top.
        -- DragHandle is shrunken to HEADER_DATATEXT_BAR_TOP (4px) to stay clear.
        local barLevel = frameLevel + 20   -- safely above rows at frameLevel+13/14
        bar:ClearAllPoints()
        bar:SetPoint("TOPLEFT",  frame, "TOPLEFT",  4,  -HEADER_DATATEXT_BAR_TOP)
        bar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -HEADER_DATATEXT_BAR_TOP)
        -- Explicitly set the width so RefreshEmbeddedBar (which calls bar:GetWidth() immediately)
        -- receives a non-zero value even before WoW resolves the two-anchor layout pass.
        bar:SetWidth(math.max(1, (frame:GetWidth() or 400) - 8))
        bar:SetHeight(HEADER_DATATEXT_BAR_HEIGHT)
        bar:SetFrameStrata("MEDIUM")
        bar:SetFrameLevel(barLevel)
        for i = 1, (bar.maxSlots or 3) do
            local slot = bar.slots and bar.slots[i]
            if slot then
                slot:SetFrameStrata("MEDIUM")
                slot:SetFrameLevel(barLevel + 1)
            end
        end
    end

    bar:Show()

    -- ── Content / style ─────────────────────────────────────────────────────
    local slots = hdt.slots or {}
    local panelDefinition = {
        segments = slotCount,
        slot1 = slots[1] ~= "NONE" and slots[1] or nil,
        slot2 = slotCount >= 2 and (slots[2] ~= "NONE" and slots[2] or nil) or nil,
        slot3 = slotCount >= 3 and (slots[3] ~= "NONE" and slots[3] or nil) or nil,
    }
    local accentR, accentG, accentB = self:GetShellAccentColor()
    local hdtFontSize = hdt.fontSize or 11
    local textR, textG, textB = 0.92, 0.94, 0.96
    if hdt.useCustomTextColor and hdt.textColor then
        textR = hdt.textColor.r or textR
        textG = hdt.textColor.g or textG
        textB = hdt.textColor.b or textB
    end
    DataTextMod:RefreshEmbeddedBar(barID, panelDefinition, {
        font       = self.settings and self.settings.tabFont,
        fontSize   = hdtFontSize,
        accentR    = accentR,
        accentG    = accentG,
        accentB    = accentB,
        textR      = textR,
        textG      = textG,
        textB      = textB,
    })

    self:LogDebugf(false,
        "headerDT: frame=%s isUnified=%s frameLevel=%d rendererLevel=%d barLevel=%d slot1Level=%d",
        tostring(frame:GetName()),
        tostring(isUnified),
        frameLevel,
        (frame.TwichUICustomRenderer and frame.TwichUICustomRenderer:GetFrameLevel() or -1),
        bar:GetFrameLevel(),
        (bar.slots and bar.slots[1] and bar.slots[1]:GetFrameLevel() or -1))
end

function ChatStylingModule:GetShellAccentColor()
    local accent = self.settings and self.settings.shellAccent or nil
    if accent then
        return accent.r or GOLD_ACCENT[1], accent.g or GOLD_ACCENT[2], accent.b or GOLD_ACCENT[3]
    end

    return GOLD_ACCENT[1], GOLD_ACCENT[2], GOLD_ACCENT[3]
end

function ChatStylingModule:GetChannelColor(key)
    local colors = self.settings and self.settings.channelColors or nil
    local color = colors and colors[key] or nil
    if color then
        return color.r or 1, color.g or 1, color.b or 1
    end

    return self:GetShellAccentColor()
end

function ChatStylingModule:ResolveChannelKeyFromLabel(label)
    if not label or label == "" then
        return nil
    end

    local cleanLabel = NormalizeMatcher(StripMarkup(label)
        :gsub("^%d+%.%s*", "")
        :gsub("^%[", "")
        :gsub("%]$", "")
        :gsub(":.*$", "")
        :gsub("%-.*$", ""))
    if not cleanLabel then
        return nil
    end

    for key, matchers in pairs(CUSTOM_CHANNEL_MATCHERS) do
        for _, matcher in ipairs(matchers) do
            local normalizedMatcher = NormalizeMatcher(matcher)
            if normalizedMatcher and cleanLabel:find(normalizedMatcher, 1, true) then
                return key
            end
        end
    end

    if cleanLabel:find("whisper", 1, true) or cleanLabel:find("tell", 1, true) then
        return "whisper"
    end

    if cleanLabel == "say" or cleanLabel:find("^say$") then
        return "say"
    end

    if cleanLabel == "yell" or cleanLabel:find("^yell$") then
        return "yell"
    end

    if cleanLabel == "emote" or cleanLabel:find("^emote$") then
        return "emote"
    end

    if cleanLabel:find("party leader", 1, true) then
        return "partyLeader"
    end

    if cleanLabel:find("raid leader", 1, true) or cleanLabel:find("warning", 1, true) then
        return "raidLeader"
    end

    if cleanLabel:find("instance leader", 1, true) then
        return "instanceLeader"
    end

    if cleanLabel:find("party", 1, true) then
        return "party"
    end

    if cleanLabel:find("raid", 1, true) then
        return "raid"
    end

    if cleanLabel:find("guild", 1, true) then
        return "guild"
    end

    if cleanLabel:find("officer", 1, true) then
        return "officer"
    end

    return nil
end

function ChatStylingModule:ResolveChannelKeyFromChatType(chatType, channelTarget)
    if chatType == "CHANNEL" then
        return self:ResolveChannelKeyFromLabel(channelTarget)
    end

    return CHANNEL_TYPE_TO_KEY[chatType]
end

function ChatStylingModule:GetEditBoxAccentColor(editBox)
    local chatType = editBox and editBox.chatType or nil
    local channelTarget = editBox and (editBox.channelTarget or editBox.tellTarget) or nil
    local key = self:ResolveChannelKeyFromChatType(chatType, channelTarget)
    if not key and editBox then
        local headerText = editBox.header and editBox.header:GetText() or ""
        local suffixText = editBox.headerSuffix and editBox.headerSuffix:GetText() or ""
        key = self:ResolveChannelKeyFromLabel(headerText .. " " .. suffixText)
    end
    if key then
        return self:GetChannelColor(key)
    end

    return self:GetShellAccentColor()
end

function ChatStylingModule:GetDragTargetFrame(frame)
    if frame and frame.isDocked and _G.SELECTED_CHAT_FRAME then
        return _G.SELECTED_CHAT_FRAME
    end

    return frame
end

function ChatStylingModule:GetProxyOwnerFrame(frame)
    return frame
end

function ChatStylingModule:LogDebug(message, shouldShow)
    local rendererModule = ChatEnhancementModule:GetModule("ChatRenderer", true)
    if rendererModule and rendererModule.LogDebug then
        return rendererModule:LogDebug(message, shouldShow)
    end

    return false
end

function ChatStylingModule:LogDebugf(shouldShow, messageFormat, ...)
    local rendererModule = ChatEnhancementModule:GetModule("ChatRenderer", true)
    if rendererModule and rendererModule.LogDebugf then
        return rendererModule:LogDebugf(shouldShow, messageFormat, ...)
    end

    return false
end

function ChatStylingModule:LogHistoryDebugf(messageFormat, ...)
    local message = format(messageFormat, ...)
    self:LogDebug(message, false)

    if CHAT_HISTORY_DEBUG_TO_CHAT and DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff80dfff[TwichUI ChatDebug]|r " .. message)
    end
end

function ChatStylingModule:ForwardDragStart(frame)
    local targetFrame = self:GetDragTargetFrame(frame)

    -- Ensure the frame is movable before attempting to drag.
    if targetFrame and targetFrame.SetMovable then
        targetFrame:SetMovable(true)
    end
    if targetFrame and targetFrame.SetUserPlaced then
        targetFrame:SetUserPlaced(true)
    end

    self:LogDebugf(false, "drag start frame=%s isDocked=%s movable=%s pos=(%.0f,%.0f)",
        tostring(targetFrame and targetFrame:GetName() or "nil"),
        tostring(targetFrame and targetFrame.isDocked or false),
        tostring(targetFrame and targetFrame:IsMovable() or false),
        targetFrame and targetFrame:GetLeft() or 0,
        targetFrame and targetFrame:GetTop() or 0)

    if targetFrame and targetFrame.StartMoving then
        targetFrame:StartMoving()
    end
end

function ChatStylingModule:ForwardDragStop(frame)
    local targetFrame = self:GetDragTargetFrame(frame)

    if targetFrame and targetFrame.StopMovingOrSizing then
        targetFrame:StopMovingOrSizing()
        if targetFrame.SetUserPlaced then
            targetFrame:SetUserPlaced(true)
        end
        if type(FCF_SavePositionAndDimensions) == "function" then
            pcall(FCF_SavePositionAndDimensions, targetFrame)
        end
    end

    -- Auto-persist the new position directly into our DB so ApplyPositionOverride
    -- restores it correctly on the next reload (no "Capture Position" click required).
    if targetFrame == _G.ChatFrame1 then
        local opts = self:GetOptions()
        if opts then
            local x, y = self:CaptureCurrentPosition()
            if x and y then
                local db = opts:GetChatEnhancementDB()
                db.chatPositionX = x
                db.chatPositionY = y
                -- Keep cached settings in sync so any lifecycle refresh (UPDATE_CHAT_WINDOWS
                -- etc.) doesn't call ApplyPositionOverride with stale old values and
                -- overwrite the freshly dragged position.
                if self.settings then
                    self.settings.positionX = x
                    self.settings.positionY = y
                end
            end
        end
    end

    self:LogDebugf(false, "drag stop frame=%s pos=(%.0f,%.0f)",
        tostring(targetFrame and targetFrame:GetName() or "nil"),
        targetFrame and targetFrame:GetLeft() or 0,
        targetFrame and targetFrame:GetTop() or 0)
end

function ChatStylingModule:SelectChatFrame(targetFrame)
    if not targetFrame then
        return
    end

    local targetTab = GetTabFromFrame(targetFrame)
    _G.SELECTED_CHAT_FRAME = targetFrame

    -- Capture primary frame dimensions before Blizzard's FCF code potentially resizes it
    -- (FCFDock_SelectWindow restores each tab's saved size into the container frame).
    local primaryFrame = DEFAULT_CHAT_FRAME
    local savedW = primaryFrame and primaryFrame:GetWidth() or nil
    local savedH = primaryFrame and primaryFrame:GetHeight() or nil

    -- Pre-align the target frame's saved dimensions to the primary frame BEFORE WoW
    -- shows it.  FCF_SavePositionAndDimensions persists the size so that when Blizzard's
    -- own tab-click handler calls its internal restoration it reads OUR saved value,
    -- preventing the visible resize glitch.
    if targetFrame ~= primaryFrame and savedW and savedH then
        local tw = targetFrame.GetWidth and targetFrame:GetWidth() or savedW
        local th = targetFrame.GetHeight and targetFrame:GetHeight() or savedH
        if math.abs(tw - savedW) > 2 or math.abs(th - savedH) > 2 then
            targetFrame:SetSize(savedW, savedH)
            if type(FCF_SavePositionAndDimensions) == "function" then
                pcall(FCF_SavePositionAndDimensions, targetFrame)
            end
        end
    end

    if targetFrame.isDocked and type(FCFDock_SelectWindow) == "function" and _G.GENERAL_CHAT_DOCK then
        _G.FCFDock_SelectWindow(_G.GENERAL_CHAT_DOCK, targetFrame)
        if savedW and savedH then
            C_Timer.After(0.1, function()
                -- Restore primary frame size if WoW dock altered it.
                if primaryFrame then
                    local newW = primaryFrame:GetWidth()
                    local newH = primaryFrame:GetHeight()
                    self:LogDebugf(false, "resize check after select: saved=%.0fx%.0f current=%.0fx%.0f",
                        savedW, savedH, newW, newH)
                    if math.abs(newW - savedW) > 2 or math.abs(newH - savedH) > 2 then
                        primaryFrame:SetSize(savedW, savedH)
                    end
                end
                -- Also match targetFrame dimensions to primary.  WoW stores a per-tab
                -- "saved size" in the dock; when it shows ChatFrame2 it restores that
                -- saved size, which may differ from ChatFrame1's.  Force them to match
                -- so the visible frame never appears to resize on tab switch.
                if targetFrame and targetFrame ~= primaryFrame and targetFrame.GetWidth then
                    local tw, th = targetFrame:GetWidth(), targetFrame:GetHeight()
                    self:LogDebugf(false, "resize check target: target=%.0fx%.0f vs primary=%.0fx%.0f",
                        tw, th, savedW, savedH)
                    if math.abs(tw - savedW) > 2 or math.abs(th - savedH) > 2 then
                        targetFrame:SetSize(savedW, savedH)
                        if type(FCF_SavePositionAndDimensions) == "function" then
                            pcall(FCF_SavePositionAndDimensions, targetFrame)
                        end
                    end
                end
            end)
        end
    elseif targetFrame.isDocked and type(FCF_SelectDockFrame) == "function" then
        FCF_SelectDockFrame(targetFrame)
        if savedW and savedH and primaryFrame then
            C_Timer.After(0.1, function()
                local newW = primaryFrame:GetWidth()
                local newH = primaryFrame:GetHeight()
                self:LogDebugf(false, "resize check after selectDock: saved=%.0fx%.0f current=%.0fx%.0f",
                    savedW, savedH, newW, newH)
                if math.abs(newW - savedW) > 2 or math.abs(newH - savedH) > 2 then
                    primaryFrame:SetSize(savedW, savedH)
                end
            end)
        end
    else
        if targetFrame.Show then
            targetFrame:Show()
        end

        if targetTab and targetTab.GetScript then
            local onClick = targetTab:GetScript("OnClick")
            if type(onClick) == "function" then
                onClick(targetTab, "LeftButton")
            end
        end

        -- WoW's native tab onClick may call FCFDock_SelectWindow internally, which can
        -- restore a different saved frame size. Guard both the primary frame and the
        -- target frame with a post-click timer safety-net.
        if savedW and savedH then
            C_Timer.After(0.25, function()
                if primaryFrame then
                    local newW = primaryFrame:GetWidth()
                    local newH = primaryFrame:GetHeight()
                    self:LogDebugf(false, "resize check non-docked: saved=%.0fx%.0f current=%.0fx%.0f",
                        savedW, savedH, newW, newH)
                    if math.abs(newW - savedW) > 2 or math.abs(newH - savedH) > 2 then
                        primaryFrame:SetSize(savedW, savedH)
                    end
                end
                if targetFrame and targetFrame ~= primaryFrame and targetFrame.GetWidth then
                    local tw, th = targetFrame:GetWidth(), targetFrame:GetHeight()
                    self:LogDebugf(false, "resize check non-docked target: target=%.0fx%.0f vs primary=%.0fx%.0f",
                        tw, th, savedW, savedH)
                    if math.abs(tw - savedW) > 2 or math.abs(th - savedH) > 2 then
                        targetFrame:SetSize(savedW, savedH)
                        if type(FCF_SavePositionAndDimensions) == "function" then
                            pcall(FCF_SavePositionAndDimensions, targetFrame)
                        end
                    end
                end
            end)
        end
    end

    if targetFrame.ResetAllFadeTimes then
        targetFrame:ResetAllFadeTimes()
    end

    self:RefreshAllVisuals()
end

function ChatStylingModule:GetManagedChatFrame()
    local frame = _G.SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME
    if not frame or frame.isCombatLog then
        return DEFAULT_CHAT_FRAME
    end

    return frame
end

function ChatStylingModule:OpenTabContextMenu(frame)
    local targetFrame = frame or self:GetManagedChatFrame()
    local targetTab = GetTabFromFrame(targetFrame)
    if not targetTab or not targetTab.GetScript then
        return
    end

    local onClick = targetTab:GetScript("OnClick")
    if type(onClick) == "function" then
        onClick(targetTab, "RightButton")
    end
end

--- Toggles the voice chat panel using a robust fallback chain.
--- Tries the standard Blizzard API, then known frame names, then the mute button.
function ChatStylingModule:ToggleVoiceChat()
    -- Modern API (Dragonflight / Midnight).
    if type(_G.ToggleVoiceChatFrame) == "function" then
        local ok = pcall(_G.ToggleVoiceChatFrame)
        if ok then return end
    end
    -- Direct frame show/hide — different WoW builds use different names.
    for _, name in ipairs({ "VoiceChatFrame", "VoiceChatPromptFrame" }) do
        local vcf = _G[name]
        if vcf and type(vcf.IsShown) == "function" then
            if vcf:IsShown() then
                vcf:Hide()
            else
                vcf:Show()
            end
            return
        end
    end
    -- Last resort: delegate to the mute toggle button's click handler.
    local btn = _G.ChatFrameToggleVoiceMuteButton
    if btn and type(btn.GetScript) == "function" then
        local onClick = btn:GetScript("OnClick")
        if type(onClick) == "function" then
            pcall(onClick, btn, "LeftButton")
        end
    end
end

function ChatStylingModule:OpenFrameUtilityMenu(frame, anchor)
    local uiTools = T.Tools and T.Tools.UI or nil
    local targetFrame = frame or self:GetManagedChatFrame()
    if not targetFrame then
        self:OpenTabContextMenu(targetFrame)
        return
    end

    local menu = GetChatTabMenu()

    local entries = {
        {
            text = GetFrameDisplayText(targetFrame),
            isTitle = true,
        },
        {
            text = "Copy Chat Text",
            notCheckable = true,
            func = function()
                PlayMenuSound("TwichUI-Menu-Confirm")
                self:OpenCopyFrame(targetFrame)
            end,
        },
        {
            text = "Blizzard Configuration",
            notCheckable = true,
            func = function()
                PlayMenuSound("TwichUI-Menu-Confirm")
                self:OpenTabContextMenu(targetFrame)
            end,
        },
        {
            text = "Open Voice Chat",
            notCheckable = true,
            func = function()
                PlayMenuSound("TwichUI-Menu-Confirm")
                self:ToggleVoiceChat()
            end,
        },
        {
            text = "TwichUI Settings",
            notCheckable = true,
            func = function()
                PlayMenuSound("TwichUI-Menu-Confirm")
                local config = T:GetModule("Configuration", true)
                if config and type(config.ToggleOptionsUI) == "function" then
                    config:ToggleOptionsUI("Chat")
                end
            end,
        },
        {
            text = "New Tab",
            notCheckable = true,
            func = function()
                PlayMenuSound("TwichUI-Menu-Confirm")
                self:CreateChatWindow()
            end,
        },
        {
            text = "Close Tab",
            notCheckable = true,
            disabled = targetFrame == DEFAULT_CHAT_FRAME,
            func = function()
                PlayMenuSound("TwichUI-Menu-Confirm")
                self:CloseChatWindow(targetFrame)
            end,
        },
    }

    menu:SetEntries(entries)
    menu:Toggle(anchor or UIParent)
end

function ChatStylingModule:CreateChatWindow()
    if type(FCF_OpenNewWindow) ~= "function" then
        return
    end

    local frame = FCF_OpenNewWindow("Chat")
    if frame then
        self:HookChatFrame(frame)
        self:HandleLifecycleRefresh()
        self:SelectChatFrame(frame)
    end
end

function ChatStylingModule:CloseChatWindow(frame)
    local targetFrame = frame or self:GetManagedChatFrame()
    if not targetFrame or targetFrame == DEFAULT_CHAT_FRAME then
        return
    end

    if type(FCF_Close) == "function" then
        pcall(FCF_Close, targetFrame)
    else
        if type(FCF_UnDockFrame) == "function" then
            pcall(FCF_UnDockFrame, targetFrame)
        end
        if targetFrame.Hide then
            targetFrame:Hide()
        end
    end

    self:HandleLifecycleRefresh()
end

function ChatStylingModule:ApplyCombatLogChrome()
    local combatLogFrame = _G.ChatFrame2
    if not combatLogFrame or not self:IsEnabled() then
        return
    end

    local combatTab = GetTabFromFrame(combatLogFrame)
    if combatTab then
        self:EnsureTabChrome(combatTab)
        self:ApplyTabChrome(combatTab)
    end

    local quickButtons = _G.CombatLogQuickButtonFrame_Custom
    if quickButtons then
        quickButtons:SetParent(combatLogFrame)
        quickButtons:ClearAllPoints()
        quickButtons:SetPoint("TOPLEFT", combatLogFrame, "TOPLEFT", 2, -2)
        quickButtons:SetPoint("TOPRIGHT", combatLogFrame, "TOPRIGHT", -18, -2)
        quickButtons:SetFrameStrata("MEDIUM")
        quickButtons:SetFrameLevel(combatLogFrame:GetFrameLevel() + 6)
    end

    HideNamedRegion("CombatLogQuickButtonFrame_CustomTexture")
    HideNamedRegion("CombatLogQuickButtonFrame_CustomAdditionalFilterButton")
end

function ChatStylingModule:SuppressBlizzardDockArt(frame)
    if not self:IsEnabled() then
        return
    end

    local frameName = frame and frame.GetName and frame:GetName() or nil
    if frameName then
        HideNamedRegion(frameName .. "ButtonFrameUpButton")
        HideNamedRegion(frameName .. "ButtonFrameDownButton")
        HideNamedRegion(frameName .. "ButtonFrameBottomButton")
        HideNamedRegion(frameName .. "ButtonFrameMinimizeButton")
        HideNamedRegion(frameName .. "ButtonFrameBackground")
        HideNamedRegion(frameName .. "ButtonFrameTopButton")
        HideNamedRegion(frameName .. "Background")
        HideNamedRegion(frameName .. "BackgroundLeft")
        HideNamedRegion(frameName .. "BackgroundRight")
    end

    for _, name in ipairs({
        "GeneralDockManagerOverflowButton",
        "GeneralDockManagerScrollFrameLeft",
        "GeneralDockManagerScrollFrameMiddle",
        "GeneralDockManagerScrollFrameRight",
    }) do
        HideNamedRegion(name)
    end

    local dockManager = _G.GeneralDockManager or _G.GENERAL_CHAT_DOCK
    if dockManager and dockManager.GetRegions then
        for index = 1, select("#", dockManager:GetRegions()) do
            local region = select(index, dockManager:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                HideTexture(region)
            end
        end
    end

    if frame and frame.GetRegions then
        for index = 1, select("#", frame:GetRegions()) do
            local region = select(index, frame:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                HideTexture(region)
            end
        end
    end

    local buttonFrame = frameName and _G[frameName .. "ButtonFrame"] or nil
    if buttonFrame and buttonFrame.GetRegions then
        for index = 1, select("#", buttonFrame:GetRegions()) do
            local region = select(index, buttonFrame:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                HideTexture(region)
            end
        end
    end
end

function ChatStylingModule:ResolveCustomChannelAbbreviation(label)
    local settings = self.settings
    local cleanLabel = label:lower():gsub("^%d+%.%s*", "")

    for key, matchers in pairs(CUSTOM_CHANNEL_MATCHERS) do
        for _, matcher in ipairs(matchers) do
            local normalizedMatcher = NormalizeMatcher(matcher)
            if normalizedMatcher and cleanLabel:find(normalizedMatcher, 1, true) then
                return settings.abbreviations[key]
            end
        end
    end

    return label:match("^(%d+)%.")
end

function ChatStylingModule:ResolveChannelAbbreviation(channelRef, label)
    local settings = self.settings
    local mappedKey = CHANNEL_REF_TO_KEY[channelRef]

    if mappedKey then
        return settings.abbreviations[mappedKey]
    end

    if channelRef and channelRef:find("^channel:") then
        return self:ResolveCustomChannelAbbreviation(label)
    end

    return nil
end

function ChatStylingModule:ApplyChannelAbbreviations(message)
    return message:gsub("(|Hchannel:([^|]+)|h)%[(.-)%](|h)", function(prefix, channelRef, label, suffix)
        local abbreviation = self:ResolveChannelAbbreviation(channelRef, label)
        if not abbreviation or abbreviation == "" then
            return prefix .. "[" .. label .. "]" .. suffix
        end

        return prefix .. "[" .. abbreviation .. "]" .. suffix
    end)
end

function ChatStylingModule:BuildPrefix()
    local settings = self.settings
    local segments = {}
    local accentR, accentG, accentB = self:GetShellAccentColor()

    if settings.timestampsEnabled then
        segments[#segments + 1] = ("|cff93a6b0[%s]|r"):format(date(settings.timestampFormat))
    end

    if settings.showAccentBar then
        segments[#segments + 1] = ("|cff%02x%02x%02x||r"):format(math.floor(accentR * 255), math.floor(accentG * 255),
            math.floor(accentB * 255))
    end

    return table.concat(segments, " ")
end

function ChatStylingModule:FormatMessage(message)
    if type(message) ~= "string" or message == "" then
        return message
    end

    local formatted = message
    local settings = self.settings

    if settings.abbreviationsEnabled then
        formatted = self:ApplyChannelAbbreviations(formatted)
    end

    local prefix = self:BuildPrefix()
    if prefix == "" then
        return formatted
    end

    return prefix .. " " .. formatted
end

function ChatStylingModule:EnsureFrameChrome(frame)
    if not frame or frame.TwichUIChrome then
        return
    end

    local chrome = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TwichUIChrome = chrome
    chrome:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
    chrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 8, -8)
    chrome:SetFrameStrata(frame:GetFrameStrata())
    chrome:SetFrameLevel(math.max(0, frame:GetFrameLevel() - 1))
    chrome:EnableMouse(false)
    CreateBackdrop(chrome)

    chrome.Fill = chrome:CreateTexture(nil, "BACKGROUND")
    chrome.Fill:SetAllPoints(chrome)
    SetVerticalGradient(chrome.Fill, 0.05, 0.08, 0.11, 0.96, 0.02, 0.03, 0.05, 0.96)

    -- Separate header strip: covers the top drag region and can be independently colored.
    chrome.HeaderArea = chrome:CreateTexture(nil, "BACKGROUND", nil, 1)
    chrome.HeaderArea:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.HeaderArea:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -1, -1)
    chrome.HeaderArea:SetHeight(26)
    chrome.HeaderArea:SetColorTexture(0.06, 0.09, 0.12, 0.9)

    chrome.TopGlow = chrome:CreateTexture(nil, "ARTWORK")
    chrome.TopGlow:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.TopGlow:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -1, -1)
    chrome.TopGlow:SetHeight(18)
    SetVerticalGradient(chrome.TopGlow, PRIMARY_BORDER[1], PRIMARY_BORDER[2], PRIMARY_BORDER[3], 0.14, PRIMARY_BORDER[1],
        PRIMARY_BORDER[2], PRIMARY_BORDER[3], 0)

    chrome.BottomShade = chrome:CreateTexture(nil, "ARTWORK")
    chrome.BottomShade:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 1, 1)
    chrome.BottomShade:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -1, 1)
    chrome.BottomShade:SetHeight(22)
    SetVerticalGradient(chrome.BottomShade, 0, 0, 0, 0, GOLD_ACCENT[1], GOLD_ACCENT[2], GOLD_ACCENT[3], 0.08)

    chrome.LeftAccent = chrome:CreateTexture(nil, "BORDER")
    chrome.LeftAccent:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.LeftAccent:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 1, 1)
    chrome.LeftAccent:SetWidth(3)

    chrome.InnerGlow = chrome:CreateTexture(nil, "ARTWORK")
    chrome.InnerGlow:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.InnerGlow:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -1, 1)
    chrome.InnerGlow:SetColorTexture(PRIMARY_BORDER[1], PRIMARY_BORDER[2], PRIMARY_BORDER[3], 0.03)

    chrome.DragHint = chrome:CreateFontString(nil, "OVERLAY")
    chrome.DragHint:SetPoint("TOPRIGHT", chrome, "TOPRIGHT", -14, -8)
    ApplyResolvedFont(chrome.DragHint, self.settings and self.settings.tabFont, 10, TEXT_INACTIVE[1], TEXT_INACTIVE[2],
        TEXT_INACTIVE[3], "")
    chrome.DragHint:SetText("") -- text removed; header is the drag target

    -- Primary drag zone: the header strip inside the frame top (where the user sees the header).
    -- Parent to the frame, TOOLTIP strata so it sits above the renderer content but below strip buttons.
    chrome.DragHandle = CreateFrame("Frame", nil, frame)
    chrome.DragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, 0)
    chrome.DragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -40, 0)
    chrome.DragHandle:SetHeight(20)
    chrome.DragHandle:SetFrameStrata("TOOLTIP")
    chrome.DragHandle:SetFrameLevel(frame:GetFrameLevel() + 118)
    chrome.DragHandle:EnableMouse(true)
    chrome.DragHandle:SetMouseMotionEnabled(true)
    chrome.DragHandle:RegisterForDrag("LeftButton")
    chrome.DragHandle:SetScript("OnDragStart", function()
        ChatStylingModule:LogDebugf(false, "drag start frame=%s", tostring(frame:GetName()))
        ChatStylingModule:ForwardDragStart(frame)
    end)
    chrome.DragHandle:SetScript("OnDragStop", function()
        ChatStylingModule:LogDebugf(false, "drag stop frame=%s", tostring(frame:GetName()))
        ChatStylingModule:ForwardDragStop(frame)
    end)
    chrome.DragHandle:HookScript("OnEnter", function()
        ChatStylingModule:UpdateControlStripVisibility(frame, true)
    end)
    chrome.DragHandle:HookScript("OnLeave", function()
        ChatStylingModule:UpdateControlStripVisibility(frame, false)
    end)

    -- Secondary drag zone: the left accent bar (full height). Gives user a clear affordance.
    chrome.AccentDragHandle = CreateFrame("Frame", nil, frame)
    chrome.AccentDragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
    chrome.AccentDragHandle:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", -8, -8)
    chrome.AccentDragHandle:SetWidth(12)
    chrome.AccentDragHandle:SetFrameStrata("TOOLTIP")
    chrome.AccentDragHandle:SetFrameLevel(frame:GetFrameLevel() + 118)
    chrome.AccentDragHandle:EnableMouse(true)
    chrome.AccentDragHandle:SetMouseMotionEnabled(true)
    chrome.AccentDragHandle:RegisterForDrag("LeftButton")
    chrome.AccentDragHandle:SetScript("OnDragStart", function()
        ChatStylingModule:LogDebugf(false, "accent drag start frame=%s", tostring(frame:GetName()))
        ChatStylingModule:ForwardDragStart(frame)
    end)
    chrome.AccentDragHandle:SetScript("OnDragStop", function()
        ChatStylingModule:LogDebugf(false, "accent drag stop frame=%s", tostring(frame:GetName()))
        ChatStylingModule:ForwardDragStop(frame)
    end)

    chrome.ResizeHandle = CreateFrame("Button", nil, frame, "BackdropTemplate")
    chrome.ResizeHandle:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", 4, -4)
    chrome.ResizeHandle:SetSize(18, 18)
    chrome.ResizeHandle:SetFrameStrata("TOOLTIP")
    chrome.ResizeHandle:SetFrameLevel(frame:GetFrameLevel() + 120)
    chrome.ResizeHandle:EnableMouse(true)
    chrome.ResizeHandle:RegisterForDrag("LeftButton")
    CreateBackdrop(chrome.ResizeHandle)
    chrome.ResizeHandle:SetBackdropColor(0.03, 0.05, 0.07, 0.92)
    chrome.ResizeHandle:SetBackdropBorderColor(PRIMARY_BORDER[1], PRIMARY_BORDER[2], PRIMARY_BORDER[3], 0.18)
    chrome.ResizeHandle.Fill = chrome.ResizeHandle:CreateTexture(nil, "BACKGROUND")
    chrome.ResizeHandle.Fill:SetAllPoints(chrome.ResizeHandle)
    SetVerticalGradient(chrome.ResizeHandle.Fill, 0.08, 0.11, 0.14, 0.92, 0.03, 0.05, 0.07, 0.92)
    chrome.ResizeHandle.Mark = chrome.ResizeHandle:CreateFontString(nil, "OVERLAY")
    chrome.ResizeHandle.Mark:SetPoint("CENTER", chrome.ResizeHandle, "CENTER", 0, 0)
    ApplyResolvedFont(chrome.ResizeHandle.Mark, self.settings and self.settings.tabFont, 12, TEXT_ACTIVE[1],
        TEXT_ACTIVE[2],
        TEXT_ACTIVE[3], "")
    chrome.ResizeHandle.Mark:SetText("//")
    chrome.ResizeHandle:SetScript("OnDragStart", function()
        local targetFrame = ChatStylingModule:GetDragTargetFrame(frame)
        if targetFrame and targetFrame.StartSizing then
            ChatStylingModule:LogDebugf(false, "resize start frame=%s", tostring(targetFrame:GetName()))
            targetFrame:StartSizing("BOTTOMRIGHT")
        end
    end)
    chrome.ResizeHandle:SetScript("OnDragStop", function()
        local targetFrame = ChatStylingModule:GetDragTargetFrame(frame)
        if targetFrame and targetFrame.StopMovingOrSizing then
            targetFrame:StopMovingOrSizing()
            ChatStylingModule:LogDebugf(false, "resize stop frame=%s size=%.0fx%.0f", tostring(targetFrame:GetName()),
                targetFrame:GetWidth() or 0, targetFrame:GetHeight() or 0)
            -- Persist the new size via WoW's FCF system so it survives /reload.
            if type(FCF_SavePositionAndDimensions) == "function" then
                pcall(FCF_SavePositionAndDimensions, targetFrame)
            end
            -- Also store size in our own DB so ApplyPositionOverride can restore it.
            if targetFrame == _G.ChatFrame1 then
                local opts = ChatStylingModule:GetOptions()
                if opts then
                    local w = targetFrame:GetWidth()
                    local h = targetFrame:GetHeight()
                    local db = opts:GetChatEnhancementDB()
                    if w and w > 50 then
                        db.chatWidth = math.floor(w + 0.5)
                        if ChatStylingModule.settings then ChatStylingModule.settings.chatWidth = db.chatWidth end
                    end
                    if h and h > 50 then
                        db.chatHeight = math.floor(h + 0.5)
                        if ChatStylingModule.settings then ChatStylingModule.settings.chatHeight = db.chatHeight end
                    end
                end
            end
        end
    end)
end

function ChatStylingModule:ApplyFrameChrome(frame)
    if not frame or not frame.TwichUIChrome then
        return
    end

    local enabled = self:IsEnabled()
    if enabled then
        local accentR, accentG, accentB = self:GetShellAccentColor()
        local locked = self.settings and self.settings.locked or false
        local isUnified = self.settings and self.settings.tabStyle == "unified"

        -- Unified style: extend the chrome background upward to visually encompass the
        -- tab bar (which floats ~34px above the frame top) creating one solid panel.
        frame.TwichUIChrome:ClearAllPoints()
        if isUnified then
            frame.TwichUIChrome:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 42)
        else
            frame.TwichUIChrome:SetPoint("TOPLEFT", frame, "TOPLEFT", -8, 8)
        end
        frame.TwichUIChrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 8, -8)

        frame.TwichUIChrome:Show()
        -- Apply configurable background and border colors.
        local bg = self.settings and self.settings.chatBgColor or nil
        local bgR = bg and bg.r or 0.03
        local bgG = bg and bg.g or 0.04
        local bgB = bg and bg.b or 0.06
        local bgA = bg and bg.a or 0.9
        frame.TwichUIChrome:SetBackdropColor(bgR, bgG, bgB, bgA)
        if frame.TwichUIChrome.Fill then
            SetVerticalGradient(frame.TwichUIChrome.Fill,
                bgR * 1.5, bgG * 1.5, bgB * 1.5, bgA,
                bgR * 0.5, bgG * 0.5, bgB * 0.5, bgA)
        end
        local bd = self.settings and self.settings.chatBorderColor or nil
        local bdR = bd and bd.r or PRIMARY_BORDER[1]
        local bdG = bd and bd.g or PRIMARY_BORDER[2]
        local bdB = bd and bd.b or PRIMARY_BORDER[3]
        local bdA = bd and bd.a or 0.55
        frame.TwichUIChrome:SetBackdropBorderColor(bdR, bdG, bdB, bdA)
        local showChromeAccent = self.settings == nil or self.settings.showChromeAccent ~= false
        frame.TwichUIChrome.LeftAccent:SetColorTexture(accentR, accentG, accentB, showChromeAccent and 0.92 or 0)
        if frame.TwichUIChrome.DragHint then
            frame.TwichUIChrome.DragHint:SetTextColor(accentR, accentG, accentB)
        end
        SetVerticalGradient(frame.TwichUIChrome.BottomShade, 0, 0, 0, 0, accentR, accentG, accentB,
            showChromeAccent and 0.08 or 0)
        if frame.TwichUIChrome.ResizeHandle then
            frame.TwichUIChrome.ResizeHandle:SetBackdropBorderColor(accentR, accentG, accentB, 0.2)
            frame.TwichUIChrome.ResizeHandle:SetShown(not locked)
        end
        if frame.TwichUIChrome.AccentDragHandle then
            frame.TwichUIChrome.AccentDragHandle:SetShown(not locked)
        end
        if not locked then
            frame:SetMovable(true)
            frame:SetResizable(true)
        else
            frame:SetMovable(false)
            frame:SetResizable(false)
        end
        if frame.TwichUIChrome.HeaderArea then
            local hideHeader = self.settings and self.settings.hideHeader or false
            if hideHeader then
                frame.TwichUIChrome.HeaderArea:SetShown(false)
                if frame.TwichUIChrome.TopGlow then
                    frame.TwichUIChrome.TopGlow:SetShown(false)
                end
                if frame.TwichUIChrome.DragHandle then
                    frame.TwichUIChrome.DragHandle:SetShown(false)
                end
            else
                local hc = self.settings and self.settings.headerBgColor
                local hr = hc and hc.r or 0.06
                local hg = hc and hc.g or 0.09
                local hb = hc and hc.b or 0.12
                local ha = hc and hc.a ~= nil and hc.a or 0.9
                self:LogDebugf(false, "header color r=%.2f g=%.2f b=%.2f a=%.2f", hr, hg, hb, ha)
                frame.TwichUIChrome.HeaderArea:SetShown(true)
                frame.TwichUIChrome.HeaderArea:SetColorTexture(hr, hg, hb, ha)
                -- Extend header height when the header datatext bar is enabled,
                -- to ensure the header background covers the extra row.
                local headerDatatextEnabled = self.settings and self.settings.headerDatatext
                    and self.settings.headerDatatext.enabled
                local headerExtra = headerDatatextEnabled and (HEADER_DATATEXT_BAR_HEIGHT + 4) or 0
                -- In unified mode the header strip must cover the full extended chrome top
                -- (which now reaches behind the tab bar, ~50px total height).
                frame.TwichUIChrome.HeaderArea:SetHeight((isUnified and 60 or 26) + headerExtra)
                -- TopGlow is an ARTWORK-layer teal gradient that sits above HeaderArea.
                -- When the header background is fully transparent it becomes the only visible
                -- element in the header zone, so hide it together with the background.
                -- Also hide it when the user has disabled the chrome accent entirely.
                if frame.TwichUIChrome.TopGlow then
                    frame.TwichUIChrome.TopGlow:SetShown(showChromeAccent and ha > 0.01)
                end
                if frame.TwichUIChrome.DragHandle then
                    -- In non-unified with datatexts: shrink DragHandle to a 4px thin
                    -- strip so it doesn't intercept clicks on the datatext bar below.
                    -- In unified the datatexts live in the chrome above the frame, so
                    -- the DragHandle keeps its full 20px height.
                    local dragH = (headerDatatextEnabled and not isUnified) and 4 or 20
                    frame.TwichUIChrome.DragHandle:SetHeight(dragH)
                    frame.TwichUIChrome.DragHandle:SetShown(not locked)
                end
            end
        end
        -- Refresh the header datatext bar visibility and slot assignments.
        self:ApplyChatHeaderDatatextBar(frame)
    else
        frame.TwichUIChrome:Hide()
    end

    local buttonFrame = frame.GetName and _G[frame:GetName() .. "ButtonFrame"] or nil
    if buttonFrame then
        if enabled then
            buttonFrame:Hide()
        elseif not buttonFrame:IsShown() then
            buttonFrame:Show()
        end
    end

    if enabled then
        self:SuppressBlizzardDockArt(frame)
    end
end

function ChatStylingModule:EnsureEditBoxChrome()
    local editBox = _G.ChatFrame1EditBox
    if not editBox or editBox.TwichUIChrome then
        if editBox then
            self:EnsureEditBoxHistoryHooks(editBox)
        end
        return
    end

    local chrome = CreateFrame("Frame", nil, editBox, "BackdropTemplate")
    editBox.TwichUIChrome = chrome
    chrome:SetPoint("TOPLEFT", editBox, "TOPLEFT", -6, 4)
    chrome:SetPoint("BOTTOMRIGHT", editBox, "BOTTOMRIGHT", 6, -4)
    chrome:SetFrameLevel(math.max(0, editBox:GetFrameLevel() - 1))
    chrome:EnableMouse(false)
    CreateBackdrop(chrome)
    chrome:SetBackdropColor(0.04, 0.05, 0.07, 0.95)
    chrome:SetBackdropBorderColor(PRIMARY_BORDER[1], PRIMARY_BORDER[2], PRIMARY_BORDER[3], 0.24)

    chrome.LeftAccent = chrome:CreateTexture(nil, "BORDER")
    chrome.LeftAccent:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
    chrome.LeftAccent:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 1, 1)
    chrome.LeftAccent:SetWidth(3)
    chrome.LeftAccent:SetColorTexture(GOLD_ACCENT[1], GOLD_ACCENT[2], GOLD_ACCENT[3], 0.9)

    chrome.Fill = chrome:CreateTexture(nil, "BACKGROUND")
    chrome.Fill:SetAllPoints(chrome)
    SetVerticalGradient(chrome.Fill, 0.07, 0.10, 0.13, 0.35, 0.03, 0.04, 0.05, 0.1)

    local editBoxName = editBox:GetName()
    if editBoxName then
        HideTexture(_G[editBoxName .. "Left"])
        HideTexture(_G[editBoxName .. "Mid"])
        HideTexture(_G[editBoxName .. "Right"])
        HideTexture(_G[editBoxName .. "FocusLeft"])
        HideTexture(_G[editBoxName .. "FocusMid"])
        HideTexture(_G[editBoxName .. "FocusRight"])
    end

    if editBox.SetAltArrowKeyMode then
        editBox:SetAltArrowKeyMode(false)
    end

    self:EnsureEditBoxHistoryHooks(editBox)

    editBox:HookScript("OnShow", function(self)
        if self.TwichUIChrome and ChatStylingModule:IsEnabled() then
            self.TwichUIChrome:Show()
        end
        -- Re-apply position each time the edit box shows (Blizzard may have reset anchors).
        ChatStylingModule:ApplyEditBoxPosition()
    end)
    editBox:HookScript("OnHide", function(self)
        if self.TwichUIChrome then
            self.TwichUIChrome:Hide()
        end
    end)
    editBox:HookScript("OnTextChanged", function()
        ChatStylingModule:ApplyEditBoxChrome()
    end)
    editBox:HookScript("OnEditFocusGained", function()
        ChatStylingModule:ApplyEditBoxChrome()
    end)
    editBox:HookScript("OnEditFocusLost", function()
        ChatStylingModule:ApplyEditBoxChrome()
    end)

    -- Re-apply our custom position whenever the chat frame is repositioned/resized by WoW.
    local chatFrame = _G.ChatFrame1
    if chatFrame and not chatFrame.TwichUIEditBoxPositionHooked then
        chatFrame.TwichUIEditBoxPositionHooked = true
        chatFrame:HookScript("OnSizeChanged", function()
            ChatStylingModule:ApplyEditBoxPosition()
        end)
    end
end

function ChatStylingModule:EnsureEditBoxHistoryHooks(editBox)
    if not editBox then
        return
    end

    if editBox.SetAltArrowKeyMode then
        editBox:SetAltArrowKeyMode(false)
    end

    if editBox.SetHistoryLines then
        editBox:SetHistoryLines(EDIT_BOX_HISTORY_LIMIT)
    end

    if EDIT_BOX_HISTORY_HOOKED[editBox] then
        return
    end

    EDIT_BOX_HISTORY_HOOKED[editBox] = true

    self:LogHistoryDebugf("history hook attached box=%s", tostring(editBox.GetName and editBox:GetName() or "unknown"))

    if editBox.AddHistoryLine then
        hooksecurefunc(editBox, "AddHistoryLine", function(selfEditBox, text)
            ChatStylingModule:AddEditBoxHistoryLine(selfEditBox, text, "native")
        end)
    end
end

function ChatStylingModule:AddEditBoxHistoryLine(editBox, text, source)
    if not editBox or type(text) ~= "string" or not text:match("%S") then
        self:LogHistoryDebugf("chat history skip source=%s reason=empty box=%s",
            tostring(source or "unknown"), tostring(editBox and editBox.GetName and editBox:GetName() or "unknown"))
        return
    end

    local command = text:match("(/[^ ]+)")
    if command and IsSecureCmd and IsSecureCmd(command) then
        self:LogHistoryDebugf("chat history skip source=%s reason=secure command=%s box=%s",
            tostring(source or "unknown"), tostring(command),
            tostring(editBox.GetName and editBox:GetName() or "unknown"))
        return
    end

    self:LogHistoryDebugf("chat history store source=%s box=%s text=%s",
        tostring(source or "unknown"), tostring(editBox.GetName and editBox:GetName() or "unknown"),
        DescribeHistoryText(text))
end

function ChatStylingModule:ApplyEditBoxPosition()
    local editBox = _G.ChatFrame1EditBox
    if not editBox or not self:IsEnabled() then
        return
    end

    local s = self.settings or {}
    local pos = s.editBoxPosition or "below"
    local h = s.editBoxHeight or 28
    local chatFrame = _G.ChatFrame1
    if not chatFrame then
        return
    end

    editBox:SetHeight(h)

    if pos == "above" then
        editBox:ClearAllPoints()
        editBox:SetPoint("BOTTOMLEFT", chatFrame, "TOPLEFT", 0, 2)
        editBox:SetPoint("BOTTOMRIGHT", chatFrame, "TOPRIGHT", 0, 2)
    else
        -- "below" – let Blizzard control or restore default below-chat anchoring.
        editBox:ClearAllPoints()
        editBox:SetPoint("TOPLEFT", chatFrame, "BOTTOMLEFT", 0, -2)
        editBox:SetPoint("TOPRIGHT", chatFrame, "BOTTOMRIGHT", 0, -2)
    end
end

function ChatStylingModule:ApplyEditBoxChrome()
    local editBox = _G.ChatFrame1EditBox
    if not editBox or not editBox.TwichUIChrome then
        return
    end

    if self:IsEnabled() then
        local s = self.settings or {}
        local accentR, accentG, accentB = self:GetEditBoxAccentColor(editBox)
        local bg = s.editBoxBgColor or {}
        local bgR = bg.r or 0.04
        local bgG = bg.g or 0.05
        local bgB = bg.b or 0.07
        local bgA = bg.a ~= nil and bg.a or 0.95
        local pH = s.editBoxPaddingH or 10
        local pV = s.editBoxPaddingV or 2

        if editBox:IsShown() then
            editBox.TwichUIChrome:Show()
        end
        editBox.TwichUIChrome:SetBackdropColor(bgR, bgG, bgB, bgA)
        editBox.TwichUIChrome:SetBackdropBorderColor(accentR, accentG, accentB, 0.24)
        editBox.TwichUIChrome.LeftAccent:SetColorTexture(accentR, accentG, accentB, 0.9)
        if editBox.SetTextInsets then
            -- Account for the channel-type indicator ("Say:", "Guild:", etc.) that
            -- sits at the left edge of the edit box.  If we use a small fixed inset the
            -- typed text renders behind that label.  Measure the header string width
            -- (from the FontString WoW attaches to the edit box) and add it to the inset.
            local leftInset = pH
            local headerLabel = editBox.header
            if headerLabel and headerLabel.GetStringWidth then
                local hw = headerLabel:GetStringWidth()
                if hw and hw > 0 then
                    leftInset = math.max(pH, math.ceil(hw) + 14)
                end
            end
            editBox:SetTextInsets(leftInset, pH, pV, pV)
        end
        if editBox.header then
            -- Use the editbox font and size so the channel prefix matches the typed text.
            local ebFont = s.editBoxFont or s.chatFont
            local ebSize = (s.editBoxFontSize and s.editBoxFontSize > 0 and s.editBoxFontSize) or s.chatFontSize or 13
            ApplyResolvedFont(editBox.header, ebFont, ebSize,
                accentR, accentG, accentB, "")
        end
        if editBox.headerSuffix then
            local ebFont = s.editBoxFont or s.chatFont
            local ebSize = (s.editBoxFontSize and s.editBoxFontSize > 0 and s.editBoxFontSize) or s.chatFontSize or 13
            ApplyResolvedFont(editBox.headerSuffix, ebFont, ebSize,
                TEXT_ACTIVE[1], TEXT_ACTIVE[2], TEXT_ACTIVE[3], "")
        end
        self:ApplyChatFonts(DEFAULT_CHAT_FRAME)
        self:ApplyEditBoxPosition()
    else
        editBox.TwichUIChrome:Hide()
    end
end

function ChatStylingModule:EnsureCopyFrame()
    if self.CopyFrame then
        return self.CopyFrame
    end

    local accentR, accentG, accentB = self:GetShellAccentColor()
    local font = self.settings and self.settings.tabFont
    local fontSize = self.settings and self.settings.chatFontSize or 13

    local frame = CreateFrame("Frame", "TwichUIChatCopyFrame", UIParent, "BackdropTemplate")
    self.CopyFrame = frame
    frame:SetSize(760, 460)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", frame.StartMoving)
    frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
    CreateBackdrop(frame)
    frame:SetBackdropColor(0.03, 0.04, 0.06, 0.98)
    frame:SetBackdropBorderColor(accentR, accentG, accentB, 0.28)

    -- Main background gradient
    frame.Fill = frame:CreateTexture(nil, "BACKGROUND")
    frame.Fill:SetAllPoints(frame)
    SetVerticalGradient(frame.Fill, 0.05, 0.07, 0.10, 0.98, 0.02, 0.03, 0.05, 0.98)

    -- Left accent bar
    frame.LeftAccent = frame:CreateTexture(nil, "BORDER")
    frame.LeftAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.LeftAccent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.LeftAccent:SetWidth(3)
    frame.LeftAccent:SetColorTexture(accentR, accentG, accentB, 0.9)

    -- Title bar fill (header strip) — flat color, fully opaque so the gradient
    -- body background does not bleed through.
    local HEADER_H = 36
    frame.HeaderFill = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
    frame.HeaderFill:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.HeaderFill:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.HeaderFill:SetHeight(HEADER_H)
    frame.HeaderFill:SetColorTexture(0.06, 0.09, 0.13, 1.0)

    -- Title text
    frame.Title = frame:CreateFontString(nil, "OVERLAY")
    frame.Title:SetPoint("TOPLEFT", frame, "TOPLEFT", 18, -10)
    frame.Title:SetJustifyH("LEFT")
    ApplyResolvedFont(frame.Title, font, 14, TEXT_ACTIVE[1], TEXT_ACTIVE[2], TEXT_ACTIVE[3], "")
    frame.Title:SetText("Copy Chat Text")

    -- Subtitle / usage hint
    frame.SubTitle = frame:CreateFontString(nil, "OVERLAY")
    frame.SubTitle:SetPoint("LEFT", frame.Title, "RIGHT", 10, 0)
    ApplyResolvedFont(frame.SubTitle, font, 11,
        accentR * 0.8, accentG * 0.8, accentB * 0.8, "")
    frame.SubTitle:SetText("Ctrl+A to select all  ·  Ctrl+C to copy")

    -- Separator line below header
    frame.Separator = frame:CreateTexture(nil, "ARTWORK")
    frame.Separator:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -(HEADER_H + 1))
    frame.Separator:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -4, -(HEADER_H + 1))
    frame.Separator:SetHeight(1)
    frame.Separator:SetColorTexture(accentR, accentG, accentB, 0.30)

    -- Close button
    frame.Close = CreateFrame("Button", nil, frame, "BackdropTemplate")
    frame.Close:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -8)
    frame.Close:SetSize(72, 22)
    frame.Close:SetText("CLOSE")
    T.Tools.UI.SkinTwichButton(frame.Close, { accentR, accentG, accentB })
    if frame.Close.GetFontString and frame.Close:GetFontString() then
        ApplyResolvedFont(frame.Close:GetFontString(), font,
            max(11, fontSize - 1),
            TEXT_ACTIVE[1], TEXT_ACTIVE[2], TEXT_ACTIVE[3], "")
    end
    frame.Close:SetScript("OnClick", function()
        frame:Hide()
        local uiTools = T.Tools and T.Tools.UI or nil
        if uiTools and uiTools.PlayTwichSound then
            uiTools.PlayTwichSound("TwichUI-Menu-Confirm")
        end
    end)
    frame.Close:SetFrameLevel(frame:GetFrameLevel() + 4)

    -- Register with WoW's standard UISpecialFrames so ESC closes the window even
    -- when the copy edit box has lost focus.
    if _G.UISpecialFrames and not tContains(_G.UISpecialFrames, "TwichUIChatCopyFrame") then
        tinsert(_G.UISpecialFrames, "TwichUIChatCopyFrame")
    end

    -- Scroll background
    frame.ScrollBg = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.ScrollBg:SetPoint("TOPLEFT", frame, "TOPLEFT", 6, -(HEADER_H + 3))
    frame.ScrollBg:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    frame.ScrollBg:SetColorTexture(0.01, 0.02, 0.03, 0.60)

    -- Scrollbar chrome (right edge indicator)
    frame.ScrollBar = frame:CreateTexture(nil, "ARTWORK")
    frame.ScrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -6, -(HEADER_H + 3))
    frame.ScrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -6, 6)
    frame.ScrollBar:SetWidth(3)
    frame.ScrollBar:SetColorTexture(accentR, accentG, accentB, 0.22)

    -- Plain ScrollFrame — not InputScrollFrameTemplate, which creates its own internal
    -- EditBox. Setting a different scroll child on it orphans the internal EditBox and
    -- causes ScrollingEdit_OnUpdate to crash.
    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame)
    frame.ScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 16, -(HEADER_H + 3))
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -20, 8)

    frame.EditBox = CreateFrame("EditBox", nil, frame.ScrollFrame)
    frame.EditBox:SetMultiLine(true)
    frame.EditBox:SetAutoFocus(false)
    frame.EditBox:SetWidth(716)
    frame.EditBox:SetFont(ResolveFontPath(font), fontSize, "")
    frame.EditBox:SetTextInsets(4, 4, 4, 4)
    frame.EditBox:SetTextColor(TEXT_ACTIVE[1], TEXT_ACTIVE[2], TEXT_ACTIVE[3])
    frame.EditBox:SetScript("OnEscapePressed", function()
        frame:Hide()
    end)
    frame.ScrollFrame:SetScrollChild(frame.EditBox)
    frame:Hide()

    return frame
end

function ChatStylingModule:GetCopyText(frame)
    local renderer = frame and frame.TwichUICustomRenderer or nil
    if renderer and renderer.entries then
        local lines = {}
        for _, entry in ipairs(renderer.entries) do
            local stamp = self.settings and self.settings.timestampsEnabled and
                date(self.settings.timestampFormat, entry.timestamp) or nil
            local text = StripMarkup(entry.text or entry.message or "")
            if text ~= "" then
                if stamp then
                    lines[#lines + 1] = ("[%s] %s"):format(stamp, text)
                else
                    lines[#lines + 1] = text
                end
            end
        end
        return table.concat(lines, "\n")
    end

    if frame and type(frame.GetNumMessages) == "function" and type(frame.GetMessageInfo) == "function" then
        local lines = {}
        for index = 1, frame:GetNumMessages() do
            local text = frame:GetMessageInfo(index)
            if text then
                lines[#lines + 1] = StripMarkup(text)
            end
        end
        return table.concat(lines, "\n")
    end

    return ""
end

function ChatStylingModule:RefreshCopyFrame()
    local frame = self.CopyFrame
    if not frame then return end
    local accentR, accentG, accentB = self:GetShellAccentColor()
    local font = self.settings and self.settings.tabFont
    local fontSize = self.settings and self.settings.chatFontSize or 13

    frame:SetBackdropBorderColor(accentR, accentG, accentB, 0.28)
    if frame.LeftAccent then frame.LeftAccent:SetColorTexture(accentR, accentG, accentB, 0.9) end
    if frame.Separator then frame.Separator:SetColorTexture(accentR, accentG, accentB, 0.30) end
    if frame.ScrollBar then frame.ScrollBar:SetColorTexture(accentR, accentG, accentB, 0.22) end
    if frame.SubTitle then
        ApplyResolvedFont(frame.SubTitle, font, 11,
            accentR * 0.8, accentG * 0.8, accentB * 0.8, "")
    end
    if frame.Close and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
        T.Tools.UI.SkinTwichButton(frame.Close, { accentR, accentG, accentB })
        if frame.Close.GetFontString and frame.Close:GetFontString() then
            ApplyResolvedFont(frame.Close:GetFontString(), font,
                max(11, fontSize - 1),
                TEXT_ACTIVE[1], TEXT_ACTIVE[2], TEXT_ACTIVE[3], "")
        end
    end
    if frame.EditBox then
        frame.EditBox:SetFont(ResolveFontPath(font), fontSize, "")
    end
end

function ChatStylingModule:OpenCopyFrame(frame)
    local copyFrame = self:EnsureCopyFrame()
    self:RefreshCopyFrame()
    local text = GetSafeDisplayText(self:GetCopyText(frame or _G.SELECTED_CHAT_FRAME or DEFAULT_CHAT_FRAME))
    copyFrame.EditBox:SetText(text)
    copyFrame.EditBox:HighlightText()
    copyFrame:Show()
    copyFrame.EditBox:SetFocus()
    PlayMenuSound("TwichUI-Menu-Click")
end

--- Opens the copy frame pre-filled with an arbitrary raw text string.
--- Focus is deferred by one tick so any calling menu's close/hide cycle
--- completes before we claim focus, preventing it being immediately stolen.
function ChatStylingModule:ShowRawTextCopyFrame(text)
    local copyFrame = self:EnsureCopyFrame()
    self:RefreshCopyFrame()
    copyFrame.EditBox:SetText(GetSafeDisplayText(text))
    copyFrame.EditBox:HighlightText()
    copyFrame:Show()
    -- Defer focus so menu teardown can't steal it back.
    C_Timer.After(0.05, function()
        if copyFrame:IsShown() then
            copyFrame.EditBox:SetFocus()
            copyFrame.EditBox:HighlightText()
        end
    end)
end

function ChatStylingModule:GetFramesForProxyBar(frame)
    if frame and frame.isDocked then
        local frames = {}
        for _, frameName in ipairs(CHAT_FRAMES or {}) do
            local candidate = _G[frameName]
            local tab = candidate and GetTabFromFrame(candidate) or nil
            if candidate and tab and candidate.isDocked then
                frames[#frames + 1] = candidate
            end
        end

        sort(frames, function(leftFrame, rightFrame)
            local leftTab = GetTabFromFrame(leftFrame)
            local rightTab = GetTabFromFrame(rightFrame)
            local leftPos = leftTab and leftTab.GetLeft and leftTab:GetLeft() or 0
            local rightPos = rightTab and rightTab.GetLeft and rightTab:GetLeft() or 0
            return leftPos < rightPos
        end)

        if #frames > 0 then
            return frames
        end
    end

    return { frame }
end

function ChatStylingModule:EnsureProxyTabButton(bar, index)
    bar.buttons = bar.buttons or {}
    if bar.buttons[index] then
        return bar.buttons[index]
    end

    local button = CreateFrame("Button", nil, bar, "BackdropTemplate")
    bar.buttons[index] = button
    button:SetHeight(28)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetScale(1)
    button:SetFrameStrata("TOOLTIP")
    button:SetFrameLevel((bar:GetFrameLevel() or 0) + 2)
    CreateBackdrop(button)
    button:SetBackdropColor(0.03, 0.05, 0.07, 0.95)
    button:SetBackdropBorderColor(PRIMARY_BORDER[1], PRIMARY_BORDER[2], PRIMARY_BORDER[3], 0.18)

    button.Fill = button:CreateTexture(nil, "BACKGROUND")
    button.Fill:SetAllPoints(button)

    button.Highlight = button:CreateTexture(nil, "ARTWORK")
    button.Highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
    button.Highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.Highlight:SetColorTexture(PRIMARY_BORDER[1], PRIMARY_BORDER[2], PRIMARY_BORDER[3], 0)

    button.Accent = button:CreateTexture(nil, "BORDER")
    button.Accent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
    button.Accent:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
    button.Accent:SetHeight(2)

    button.Alert = button:CreateTexture(nil, "ARTWORK")
    button.Alert:SetPoint("RIGHT", button, "RIGHT", -10, 0)
    button.Alert:SetSize(5, 5)
    do
        local accentR, accentG, accentB = self:GetShellAccentColor()
        button.Alert:SetColorTexture(accentR, accentG, accentB, 0.95)
    end

    button.Label = button:CreateFontString(nil, "OVERLAY")
    button.Label:SetPoint("LEFT", button, "LEFT", 12, 0)
    button.Label:SetPoint("RIGHT", button, "RIGHT", -20, 0)
    button.Label:SetJustifyH("LEFT")
    button.Label:SetMaxLines(1)
    ApplyResolvedFont(button.Label, self.settings and self.settings.tabFont,
        self.settings and self.settings.tabFontSize or 12,
        TEXT_INACTIVE[1], TEXT_INACTIVE[2], TEXT_INACTIVE[3], "")

    -- HoverIn: glow highlight fade-in + 3px upward lift
    button.HoverIn = button:CreateAnimationGroup()
    local hoverIn = button.HoverIn:CreateAnimation("Alpha")
    hoverIn:SetChildKey("Highlight")
    hoverIn:SetFromAlpha(0)
    hoverIn:SetToAlpha(0.22)
    hoverIn:SetDuration(0.2)
    hoverIn:SetOrder(1)
    local hoverInLift = button.HoverIn:CreateAnimation("Translation")
    hoverInLift:SetOffset(0, 3)
    hoverInLift:SetDuration(0.2)
    hoverInLift:SetSmoothing("OUT")
    hoverInLift:SetOrder(1)

    -- HoverOut: reverse the lift and fade
    button.HoverOut = button:CreateAnimationGroup()
    local hoverOut = button.HoverOut:CreateAnimation("Alpha")
    hoverOut:SetChildKey("Highlight")
    hoverOut:SetFromAlpha(0.22)
    hoverOut:SetToAlpha(0)
    hoverOut:SetDuration(0.18)
    hoverOut:SetOrder(1)
    local hoverOutLift = button.HoverOut:CreateAnimation("Translation")
    hoverOutLift:SetOffset(0, -3)
    hoverOutLift:SetDuration(0.18)
    hoverOutLift:SetSmoothing("IN")
    hoverOutLift:SetOrder(1)

    -- BreatheIn: uniform pop (scale X and Y equally — no shake)
    button.BreatheIn = button:CreateAnimationGroup()
    local breatheScaleIn = button.BreatheIn:CreateAnimation("Scale")
    breatheScaleIn:SetScale(1.04, 1.04)
    breatheScaleIn:SetDuration(0.18)
    breatheScaleIn:SetSmoothing("OUT")
    breatheScaleIn:SetOrder(1)

    button.BreatheOut = button:CreateAnimationGroup()
    local breatheScaleOut = button.BreatheOut:CreateAnimation("Scale")
    breatheScaleOut:SetScale(0.96, 0.96)
    breatheScaleOut:SetDuration(0.14)
    breatheScaleOut:SetSmoothing("IN")
    breatheScaleOut:SetOrder(1)

    button:SetScript("OnEnter", function(selfButton)
        ChatStylingModule:UpdateProxyTabButton(selfButton, true)
    end)
    button:SetScript("OnLeave", function(selfButton)
        ChatStylingModule:UpdateProxyTabButton(selfButton, false)
    end)
    button:SetScript("OnClick", function(selfButton, mouseButton)
        if not selfButton.chatFrameTarget then
            return
        end

        if mouseButton == "RightButton" then
            PlayMenuSound("TwichUI-Menu-Click")
            ChatStylingModule:OpenFrameUtilityMenu(selfButton.chatFrameTarget, selfButton)
            return
        end

        PlayMenuSound("TwichUI-Menu-Confirm")
        ChatStylingModule:LogDebugf(false, "tab click target=%s docked=%s",
            tostring(selfButton.chatFrameTarget:GetName()),
            tostring(selfButton.chatFrameTarget.isDocked == true))
        ChatStylingModule:SelectChatFrame(selfButton.chatFrameTarget)
    end)
    button:SetScript("OnDragStart", function(selfButton)
        if selfButton.chatFrameTarget then
            ChatStylingModule:ForwardDragStart(selfButton.chatFrameTarget)
        end
    end)
    button:SetScript("OnDragStop", function(selfButton)
        if selfButton.chatFrameTarget then
            ChatStylingModule:ForwardDragStop(selfButton.chatFrameTarget)
        end
    end)

    return button
end

function ChatStylingModule:UpdateProxyTabButton(button, hovered)
    if not button then
        return
    end

    local settings = self.settings or {}
    local selected = button.chatFrameTarget and IsFrameSelected(button.chatFrameTarget)
    local flashing = button.chatFrameTarget and button.chatFrameTarget.hasActiveChanges
    local fontSize = settings.tabFontSize or 12
    local accentR, accentG, accentB = self:GetShellAccentColor()
    ApplyResolvedFont(button.Label, settings.tabFont, fontSize, selected and TEXT_ACTIVE[1] or TEXT_INACTIVE[1],
        selected and TEXT_ACTIVE[2] or TEXT_INACTIVE[2], selected and TEXT_ACTIVE[3] or TEXT_INACTIVE[3], "")

    local isTransparent = settings.tabStyle == "transparent" or settings.tabStyle == "unified"
    local tabBg  = settings.tabBgColor     or {}
    local tabBr  = settings.tabBorderColor or {}
    local tabAc  = settings.tabAccentColor or {}
    local bgR = tabBg.r or PRIMARY_FILL[1]
    local bgG = tabBg.g or PRIMARY_FILL[2]
    local bgB = tabBg.b or PRIMARY_FILL[3]
    local brR = tabBr.r or PRIMARY_BORDER[1]
    local brG = tabBr.g or PRIMARY_BORDER[2]
    local brB = tabBr.b or PRIMARY_BORDER[3]
    local acR = tabAc.r or brR
    local acG = tabAc.g or brG
    local acB = tabAc.b or brB

    if isTransparent then
        -- Transparent mode: no background fill, just text and accent underline.
        button:SetBackdropColor(0, 0, 0, 0)
        button:SetBackdropBorderColor(0, 0, 0, 0)
        button.Fill:SetColorTexture(0, 0, 0, 0)
        button.Highlight:SetAlpha(0)
        button:SetScale(1)
        if settings.animationsEnabled then
            button.HoverIn:Stop()
            button.HoverOut:Stop()
            button.BreatheIn:Stop()
            button.BreatheOut:Stop()
        end
        if selected then
            button.Accent:SetColorTexture(acR, acG, acB, 1)
        elseif hovered then
            button.Accent:SetColorTexture(acR, acG, acB, 0.65)
        else
            button.Accent:SetColorTexture(acR, acG, acB, 0.22)
        end
    elseif selected then
        button:SetBackdropColor(math.min(1, bgR * 2.7), math.min(1, bgG * 2.7), math.min(1, bgB * 2.7), 0.98)
        button:SetBackdropBorderColor(brR, brG, brB, 0.42)
        SetVerticalGradient(button.Fill,
            math.min(1, bgR * 3.3), math.min(1, bgG * 3.3), math.min(1, bgB * 3.3), 0.92,
            bgR, bgG, bgB, 0.92)
        button.Accent:SetColorTexture(acR, acG, acB, 1)
        button.Highlight:SetAlpha(0.22)
        button:SetScale(1.03)
    elseif hovered then
        button:SetBackdropColor(math.min(1, bgR * 1.3), math.min(1, bgG * 1.3), math.min(1, bgB * 1.3), 0.96)
        button:SetBackdropBorderColor(brR, brG, brB, 0.26)
        SetVerticalGradient(button.Fill,
            math.min(1, bgR * 1.75), math.min(1, bgG * 1.75), math.min(1, bgB * 1.75), 0.88,
            bgR * 0.75, bgG * 0.75, bgB * 0.75, 0.88)
        button.Accent:SetColorTexture(brR, brG, brB, 0.88)
        if settings.animationsEnabled then
            button.HoverOut:Stop()
            button.HoverIn:Play()
            button.BreatheOut:Stop()
            button.BreatheIn:Play()
        else
            button.Highlight:SetAlpha(0.22)
            button:SetScale(1.04)
        end
    else
        button:SetBackdropColor(bgR, bgG, bgB, 0.92)
        button:SetBackdropBorderColor(brR, brG, brB, 0.12)
        SetVerticalGradient(button.Fill,
            math.min(1, bgR * 1.3), math.min(1, bgG * 1.3), math.min(1, bgB * 1.3), 0.84,
            bgR * 0.6, bgG * 0.6, bgB * 0.6, 0.84)
        button.Accent:SetColorTexture(brR, brG, brB, 0.32)
        if settings.animationsEnabled then
            button.HoverIn:Stop()
            button.HoverOut:Play()
            button.BreatheIn:Stop()
            button.BreatheOut:Play()
        else
            button.Highlight:SetAlpha(0)
            button:SetScale(1)
        end
    end

    button.Alert:SetShown(not selected and flashing or false)

    -- Tab name fade: dim the label text when the tab is not active or hovered.
    local labelAlpha = (selected or hovered) and 1.0 or (settings.tabNameFade and 0.45 or 1.0)
    button.Label:SetAlpha(labelAlpha)
end

function ChatStylingModule:EnsureProxyTabBar(frame)
    if not frame then
        return
    end

    if frame.TwichUIProxyTabBar then
        return
    end

    local anchor = frame.TwichUIChrome or frame
    local bar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TwichUIProxyTabBar = bar
    bar:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 12, -2)
    bar:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -12, -2)
    bar:SetHeight(32)
    bar:SetFrameStrata("TOOLTIP")
    bar:SetFrameLevel(math.max(frame:GetFrameLevel() + 30, 120))
    bar:EnableMouse(true)
    bar:RegisterForDrag("LeftButton")
    bar:SetScript("OnDragStart", function(selfBar)
        ChatStylingModule:ForwardDragStart(selfBar:GetParent())
    end)
    bar:SetScript("OnDragStop", function(selfBar)
        ChatStylingModule:ForwardDragStop(selfBar:GetParent())
    end)
    bar.buttons = {}
end

function ChatStylingModule:RefreshProxyTabBar(frame)
    local owner = self:GetProxyOwnerFrame(frame)

    if not owner then
        return
    end

    self:EnsureProxyTabBar(owner)
    local bar = owner.TwichUIProxyTabBar
    if not bar then
        return
    end

    do
        local anchor   = owner.TwichUIChrome or owner
        local isUnified = self.settings and self.settings.tabStyle == "unified"
        local hdt      = isUnified and self.settings and self.settings.headerDatatext or nil
        local hdtEnabled = hdt and hdt.enabled
        bar:ClearAllPoints()
        if isUnified then
            -- Unified: chrome extends 42px above frame; tabs inside chrome top.
            -- When datatexts are active, leave the right side for the datatext bar.
            bar:SetPoint("TOPLEFT", anchor, "TOPLEFT", 12, -4)
            if hdtEnabled then
                local slotCount = math.max(1, math.min(3, tonumber(hdt.slotCount) or 1))
                local slotWidth = math.max(32, math.min(200, tonumber(hdt.slotWidth) or HEADER_DATATEXT_SLOT_WIDTH))
                local dtBarWidth = slotCount * slotWidth + 8
                bar:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -(12 + dtBarWidth + 4), -4)
            else
                bar:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", -12, -4)
            end
        else
            -- Normal: tabs float just above the chrome top edge.
            bar:SetPoint("BOTTOMLEFT",  anchor, "TOPLEFT",  12, -2)
            bar:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", -12, -2)
        end
    end

    self:LogDebugf(false, "proxy refresh frame=%s owner=%s selected=%s", tostring(frame and frame:GetName() or "nil"),
        tostring(owner:GetName()), tostring(_G.SELECTED_CHAT_FRAME and _G.SELECTED_CHAT_FRAME:GetName() or "nil"))

    if not self:IsEnabled() then
        bar:Hide()
        return
    end

    local frames = self:GetFramesForProxyBar(owner)
    local availableWidth = max(140, owner:GetWidth() - 24)
    local gap = 6
    local totalDesiredWidth = 0
    local count = #frames

    for index, targetFrame in ipairs(frames) do
        local button = self:EnsureProxyTabButton(bar, index)
        button.chatFrameTarget = targetFrame
        ApplyResolvedFont(button.Label, self.settings.tabFont, self.settings.tabFontSize, TEXT_INACTIVE[1],
            TEXT_INACTIVE[2],
            TEXT_INACTIVE[3], "")
        button.Label:SetText(GetFrameDisplayText(targetFrame))
        button.desiredWidth = min(240, max(72, MeasureFontStringWidth(button.Label) + 32))
        totalDesiredWidth = totalDesiredWidth + button.desiredWidth
    end

    totalDesiredWidth = totalDesiredWidth + max(0, count - 1) * gap
    local compressedWidth = nil
    if totalDesiredWidth > availableWidth and count > 0 then
        compressedWidth = max(74, (availableWidth - ((count - 1) * gap)) / count)
    end

    local previous = nil
    for index, targetFrame in ipairs(frames) do
        local button = self:EnsureProxyTabButton(bar, index)
        button.chatFrameTarget = targetFrame
        button:ClearAllPoints()
        button:SetWidth(compressedWidth and min(button.desiredWidth, compressedWidth) or button.desiredWidth)
        if previous then
            button:SetPoint("LEFT", previous, "RIGHT", gap, 0)
        else
            button:SetPoint("LEFT", bar, "LEFT", 0, 0)
        end
        previous = button
        button:Show()
        self:UpdateProxyTabButton(button, button:IsMouseOver())
    end

    for index = count + 1, #(bar.buttons or {}) do
        local button = bar.buttons[index]
        if button then
            button:Hide()
            button.chatFrameTarget = nil
        end
    end

    SetAnimatedVisibility(bar, true, self.settings.animationsEnabled)
end

function ChatStylingModule:UpdateControlStripVisibility(frame, forceVisible)
    local strip = frame and frame.TwichUIControlStrip or nil
    if not strip then
        return
    end

    if not self:IsEnabled() then
        strip:Hide()
        return
    end

    -- The custom renderer covers the entire chat frame with EnableMouse(true), so the
    -- frame's own OnEnter never fires. Use IsMouseOver() position checks for robustness.
    -- Also include the DragHandle: it sits just above the renderer bounds and physically
    -- overlaps the top of the control strip, so hovering there should keep the strip up.
    local renderer = frame.TwichUICustomRenderer
    local dragHandle = frame.TwichUIChrome and frame.TwichUIChrome.DragHandle or nil
    local shouldShow = forceVisible
        or frame:IsMouseOver()
        or strip:IsMouseOver()
        or (renderer and renderer:IsMouseOver())
        or (renderer and renderer.Viewport and renderer.Viewport:IsMouseOver())
        or (dragHandle and dragHandle:IsMouseOver())
    SetAnimatedVisibility(strip, shouldShow, self.settings.animationsEnabled)
end

function ChatStylingModule:EnsureTabChrome(tabOrFrame)
    local tab = ResolveTab(tabOrFrame)
    if not tab or tab.TwichUITabSuppressed then
        return
    end

    tab.TwichUITabSuppressed = true
    local name = tab:GetName()
    if name then
        tab.TwichUIDefaultTextures = {
            _G[name .. "Left"],
            _G[name .. "Middle"],
            _G[name .. "Right"],
            _G[name .. "SelectedLeft"],
            _G[name .. "SelectedMiddle"],
            _G[name .. "SelectedRight"],
            _G[name .. "HighlightLeft"],
            _G[name .. "HighlightMiddle"],
            _G[name .. "HighlightRight"],
            _G[name .. "Glow"],
        }
    else
        tab.TwichUIDefaultTextures = {}
    end

    if tab.GetRegions then
        for index = 1, select("#", tab:GetRegions()) do
            local region = select(index, tab:GetRegions())
            if region and region.GetObjectType and region:GetObjectType() == "Texture" then
                tab.TwichUIDefaultTextures[#tab.TwichUIDefaultTextures + 1] = region
            end
        end
    end

    tab:HookScript("OnShow", function(selfTab)
        ChatStylingModule:ApplyTabChrome(selfTab)
    end)
end

function ChatStylingModule:ApplyTabChrome(tabOrFrame)
    local tab = ResolveTab(tabOrFrame)
    if not tab then
        return
    end

    self:EnsureTabChrome(tab)
    local enabled = self:IsEnabled()
    local fontString = tab.GetFontString and tab:GetFontString() or nil
    local frame = GetFrameFromTab(tab)

    for _, texture in ipairs(tab.TwichUIDefaultTextures or {}) do
        if enabled then
            HideTexture(texture)
        else
            ShowTexture(texture)
        end
    end

    if fontString and fontString.SetAlpha then
        fontString:SetAlpha(enabled and 0 or 1)
    end

    if tab.EnableMouse then
        tab:EnableMouse(not enabled)
    end
    tab:SetScale(1)
    tab:SetAlpha(enabled and 0 or 1)
    if enabled and tab.GetHighlightTexture then
        HideTexture(tab:GetHighlightTexture())
    end

    if frame then
        self:RefreshProxyTabBar(frame)
    end
end

function ChatStylingModule:EnsureControlStrip(frame)
    if not frame or frame.TwichUIControlStrip or frame.isCombatLog then
        return
    end

    local strip = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TwichUIControlStrip = strip
    strip:SetPoint("BOTTOMRIGHT", frame.TwichUIChrome or frame, "TOPRIGHT", -12, -28)
    strip:SetHeight(24)
    strip:SetFrameStrata("TOOLTIP")
    -- Must be above the DragHandle (frame:GetFrameLevel() + 120) so strip buttons are
    -- always clickable even in the zone where the handle and strip overlap.
    strip:SetFrameLevel(math.max(frame:GetFrameLevel() + 125, 135))
    strip:EnableMouse(true)
    strip:SetAlpha(1)
    strip.buttons = {}
    CreateBackdrop(strip)
    strip:SetBackdropColor(0.03, 0.05, 0.07, 0.92)
    strip:SetBackdropBorderColor(PRIMARY_BORDER[1], PRIMARY_BORDER[2], PRIMARY_BORDER[3], 0.16)

    strip.Fill = strip:CreateTexture(nil, "BACKGROUND")
    strip.Fill:SetAllPoints(strip)
    SetVerticalGradient(strip.Fill, 0.05, 0.07, 0.10, 0.94, 0.02, 0.03, 0.05, 0.94)

    local function CreateProxyButton(parent, text, color, onClick)
        local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
        button:SetHeight(20)
        button:SetText(text)
        button:SetNormalFontObject("GameFontHighlightSmall")
        button:SetFrameStrata("TOOLTIP")
        button:SetFrameLevel(parent:GetFrameLevel() + 2)

        if button.GetFontString then
            local fontString = button:GetFontString()
            ApplyResolvedFont(fontString, ChatStylingModule.settings.tabFont,
                max(10, (ChatStylingModule.settings.tabFontSize or 12) - 2),
                TEXT_ACTIVE[1], TEXT_ACTIVE[2], TEXT_ACTIVE[3], "")
        end

        T.Tools.UI.SkinTwichButton(button, color)
        button:SetScript("OnClick", onClick)
        return button
    end

    strip.buttons.voice = CreateProxyButton(strip, "VOICE", { 0.26, 0.84, 0.98 }, function()
        PlayMenuSound("TwichUI-Menu-Confirm")
        ChatStylingModule:ToggleVoiceChat()
    end)

    strip.buttons.copy = CreateProxyButton(strip, "COPY", { 0.42, 0.89, 0.63 }, function()
        PlayMenuSound("TwichUI-Menu-Confirm")
        ChatStylingModule:OpenCopyFrame(frame)
    end)

    -- Context-menu button: right-click on hover strip opens the utility menu.
    strip.buttons.menu = CreateProxyButton(strip, "MENU", { 0.98, 0.76, 0.24 }, function()
        PlayMenuSound("TwichUI-Menu-Click")
        ChatStylingModule:OpenFrameUtilityMenu(frame, strip.buttons.menu)
    end)

    frame:HookScript("OnEnter", function(selfFrame)
        ChatStylingModule:RefreshControlStrip(selfFrame)
        ChatStylingModule:UpdateControlStripVisibility(selfFrame, true)
    end)

    frame:HookScript("OnLeave", function(selfFrame)
        ChatStylingModule:UpdateControlStripVisibility(selfFrame, false)
    end)

    strip:HookScript("OnEnter", function()
        ChatStylingModule:UpdateControlStripVisibility(frame, true)
    end)
    strip:HookScript("OnLeave", function(selfStrip)
        ChatStylingModule:UpdateControlStripVisibility(frame, false)
    end)
end

function ChatStylingModule:RefreshControlStrip(frame)
    local strip = frame and frame.TwichUIControlStrip or nil
    if not strip then
        return
    end

    if not self:IsEnabled() then
        strip:Hide()
        return
    end

    local visibleButtons = {}

    if self.settings.controlButtons.voice then
        visibleButtons[#visibleButtons + 1] = strip.buttons.voice
    end
    if self.settings.controlButtons.copy then
        visibleButtons[#visibleButtons + 1] = strip.buttons.copy
    end
    if self.settings.controlButtons.menu then
        visibleButtons[#visibleButtons + 1] = strip.buttons.menu
    end

    for _, button in pairs(strip.buttons or {}) do
        button:Hide()
    end

    local width = 0
    local previous = nil
    for _, button in ipairs(visibleButtons) do
        if button then
            local label = button.GetText and button:GetText() or ""
            local buttonWidth = max(42, 16 + (#label * 7))
            button:SetWidth(buttonWidth)
            button:ClearAllPoints()
            if previous then
                button:SetPoint("LEFT", previous, "RIGHT", 4, 0)
            else
                button:SetPoint("LEFT", strip, "LEFT", 2, 0)
            end
            previous = button
            width = width + buttonWidth + 4
            button:Show()
        end
    end

    strip:SetWidth(max(0, width))
    self:UpdateControlStripVisibility(frame, false)
end

function ChatStylingModule:ApplyDefaultButtonSuppression()
    for _, buttonName in ipairs(DEFAULT_CONTROL_BUTTONS) do
        local button = _G[buttonName]
        if button then
            if not button.TwichUIChatHooked then
                button.TwichUIChatHooked = true
                button:HookScript("OnShow", function(self)
                    if ChatStylingModule:IsEnabled() then
                        self:Hide()
                    end
                end)
            end

            if self:IsEnabled() then
                button:Hide()
            elseif not button:IsShown() then
                button:Show()
            end
        end
    end
end

function ChatStylingModule:ApplyChatFonts(frame)
    if not frame or not self:IsEnabled() then
        return
    end

    local s = self.settings or {}
    local fontPath = ResolveFontPath(s.chatFont)
    if frame.SetFont then
        pcall(frame.SetFont, frame, fontPath, s.chatFontSize or 13, "")
    end

    if frame == DEFAULT_CHAT_FRAME then
        local editBox = _G.ChatFrame1EditBox
        -- Resolve edit-box font independently from the chat font when overridden.
        local ebFontPath = s.editBoxFont and ResolveFontPath(s.editBoxFont) or fontPath
        local ebFontSize = (s.editBoxFontSize and s.editBoxFontSize > 0) and s.editBoxFontSize or (s.chatFontSize or 13)
        if editBox and editBox.SetFont then
            editBox:SetFont(ebFontPath, ebFontSize, "")
        end
        if editBox and editBox.header then
            local accentR, accentG, accentB = self:GetEditBoxAccentColor(editBox)
            local ebFont = s.editBoxFont or s.chatFont
            local ebSize = (s.editBoxFontSize and s.editBoxFontSize > 0 and s.editBoxFontSize) or s.chatFontSize or 13
            ApplyResolvedFont(editBox.header, ebFont, ebSize,
                accentR, accentG, accentB, "")
        end
        if editBox and editBox.headerSuffix then
            local ebFont = s.editBoxFont or s.chatFont
            local ebSize = (s.editBoxFontSize and s.editBoxFontSize > 0 and s.editBoxFontSize) or s.chatFontSize or 13
            ApplyResolvedFont(editBox.headerSuffix, ebFont, ebSize,
                TEXT_ACTIVE[1], TEXT_ACTIVE[2], TEXT_ACTIVE[3], "")
        end
    end

    local chatRendererModule = ChatEnhancementModule:GetModule("ChatRenderer", true)
    if chatRendererModule and chatRendererModule.IsEnabled and chatRendererModule:IsEnabled() then
        chatRendererModule:RefreshFrame(frame)
    end
end

function ChatStylingModule:HookChatFrame(frame)
    if not frame or frame.TwichUIChatStylingHooked or type(frame.AddMessage) ~= "function" then
        return
    end

    frame.TwichUIChatStylingHooked = true
    frame:SetMovable(true)
    frame:SetResizable(true)
    frame:SetClampedToScreen(false)  -- allow placing flush against the monitor edge
    -- Do not mark every chat frame as user-placed here. Temporary windows such as
    -- whisper tabs can inherit this flag and later trigger Blizzard restore errors
    -- during display-size changes when they are no longer movable/resizable.
    if frame.isTemporary and frame.SetUserPlaced then
        frame:SetUserPlaced(false)
    end
    if frame.SetMinResize then
        frame:SetMinResize(260, 120)
    end
    local originalAddMessage = frame.AddMessage

    frame.AddMessage = function(chatFrame, message, ...)
        local chatRendererModule = ChatEnhancementModule:GetModule("ChatRenderer", true)
        local useCustomRenderer = chatRendererModule and chatRendererModule.IsEnabled and chatRendererModule:IsEnabled()
            and chatRendererModule:IsFrameOwned(chatFrame)

        if ChatStylingModule:IsEnabled() and not useCustomRenderer then
            message = ChatStylingModule:FormatMessage(message)
        end

        return originalAddMessage(chatFrame, message, ...)
    end

    self:EnsureFrameChrome(frame)
    self:ApplyFrameChrome(frame)
    self:ApplyChatFonts(frame)

    local tab = frame.GetName and _G[frame:GetName() .. "Tab"] or nil
    if tab then
        self:EnsureTabChrome(tab)
        self:ApplyTabChrome(tab)
    end

    if not frame.isCombatLog then
        self:EnsureProxyTabBar(frame)
        self:RefreshProxyTabBar(frame)
    end

    if not frame.isCombatLog then
        self:EnsureControlStrip(frame)
        self:RefreshControlStrip(frame)
    end

    if frame == DEFAULT_CHAT_FRAME then
        self:EnsureEditBoxChrome()
        self:ApplyEditBoxChrome()
    end

    frame:HookScript("OnShow", function(selfFrame)
        ChatStylingModule:ApplyFrameChrome(selfFrame)
        ChatStylingModule:ApplyChatFonts(selfFrame)
        local selfTab = selfFrame.GetName and _G[selfFrame:GetName() .. "Tab"] or nil
        if selfTab then
            ChatStylingModule:ApplyTabChrome(selfTab)
        end
        if not selfFrame.isCombatLog then
            ChatStylingModule:RefreshProxyTabBar(selfFrame)
        end
        if not selfFrame.isCombatLog then
            ChatStylingModule:RefreshControlStrip(selfFrame)
        end
        if selfFrame == DEFAULT_CHAT_FRAME then
            ChatStylingModule:ApplyEditBoxChrome()
        end
    end)

    frame:HookScript("OnSizeChanged", function(selfFrame)
        if not selfFrame.isCombatLog then
            ChatStylingModule:RefreshProxyTabBar(selfFrame)
            ChatStylingModule:RefreshControlStrip(selfFrame)
        end
    end)
end

function ChatStylingModule:HookAllChatFrames()
    for _, frame in ipairs(IterateStyledChatFrames()) do
        self:HookChatFrame(frame)
    end

    self:HookAllChatEditBoxes()
end

function ChatStylingModule:HookAllChatEditBoxes()
    for _, editBox in ipairs(IterateChatEditBoxes()) do
        self:EnsureEditBoxHistoryHooks(editBox)
    end
end

function ChatStylingModule:RefreshAllVisuals()
    for _, frame in ipairs(IterateStyledChatFrames()) do
        if frame then
            self:EnsureFrameChrome(frame)
            self:ApplyFrameChrome(frame)
            self:ApplyChatFonts(frame)

            local tab = frame.GetName and _G[frame:GetName() .. "Tab"] or nil
            if tab then
                self:EnsureTabChrome(tab)
                self:ApplyTabChrome(tab)
            end

            if not frame.isCombatLog then
                self:EnsureProxyTabBar(frame)
                self:RefreshProxyTabBar(frame)
            end

            if not frame.isCombatLog then
                self:EnsureControlStrip(frame)
                self:RefreshControlStrip(frame)
            end

            if frame == DEFAULT_CHAT_FRAME then
                self:EnsureEditBoxChrome()
                self:ApplyEditBoxChrome()
            end
        end
    end

    self:HookAllChatEditBoxes()
    self:ApplyCombatLogChrome()
    self:ApplyDefaultButtonSuppression()
end

function ChatStylingModule:QueueRefreshAllVisuals(delay)
    if self.refreshAllTimer then
        self:CancelTimer(self.refreshAllTimer)
        self.refreshAllTimer = nil
    end

    local refreshDelay = delay or 0
    if refreshDelay <= 0 then
        self:RefreshAllVisuals()
        return
    end

    self.refreshAllTimer = self:ScheduleTimer(function()
        self.refreshAllTimer = nil
        self:RefreshAllVisuals()
    end, refreshDelay)
end

function ChatStylingModule:CancelLifecycleRefreshes()
    if not self.lifecycleRefreshTimers then
        return
    end

    for index, timerHandle in ipairs(self.lifecycleRefreshTimers) do
        if timerHandle then
            self:CancelTimer(timerHandle)
        end
        self.lifecycleRefreshTimers[index] = nil
    end
end

function ChatStylingModule:HandleLifecycleRefresh()
    self:CancelLifecycleRefreshes()
    self:RefreshAllVisuals()
    self.lifecycleRefreshTimers = {
        self:ScheduleTimer(function()
            ChatStylingModule:RefreshAllVisuals()
            ChatStylingModule:ApplyPositionOverride()
        end, 0.1),
        self:ScheduleTimer(function()
            ChatStylingModule:RefreshAllVisuals()
            ChatStylingModule:ApplyPositionOverride()
        end, 0.35),
    }
end

function ChatStylingModule:InstallFrameHooks()
    if self.frameHooksInstalled then
        return
    end

    self.frameHooksInstalled = true

    if type(FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            self:HookAllChatFrames()
            for _, frame in ipairs(IterateStyledChatFrames()) do
                if frame and frame.isTemporary and frame.SetUserPlaced then
                    frame:SetUserPlaced(false)
                end
            end
            self:RefreshAllVisuals()
        end)
    end

    if type(FCF_OpenNewWindow) == "function" then
        hooksecurefunc("FCF_OpenNewWindow", function()
            self:HookAllChatFrames()
            self:RefreshAllVisuals()
        end)
    end

    if type(_G.FCFTab_UpdateAlpha) == "function" then
        hooksecurefunc("FCFTab_UpdateAlpha", function(tab)
            self:ApplyTabChrome(tab)
        end)
    end

    if type(_G.FCFTab_UpdateColors) == "function" then
        hooksecurefunc("FCFTab_UpdateColors", function(tab)
            self:ApplyTabChrome(tab)
        end)
    end

    if type(_G.FCFDock_SelectWindow) == "function" then
        hooksecurefunc("FCFDock_SelectWindow", function()
            self:QueueRefreshAllVisuals(0)
        end)
    end

    if type(_G.FCFDock_UpdateTabs) == "function" then
        hooksecurefunc("FCFDock_UpdateTabs", function()
            self:QueueRefreshAllVisuals(0)
        end)
    end

    if type(_G.ChatEdit_UpdateHeader) == "function" then
        hooksecurefunc("ChatEdit_UpdateHeader", function()
            self:ApplyEditBoxChrome()
        end)
    end
end

function ChatStylingModule:OnEnable()
    self:RefreshSettings()
    self:InstallFrameHooks()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleLifecycleRefresh")
    self:RegisterEvent("UPDATE_CHAT_WINDOWS", "HandleLifecycleRefresh")
    self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "HandleLifecycleRefresh")
    -- Whisper tab routing (always registered; setting is checked in the handler).
    self:RegisterEvent("CHAT_MSG_WHISPER", "HandleWhisperMessage")
    self:RegisterEvent("CHAT_MSG_WHISPER_INFORM", "HandleWhisperOutboundMessage")
    self:HookAllChatFrames()
    -- Apply theme colors to the local style constants and subscribe to future changes.
    self:ApplyThemeColors()
    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")
    self:RefreshAllVisuals()
    self:HandleLifecycleRefresh()
end

function ChatStylingModule:OnDisable()
    self:UnregisterMessage("TWICH_THEME_CHANGED")
    self:RefreshSettings()
    if self.refreshAllTimer then
        self:CancelTimer(self.refreshAllTimer)
        self.refreshAllTimer = nil
    end
    self:CancelLifecycleRefreshes()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("UPDATE_CHAT_WINDOWS")
    self:UnregisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    self:UnregisterEvent("CHAT_MSG_WHISPER")
    self:UnregisterEvent("CHAT_MSG_WHISPER_INFORM")
    self:RefreshAllVisuals()
end

--- Finds or creates a dedicated chat window for the given whisper sender name.
--- Returns the ChatFrame if successful, or nil if creation is not possible.
function ChatStylingModule:GetOrCreateWhisperTab(sender)
    local numWindows = NUM_CHAT_WINDOWS or 10
    for i = 1, numWindows do
        local cf = _G["ChatFrame" .. i]
        if cf and cf.TwichUIWhisperSender == sender then
            return cf
        end
    end
    -- FCF_OpenNewWindow is available outside combat lockdown in retail WoW.
    if InCombatLockdown() then return nil end
    if type(FCF_OpenNewWindow) ~= "function" then return nil end
    local newFrame = FCF_OpenNewWindow(sender)
    if newFrame then
        newFrame.TwichUIWhisperSender = sender
        -- Name the tab after the sender.
        if type(FCF_SetWindowName) == "function" then
            FCF_SetWindowName(newFrame, sender)
        end
    end
    return newFrame
end

--- Routes incoming whispers to a per-sender chat tab when the feature is enabled.
function ChatStylingModule:HandleWhisperMessage(_, message, sender)
    if not self.settings or not self.settings.whisperTabsEnabled then return end
    local targetFrame = self:GetOrCreateWhisperTab(sender)
    if not targetFrame then return end
    -- Add the whisper line to the dedicated frame so it mirrors the main window.
    local line = string.format("|cFFFF7DFF[%s]:|r %s", sender, message)
    targetFrame:AddMessage(line, 1.0, 0.49, 1.0)
end

--- Routes outbound whisper replies to the same per-sender tab so the conversation
--- is visible in one place.
function ChatStylingModule:HandleWhisperOutboundMessage(_, message, receiver)
    if not self.settings or not self.settings.whisperTabsEnabled then return end
    local targetFrame = self:GetOrCreateWhisperTab(receiver)
    if not targetFrame then return end
    local unitName = UnitName("player") or "You"
    local line = string.format("|cFF99DDFF[%s]:|r %s", unitName, message)
    targetFrame:AddMessage(line, 0.60, 0.87, 1.0)
end

--- Pulls the current theme colors into the module-local style constants so that
--- ApplyFrameChrome and related functions always use the themed palette.
function ChatStylingModule:ApplyThemeColors()
    local theme = T:GetModule("Theme", true)
    if not theme then return end
    local primary = theme:GetColor("primaryColor")
    PRIMARY_BORDER[1] = primary[1]
    PRIMARY_BORDER[2] = primary[2]
    PRIMARY_BORDER[3] = primary[3]
    -- Fill and active-fill are a darkened tint of the primary color.
    PRIMARY_FILL[1] = primary[1] * 0.38
    PRIMARY_FILL[2] = primary[2] * 0.38
    PRIMARY_FILL[3] = primary[3] * 0.38
    PRIMARY_FILL_ACTIVE[1] = primary[1] * 0.68
    PRIMARY_FILL_ACTIVE[2] = primary[2] * 0.68
    PRIMARY_FILL_ACTIVE[3] = primary[3] * 0.68
    local accent = theme:GetColor("accentColor")
    GOLD_ACCENT[1] = accent[1]
    GOLD_ACCENT[2] = accent[2]
    GOLD_ACCENT[3] = accent[3]
end

--- Called whenever the shared theme changes so chat chrome stays in sync.
function ChatStylingModule:OnThemeChanged(event, changedKey)
    local isColorChange = changedKey == "primaryColor" or changedKey == "accentColor" or changedKey == nil
    if not isColorChange then return end
    self:ApplyThemeColors()
    self:QueueRefreshAllVisuals(0.05)
end
