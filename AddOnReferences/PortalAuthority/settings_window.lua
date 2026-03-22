local PortalAuthority = PortalAuthority

if not PortalAuthority then
    return
end

local WINDOW_NAME = "PortalAuthoritySettingsWindow"
local WINDOW_WIDTH = 876
local WINDOW_HEIGHT = 630
local SIDEBAR_WIDTH = 210
local CONTENT_WIDTH = 665
local HEADER_HEIGHT = 72
local HEADER_TITLE_TOP_INSET = 24
local HEADER_BADGE_TEXT_ACTIVE = "ACTIVE"
local HEADER_BADGE_TEXT_INACTIVE = "INACTIVE"
local HEADER_BADGE_HORIZONTAL_PADDING = 16
local HEADER_BADGE_VERTICAL_PADDING = 5
local HEADER_BADGE_PRESS_SCALE = 0.95
local HEADER_BADGE_PRESS_DURATION = 0.10
local HEADER_BADGE_COLOR_DURATION = 0.30
local NAV_ROW_HEIGHT = 34
local NAV_ROW_SPACING = 4
local OPEN_FADE_DURATION = 0.15
local GLIDE_DURATION = 0.30
local HINT_FADE_DURATION = 0.25
local SEARCH_MIN_QUERY_CHARS = 2
local SEARCH_DROPDOWN_MAX_RESULTS = 6
local SEARCH_RESULT_ROW_HEIGHT = 36
local SEARCH_SECTION_HEADER_HEIGHT = 18
local SEARCH_SECTION_HEADER_GAP = 6
local SEARCH_DROPDOWN_MAX_HEIGHT = 252
local SEARCH_DROPDOWN_SCROLL_STEP = 24
local SEARCH_RESULT_ICON_SIZE = 14
local SEARCH_DROPDOWN_EDGE_FADE_HEIGHT = 16
local SEARCH_DROPDOWN_CONTENT_TOP_PADDING = 8
local SEARCH_DROPDOWN_CONTENT_BOTTOM_PADDING = 8
local SEARCH_DROPDOWN_NO_RESULTS_HEIGHT = 52
local SEARCH_DROPDOWN_FADE_DURATION = 0.25
local SEARCH_DROPDOWN_SHIMMER_DELAY = 0.20
local SEARCH_DROPDOWN_SHIMMER_DURATION = 1.20
local SEARCH_DROPDOWN_SHIMMER_WIDTH = 40
local SEARCH_DROPDOWN_GLOW_HEIGHT = 3
local SEARCH_DROPDOWN_GLOW_DURATION = 0.40
local SEARCH_HIGHLIGHT_ENTRY_DURATION = 0.30
local SEARCH_HIGHLIGHT_SETTLE_DURATION = 0.20
local SEARCH_HIGHLIGHT_HOLD_DURATION = 1.00
local SEARCH_HIGHLIGHT_FADE_DURATION = 0.80
local SEARCH_INTRO_DELAY = 0.80
local SEARCH_INTRO_DURATION = 2.50
local SEARCH_INTRO_PULSE_DURATION = 0.50
local SEARCH_INTRO_GLOW_ALPHA = 0.20
local SEARCH_INTRO_PULSE_OFFSETS = { 0.0, 0.70, 1.40 }
local SEARCH_CLICK_DEBUG = false
local SearchTargetAudit = { enabled = false }
local HOSTABLE_SECTION_REGISTRY_KEYS = {
    root = "root",
    announcements = "announcements",
    dock = "dock",
    timers = "timers",
    interrupt = "interrupt",
    combat = "combat",
    keystone = "keystone",
    profiles = "profiles",
}
local HEADER_TOGGLE_SECTION_KEYS = {
    dock = true,
    timers = true,
    interrupt = true,
    combat = true,
}

local PANEL_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Buttons\\WHITE8x8",
    edgeSize = 1,
}

local function trim(value)
    if type(value) ~= "string" then
        return ""
    end
    return value:match("^%s*(.-)%s*$") or ""
end

local function hexToColor(hex, alpha)
    if type(hex) ~= "string" then
        return 1, 1, 1, alpha == nil and 1 or alpha
    end

    hex = hex:gsub("#", "")
    if #hex ~= 6 then
        return 1, 1, 1, alpha == nil and 1 or alpha
    end

    local r = tonumber(hex:sub(1, 2), 16) or 255
    local g = tonumber(hex:sub(3, 4), 16) or 255
    local b = tonumber(hex:sub(5, 6), 16) or 255
    return r / 255, g / 255, b / 255, alpha == nil and 1 or alpha
end

local function rgba255(r, g, b, a)
    return (tonumber(r) or 255) / 255,
        (tonumber(g) or 255) / 255,
        (tonumber(b) or 255) / 255,
        a == nil and 1 or math.max(0, math.min(1, tonumber(a) or 1))
end

local SHELL_STYLE = {
    windowBg = { rgba255(8, 11, 15, 1.0) },
    windowBorder = { rgba255(27, 33, 41, 1.0) },
    sidebarBg = { rgba255(11, 14, 18, 1.0) },
    sidebarDivider = { rgba255(22, 29, 36, 1.0) },
    sectionDivider = { rgba255(25, 31, 39, 0.80) },
    searchBg = { rgba255(26, 28, 36, 0.95) },
    searchBorderIdle = { hexToColor("#1a1a28", 1.0) },
    searchBorderFocus = { rgba255(155, 48, 255, 0.25) },
    searchText = { rgba255(208, 212, 220, 1.0) },
    searchPlaceholder = { hexToColor("#3a3a4a", 1.0) },
    searchIcon = { hexToColor("#3a3a4a", 1.0) },
    navActiveText = { hexToColor("#c4bef0", 1.0) },
    navIdleText = { rgba255(111, 121, 136, 1.0) },
    navHoverText = { rgba255(204, 210, 220, 1.0) },
    navTeaserText = { hexToColor("#3a3e48", 1.0) },
    navSoonBadgeText = { hexToColor("#8b7ef0", 1.0) },
    navSoonBadgeBg = { rgba255(139, 126, 240, 0.08) },
    navSoonBadgeBorder = { rgba255(139, 126, 240, 0.18) },
    navWash = { rgba255(155, 48, 255, 0.06) },
    indicatorGlow = { rgba255(155, 48, 255, 0.35) },
    indicatorBar = { hexToColor("#9b30ff", 0.70) },
    headerBg = { rgba255(10, 13, 18, 1.0) },
    headerDivider = { rgba255(23, 29, 36, 1.0) },
    headerTitle = { rgba255(232, 235, 240, 1.0) },
    headerDescriptor = { rgba255(133, 141, 154, 1.0) },
    wordmark = { rgba255(196, 200, 208, 1.0) },
    homeHint = { rgba255(105, 111, 123, 1.0) },
    closeBorderIdle = { rgba255(35, 42, 50, 1.0) },
    closeBorderHover = { rgba255(131, 71, 76, 1.0) },
    closeTextIdle = { rgba255(146, 152, 164, 1.0) },
    closeTextHover = { rgba255(221, 150, 150, 1.0) },
}

local SEARCH_INTRO_GLOW_COLOR = { rgba255(107, 94, 207, 1.0) }
local SEARCH_INTRO_BORDER_COLOR = { rgba255(107, 94, 207, 0.55) }
local SEARCH_DROPDOWN_BG_COLOR = { hexToColor("#0a0a10", 1.0) }
local SEARCH_DROPDOWN_BORDER_COLOR = { hexToColor("#1a1a28", 1.0) }
local SEARCH_DROPDOWN_SHADOW_COLOR = { rgba255(0, 0, 0, 0.40) }
local SEARCH_RESULT_TEXT_COLOR = { hexToColor("#cccccc", 1.0) }
local SEARCH_RESULT_HELPER_COLOR = { hexToColor("#444444", 1.0) }
local SEARCH_RESULT_SECTION_COLOR = { hexToColor("#9b93c9", 1.0) }
local SEARCH_RESULT_GROUP_TITLE_COLOR = { hexToColor("#555555", 1.0) }
local SEARCH_GROUP_HEADER_COLOR = { hexToColor("#3a3a4a", 1.0) }
local SEARCH_RESULT_HOVER_WASH = { rgba255(155, 48, 255, 0.04) }
local SEARCH_RESULT_MATCH_COLOR = { hexToColor("#5bbfb5", 1.0) }
local SEARCH_GROUP_DIVIDER_COLOR = { rgba255(32, 38, 48, 1.0) }
local SEARCH_OVERFLOW_FADE_COLOR = { rgba255(10, 10, 16, 0.85) }
local SEARCH_OVERFLOW_SHIMMER_COLOR = { rgba255(91, 191, 181, 0.06) }
local SEARCH_OVERFLOW_GLOW_COLOR = { rgba255(91, 191, 181, 0.18) }
local SEARCH_HIGHLIGHT_WASH_COLOR = {
    entry = { rgba255(40, 130, 122, 0.25) },
    settled = { rgba255(40, 130, 122, 0.12) },
}
local SEARCH_HIGHLIGHT_EDGE_COLOR = {
    entry = { rgba255(40, 130, 122, 0.65) },
    settled = { rgba255(40, 130, 122, 0.40) },
}
local SEARCH_NO_RESULTS_LINES = {
    "By the tides... no results found.",
    "Searched Yet's browser history... no results found.",
    "BMI calculated... no results found.",
    "Twiggle tried... no results found.",
    "Gooby wooby... no results found.",
}

local HEADER_BADGE_STYLE = {
    onBg = { rgba255(18, 48, 52, 0.60) },
    onBorder = { rgba255(40, 130, 120, 0.35) },
    onText = { rgba255(170, 240, 230, 0.85) },
    onHoverBg = { rgba255(18, 48, 52, 0.75) },
    onHoverBorder = { rgba255(40, 130, 120, 0.55) },
    offBg = { rgba255(48, 14, 30, 0.70) },
    offBorder = { rgba255(80, 25, 45, 0.70) },
    offText = { rgba255(220, 185, 200, 0.90) },
    offHoverBg = { rgba255(55, 18, 35, 0.80) },
    offHoverBorder = { rgba255(100, 35, 55, 0.80) },
}

local function unpackColor(color)
    if type(color) ~= "table" then
        return 1, 1, 1, 1
    end
    return color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1
end

local wipeTable = table.wipe or wipe or function(target)
    if type(target) ~= "table" then
        return {}
    end
    for key in pairs(target) do
        target[key] = nil
    end
    return target
end

local function setHorizontalGradient(texture, leftColor, rightColor)
    if not texture then
        return
    end

    local leftR, leftG, leftB, leftA = unpackColor(leftColor)
    local rightR, rightG, rightB, rightA = unpackColor(rightColor)
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha("HORIZONTAL", leftR, leftG, leftB, leftA, rightR, rightG, rightB, rightA)
    elseif texture.SetGradient and CreateColor then
        texture:SetGradient(
            "HORIZONTAL",
            CreateColor(leftR, leftG, leftB, leftA),
            CreateColor(rightR, rightG, rightB, rightA)
        )
    else
        texture:SetColorTexture(
            (leftR + rightR) * 0.5,
            (leftG + rightG) * 0.5,
            (leftB + rightB) * 0.5,
            (leftA + rightA) * 0.5
        )
    end
end

local function setVerticalGradient(texture, topColor, bottomColor)
    if not texture then
        return
    end

    local topR, topG, topB, topA = unpackColor(topColor)
    local bottomR, bottomG, bottomB, bottomA = unpackColor(bottomColor)
    if texture.SetGradientAlpha then
        texture:SetGradientAlpha("VERTICAL", topR, topG, topB, topA, bottomR, bottomG, bottomB, bottomA)
    elseif texture.SetGradient and CreateColor then
        texture:SetGradient(
            "VERTICAL",
            CreateColor(topR, topG, topB, topA),
            CreateColor(bottomR, bottomG, bottomB, bottomA)
        )
    else
        texture:SetColorTexture(
            (topR + bottomR) * 0.5,
            (topG + bottomG) * 0.5,
            (topB + bottomB) * 0.5,
            (topA + bottomA) * 0.5
        )
    end
end

local function applyPremiumFont(target, size, flags, fallbackObject)
    if PortalAuthority.ApplyPremiumAuthoredFont then
        PortalAuthority:ApplyPremiumAuthoredFont(target, size, flags or "")
        return
    end
    if target and target.SetFontObject and fallbackObject then
        target:SetFontObject(fallbackObject)
    end
end

local function ensureRuntime(self)
    if type(self._settingsWindowRuntime) ~= "table" then
        self._settingsWindowRuntime = {
            currentSectionKey = nil,
            activeNavKey = nil,
            lastSelectedSectionKey = nil,
            hostedPanelKey = nil,
            hostedPanelFrame = nil,
            panelParkingFrame = nil,
            externalPanelParents = {},
            position = nil,
            fadeToken = 0,
            glideToken = 0,
            hintToken = 0,
            headerAccessorySource = nil,
            headerAccessorySectionKey = nil,
            headerAccessoryRefreshActive = false,
            headerAccessoryRefreshPending = false,
            headerAccessoryRefreshGeneration = 0,
            lastError = nil,
            searchFocused = false,
            searchGlowIntensity = 0,
            searchIntroScheduleToken = 0,
            searchGlowToken = 0,
            searchCatalogInitialized = false,
            searchCatalogRevision = 0,
            searchCatalogRefs = {},
            searchCatalogSections = {},
            searchFilteredResults = {},
            searchScratchResults = {},
            searchActiveQuery = "",
            searchPreviousQuery = "",
            searchPreviousCatalogRevision = 0,
            searchDropdownVisible = false,
            searchDropdownInteractionGuard = false,
            searchResultClickState = "idle",
            searchResultClickToken = 0,
            searchResultClickEntry = nil,
            searchResultCommitOwnerToken = nil,
            searchResultReleaseWatcherToken = 0,
            searchSuppressTextChanged = false,
            searchSelectionToken = 0,
            searchHighlightToken = 0,
            searchHighlightQueuedToken = 0,
            searchDropdownOpenToken = 0,
            searchDropdownTopFadeToken = 0,
            searchDropdownBottomFadeToken = 0,
            searchDropdownShimmerToken = 0,
            searchDropdownShimmerPlayedToken = 0,
            searchDropdownTopGlowToken = 0,
            searchDropdownBottomGlowToken = 0,
            activeNoResultsMessage = nil,
            navButtons = {},
            shellOwnedFrames = {},
        }
    end
    return self._settingsWindowRuntime
end

local function setLastError(self, message)
    local runtime = ensureRuntime(self)
    runtime.lastError = message
end

local function clearLastError(self)
    local runtime = ensureRuntime(self)
    runtime.lastError = nil
end

local function getSectionMeta(self)
    if type(self.settingsWindowSectionMeta) == "table" then
        return self.settingsWindowSectionMeta
    end
    return {}
end

local function getSectionState(self, sectionKey)
    local runtime = ensureRuntime(self)
    local meta = getSectionMeta(self)
    local descriptor = meta[sectionKey]
    if type(descriptor) ~= "table" then
        return nil
    end
    return descriptor, runtime
end

local function getSettingsPanelRegistry(self)
    if self.GetSettingsPanelRegistry then
        local registry = self:GetSettingsPanelRegistry()
        if type(registry) == "table" then
            return registry
        end
    end
    return type(self.settingsPanelRegistry) == "table" and self.settingsPanelRegistry or {}
end

local function isHostableSectionKey(sectionKey)
    return type(sectionKey) == "string" and HOSTABLE_SECTION_REGISTRY_KEYS[sectionKey] ~= nil
end

local function getHostablePanelEntry(self, sectionKey)
    local registryKey = HOSTABLE_SECTION_REGISTRY_KEYS[sectionKey]
    if not registryKey then
        return nil
    end

    local registry = getSettingsPanelRegistry(self)
    local entry = registry and registry[registryKey] or nil
    if entry and entry.panel then
        return entry
    end

    if sectionKey == "root" and self.rootPanel then
        return {
            key = "root",
            panel = self.rootPanel,
        }
    end

    return nil
end

local function getDefaultSectionKey(self)
    local runtime = ensureRuntime(self)
    local lastKey = runtime.lastSelectedSectionKey
    if type(lastKey) == "string" and self:NormalizeSettingsWindowSectionKey(lastKey) then
        return self:NormalizeSettingsWindowSectionKey(lastKey)
    end
    return "announcements"
end

local function ensureSpecialFrame(name)
    if type(name) ~= "string" or name == "" or type(UISpecialFrames) ~= "table" then
        return
    end
    for i = 1, #UISpecialFrames do
        if UISpecialFrames[i] == name then
            return
        end
    end
    table.insert(UISpecialFrames, name)
end

local function stopFrameAnimation(owner)
    if owner and owner.SetScript then
        owner:SetScript("OnUpdate", nil)
    end
end

local function easeInOut(progress)
    progress = math.max(0, math.min(1, progress or 0))
    return progress * progress * (3 - (2 * progress))
end

local function startAlphaTween(owner, runtime, tokenField, fromAlpha, toAlpha, duration, onFinished)
    if not owner or not runtime then
        return
    end

    runtime[tokenField] = (tonumber(runtime[tokenField]) or 0) + 1
    local token = runtime[tokenField]
    local elapsed = 0

    owner:SetAlpha(fromAlpha)
    owner:SetScript("OnUpdate", function(self, delta)
        if runtime[tokenField] ~= token then
            self:SetScript("OnUpdate", nil)
            return
        end

        elapsed = elapsed + (delta or 0)
        local progress = duration > 0 and easeInOut(elapsed / duration) or 1
        self:SetAlpha(fromAlpha + ((toAlpha - fromAlpha) * progress))
        if progress >= 1 then
            self:SetAlpha(toAlpha)
            self:SetScript("OnUpdate", nil)
            if onFinished then
                onFinished(self)
            end
        end
    end)
end

local function captureWindowPosition(self)
    local runtime = ensureRuntime(self)
    local frame = runtime.window
    if not frame or not frame.GetCenter or not UIParent or not UIParent.GetCenter then
        return
    end

    local centerX, centerY = frame:GetCenter()
    local parentX, parentY = UIParent:GetCenter()
    if not centerX or not centerY or not parentX or not parentY then
        return
    end

    runtime.position = {
        point = "CENTER",
        relativePoint = "CENTER",
        x = centerX - parentX,
        y = centerY - parentY,
    }
end

local function applyWindowPosition(self)
    local runtime = ensureRuntime(self)
    local frame = runtime.window
    if not frame then
        return
    end

    frame:ClearAllPoints()
    if type(runtime.position) == "table" then
        frame:SetPoint(
            runtime.position.point or "CENTER",
            UIParent,
            runtime.position.relativePoint or "CENTER",
            tonumber(runtime.position.x) or 0,
            tonumber(runtime.position.y) or 0
        )
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

local function closeBlizzardSettings()
    if Settings and type(Settings.CloseSettings) == "function" then
        pcall(Settings.CloseSettings)
    end
    if Settings and type(Settings.Close) == "function" then
        pcall(Settings.Close)
    end

    local settingsPanel = PortalAuthority.CpuDiagGetSettingsPanelFrame and PortalAuthority:CpuDiagGetSettingsPanelFrame() or nil
    if settingsPanel and settingsPanel.IsShown and settingsPanel:IsShown() and settingsPanel.Hide then
        settingsPanel:Hide()
    end
