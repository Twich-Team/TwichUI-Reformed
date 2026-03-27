---@diagnostic disable: undefined-field, undefined-global
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local CHAT_FRAMES = _G.CHAT_FRAMES
local ChatFrame_AddMessageEventFilter = _G.ChatFrame_AddMessageEventFilter
local ChatFrame2 = _G.ChatFrame2
local CreateFrame = _G.CreateFrame
local FCF_OpenNewWindow = _G.FCF_OpenNewWindow
local ChatFrame_RemoveMessageEventFilter = _G.ChatFrame_RemoveMessageEventFilter
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local UIParent = _G.UIParent
local date = _G.date
local format = string.format
local hooksecurefunc = _G.hooksecurefunc
local hasanysecretvalues = _G.hasanysecretvalues
local ipairs = _G.ipairs
local mathMax = math.max
local mathMin = math.min
local pairs = _G.pairs
local time = _G.time
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type

---@type ChatEnhancementModule
local ChatEnhancementModule = T:GetModule("ChatEnhancements")

---@class ChatRendererModule : AceModule
---@field frameHooksInstalled boolean
---@field settings table
local ChatRendererModule = ChatEnhancementModule:NewModule("ChatRenderer", "AceEvent-3.0", "AceTimer-3.0")

local DEBUG_SOURCE_KEY = "chat"
local ROW_CAP = 350
local DEFAULT_TIMESTAMP_WIDTH = 58
local DEFAULT_ROW_GAP = 8
local VIEWPORT_TOP_INSET = 26
local VIEWPORT_BOTTOM_INSET = 10
local CONTENT_TOP_PADDING = 4
local CONTENT_BOTTOM_PADDING = 8
local LIVE_BUTTON_BOTTOM_INSET = 8
local SCROLL_STEP = 42
local SCROLLBAR_WIDTH = 8
local LIVE_BUTTON_WIDTH = 58
local CLASS_ICON_SIZE = 14
local CLASS_ICON_LABEL_OFFSET = 18  -- horizontal space reserved for the class icon
local BORDER = { 0.10, 0.72, 0.74 }
local ACCENT = { 0.95, 0.76, 0.26 }
local TEXT_MUTED = { 0.57, 0.66, 0.74 }

local function PlayMenuSound(soundKey)
    local uiTools = T.Tools and T.Tools.UI or nil
    if uiTools and uiTools.PlayTwichSound then
        uiTools.PlayTwichSound(soundKey)
    end
end
local TEXT_ACTIVE = { 0.96, 0.93, 0.88 }
local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil

-- Events that carry a player GUID we can use to cache sender class tokens.
local CLASS_CACHE_EVENTS = {
    "CHAT_MSG_SAY", "CHAT_MSG_YELL",
    "CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
    "CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
    "CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER",
    "CHAT_MSG_WHISPER",
    "CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

-- Maps a resolved channel key to the slash command used to open that channel in the edit box.
-- Whisper entries are handled separately (need the target player name).
local CHANNEL_KEY_TO_SLASH = {
    guild         = "/g ",
    officer       = "/o ",
    party         = "/p ",
    partyLeader   = "/p ",
    raid          = "/raid ",
    raidLeader    = "/rw ",
    instance      = "/i ",
    instanceLeader = "/i ",
    general       = "/s ",
    trade         = "/s ",
    localDefense  = "/s ",
    lookingForGroup = "/s ",
    services      = "/s ",
    newcomer      = "/s ",
}

local function GetOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.ChatEnhancement
end

local function GetStylingModule()
    return ChatEnhancementModule:GetModule("ChatStyling", true)
end

local function SafeDebugString(value)
    if value == nil then
        return "nil"
    end

    if type(value) == "string" then
        return value
    end

    return tostring(value)
end

local function HasSecretValues(...)
    if type(hasanysecretvalues) == "function" then
        local ok, hasSecret = pcall(hasanysecretvalues, ...)
        if ok and hasSecret then
            return true
        end
    end

    return false
end

local function IsUsablePlainString(value)
    if type(value) ~= "string" then
        return false
    end

    if HasSecretValues(value) then
        return false
    end

    return true
end

local function FormatFramePoint(frame)
    if not frame or type(frame.GetPoint) ~= "function" then
        return "<none>"
    end

    local point, relativeTo, relativePoint, offsetX, offsetY = frame:GetPoint(1)
    local relativeName = relativeTo and relativeTo.GetName and relativeTo:GetName() or tostring(relativeTo)
    return format("%s -> %s:%s (%.1f, %.1f)", tostring(point or "nil"), tostring(relativeName or "nil"),
        tostring(relativePoint or "nil"), tonumber(offsetX) or 0, tonumber(offsetY) or 0)
end

local function HandleRendererMouseWheel(renderer, delta)
    if not renderer then
        return
    end

    -- delta > 0 = wheel up = show older messages = increase offset toward maxScroll
    -- delta < 0 = wheel down = show newer messages = decrease offset toward 0
    ChatRendererModule:ScrollBy(renderer, delta > 0 and SCROLL_STEP or -SCROLL_STEP)
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
        texture:SetColorTexture(topR, topG, topB, mathMax(topA, bottomA))
    end
end

local function ResolveFontPath(fontName)
    local lsm = T.Libs and T.Libs.LSM
    if lsm and fontName and lsm.Fetch then
        local ok, fontPath = pcall(lsm.Fetch, lsm, "font", fontName, true)
        if ok and fontPath then
            return fontPath
        end
    end

    return STANDARD_TEXT_FONT or "Fonts\\FRIZQT__.TTF"
end

local function ApplyResolvedFont(fontString, fontName, size, r, g, b, flags)
    if not fontString then
        return
    end

    fontString:SetFont(ResolveFontPath(fontName), size or 12, flags or "")
    if fontString.SetTextColor then
        fontString:SetTextColor(r or 1, g or 1, b or 1)
    end
    if fontString.SetShadowOffset then
        fontString:SetShadowOffset(1, -1)
    end
    if fontString.SetShadowColor then
        fontString:SetShadowColor(0, 0, 0, 0.92)
    end
    if fontString.SetWordWrap then
        fontString:SetWordWrap(true)
    end
    if fontString.SetNonSpaceWrap then
        fontString:SetNonSpaceWrap(true)
    end
end

local function StripMarkup(text)
    if text == nil then
        return ""
    end

    if not IsUsablePlainString(text) then
        return ""
    end

    local cleaned = text
    cleaned = cleaned:gsub("|T.-|t", "")
    cleaned = cleaned:gsub("|A.-|a", "")
    cleaned = cleaned:gsub("|c%x%x%x%x%x%x%x%x", "")
    cleaned = cleaned:gsub("|r", "")
    cleaned = cleaned:gsub("|H.-|h", "")
    cleaned = cleaned:gsub("|h", "")
    return cleaned
end

local function ExtractSpeakerKey(message)
    if not IsUsablePlainString(message) then
        return nil
    end

    local directPlayer = message:match("|Hplayer:([^:|]+)")
    if directPlayer then
        return directPlayer:lower()
    end

    local bnetPlayer = message:match("|HBNplayer:[^|]+|h%[([^%]]+)%]|h")
    if bnetPlayer then
        return bnetPlayer:lower()
    end

    local plainSpeaker = StripMarkup(message):match("^%s*([^:]+):")
    if plainSpeaker then
        return plainSpeaker:lower()
    end

    return nil
end

local function ShouldSkipFrame(frame)
    if not frame then
        return true
    end

    if frame == ChatFrame2 or frame.isCombatLog then
        return true
    end

    return false
end

function ChatRendererModule:RefreshSettings()
    local options = GetOptions()
    self.settings = {
        addonRedirectEnabled = options:IsAddonRedirectEnabled(),
        abbreviationsEnabled = options:AreAbbreviationsEnabled(),
        animationsEnabled = options:AreAnimationsEnabled(),
        chatFont = options:GetChatFont(),
        chatFontSize = options:GetChatFontSize(),
        channelColors = options:GetResolvedChannelColors(),
        hideHeader = options:IsHeaderHidden(),
        hideRealm = options:IsRealmHidden(),
        historyLimit = options:GetChatHistoryLimit(),
        messageFadeDelay = options:GetMessageFadeDelay(),
        messageFadeDuration = options:GetMessageFadeDuration(),
        messageFadeMinAlpha = options:GetMessageFadeMinAlpha(),
        messageFadesEnabled = options:AreMessageFadesEnabled(),
        rowGap = options:GetRowGap(),
        shellAccent = options:GetResolvedShellAccentColor(),
        showAccentBar = options:ShouldShowAccentBar(),
        timestampFormat = options:GetTimestampFormat(),
        timestampsEnabled = options:AreTimestampsEnabled(),
        timestampWidth = options:GetTimestampWidth(),
        keywordHighlightEnabled = options:IsKeywordHighlightEnabled(),
        keywordHighlightColor = options:GetResolvedKeywordHighlightColor(),
        keywords = options:GetParsedKeywords(),
        headerDatatextEnabled = options:IsHeaderDatatextEnabled(),
        msgBgColor = options:GetResolvedMsgBgColor(),
        showClassIcons = options:IsClassIconsEnabled(),
        classIconStyle = options:GetClassIconStyle(),
        tabStyle = options:GetTabStyle(),
        routingRules = options:GetParsedRoutingRules(),
    }
end

--- Cache the class token for a message sender using the event GUID.
function ChatRendererModule:CacheClassFromEvent(chatEvent, message, sender, language, channelString, target, flags, _, channelNumber, channelName, _, counter, guid)
    if not IsUsablePlainString(sender) or sender == "" then return end
    if not guid or guid == "" then return end
    local _, classToken = GetPlayerInfoByGUID(guid)
    if not classToken then return end
    self.classCache = self.classCache or {}
    local key = sender:lower()
    self.classCache[key] = classToken
    -- Also index by short name (without realm) for hyperlink lookups.
    local shortKey = key:match("^([^%-]+)")
    if shortKey and shortKey ~= key then
        self.classCache[shortKey] = classToken
    end
end

--- Returns the class token for a speaker key, or nil if unknown.
function ChatRendererModule:GetSpeakerClassToken(speakerKey)
    if not speakerKey or not self.classCache then return nil end
    local token = self.classCache[speakerKey]
    if token then return token end
    -- Fallback: strip realm and retry (speakerKey may be "name-realm").
    local shortKey = speakerKey:match("^([^%-]+)")
    return shortKey and self.classCache[shortKey] or nil
end

--- Returns true if the message body (excluding the sender name) contains a keyword.
function ChatRendererModule:MessageMatchesKeyword(message)
    local keywords = self.settings and self.settings.keywords
    if not self.settings.keywordHighlightEnabled or not keywords then return false end
    -- Strip WoW markup to obtain plain text, then remove the sender prefix so
    -- keywords are only matched against the message body and not the player name.
    local plain = StripMarkup(message or ""):lower()
    -- Sender prefix ends at the first ": " (colon + space).
    local bodyStart = plain:find(":%s")
    local body = bodyStart and plain:sub(bodyStart + 2) or plain
    for _, kw in ipairs(keywords) do
        if body:find(kw, 1, true) then return true end
    end
    return false
end

function ChatRendererModule:GetViewportTopInset()
    local isUnified = self.settings and self.settings.tabStyle == "unified"
    if isUnified then
        -- In unified mode the tab bar floats above the frame in chrome space.
        -- No header drag zone lives inside the frame, and the datatext bar is
        -- anchored in the chrome area — not at the frame top — so no inset needed.
        return 2
    end
    if self.settings and self.settings.hideHeader then
        -- Even when the header bar is hidden, the datatext bar still occupies the
        -- top inset zone in non-unified mode.  Reserve that space so messages
        -- don't render underneath the bar.
        if self.settings.headerDatatextEnabled then
            return VIEWPORT_TOP_INSET
        end
        return 2
    end
    -- Non-unified with visible header: header drag zone + optional datatext bar
    -- occupies exactly the VIEWPORT_TOP_INSET (26px) at the frame top.
    return VIEWPORT_TOP_INSET
end

function ChatRendererModule:RefreshViewportInsetsForFrame(frame)
    local renderer = frame and frame.TwichUICustomRenderer
    if not renderer or not renderer.Viewport then
        return
    end
    local topInset = self:GetViewportTopInset()
    renderer.Viewport:ClearAllPoints()
    renderer.Viewport:SetPoint("TOPLEFT", renderer, "TOPLEFT", 0, -topInset)
    renderer.Viewport:SetPoint("BOTTOMRIGHT", renderer, "BOTTOMRIGHT", 0, VIEWPORT_BOTTOM_INSET)
    self:RelayoutRenderer(renderer)
end

function ChatRendererModule:LogDebug(message, shouldShow)
    if not DebugConsole or type(DebugConsole.Log) ~= "function" then
        return false
    end

    return DebugConsole:Log(DEBUG_SOURCE_KEY, SafeDebugString(message), shouldShow)
end

function ChatRendererModule:LogDebugf(shouldShow, messageFormat, ...)
    if not DebugConsole or type(DebugConsole.Logf) ~= "function" then
        return false
    end

    return DebugConsole:Logf(DEBUG_SOURCE_KEY, shouldShow, messageFormat, ...)
end

function ChatRendererModule:BuildDebugReport()
    local lines = {
        "TwichUI Chat Debug Report",
        "",
    }

    local selected = _G.SELECTED_CHAT_FRAME
    lines[#lines + 1] = format("selectedFrame=%s", selected and selected:GetName() or "nil")

    local styleModule = GetStylingModule()
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        if frame and not ShouldSkipFrame(frame) then
            local renderer = frame.TwichUICustomRenderer
            local proxyBar = frame.TwichUIProxyTabBar
            local entries = renderer and #(renderer.entries or {}) or 0
            local buttonCount = proxyBar and #(proxyBar.buttons or {}) or 0
            local owner = styleModule and styleModule.GetProxyOwnerFrame and styleModule:GetProxyOwnerFrame(frame) or
            frame
            lines[#lines + 1] = ""
            lines[#lines + 1] = format("[%s] docked=%s shown=%s size=%.0fx%.0f", frameName,
                tostring(frame.isDocked == true),
                tostring(frame:IsShown()), frame:GetWidth() or 0, frame:GetHeight() or 0)
            lines[#lines + 1] = format("point=%s", FormatFramePoint(frame))
            lines[#lines + 1] = format("proxyOwner=%s proxyButtons=%d proxyShown=%s", owner and owner:GetName() or "nil",
                buttonCount, tostring(proxyBar and proxyBar:IsShown() or false))
            lines[#lines + 1] = format("renderer=%s entries=%d scroll=%.1f target=%.1f total=%.1f viewport=%.1f",
                tostring(renderer ~= nil), entries, renderer and (renderer.scrollOffset or 0) or 0,
                renderer and (renderer.targetScrollOffset or 0) or 0, renderer and (renderer.totalHeight or 0) or 0,
                renderer and renderer.Viewport and renderer.Viewport:GetHeight() or 0)
        end
    end

    local debugLines = DebugConsole and DebugConsole.GetLines and DebugConsole:GetLines(DEBUG_SOURCE_KEY) or nil
    if debugLines and #debugLines > 0 then
        lines[#lines + 1] = ""
        lines[#lines + 1] = "Recent Log Lines"
        for _, line in ipairs(debugLines) do
            lines[#lines + 1] = line
        end
    end

    return table.concat(lines, "\n")
end

function ChatRendererModule:GetShellAccentColor()
    local accent = self.settings and self.settings.shellAccent or nil
    if accent then
        return accent.r or ACCENT[1], accent.g or ACCENT[2], accent.b or ACCENT[3]
    end

    return ACCENT[1], ACCENT[2], ACCENT[3]
end

function ChatRendererModule:GetChannelColor(key, fallbackR, fallbackG, fallbackB)
    local colors = self.settings and self.settings.channelColors or nil
    local color = colors and colors[key] or nil
    if color then
        return color.r or fallbackR or 1, color.g or fallbackG or 1, color.b or fallbackB or 1
    end

    return fallbackR or 1, fallbackG or 1, fallbackB or 1
end

function ChatRendererModule:ResolveMessageChannelKey(message)
    if not IsUsablePlainString(message) then
        return nil
    end

    local styleModule = GetStylingModule()

    local channelRef, label = message:match("|Hchannel:([^|]+)|h%[(.-)%]|h")
    if channelRef then
        local upperRef = channelRef:upper()
        if styleModule and styleModule.ResolveChannelKeyFromLabel then
            if upperRef == "GUILD" then return "guild" end
            if upperRef == "OFFICER" then return "officer" end
            if upperRef == "PARTY" then return "party" end
            if upperRef == "PARTY_LEADER" then return "partyLeader" end
            if upperRef == "RAID" then return "raid" end
            if upperRef == "RAID_LEADER" then return "raidLeader" end
            if upperRef == "INSTANCE_CHAT" then return "instance" end
            if upperRef == "INSTANCE_CHAT_LEADER" then return "instanceLeader" end
            return styleModule:ResolveChannelKeyFromLabel(label)
        end
    end

    if styleModule and styleModule.ResolveChannelKeyFromLabel then
        local stripped = StripMarkup(message)
        local leadingLabel = stripped:match("^%s*%[([^%]]+)%]")
        if leadingLabel then
            local resolved = styleModule:ResolveChannelKeyFromLabel(leadingLabel)
            if resolved then
                return resolved
            end
        end

        local plainPrefix = stripped:match("^%s*([^:]+):")
        if plainPrefix then
            local resolved = styleModule:ResolveChannelKeyFromLabel(plainPrefix)
            if resolved then
                return resolved
            end
        end
    end

    -- BNet whispers use a distinct link type; keep them as whisper.
    -- Do NOT map regular |Hplayer: to whisper — that hyperlink appears in SAY,
    -- YELL, PARTY, etc. and would incorrectly colour all player messages pink.
    if message:find("|HBNplayer:", 1, true) then
        return "whisper"
    end

    return nil
end

function ChatRendererModule:ApplyEntryChannelColor(entry)
    local key = entry.channelKey or self:ResolveMessageChannelKey(entry.message)
    entry.channelKey = key
    if not key then
        return
    end

    entry.r, entry.g, entry.b = self:GetChannelColor(key, entry.r, entry.g, entry.b)
end

function ChatRendererModule:UpdateRowOpacity(renderer, row, entry)
    if not renderer or not row or not entry then
        return
    end

    if (entry.animateIn and self.settings.animationsEnabled) or (row.FadeIn and row.FadeIn.IsPlaying and row.FadeIn:IsPlaying()) or
        row.TwichUIAnimatingIn then
        return
    end

    local rendererHovered = (renderer.Viewport and renderer.Viewport.IsMouseOver and renderer.Viewport:IsMouseOver()) or
        (renderer.IsMouseOver and renderer:IsMouseOver()) or false
    if not self.settings.messageFadesEnabled or not self:IsAtBottom(renderer) or rendererHovered or row:IsMouseOver() then
        row:SetAlpha(1)
        return
    end

    -- Use the time since the user last un-hovered the frame as the age base.  This
    -- restarts the fade-delay countdown each time they leave, so messages don't snap
    -- to faded state immediately after the pointer exits.  GetTime() is used for
    -- sub-second precision so alpha changes are smooth at any tick rate.
    -- When unhoveredAt is not yet set (first time leaving), treat now as the base.
    local age = GetTime() - (renderer.unhoveredAt or GetTime())
    local delay = self.settings.messageFadeDelay or 45
    local duration = mathMax(1, self.settings.messageFadeDuration or 6)
    if age <= delay then
        row:SetAlpha(1)
        return
    end

    local progress = mathMin(1, (age - delay) / duration)
    local minAlpha = mathMax(0, mathMin(1, self.settings.messageFadeMinAlpha or 0.55))
    row:SetAlpha(minAlpha + (1 - minAlpha) * (1 - progress))
end

function ChatRendererModule:RefreshAllRowOpacities(renderer)
    if not renderer then
        return
    end

    for index, entry in ipairs(renderer.entries or {}) do
        local row = renderer.rows and renderer.rows[index] or nil
        if row and row:IsShown() then
            self:UpdateRowOpacity(renderer, row, entry)
        end
    end
end

function ChatRendererModule:UpdateScrollTarget(renderer, offset, instant)
    if not renderer then
        return
    end

    local maxScroll = mathMax(0, (renderer.totalHeight or 0) - renderer.Viewport:GetHeight())
    local clamped = mathMin(mathMax(offset or 0, 0), maxScroll)
    renderer.targetScrollOffset = clamped
    if instant or not self.settings.animationsEnabled then
        renderer.scrollOffset = clamped
    end
    self:UpdateScrollState(renderer)
end

function ChatRendererModule:GetAddonFrame()
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        local tab = frame and frame.GetName and _G[frame:GetName() .. "Tab"] or nil
        local text = tab and tab.GetText and StripMarkup(tab:GetText()) or nil
        if text == "AddOns" then
            return frame
        end
    end

    -- Do not auto-create the AddOns window; only redirect when the user has set one up.
    return nil
end

function ChatRendererModule:GetFrameByTabName(tabName)
    if not tabName or tabName == "" then return nil end
    local lower = tabName:lower()
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        local tab = frame and frame.GetName and _G[frame:GetName() .. "Tab"] or nil
        local tabText = tab and tab.GetText and tab:GetText() or nil
        local text = StripMarkup(tabText)
        if text and text:lower() == lower then
            return frame
        end
    end
    return nil
end

--- Returns the target frame for the first routing rule whose pattern matches
--- the given message text.  Returns nil if no rule matches.
function ChatRendererModule:ResolveRoutingTarget(message)
    local rules = self.settings and self.settings.routingRules
    if not rules or #rules == 0 then return nil end
    local stripped = StripMarkup(message)
    for _, rule in ipairs(rules) do
        if stripped:find(rule.pattern, 1, true) then
            local target = self:GetFrameByTabName(rule.tabName)
            if not target then
                print(string.format("|cff80dfff[TwichUI Routing]|r Pattern '%s' matched but tab '%s' not found.",
                    rule.pattern, rule.tabName))
            end
            return target
        end
    end
    return nil
end

function ChatRendererModule:HandleAddonMessage(chatFrame, event, prefix, message, channel, sender)
    if event ~= "CHAT_MSG_ADDON" or not self:IsEnabled() or not self.settings.addonRedirectEnabled then
        return false
    end

    local addonFrame = self:GetAddonFrame()
    if not addonFrame then
        return false
    end

    -- Suppress Blizzard's own formatting on the AddOns frame; we push a
    -- consistently-formatted version from the redirect below.
    if chatFrame == addonFrame then
        return true
    end

    -- ChatFrame_AddMessageEventFilter fires for EVERY chat frame registered
    -- for the event. Deduplicate so only the first non-AddOns frame routes
    -- the message (same C_Timer.After(0) cycle = same dispatch).
    local dedupKey = tostring(prefix) .. "\0" .. tostring(channel) .. "\0" ..
        tostring(sender) .. "\0" .. tostring(message)
    if self._addonMsgDedupKey == dedupKey then
        return true
    end
    self._addonMsgDedupKey = dedupKey
    C_Timer.After(0, function()
        if self._addonMsgDedupKey == dedupKey then
            self._addonMsgDedupKey = nil
        end
    end)

    local color = self.settings.channelColors and self.settings.channelColors.addon or nil
    local r = color and color.r or 0.84
    local g = color and color.g or 0.62
    local b = color and color.b or 0.26
    local text = ("|cffd69f42[ADDON:%s]|r %s: %s"):format(prefix or "?", sender or "Unknown", message or "")
    -- Route through the hooked AddMessage so the message enters our renderer.
    addonFrame.AddMessage(addonFrame, text, r, g, b)
    return true
end

function ChatRendererModule:IsFrameOwned(frame)
    return frame and frame.TwichUICustomRenderer ~= nil
end

function ChatRendererModule:DecorateMessage(message)
    if type(message) ~= "string" then
        return message
    end

    if not IsUsablePlainString(message) then
        return message
    end

    if self.settings.hideRealm then
        -- Strip the realm suffix from the display name inside |Hplayer:...|h[Name-Realm]|h
        -- while keeping the full qualified name in the hyperlink target intact.
        -- Also ensure any |c color markup inside the display is properly closed with |r
        -- so the class color does not bleed into subsequent message text.
        message = message:gsub("|Hplayer:([^|]+)|h%[([^%]]+)%]|h", function(target, display)
            local shortDisplay = display:match("^([^%-]+)") or display
            -- If the display started a color escape and we stripped its |r terminator
            -- when removing the realm suffix, re-append it so the color is closed.
            if shortDisplay:find("|c", 1, true) and not shortDisplay:match("|r%s*$") then
                shortDisplay = shortDisplay .. "|r"
            end
            return string.format("|Hplayer:%s|h[%s]|h", target, shortDisplay)
        end)
    end

    if not self.settings.abbreviationsEnabled then
        return message
    end

    local stylingModule = GetStylingModule()
    if stylingModule and stylingModule.ApplyChannelAbbreviations then
        return stylingModule:ApplyChannelAbbreviations(message)
    end

    return message
end

function ChatRendererModule:IsAtBottom(renderer)
    if not renderer then
        return true
    end

    -- scrollOffset = 0 means newest messages visible (content bottom aligned to viewport bottom)
    -- scrollOffset = maxScroll means oldest messages visible (content top aligned to viewport top)
    return (renderer.scrollOffset or 0) <= 2
end

function ChatRendererModule:UpdateScrollState(renderer)
    if not renderer then
        return
    end

    local maxScroll = mathMax(0, (renderer.totalHeight or 0) - renderer.Viewport:GetHeight())
    renderer.scrollOffset = mathMin(mathMax(renderer.scrollOffset or 0, 0), maxScroll)
    renderer.targetScrollOffset = mathMin(mathMax(renderer.targetScrollOffset or renderer.scrollOffset or 0, 0),
        maxScroll)

    -- Content is positioned so that scrollOffset=0 shows the BOTTOM (newest) messages and
    -- scrollOffset=maxScroll shows the TOP (oldest) messages.
    -- Formula: contentTopOffset = maxScroll - scrollOffset
    --   At scrollOffset=0     → offset=maxScroll  → content top is above viewport, bottom portion visible (newest) ✓
    --   At scrollOffset=max   → offset=0          → content top aligned to viewport top, first rows visible (oldest) ✓
    local contentTopOffset = maxScroll - (renderer.scrollOffset or 0)
    renderer.Content:ClearAllPoints()
    renderer.Content:SetPoint("TOPLEFT", renderer.Viewport, "TOPLEFT", 0, contentTopOffset)
    renderer.Content:SetWidth(mathMax(1, renderer.Viewport:GetWidth() - (SCROLLBAR_WIDTH + 6)))

    if maxScroll > 0 then
        local trackHeight = renderer.ScrollTrack:GetHeight()
        local viewportHeight = renderer.Viewport:GetHeight()
        local thumbHeight = mathMax(28, trackHeight * (viewportHeight / (renderer.totalHeight or viewportHeight)))
        local thumbTravel = mathMax(0, trackHeight - thumbHeight)
        -- Thumb at bottom = viewing newest (scrollOffset=0), thumb at top = viewing oldest (scrollOffset=max)
        local thumbOffset = thumbTravel * (1 - (renderer.scrollOffset or 0) / maxScroll)
        renderer.ScrollThumb:SetHeight(thumbHeight)
        renderer.ScrollThumb:ClearAllPoints()
        renderer.ScrollThumb:SetPoint("TOPLEFT", renderer.ScrollTrack, "TOPLEFT", 0, -thumbOffset)
        renderer.ScrollThumb:SetPoint("TOPRIGHT", renderer.ScrollTrack, "TOPRIGHT", 0, -thumbOffset)
        renderer.ScrollTrack:Show()
    else
        renderer.ScrollTrack:Hide()
    end

    renderer.LiveButton:SetShown(not self:IsAtBottom(renderer))
end

function ChatRendererModule:SetScrollOffset(renderer, offset)
    if not renderer then
        return
    end

    self:UpdateScrollTarget(renderer, offset, true)
end

--- Open the edit box pre-filled for a whisper to playerName.
function ChatRendererModule:InitiateWhisper(playerName, chatFrame)
    if not playerName or playerName == "" then
        return
    end

    local frame = chatFrame or _G.DEFAULT_CHAT_FRAME
    local text = "/w " .. playerName .. " "
    if type(_G.ChatFrame_OpenChat) == "function" then
        _G.ChatFrame_OpenChat(text, frame)
    else
        local editBox = _G.ChatFrame1EditBox
        if editBox then
            editBox:SetText(text)
            editBox:Show()
            editBox:SetFocus()
        end
    end
end

--- Open the edit box with the appropriate slash command for the message's channel.
function ChatRendererModule:ActivateChatForEntry(entry, chatFrame)
    if not entry then
        return
    end

    local frame = chatFrame or _G.DEFAULT_CHAT_FRAME
    local channelKey = entry.channelKey

    if channelKey == "whisper" then
        local speaker = entry.speakerKey
        if speaker and speaker ~= "" then
            self:InitiateWhisper(speaker, frame)
            return
        end
    end

    local slash = (channelKey and CHANNEL_KEY_TO_SLASH[channelKey]) or "/s "
    if type(_G.ChatFrame_OpenChat) == "function" then
        _G.ChatFrame_OpenChat(slash, frame)
    else
        local editBox = _G.ChatFrame1EditBox
        if editBox then
            editBox:Show()
            editBox:SetFocus()
        end
    end
end

function ChatRendererModule:ScrollToBottom(renderer)
    if not renderer then
        return
    end

    -- scrollOffset=0 shows the newest messages (content bottom aligned to viewport bottom)
    self:SetScrollOffset(renderer, 0)
end

function ChatRendererModule:ScrollBy(renderer, amount)
    if not renderer then
        return
    end

    self:UpdateScrollTarget(renderer, (renderer.targetScrollOffset or renderer.scrollOffset or 0) + amount)
end

function ChatRendererModule:EnsureRow(renderer, index)
    renderer.rows = renderer.rows or {}
    if renderer.rows[index] then
        return renderer.rows[index]
    end

    local row = CreateFrame("Button", nil, renderer.Content, "BackdropTemplate")
    renderer.rows[index] = row
    CreateBackdrop(row)
    row:SetBackdropColor(0.03, 0.05, 0.07, 0.72)
    row:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.08)
    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row.isKeywordMatch = false
    -- Required for the frame to fire OnHyperlinkEnter / OnHyperlinkLeave /
    -- OnHyperlinkClick events from FontStrings it contains.
    row:SetHyperlinksEnabled(true)

    row.Fill = row:CreateTexture(nil, "BACKGROUND")
    row.Fill:SetAllPoints(row)

    row.Highlight = row:CreateTexture(nil, "ARTWORK")
    row.Highlight:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    row.Highlight:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    row.Highlight:SetColorTexture(BORDER[1], BORDER[2], BORDER[3], 0)

    row.Bar = row:CreateTexture(nil, "BORDER")
    row.Bar:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    row.Bar:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 0, 0)
    row.Bar:SetWidth(3)

    row.Separator = row:CreateTexture(nil, "BORDER")
    row.Separator:SetWidth(1)

    row.Timestamp = row:CreateFontString(nil, "OVERLAY")
    row.Timestamp:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
    row.Timestamp:SetJustifyH("LEFT")
    row.Timestamp:SetJustifyV("TOP")

    row.Label = row:CreateFontString(nil, "OVERLAY")
    row.Label:SetPoint("TOPLEFT", row, "TOPLEFT", DEFAULT_TIMESTAMP_WIDTH + 14, -8)
    row.Label:SetJustifyH("LEFT")
    row.Label:SetJustifyV("TOP")

    row.ClassIcon = row:CreateTexture(nil, "OVERLAY")
    row.ClassIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
    row.ClassIcon:Hide()

    row.FadeIn = row:CreateAnimationGroup()
    row.FadeIn:SetScript("OnPlay", function(selfGroup)
        local parentRow = selfGroup:GetParent()
        if parentRow then
            parentRow.TwichUIAnimatingIn = true
        end
    end)
    row.FadeIn:SetScript("OnFinished", function(selfGroup)
        local parentRow = selfGroup:GetParent()
        if parentRow then
            parentRow.TwichUIAnimatingIn = false
            ChatRendererModule:UpdateRowOpacity(renderer, parentRow, parentRow.entry)
        end
    end)
    row.FadeIn:SetScript("OnStop", function(selfGroup)
        local parentRow = selfGroup:GetParent()
        if parentRow then
            parentRow.TwichUIAnimatingIn = false
        end
    end)
    local alpha = row.FadeIn:CreateAnimation("Alpha")
    alpha:SetFromAlpha(0)
    alpha:SetToAlpha(1)
    alpha:SetDuration(0.16)
    alpha:SetOrder(1)

    local slide = row.FadeIn:CreateAnimation("Translation")
    slide:SetOffset(0, -2)
    slide:SetDuration(0.16)
    slide:SetOrder(1)

    -- Hover restore: smoothly raise alpha to 1 when mouse enters a faded row.
    row.HoverFadeIn = row:CreateAnimationGroup()
    local hoverAlphaIn = row.HoverFadeIn:CreateAnimation("Alpha")
    hoverAlphaIn:SetFromAlpha(0)   -- will be overridden via SetAlpha before Play()
    hoverAlphaIn:SetToAlpha(1)
    hoverAlphaIn:SetDuration(0.30)
    hoverAlphaIn:SetOrder(1)
    row.HoverFadeIn:SetScript("OnPlay", function()
        -- capture the true current alpha so the anim starts from where we are
        local cur = row:GetAlpha()
        hoverAlphaIn:SetFromAlpha(cur)
    end)
    row.HoverFadeIn:SetScript("OnFinished", function()
        row:SetAlpha(1)
    end)

    -- Hover restore-out: when mouse leaves, transition back to the correct faded alpha.
    row.HoverFadeOut = row:CreateAnimationGroup()
    local hoverAlphaOut = row.HoverFadeOut:CreateAnimation("Alpha")
    hoverAlphaOut:SetFromAlpha(1)
    hoverAlphaOut:SetToAlpha(0)    -- will be overridden via SetAlpha before Play()
    hoverAlphaOut:SetDuration(0.45)
    hoverAlphaOut:SetOrder(1)
    row.HoverFadeOut:SetScript("OnPlay", function()
        hoverAlphaOut:SetFromAlpha(row:GetAlpha())
    end)
    row.HoverFadeOut:SetScript("OnFinished", function()
        -- Snap to the precise target alpha once the animation completes.
        ChatRendererModule:UpdateRowOpacity(renderer, row, row.entry)
    end)

    row:SetScript("OnEnter", function(selfRow)
        selfRow.Highlight:SetAlpha(0.08)
        -- Keyword-matched rows keep a tinted border on hover; others use the standard accent.
        if selfRow.isKeywordMatch then
            local hc = ChatRendererModule.settings and ChatRendererModule.settings.keywordHighlightColor or {}
            local hR, hG, hB = hc.r or 0.95, hc.g or 0.76, hc.b or 0.26
            selfRow:SetBackdropBorderColor(hR, hG, hB, 0.90)
        else
            selfRow:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.18)
        end
        -- Animate faded rows back to full visibility on hover.
        if selfRow:GetAlpha() < 0.99 then
            selfRow.HoverFadeOut:Stop()
            selfRow.HoverFadeIn:Stop()
            selfRow.HoverFadeIn:Play()
        end
    end)
    row:SetScript("OnLeave", function(selfRow)
        selfRow.Highlight:SetAlpha(0)
        -- Restore border: keyword rows keep a subtle tinted border; others revert to default.
        if selfRow.isKeywordMatch then
            local hc = ChatRendererModule.settings and ChatRendererModule.settings.keywordHighlightColor or {}
            local hR, hG, hB = hc.r or 0.95, hc.g or 0.76, hc.b or 0.26
            selfRow:SetBackdropBorderColor(hR, hG, hB, 0.60)
        else
            selfRow:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.08)
        end
        selfRow.HoverFadeIn:Stop()
        selfRow.HoverFadeOut:Stop()
        -- If the pointer moved to another row inside the same renderer, the renderer
        -- is still hovered.  Don't start a fade-out — that would cause a flicker where
        -- the row dims then snaps back when UpdateRowOpacity next fires.
        local rendererStillHovered = (renderer.Viewport and renderer.Viewport:IsMouseOver()) or
            (renderer:IsMouseOver()) or false
        if rendererStillHovered then
            return
        end
        -- Renderer unhovered: animate back to the correct faded alpha if needed.
        selfRow.HoverFadeIn:Stop()
        selfRow.HoverFadeOut:Stop()
        local targetAlpha = 1
        if ChatRendererModule.settings.messageFadesEnabled and ChatRendererModule:IsAtBottom(renderer) then
            -- The viewport/renderer OnLeave hooks set unhoveredAt, but they fire AFTER
            -- row OnLeave.  Seed it here so old messages don't snap to fully faded state
            -- before the viewport handler runs — the delay restarts from NOW on mouse-out.
            if not renderer.unhoveredAt then
                renderer.unhoveredAt = GetTime()
            end
            local age = GetTime() - renderer.unhoveredAt
            local delay = ChatRendererModule.settings.messageFadeDelay or 45
            local duration = mathMax(1, ChatRendererModule.settings.messageFadeDuration or 6)
            local minAlpha = mathMax(0, mathMin(1, ChatRendererModule.settings.messageFadeMinAlpha or 0.55))
            if age > delay then
                local progress = mathMin(1, (age - delay) / duration)
                targetAlpha = minAlpha + (1 - minAlpha) * (1 - progress)
            end
        end
        if targetAlpha < 0.99 then
            hoverAlphaOut:SetToAlpha(targetAlpha)
            selfRow.HoverFadeOut:Play()
        else
            ChatRendererModule:UpdateRowOpacity(renderer, selfRow, selfRow.entry)
        end
    end)

    -- Hyperlink hover: show GameTooltip for link types that support it.
    -- Guild links, calendar links, player links etc. have no hover tooltip
    -- in standard WoW either; attempting SetHyperlink on them produces blank
    -- or erroring tooltips, so we only attempt it for known informational types.
    -- "trade" (profession links) is intentionally excluded: SetHyperlink on a
    -- trade link opens the profession UI as a side-effect rather than showing a
    -- tooltip, so we leave hover over those links as a no-op and let the click
    -- handler open the window on demand.
    local TOOLTIP_LINK_TYPES = {
        item = true, spell = true, achievement = true, quest = true,
        enchant = true, battlepet = true, instancelockout = true,
        transmogappearance = true, garrmission = true, talent = true,
        currency = true, glyph = true, dungeonScore = true,
    }
    row:SetScript("OnHyperlinkEnter", function(selfRow, link)
        if not link or link == "" then return end
        local linkType = link:match("^([^:]+)")
        if linkType and TOOLTIP_LINK_TYPES[linkType:lower()] then
            local gt = _G.GameTooltip
            if gt then
                gt:SetOwner(selfRow, "ANCHOR_CURSOR")
                local ok = pcall(gt.SetHyperlink, gt, link)
                if ok then
                    gt:Show()
                else
                    gt:Hide()
                end
            end
        end
    end)
    row:SetScript("OnHyperlinkLeave", function()
        local gt = _G.GameTooltip
        if gt then gt:Hide() end
    end)

    -- Hyperlink clicks: use ChatFrame_OnHyperlinkShow which is WoW's full handler
    -- for ALL hyperlink types including guild recruitment, calendar events, items,
    -- achievements, quests, player context menus, URL dialogs and more.
    -- Falls back to SetItemRef if the full handler is unavailable.
    row:SetScript("OnHyperlinkClick", function(selfRow, link, text, button)
        selfRow._twichHyperlinkHandled = true
        local chatFrame = renderer:GetParent()
        -- Use securecall to avoid propagating addon taint into Blizzard's
        -- protected hyperlink handlers (e.g. CommunitiesHyperlink → GetLastTicketResponse).
        if _G.ChatFrame_OnHyperlinkShow then
            securecall("ChatFrame_OnHyperlinkShow", chatFrame or _G.ChatFrame1, link, text, button)
        elseif _G.SetItemRef then
            securecall("SetItemRef", link, text, button, chatFrame)
        end
    end)

    -- Row click: left-click opens the edit box; right-click shows the TwichUI context menu.
    row:SetScript("OnClick", function(selfRow, clickButton)
        if selfRow._twichHyperlinkHandled then
            selfRow._twichHyperlinkHandled = nil
            return
        end
        if clickButton == "RightButton" and selfRow.entry then
            ChatRendererModule:ShowMessageContextMenu(selfRow, selfRow.entry)
            return
        end
        if clickButton ~= "LeftButton" then
            return
        end
        if selfRow.entry then
            ChatRendererModule:ActivateChatForEntry(selfRow.entry, renderer:GetParent())
        end
    end)

    return row
end

function ChatRendererModule:MeasureEntry(renderer, entry, bodyWidth)
    if not renderer or not entry then
        return
    end

    local measure = renderer.MeasureLabel
    local baseFontSize = self.settings.chatFontSize or 13
    if not IsUsablePlainString(entry.text) then
        entry.bodyHeight = baseFontSize
        entry.rowHeight = mathMax(28, baseFontSize + 16)
        return
    end

    ApplyResolvedFont(measure, self.settings.chatFont, self.settings.chatFontSize, 1, 1, 1, "")
    measure:SetWidth(bodyWidth)
    measure:SetText(entry.text or "")
    local textHeight = mathMax(baseFontSize, measure:GetStringHeight())
    entry.bodyHeight = textHeight
    entry.rowHeight = mathMax(28, textHeight + 16)
end

function ChatRendererModule:RefreshRow(renderer, row, entry, bodyWidth)
    local grouped = entry.groupedWithPrevious
    local timestampsEnabled = self.settings.timestampsEnabled
    local timestampWidth = timestampsEnabled and (self.settings.timestampWidth or DEFAULT_TIMESTAMP_WIDTH) or 0
    local accentR, accentG, accentB = self:GetShellAccentColor()
    if entry.channelKey then
        accentR, accentG, accentB = self:GetChannelColor(entry.channelKey, accentR, accentG, accentB)
    end

    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", renderer.Content, "TOPLEFT", 0, -entry.yOffset)
    row:SetPoint("TOPRIGHT", renderer.Content, "TOPRIGHT", 0, -entry.yOffset)
    row:SetHeight(entry.rowHeight)

    local msgBg = self.settings.msgBgColor or {}
    local mbR = msgBg.r or 0.03
    local mbG = msgBg.g or 0.05
    local mbB = msgBg.b or 0.07
    local mbA = msgBg.a ~= nil and msgBg.a or 0.72
    SetVerticalGradient(row.Fill,
        mathMin(1, mbR * (grouped and 1.0 or 2.0)),
        mathMin(1, mbG * (grouped and 1.0 or 2.0)),
        mathMin(1, mbB * (grouped and 1.0 or 2.0)),
        mbA * (grouped and 0.62 or 1.0),
        mbR * 0.65, mbG * 0.65, mbB * 0.65, mbA * (grouped and 0.62 or 1.0))

    -- Keyword match highlight: override the row background and accent bar with a warm tint.
    -- Also change the row border to the keyword color so it stands out more clearly.
    local kwMatch = self:MessageMatchesKeyword(entry.message)
    row.isKeywordMatch = kwMatch
    if kwMatch then
        local hc = self.settings.keywordHighlightColor or {}
        local hR, hG, hB = hc.r or 0.95, hc.g or 0.76, hc.b or 0.26
        row:SetBackdropColor(hR * 0.14, hG * 0.06, hB * 0.02, grouped and 0.5 or 0.82)
        row:SetBackdropBorderColor(hR, hG, hB, 0.60)
        row.Bar:SetColorTexture(hR, hG, hB, grouped and 0.6 or 1.0)
        row.Bar:Show()
    else
        row:SetBackdropColor(mbR, mbG, mbB, mbA * (grouped and 0.55 or 0.92))
        row:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.08)
        row.Bar:SetShown(self.settings.showAccentBar)
        row.Bar:SetColorTexture(accentR, accentG, accentB, grouped and 0.52 or 0.96)
    end
    row.Separator:ClearAllPoints()
    row.Separator:SetPoint("TOPLEFT", row, "TOPLEFT", timestampWidth + 10, -8)
    row.Separator:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", timestampWidth + 10, 8)
    row.Separator:SetColorTexture(accentR, accentG, accentB, grouped and 0.34 or 0)
    row.Separator:SetShown(grouped)

    row.Timestamp:ClearAllPoints()
    row.Timestamp:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
    row.Timestamp:SetWidth(mathMax(0, timestampWidth - 10))
    row.Timestamp:SetShown(timestampsEnabled)
    if timestampsEnabled then
        ApplyResolvedFont(row.Timestamp, self.settings.chatFont, mathMax(10, (self.settings.chatFontSize or 13) - 2),
            TEXT_MUTED[1], TEXT_MUTED[2], TEXT_MUTED[3], "")
        row.Timestamp:SetText(grouped and "" or date(self.settings.timestampFormat, entry.timestamp))
    else
        row.Timestamp:SetText("")
    end

    row.Label:ClearAllPoints()
    local labelOffsetX = timestampWidth + 14
    local showIcon = self.settings.showClassIcons and entry.speakerKey ~= nil
    local iconShown = false
    if showIcon then
        local classToken = self:GetSpeakerClassToken(entry.speakerKey)
        if classToken then
            local TwichTextures = T.Tools and T.Tools.Textures
            if TwichTextures and TwichTextures.ApplyClassTexture then
                row.ClassIcon:ClearAllPoints()
                -- Vertically center the icon in the row's text area (8px padding + half icon)
                local iconY = -8 - (CLASS_ICON_SIZE - (self.settings.chatFontSize or 13)) * 0.5
                row.ClassIcon:SetPoint("TOPLEFT", row, "TOPLEFT", timestampWidth + 14, iconY)
                row.ClassIcon:SetSize(CLASS_ICON_SIZE, CLASS_ICON_SIZE)
                TwichTextures:ApplyClassTexture(row.ClassIcon, classToken, ChatRendererModule.settings and ChatRendererModule.settings.classIconStyle)
                row.ClassIcon:Show()
                labelOffsetX = timestampWidth + 14 + CLASS_ICON_LABEL_OFFSET
                iconShown = true
            else
                row.ClassIcon:Hide()
            end
        else
            -- Class not yet resolved for this sender; hide icon and use full width.
            row.ClassIcon:Hide()
        end
    else
        row.ClassIcon:Hide()
    end
    row.Label:SetPoint("TOPLEFT", row, "TOPLEFT", labelOffsetX, -8)
    -- When an icon is shown the label starts CLASS_ICON_LABEL_OFFSET to the right;
    -- shrink its width by the same amount so text doesn't overflow the row edge.
    local effectiveLabelWidth = iconShown and mathMax(50, bodyWidth - CLASS_ICON_LABEL_OFFSET) or bodyWidth
    row.Label:SetWidth(effectiveLabelWidth)
    ApplyResolvedFont(row.Label, self.settings.chatFont, self.settings.chatFontSize, entry.r, entry.g, entry.b, "")
    row.Label:SetText(entry.text or "")
    row.Label:SetTextColor(entry.r, entry.g, entry.b)
    row.entry = entry

    row:Show()
    if entry.animateIn and self.settings.animationsEnabled then
        row:SetAlpha(0)
        row.FadeIn:Stop()
        row.FadeIn:Play()
    else
        self:UpdateRowOpacity(renderer, row, entry)
    end
    entry.animateIn = false
end

function ChatRendererModule:RelayoutRenderer(renderer)
    if not renderer then
        return
    end

    local width = renderer.Viewport:GetWidth() - (SCROLLBAR_WIDTH + 10)
    if width <= 40 then
        return
    end

    local timestampWidth = self.settings.timestampsEnabled and (self.settings.timestampWidth or DEFAULT_TIMESTAMP_WIDTH) or
    0
    -- bodyWidth is the shared content column width.
    local bodyWidth = mathMax(70, width - timestampWidth - 18)
    local offsetY = CONTENT_TOP_PADDING
    local previousEntry = nil
    local rowGap = self.settings.rowGap or DEFAULT_ROW_GAP
    local groupedRowGap = mathMax(1, math.floor(rowGap * 0.4))

    for index, entry in ipairs(renderer.entries) do
        -- Mirror the icon-offset logic from RefreshRow so the measurement width
        -- matches the actual label width used when rendering.  If a class icon
        -- will be shown, the label is CLASS_ICON_LABEL_OFFSET narrower than
        -- bodyWidth, causing multi-line wrapping that wasn't captured by a
        -- measurement taken at the full bodyWidth.  This was the root cause of
        -- rows not expanding vertically when messages wrapped (most noticeable
        -- in dungeons where every instance-chat sender has a cached class icon).
        local iconOffset = 0
        if self.settings.showClassIcons and entry.speakerKey then
            local classToken = self:GetSpeakerClassToken(entry.speakerKey)
            if classToken then
                local TwichTextures = T.Tools and T.Tools.Textures
                if TwichTextures and TwichTextures.ApplyClassTexture then
                    iconOffset = CLASS_ICON_LABEL_OFFSET
                end
            end
        end
        local effectiveBodyWidth = mathMax(50, bodyWidth - iconOffset)
        if entry.measuredWidth ~= effectiveBodyWidth then
            self:MeasureEntry(renderer, entry, effectiveBodyWidth)
            entry.measuredWidth = effectiveBodyWidth
        end

        local spacing = previousEntry and (entry.groupedWithPrevious and groupedRowGap or rowGap) or 0
        offsetY = offsetY + spacing
        entry.yOffset = offsetY
        offsetY = offsetY + entry.rowHeight
        previousEntry = entry

        local row = self:EnsureRow(renderer, index)
        self:RefreshRow(renderer, row, entry, bodyWidth)
    end

    for index = #renderer.entries + 1, #(renderer.rows or {}) do
        local row = renderer.rows[index]
        if row then
            row:Hide()
        end
    end

    renderer.totalHeight = mathMax(renderer.Viewport:GetHeight(), offsetY + CONTENT_BOTTOM_PADDING)
    renderer.Content:SetHeight(renderer.totalHeight)
    self:UpdateScrollState(renderer)
    for index, entry in ipairs(renderer.entries) do
        local row = renderer.rows and renderer.rows[index] or nil
        if row and row:IsShown() then
            self:UpdateRowOpacity(renderer, row, entry)
        end
    end
end

function ChatRendererModule:RebuildGrouping(renderer)
    local previousSpeaker = nil
    for _, entry in ipairs(renderer.entries) do
        entry.groupedWithPrevious = previousSpeaker ~= nil and previousSpeaker == entry.speakerKey
        previousSpeaker = entry.speakerKey
    end
end

function ChatRendererModule:CreateEntry(message, r, g, b, accessID)
    local entry = {
        accessID = accessID,
        animateIn = true,
        b = b or 1,
        g = g or 1,
        message = message,
        r = r or 1,
        speakerKey = ExtractSpeakerKey(message),
        text = self:DecorateMessage(message),
        timestamp = time(),
        entryTime = GetTime(),
    }

    self:ApplyEntryChannelColor(entry)
    return entry
end

function ChatRendererModule:PushMessage(frame, message, r, g, b, accessID)
    local renderer = frame and frame.TwichUICustomRenderer
    if not renderer then
        return
    end

    local stickToBottom = self:IsAtBottom(renderer)
    local entry = self:CreateEntry(message, r, g, b, accessID)
    local previousEntry = renderer.entries[#renderer.entries]
    entry.groupedWithPrevious = previousEntry ~= nil and previousEntry.speakerKey ~= nil and
        previousEntry.speakerKey == entry.speakerKey
    renderer.entries[#renderer.entries + 1] = entry

    local cap = (self.settings and self.settings.historyLimit) or ROW_CAP
    if #renderer.entries > cap then
        table.remove(renderer.entries, 1)
        self:RebuildGrouping(renderer)
    end

    self:RelayoutRenderer(renderer)
    if stickToBottom then
        self:ScrollToBottom(renderer)
    else
        self:UpdateScrollState(renderer)
    end
end

function ChatRendererModule:ClearRenderer(frame)
    local renderer = frame and frame.TwichUICustomRenderer
    if not renderer then
        return
    end

    renderer.entries = {}
    renderer.totalHeight = renderer.Viewport:GetHeight()
    for _, row in pairs(renderer.rows or {}) do
        row:Hide()
    end
    self:SetScrollOffset(renderer, 0)
end

function ChatRendererModule:SeedFromChatFrame(frame)
    local renderer = frame and frame.TwichUICustomRenderer
    if not renderer or not frame or type(frame.GetNumMessages) ~= "function" or type(frame.GetMessageInfo) ~= "function" then
        return
    end

    local count = tonumber(frame:GetNumMessages()) or 0
    if count <= 0 then
        return
    end

    renderer.entries = {}
    local cap = (self.settings and self.settings.historyLimit) or ROW_CAP
    local startIndex = mathMax(1, count - cap + 1)
    for index = startIndex, count do
        local text, red, green, blue, accessID = frame:GetMessageInfo(index)
        if text then
            local entry = self:CreateEntry(text, red, green, blue, accessID)
            entry.animateIn = false
            renderer.entries[#renderer.entries + 1] = entry
        end
    end

    self:RebuildGrouping(renderer)
    self:RelayoutRenderer(renderer)
    self:ScrollToBottom(renderer)
    if frame.TwichUIOriginalClear then
        frame.TwichUIOriginalClear(frame)
    elseif frame.Clear then
        frame:Clear()
    end
end

function ChatRendererModule:EnsureRenderer(frame)
    if ShouldSkipFrame(frame) or frame.TwichUICustomRenderer then
        return frame and frame.TwichUICustomRenderer or nil
    end

    local renderer = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TwichUICustomRenderer = renderer
    renderer:SetAllPoints(frame)
    renderer:SetFrameStrata("MEDIUM")
    renderer:SetFrameLevel(frame:GetFrameLevel() + 10)
    renderer.entries = {}
    renderer.rows = {}
    renderer.scrollOffset = 0
    renderer.targetScrollOffset = 0
    renderer.fadeElapsed = 0

    renderer.Viewport = CreateFrame("Frame", nil, renderer)
    renderer.Viewport:SetPoint("TOPLEFT", renderer, "TOPLEFT", 0, -VIEWPORT_TOP_INSET)
    renderer.Viewport:SetPoint("BOTTOMRIGHT", renderer, "BOTTOMRIGHT", 0, VIEWPORT_BOTTOM_INSET)
    renderer.Viewport:SetClipsChildren(true)
    renderer.Viewport:EnableMouse(true)
    renderer.Viewport:EnableMouseWheel(true)

    renderer:EnableMouse(true)
    renderer:EnableMouseWheel(true)

    renderer.Content = CreateFrame("Frame", nil, renderer.Viewport)
    renderer.Content:SetPoint("TOPLEFT", renderer.Viewport, "TOPLEFT", 0, 0)
    renderer.Content:SetWidth(mathMax(1, renderer.Viewport:GetWidth() - (SCROLLBAR_WIDTH + 6)))
    renderer.Content:SetHeight(renderer.Viewport:GetHeight())

    renderer.MeasureLabel = renderer:CreateFontString(nil, "ARTWORK")
    renderer.MeasureLabel:SetParent(UIParent)
    renderer.MeasureLabel:Hide()

    renderer.ScrollTrack = CreateFrame("Frame", nil, renderer)
    renderer.ScrollTrack:SetPoint("TOPRIGHT", renderer.Viewport, "TOPRIGHT", -1, -2)
    renderer.ScrollTrack:SetPoint("BOTTOMRIGHT", renderer.Viewport, "BOTTOMRIGHT", -1, 2)
    renderer.ScrollTrack:SetWidth(SCROLLBAR_WIDTH)
    CreateBackdrop(renderer.ScrollTrack)
    renderer.ScrollTrack:SetBackdropColor(0.02, 0.03, 0.05, 0.82)
    renderer.ScrollTrack:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.14)

    renderer.ScrollThumb = CreateFrame("Frame", nil, renderer.ScrollTrack, "BackdropTemplate")
    renderer.ScrollThumb:SetPoint("TOPLEFT", renderer.ScrollTrack, "TOPLEFT", 0, 0)
    renderer.ScrollThumb:SetPoint("TOPRIGHT", renderer.ScrollTrack, "TOPRIGHT", 0, 0)
    renderer.ScrollThumb:SetHeight(40)
    CreateBackdrop(renderer.ScrollThumb)
    renderer.ScrollThumb:SetBackdropColor(BORDER[1], BORDER[2], BORDER[3], 0.3)
    renderer.ScrollThumb:SetBackdropBorderColor(BORDER[1], BORDER[2], BORDER[3], 0.45)

    -- Scrollbar fade: start hidden (alpha 0) and reveal on renderer hover.
    renderer.ScrollTrack:SetAlpha(0)
    do
        local sbFadeIn = renderer.ScrollTrack:CreateAnimationGroup()
        local sbFadeInAlpha = sbFadeIn:CreateAnimation("Alpha")
        sbFadeInAlpha:SetOrder(1)
        sbFadeInAlpha:SetFromAlpha(0)
        sbFadeInAlpha:SetToAlpha(1)
        sbFadeInAlpha:SetDuration(0.20)
        sbFadeIn:SetToFinalAlpha(true)
        renderer.ScrollTrack.__sbFadeIn = sbFadeIn

        local sbFadeOut = renderer.ScrollTrack:CreateAnimationGroup()
        local sbFadeOutAlpha = sbFadeOut:CreateAnimation("Alpha")
        sbFadeOutAlpha:SetOrder(1)
        sbFadeOutAlpha:SetFromAlpha(1)
        sbFadeOutAlpha:SetToAlpha(0)
        sbFadeOutAlpha:SetDuration(0.50)
        sbFadeOut:SetToFinalAlpha(true)
        renderer.ScrollTrack.__sbFadeOut = sbFadeOut
    end

    renderer.LiveButton = CreateFrame("Button", nil, renderer, "BackdropTemplate")
    renderer.LiveButton:SetPoint("BOTTOMRIGHT", renderer.Viewport, "BOTTOMRIGHT", -18, LIVE_BUTTON_BOTTOM_INSET)
    renderer.LiveButton:SetSize(LIVE_BUTTON_WIDTH, 22)
    renderer.LiveButton:SetText("LIVE")
    do
        local accentR, accentG, accentB = self:GetShellAccentColor()
        T.Tools.UI.SkinTwichButton(renderer.LiveButton, { accentR, accentG, accentB })
        renderer.ScrollThumb:SetBackdropColor(accentR, accentG, accentB, 0.3)
        renderer.ScrollThumb:SetBackdropBorderColor(accentR, accentG, accentB, 0.45)
        renderer.ScrollTrack:SetBackdropBorderColor(accentR, accentG, accentB, 0.14)
    end
    renderer.LiveButton:GetFontString():SetTextColor(TEXT_ACTIVE[1], TEXT_ACTIVE[2], TEXT_ACTIVE[3])
    renderer.LiveButton:SetScript("OnClick", function()
        ChatRendererModule:ScrollToBottom(renderer)
    end)
    renderer.LiveButton:Hide()

    renderer.Viewport:SetScript("OnMouseWheel", function(_, delta)
        HandleRendererMouseWheel(renderer, delta)
    end)
    renderer:SetScript("OnMouseWheel", function(_, delta)
        HandleRendererMouseWheel(renderer, delta)
    end)
    renderer.Viewport:HookScript("OnEnter", function()
        renderer.unhoveredAt = nil
        ChatRendererModule:RefreshAllRowOpacities(renderer)
        -- Cancel any pending fade-out timer and reveal scrollbar immediately.
        if renderer.ScrollTrack then
            if renderer.ScrollTrack.__sbFadeOutTimer then
                renderer.ScrollTrack.__sbFadeOutTimer:Cancel()
                renderer.ScrollTrack.__sbFadeOutTimer = nil
            end
            if renderer.ScrollTrack.__sbFadeOut then renderer.ScrollTrack.__sbFadeOut:Stop() end
            if renderer.ScrollTrack.__sbFadeIn and not renderer.ScrollTrack.__sbFadeIn:IsPlaying() then
                renderer.ScrollTrack.__sbFadeIn:Play()
            end
        end
        local stylingModule = GetStylingModule()
        if stylingModule and frame.TwichUIControlStrip then
            stylingModule:UpdateControlStripVisibility(frame, true)
        end
    end)
    renderer.Viewport:HookScript("OnLeave", function()
        -- When the mouse moves from the Viewport to a child row, WoW fires OnLeave
        -- on the Viewport even though the cursor is still within the renderer bounds.
        -- Guard against this so the scrollbar and row-opacity state are only reset
        -- when the cursor truly leaves the chat frame area.
        if renderer:IsMouseOver() then return end
        renderer.unhoveredAt = GetTime()
        ChatRendererModule:RefreshAllRowOpacities(renderer)
        -- Schedule scrollbar fade-out after a 5-second idle delay.
        if renderer.ScrollTrack then
            if renderer.ScrollTrack.__sbFadeOutTimer then
                renderer.ScrollTrack.__sbFadeOutTimer:Cancel()
                renderer.ScrollTrack.__sbFadeOutTimer = nil
            end
            renderer.ScrollTrack.__sbFadeOutTimer = C_Timer.NewTimer(5, function()
                renderer.ScrollTrack.__sbFadeOutTimer = nil
                if renderer:IsMouseOver() or (renderer.Viewport and renderer.Viewport:IsMouseOver()) then return end
                if renderer.ScrollTrack.__sbFadeIn then renderer.ScrollTrack.__sbFadeIn:Stop() end
                if renderer.ScrollTrack.__sbFadeOut and not renderer.ScrollTrack.__sbFadeOut:IsPlaying() then
                    renderer.ScrollTrack.__sbFadeOut:Play()
                end
            end)
        end
        local stylingModule = GetStylingModule()
        if stylingModule and frame.TwichUIControlStrip then
            stylingModule:UpdateControlStripVisibility(frame, false)
        end
    end)
    renderer:HookScript("OnEnter", function()
        renderer.unhoveredAt = nil
        ChatRendererModule:RefreshAllRowOpacities(renderer)
        local stylingModule = GetStylingModule()
        if stylingModule and frame.TwichUIControlStrip then
            stylingModule:UpdateControlStripVisibility(frame, true)
        end
    end)
    renderer:HookScript("OnLeave", function()
        renderer.unhoveredAt = GetTime()
        ChatRendererModule:RefreshAllRowOpacities(renderer)
        local stylingModule = GetStylingModule()
        if stylingModule and frame.TwichUIControlStrip then
            stylingModule:UpdateControlStripVisibility(frame, false)
        end
    end)

    renderer:SetScript("OnUpdate", function(selfRenderer, elapsed)
        local target = selfRenderer.targetScrollOffset or selfRenderer.scrollOffset or 0
        local current = selfRenderer.scrollOffset or 0
        if math.abs(target - current) > 0.5 then
            local smoothing = mathMin(1, elapsed * 14)
            selfRenderer.scrollOffset = current + ((target - current) * smoothing)
            ChatRendererModule:UpdateScrollState(selfRenderer)
        elseif current ~= target then
            selfRenderer.scrollOffset = target
            ChatRendererModule:UpdateScrollState(selfRenderer)
        end

        selfRenderer.fadeElapsed = (selfRenderer.fadeElapsed or 0) + elapsed
        if selfRenderer.fadeElapsed >= 0.05 then
            selfRenderer.fadeElapsed = 0
            for index, entry in ipairs(selfRenderer.entries or {}) do
                local row = selfRenderer.rows and selfRenderer.rows[index] or nil
                if row and row:IsShown() then
                    ChatRendererModule:UpdateRowOpacity(selfRenderer, row, entry)
                end
            end
        end
    end)

    frame:HookScript("OnSizeChanged", function()
        ChatRendererModule:RelayoutRenderer(renderer)
        if ChatRendererModule:IsAtBottom(renderer) then
            ChatRendererModule:ScrollToBottom(renderer)
        end
    end)

    return renderer
end

--- Reusable TwichUI context menu for right-clicking a chat message row.
local chatContextMenu = nil
local function GetChatContextMenu()
    if not chatContextMenu then
        chatContextMenu = T.Tools.UI.CreateSecureMenu("TwichUIChatContextMenu")
    end
    return chatContextMenu
end

--- Extracts the full player link target (e.g. "Name-Realm") from a message, or nil.
local function ExtractPlayerTarget(message)
    if not IsUsablePlainString(message) then return nil end
    return message:match("|Hplayer:([^:|]+)")
end

--- Shows a context menu for the given message row and entry.
function ChatRendererModule:ShowMessageContextMenu(row, entry)
    local menu = GetChatContextMenu()
    if not (menu and entry) then return end

    local playerTarget = ExtractPlayerTarget(entry.message)
    local shortName    = playerTarget and (playerTarget:match("^([^%-]+)") or playerTarget) or nil
    local rawText = ""
    if IsUsablePlainString(entry.message) then
        rawText = entry.message
        rawText = rawText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|C%x%x%x%x%x%x%x%x%x%x", "")
        rawText = rawText:gsub("|r", "")
        rawText = rawText:gsub("|H[^|]+|h%[([^%]]*)%]|h", "%1")
        rawText = rawText:gsub("|A.-|a", "")
        rawText = rawText:gsub("|T.-|t", "")
        rawText = rawText:gsub("|K.-|k", "")
    end

    local entries = {}

    -- Section title: player name or generic
    entries[#entries + 1] = {
        text = shortName and shortName or "Message",
        isTitle = true,
    }

    if shortName then
        entries[#entries + 1] = {
            text = "Whisper",
            func = function()
                local eb = _G.ChatFrame1EditBox
                if eb then
                    eb:SetText("/w " .. shortName .. " ")
                    eb:Show()
                    eb:SetFocus()
                end
            end,
        }
        entries[#entries + 1] = {
            text = "Invite to Party",
            macrotext = "/invite " .. (playerTarget or shortName),
        }
        entries[#entries + 1] = {
            text = "Ignore Player",
            macrotext = "/ignore " .. shortName,
        }
    end

    -- Copy message text to the system clipboard
    if rawText and rawText ~= "" then
        entries[#entries + 1] = {
            text = "Copy to Clipboard",
            func = function()
                PlayMenuSound("TwichUI-Menu-Confirm")
                -- CopyToClipboard is a protected function; the copy frame is the
                -- only available path. Defer by one tick so the menu's PostClick
                -- hide cycle completes before we claim keyboard focus.
                local stylingModule = GetStylingModule()
                if stylingModule and stylingModule.ShowRawTextCopyFrame then
                    C_Timer.After(0.05, function()
                        stylingModule:ShowRawTextCopyFrame(rawText)
                    end)
                end
            end,
        }
    end

    PlayMenuSound("TwichUI-Menu-Click")
    menu:SetEntries(entries)
    menu:Toggle(row, "TOPLEFT", "BOTTOMLEFT", 0, -4)
end

function ChatRendererModule:RefreshFrame(frame)
    if ShouldSkipFrame(frame) then
        return
    end

    local renderer = self:EnsureRenderer(frame)
    if not renderer then
        return
    end

    do
        local accentR, accentG, accentB = self:GetShellAccentColor()
        renderer:SetParent(frame)
        renderer:SetAllPoints(frame)
        renderer:SetFrameLevel(frame:GetFrameLevel() + 10)
        if renderer.LiveButton then
            T.Tools.UI.SkinTwichButton(renderer.LiveButton, { accentR, accentG, accentB })
        end
        if renderer.ScrollThumb then
            renderer.ScrollThumb:SetBackdropColor(accentR, accentG, accentB, 0.3)
            renderer.ScrollThumb:SetBackdropBorderColor(accentR, accentG, accentB, 0.45)
        end
        if renderer.ScrollTrack then
            renderer.ScrollTrack:SetBackdropBorderColor(accentR, accentG, accentB, 0.14)
        end
    end

    renderer:SetShown(self:IsEnabled())
    self:RefreshViewportInsetsForFrame(frame)

    if self:IsEnabled() and #(renderer.entries or {}) == 0 and type(frame.GetNumMessages) == "function" and
        (tonumber(frame:GetNumMessages()) or 0) > 0 then
        self:SeedFromChatFrame(frame)
    end
end

function ChatRendererModule:HookChatFrame(frame)
    if ShouldSkipFrame(frame) or frame.TwichUICustomRendererHooked or type(frame.AddMessage) ~= "function" then
        return
    end

    frame.TwichUICustomRendererHooked = true
    self:EnsureRenderer(frame)

    local originalAddMessage = frame.AddMessage
    local originalClear = frame.Clear
    local originalMouseWheel = frame:GetScript("OnMouseWheel")
    frame.TwichUIOriginalAddMessage = originalAddMessage
    frame.TwichUIOriginalClear = originalClear
    frame.TwichUIOriginalOnMouseWheel = originalMouseWheel

    frame.AddMessage = function(chatFrame, message, red, green, blue, accessID, ...)
        if ChatRendererModule:IsEnabled() and chatFrame.TwichUICustomRenderer then
            -- Keyword routing: if a routing rule matches and targets a different
            -- frame, redirect the message there instead of the current frame.
            local routeTarget = ChatRendererModule:ResolveRoutingTarget(message)
            if routeTarget and routeTarget ~= chatFrame then
                routeTarget.AddMessage(routeTarget, message, red, green, blue, accessID, ...)
                return
            end

            ChatRendererModule:PushMessage(chatFrame, message, red, green, blue, accessID)
            return
        end

        return originalAddMessage(chatFrame, message, red, green, blue, accessID, ...)
    end

    if type(originalClear) == "function" then
        frame.Clear = function(chatFrame, ...)
            if ChatRendererModule:IsEnabled() and chatFrame.TwichUICustomRenderer then
                ChatRendererModule:ClearRenderer(chatFrame)
            end

            return originalClear(chatFrame, ...)
        end
    end

    frame:EnableMouseWheel(true)
    frame:SetScript("OnMouseWheel", function(selfFrame, delta)
        if ChatRendererModule:IsEnabled() and selfFrame.TwichUICustomRenderer then
            HandleRendererMouseWheel(selfFrame.TwichUICustomRenderer, delta)
            return
        end

        if type(selfFrame.TwichUIOriginalOnMouseWheel) == "function" then
            return selfFrame.TwichUIOriginalOnMouseWheel(selfFrame, delta)
        end
    end)

    frame:HookScript("OnShow", function(selfFrame)
        if selfFrame.TwichUICustomRenderer then
            selfFrame.TwichUICustomRenderer:SetShown(ChatRendererModule:IsEnabled())
            ChatRendererModule:RelayoutRenderer(selfFrame.TwichUICustomRenderer)
            if ChatRendererModule:IsEnabled() and #(selfFrame.TwichUICustomRenderer.entries or {}) == 0 and
                type(selfFrame.GetNumMessages) == "function" and (tonumber(selfFrame:GetNumMessages()) or 0) > 0 then
                ChatRendererModule:SeedFromChatFrame(selfFrame)
            end
        end
    end)
end

function ChatRendererModule:HookAllFrames()
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        self:HookChatFrame(_G[frameName])
    end
end

function ChatRendererModule:RefreshAllFrames()
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        self:RefreshFrame(_G[frameName])
    end
end

function ChatRendererModule:QueueRefreshAllFrames(delay)
    if self.refreshAllTimer then
        self:CancelTimer(self.refreshAllTimer)
        self.refreshAllTimer = nil
    end

    local refreshDelay = delay or 0
    if refreshDelay <= 0 then
        self:RefreshAllFrames()
        return
    end

    self.refreshAllTimer = self:ScheduleTimer(function()
        self.refreshAllTimer = nil
        self:RefreshAllFrames()
    end, refreshDelay)
end

function ChatRendererModule:CancelLifecycleRefreshes()
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

function ChatRendererModule:HandleLifecycleRefresh()
    self:CancelLifecycleRefreshes()
    self:RefreshAllFrames()
    self.lifecycleRefreshTimers = {
        self:ScheduleTimer(function()
            ChatRendererModule:RefreshAllFrames()
        end, 0.1),
        self:ScheduleTimer(function()
            ChatRendererModule:RefreshAllFrames()
        end, 0.35),
    }
end

function ChatRendererModule:InstallFrameHooks()
    if self.frameHooksInstalled then
        return
    end

    self.frameHooksInstalled = true

    if type(_G.FCF_OpenTemporaryWindow) == "function" then
        hooksecurefunc("FCF_OpenTemporaryWindow", function()
            ChatRendererModule:HookAllFrames()
            ChatRendererModule:RefreshAllFrames()
        end)
    end

    if type(_G.FCF_OpenNewWindow) == "function" then
        hooksecurefunc("FCF_OpenNewWindow", function()
            ChatRendererModule:HookAllFrames()
            ChatRendererModule:RefreshAllFrames()
        end)
    end

    if type(_G.FCFDock_SelectWindow) == "function" then
        hooksecurefunc("FCFDock_SelectWindow", function(_, frame)
            if frame then
                ChatRendererModule:RefreshFrame(frame)
            end
            ChatRendererModule:QueueRefreshAllFrames(0)
        end)
    end

    if type(_G.FCFDock_UpdateTabs) == "function" then
        hooksecurefunc("FCFDock_UpdateTabs", function()
            ChatRendererModule:QueueRefreshAllFrames(0)
        end)
    end

    if type(_G.ChatFrame_ChatPageUp) == "function" then
        hooksecurefunc("ChatFrame_ChatPageUp", function(frame)
            local target = frame or _G.SELECTED_CHAT_FRAME
            if target and target.TwichUICustomRenderer then
                -- PageUp = show older messages = increase scrollOffset toward maxScroll
                ChatRendererModule:ScrollBy(target.TwichUICustomRenderer,
                    target.TwichUICustomRenderer.Viewport:GetHeight() * 0.9)
            end
        end)
    end

    if type(_G.ChatFrame_ChatPageDown) == "function" then
        hooksecurefunc("ChatFrame_ChatPageDown", function(frame)
            local target = frame or _G.SELECTED_CHAT_FRAME
            if target and target.TwichUICustomRenderer then
                -- PageDown = show newer messages = decrease scrollOffset toward 0
                ChatRendererModule:ScrollBy(target.TwichUICustomRenderer,
                    -(target.TwichUICustomRenderer.Viewport:GetHeight() * 0.9))
            end
        end)
    end

    if type(_G.ChatFrame_ScrollToBottom) == "function" then
        hooksecurefunc("ChatFrame_ScrollToBottom", function(frame)
            local target = frame or _G.SELECTED_CHAT_FRAME
            if target and target.TwichUICustomRenderer then
                ChatRendererModule:ScrollToBottom(target.TwichUICustomRenderer)
            end
        end)
    end
end

function ChatRendererModule:OnEnable()
    self.classCache = self.classCache or {}
    self:RefreshSettings()
    self:InstallFrameHooks()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "HandleLifecycleRefresh")
    self:RegisterEvent("UPDATE_CHAT_WINDOWS", "HandleLifecycleRefresh")
    self:RegisterEvent("UPDATE_FLOATING_CHAT_WINDOWS", "HandleLifecycleRefresh")
    for _, eventName in ipairs(CLASS_CACHE_EVENTS) do
        self:RegisterEvent(eventName, "CacheClassFromEvent")
    end
    self:HookAllFrames()
    self:RefreshAllFrames()
    self:LogDebug("chat renderer enabled", false)

    if type(ChatFrame_AddMessageEventFilter) == "function" and not self.addonFilterRegistered then
        self.addonFilterRegistered = true
        self.addonFilterHandler = self.addonFilterHandler or function(...)
            return ChatRendererModule:HandleAddonMessage(...)
        end
        ChatFrame_AddMessageEventFilter("CHAT_MSG_ADDON", self.addonFilterHandler)
    end

    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        if frame and frame.TwichUICustomRenderer and #frame.TwichUICustomRenderer.entries == 0 then
            self:SeedFromChatFrame(frame)
        end
    end

    self:HandleLifecycleRefresh()
end

function ChatRendererModule:OnDisable()
    self:RefreshSettings()
    if self.refreshAllTimer then
        self:CancelTimer(self.refreshAllTimer)
        self.refreshAllTimer = nil
    end
    self:CancelLifecycleRefreshes()
    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("UPDATE_CHAT_WINDOWS")
    self:UnregisterEvent("UPDATE_FLOATING_CHAT_WINDOWS")
    for _, eventName in ipairs(CLASS_CACHE_EVENTS) do
        self:UnregisterEvent(eventName)
    end
    if self.addonFilterRegistered and type(ChatFrame_RemoveMessageEventFilter) == "function" then
        self.addonFilterRegistered = false
        ChatFrame_RemoveMessageEventFilter("CHAT_MSG_ADDON", self.addonFilterHandler)
    end
    for _, frameName in ipairs(CHAT_FRAMES or {}) do
        local frame = _G[frameName]
        if frame and frame.TwichUICustomRenderer then
            frame.TwichUICustomRenderer:Hide()
        end
    end
end

if DebugConsole and DebugConsole.RegisterSource then
    DebugConsole:RegisterSource(DEBUG_SOURCE_KEY, {
        title = "Chat",
        order = 22,
        aliases = { "chatenhancements", "chatshell", "chatrenderer" },
        maxLines = 160,
        isEnabled = function()
            local options = GetOptions()
            return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
        end,
        buildReport = function()
            return ChatRendererModule:BuildDebugReport()
        end,
    })
end