end

local function updateSearchPlaceholder(runtime)
    local searchEdit = runtime and runtime.searchEdit or nil
    local placeholder = runtime and runtime.searchPlaceholder or nil
    if not searchEdit or not placeholder then
        return
    end

    local text = searchEdit.GetText and searchEdit:GetText() or ""
    local hasFocus = searchEdit.HasFocus and searchEdit:HasFocus() or false
    local shouldShow = trim(text) == "" and not hasFocus
    if placeholder.SetShown then
        placeholder:SetShown(shouldShow)
    elseif shouldShow then
        placeholder:Show()
    else
        placeholder:Hide()
    end
end

local function getAnnouncementReleaseVersion()
    if PortalAuthority and PortalAuthority.GetAnnouncementReleaseVersionString then
        local version = trim(tostring(PortalAuthority:GetAnnouncementReleaseVersionString() or ""))
        if version ~= "" then
            return version
        end
    end
    return nil
end

local function getSearchIntroSeenVersion()
    if PortalAuthority and PortalAuthority.Profiles_GetSettingsWindowSearchIntroSeenVersion then
        local version = trim(tostring(PortalAuthority:Profiles_GetSettingsWindowSearchIntroSeenVersion() or ""))
        if version ~= "" then
            return version
        end
    end
    return nil
end

local function shouldPlaySearchIntroGlow()
    local releaseVersion = getAnnouncementReleaseVersion()
    if not releaseVersion then
        return false, nil
    end
    return getSearchIntroSeenVersion() ~= releaseVersion, releaseVersion
end

local lerpColor

local function applySearchBorderVisual(runtime)
    local searchBox = runtime and runtime.searchBox or nil
    if not searchBox or not searchBox.SetBackdropBorderColor then
        return
    end

    local intensity = math.max(0, math.min(1, tonumber(runtime.searchGlowIntensity) or 0))
    if intensity > 0 then
        searchBox:SetBackdropBorderColor(unpackColor(lerpColor(SHELL_STYLE.searchBorderIdle, SEARCH_INTRO_BORDER_COLOR, intensity)))
    elseif runtime.searchFocused then
        searchBox:SetBackdropBorderColor(unpackColor(SHELL_STYLE.searchBorderFocus))
    else
        searchBox:SetBackdropBorderColor(unpackColor(SHELL_STYLE.searchBorderIdle))
    end

    local searchGlowTexture = runtime and runtime.searchGlowTexture or nil
    if searchGlowTexture and searchGlowTexture.SetAlpha then
        searchGlowTexture:SetAlpha(SEARCH_INTRO_GLOW_ALPHA * intensity)
    end
end

local function updateSearchBorder(runtime, focused)
    if not runtime then
        return
    end
    runtime.searchFocused = focused and true or false
    applySearchBorderVisual(runtime)
end

local function getSearchIntroPulseIntensity(elapsed)
    local intensity = 0
    for i = 1, #SEARCH_INTRO_PULSE_OFFSETS do
        local startAt = SEARCH_INTRO_PULSE_OFFSETS[i]
        local endAt = startAt + SEARCH_INTRO_PULSE_DURATION
        if elapsed >= startAt and elapsed <= endAt then
            local pulseProgress = SEARCH_INTRO_PULSE_DURATION > 0 and ((elapsed - startAt) / SEARCH_INTRO_PULSE_DURATION) or 1
            local shapedProgress
            if pulseProgress <= 0.5 then
                shapedProgress = easeInOut(pulseProgress / 0.5)
            else
                shapedProgress = easeInOut((1 - pulseProgress) / 0.5)
            end
            intensity = math.max(intensity, shapedProgress)
        end
    end
    return intensity
end

local function stopSearchIntroGlow(runtime)
    if not runtime then
        return
    end
    runtime.searchIntroScheduleToken = (tonumber(runtime.searchIntroScheduleToken) or 0) + 1
    runtime.searchGlowToken = (tonumber(runtime.searchGlowToken) or 0) + 1
    runtime.searchGlowIntensity = 0
    if runtime.searchBox and runtime.searchBox.SetScript then
        runtime.searchBox:SetScript("OnUpdate", nil)
    end
    applySearchBorderVisual(runtime)
end

local function startSearchIntroGlow(self, releaseVersion)
    local runtime = ensureRuntime(self)
    local searchBox = runtime.searchBox
    if not searchBox or not searchBox.SetScript then
        return false
    end

    runtime.searchGlowToken = (tonumber(runtime.searchGlowToken) or 0) + 1
    local token = runtime.searchGlowToken
    runtime.searchGlowIntensity = 0
    if PortalAuthority and PortalAuthority.Profiles_SetSettingsWindowSearchIntroSeenVersion then
        PortalAuthority:Profiles_SetSettingsWindowSearchIntroSeenVersion(releaseVersion)
    end
    applySearchBorderVisual(runtime)

    local elapsed = 0
    searchBox:SetScript("OnUpdate", function(selfBox, delta)
        if runtime.searchGlowToken ~= token then
            selfBox:SetScript("OnUpdate", nil)
            return
        end

        elapsed = elapsed + (delta or 0)
        runtime.searchGlowIntensity = getSearchIntroPulseIntensity(elapsed)
        applySearchBorderVisual(runtime)
        if elapsed >= SEARCH_INTRO_DURATION then
            runtime.searchGlowIntensity = 0
            applySearchBorderVisual(runtime)
            selfBox:SetScript("OnUpdate", nil)
        end
    end)
    return true
end

local function scheduleSearchIntroGlowAfterOpen(self)
    local runtime = ensureRuntime(self)
    local frame = runtime.window
    local shouldPlay, releaseVersion = shouldPlaySearchIntroGlow()
    if not shouldPlay or not frame or not (frame.IsShown and frame:IsShown()) then
        return false
    end

    runtime.searchIntroScheduleToken = (tonumber(runtime.searchIntroScheduleToken) or 0) + 1
    local token = runtime.searchIntroScheduleToken
    if not (C_Timer and C_Timer.After) then
        return startSearchIntroGlow(self, releaseVersion)
    end

    C_Timer.After(SEARCH_INTRO_DELAY, function()
        if not PortalAuthority then
            return
        end

        local currentRuntime = ensureRuntime(PortalAuthority)
        if currentRuntime.searchIntroScheduleToken ~= token then
            return
        end

        local currentFrame = currentRuntime.window
        if not currentFrame or not (currentFrame.IsShown and currentFrame:IsShown()) then
            return
        end

        local shouldStart, currentReleaseVersion = shouldPlaySearchIntroGlow()
        if not shouldStart then
            return
        end

        startSearchIntroGlow(PortalAuthority, currentReleaseVersion)
    end)
    return true
end

local function updateHeader(self)
    local runtime = ensureRuntime(self)
    local meta = getSectionMeta(self)
    local sectionKey = runtime.currentSectionKey or "announcements"
    local section = meta[sectionKey] or meta.announcements or {}

    if runtime.headerTitle then
        runtime.headerTitle:SetText(section.title or "")
    end
    if runtime.headerDescriptor then
        runtime.headerDescriptor:SetText(section.descriptor or "")
    end
end

local updateNavState
local clearSearchHighlight
local isPanelCorrectlyHosted
local refreshHeaderAccessory
local applyHeaderAccessorySelection

local function setHeaderAccessoryCursor(active)
    if ResetCursor then
        pcall(ResetCursor)
    end
end

local function cloneColor(color)
    return {
        color and color[1] or 1,
        color and color[2] or 1,
        color and color[3] or 1,
        color and color[4] or 1,
    }
end

function lerpColor(fromColor, toColor, progress)
    local fromR, fromG, fromB, fromA = unpackColor(fromColor)
    local toR, toG, toB, toA = unpackColor(toColor)
    return {
        fromR + ((toR - fromR) * progress),
        fromG + ((toG - fromG) * progress),
        fromB + ((toB - fromB) * progress),
        fromA + ((toA - fromA) * progress),
    }
end

local function createHeaderStatusBadgeAccessory(parent)
    local spec = {}
    local wrapper = CreateFrame("Frame", nil, parent)
    wrapper._paSettingsWindowVisualStyleOptIn = true

    local control = CreateFrame("Button", nil, wrapper, "BackdropTemplate")
    control:SetBackdrop(PANEL_BACKDROP)
    control:SetPoint("CENTER", wrapper, "CENTER", 0, 0)
    control._paSettingsWindowVisualStyleOptIn = true
    control._visualValue = false
    control._enabled = true
    control._hovered = false
    control._pressed = false
    control._displayScale = 1.0
    control._colorToken = 0
    control._scaleToken = 0
    control._currentBg = cloneColor(HEADER_BADGE_STYLE.offBg)
    control._currentBorder = cloneColor(HEADER_BADGE_STYLE.offBorder)
    control._currentText = cloneColor(HEADER_BADGE_STYLE.offText)

    local label = control:CreateFontString(nil, "ARTWORK")
    label:SetPoint("CENTER", control, "CENTER", 0, 0)
    label:SetJustifyH("CENTER")
    label:SetJustifyV("MIDDLE")
    label:SetWordWrap(false)
    if label.SetNonSpaceWrap then
        label:SetNonSpaceWrap(false)
    end
    if label.SetMaxLines then
        label:SetMaxLines(1)
    end
    applyPremiumFont(label, 10, "", GameFontHighlightSmall)

    local function computeBadgeDimensions()
        label:SetText(HEADER_BADGE_TEXT_ACTIVE)
        local activeW = math.ceil(label:GetStringWidth() or 0)
        local activeH = math.ceil(label:GetStringHeight() or 0)
        label:SetText(HEADER_BADGE_TEXT_INACTIVE)
        local inactiveW = math.ceil(label:GetStringWidth() or 0)
        local inactiveH = math.ceil(label:GetStringHeight() or 0)
        local textW = math.max(activeW, inactiveW)
        local textH = math.max(activeH, inactiveH)
        local width = math.max(1, textW + (HEADER_BADGE_HORIZONTAL_PADDING * 2))
        local height = math.max(1, textH + (HEADER_BADGE_VERTICAL_PADDING * 2))
        label:SetWidth(textW)
        wrapper:SetSize(width, height)
        control:SetSize(width, height)
    end

    local function getTargetColors()
        local visualValue = control._visualValue and true or false
        local hovered = control._enabled ~= false and control._hovered and true or false
        local bgColor
        local borderColor
        local textColor
        if visualValue then
            bgColor = hovered and HEADER_BADGE_STYLE.onHoverBg or HEADER_BADGE_STYLE.onBg
            borderColor = hovered and HEADER_BADGE_STYLE.onHoverBorder or HEADER_BADGE_STYLE.onBorder
            textColor = HEADER_BADGE_STYLE.onText
        else
            bgColor = hovered and HEADER_BADGE_STYLE.offHoverBg or HEADER_BADGE_STYLE.offBg
            borderColor = hovered and HEADER_BADGE_STYLE.offHoverBorder or HEADER_BADGE_STYLE.offBorder
            textColor = HEADER_BADGE_STYLE.offText
        end
        return bgColor, borderColor, textColor
    end

    local function applyRenderedVisual(bgColor, borderColor, textColor)
        control:SetBackdropColor(unpackColor(bgColor))
        control:SetBackdropBorderColor(unpackColor(borderColor))
        label:SetTextColor(unpackColor(textColor))
        control:SetAlpha(control._enabled ~= false and 1 or 0.72)
        control:SetScale(control._displayScale or 1.0)
    end

    local function refreshAnimationDriver()
        if not wrapper or not wrapper.SetScript then
            return
        end
        local hasScale = type(control._scaleTween) == "table"
        local hasColor = type(control._colorTween) == "table"
        if not hasScale and not hasColor then
            wrapper:SetScript("OnUpdate", nil)
            return
        end
        wrapper:SetScript("OnUpdate", function(self, delta)
            local needsMore = false
            if type(control._scaleTween) == "table" then
                local tween = control._scaleTween
                tween.elapsed = (tonumber(tween.elapsed) or 0) + (delta or 0)
                local progress = tween.duration > 0 and math.min(1, tween.elapsed / tween.duration) or 1
                local eased = easeInOut(progress)
                control._displayScale = tween.start + ((tween.target - tween.start) * eased)
                if progress >= 1 then
                    control._displayScale = tween.target
                    control._scaleTween = nil
                else
                    needsMore = true
                end
            end

            if type(control._colorTween) == "table" then
                local tween = control._colorTween
                tween.elapsed = (tonumber(tween.elapsed) or 0) + (delta or 0)
                local progress = tween.duration > 0 and math.min(1, tween.elapsed / tween.duration) or 1
                local eased = easeInOut(progress)
                control._currentBg = lerpColor(tween.startBg, tween.targetBg, eased)
                control._currentBorder = lerpColor(tween.startBorder, tween.targetBorder, eased)
                control._currentText = lerpColor(tween.startText, tween.targetText, eased)
                if progress >= 1 then
                    control._currentBg = cloneColor(tween.targetBg)
                    control._currentBorder = cloneColor(tween.targetBorder)
                    control._currentText = cloneColor(tween.targetText)
                    control._colorTween = nil
                else
                    needsMore = true
                end
            end

            applyRenderedVisual(control._currentBg, control._currentBorder, control._currentText)
            if not needsMore then
                self:SetScript("OnUpdate", nil)
            end
        end)
    end

    local function animateScaleTo(targetScale, duration)
        control._scaleToken = (tonumber(control._scaleToken) or 0) + 1
        local currentScale = tonumber(control._displayScale) or 1.0
        if math.abs((tonumber(targetScale) or 1.0) - currentScale) < 0.001 then
            control._displayScale = tonumber(targetScale) or 1.0
            control._scaleTween = nil
            applyRenderedVisual(control._currentBg, control._currentBorder, control._currentText)
            refreshAnimationDriver()
            return
        end
        control._scaleTween = {
            token = control._scaleToken,
            start = currentScale,
            target = tonumber(targetScale) or 1.0,
            duration = math.max(0, tonumber(duration) or 0),
            elapsed = 0,
        }
        refreshAnimationDriver()
    end

    local function applyColorTarget(animate)
        local targetBg, targetBorder, targetText = getTargetColors()
        if animate and wrapper.IsShown and wrapper:IsShown() then
            control._colorToken = (tonumber(control._colorToken) or 0) + 1
            control._colorTween = {
                token = control._colorToken,
                startBg = cloneColor(control._currentBg),
                startBorder = cloneColor(control._currentBorder),
                startText = cloneColor(control._currentText),
                targetBg = cloneColor(targetBg),
                targetBorder = cloneColor(targetBorder),
                targetText = cloneColor(targetText),
                duration = HEADER_BADGE_COLOR_DURATION,
                elapsed = 0,
            }
            refreshAnimationDriver()
            return
        end
        control._colorTween = nil
        control._currentBg = cloneColor(targetBg)
        control._currentBorder = cloneColor(targetBorder)
        control._currentText = cloneColor(targetText)
        applyRenderedVisual(control._currentBg, control._currentBorder, control._currentText)
        refreshAnimationDriver()
    end

    local function updateBadgeLabel()
        label:SetText(control._visualValue and HEADER_BADGE_TEXT_ACTIVE or HEADER_BADGE_TEXT_INACTIVE)
    end

    computeBadgeDimensions()
    updateBadgeLabel()
    applyColorTarget(false)

    function spec:SetVisualSelectedValue(value)
        control._visualValue = value and true or false
        updateBadgeLabel()
        applyColorTarget(wrapper.IsShown and wrapper:IsShown())
    end

    function spec:GetVisualSelectedValue()
        return control._visualValue and true or false
    end

    function spec:SetEnabled(enabled)
        control._enabled = enabled and true or false
        control:EnableMouse(control._enabled)
        if not control._enabled then
            control._pressed = false
            control._hovered = false
            animateScaleTo(1.0, HEADER_BADGE_PRESS_DURATION)
            setHeaderAccessoryCursor(false)
        end
        applyColorTarget(false)
    end

    function spec:Show()
        control._displayScale = 1.0
        applyRenderedVisual(control._currentBg, control._currentBorder, control._currentText)
        wrapper:Show()
    end

    function spec:Hide()
        control._pressed = false
        control._hovered = false
        control._scaleTween = nil
        control._colorTween = nil
        control._displayScale = 1.0
        setHeaderAccessoryCursor(false)
        wrapper:SetScript("OnUpdate", nil)
        applyRenderedVisual(control._currentBg, control._currentBorder, control._currentText)
        wrapper:Hide()
    end

    control:SetScript("OnEnter", function(self)
        if self._enabled == false then
            return
        end
        self._hovered = true
        setHeaderAccessoryCursor(true)
        applyColorTarget(false)
    end)
    control:SetScript("OnLeave", function(self)
        self._hovered = false
        if self._enabled ~= false then
            self._pressed = false
            animateScaleTo(1.0, HEADER_BADGE_PRESS_DURATION)
        end
        setHeaderAccessoryCursor(false)
        applyColorTarget(false)
    end)
    control:SetScript("OnMouseDown", function(self, mouseButton)
        if mouseButton ~= "LeftButton" or self._enabled == false then
            return
        end
        self._pressed = true
        animateScaleTo(HEADER_BADGE_PRESS_SCALE, HEADER_BADGE_PRESS_DURATION)
    end)
    control:SetScript("OnMouseUp", function(self)
        if self._pressed then
            self._pressed = false
            animateScaleTo(1.0, HEADER_BADGE_PRESS_DURATION)
        end
    end)
    wrapper:SetScript("OnHide", function()
        control._hovered = false
        control._pressed = false
        control._scaleTween = nil
        control._colorTween = nil
        control._displayScale = 1.0
        wrapper:SetScript("OnUpdate", nil)
        setHeaderAccessoryCursor(false)
    end)
    control:SetScript("OnClick", function(selfButton, mouseButton)
        if mouseButton ~= "LeftButton" or selfButton._enabled == false then
            return
        end

        local currentValue = selfButton._visualValue and true or false
        local runtime = PortalAuthority and PortalAuthority._settingsWindowRuntime or nil
        local source = runtime and runtime.headerAccessorySource or nil
        if type(source) == "table" and type(source.GetSelectedValue) == "function" then
            local ok, selectedValue = pcall(source.GetSelectedValue, source)
            if ok then
                currentValue = selectedValue and true or false
            end
        end

        applyHeaderAccessorySelection(PortalAuthority, not currentValue)
    end)

    spec.control = wrapper
    spec.button = control
    spec.label = label
    return spec
end

local function clearHeaderAccessoryBinding(runtime)
    if not runtime then
        return
    end
    runtime.headerAccessorySource = nil
    runtime.headerAccessorySectionKey = nil
end

local function hideHeaderAccessory(runtime)
    if not runtime then
        return
    end
    clearHeaderAccessoryBinding(runtime)
    if runtime.headerAccessory then
        if runtime.headerAccessory.SetEnabled then
            runtime.headerAccessory:SetEnabled(false)
        end
        if runtime.headerAccessory.Hide then
            runtime.headerAccessory:Hide()
        elseif runtime.headerAccessory.control then
            runtime.headerAccessory.control:Hide()
        end
    end
end

local function setHeaderAccessoryVisual(runtime, value)
    if not runtime or not runtime.headerAccessory then
        return
    end
    if runtime.headerAccessory.SetVisualSelectedValue then
        runtime.headerAccessory:SetVisualSelectedValue(value)
    end
end

local function getCurrentSectionHeaderToggleSource(self)
    local runtime = ensureRuntime(self)
    local sectionKey = runtime.currentSectionKey
    if not HEADER_TOGGLE_SECTION_KEYS[sectionKey] then
        return nil, sectionKey
    end

    local panel = runtime.hostedPanelFrame
    if not panel or runtime.hostedPanelKey ~= sectionKey then
        return nil, sectionKey
    end
    if not isPanelCorrectlyHosted(runtime, sectionKey, panel) then
        return nil, sectionKey
    end

    local source = panel._settingsWindowHeaderToggleSource
    if type(source) ~= "table" then
        return nil, sectionKey
    end
    if type(source.GetSelectedValue) ~= "function" or type(source.SetSelectedValue) ~= "function" then
        return nil, sectionKey
    end

    return source, sectionKey
end

local function frameIsAlive(frame)
    return frame ~= nil and type(frame.GetObjectType) == "function"
end

local function isDescendedFrom(frame, ancestor)
    if not frame or not ancestor then
        return false
    end

    local current = frame
    while current do
        if current == ancestor then
            return true
        end
        current = current.GetParent and current:GetParent() or nil
    end
    return false
end

local function isShellOwnedFrame(runtime, frame)
    if not runtime or not frameIsAlive(frame) then
        return false
    end

    if runtime.window and isDescendedFrom(frame, runtime.window) then
        return true
    end
    if runtime.panelParkingFrame and isDescendedFrom(frame, runtime.panelParkingFrame) then
        return true
    end
    if type(runtime.shellOwnedFrames) == "table" and runtime.shellOwnedFrames[frame] then
        return true
    end
    return false
end

local function isValidExternalParent(runtime, frame)
    return frameIsAlive(frame) and not isShellOwnedFrame(runtime, frame)
end

local function rememberExternalParent(runtime, panelKey, panel)
    if type(panelKey) ~= "string" or not panel or not panel.GetParent then
        return
    end

    local parent = panel:GetParent()
    if isValidExternalParent(runtime, parent) then
        runtime.externalPanelParents[panelKey] = parent
    end
end

local function getStoredExternalParent(runtime, panelKey)
    if type(panelKey) ~= "string" then
        return nil
    end

    local parent = runtime.externalPanelParents and runtime.externalPanelParents[panelKey] or nil
    if isValidExternalParent(runtime, parent) then
        return parent
    end
    return nil
end

local function getPanelHostingTarget(runtime)
    return runtime and runtime.body or nil
end

isPanelCorrectlyHosted = function(runtime, panelKey, panel)
    local body = getPanelHostingTarget(runtime)
    if not panel or not body then
        return false
    end
    if runtime.hostedPanelKey ~= panelKey then
        return false
    end
    if runtime.hostedPanelFrame ~= panel then
        return false
    end
    if not panel.GetParent or panel:GetParent() ~= body then
        return false
    end
    if not panel.IsShown or not panel:IsShown() then
        return false
    end
    return true
end

local function snapshotCommittedState(runtime)
    return {
        currentSectionKey = runtime.currentSectionKey,
        activeNavKey = runtime.activeNavKey,
        lastSelectedSectionKey = runtime.lastSelectedSectionKey,
        hostedPanelKey = runtime.hostedPanelKey,
        hostedPanelFrame = runtime.hostedPanelFrame,
    }
end

local function restoreCommittedState(runtime, snapshot)
    runtime.currentSectionKey = snapshot and snapshot.currentSectionKey or nil
    runtime.activeNavKey = snapshot and snapshot.activeNavKey or nil
    runtime.lastSelectedSectionKey = snapshot and snapshot.lastSelectedSectionKey or nil
    runtime.hostedPanelKey = snapshot and snapshot.hostedPanelKey or nil
    runtime.hostedPanelFrame = snapshot and snapshot.hostedPanelFrame or nil
end

local function commitSectionState(self, section, immediate, hostedPanelKey, hostedPanelFrame)
    local runtime = ensureRuntime(self)
    if runtime.currentSectionKey ~= section.key then
        clearSearchHighlight(runtime)
    end
    runtime.currentSectionKey = section.key
    runtime.activeNavKey = section.showInNav and section.key or nil
    runtime.lastSelectedSectionKey = section.key
    runtime.hostedPanelKey = hostedPanelKey
    runtime.hostedPanelFrame = hostedPanelFrame
    clearLastError(self)
    updateHeader(self)
    updateNavState(self, immediate)
    refreshHeaderAccessory(self)
    return true
end

local function attachHostedPanel(self, sectionKey, panel)
    local runtime = ensureRuntime(self)
    local body = getPanelHostingTarget(runtime)
    if not panel or not body then
        setLastError(self, "Settings window host panel is unavailable.")
        return false
    end

    rememberExternalParent(runtime, sectionKey, panel)

    if panel.Hide and panel.IsShown and panel:IsShown() then
        panel:Hide()
    end

    if panel.SetParent then
        panel:SetParent(body)
    end
    panel._paHostedBySettingsWindow = true
    panel._paHostedSectionKey = sectionKey
    if panel.ClearAllPoints then
        panel:ClearAllPoints()
    end
    if panel.SetAllPoints then
        panel:SetAllPoints(body)
    else
        panel:SetPoint("TOPLEFT", body, "TOPLEFT", 0, 0)
        panel:SetPoint("BOTTOMRIGHT", body, "BOTTOMRIGHT", 0, 0)
    end
    if panel.Show then
        panel:Show()
    end

    if self.RefreshSettingsWindowHostVisuals then
        self:RefreshSettingsWindowHostVisuals(panel)
    end

    if not panel.GetParent or panel:GetParent() ~= body then
        setLastError(self, "Settings window host panel is unavailable.")
        return false
    end
    return true
end

local function detachHostedPanel(self, sectionKey, panel)
    local runtime = ensureRuntime(self)
    if not panel then
        return true
    end

    if panel.Hide then
        panel:Hide()
    end

    local restoreParent = getStoredExternalParent(runtime, sectionKey)
    if not restoreParent then
        restoreParent = runtime.panelParkingFrame
    end
    if not frameIsAlive(restoreParent) then
        setLastError(self, "Settings window host panel is unavailable.")
        return false
    end

    if panel.SetParent then
        panel:SetParent(restoreParent)
    end
    panel._paHostedBySettingsWindow = nil
    panel._paHostedSectionKey = nil
    if panel.ClearAllPoints then
        panel:ClearAllPoints()
    end

    if self.RefreshSettingsWindowHostVisuals then
        self:RefreshSettingsWindowHostVisuals(panel)
    end

    return true
end

local function detachCurrentHostedPanel(self)
    local runtime = ensureRuntime(self)
    local hostedPanelKey = runtime.hostedPanelKey
    local hostedPanelFrame = runtime.hostedPanelFrame
    if not hostedPanelFrame then
        runtime.hostedPanelKey = nil
        runtime.hostedPanelFrame = nil
        return true
    end
    if not detachHostedPanel(self, hostedPanelKey, hostedPanelFrame) then
        return false
    end
    runtime.hostedPanelKey = nil
    runtime.hostedPanelFrame = nil
    return true
end

local function restorePreviousHostedState(self, snapshot)
    local runtime = ensureRuntime(self)
    restoreCommittedState(runtime, snapshot)
    if snapshot and snapshot.hostedPanelFrame and snapshot.hostedPanelKey then
        if not attachHostedPanel(self, snapshot.hostedPanelKey, snapshot.hostedPanelFrame) then
            return false
        end
        runtime.hostedPanelKey = snapshot.hostedPanelKey
        runtime.hostedPanelFrame = snapshot.hostedPanelFrame
    else
        runtime.hostedPanelKey = nil
        runtime.hostedPanelFrame = nil
    end
    updateHeader(self)
    updateNavState(self, true)
    refreshHeaderAccessory(self)
    return true
end

local function isCommittedSelectionNoOp(self, section, targetPanel)
    local runtime = ensureRuntime(self)
    if not section then
        return false
    end

    local expectedActiveNavKey = section.showInNav and section.key or nil
    if runtime.currentSectionKey ~= section.key then
        return false
    end
    if runtime.activeNavKey ~= expectedActiveNavKey then
        return false
    end

    if targetPanel then
        return isPanelCorrectlyHosted(runtime, section.key, targetPanel)
    end

    return runtime.hostedPanelKey == nil and runtime.hostedPanelFrame == nil
end

local function performHeaderAccessoryRefresh(self)
    local runtime = ensureRuntime(self)
    if not runtime.window or not runtime.headerAccessory then
        return false
    end

    local frame = runtime.window
    if not (frame.IsShown and frame:IsShown()) then
        hideHeaderAccessory(runtime)
        return false
    end

    local source, sectionKey = getCurrentSectionHeaderToggleSource(self)
    if not source or runtime.currentSectionKey ~= sectionKey then
        hideHeaderAccessory(runtime)
        return false
    end

    local ok, selectedValue = pcall(source.GetSelectedValue, source)
    if not ok then
        hideHeaderAccessory(runtime)
        return false
    end

    runtime.headerAccessorySource = source
    runtime.headerAccessorySectionKey = sectionKey
    if runtime.headerAccessory.SetEnabled then
        runtime.headerAccessory:SetEnabled(true)
    end
    setHeaderAccessoryVisual(runtime, selectedValue)
    if runtime.headerAccessory.Show then
        runtime.headerAccessory:Show()
    elseif runtime.headerAccessory.control then
        runtime.headerAccessory.control:Show()
    end
    return true
end

refreshHeaderAccessory = function(self)
    local runtime = ensureRuntime(self)
    if not runtime.window or not runtime.headerAccessory then
        return false
    end

    if runtime.headerAccessoryRefreshActive then
        runtime.headerAccessoryRefreshPending = true
        return false
    end

    runtime.headerAccessoryRefreshActive = true
    local success = false
    repeat
        runtime.headerAccessoryRefreshPending = false
        runtime.headerAccessoryRefreshGeneration = (tonumber(runtime.headerAccessoryRefreshGeneration) or 0) + 1
        success = performHeaderAccessoryRefresh(self)
    until not runtime.headerAccessoryRefreshPending
    runtime.headerAccessoryRefreshActive = false
    return success
end

applyHeaderAccessorySelection = function(self, value)
    local runtime = ensureRuntime(self)
    if not runtime.window or not runtime.headerAccessory then
        return false
    end
    if runtime.headerAccessoryRefreshActive then
        runtime.headerAccessoryRefreshPending = true
        return false
    end

    local source, sectionKey = getCurrentSectionHeaderToggleSource(self)
    if not source or runtime.currentSectionKey ~= sectionKey then
        hideHeaderAccessory(runtime)
        return false
    end

    runtime.headerAccessoryRefreshActive = true
    local ok = pcall(source.SetSelectedValue, source, value, true)
    runtime.headerAccessoryRefreshPending = true
    repeat
        runtime.headerAccessoryRefreshPending = false
        runtime.headerAccessoryRefreshGeneration = (tonumber(runtime.headerAccessoryRefreshGeneration) or 0) + 1
        performHeaderAccessoryRefresh(self)
    until not runtime.headerAccessoryRefreshPending
    runtime.headerAccessoryRefreshActive = false
    return ok
end

local function getRowTopOffset(row, parent)
    local rowTop = row and row.GetTop and row:GetTop() or nil
    local parentTop = parent and parent.GetTop and parent:GetTop() or nil
    if not rowTop or not parentTop then
        return nil
    end
    return rowTop - parentTop
end

local function positionIndicator(sidebar, indicator, row, offsetY, height)
    if not sidebar or not indicator then
        return
    end

    indicator:ClearAllPoints()
    if type(offsetY) == "number" then
        indicator:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, offsetY)
    elseif row then
        indicator:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
    else
        indicator:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
    end
    indicator:SetHeight(height or indicator:GetHeight() or NAV_ROW_HEIGHT)
end

local function updateIndicator(runtime, row, immediate)
    local indicator = runtime.indicator
    local sidebar = runtime.sidebar
    if not indicator or not sidebar then
        return
    end

    stopFrameAnimation(indicator)

    if not row then
        indicator:Hide()
        return
    end

    local targetOffsetY = getRowTopOffset(row, sidebar)
    local targetHeight = row.GetHeight and row:GetHeight() or NAV_ROW_HEIGHT
    if type(targetOffsetY) ~= "number" then
        positionIndicator(sidebar, indicator, row, nil, targetHeight)
        indicator:Show()
        runtime.indicatorOffsetY = nil
        return
    end

    if immediate or runtime.indicatorOffsetY == nil or not indicator:IsShown() then
        positionIndicator(sidebar, indicator, row, targetOffsetY, targetHeight)
        indicator:Show()
        runtime.indicatorOffsetY = targetOffsetY
        runtime.indicatorHeight = targetHeight
        return
    end

    runtime.glideToken = (tonumber(runtime.glideToken) or 0) + 1
    local token = runtime.glideToken
    local elapsed = 0
    local startOffsetY = runtime.indicatorOffsetY
    local startHeight = runtime.indicatorHeight or indicator:GetHeight() or targetHeight

    indicator:Show()
    indicator:SetScript("OnUpdate", function(self, delta)
        if runtime.glideToken ~= token then
            self:SetScript("OnUpdate", nil)
            return
        end

        elapsed = elapsed + (delta or 0)
        local progress = GLIDE_DURATION > 0 and easeInOut(elapsed / GLIDE_DURATION) or 1
        local currentOffsetY = startOffsetY + ((targetOffsetY - startOffsetY) * progress)
        local currentHeight = startHeight + ((targetHeight - startHeight) * progress)
        positionIndicator(sidebar, self, nil, currentOffsetY, currentHeight)
        if progress >= 1 then
            self:SetScript("OnUpdate", nil)
            positionIndicator(sidebar, self, row, targetOffsetY, targetHeight)
            runtime.indicatorOffsetY = targetOffsetY
            runtime.indicatorHeight = targetHeight
        end
    end)
end

updateNavState = function(self, immediate)
    local runtime = ensureRuntime(self)
    local activeNavKey = runtime.activeNavKey
    local navButtons = runtime.navButtons or {}

    for key, button in pairs(navButtons) do
        local isActive = key == activeNavKey
        if button.wash then
            button.wash:SetShown(isActive)
        end
        if button.label then
            if isActive then
                button.label:SetTextColor(unpackColor(SHELL_STYLE.navActiveText))
            else
                button.label:SetTextColor(unpackColor(SHELL_STYLE.navIdleText))
            end
        end
    end

    updateIndicator(runtime, activeNavKey and navButtons[activeNavKey] or nil, immediate)
end

local function selectSection(self, sectionKey, immediate)
    local section, runtime = getSectionState(self, sectionKey)
    if not section then
        setLastError(self, "Settings window target is unavailable.")
        return false
    end

    local expectsHostedPanel = isHostableSectionKey(section.key)
    local targetEntry = expectsHostedPanel and getHostablePanelEntry(self, section.key) or nil
    local targetPanel = targetEntry and targetEntry.panel or nil
    if expectsHostedPanel and not targetPanel then
        setLastError(self, "Settings window host panel is unavailable.")
        return false
    end

    if isCommittedSelectionNoOp(self, section, targetPanel) then
        clearLastError(self)
        return true
    end

    if targetPanel and isPanelCorrectlyHosted(runtime, section.key, targetPanel) then
        return commitSectionState(self, section, immediate, section.key, targetPanel)
    end

    local snapshot = snapshotCommittedState(runtime)
    local currentHostedKey = runtime.hostedPanelKey
    local currentHostedFrame = runtime.hostedPanelFrame

    if currentHostedFrame and currentHostedFrame ~= targetPanel then
        if not detachHostedPanel(self, currentHostedKey, currentHostedFrame) then
            restoreCommittedState(runtime, snapshot)
            return false
        end
        runtime.hostedPanelKey = nil
        runtime.hostedPanelFrame = nil
    end

    if targetPanel and not attachHostedPanel(self, section.key, targetPanel) then
        local attachError = runtime.lastError
        detachHostedPanel(self, section.key, targetPanel)
        restorePreviousHostedState(self, snapshot)
        setLastError(self, attachError or "Settings window host panel is unavailable.")
        return false
    end

    return commitSectionState(self, section, immediate, section.key, targetPanel)
end

local hideSearchDropdown
local clearSearchState
local handleSearchResultSelected

local function normalizeSearchQuery(text)
    text = trim(tostring(text or ""))
    if text == "" then
        return ""
    end
    return string.lower(text)
end

local function getSearchNavOrder(self)
    return type(self.settingsWindowNavOrder) == "table" and self.settingsWindowNavOrder or {}
end

local function setSearchTextSilently(runtime, text)
    local searchEdit = runtime and runtime.searchEdit or nil
    if not searchEdit or not searchEdit.SetText then
        return
    end
    runtime.searchSuppressTextChanged = true
    searchEdit:SetText(tostring(text or ""))
    runtime.searchSuppressTextChanged = false
    updateSearchPlaceholder(runtime)
end

local function resetSearchQueryState(runtime)
    if not runtime then
        return
    end
    runtime.searchActiveQuery = ""
    runtime.searchPreviousQuery = ""
    runtime.searchPreviousCatalogRevision = tonumber(runtime.searchCatalogRevision) or 0
    wipeTable(runtime.searchFilteredResults)
    wipeTable(runtime.searchScratchResults)
end

clearSearchHighlight = function(runtime)
    if not runtime then
        return
    end
    runtime.searchHighlightToken = (tonumber(runtime.searchHighlightToken) or 0) + 1
    local highlight = runtime.searchHighlightFrame
    if highlight and highlight.SetScript then
        highlight:SetScript("OnUpdate", nil)
        highlight:Hide()
        highlight:ClearAllPoints()
        highlight._paTarget = nil
    end
end

local function getSearchNoResultsLine()
    if #SEARCH_NO_RESULTS_LINES <= 0 then
        return "By the tides... no results found."
    end
    return SEARCH_NO_RESULTS_LINES[math.random(1, #SEARCH_NO_RESULTS_LINES)]
end

local function clearActiveNoResultsMessage(runtime)
    if runtime then
        runtime.activeNoResultsMessage = nil
    end
end

local function getActiveNoResultsMessage(runtime)
    if not runtime then
        return getSearchNoResultsLine()
    end
    if type(runtime.activeNoResultsMessage) ~= "string" or runtime.activeNoResultsMessage == "" then
        runtime.activeNoResultsMessage = getSearchNoResultsLine()
    end
    return runtime.activeNoResultsMessage
end

local function formatSearchResultText(text)
    text = tostring(text or "")
    text = text:gsub("[%c\r\n\t]+", " ")
    text = text:gsub("%s+", " ")
    return trim(text)
end

local function logSearchClickStep(...)
    if SEARCH_CLICK_DEBUG ~= true then
        return
    end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    local message = "[PA search click] " .. table.concat(parts, " ")
    if type(DEFAULT_CHAT_FRAME) == "table" and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    else
        print(message)
    end
end

function SearchTargetAudit.log(...)
    if SearchTargetAudit.enabled ~= true then
        return
    end
    local parts = {}
    for i = 1, select("#", ...) do
        parts[#parts + 1] = tostring(select(i, ...))
    end
    local message = "[PA search target] " .. table.concat(parts, " ")
    if type(DEFAULT_CHAT_FRAME) == "table" and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage(message)
    else
        print(message)
    end
end

function SearchTargetAudit.formatFrameRef(ref)
    if not frameIsAlive(ref) then
        return "NIL"
    end
    local objectType = ref.GetObjectType and ref:GetObjectType() or "?"
    local name = ref.GetName and ref:GetName() or nil
    if type(name) == "string" and name ~= "" then
        return string.format("%s:%s", objectType, name)
    end
    return string.format("%s:%s", objectType, tostring(ref))
end

function SearchTargetAudit.formatFlag(flag)
    return flag and "YES" or "NO"
end

function SearchTargetAudit.findEntryIndex(entries, targetEntry)
    if type(entries) ~= "table" then
        return nil
    end
    for i = 1, #entries do
        if entries[i] == targetEntry then
            return i
        end
    end
    return nil
end

function SearchTargetAudit.classifyMismatch(entry, registryIndex, filteredIndex, handoffMatches)
    if registryIndex == nil or filteredIndex == nil or handoffMatches ~= true then
        return "right registry target but stale copied entry in visible filtered results"
    end
    if type(entry) ~= "table" then
        return "unknown"
    end
    if entry._searchTargetType == "widget_fallback" then
        return "wrong frame chosen"
    end
    if entry._searchTargetBoundsValid == false then
        return "right frame chosen but wrong bounds"
    end
    return "aligned"
end

function SearchTargetAudit.classifyAttachMismatch(entry, target)
    local registryTarget = type(entry) == "table" and (entry._searchRegistryTargetRef or entry.controlRef) or nil
    if target ~= registryTarget then
        return "wrong attach-time frame"
    end
    return "aligned"
end

function SearchTargetAudit.printControlEntry(runtime, entry, registryEntries, filteredIndexOverride)
    if SearchTargetAudit.enabled ~= true or type(entry) ~= "table" or entry.kind ~= "control" then
        return
    end

    local filteredIndex = filteredIndexOverride
    if filteredIndex == nil then
        filteredIndex = SearchTargetAudit.findEntryIndex(runtime and runtime.searchFilteredResults or nil, entry)
    end
    local registryIndex = SearchTargetAudit.findEntryIndex(registryEntries, entry)
    local handoffMatches = runtime and runtime.searchResultClickEntry == entry
    local mismatchClass = SearchTargetAudit.classifyMismatch(entry, registryIndex, filteredIndex, handoffMatches)
    SearchTargetAudit.log(
        "label=", formatSearchResultText(entry.displayLabel or entry.labelText or ""),
        "type=", entry._searchTargetType or "NIL",
        "phase=", entry._searchResolvedPhase or "NIL",
        "provisional=", SearchTargetAudit.formatFlag(entry._searchTargetProvisional == true),
        "history=", entry._searchTargetHistorySummary or (entry._searchTargetType or "NIL"),
        "registryTarget=", SearchTargetAudit.formatFrameRef(entry._searchRegistryTargetRef or entry.controlRef),
        "registryAnchor=", SearchTargetAudit.formatFrameRef(entry._searchRegistryAnchorRef or entry.anchorRef),
        "scrollRef=", SearchTargetAudit.formatFrameRef(entry._searchScrollSourceRef or entry.controlRef),
        "aligned=", SearchTargetAudit.formatFlag(entry._searchAlignedTarget == true)
    )
    SearchTargetAudit.log(
        "label=", formatSearchResultText(entry.displayLabel or entry.labelText or ""),
        "registryObject=", SearchTargetAudit.formatFlag(registryIndex ~= nil),
        "filteredObject=", SearchTargetAudit.formatFlag(filteredIndex ~= nil),
        "handoffObject=", SearchTargetAudit.formatFlag(handoffMatches),
        "filteredIndex=", filteredIndex or "NIL",
        "registryIndex=", registryIndex or "NIL"
    )
    SearchTargetAudit.log(
        "label=", formatSearchResultText(entry.displayLabel or entry.labelText or ""),
        "boundsNote=", entry._searchTargetBoundsNote or "NIL",
        "fallbackReason=", entry._searchWidgetFallbackReason or "NONE",
        "hiddenResolved=", entry._searchHiddenResolvedTargetType or "NIL",
        "realResolved=", entry._searchRealResolvedTargetType or "NIL",
        "mismatch=", mismatchClass
    )
end

local function escapeColorCodeText(text)
    text = tostring(text or "")
    text = text:gsub("|", "||")
    return text
end

local function formatHighlightedLabel(labelText, normalizedQuery)
    local label = formatSearchResultText(labelText)
    normalizedQuery = trim(tostring(normalizedQuery or ""))
    if label == "" or normalizedQuery == "" then
        return escapeColorCodeText(label), false
    end

    local lowerLabel = string.lower(label)
    local startIndex, endIndex = string.find(lowerLabel, normalizedQuery, 1, true)
    if not startIndex or not endIndex then
        return escapeColorCodeText(label), false
    end

    local prefix = escapeColorCodeText(string.sub(label, 1, startIndex - 1))
    local matchText = escapeColorCodeText(string.sub(label, startIndex, endIndex))
    local suffix = escapeColorCodeText(string.sub(label, endIndex + 1))
    return string.format("%s|cff5bbfb5%s|r%s", prefix, matchText, suffix), true
end

local function isSearchResultClickActive(runtime)
    local state = runtime and runtime.searchResultClickState or "idle"
    return state == "armed" or state == "committing"
end

local function isPointerOverOpenSearchDropdown(runtime)
    if not runtime or runtime.searchDropdownVisible ~= true or not MouseIsOver then
        return false
    end

    local dropdown = runtime.searchDropdown
    if not dropdown or not dropdown.IsShown or not dropdown:IsShown() then
        return false
    end

    if MouseIsOver(dropdown) then
        return true
    end

    local scrollFrame = runtime.searchDropdownScrollFrame
    if scrollFrame and scrollFrame.IsShown and scrollFrame:IsShown() and MouseIsOver(scrollFrame) then
        return true
    end

    return false
end

local function debugSearchClickPrint(...)
    if SEARCH_CLICK_DEBUG == true then
        print(...)
    end
end

local function clearSearchResultClickTransaction(runtime, token)
    if not runtime then
        return
    end
    if token and runtime.searchResultClickToken ~= token then
        return
    end
    logSearchClickStep("clear-transaction", token or runtime.searchResultClickToken or 0)
    runtime.searchResultClickState = "idle"
    runtime.searchResultClickEntry = nil
    runtime.searchResultCommitOwnerToken = nil
    runtime.searchSelectionToken = (tonumber(runtime.searchSelectionToken) or 0) + 1
    runtime.searchResultReleaseWatcherToken = (tonumber(runtime.searchResultReleaseWatcherToken) or 0) + 1
    if runtime.searchResultReleaseWatcher and runtime.searchResultReleaseWatcher.SetScript then
        runtime.searchResultReleaseWatcher:SetScript("OnUpdate", nil)
    end
end

local function startSearchResultReleaseWatcher(runtime, token)
    if not runtime or not token then
        return
    end

    if not runtime.searchResultReleaseWatcher then
        runtime.searchResultReleaseWatcher = CreateFrame("Frame", nil, runtime.window or UIParent)
    end

    local watcher = runtime.searchResultReleaseWatcher
    runtime.searchResultReleaseWatcherToken = (tonumber(runtime.searchResultReleaseWatcherToken) or 0) + 1
    local watcherToken = runtime.searchResultReleaseWatcherToken
    watcher:SetScript("OnUpdate", function(selfWatcher)
        if runtime.searchResultReleaseWatcherToken ~= watcherToken
            or runtime.searchResultClickToken ~= token
            or runtime.searchResultClickState ~= "armed"
        then
            selfWatcher:SetScript("OnUpdate", nil)
            return
        end

        if IsMouseButtonDown and IsMouseButtonDown("LeftButton") then
            return
        end

        logSearchClickStep("cancel-armed-click", token)
        clearSearchResultClickTransaction(runtime, token)
        if not (runtime.searchEdit and runtime.searchEdit.HasFocus and runtime.searchEdit:HasFocus()) then
            hideSearchDropdown(runtime, {
                reason = "abandoned-click",
            })
        end
    end)
end

local function beginSearchResultClickTransaction(runtime, entry)
    if not runtime or type(entry) ~= "table" then
        return 0
    end
    runtime.searchResultClickToken = (tonumber(runtime.searchResultClickToken) or 0) + 1
    runtime.searchResultClickState = "armed"
    runtime.searchResultClickEntry = entry
    runtime.searchResultCommitOwnerToken = nil
    logSearchClickStep("begin-transaction", runtime.searchResultClickToken, type(entry) == "table" and entry.sectionKey or "nil")
    startSearchResultReleaseWatcher(runtime, runtime.searchResultClickToken)
    return runtime.searchResultClickToken
end

local function ensureSearchCatalog(self, runtime)
    if not runtime then
        return {}
    end

    runtime.searchCatalogSections = runtime.searchCatalogSections or {}
    runtime.searchCatalogRefs = runtime.searchCatalogRefs or {}

    local changed = runtime.searchCatalogInitialized ~= true
    local navOrder = getSearchNavOrder(self)
    for i = 1, #navOrder do
        local sectionKey = navOrder[i]
        local entries = runtime.searchCatalogSections[sectionKey] or {}
        local panelChanged = false
        if self.SettingsSearch_EnsurePanelRegistry then
            local ok, resultEntries, resultChanged = pcall(self.SettingsSearch_EnsurePanelRegistry, self, sectionKey)
            if ok and type(resultEntries) == "table" then
                entries = resultEntries
                panelChanged = resultChanged == true
            end
        end
        runtime.searchCatalogSections[sectionKey] = entries
        if panelChanged then
            changed = true
        end
    end

    if changed then
        local merged = runtime.searchCatalogRefs
        wipeTable(merged)
        for i = 1, #navOrder do
            local entries = runtime.searchCatalogSections[navOrder[i]] or {}
            for j = 1, #entries do
                merged[#merged + 1] = entries[j]
            end
        end
        runtime.searchCatalogRevision = (tonumber(runtime.searchCatalogRevision) or 0) + 1
        runtime.searchCatalogInitialized = true
        resetSearchQueryState(runtime)
    end

    return runtime.searchCatalogRefs
end

local function refreshSearchCatalogSection(self, runtime, sectionKey, opts)
    if not self or not runtime or type(sectionKey) ~= "string" or sectionKey == "" then
        return nil, false
    end
    opts = type(opts) == "table" and opts or nil

    local refreshFn = nil
    if opts and opts.resolveTargetsOnly == true and self.SettingsSearch_RefreshResolvedTargets then
        refreshFn = self.SettingsSearch_RefreshResolvedTargets
    else
        refreshFn = self.SettingsSearch_EnsurePanelRegistry
    end
    if not refreshFn then
        return nil, false
    end

    local ok, resultEntries, resultChanged = pcall(refreshFn, self, sectionKey)
    if not ok or type(resultEntries) ~= "table" then
        return nil, false
    end

    runtime.searchCatalogSections = runtime.searchCatalogSections or {}
    runtime.searchCatalogSections[sectionKey] = resultEntries
    return resultEntries, resultChanged == true
end

local function filterSearchCatalog(self, runtime, normalizedQuery)
    if not runtime then
        return {}
    end

    local fullCatalog = ensureSearchCatalog(self, runtime)
    local canNarrow = normalizedQuery ~= ""
        and runtime.searchPreviousQuery ~= ""
        and runtime.searchCatalogRevision == runtime.searchPreviousCatalogRevision
        and string.sub(normalizedQuery, 1, string.len(runtime.searchPreviousQuery)) == runtime.searchPreviousQuery
    local source = canNarrow and runtime.searchFilteredResults or fullCatalog

    local output = runtime.searchScratchResults
    if output == runtime.searchFilteredResults then
        output = {}
    end
    wipeTable(output)

    for i = 1, #(source or {}) do
        local entry = source[i]
        local haystack = entry and entry.haystack or nil
        if type(haystack) == "string" and haystack ~= "" and string.find(haystack, normalizedQuery, 1, true) then
            output[#output + 1] = entry
        end
    end

    runtime.searchScratchResults = runtime.searchFilteredResults
    runtime.searchFilteredResults = output
    runtime.searchPreviousQuery = normalizedQuery
    runtime.searchPreviousCatalogRevision = runtime.searchCatalogRevision
    return runtime.searchFilteredResults
end

local function resolveSearchEntryLiveScrollY(scrollChild, entry)
    local targetRef = entry and entry.controlRef or nil
    if not targetRef or not scrollChild then
        return tonumber(entry and entry.scrollY) or 0
    end

    local rootTop = scrollChild.GetTop and scrollChild:GetTop() or nil
    local targetTop = targetRef.GetTop and targetRef:GetTop() or nil
    if rootTop and targetTop then
        return math.max(0, rootTop - targetTop)
    end
    return tonumber(entry and entry.scrollY) or 0
end

local function resolveSearchEntryDesiredScroll(scrollFrame, scrollChild, entry)
    if not scrollFrame or not scrollChild or not entry then
        return 0
    end

    local viewportHeight = tonumber(scrollFrame.GetHeight and scrollFrame:GetHeight()) or 0
    local contentHeight = tonumber(scrollChild.GetHeight and scrollChild:GetHeight()) or 0
    local maxScroll = math.max(0, contentHeight - viewportHeight)
    local baseY = resolveSearchEntryLiveScrollY(scrollChild, entry)
    local targetRef = entry.controlRef
    local targetHeight = tonumber(targetRef and targetRef.GetHeight and targetRef:GetHeight()) or SEARCH_RESULT_ROW_HEIGHT
    local desiredTopInset = math.max(0, math.floor((viewportHeight * 0.30) - (targetHeight * 0.5)))
    local desired = math.max(0, baseY - desiredTopInset)
    if desired > maxScroll then
        desired = maxScroll
    end
    return desired
end

local function ensureSearchHighlightFrame(self)
    local runtime = ensureRuntime(self)
    if runtime.searchHighlightFrame and runtime.searchHighlightFrame.GetObjectType then
        return runtime.searchHighlightFrame
    end

    local parent = runtime.body or runtime.window
    if not parent then
        return nil
    end

    local highlight = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    highlight:SetBackdrop(PANEL_BACKDROP)
    highlight:SetBackdropColor(unpackColor(SEARCH_HIGHLIGHT_WASH_COLOR.entry))
    highlight:SetBackdropBorderColor(0, 0, 0, 0)
    highlight:SetFrameStrata("HIGH")
    highlight:Hide()

    local edge = highlight:CreateTexture(nil, "ARTWORK")
    edge:SetPoint("TOPLEFT", highlight, "TOPLEFT", 0, 0)
    edge:SetPoint("BOTTOMLEFT", highlight, "BOTTOMLEFT", 0, 0)
    edge:SetWidth(2)
    edge:SetColorTexture(unpackColor(SEARCH_HIGHLIGHT_EDGE_COLOR.entry))
    highlight._edge = edge

    runtime.searchHighlightFrame = highlight
    return highlight
end

local function smoothStep(progress)
    progress = math.max(0, math.min(1, tonumber(progress) or 0))
    return progress * progress * (3 - (2 * progress))
end

local function getSearchHighlightPhaseAlpha(elapsed, entryAlpha, settledAlpha)
    elapsed = tonumber(elapsed) or 0
    local settleStart = SEARCH_HIGHLIGHT_ENTRY_DURATION
    local holdStart = settleStart + SEARCH_HIGHLIGHT_SETTLE_DURATION
    local fadeStart = holdStart + SEARCH_HIGHLIGHT_HOLD_DURATION
    local fadeEnd = fadeStart + SEARCH_HIGHLIGHT_FADE_DURATION

    if elapsed <= settleStart then
        return entryAlpha
    end

    if elapsed <= holdStart then
        local settleProgress = SEARCH_HIGHLIGHT_SETTLE_DURATION > 0
            and smoothStep((elapsed - settleStart) / SEARCH_HIGHLIGHT_SETTLE_DURATION)
            or 1
        return entryAlpha + ((settledAlpha - entryAlpha) * settleProgress)
    end

    if elapsed <= fadeStart then
        return settledAlpha
    end

    if elapsed <= fadeEnd then
        local fadeProgress = SEARCH_HIGHLIGHT_FADE_DURATION > 0
            and math.max(0, math.min(1, (elapsed - fadeStart) / SEARCH_HIGHLIGHT_FADE_DURATION))
            or 1
        return settledAlpha * (1 - fadeProgress)
    end

    return nil
end

local function applySearchHighlight(self, entry)
    local runtime = ensureRuntime(self)
    clearSearchHighlight(runtime)

    if not entry or entry.skipHighlight == true or not frameIsAlive(entry.controlRef) then
        return
    end

    local target = entry.controlRef
    local parent = target.GetParent and target:GetParent() or runtime.body or runtime.window
    if not frameIsAlive(parent) then
        return
    end

    local highlight = ensureSearchHighlightFrame(self)
    if not highlight then
        return
    end

    highlight:SetParent(parent)
    highlight:ClearAllPoints()
    highlight:SetPoint("TOPLEFT", target, "TOPLEFT", -8, 4)
    highlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 8, -4)
    highlight:SetBackdropColor(unpackColor(SEARCH_HIGHLIGHT_WASH_COLOR.entry))
    highlight:Show()
    highlight._paTarget = target

    if SearchTargetAudit.enabled == true and type(entry) == "table" and entry.kind == "control" then
        SearchTargetAudit.log(
            "label=", formatSearchResultText(entry.displayLabel or entry.labelText or ""),
            "highlightTarget=", SearchTargetAudit.formatFrameRef(target),
            "attachMatchesRegistry=", SearchTargetAudit.formatFlag(target == (entry._searchRegistryTargetRef or entry.controlRef)),
            "attachMatchesEntry=", SearchTargetAudit.formatFlag(target == entry.controlRef),
            "attachMismatch=", SearchTargetAudit.classifyAttachMismatch(entry, target)
        )
    end

    runtime.searchHighlightToken = (tonumber(runtime.searchHighlightToken) or 0) + 1
    local token = runtime.searchHighlightToken
    local elapsed = 0
    highlight:SetScript("OnUpdate", function(selfHighlight, delta)
        if runtime.searchHighlightToken ~= token then
            selfHighlight:SetScript("OnUpdate", nil)
            return
        end

        elapsed = elapsed + (tonumber(delta) or 0)
        local washEntryR, washEntryG, washEntryB, washEntryA = unpackColor(SEARCH_HIGHLIGHT_WASH_COLOR.entry)
        local _, _, _, washSettledA = unpackColor(SEARCH_HIGHLIGHT_WASH_COLOR.settled)
        local edgeEntryR, edgeEntryG, edgeEntryB, edgeEntryA = unpackColor(SEARCH_HIGHLIGHT_EDGE_COLOR.entry)
        local _, _, _, edgeSettledA = unpackColor(SEARCH_HIGHLIGHT_EDGE_COLOR.settled)
        local washAlpha = getSearchHighlightPhaseAlpha(elapsed, washEntryA, washSettledA)
        local edgeAlpha = getSearchHighlightPhaseAlpha(elapsed, edgeEntryA, edgeSettledA)

        if not washAlpha or washAlpha <= 0 or not edgeAlpha or edgeAlpha <= 0 then
            clearSearchHighlight(runtime)
            return
        end

        selfHighlight:SetBackdropColor(washEntryR, washEntryG, washEntryB, washAlpha)
        if selfHighlight._edge and selfHighlight._edge.SetColorTexture then
            selfHighlight._edge:SetColorTexture(edgeEntryR, edgeEntryG, edgeEntryB, edgeAlpha)
        end
    end)
end

local function applySearchScroll(self, scrollFrame, scrollChild, desiredValue)
    if not scrollFrame or not scrollChild then
        return 0
    end
    if self.SettingsWindowApplySearchScroll then
        local ok, resolved = self:SettingsWindowApplySearchScroll(scrollFrame, scrollChild, desiredValue)
        if ok ~= false and type(resolved) == "number" then
            return resolved
        end
    end
    if scrollFrame.SetVerticalScroll then
        scrollFrame:SetVerticalScroll(math.max(0, tonumber(desiredValue) or 0))
    end
    return math.max(0, tonumber(desiredValue) or 0)
end

handleSearchResultSelected = function(self, entry)
    if type(entry) ~= "table" or type(entry.sectionKey) ~= "string" then
        clearSearchResultClickTransaction(ensureRuntime(self))
        return false
    end

    local runtime = ensureRuntime(self)
    local clickToken = runtime.searchResultClickToken
    if runtime.searchResultClickState ~= "committing" or runtime.searchResultCommitOwnerToken ~= clickToken then
        clearSearchResultClickTransaction(runtime, clickToken)
        return false
    end

    logSearchClickStep("select-start", clickToken, entry.sectionKey, entry.kind or "control")
    local preFilteredIndex = nil
    if entry.kind == "control" then
        preFilteredIndex = SearchTargetAudit.findEntryIndex(runtime.searchFilteredResults, entry)
    end
    local prePanel = nil
    if self.SettingsSearch_GetScrollContext then
        prePanel = self:SettingsSearch_GetScrollContext(entry.sectionKey)
    end
    local needsActivationCorrection = prePanel and prePanel._paSearchRealActivationPending == true

    debugSearchClickPrint("PA SEARCH: step 1 - snapshot done")
    hideSearchDropdown(runtime, {
        commitOwned = true,
        clickToken = clickToken,
        reason = "result-commit",
    })
    debugSearchClickPrint("PA SEARCH: step 2 - dropdown hidden")
    clearSearchHighlight(runtime)
    setSearchTextSilently(runtime, "")
    resetSearchQueryState(runtime)
    clearActiveNoResultsMessage(runtime)
    debugSearchClickPrint("PA SEARCH: step 3 - text cleared")
    if runtime.searchEdit and runtime.searchEdit.ClearFocus then
        runtime.searchEdit:ClearFocus()
    end
    updateSearchPlaceholder(runtime)
    debugSearchClickPrint("PA SEARCH: step 4 - focus removed")

    debugSearchClickPrint("PA SEARCH: step 5 - calling section switch to", entry.sectionKey)
    if not selectSection(self, entry.sectionKey, false) then
        logSearchClickStep("select-section-failed", clickToken, entry.sectionKey)
        clearSearchResultClickTransaction(runtime, clickToken)
        return false
    end
    logSearchClickStep("select-section-ok", clickToken, entry.sectionKey)

    local refreshedRegistryEntries = nil
    if entry.kind == "control" then
        refreshedRegistryEntries = select(1, refreshSearchCatalogSection(self, runtime, entry.sectionKey))
        SearchTargetAudit.printControlEntry(runtime, entry, refreshedRegistryEntries or (runtime.searchCatalogSections and runtime.searchCatalogSections[entry.sectionKey] or nil), preFilteredIndex)
    end

    runtime.searchSelectionToken = (tonumber(runtime.searchSelectionToken) or 0) + 1
    local token = runtime.searchSelectionToken

    local function finishPlacement(isFinalPass)
        if runtime.searchSelectionToken ~= token then
            logSearchClickStep("selection-token-stale", clickToken, token)
            clearSearchResultClickTransaction(runtime, clickToken)
            return
        end

        local panel, scrollFrame, scrollChild = nil, nil, nil
        if self.SettingsSearch_GetScrollContext then
            panel, scrollFrame, scrollChild = self:SettingsSearch_GetScrollContext(entry.sectionKey)
        end
        if not panel or not scrollFrame or not scrollChild then
            logSearchClickStep("scroll-context-missing", clickToken, entry.sectionKey)
            if isFinalPass or needsActivationCorrection ~= true then
                clearSearchResultClickTransaction(runtime, clickToken)
            end
            return
        end

        if not (scrollFrame.IsShown and scrollFrame:IsShown()) then
            logSearchClickStep("scroll-context-hidden", clickToken, isFinalPass and "give-up" or "pending")
            if isFinalPass or needsActivationCorrection ~= true then
                clearSearchResultClickTransaction(runtime, clickToken)
            end
            return
        end

        if entry.kind == "control" then
            refreshSearchCatalogSection(self, runtime, entry.sectionKey, {
                resolveTargetsOnly = true,
            })
        end

        debugSearchClickPrint("PA SEARCH: step 6 - panel ready")
        local initialValue = tonumber(entry.scrollY) or 0
        applySearchScroll(self, scrollFrame, scrollChild, initialValue)
        local desiredValue = resolveSearchEntryDesiredScroll(scrollFrame, scrollChild, entry)
        debugSearchClickPrint("PA SEARCH: step 7 - scroll target resolved", desiredValue)
        applySearchScroll(self, scrollFrame, scrollChild, desiredValue)
        debugSearchClickPrint("PA SEARCH: step 8 - scroll applied")
        debugSearchClickPrint("PA SEARCH: step 9 - thumb synced")
        logSearchClickStep("scroll-applied", clickToken, desiredValue)
        if entry.skipHighlight ~= true then
            applySearchHighlight(self, entry)
            logSearchClickStep("highlight-applied", clickToken)
        end
        debugSearchClickPrint("PA SEARCH: step 10 - highlight applied")
        if isFinalPass or needsActivationCorrection ~= true then
            clearSearchResultClickTransaction(runtime, clickToken)
        end
    end

    finishPlacement(needsActivationCorrection ~= true)
    if needsActivationCorrection == true and C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            finishPlacement(true)
        end)
    end
    return true
end

local function getSearchDropdownMaxVisibleHeight(runtime)
    local maxHeight = SEARCH_DROPDOWN_MAX_HEIGHT
    if not runtime then
        return maxHeight
    end

    local searchBox = runtime.searchBox
    local logoButton = runtime.logoButton
    local searchTop = tonumber(searchBox and searchBox.GetTop and searchBox:GetTop()) or nil
    local logoBottom = tonumber(logoButton and logoButton.GetBottom and logoButton:GetBottom()) or nil
    if searchTop and logoBottom then
        local availableHeight = math.floor(searchTop - logoBottom - 40)
        if availableHeight > 0 then
            maxHeight = math.min(maxHeight, availableHeight)
        end
    end
    return math.max(60, maxHeight)
end

local function getSearchDropdownScrollMetrics(runtime)
    if not runtime then
        return 0, 0, 0, 0
    end

    local scrollFrame = runtime.searchDropdownScrollFrame
    local content = runtime.searchDropdownContent
    if not scrollFrame or not content then
        return 0, 0, 0, 0
    end

    if scrollFrame.UpdateScrollChildRect then
        scrollFrame:UpdateScrollChildRect()
    end

    local viewportHeight = tonumber(scrollFrame.GetHeight and scrollFrame:GetHeight()) or 0
    local contentHeight = tonumber(content.GetHeight and content:GetHeight()) or 0
    local maxScroll = math.max(0, contentHeight - viewportHeight)
    local currentScroll = tonumber(scrollFrame.GetVerticalScroll and scrollFrame:GetVerticalScroll()) or 0
    return currentScroll, maxScroll, viewportHeight, contentHeight
end

local function setSearchDropdownOverlayAlpha(runtime, overlay, tokenField, targetAlpha, duration)
    if not runtime or not overlay then
        return
    end

    targetAlpha = math.max(0, math.min(1, tonumber(targetAlpha) or 0))
    duration = math.max(0, tonumber(duration) or 0)
    local currentAlpha = overlay.GetAlpha and overlay:GetAlpha() or 0
    local isShown = overlay.IsShown and overlay:IsShown() or false
    if math.abs(currentAlpha - targetAlpha) < 0.01 and ((targetAlpha > 0 and isShown) or (targetAlpha <= 0 and not isShown)) then
        return
    end

    runtime[tokenField] = (tonumber(runtime[tokenField]) or 0) + 1

    if targetAlpha > 0 then
        overlay:Show()
    end

    stopFrameAnimation(overlay)
    if duration <= 0 then
        overlay:SetAlpha(targetAlpha)
        if targetAlpha <= 0 then
            overlay:Hide()
        end
        return
    end

    startAlphaTween(overlay, runtime, tokenField, currentAlpha, targetAlpha, duration, function(selfOverlay)
        if targetAlpha <= 0 then
            selfOverlay:Hide()
        end
    end)
end

local function stopSearchDropdownShimmer(runtime)
    if not runtime or not runtime.searchDropdownShimmer then
        return
    end
    runtime.searchDropdownShimmerToken = (tonumber(runtime.searchDropdownShimmerToken) or 0) + 1
    stopFrameAnimation(runtime.searchDropdownShimmer)
    runtime.searchDropdownShimmer._elapsed = nil
    runtime.searchDropdownShimmer:SetAlpha(0)
    runtime.searchDropdownShimmer:Hide()
end

local function stopSearchDropdownGlow(runtime, edge)
    local frame = edge == "top" and runtime and runtime.searchDropdownTopGlow or runtime and runtime.searchDropdownBottomGlow
    local tokenField = edge == "top" and "searchDropdownTopGlowToken" or "searchDropdownBottomGlowToken"
    if not runtime or not frame then
        return
    end
    runtime[tokenField] = (tonumber(runtime[tokenField]) or 0) + 1
    stopFrameAnimation(frame)
    frame._remaining = nil
    frame:SetAlpha(0)
    frame:Hide()
end

local function hideSearchDropdownIndicators(runtime)
    if not runtime then
        return
    end
    setSearchDropdownOverlayAlpha(runtime, runtime.searchDropdownTopFade, "searchDropdownTopFadeToken", 0, 0)
    setSearchDropdownOverlayAlpha(runtime, runtime.searchDropdownBottomFade, "searchDropdownBottomFadeToken", 0, 0)
    stopSearchDropdownShimmer(runtime)
    stopSearchDropdownGlow(runtime, "top")
    stopSearchDropdownGlow(runtime, "bottom")
end

local function updateSearchDropdownOverflowIndicators(runtime, immediate)
    if not runtime or runtime.searchDropdownVisible ~= true then
        hideSearchDropdownIndicators(runtime)
        return
    end

    local currentScroll, maxScroll = getSearchDropdownScrollMetrics(runtime)
    local atTop = currentScroll <= 0.5
    local atBottom = currentScroll >= (maxScroll - 0.5)
    local duration = immediate and 0 or SEARCH_DROPDOWN_FADE_DURATION

    setSearchDropdownOverlayAlpha(
        runtime,
        runtime.searchDropdownTopFade,
        "searchDropdownTopFadeToken",
        (maxScroll > 0 and not atTop) and 1 or 0,
        duration
    )
    setSearchDropdownOverlayAlpha(
        runtime,
        runtime.searchDropdownBottomFade,
        "searchDropdownBottomFadeToken",
        (maxScroll > 0 and not atBottom) and 1 or 0,
        duration
    )
end

local function applySearchDropdownScroll(runtime, desiredValue)
    if not runtime or not runtime.searchDropdownScrollFrame or not runtime.searchDropdownContent then
        return 0, 0
    end

    local scrollFrame = runtime.searchDropdownScrollFrame
    local content = runtime.searchDropdownContent
    if scrollFrame.UpdateScrollChildRect then
        scrollFrame:UpdateScrollChildRect()
    end

    local viewportHeight = tonumber(scrollFrame.GetHeight and scrollFrame:GetHeight()) or 0
    local contentHeight = tonumber(content.GetHeight and content:GetHeight()) or 0
    local maxScroll = math.max(0, contentHeight - viewportHeight)
    local nextValue = math.max(0, math.min(maxScroll, tonumber(desiredValue) or 0))
    if scrollFrame.SetVerticalScroll then
        scrollFrame:SetVerticalScroll(nextValue)
    end
    return nextValue, maxScroll
end

local function triggerSearchDropdownGlow(runtime, edge)
    if not runtime then
        return
    end

    local glow = edge == "top" and runtime.searchDropdownTopGlow or runtime.searchDropdownBottomGlow
    local tokenField = edge == "top" and "searchDropdownTopGlowToken" or "searchDropdownBottomGlowToken"
    if not glow then
        return
    end

    runtime[tokenField] = (tonumber(runtime[tokenField]) or 0) + 1
    local token = runtime[tokenField]
    glow:SetAlpha(1)
    glow:Show()
    glow:SetScript("OnUpdate", function(selfGlow, delta)
        if runtime[tokenField] ~= token then
            selfGlow:SetScript("OnUpdate", nil)
            return
        end

        local remaining = math.max(0, (tonumber(selfGlow._remaining) or SEARCH_DROPDOWN_GLOW_DURATION) - (tonumber(delta) or 0))
        selfGlow._remaining = remaining
        local progress = SEARCH_DROPDOWN_GLOW_DURATION > 0 and (remaining / SEARCH_DROPDOWN_GLOW_DURATION) or 0
        selfGlow:SetAlpha(math.max(0, math.min(1, progress * progress)))
        if remaining <= 0 then
            selfGlow:SetAlpha(0)
            selfGlow:Hide()
            selfGlow._remaining = nil
            selfGlow:SetScript("OnUpdate", nil)
        end
    end)
    glow._remaining = SEARCH_DROPDOWN_GLOW_DURATION
end

local function maybePlaySearchDropdownShimmer(runtime)
    if not runtime or runtime.searchDropdownVisible ~= true then
        return
    end

    local _, maxScroll = getSearchDropdownScrollMetrics(runtime)
    local openToken = tonumber(runtime.searchDropdownOpenToken) or 0
    if maxScroll <= 0 or openToken <= 0 or runtime.searchDropdownShimmerPlayedToken == openToken then
        return
    end

    runtime.searchDropdownShimmerPlayedToken = openToken
    if not runtime.searchDropdownShimmer then
        return
    end

    local function startShimmer()
        local _, currentMaxScroll = getSearchDropdownScrollMetrics(runtime)
        if not runtime
            or runtime.searchDropdownVisible ~= true
            or runtime.searchDropdownOpenToken ~= openToken
            or currentMaxScroll <= 0
        then
            return
        end

        stopSearchDropdownShimmer(runtime)
        runtime.searchDropdownShimmerToken = (tonumber(runtime.searchDropdownShimmerToken) or 0) + 1
        local token = runtime.searchDropdownShimmerToken
        local shimmer = runtime.searchDropdownShimmer
        shimmer._elapsed = 0
        shimmer:SetAlpha(1)
        shimmer:Show()
        shimmer:SetScript("OnUpdate", function(selfShimmer, delta)
            if runtime.searchDropdownShimmerToken ~= token or runtime.searchDropdownOpenToken ~= openToken then
                selfShimmer:SetScript("OnUpdate", nil)
                selfShimmer:SetAlpha(0)
                selfShimmer:Hide()
                return
            end

            local elapsed = (tonumber(selfShimmer._elapsed) or 0) + (tonumber(delta) or 0)
            selfShimmer._elapsed = elapsed
            local progress = SEARCH_DROPDOWN_SHIMMER_DURATION > 0 and math.max(0, math.min(1, elapsed / SEARCH_DROPDOWN_SHIMMER_DURATION)) or 1
            local eased = easeInOut(progress)
            local parentWidth = tonumber(runtime.searchDropdownOverlay and runtime.searchDropdownOverlay.GetWidth and runtime.searchDropdownOverlay:GetWidth()) or 0
            local travelWidth = math.max(0, parentWidth - SEARCH_DROPDOWN_SHIMMER_WIDTH)
            local x = (SEARCH_DROPDOWN_SHIMMER_WIDTH * 0.5) + (travelWidth * eased)
            selfShimmer:ClearAllPoints()
            selfShimmer:SetPoint("CENTER", runtime.searchDropdownOverlay, "BOTTOMLEFT", x, SEARCH_DROPDOWN_EDGE_FADE_HEIGHT * 0.5)
            selfShimmer:SetAlpha(1 - math.abs((progress * 2) - 1))
            if progress >= 1 then
                selfShimmer._elapsed = nil
                selfShimmer:SetAlpha(0)
                selfShimmer:Hide()
                selfShimmer:SetScript("OnUpdate", nil)
            end
        end)
    end

    if C_Timer and C_Timer.After then
        C_Timer.After(SEARCH_DROPDOWN_SHIMMER_DELAY, startShimmer)
    else
        startShimmer()
    end
end

local function handleSearchDropdownMouseWheel(runtime, delta)
    if not runtime or runtime.searchDropdownVisible ~= true then
        return
    end

    local currentValue, maxScroll = getSearchDropdownScrollMetrics(runtime)
    if maxScroll <= 0 then
        updateSearchDropdownOverflowIndicators(runtime, false)
        return
    end

    local step = (tonumber(delta) or 0) * SEARCH_DROPDOWN_SCROLL_STEP
    if step == 0 then
        return
    end

    if step > 0 and currentValue <= 0.5 then
        triggerSearchDropdownGlow(runtime, "top")
    elseif step < 0 and currentValue >= (maxScroll - 0.5) then
        triggerSearchDropdownGlow(runtime, "bottom")
    end

    applySearchDropdownScroll(runtime, currentValue - step)
    updateSearchDropdownOverflowIndicators(runtime, false)
end

local function setSearchDropdownDecorativeFramePassThrough(frame)
    if not frame then
        return
    end
    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    if frame.EnableMouseWheel then
        frame:EnableMouseWheel(false)
    end
    if frame.SetMouseClickEnabled then
        frame:SetMouseClickEnabled(false)
    end
    if frame.SetMouseMotionEnabled then
        frame:SetMouseMotionEnabled(false)
    end
end

local function createSearchDropdownFadeOverlay(parent, topColor, bottomColor)
    local frame = CreateFrame("Frame", nil, parent)
    setSearchDropdownDecorativeFramePassThrough(frame)
    frame:SetAlpha(0)
    frame:Hide()

    local texture = frame:CreateTexture(nil, "ARTWORK")
    texture:SetAllPoints()
    texture:SetTexture("Interface\\Buttons\\WHITE8x8")
    setVerticalGradient(texture, topColor, bottomColor)
    frame.texture = texture
    return frame
end

local function createSearchDropdownCenteredBand(parent, peakColor)
    local frame = CreateFrame("Frame", nil, parent)
    setSearchDropdownDecorativeFramePassThrough(frame)
    frame:SetAlpha(0)
    frame:Hide()

    local leftTexture = frame:CreateTexture(nil, "ARTWORK")
    leftTexture:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    leftTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOM", 0, 0)
    leftTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    leftTexture:SetBlendMode("ADD")
    setHorizontalGradient(leftTexture, { peakColor[1], peakColor[2], peakColor[3], 0 }, peakColor)

    local rightTexture = frame:CreateTexture(nil, "ARTWORK")
    rightTexture:SetPoint("TOPLEFT", frame, "TOP", 0, 0)
    rightTexture:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    rightTexture:SetTexture("Interface\\Buttons\\WHITE8x8")
    rightTexture:SetBlendMode("ADD")
    setHorizontalGradient(rightTexture, peakColor, { peakColor[1], peakColor[2], peakColor[3], 0 })
    return frame
end

local function configureSearchResultRowLayout(row, entryKind, hasHelper, showBadge, showIcon)
    if not row or not row.label or not row.section or not row.iconHolder or not row.badge then
        return
    end

    row.label:ClearAllPoints()
    row.section:ClearAllPoints()
    row.badge:ClearAllPoints()
    row.badge:SetShown(false)
    row.section:SetShown(false)

    if entryKind == "control" then
        row.iconHolder:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
        row.iconHolder:SetShown(showIcon == true)
        if hasHelper then
            if showIcon == true then
                row.label:SetPoint("TOPLEFT", row.iconHolder, "TOPRIGHT", 8, 1)
            else
                row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -7)
            end
            row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            row.section:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
            row.section:SetPoint("RIGHT", row, "RIGHT", -10, 0)
            row.section:SetShown(true)
        else
            if showIcon == true then
                row.label:SetPoint("TOPLEFT", row.iconHolder, "TOPRIGHT", 8, -6)
            else
                row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -12)
            end
            row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        end
        return
    end

    row.iconHolder:Hide()
    if entryKind == "section_name" and showBadge then
        row.badge:SetPoint("RIGHT", row, "RIGHT", -10, 0)
        row.badge:SetShown(true)
        row.label:SetPoint("TOPLEFT", row, "TOPLEFT", 16, -12)
        row.label:SetPoint("RIGHT", row.badge, "LEFT", -8, 0)
        return
    end

    local leftInset = entryKind == "group_title" and 20 or 16
    row.label:SetPoint("TOPLEFT", row, "TOPLEFT", leftInset, -12)
    row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
end

local function setSearchResultRowIcon(row, iconType)
    if not row or not row.iconHolder then
        return
    end

    row.iconToggle:Hide()
    row.iconDropdown:Hide()
    row.iconSlider:Hide()

    if iconType == "toggle" then
        row.iconToggle:Show()
    elseif iconType == "dropdown" then
        row.iconDropdown:Show()
    elseif iconType == "slider" then
        row.iconSlider:Show()
    end

    row.iconHolder:SetShown(iconType == "toggle" or iconType == "dropdown" or iconType == "slider")
end

local function createSearchSectionHeaderRow(parent, runtime)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(SEARCH_SECTION_HEADER_HEIGHT)
    row:EnableMouse(false)
    row:EnableMouseWheel(false)
    row.divider = row:CreateTexture(nil, "BORDER")
    row.divider:SetPoint("TOPLEFT", row, "TOPLEFT", 10, 0)
    row.divider:SetPoint("TOPRIGHT", row, "TOPRIGHT", -10, 0)
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(unpackColor(SEARCH_GROUP_DIVIDER_COLOR))
    row.divider:Hide()
    row.label = row:CreateFontString(nil, "ARTWORK")
    row.label:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 10, 0)
    row.label:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -10, 0)
    row.label:SetJustifyH("LEFT")
    applyPremiumFont(row.label, 9, "", GameFontDisableSmall)
    row.label:SetTextColor(unpackColor(SEARCH_GROUP_HEADER_COLOR))
    if row.label.SetWordWrap then
        row.label:SetWordWrap(false)
    end
    if row.label.SetMaxLines then
        row.label:SetMaxLines(1)
    end
    row:SetScript("OnMouseWheel", function(_, delta)
        handleSearchDropdownMouseWheel(runtime, delta)
    end)
    return row
end

local function createSearchResultIconHolder(parent)
    local holder = CreateFrame("Frame", nil, parent)
    holder:SetSize(SEARCH_RESULT_ICON_SIZE, SEARCH_RESULT_ICON_SIZE)

    local toggle = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    toggle:SetAllPoints()
    toggle:SetBackdrop(PANEL_BACKDROP)
    toggle:SetBackdropColor(0, 0, 0, 0)
    toggle:SetBackdropBorderColor(unpackColor(SHELL_STYLE.searchIcon))
    local toggleKnob = toggle:CreateTexture(nil, "ARTWORK")
    toggleKnob:SetSize(5, 5)
    toggleKnob:SetPoint("RIGHT", toggle, "RIGHT", -2, 0)
    toggleKnob:SetColorTexture(unpackColor(SHELL_STYLE.searchIcon))
    toggle:Hide()

    local dropdown = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    dropdown:SetAllPoints()
    dropdown:SetBackdrop(PANEL_BACKDROP)
    dropdown:SetBackdropColor(0, 0, 0, 0)
    dropdown:SetBackdropBorderColor(unpackColor(SHELL_STYLE.searchIcon))
    local dropdownText = dropdown:CreateFontString(nil, "ARTWORK")
    dropdownText:SetPoint("CENTER", dropdown, "CENTER", 0, -1)
    applyPremiumFont(dropdownText, 9, "", GameFontDisableSmall)
    dropdownText:SetText("v")
    dropdownText:SetTextColor(unpackColor(SHELL_STYLE.searchIcon))
    dropdown:Hide()

    local slider = CreateFrame("Frame", nil, holder)
    slider:SetAllPoints()
    local sliderTrack = slider:CreateTexture(nil, "ARTWORK")
    sliderTrack:SetPoint("LEFT", slider, "LEFT", 1, 0)
    sliderTrack:SetPoint("RIGHT", slider, "RIGHT", -1, 0)
    sliderTrack:SetHeight(2)
    sliderTrack:SetColorTexture(unpackColor(SHELL_STYLE.searchIcon))
    local sliderKnob = slider:CreateTexture(nil, "ARTWORK")
    sliderKnob:SetSize(4, 8)
    sliderKnob:SetPoint("CENTER", slider, "CENTER", 0, 0)
    sliderKnob:SetColorTexture(unpackColor(SHELL_STYLE.searchIcon))
    slider:Hide()

    holder.toggle = toggle
    holder.dropdown = dropdown
    holder.slider = slider
    return holder
end

local function createSearchResultRow(parent, runtime)
    local row = CreateFrame("Button", nil, parent)
    row:SetHeight(SEARCH_RESULT_ROW_HEIGHT)
    row:EnableMouse(true)
    row:RegisterForClicks("LeftButtonUp")
    row:EnableMouseWheel(true)

    row.hover = row:CreateTexture(nil, "BACKGROUND")
    row.hover:SetAllPoints()
    row.hover:SetColorTexture(unpackColor(SEARCH_RESULT_HOVER_WASH))
    row.hover:Hide()

    row.iconHolder = CreateFrame("Frame", nil, row)
    row.iconHolder:SetPoint("TOPLEFT", row, "TOPLEFT", 10, -8)
    row.iconHolder:SetSize(SEARCH_RESULT_ICON_SIZE, SEARCH_RESULT_ICON_SIZE)

    local iconHolder = createSearchResultIconHolder(row.iconHolder)
    iconHolder:SetAllPoints()
    row.iconToggle = iconHolder.toggle
    row.iconDropdown = iconHolder.dropdown
    row.iconSlider = iconHolder.slider

    row.label = row:CreateFontString(nil, "ARTWORK")
    row.label:SetPoint("TOPLEFT", row.iconHolder, "TOPRIGHT", 8, 1)
    row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.label:SetJustifyH("LEFT")
    applyPremiumFont(row.label, 12, "", GameFontNormal)
    row.label:SetTextColor(unpackColor(SEARCH_RESULT_TEXT_COLOR))
    if row.label.SetWordWrap then
        row.label:SetWordWrap(false)
    end
    if row.label.SetMaxLines then
        row.label:SetMaxLines(1)
    end

    row.badge = row:CreateFontString(nil, "ARTWORK")
    row.badge:SetJustifyH("RIGHT")
    applyPremiumFont(row.badge, 9, "", GameFontDisableSmall)
    row.badge:SetTextColor(unpackColor(SEARCH_GROUP_HEADER_COLOR))
    row.badge:SetText("SECTION")
    row.badge:Hide()

    row.section = row:CreateFontString(nil, "ARTWORK")
    row.section:SetPoint("TOPLEFT", row.label, "BOTTOMLEFT", 0, -2)
    row.section:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.section:SetJustifyH("LEFT")
    applyPremiumFont(row.section, 10, "", GameFontDisableSmall)
    row.section:SetTextColor(unpackColor(SEARCH_RESULT_HELPER_COLOR))
    if row.section.SetWordWrap then
        row.section:SetWordWrap(false)
    end
    if row.section.SetMaxLines then
        row.section:SetMaxLines(1)
    end

    row:SetScript("OnEnter", function(selfRow)
        selfRow.hover:Show()
    end)
    row:SetScript("OnLeave", function(selfRow)
        selfRow.hover:Hide()
    end)
    row:SetScript("OnMouseDown", function(selfRow, button)
        if button ~= "LeftButton" then
            return
        end
        selfRow._mouseDownToken = beginSearchResultClickTransaction(runtime, selfRow._entry)
    end)
    row:SetScript("OnClick", function(selfRow)
        debugSearchClickPrint("PA SEARCH: row clicked, entry=", runtime.searchResultClickEntry and runtime.searchResultClickEntry.displayLabel or "NIL")
        local entry = runtime.searchResultClickEntry
        if selfRow._mouseDownToken ~= runtime.searchResultClickToken or runtime.searchResultClickState ~= "armed" or type(entry) ~= "table" then
            clearSearchResultClickTransaction(runtime, selfRow._mouseDownToken)
            selfRow._mouseDownToken = nil
            return
        end
        runtime.searchResultClickState = "committing"
        runtime.searchResultCommitOwnerToken = runtime.searchResultClickToken
        handleSearchResultSelected(PortalAuthority, entry)
        selfRow._mouseDownToken = nil
    end)
    row:SetScript("OnMouseWheel", function(_, delta)
        handleSearchDropdownMouseWheel(runtime, delta)
    end)
    row:SetScript("OnHide", function(selfRow)
        selfRow._mouseDownToken = nil
        selfRow.hover:Hide()
        if selfRow._entry == nil and runtime.searchResultClickState == "armed" then
            clearSearchResultClickTransaction(runtime, runtime.searchResultClickToken)
        end
    end)
    return row
end

local function hideSearchDropdownRows(runtime)
    if not runtime then
        return
    end
    for i = 1, #(runtime.searchDropdownResultRows or {}) do
        runtime.searchDropdownResultRows[i]:Hide()
        runtime.searchDropdownResultRows[i]._entry = nil
    end
    for i = 1, #(runtime.searchDropdownHeaderRows or {}) do
        runtime.searchDropdownHeaderRows[i]:Hide()
    end
    if runtime.searchDropdownNoResults then
        runtime.searchDropdownNoResults:Hide()
    end
end

hideSearchDropdown = function(runtime, opts)
    if not runtime then
        return
    end
    local activeToken = runtime.searchResultClickToken
    local activeState = runtime.searchResultClickState
    runtime.searchDropdownVisible = false
    clearActiveNoResultsMessage(runtime)
    hideSearchDropdownIndicators(runtime)
    hideSearchDropdownRows(runtime)
    if runtime.searchDropdownScrollFrame and runtime.searchDropdownScrollFrame.SetVerticalScroll then
        runtime.searchDropdownScrollFrame:SetVerticalScroll(0)
    end
    if runtime.searchDropdown then
        runtime.searchDropdown:Hide()
    end
    if activeState == "armed" then
        clearSearchResultClickTransaction(runtime, activeToken)
    elseif activeState == "committing" then
        local isCommitOwnedHide = opts
            and opts.commitOwned == true
            and opts.clickToken
            and runtime.searchResultCommitOwnerToken == opts.clickToken
        if opts and opts.forceAbort == true and not isCommitOwnedHide then
            clearSearchResultClickTransaction(runtime, activeToken)
        end
    end
end

local function ensureSearchResultRow(runtime, index)
    runtime.searchDropdownResultRows = runtime.searchDropdownResultRows or {}
    if not runtime.searchDropdownResultRows[index] then
        runtime.searchDropdownResultRows[index] = createSearchResultRow(runtime.searchDropdownContent, runtime)
    end
    return runtime.searchDropdownResultRows[index]
end

local function ensureSearchHeaderRow(runtime, index)
    runtime.searchDropdownHeaderRows = runtime.searchDropdownHeaderRows or {}
    if not runtime.searchDropdownHeaderRows[index] then
        runtime.searchDropdownHeaderRows[index] = createSearchSectionHeaderRow(runtime.searchDropdownContent, runtime)
    end
    return runtime.searchDropdownHeaderRows[index]
end

local function getSearchDropdownContentWidth(runtime)
    if not runtime then
        return 1
    end
    local scrollFrame = runtime.searchDropdownScrollFrame
    local dropdown = runtime.searchDropdown
    local width = tonumber(scrollFrame and scrollFrame.GetWidth and scrollFrame:GetWidth()) or 0
    if width <= 1 then
        width = tonumber(dropdown and dropdown.GetWidth and dropdown:GetWidth()) or 0
    end
    return math.max(1, math.floor(width + 0.5))
end

local function renderSearchDropdown(self, runtime, results)
    if not runtime or not runtime.searchDropdown or not runtime.searchDropdownContent then
        return
    end

    local wasVisible = runtime.searchDropdownVisible == true and runtime.searchDropdown and runtime.searchDropdown.IsShown and runtime.searchDropdown:IsShown()
    hideSearchDropdownRows(runtime)

    local content = runtime.searchDropdownContent
    local contentWidth = getSearchDropdownContentWidth(runtime)
    if content.SetWidth then
        content:SetWidth(contentWidth)
    end
    local y = -SEARCH_DROPDOWN_CONTENT_TOP_PADDING
    local headerIndex = 0
    local rowIndex = 0
    local lastSectionKey = nil

    if #results <= 0 then
        clearSearchHighlight(runtime)
        local noResults = runtime.searchDropdownNoResults
        if noResults then
            noResults:SetText(getActiveNoResultsMessage(runtime))
            noResults:ClearAllPoints()
            noResults:SetPoint("TOPLEFT", content, "TOPLEFT", 12, -16)
            noResults:SetPoint("TOPRIGHT", content, "TOPRIGHT", -12, -16)
            noResults:SetWidth(math.max(1, contentWidth - 24))
            noResults:Show()
        end
        content:SetHeight(SEARCH_DROPDOWN_NO_RESULTS_HEIGHT)
        runtime.searchDropdown:SetHeight(SEARCH_DROPDOWN_NO_RESULTS_HEIGHT + 2)
        runtime.searchDropdown:Show()
        if not wasVisible then
            runtime.searchDropdownOpenToken = (tonumber(runtime.searchDropdownOpenToken) or 0) + 1
        end
        runtime.searchDropdownVisible = true
        applySearchDropdownScroll(runtime, 0)
        updateSearchDropdownOverflowIndicators(runtime, true)
        return
    end

    clearActiveNoResultsMessage(runtime)
    for i = 1, #results do
        local entry = results[i]
        if entry.sectionKey ~= lastSectionKey then
            if lastSectionKey ~= nil then
                y = y - SEARCH_SECTION_HEADER_GAP
            end
            headerIndex = headerIndex + 1
            local headerRow = ensureSearchHeaderRow(runtime, headerIndex)
            headerRow:SetWidth(contentWidth)
            headerRow:ClearAllPoints()
            headerRow:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
            headerRow:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
            headerRow.label:SetText(string.upper(formatSearchResultText(entry.sectionName or "")))
            headerRow.divider:SetShown(lastSectionKey ~= nil)
            headerRow:Show()
            y = y - SEARCH_SECTION_HEADER_HEIGHT
            lastSectionKey = entry.sectionKey
        end

        rowIndex = rowIndex + 1
        local row = ensureSearchResultRow(runtime, rowIndex)
        row:SetWidth(contentWidth)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, y)
        row:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, y)
        row._entry = entry
        local entryKind = type(entry.kind) == "string" and entry.kind or "control"
        local primaryText = formatSearchResultText(entry.displayLabel or entry.labelText or entry.sectionName or "")
        local secondaryText = ""
        local iconType = nil
        local showBadge = false
        if entryKind == "control" then
            secondaryText = formatSearchResultText(entry.displayHelper or entry.helperText or "")
            iconType = entry.iconType
        elseif entryKind == "group_title" then
            primaryText = string.upper(primaryText)
        elseif entryKind == "section_name" then
            showBadge = true
        end

        local displayText = primaryText
        if entryKind == "control" then
            displayText = select(1, formatHighlightedLabel(primaryText, runtime.searchActiveQuery))
        end

        configureSearchResultRowLayout(row, entryKind, secondaryText ~= "", showBadge, iconType ~= nil)
        row.badge:SetText("SECTION")
        row.badge:SetShown(showBadge)
        row.label:SetText(displayText)
        row.section:SetText(secondaryText)
        setSearchResultRowIcon(row, iconType)

        if entryKind == "control" then
            applyPremiumFont(row.label, 12, "", GameFontNormal)
            row.label:SetTextColor(unpackColor(SEARCH_RESULT_TEXT_COLOR))
            applyPremiumFont(row.section, 10, "", GameFontDisableSmall)
            row.section:SetTextColor(unpackColor(SEARCH_RESULT_HELPER_COLOR))
        elseif entryKind == "group_title" then
            applyPremiumFont(row.label, 10, "", GameFontDisableSmall)
            row.label:SetTextColor(unpackColor(SEARCH_RESULT_GROUP_TITLE_COLOR))
        else
            applyPremiumFont(row.label, 12, "", GameFontNormal)
            row.label:SetTextColor(unpackColor(SEARCH_RESULT_SECTION_COLOR))
            applyPremiumFont(row.badge, 9, "", GameFontDisableSmall)
            row.badge:SetTextColor(unpackColor(SEARCH_GROUP_HEADER_COLOR))
        end

        row:Show()
        y = y - SEARCH_RESULT_ROW_HEIGHT
    end

    local contentHeight = math.max(1, (-y) + SEARCH_DROPDOWN_CONTENT_BOTTOM_PADDING)
    local maxVisibleHeight = getSearchDropdownMaxVisibleHeight(runtime)
    content:SetHeight(contentHeight)
    runtime.searchDropdown:SetHeight(math.min(maxVisibleHeight, contentHeight + 2))
    runtime.searchDropdown:Show()
    if not wasVisible then
        runtime.searchDropdownOpenToken = (tonumber(runtime.searchDropdownOpenToken) or 0) + 1
    end
    runtime.searchDropdownVisible = true
    local currentScroll = wasVisible and (tonumber(runtime.searchDropdownScrollFrame and runtime.searchDropdownScrollFrame.GetVerticalScroll and runtime.searchDropdownScrollFrame:GetVerticalScroll()) or 0) or 0
    applySearchDropdownScroll(runtime, currentScroll)
    updateSearchDropdownOverflowIndicators(runtime, not wasVisible)
    if not wasVisible then
        maybePlaySearchDropdownShimmer(runtime)
    end
end

clearSearchState = function(self, opts)
    local runtime = ensureRuntime(self)
    opts = type(opts) == "table" and opts or {}

    if opts.clearHighlight ~= false then
        clearSearchHighlight(runtime)
    end
    if opts.hideDropdown ~= false then
        hideSearchDropdown(runtime)
    end
    if opts.clearText ~= false then
        setSearchTextSilently(runtime, "")
        resetSearchQueryState(runtime)
        clearActiveNoResultsMessage(runtime)
    end
    if opts.clearFocus ~= false and runtime.searchEdit and runtime.searchEdit.ClearFocus then
        runtime.searchEdit:ClearFocus()
    end
    updateSearchPlaceholder(runtime)
end

local function runSearchFilter(self, runtime, userText)
    if not runtime then
        return
    end

    local normalizedQuery = normalizeSearchQuery(userText)
    if normalizedQuery == "" or string.len(normalizedQuery) < SEARCH_MIN_QUERY_CHARS then
        clearSearchHighlight(runtime)
        hideSearchDropdown(runtime)
        resetSearchQueryState(runtime)
        return
    end

    clearSearchHighlight(runtime)
    runtime.searchActiveQuery = normalizedQuery
    local results = filterSearchCatalog(self, runtime, normalizedQuery)
    renderSearchDropdown(self, runtime, results)
end

local function createNavButton(self, parent, key, labelText)
    local runtime = ensureRuntime(self)
    local button = CreateFrame("Button", nil, parent)
    button:SetHeight(NAV_ROW_HEIGHT)
    button:SetPoint("LEFT", parent, "LEFT", 0, 0)
    button:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

    button.wash = button:CreateTexture(nil, "BACKGROUND")
    button.wash:SetAllPoints()
    button.wash:SetColorTexture(unpackColor(SHELL_STYLE.navWash))
    button.wash:Hide()

    button.label = button:CreateFontString(nil, "ARTWORK")
    button.label:SetPoint("LEFT", button, "LEFT", 22, 0)
    button.label:SetJustifyH("LEFT")
    applyPremiumFont(button.label, 13, "", GameFontNormal)
    button.label:SetText(labelText or key)
    button.label:SetTextColor(unpackColor(SHELL_STYLE.navIdleText))

    button:SetScript("OnEnter", function(selfButton)
        if runtime.activeNavKey ~= key and selfButton.label then
            selfButton.label:SetTextColor(unpackColor(SHELL_STYLE.navHoverText))
        end
    end)
    button:SetScript("OnLeave", function(selfButton)
        if selfButton.label then
            if runtime.activeNavKey == key then
                selfButton.label:SetTextColor(unpackColor(SHELL_STYLE.navActiveText))
            else
                selfButton.label:SetTextColor(unpackColor(SHELL_STYLE.navIdleText))
            end
        end
    end)
    button:SetScript("OnClick", function()
        clearSearchState(PortalAuthority, {
            clearText = true,
            clearFocus = true,
            hideDropdown = true,
            clearHighlight = true,
        })
        selectSection(PortalAuthority, key, false)
    end)

    runtime.navButtons[key] = button
    return button
end

local function createSidebarTeaserRow(parent, labelText, badgeText)
    local row = CreateFrame("Frame", nil, parent)
    row:SetHeight(NAV_ROW_HEIGHT)
    row:SetPoint("LEFT", parent, "LEFT", 0, 0)
    row:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
    row:EnableMouse(false)

    row.label = row:CreateFontString(nil, "ARTWORK")
    row.label:SetPoint("LEFT", row, "LEFT", 22, 0)
    row.label:SetJustifyH("LEFT")
    applyPremiumFont(row.label, 13, "", GameFontNormal)
    row.label:SetText(tostring(labelText or ""))
    row.label:SetTextColor(unpackColor(SHELL_STYLE.navTeaserText))
    if row.label.SetWordWrap then
        row.label:SetWordWrap(false)
    end
    if row.label.SetMaxLines then
        row.label:SetMaxLines(1)
    end

    row.badge = CreateFrame("Frame", nil, row, "BackdropTemplate")
    row.badge:SetBackdrop(PANEL_BACKDROP)
    row.badge:SetBackdropColor(unpackColor(SHELL_STYLE.navSoonBadgeBg))
    row.badge:SetBackdropBorderColor(unpackColor(SHELL_STYLE.navSoonBadgeBorder))
    row.badge:EnableMouse(false)

    row.badge.text = row.badge:CreateFontString(nil, "ARTWORK")
    row.badge.text:SetPoint("CENTER", row.badge, "CENTER", 0, 0)
    row.badge.text:SetJustifyH("CENTER")
    applyPremiumFont(row.badge.text, 8, "", GameFontDisableSmall)
    row.badge.text:SetText(tostring(badgeText or ""))
    row.badge.text:SetTextColor(unpackColor(SHELL_STYLE.navSoonBadgeText))
    if row.badge.text.SetWordWrap then
        row.badge.text:SetWordWrap(false)
    end
    if row.badge.text.SetMaxLines then
        row.badge.text:SetMaxLines(1)
    end

    local badgeWidth = math.max(32, math.ceil((row.badge.text.GetStringWidth and row.badge.text:GetStringWidth() or 0) + 12))
    local badgeHeight = math.max(12, math.ceil((row.badge.text.GetStringHeight and row.badge.text:GetStringHeight() or 0) + 4))
    row.badge:SetSize(badgeWidth, badgeHeight)
    row.badge:SetPoint("RIGHT", row, "RIGHT", -10, 0)

    row.label:SetPoint("RIGHT", row.badge, "LEFT", -10, 0)
    return row
end

local function createWindow(self)
    local runtime = ensureRuntime(self)
    if runtime.window then
        return runtime.window
    end

    local frame = CreateFrame("Frame", WINDOW_NAME, UIParent, "BackdropTemplate")
    frame:SetSize(WINDOW_WIDTH, WINDOW_HEIGHT)
    frame:SetFrameStrata("DIALOG")
    frame:SetToplevel(true)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetBackdrop(PANEL_BACKDROP)
    frame:SetBackdropColor(unpackColor(SHELL_STYLE.windowBg))
    frame:SetBackdropBorderColor(unpackColor(SHELL_STYLE.windowBorder))
    frame:Hide()

    ensureSpecialFrame(WINDOW_NAME)

    runtime.window = frame
    runtime.navButtons = runtime.navButtons or {}
    frame._paRuntime = runtime
    self.settingsWindow = frame
    self._settingsWindow = frame
    self.SettingsWindow = frame

    local parkingFrame = CreateFrame("Frame", nil, UIParent)
    parkingFrame:SetSize(1, 1)
    parkingFrame:Hide()
    runtime.panelParkingFrame = parkingFrame

    local sidebar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    sidebar:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    sidebar:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    sidebar:SetWidth(SIDEBAR_WIDTH)
    sidebar:SetBackdrop(PANEL_BACKDROP)
    sidebar:SetBackdropColor(unpackColor(SHELL_STYLE.sidebarBg))
    sidebar:SetBackdropBorderColor(0, 0, 0, 0)
    runtime.sidebar = sidebar

    local sidebarDivider = sidebar:CreateTexture(nil, "BORDER")
    sidebarDivider:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
    sidebarDivider:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
    sidebarDivider:SetWidth(1)
    sidebarDivider:SetColorTexture(unpackColor(SHELL_STYLE.sidebarDivider))

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", SIDEBAR_WIDTH + 1, 0)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    runtime.content = content

    local closeButton = CreateFrame("Button", nil, frame, "BackdropTemplate")
    closeButton:SetSize(26, 26)
    closeButton:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -12, -12)
    closeButton:SetBackdrop(PANEL_BACKDROP)
    closeButton:SetBackdropColor(unpackColor(SHELL_STYLE.windowBg))
    closeButton:SetBackdropBorderColor(unpackColor(SHELL_STYLE.closeBorderIdle))
    closeButton.text = closeButton:CreateFontString(nil, "OVERLAY")
    closeButton.text:SetPoint("CENTER")
    applyPremiumFont(closeButton.text, 15, "", GameFontNormal)
    closeButton.text:SetText("x")
    closeButton.text:SetTextColor(unpackColor(SHELL_STYLE.closeTextIdle))
    closeButton:SetScript("OnEnter", function(selfButton)
        selfButton:SetBackdropBorderColor(unpackColor(SHELL_STYLE.closeBorderHover))
        selfButton.text:SetTextColor(unpackColor(SHELL_STYLE.closeTextHover))
    end)
    closeButton:SetScript("OnLeave", function(selfButton)
        selfButton:SetBackdropBorderColor(unpackColor(SHELL_STYLE.closeBorderIdle))
        selfButton.text:SetTextColor(unpackColor(SHELL_STYLE.closeTextIdle))
    end)
    closeButton:SetScript("OnClick", function()
        PortalAuthority:CloseSettingsWindow()
    end)
    runtime.closeButton = closeButton

    local logoButton = CreateFrame("Button", nil, sidebar)
    logoButton:SetPoint("TOPLEFT", sidebar, "TOPLEFT", 0, 0)
    logoButton:SetPoint("TOPRIGHT", sidebar, "TOPRIGHT", 0, 0)
    logoButton:SetHeight(78)
    runtime.logoButton = logoButton

    local logoTexture = logoButton:CreateTexture(nil, "ARTWORK")
    logoTexture:SetSize(36, 36)
    logoTexture:SetPoint("LEFT", logoButton, "LEFT", 18, -2)
    logoTexture:SetTexture("Interface\\AddOns\\PortalAuthority\\Media\\Images\\PA_logo_76x76_transparent.png")

    local wordmark = logoButton:CreateFontString(nil, "ARTWORK")
    wordmark:SetPoint("LEFT", logoTexture, "RIGHT", 12, 6)
    wordmark:SetJustifyH("LEFT")
    applyPremiumFont(wordmark, 14, "", GameFontNormal)
    wordmark:SetText("Portal Authority")
    wordmark:SetTextColor(unpackColor(SHELL_STYLE.wordmark))

    local homeHint = CreateFrame("Frame", nil, logoButton)
    homeHint:SetPoint("TOPLEFT", wordmark, "BOTTOMLEFT", 0, -2)
    homeHint:SetSize(48, 12)
    homeHint:SetAlpha(0)
    runtime.homeHint = homeHint

    local homeHintText = homeHint:CreateFontString(nil, "ARTWORK")
    homeHintText:SetAllPoints()
    homeHintText:SetJustifyH("LEFT")
    applyPremiumFont(homeHintText, 9, "", GameFontNormalSmall)
    homeHintText:SetText("Home")
    homeHintText:SetTextColor(unpackColor(SHELL_STYLE.homeHint))
    runtime.homeHintText = homeHintText

    logoButton:SetScript("OnEnter", function(selfButton)
        wordmark:SetTextColor(0.784, 0.784, 0.816, 1)
        startAlphaTween(homeHint, runtime, "hintToken", homeHint:GetAlpha(), 1, HINT_FADE_DURATION)
    end)
    logoButton:SetScript("OnLeave", function(selfButton)
        wordmark:SetTextColor(unpackColor(SHELL_STYLE.wordmark))
        startAlphaTween(homeHint, runtime, "hintToken", homeHint:GetAlpha(), 0, HINT_FADE_DURATION)
    end)
    logoButton:SetScript("OnClick", function()
        clearSearchState(PortalAuthority, {
            clearText = true,
            clearFocus = true,
            hideDropdown = true,
            clearHighlight = true,
        })
        selectSection(PortalAuthority, "root", false)
    end)

    local separator = CreateFrame("Frame", nil, sidebar)
    separator:SetHeight(1)
    separator:SetPoint("TOPLEFT", logoButton, "BOTTOMLEFT", 18, -2)
    separator:SetPoint("TOPRIGHT", logoButton, "BOTTOMRIGHT", -18, -2)
    local separatorTexture = separator:CreateTexture(nil, "BORDER")
    separatorTexture:SetAllPoints()
    separatorTexture:SetColorTexture(unpackColor(SHELL_STYLE.sectionDivider))

    local searchArea = CreateFrame("Frame", nil, sidebar)
    searchArea:SetPoint("BOTTOMLEFT", sidebar, "BOTTOMLEFT", 0, 0)
    searchArea:SetPoint("BOTTOMRIGHT", sidebar, "BOTTOMRIGHT", 0, 0)
    searchArea:SetHeight(58)
    runtime.searchArea = searchArea

    local searchDivider = searchArea:CreateTexture(nil, "BORDER")
    searchDivider:SetPoint("TOPLEFT", searchArea, "TOPLEFT", 0, 0)
    searchDivider:SetPoint("TOPRIGHT", searchArea, "TOPRIGHT", 0, 0)
    searchDivider:SetHeight(1)
    searchDivider:SetColorTexture(unpackColor(SHELL_STYLE.sidebarDivider))

    local searchBox = CreateFrame("Frame", nil, searchArea, "BackdropTemplate")
    searchBox:SetPoint("TOPLEFT", searchArea, "TOPLEFT", 14, -12)
    searchBox:SetPoint("BOTTOMRIGHT", searchArea, "BOTTOMRIGHT", -14, 12)
    searchBox:SetBackdrop(PANEL_BACKDROP)
    searchBox:SetBackdropColor(unpackColor(SHELL_STYLE.searchBg))
    searchBox:SetBackdropBorderColor(unpackColor(SHELL_STYLE.searchBorderIdle))
    runtime.searchBox = searchBox

    local searchGlowTexture = searchArea:CreateTexture(nil, "BACKGROUND")
    searchGlowTexture:SetPoint("TOPLEFT", searchBox, "TOPLEFT", -8, 8)
    searchGlowTexture:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", 8, -8)
    searchGlowTexture:SetColorTexture(unpackColor(SEARCH_INTRO_GLOW_COLOR))
    searchGlowTexture:SetBlendMode("ADD")
    searchGlowTexture:SetAlpha(0)
    runtime.searchGlowTexture = searchGlowTexture

    local searchIcon = searchBox:CreateTexture(nil, "ARTWORK")
    searchIcon:SetSize(14, 14)
    searchIcon:SetPoint("LEFT", searchBox, "LEFT", 8, 0)
    searchIcon:SetTexture("Interface\\Common\\UI-Searchbox-Icon")
    searchIcon:SetVertexColor(unpackColor(SHELL_STYLE.searchIcon))

    local searchEdit = CreateFrame("EditBox", nil, searchBox)
    searchEdit:SetAutoFocus(false)
    searchEdit:SetPoint("TOPLEFT", searchBox, "TOPLEFT", 28, -4)
    searchEdit:SetPoint("BOTTOMRIGHT", searchBox, "BOTTOMRIGHT", -10, 4)
    if searchEdit.SetJustifyH then
        searchEdit:SetJustifyH("LEFT")
    end
    if searchEdit.SetJustifyV then
        searchEdit:SetJustifyV("MIDDLE")
    end
    if searchEdit.SetTextInsets then
        searchEdit:SetTextInsets(0, 0, 0, 0)
    end
    searchEdit:SetText("")
    if searchEdit.SetTextColor then
        searchEdit:SetTextColor(unpackColor(SHELL_STYLE.searchText))
    end
    if searchEdit.SetPropagateKeyboardInput then
        searchEdit:SetPropagateKeyboardInput(false)
    end
    applyPremiumFont(searchEdit, 12, "", ChatFontNormal)
    runtime.searchEdit = searchEdit

    local searchPlaceholder = searchBox:CreateFontString(nil, "ARTWORK")
    searchPlaceholder:SetPoint("LEFT", searchBox, "LEFT", 28, 0)
    searchPlaceholder:SetJustifyH("LEFT")
    applyPremiumFont(searchPlaceholder, 11, "", GameFontDisableSmall)
    searchPlaceholder:SetText("Search...")
    searchPlaceholder:SetTextColor(unpackColor(SHELL_STYLE.searchPlaceholder))
    runtime.searchPlaceholder = searchPlaceholder
    updateSearchPlaceholder(runtime)

    local searchDropdown = CreateFrame("Frame", nil, searchArea, "BackdropTemplate")
    searchDropdown:SetPoint("BOTTOMLEFT", searchBox, "TOPLEFT", 0, 8)
    searchDropdown:SetPoint("BOTTOMRIGHT", searchBox, "TOPRIGHT", 0, 8)
    searchDropdown:SetHeight(60)
    searchDropdown:SetFrameStrata("FULLSCREEN_DIALOG")
    searchDropdown:SetFrameLevel(math.max(sidebar:GetFrameLevel(), searchArea:GetFrameLevel()) + 40)
    searchDropdown:SetBackdrop(PANEL_BACKDROP)
    searchDropdown:SetBackdropColor(unpackColor(SEARCH_DROPDOWN_BG_COLOR))
    searchDropdown:SetBackdropBorderColor(unpackColor(SEARCH_DROPDOWN_BORDER_COLOR))
    searchDropdown:EnableMouse(false)
    searchDropdown:EnableMouseWheel(false)
    searchDropdown:Hide()
    runtime.searchDropdown = searchDropdown

    local searchDropdownShadow = searchDropdown:CreateTexture(nil, "BACKGROUND")
    searchDropdownShadow:SetPoint("TOPLEFT", searchDropdown, "TOPLEFT", -8, 8)
    searchDropdownShadow:SetPoint("BOTTOMRIGHT", searchDropdown, "BOTTOMRIGHT", 8, -8)
    searchDropdownShadow:SetColorTexture(unpackColor(SEARCH_DROPDOWN_SHADOW_COLOR))

    local searchDropdownScrollFrame = CreateFrame("ScrollFrame", nil, searchDropdown)
    searchDropdownScrollFrame:SetPoint("TOPLEFT", searchDropdown, "TOPLEFT", 0, -1)
    searchDropdownScrollFrame:SetPoint("BOTTOMRIGHT", searchDropdown, "BOTTOMRIGHT", 0, 1)
    searchDropdownScrollFrame:EnableMouse(true)
    searchDropdownScrollFrame:EnableMouseWheel(true)
    runtime.searchDropdownScrollFrame = searchDropdownScrollFrame

    local searchDropdownContent = CreateFrame("Frame", nil, searchDropdownScrollFrame)
    searchDropdownContent:SetPoint("TOPLEFT", searchDropdownScrollFrame, "TOPLEFT", 0, 0)
    searchDropdownContent:SetPoint("TOPRIGHT", searchDropdownScrollFrame, "TOPRIGHT", 0, 0)
    searchDropdownContent:SetHeight(1)
    searchDropdownContent:EnableMouse(false)
    searchDropdownContent:EnableMouseWheel(false)
    searchDropdownScrollFrame:SetScrollChild(searchDropdownContent)
    runtime.searchDropdownContent = searchDropdownContent

    local searchDropdownNoResults = searchDropdownContent:CreateFontString(nil, "ARTWORK")
    searchDropdownNoResults:SetJustifyH("CENTER")
    searchDropdownNoResults:SetJustifyV("MIDDLE")
    applyPremiumFont(searchDropdownNoResults, 11, "ITALIC", GameFontDisableSmall)
    searchDropdownNoResults:SetTextColor(unpackColor(SEARCH_GROUP_HEADER_COLOR))
    searchDropdownNoResults:Hide()
    runtime.searchDropdownNoResults = searchDropdownNoResults

    local searchDropdownOverlay = CreateFrame("Frame", nil, searchDropdown)
    searchDropdownOverlay:SetPoint("TOPLEFT", searchDropdown, "TOPLEFT", 1, -1)
    searchDropdownOverlay:SetPoint("BOTTOMRIGHT", searchDropdown, "BOTTOMRIGHT", -1, 1)
    searchDropdownOverlay:SetFrameLevel(searchDropdownScrollFrame:GetFrameLevel() + 20)
    setSearchDropdownDecorativeFramePassThrough(searchDropdownOverlay)
    runtime.searchDropdownOverlay = searchDropdownOverlay

    local searchDropdownTopFade = createSearchDropdownFadeOverlay(
        searchDropdownOverlay,
        SEARCH_OVERFLOW_FADE_COLOR,
        { SEARCH_OVERFLOW_FADE_COLOR[1], SEARCH_OVERFLOW_FADE_COLOR[2], SEARCH_OVERFLOW_FADE_COLOR[3], 0 }
    )
    searchDropdownTopFade:SetPoint("TOPLEFT", searchDropdownOverlay, "TOPLEFT", 0, 0)
    searchDropdownTopFade:SetPoint("TOPRIGHT", searchDropdownOverlay, "TOPRIGHT", 0, 0)
    searchDropdownTopFade:SetHeight(SEARCH_DROPDOWN_EDGE_FADE_HEIGHT)
    runtime.searchDropdownTopFade = searchDropdownTopFade

    local searchDropdownBottomFade = createSearchDropdownFadeOverlay(
        searchDropdownOverlay,
        { SEARCH_OVERFLOW_FADE_COLOR[1], SEARCH_OVERFLOW_FADE_COLOR[2], SEARCH_OVERFLOW_FADE_COLOR[3], 0 },
        SEARCH_OVERFLOW_FADE_COLOR
    )
    searchDropdownBottomFade:SetPoint("BOTTOMLEFT", searchDropdownOverlay, "BOTTOMLEFT", 0, 0)
    searchDropdownBottomFade:SetPoint("BOTTOMRIGHT", searchDropdownOverlay, "BOTTOMRIGHT", 0, 0)
    searchDropdownBottomFade:SetHeight(SEARCH_DROPDOWN_EDGE_FADE_HEIGHT)
    runtime.searchDropdownBottomFade = searchDropdownBottomFade

    local searchDropdownShimmer = createSearchDropdownCenteredBand(searchDropdownOverlay, SEARCH_OVERFLOW_SHIMMER_COLOR)
    searchDropdownShimmer:SetSize(SEARCH_DROPDOWN_SHIMMER_WIDTH, SEARCH_DROPDOWN_EDGE_FADE_HEIGHT)
    runtime.searchDropdownShimmer = searchDropdownShimmer

    local searchDropdownTopGlow = createSearchDropdownCenteredBand(searchDropdownOverlay, SEARCH_OVERFLOW_GLOW_COLOR)
    searchDropdownTopGlow:SetPoint("TOPLEFT", searchDropdownOverlay, "TOPLEFT", 0, 0)
    searchDropdownTopGlow:SetPoint("TOPRIGHT", searchDropdownOverlay, "TOPRIGHT", 0, 0)
    searchDropdownTopGlow:SetHeight(SEARCH_DROPDOWN_GLOW_HEIGHT)
    runtime.searchDropdownTopGlow = searchDropdownTopGlow

    local searchDropdownBottomGlow = createSearchDropdownCenteredBand(searchDropdownOverlay, SEARCH_OVERFLOW_GLOW_COLOR)
    searchDropdownBottomGlow:SetPoint("BOTTOMLEFT", searchDropdownOverlay, "BOTTOMLEFT", 0, 0)
    searchDropdownBottomGlow:SetPoint("BOTTOMRIGHT", searchDropdownOverlay, "BOTTOMRIGHT", 0, 0)
    searchDropdownBottomGlow:SetHeight(SEARCH_DROPDOWN_GLOW_HEIGHT)
    runtime.searchDropdownBottomGlow = searchDropdownBottomGlow

    searchDropdownScrollFrame:SetScript("OnMouseWheel", function(selfScroll, delta)
        handleSearchDropdownMouseWheel(runtime, delta)
    end)
    searchDropdownScrollFrame:SetScript("OnVerticalScroll", function()
        updateSearchDropdownOverflowIndicators(runtime, false)
    end)
    searchDropdownScrollFrame:SetScript("OnSizeChanged", function()
        local contentWidth = getSearchDropdownContentWidth(runtime)
        if searchDropdownContent and searchDropdownContent.SetWidth then
            searchDropdownContent:SetWidth(contentWidth)
        end
        updateSearchDropdownOverflowIndicators(runtime, true)
    end)
    searchDropdownContent:SetScript("OnMouseWheel", function(_, delta)
        handleSearchDropdownMouseWheel(runtime, delta)
    end)
    searchDropdown:SetScript("OnMouseWheel", function(_, delta)
        handleSearchDropdownMouseWheel(runtime, delta)
    end)

    searchEdit:SetScript("OnTextChanged", function(selfEdit, userInput)
        updateSearchPlaceholder(runtime)
        if runtime.searchSuppressTextChanged then
            return
        end
        if userInput then
            runSearchFilter(PortalAuthority, runtime, selfEdit:GetText())
        end
    end)
    searchEdit:SetScript("OnEditFocusGained", function()
        updateSearchBorder(runtime, true)
        updateSearchPlaceholder(runtime)
    end)
    searchEdit:SetScript("OnEditFocusLost", function()
        updateSearchBorder(runtime, false)
        updateSearchPlaceholder(runtime)
        if isPointerOverOpenSearchDropdown(runtime) then
            if isSearchResultClickActive(runtime) then
                logSearchClickStep("focus-lost-during-click", runtime.searchResultClickToken or 0)
            end
            return
        end
        if isSearchResultClickActive(runtime) then
            logSearchClickStep("focus-lost-during-click", runtime.searchResultClickToken or 0)
            return
        end
        hideSearchDropdown(runtime)
    end)
    searchEdit:SetScript("OnEnterPressed", function(selfEdit)
        selfEdit:ClearFocus()
    end)
    searchEdit:SetScript("OnEscapePressed", function(selfEdit)
        clearSearchState(PortalAuthority, {
            clearText = true,
            clearFocus = true,
            hideDropdown = true,
            clearHighlight = true,
        })
        updateSearchBorder(runtime, false)
    end)

    local navContainer = CreateFrame("Frame", nil, sidebar)
    navContainer:SetPoint("TOPLEFT", separator, "BOTTOMLEFT", -18, -12)
    navContainer:SetPoint("BOTTOMRIGHT", searchArea, "TOPRIGHT", -18, 0)
    runtime.navContainer = navContainer

    local navOrder = type(self.settingsWindowNavOrder) == "table" and self.settingsWindowNavOrder or {}
    local previous = nil
    for i = 1, #navOrder do
        local key = navOrder[i]
        local meta = getSectionMeta(self)[key]
        if meta and meta.showInNav then
            local button = createNavButton(self, navContainer, key, meta.navLabel or meta.title or key)
            if previous then
                button:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -NAV_ROW_SPACING)
            else
                button:SetPoint("TOPLEFT", navContainer, "TOPLEFT", 0, 0)
            end
            previous = button

            if key == "interrupt" then
                local teaserRow = createSidebarTeaserRow(navContainer, "Group Cooldowns", "SOON")
                teaserRow:SetPoint("TOPLEFT", previous, "BOTTOMLEFT", 0, -NAV_ROW_SPACING)
                previous = teaserRow
            end
        end
    end

    local indicator = CreateFrame("Frame", nil, sidebar)
    indicator:SetSize(12, NAV_ROW_HEIGHT)
    indicator:SetFrameStrata("DIALOG")
    indicator:SetFrameLevel(frame:GetFrameLevel() + 8)
    indicator:Hide()
    local indicatorGlow = indicator:CreateTexture(nil, "BACKGROUND")
    indicatorGlow:SetPoint("TOPLEFT", indicator, "TOPLEFT", 0, 0)
    indicatorGlow:SetPoint("BOTTOMLEFT", indicator, "BOTTOMLEFT", 0, 0)
    indicatorGlow:SetWidth(12)
    indicatorGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
    indicatorGlow:SetBlendMode("ADD")
    setHorizontalGradient(indicatorGlow, SHELL_STYLE.indicatorGlow, { 155 / 255, 48 / 255, 255 / 255, 0.0 })
    local indicatorBar = indicator:CreateTexture(nil, "ARTWORK")
    indicatorBar:SetPoint("TOPLEFT", indicator, "TOPLEFT", 0, 0)
    indicatorBar:SetPoint("BOTTOMLEFT", indicator, "BOTTOMLEFT", 0, 0)
    indicatorBar:SetWidth(2)
    indicatorBar:SetColorTexture(unpackColor(SHELL_STYLE.indicatorBar))
    runtime.indicator = indicator

    local header = CreateFrame("Frame", nil, content, "BackdropTemplate")
    header:SetPoint("TOPLEFT", content, "TOPLEFT", 0, 0)
    header:SetPoint("TOPRIGHT", content, "TOPRIGHT", 0, 0)
    header:SetHeight(HEADER_HEIGHT)
    header:SetBackdrop(PANEL_BACKDROP)
    header:SetBackdropColor(unpackColor(SHELL_STYLE.headerBg))
    header:SetBackdropBorderColor(0, 0, 0, 0)
    header:EnableMouse(true)
    header:RegisterForDrag("LeftButton")
    header:SetScript("OnDragStart", function()
        frame:StartMoving()
    end)
    header:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        captureWindowPosition(PortalAuthority)
    end)
    runtime.header = header

    local headerDivider = header:CreateTexture(nil, "BORDER")
    headerDivider:SetPoint("BOTTOMLEFT", header, "BOTTOMLEFT", 0, 0)
    headerDivider:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", 0, 0)
    headerDivider:SetHeight(1)
    headerDivider:SetColorTexture(unpackColor(SHELL_STYLE.headerDivider))

    local headerTitle = header:CreateFontString(nil, "ARTWORK")
    headerTitle:SetPoint("TOPLEFT", header, "TOPLEFT", 28, -HEADER_TITLE_TOP_INSET)
    headerTitle:SetJustifyH("LEFT")
    applyPremiumFont(headerTitle, 18, "", GameFontNormalLarge)
    headerTitle:SetTextColor(unpackColor(SHELL_STYLE.headerTitle))
    runtime.headerTitle = headerTitle

    local headerDescriptor = header:CreateFontString(nil, "ARTWORK")
    headerDescriptor:SetPoint("TOPLEFT", headerTitle, "BOTTOMLEFT", 0, -3)
    headerDescriptor:SetJustifyH("LEFT")
    applyPremiumFont(headerDescriptor, 11, "", GameFontDisableSmall)
    headerDescriptor:SetTextColor(unpackColor(SHELL_STYLE.headerDescriptor))
    runtime.headerDescriptor = headerDescriptor

    local headerRight = CreateFrame("Frame", nil, header)
    headerRight:SetPoint("TOPRIGHT", header, "TOPRIGHT", -28, -14)
    headerRight:SetPoint("BOTTOMRIGHT", header, "BOTTOMRIGHT", -28, 14)
    headerRight:SetWidth(220)
    headerRight._paSettingsWindowVisualStyleOptIn = true
    runtime.headerRight = headerRight

    do
        local headerAccessory = createHeaderStatusBadgeAccessory(headerRight)
        if headerAccessory and headerAccessory.control then
            headerAccessory.control:ClearAllPoints()
            headerAccessory.control:SetPoint("RIGHT", headerRight, "RIGHT", 0, 0)
            if headerAccessory.SetEnabled then
                headerAccessory:SetEnabled(false)
            end
            if headerAccessory.Hide then
                headerAccessory:Hide()
            else
                headerAccessory.control:Hide()
            end
        end
        runtime.headerAccessory = headerAccessory
    end

    local body = CreateFrame("Frame", nil, content)
    body:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    body:SetPoint("BOTTOMRIGHT", content, "BOTTOMRIGHT", 0, 0)
    runtime.body = body
    runtime.shellOwnedFrames = {
        [frame] = true,
        [sidebar] = true,
        [content] = true,
        [header] = true,
        [headerRight] = true,
        [body] = true,
        [navContainer] = true,
        [searchArea] = true,
        [searchBox] = true,
        [searchDropdown] = true,
        [searchDropdownScrollFrame] = true,
        [searchDropdownContent] = true,
        [parkingFrame] = true,
    }
    if runtime.headerAccessory and runtime.headerAccessory.control then
        runtime.shellOwnedFrames[runtime.headerAccessory.control] = true
    end

    frame:SetScript("OnShow", function()
        if PortalAuthority and PortalAuthority.CpuDiagRecordTrigger then
            PortalAuthority:CpuDiagRecordTrigger("settings_open")
        end
    end)
    frame:SetScript("OnHide", function()
        detachCurrentHostedPanel(PortalAuthority)
        runtime.fadeToken = (tonumber(runtime.fadeToken) or 0) + 1
        runtime.glideToken = (tonumber(runtime.glideToken) or 0) + 1
        runtime.hintToken = (tonumber(runtime.hintToken) or 0) + 1
        runtime.headerAccessoryRefreshPending = false
        runtime.headerAccessoryRefreshActive = false
        stopFrameAnimation(frame)
        stopFrameAnimation(indicator)
        stopFrameAnimation(homeHint)
        frame:SetAlpha(1)
        if homeHint then
            homeHint:SetAlpha(0)
        end
        if searchEdit and searchEdit.ClearFocus then
            searchEdit:ClearFocus()
        end
        clearSearchState(PortalAuthority, {
            clearText = true,
            clearFocus = false,
            hideDropdown = true,
            clearHighlight = true,
        })
        clearSearchResultClickTransaction(runtime)
        stopSearchIntroGlow(runtime)
        hideHeaderAccessory(runtime)
        updateSearchBorder(runtime, false)
        updateSearchPlaceholder(runtime)
        if PortalAuthority and PortalAuthority.CpuDiagRecordTrigger then
            PortalAuthority:CpuDiagRecordTrigger("settings_closed")
        end
    end)

    applyWindowPosition(self)
    updateHeader(self)
    updateNavState(self, true)
    hideHeaderAccessory(runtime)
    return frame
end

function PortalAuthority:NormalizeSettingsWindowSectionKey(sectionKey)
    if type(sectionKey) ~= "string" then
        return nil
    end

    sectionKey = trim(sectionKey):lower()
    if sectionKey == "" then
        return nil
    end
    if sectionKey == "home" then
        sectionKey = "root"
    end

    local meta = getSectionMeta(self)
    if type(meta[sectionKey]) == "table" then
        return sectionKey
    end
    return nil
end

function PortalAuthority:EnsureSettingsWindow()
    return createWindow(self)
end

function PortalAuthority:RefreshSettingsWindowHeaderAccessory()
    local runtime = self._settingsWindowRuntime
    if type(runtime) ~= "table" or not runtime.window or not runtime.headerAccessory then
        return false
    end
    return refreshHeaderAccessory(self)
end

function PortalAuthority:IsSettingsWindowOpen()
    local frame = self.GetExistingSettingsWindowFrame and self:GetExistingSettingsWindowFrame() or nil
    return frame and frame.IsShown and frame:IsShown() and true or false
end

function PortalAuthority:OpenSettingsWindow(sectionKey, opts)
    local runtime = ensureRuntime(self)
    opts = type(opts) == "table" and opts or {}
    local deferBlizzardCloseUntilSuccess = opts.deferBlizzardCloseUntilSuccess == true
    local existingFrame = self.GetExistingSettingsWindowFrame and self:GetExistingSettingsWindowFrame() or nil
    local wasVisible = existingFrame and existingFrame.IsShown and existingFrame:IsShown() and true or false

    if sectionKey ~= nil then
        sectionKey = self:NormalizeSettingsWindowSectionKey(sectionKey)
        if not sectionKey then
            setLastError(self, "Settings window target is unavailable.")
            return false
        end
    end

    if not (self.IsSettingsWindowHostEnabled and self:IsSettingsWindowHostEnabled()) then
        setLastError(self, "Settings window is unavailable in this build.")
        return false
    end

    if self.EnsureSettingsHostCoexistenceHooks then
        self:EnsureSettingsHostCoexistenceHooks()
    end

    if not wasVisible then
        local inCombat = (InCombatLockdown and InCombatLockdown()) or false
        if inCombat or (self.IsPlayerInCombat and self:IsPlayerInCombat()) then
            setLastError(self, "Settings are unavailable during combat.")
            return false
        end
    end

    local frame = self:EnsureSettingsWindow()
    wasVisible = frame:IsShown()
    local targetSectionKey = sectionKey

    if not targetSectionKey then
        if wasVisible and type(runtime.currentSectionKey) == "string" then
            targetSectionKey = runtime.currentSectionKey
        else
            targetSectionKey = getDefaultSectionKey(self)
        end
    end

    targetSectionKey = self:NormalizeSettingsWindowSectionKey(targetSectionKey)
    if not targetSectionKey then
        setLastError(self, "Settings window target is unavailable.")
        return false
    end

    if not deferBlizzardCloseUntilSuccess then
        closeBlizzardSettings()
    end
    applyWindowPosition(self)

    frame:SetFrameStrata("DIALOG")
    frame:Raise()
    if not wasVisible then
        frame:SetAlpha(0)
        frame:Show()
    end

    if not selectSection(self, targetSectionKey, not wasVisible) then
        if not wasVisible and frame.Hide then
            frame:Hide()
        end
        return false
    end

    if deferBlizzardCloseUntilSuccess then
        closeBlizzardSettings()
    end

    clearLastError(self)

    if not wasVisible then
        startAlphaTween(frame, runtime, "fadeToken", 0, 1, OPEN_FADE_DURATION, function()
            scheduleSearchIntroGlowAfterOpen(self)
        end)
    else
        frame:SetAlpha(1)
    end

    return true
end

function PortalAuthority:OpenSettingsWindowToSection(sectionKey)
    sectionKey = self:NormalizeSettingsWindowSectionKey(sectionKey)
    if not sectionKey then
        setLastError(self, "Settings window target is unavailable.")
        return false
    end
    return self:OpenSettingsWindow(sectionKey, { targeted = true })
end

function PortalAuthority:OpenSettingsWindowFromBlizzardStub(sectionKey)
    sectionKey = self:NormalizeSettingsWindowSectionKey(sectionKey)
    if not sectionKey then
        setLastError(self, "Settings window target is unavailable.")
        return false, "Settings window target is unavailable."
    end

    local ok = self:OpenSettingsWindow(sectionKey, {
        targeted = true,
        source = "blizzard-stub",
        deferBlizzardCloseUntilSuccess = true,
    })
    if ok then
        return true
    end

    local runtime = self._settingsWindowRuntime
    return false, tostring((runtime and runtime.lastError) or "Settings host is unavailable.")
end

function PortalAuthority:ToggleSettingsWindow()
    if self:IsSettingsWindowOpen() then
        self:CloseSettingsWindow()
        return false
    end
    return self:OpenSettingsWindow(nil, { source = "toggle" })
end

function PortalAuthority:CloseSettingsWindow()
    local frame = self.GetExistingSettingsWindowFrame and self:GetExistingSettingsWindowFrame() or nil
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end
    frame:Hide()
    clearLastError(self)
    return true
end
