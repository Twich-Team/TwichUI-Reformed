---@diagnostic disable: undefined-field, inject-field, duplicate-set-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class MinimapModule : AceModule, AceEvent-3.0, AceHook-3.0
local MinimapModule = T:NewModule("Minimap", "AceEvent-3.0", "AceHook-3.0")

local UIParent = _G.UIParent
local CreateFrame = _G.CreateFrame
local Minimap = _G.Minimap
local MinimapCluster = _G.MinimapCluster
local InCombatLockdown = _G.InCombatLockdown
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local C_Map = _G.C_Map
local C_Timer = _G.C_Timer
local GetTime = _G.GetTime
local GetZoneText = _G.GetZoneText
local GetSubZoneText = _G.GetSubZoneText
local GetRealZoneText = _G.GetRealZoneText
local GetGameTime = _G.GetGameTime
local GetInstanceInfo = _G.GetInstanceInfo
local HasNewMail = _G.HasNewMail
local date = _G.date
local floor = math.floor
local max = math.max
local min = math.min
local sqrt = math.sqrt
local type = type
local tostring = tostring
local table_concat = table.concat
local table_insert = table.insert
local pairs = pairs
local ipairs = ipairs
local next = next
local select = select
local unpackValues = table.unpack or _G.unpack
local format = string.format

local MINIMAP_BASE_SIZE = 256
local ROUND_MASK = 186178
local SQUARE_MASK = "Interface\\ChatFrame\\ChatFrameBackground"
local BUTTON_GAP = 6
local BUTTON_BAR_PADDING = 6
local CURSOR_CHECK_INTERVAL = 0.05
local COORDS_INTERVAL = 0.15
local CLOCK_INTERVAL = 1
local RESCAN_INTERVAL = 4
local DEFAULT_SIZE = 228
local DEBUG_SOURCE_KEY = "minimap"

local HIDDEN_FRAME_NAMES = {
    "MinimapBorderTop",
    "MinimapBorder",
    "MinimapCompassTexture",
    "MinimapNorthTag",
    "MinimapZoneText",
    "MinimapZoneTextButton",
    "TimeManagerClockButton",
    "MiniMapTracking",
    "MinimapTrackingFrame",
    "MiniMapTrackingButton",
    "MiniMapTrackingIcon",
    "MiniMapTrackingIconOverlay",
    "MiniMapTrackingButtonBorder",
    "MiniMapTrackingBorder",
    "MiniMapTrackingBackground",
    "MiniMapWorldMapButton",
    "MinimapBackdrop",
    "GameTimeFrame",
    "AddonCompartmentFrameButton",
    "MinimapZoomIn",
    "MinimapZoomOut",
    "AddonCompartmentFrame",
}

local HIDDEN_CHILD_PATTERNS = {
    "^AddonCompartment",
    "^BorderTop$",
    "^GameTime",
    "^TimeManagerClock",
    "^MinimapZoneText",
    "^MiniMapInstanceDifficulty",
    "^GuildInstanceDifficulty",
    "^MiniMapChallengeMode",
    "^MiniMapMail",
    "^MiniMapTracking",
    "^QueueStatus",
    "^MiniMapBattlefield",
}

local BUTTON_TEXTURE_HIDE_PATTERNS = {
    "Border",
    "Background",
    "Mask",
    "Overlay",
    "Ring",
    "Gloss",
    "Circle",
}

local EXCLUDED_BUTTON_PATTERNS = {
    "^TwichUI",
    "^Minimap",
    "^MiniMap",
    "^QueueStatus",
    "^GameTime",
    "^TimeManager",
    "^AddonCompartment",
    "^PlumberLandingPage",
    "^ExpansionLandingPage",
    "^GarrisonLandingPage",
    "^CraftingOrder",
    "^BattlefieldMinimap",
    "^Calendar",
}

local proxy = CreateFrame("Frame")

local function Round(value)
    return floor((tonumber(value) or 0) + 0.5)
end

local function Clamp(value, minimum, maximum)
    local numeric = tonumber(value) or minimum
    if numeric < minimum then
        return minimum
    end
    if numeric > maximum then
        return maximum
    end
    return numeric
end

local function SafeCall(func, ...)
    if type(func) ~= "function" then
        return nil
    end

    local results = { pcall(func, ...) }
    if results[1] ~= true then
        return nil
    end

    return select(2, unpackValues(results))
end

local function HasScriptHandler(frame, scriptName)
    if not frame or type(scriptName) ~= "string" or scriptName == "" then
        return false
    end

    local hasScript = SafeCall(frame.HasScript, frame, scriptName)
    if hasScript == false then
        return false
    end

    return SafeCall(frame.GetScript, frame, scriptName) ~= nil
end

local function SafeDebugString(value)
    if value == nil then
        return "nil"
    end

    return tostring(value)
end

local function DescribeFrame(frame)
    if not frame then
        return "nil"
    end

    local name = SafeCall(frame.GetName, frame)
    local objectType = SafeCall(frame.GetObjectType, frame)
    local parent = SafeCall(frame.GetParent, frame)
    local parentName = parent and SafeCall(parent.GetName, parent) or nil
    local shown = SafeCall(frame.IsShown, frame)
    local alpha = SafeCall(frame.GetAlpha, frame)
    local width = SafeCall(frame.GetWidth, frame)
    local height = SafeCall(frame.GetHeight, frame)
    local strata = SafeCall(frame.GetFrameStrata, frame)
    local level = SafeCall(frame.GetFrameLevel, frame)

    return format(
        "%s<%s> shown=%s alpha=%s size=%.1fx%.1f strata=%s level=%s parent=%s",
        SafeDebugString(name),
        SafeDebugString(objectType),
        SafeDebugString(shown),
        SafeDebugString(alpha),
        tonumber(width) or 0,
        tonumber(height) or 0,
        SafeDebugString(strata),
        SafeDebugString(level),
        SafeDebugString(parentName))
end

local function DescribePoint(frame)
    if not frame or type(frame.GetPoint) ~= "function" then
        return "nil"
    end

    local point, relativeTo, relativePoint, xOffset, yOffset = SafeCall(frame.GetPoint, frame, 1)
    local relativeName = relativeTo and SafeCall(relativeTo.GetName, relativeTo) or nil
    if not point then
        return "nil"
    end

    return format(
        "%s -> %s:%s (%s,%s)",
        SafeDebugString(point),
        SafeDebugString(relativeName),
        SafeDebugString(relativePoint),
        SafeDebugString(xOffset),
        SafeDebugString(yOffset))
end

local function GetConfigurationModule()
    return T:GetModule("Configuration", true)
end

local function GetOptions()
    local configurationModule = GetConfigurationModule()
    return configurationModule and configurationModule.Options and configurationModule.Options.Minimap or nil
end

local function GetThemeModule()
    return T:GetModule("Theme", true)
end

local function GetDebugConsole()
    return T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil
end

local function GetThemeColor(key, fallback)
    local theme = GetThemeModule()
    if not theme or type(theme.GetColor) ~= "function" then
        return fallback[1], fallback[2], fallback[3]
    end

    local color = theme:GetColor(key)
    if type(color) ~= "table" then
        return fallback[1], fallback[2], fallback[3]
    end

    return color[1] or fallback[1], color[2] or fallback[2], color[3] or fallback[3]
end

local function ResolveFontPath(fontKey)
    local LSM = T.Libs and T.Libs.LSM
    local theme = GetThemeModule()
    if type(fontKey) ~= "string" or fontKey == "" or fontKey == "__default" then
        fontKey = theme and theme.Get and theme:Get("globalFont") or nil
    end

    if LSM and type(fontKey) == "string" and fontKey ~= "" then
        local fetched = SafeCall(LSM.Fetch, LSM, "font", fontKey)
        if type(fetched) == "string" and fetched ~= "" then
            return fetched
        end
    end

    return STANDARD_TEXT_FONT
end

local function IsCursorOverFrame(frame)
    if not frame or not frame.IsShown or not frame:IsShown() then
        return false
    end

    local left = frame.GetLeft and frame:GetLeft() or nil
    local right = frame.GetRight and frame:GetRight() or nil
    local top = frame.GetTop and frame:GetTop() or nil
    local bottom = frame.GetBottom and frame:GetBottom() or nil
    if not (left and right and top and bottom) then
        return false
    end

    local cursorX, cursorY = _G.GetCursorPosition()
    local scale = frame.GetEffectiveScale and frame:GetEffectiveScale() or 1
    cursorX = cursorX / scale
    cursorY = cursorY / scale
    return cursorX >= left and cursorX <= right and cursorY >= bottom and cursorY <= top
end

local function Lerp(current, target, amount)
    return current + (target - current) * amount
end

local function FormatCoordinateValue(value, precision)
    if type(value) ~= "number" then
        precision = Clamp(precision or 1, 0, 2)
        if precision == 0 then
            return "--"
        end
        return precision == 2 and "--.--" or "--.-"
    end

    precision = Clamp(precision or 1, 0, 2)
    local numeric = Clamp(value, 0, 100)
    if precision == 0 then
        return format("%02d", floor(numeric + 0.5))
    end
    return format("%0" .. tostring(precision + 3) .. "." .. tostring(precision) .. "f", numeric)
end

local function FormatClock(hour, minute, use24Hour)
    if type(hour) ~= "number" or type(minute) ~= "number" then
        return "--:--"
    end

    if use24Hour then
        return format("%02d:%02d", hour, minute)
    end

    local displayHour = hour % 12
    if displayHour == 0 then
        displayHour = 12
    end

    return format("%d:%02d %s", displayHour, minute, hour >= 12 and "PM" or "AM")
end

local function BuildPointSnapshot(frame)
    local points = {}
    if not frame or type(frame.GetNumPoints) ~= "function" then
        return points
    end

    for index = 1, frame:GetNumPoints() do
        local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(index)
        points[#points + 1] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            xOffset = xOffset,
            yOffset = yOffset,
        }
    end

    return points
end

local function IsTopPosition(position)
    return position == "top" or position == "top-left" or position == "top-right"
end

local function GetInsetAnchorPoint(position)
    if position == "top-right" then
        return "TOPRIGHT", -8, -8
    end
    if position == "bottom-left" then
        return "BOTTOMLEFT", 8, 8
    end
    if position == "bottom-right" then
        return "BOTTOMRIGHT", -8, 8
    end
    return "TOPLEFT", 8, -8
end

local function GetEdgeAnchorPoint(position)
    if position == "top" then
        return "TOP", 0, -8
    end
    if position == "left" then
        return "LEFT", 8, 0
    end
    if position == "right" then
        return "RIGHT", -8, 0
    end
    return "BOTTOM", 0, 8
end

local function GetFontConfig(options, part)
    if not options then
        return STANDARD_TEXT_FONT, 12, 1, 1, 1
    end

    local fontGetter = options["Get" .. part .. "Font"]
    local sizeGetter = options["Get" .. part .. "FontSize"]
    local colorGetter = options["Get" .. part .. "Color"]
    local fontPath = ResolveFontPath(type(fontGetter) == "function" and fontGetter(options) or "__default")
    local fontSize = type(sizeGetter) == "function" and sizeGetter(options) or 12
    local red, green, blue = 1, 1, 1
    if type(colorGetter) == "function" then
        red, green, blue = colorGetter(options)
    end

    return fontPath, fontSize, red, green, blue
end

local function ExtractPlayerMapPosition(mapID)
    if not mapID or not C_Map or type(C_Map.GetPlayerMapPosition) ~= "function" then
        return nil, nil
    end

    local position = C_Map.GetPlayerMapPosition(mapID, "player")
    if position and type(position.GetXY) == "function" then
        return position:GetXY()
    end
    if type(position) == "table" then
        return position.x, position.y
    end
    return nil, nil
end

local function ResolvePlayerMapPosition()
    if not C_Map or type(C_Map.GetBestMapForUnit) ~= "function" then
        return nil, nil
    end

    local mapID = C_Map.GetBestMapForUnit("player")
    local xValue, yValue = ExtractPlayerMapPosition(mapID)
    if type(xValue) == "number" and type(yValue) == "number" then
        return xValue, yValue
    end

    if type(C_Map.GetMapInfo) ~= "function" then
        return nil, nil
    end

    local guard = 0
    local mapInfo = mapID and C_Map.GetMapInfo(mapID) or nil
    while mapInfo and mapInfo.parentMapID and guard < 8 do
        mapID = mapInfo.parentMapID
        xValue, yValue = ExtractPlayerMapPosition(mapID)
        if type(xValue) == "number" and type(yValue) == "number" then
            return xValue, yValue
        end
        mapInfo = C_Map.GetMapInfo(mapID)
        guard = guard + 1
    end

    return nil, nil
end

local function FindManagedButtonIcon(frame)
    if not frame then
        return nil
    end

    local directIcon = frame.icon or frame.Icon or (frame.dataObject and frame.dataObject.icon) or nil
    if directIcon and type(directIcon) == "table" and type(directIcon.GetObjectType) == "function" and directIcon:GetObjectType() == "Texture" then
        return directIcon
    end

    local normalTexture = frame.GetNormalTexture and frame:GetNormalTexture() or nil
    if normalTexture then
        return normalTexture
    end

    local largestTexture = nil
    local largestArea = 0
    local regions = frame.GetRegions and { frame:GetRegions() } or {}
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            local width = region.GetWidth and region:GetWidth() or 0
            local height = region.GetHeight and region:GetHeight() or 0
            local area = width * height
            if area > largestArea then
                largestArea = area
                largestTexture = region
            end
        end
    end

    return largestTexture
end

local function CaptureTextureStates(frame)
    local states = {}
    if not frame or type(frame.GetRegions) ~= "function" then
        return states
    end

    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            states[#states + 1] = {
                region = region,
                shown = region:IsShown(),
                alpha = region:GetAlpha(),
                texture = region.GetTexture and region:GetTexture() or nil,
                texCoord = { SafeCall(region.GetTexCoord, region) },
            }
        end
    end

    return states
end

local function SuppressFrame(frame)
    if not frame then
        return
    end

    if frame.__TwichUIOriginalShow == nil then
        frame.__TwichUIOriginalShow = frame.Show
    end

    if frame.EnableMouse then
        frame:EnableMouse(false)
    end
    frame:Hide()
    frame:SetAlpha(0)
    frame.Show = function() end
end

local function RestoreSuppressedFrame(frame)
    if not frame then
        return
    end

    if frame.__TwichUIOriginalShow then
        frame.Show = frame.__TwichUIOriginalShow
        frame.__TwichUIOriginalShow = nil
    end
    frame:SetAlpha(1)
    frame:Show()
end

local function SuppressFrameRegions(frame)
    if not frame or not frame.GetRegions then
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region then
            region:Hide()
            region:SetAlpha(0)
        end
    end
end

local function RestoreFrameRegions(frame)
    if not frame or not frame.GetRegions then
        return
    end

    for _, region in ipairs({ frame:GetRegions() }) do
        if region then
            region:SetAlpha(1)
            region:Show()
        end
    end
end

local function SuppressFrameTree(frame)
    if not frame then
        return
    end

    if frame.GetObjectType and frame:GetObjectType() ~= "Texture" and frame:GetObjectType() ~= "FontString" then
        SuppressFrame(frame)
    else
        frame:Hide()
        frame:SetAlpha(0)
    end

    SuppressFrameRegions(frame)

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            SuppressFrameTree(child)
        end
    end
end

local function RestoreFrameTree(frame)
    if not frame then
        return
    end

    if frame.__TwichUIOriginalShow then
        RestoreSuppressedFrame(frame)
    elseif frame.SetAlpha and frame.Show then
        frame:SetAlpha(1)
        frame:Show()
    end

    RestoreFrameRegions(frame)

    if frame.GetChildren then
        for _, child in ipairs({ frame:GetChildren() }) do
            RestoreFrameTree(child)
        end
    end
end

local function GetAdditionalHiddenFrames()
    local frames = {}

    if MinimapCluster then
        if MinimapCluster.BorderTop then
            frames[#frames + 1] = MinimapCluster.BorderTop
        end
        if MinimapCluster.Tracking then
            frames[#frames + 1] = MinimapCluster.Tracking
            if MinimapCluster.Tracking.Background then
                frames[#frames + 1] = MinimapCluster.Tracking.Background
            end
            if MinimapCluster.Tracking.Button then
                frames[#frames + 1] = MinimapCluster.Tracking.Button
            end
        end
        if MinimapCluster.TrackingFrame then
            frames[#frames + 1] = MinimapCluster.TrackingFrame
        end
        if MinimapCluster.ZoneTextButton then
            frames[#frames + 1] = MinimapCluster.ZoneTextButton
        end
        if MinimapCluster.InstanceDifficulty then
            frames[#frames + 1] = MinimapCluster.InstanceDifficulty
        end
        if MinimapCluster.MailFrame then
            frames[#frames + 1] = MinimapCluster.MailFrame
        end
        if MinimapCluster.CraftingOrderIcon then
            frames[#frames + 1] = MinimapCluster.CraftingOrderIcon
        end
        if MinimapCluster.GuildInstanceDifficulty then
            frames[#frames + 1] = MinimapCluster.GuildInstanceDifficulty
        end
        if MinimapCluster.DungeonDifficulty then
            frames[#frames + 1] = MinimapCluster.DungeonDifficulty
        end
        if MinimapCluster.ZoomIn then
            frames[#frames + 1] = MinimapCluster.ZoomIn
        end
        if MinimapCluster.ZoomOut then
            frames[#frames + 1] = MinimapCluster.ZoomOut
        end
    end

    return frames
end

function MinimapModule:GetDefaultAnchorPosition()
    local parentWidth = UIParent and UIParent:GetWidth() or 1920
    local parentHeight = UIParent and UIParent:GetHeight() or 1080
    local size = DEFAULT_SIZE + 24
    return Round(parentWidth - size - 24), Round(parentHeight - size - 84)
end

function MinimapModule:RequestApply(reason)
    if not self:IsEnabled() then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        self.pendingApplyReason = reason or "combat-deferred"
        return
    end

    self.pendingApplyReason = nil
    self:ApplySettings(reason or "runtime")
end

function MinimapModule:SaveBaseState()
    if self.baseState or not Minimap or not MinimapCluster then
        return
    end

    local clusterPoint, clusterRelativeTo, clusterRelativePoint, clusterX, clusterY = MinimapCluster:GetPoint()
    local minimapPoint, minimapRelativeTo, minimapRelativePoint, minimapX, minimapY = Minimap:GetPoint()
    self.baseState = {
        clusterParent = MinimapCluster:GetParent(),
        clusterPoint = clusterPoint,
        clusterRelativeTo = clusterRelativeTo,
        clusterRelativePoint = clusterRelativePoint,
        clusterX = clusterX,
        clusterY = clusterY,
        clusterScale = MinimapCluster:GetScale(),
        minimapParent = Minimap:GetParent(),
        minimapPoint = minimapPoint,
        minimapRelativeTo = minimapRelativeTo,
        minimapRelativePoint = minimapRelativePoint,
        minimapX = minimapX,
        minimapY = minimapY,
        minimapScale = Minimap:GetScale(),
        minimapWidth = Minimap:GetWidth(),
        minimapHeight = Minimap:GetHeight(),
        minimapMask = Minimap.GetMaskTexture and Minimap:GetMaskTexture() or nil,
        getMinimapShape = _G.GetMinimapShape,
    }
end

function MinimapModule:RestoreBaseState()
    if not self.baseState or not Minimap or not MinimapCluster then
        return
    end

    local state = self.baseState
    proxy.SetParent(MinimapCluster, state.clusterParent or UIParent)
    proxy.ClearAllPoints(MinimapCluster)
    if state.clusterPoint then
        proxy.SetPoint(MinimapCluster,
            state.clusterPoint,
            state.clusterRelativeTo or UIParent,
            state.clusterRelativePoint or state.clusterPoint,
            state.clusterX or 0,
            state.clusterY or 0)
    end
    proxy.SetScale(MinimapCluster, state.clusterScale or 1)

    proxy.SetParent(Minimap, state.minimapParent or MinimapCluster)
    proxy.ClearAllPoints(Minimap)
    if state.minimapPoint then
        proxy.SetPoint(Minimap,
            state.minimapPoint,
            state.minimapRelativeTo or MinimapCluster,
            state.minimapRelativePoint or state.minimapPoint,
            state.minimapX or 0,
            state.minimapY or 0)
    end
    Minimap:SetSize(state.minimapWidth or 140, state.minimapHeight or 140)
    proxy.SetScale(Minimap, state.minimapScale or 1)
    if Minimap.SetMaskTexture then
        Minimap:SetMaskTexture(state.minimapMask or SQUARE_MASK)
    end

    _G.GetMinimapShape = state.getMinimapShape
end

function MinimapModule:HideDefaultChrome()
    for _, frameName in ipairs(HIDDEN_FRAME_NAMES) do
        local frame = _G[frameName]
        if frame then
            SuppressFrame(frame)
        end
    end

    for _, frame in ipairs(GetAdditionalHiddenFrames()) do
        SuppressFrameTree(frame)
    end

    if MinimapCluster then
        local children = { MinimapCluster:GetChildren() }
        for _, child in ipairs(children) do
            if child ~= Minimap and child ~= self.holder and child ~= self.shell and child ~= self.buttonBar then
                local name = child.GetName and child:GetName() or nil
                if type(name) == "string" then
                    for _, pattern in ipairs(HIDDEN_CHILD_PATTERNS) do
                        if name:find(pattern) then
                            SuppressFrameTree(child)
                            break
                        end
                    end
                end
            end
        end
    end

    if _G.AddonCompartmentFrame and _G.AddonCompartmentFrame.GetChildren then
        local children = { _G.AddonCompartmentFrame:GetChildren() }
        for _, child in ipairs(children) do
            SuppressFrame(child)
        end
    end

    if Minimap and Minimap.GetRegions then
        local regions = { Minimap:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                region:Hide()
                region:SetAlpha(0)
            end
        end
    end

    if MinimapCluster and MinimapCluster.GetRegions then
        local regions = { MinimapCluster:GetRegions() }
        for _, region in ipairs(regions) do
            if region then
                region:Hide()
                region:SetAlpha(0)
            end
        end
    end
end

function MinimapModule:RestoreDefaultChrome()
    for _, frameName in ipairs(HIDDEN_FRAME_NAMES) do
        local frame = _G[frameName]
        if frame then
            RestoreSuppressedFrame(frame)
        end
    end

    for _, frame in ipairs(GetAdditionalHiddenFrames()) do
        if frame then
            RestoreFrameTree(frame)
        end
    end

    if MinimapCluster then
        local children = { MinimapCluster:GetChildren() }
        for _, child in ipairs(children) do
            if child then
                RestoreFrameTree(child)
            end
        end
    end

    if _G.AddonCompartmentFrame and _G.AddonCompartmentFrame.GetChildren then
        local children = { _G.AddonCompartmentFrame:GetChildren() }
        for _, child in ipairs(children) do
            if child and child.__TwichUIOriginalShow then
                RestoreSuppressedFrame(child)
            end
        end
    end

    if Minimap and Minimap.GetRegions then
        local regions = { Minimap:GetRegions() }
        for _, region in ipairs(regions) do
            if region and region.GetObjectType and region:GetObjectType() == "FontString" then
                region:SetAlpha(1)
                region:Show()
            end
        end
    end

    if MinimapCluster and MinimapCluster.GetRegions then
        local regions = { MinimapCluster:GetRegions() }
        for _, region in ipairs(regions) do
            if region then
                region:SetAlpha(1)
                region:Show()
            end
        end
    end
end

function MinimapModule:EnsureShell()
    if self.holder then
        return self.holder
    end

    local holder = CreateFrame("Frame", "TwichUIMinimapHolder", UIParent, "BackdropTemplate")
    holder:SetClampedToScreen(true)
    holder:SetFrameStrata("LOW")
    holder:SetFrameLevel(8)
    holder:EnableMouse(false)

    local shell = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    shell:SetFrameStrata(holder:GetFrameStrata())
    shell:SetFrameLevel(holder:GetFrameLevel())

    local accent = shell:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", shell, "TOPLEFT", 1, -1)
    accent:SetPoint("TOPRIGHT", shell, "TOPRIGHT", -1, -1)
    accent:SetHeight(3)

    local mapBackdrop = CreateFrame("Frame", nil, shell, "BackdropTemplate")
    mapBackdrop:SetPoint("TOPLEFT", shell, "TOPLEFT", 8, -8)
    mapBackdrop:SetPoint("BOTTOMRIGHT", shell, "BOTTOMRIGHT", -8, 8)

    local overlay = CreateFrame("Frame", nil, holder)
    overlay:SetAllPoints(shell)
    overlay:SetFrameStrata(holder:GetFrameStrata())
    overlay:SetFrameLevel(holder:GetFrameLevel() + 6)
    overlay:EnableMouse(false)

    local title = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetJustifyH("CENTER")
    title:SetJustifyV("MIDDLE")

    local detail = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    detail:SetJustifyH("CENTER")
    detail:SetJustifyV("MIDDLE")

    local leftInfo = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    leftInfo:SetJustifyH("LEFT")
    leftInfo:SetJustifyV("MIDDLE")

    local rightInfo = overlay:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    rightInfo:SetJustifyH("RIGHT")
    rightInfo:SetJustifyV("MIDDLE")

    local mailBadge = overlay:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    mailBadge:SetPoint("TOPLEFT", mapBackdrop, "TOPLEFT", 4, -4)
    mailBadge:SetText("MAIL")
    mailBadge:Hide()

    local buttonBar = CreateFrame("Frame", nil, holder, "BackdropTemplate")
    buttonBar:SetFrameStrata(holder:GetFrameStrata())
    buttonBar:SetFrameLevel(holder:GetFrameLevel() + 4)

    holder.shell = shell
    holder.mapBackdrop = mapBackdrop
    holder.overlay = overlay
    holder.title = title
    holder.detail = detail
    holder.leftInfo = leftInfo
    holder.rightInfo = rightInfo
    holder.mailBadge = mailBadge
    holder.buttonBar = buttonBar

    self.holder = holder
    self.shell = shell
    self.shellAccent = accent
    self.mapBackdrop = mapBackdrop
    self.overlayFrame = overlay
    self.titleText = title
    self.detailText = detail
    self.leftInfoText = leftInfo
    self.rightInfoText = rightInfo
    self.mailBadge = mailBadge
    self.buttonBar = buttonBar
    self.currentButtonAlpha = 1

    holder:SetScript("OnUpdate", function(_, elapsed)
        self:OnUpdate(elapsed)
    end)

    return holder
end

function MinimapModule:GetFrameAccentColor()
    local options = GetOptions()
    if options then
        return options:GetBorderColor()
    end

    return GetThemeColor("accentColor", { 0.98, 0.72, 0.24 })
end

function MinimapModule:GetBodyColors()
    local options = GetOptions()
    local background = { 0.05, 0.06, 0.08 }
    local border = { 0.20, 0.24, 0.30 }
    local accent = { self:GetFrameAccentColor() }
    if not options then
        return {
            background[1], background[2], background[3], 0.94,
        }, {
            border[1], border[2], border[3], 0.82,
        }, {
            accent[1], accent[2], accent[3], 1,
        }
    end

    return {
        background[1], background[2], background[3], options:GetBackgroundAlpha(),
    }, {
        border[1], border[2], border[3], options:GetBorderAlpha(),
    }, {
        accent[1], accent[2], accent[3], options:GetAccentAlpha(),
    }
end

function MinimapModule:ApplyFonts()
    local options = GetOptions()
    if not options or not self.holder then
        return
    end

    local titleFont, titleSize = GetFontConfig(options, "Title")
    local detailFont, detailSize = GetFontConfig(options, "Detail")
    local clockFont, clockSize = GetFontConfig(options, "Clock")
    local coordinatesFont, coordinatesSize = GetFontConfig(options, "Coordinates")
    local mailFont, mailSize = GetFontConfig(options, "Mail")

    self.titleText:SetFont(titleFont, titleSize, "")
    self.detailText:SetFont(detailFont, detailSize, "")
    self.leftInfoText:SetFont(clockFont, clockSize, "")
    self.rightInfoText:SetFont(coordinatesFont, coordinatesSize, "")
    self.mailBadge:SetFont(mailFont, mailSize, "")

    self.titleText:SetShadowOffset(1, -1)
    self.detailText:SetShadowOffset(1, -1)
    self.leftInfoText:SetShadowOffset(1, -1)
    self.rightInfoText:SetShadowOffset(1, -1)
    self.mailBadge:SetShadowOffset(1, -1)
    self.titleText:SetShadowColor(0, 0, 0, 0.85)
    self.detailText:SetShadowColor(0, 0, 0, 0.75)
    self.leftInfoText:SetShadowColor(0, 0, 0, 0.85)
    self.rightInfoText:SetShadowColor(0, 0, 0, 0.85)
    self.mailBadge:SetShadowColor(0, 0, 0, 0.85)
end

function MinimapModule:ApplyStyle()
    local options = GetOptions()
    if not self.holder or not options then
        return
    end

    local background, border, accent = self:GetBodyColors()
    local titleRed, titleGreen, titleBlue = options:GetTitleColor()
    local detailRed, detailGreen, detailBlue = options:GetDetailColor()
    local clockRed, clockGreen, clockBlue = options:GetClockColor()
    local coordinatesRed, coordinatesGreen, coordinatesBlue = options:GetCoordinatesColor()
    local mailRed, mailGreen, mailBlue = options:GetMailColor()
    self.shell:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    self.shell:SetBackdropColor(background[1], background[2], background[3], background[4])
    self.shell:SetBackdropBorderColor(border[1], border[2], border[3], border[4])

    self.mapBackdrop:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    self.mapBackdrop:SetBackdropColor(0, 0, 0, 0)
    self.mapBackdrop:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.55)
    self.shellAccent:SetColorTexture(accent[1], accent[2], accent[3], accent[4])

    self.buttonBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    self.buttonBar:SetBackdropColor(background[1], background[2], background[3], min(0.94, background[4]))
    self.buttonBar:SetBackdropBorderColor(border[1], border[2], border[3], min(1, border[4] + 0.06))

    self.titleText:SetTextColor(titleRed, titleGreen, titleBlue)
    self.detailText:SetTextColor(detailRed, detailGreen, detailBlue)
    self.leftInfoText:SetTextColor(clockRed, clockGreen, clockBlue)
    self.rightInfoText:SetTextColor(coordinatesRed, coordinatesGreen, coordinatesBlue)
    self.mailBadge:SetTextColor(mailRed, mailGreen, mailBlue)
    self:ApplyFonts()
end

function MinimapModule:GetManagedButtonsInOrder()
    local ordered = {}
    if not self.managedButtons then
        return ordered
    end

    for frame in pairs(self.managedButtons) do
        ordered[#ordered + 1] = frame
    end

    table.sort(ordered, function(left, right)
        local leftName = left and left.GetName and left:GetName() or ""
        local rightName = right and right.GetName and right:GetName() or ""
        return leftName < rightName
    end)

    return ordered
end

function MinimapModule:IsManagedAddonButton(frame)
    if not frame or frame == Minimap or frame == self.holder or frame == self.shell or frame == self.buttonBar then
        return false
    end

    local name = frame.GetName and frame:GetName() or nil
    if type(name) ~= "string" or name == "" then
        return false
    end

    for _, pattern in ipairs(EXCLUDED_BUTTON_PATTERNS) do
        if name:find(pattern) then
            return false
        end
    end

    if name:find("^LibDBIcon10_") then
        return true
    end

    local parent = frame.GetParent and frame:GetParent() or nil
    if parent ~= Minimap and parent ~= MinimapCluster then
        return false
    end

    local width = frame.GetWidth and frame:GetWidth() or 0
    local height = frame.GetHeight and frame:GetHeight() or 0
    if width <= 0 or height <= 0 or width > 40 or height > 40 then
        return false
    end

    return HasScriptHandler(frame, "OnClick")
        or HasScriptHandler(frame, "OnMouseUp")
        or HasScriptHandler(frame, "OnMouseDown")
end

function MinimapModule:CaptureManagedButtonState(frame)
    if not frame then
        return nil
    end

    local icon = FindManagedButtonIcon(frame)
    return {
        parent = frame:GetParent(),
        points = BuildPointSnapshot(frame),
        scale = frame:GetScale(),
        width = frame:GetWidth(),
        height = frame:GetHeight(),
        frameStrata = frame:GetFrameStrata(),
        frameLevel = frame:GetFrameLevel(),
        shown = frame:IsShown(),
        icon = icon,
        iconTexCoord = icon and { SafeCall(icon.GetTexCoord, icon) } or nil,
        textureStates = CaptureTextureStates(frame),
    }
end

function MinimapModule:ApplyManagedButtonStyle(frame)
    local state = self.managedButtons and self.managedButtons[frame]
    if not state or not frame then
        return
    end

    local buttonChrome = frame.__TwichUIChrome
    if not buttonChrome then
        buttonChrome = CreateFrame("Frame", nil, frame, "BackdropTemplate")
        buttonChrome:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        buttonChrome:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
        buttonChrome:SetFrameStrata(frame:GetFrameStrata())
        buttonChrome:SetFrameLevel(max(1, frame:GetFrameLevel() - 1))
        buttonChrome:EnableMouse(false)
        frame.__TwichUIChrome = buttonChrome
    end

    local background, border = self:GetBodyColors()
    buttonChrome:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    buttonChrome:SetBackdropColor(background[1], background[2], background[3], min(0.98, background[4]))
    buttonChrome:SetBackdropBorderColor(border[1], border[2], border[3], min(1, border[4] + 0.1))
    buttonChrome:Show()

    if state.icon and state.icon.SetTexCoord then
        state.icon:SetTexCoord(0.12, 0.88, 0.12, 0.88)
    end

    for _, textureState in ipairs(state.textureStates or {}) do
        local texture = textureState.region
        if texture and texture ~= state.icon then
            local texturePath = textureState.texture
            local shouldHide = false
            if type(texturePath) == "string" then
                for _, pattern in ipairs(BUTTON_TEXTURE_HIDE_PATTERNS) do
                    if texturePath:find(pattern) then
                        shouldHide = true
                        break
                    end
                end
            else
                local width = texture.GetWidth and texture:GetWidth() or 0
                local height = texture.GetHeight and texture:GetHeight() or 0
                if width >= frame:GetWidth() * 0.8 and height >= frame:GetHeight() * 0.8 then
                    shouldHide = true
                end
            end

            if shouldHide then
                texture:SetAlpha(0)
            end
        end
    end
end

function MinimapModule:RestoreManagedButton(frame)
    local state = self.managedButtons and self.managedButtons[frame]
    if not state or not frame then
        return
    end

    frame:ClearAllPoints()
    if state.parent then
        frame:SetParent(state.parent)
    end
    if state.scale then
        frame:SetScale(state.scale)
    end
    if state.width and state.height and state.width > 0 and state.height > 0 then
        frame:SetSize(state.width, state.height)
    end
    if state.frameStrata then
        frame:SetFrameStrata(state.frameStrata)
    end
    if state.frameLevel then
        frame:SetFrameLevel(state.frameLevel)
    end
    if frame.__TwichUIChrome then
        frame.__TwichUIChrome:Hide()
    end
    if state.icon and state.icon.SetTexCoord and state.iconTexCoord and #state.iconTexCoord >= 4 then
        state.icon:SetTexCoord(unpackValues(state.iconTexCoord))
    end
    for _, textureState in ipairs(state.textureStates or {}) do
        local texture = textureState.region
        if texture then
            texture:SetAlpha(textureState.alpha or 1)
            if textureState.texCoord and #textureState.texCoord >= 4 and texture.SetTexCoord then
                texture:SetTexCoord(unpackValues(textureState.texCoord))
            end
            if textureState.shown then
                texture:Show()
            else
                texture:Hide()
            end
        end
    end
    if state.points and #state.points > 0 then
        for _, point in ipairs(state.points) do
            frame:SetPoint(
                point.point,
                point.relativeTo,
                point.relativePoint or point.point,
                point.xOffset or 0,
                point.yOffset or 0)
        end
    end
    if state.shown then
        frame:Show()
    else
        frame:Hide()
    end

    self.managedButtons[frame] = nil
end

function MinimapModule:RestoreManagedButtons()
    if not self.managedButtons then
        return
    end

    for frame in pairs(self.managedButtons) do
        self:RestoreManagedButton(frame)
    end

    self.managedButtons = {}
    self.managedButtonCount = 0
end

function MinimapModule:LayoutManagedButtons()
    if not self.buttonBar then
        return
    end

    local options = GetOptions()
    local ordered = self:GetManagedButtonsInOrder()
    local buttonSize = options and options:GetAddonButtonSize() or 24
    local buttonPosition = options and options:GetAddonButtonPosition() or "bottom"
    local count = 0
    local xOffset = BUTTON_BAR_PADDING
    local yOffset = -BUTTON_BAR_PADDING
    local barHeight = buttonSize + (BUTTON_BAR_PADDING * 2)
    local barWidth = buttonSize + (BUTTON_BAR_PADDING * 2)
    local isVertical = buttonPosition == "left" or buttonPosition == "right"

    for _, button in ipairs(ordered) do
        if button then
            button:SetParent(self.buttonBar)
            button:ClearAllPoints()
            if isVertical then
                button:SetPoint("TOP", self.buttonBar, "TOP", 0, yOffset)
            else
                button:SetPoint("LEFT", self.buttonBar, "LEFT", xOffset, 0)
            end
            button:SetScale(1)
            button:SetSize(buttonSize, buttonSize)
            button:SetFrameStrata(self.buttonBar:GetFrameStrata())
            button:SetFrameLevel(self.buttonBar:GetFrameLevel() + 2)
            self:ApplyManagedButtonStyle(button)
            button:Show()
            if isVertical then
                yOffset = yOffset - buttonSize - BUTTON_GAP
            else
                xOffset = xOffset + buttonSize + BUTTON_GAP
            end
            count = count + 1
        end
    end

    self.managedButtonCount = count
    local width = 0
    local height = 1
    if count > 0 then
        if isVertical then
            width = barWidth
            height = (BUTTON_BAR_PADDING * 2) + (count * buttonSize) + ((count - 1) * BUTTON_GAP)
        else
            width = (BUTTON_BAR_PADDING * 2) + (count * buttonSize) + ((count - 1) * BUTTON_GAP)
            height = barHeight
        end
    end
    self.buttonBar:SetSize(width, height)
    self.buttonBar:SetShown(count > 0)
end

function MinimapModule:CollectAddonButtons()
    local options = GetOptions()
    if not options or options:GetManageAddonButtons() ~= true then
        self:RestoreManagedButtons()
        return
    end

    self.managedButtons = self.managedButtons or {}
    local seen = {}
    local parents = { Minimap, MinimapCluster }

    for frame in pairs(self.managedButtons) do
        if frame and frame.GetParent and frame:GetParent() == self.buttonBar then
            seen[frame] = true
        end
    end

    for _, parent in ipairs(parents) do
        if parent and parent.GetChildren then
            local children = { parent:GetChildren() }
            for _, child in ipairs(children) do
                if self:IsManagedAddonButton(child) then
                    seen[child] = true
                    if not self.managedButtons[child] then
                        self.managedButtons[child] = self:CaptureManagedButtonState(child)
                    end
                end
            end
        end
    end

    for frame in pairs(self.managedButtons) do
        if seen[frame] ~= true then
            self:RestoreManagedButton(frame)
        end
    end

    self:LayoutManagedButtons()
end

function MinimapModule:ApplyPosition()
    local options = GetOptions()
    if not options or not self.holder then
        return
    end

    local point = options.GetAnchorPoint and options:GetAnchorPoint() or "BOTTOMLEFT"
    local relativePoint = options.GetRelativePoint and options:GetRelativePoint() or point
    self.holder:ClearAllPoints()
    self.holder:SetPoint(point, UIParent, relativePoint, options:GetAnchorX(), options:GetAnchorY())
end

function MinimapModule:ApplyMinimapState()
    local options = GetOptions()
    if not options or not self.holder or not Minimap or not MinimapCluster then
        return
    end

    local size = options:GetSize()
    local mapScale = size / MINIMAP_BASE_SIZE
    local strata = self.holder:GetFrameStrata()
    local clusterLevel = self.holder:GetFrameLevel() + 2
    proxy.SetParent(MinimapCluster, self.holder)
    proxy.ClearAllPoints(MinimapCluster)
    proxy.SetPoint(MinimapCluster, "CENTER", self.shell, "CENTER", 0, 0)
    proxy.SetScale(MinimapCluster, 1)
    MinimapCluster:SetFrameStrata(strata)
    MinimapCluster:SetFrameLevel(clusterLevel)

    proxy.SetParent(Minimap, MinimapCluster)
    proxy.ClearAllPoints(Minimap)
    proxy.SetPoint(Minimap, "CENTER", MinimapCluster, "CENTER", 0, 0)
    Minimap:SetSize(MINIMAP_BASE_SIZE, MINIMAP_BASE_SIZE)
    proxy.SetScale(Minimap, mapScale)
    Minimap:SetFrameStrata(strata)
    Minimap:SetFrameLevel(clusterLevel + 1)
    if Minimap.SetMaskTexture then
        Minimap:SetMaskTexture(options:GetCircular() and ROUND_MASK or SQUARE_MASK)
    end

    if options:GetCircular() then
        _G.GetMinimapShape = function()
            return "ROUND"
        end
    else
        _G.GetMinimapShape = function()
            return "SQUARE"
        end
    end

    pcall(function()
        local zoom = Minimap:GetZoom()
        if zoom then
            Minimap:SetZoom(zoom)
        end
    end)

    Minimap:Show()
    MinimapCluster:Show()
end

function MinimapModule:ApplyLayout()
    local options = GetOptions()
    if not options or not self.holder then
        return
    end

    local mapSize = options:GetSize()
    local shellSize = mapSize + 16
    local showZone = options:GetShowZoneText()
    local showCoordinates = options:GetShowCoordinates()
    local showClock = options:GetShowClock()
    local zonePosition = options:GetZoneTextPosition()
    local clockPosition = options:GetClockPosition()
    local coordinatesPosition = options:GetCoordinatesPosition()
    local buttonPosition = options:GetAddonButtonPosition()
    local buttonBarVisible = self.managedButtonCount and self.managedButtonCount > 0 and options:GetManageAddonButtons()
    local zoneTop = showZone and zonePosition == "top"
    local zoneBottom = showZone and zonePosition ~= "top"
    local mapAnchor = self.mapBackdrop or self.shell
    local zoneOffsetX = options.GetZoneTextOffsetX and options:GetZoneTextOffsetX() or 0
    local zoneOffsetY = options.GetZoneTextOffsetY and options:GetZoneTextOffsetY() or 0
    local clockOffsetX = options.GetClockOffsetX and options:GetClockOffsetX() or 0
    local clockOffsetY = options.GetClockOffsetY and options:GetClockOffsetY() or 0
    local coordinatesOffsetX = options.GetCoordinatesOffsetX and options:GetCoordinatesOffsetX() or 0
    local coordinatesOffsetY = options.GetCoordinatesOffsetY and options:GetCoordinatesOffsetY() or 0
    local buttonOffsetX = options.GetAddonButtonOffsetX and options:GetAddonButtonOffsetX() or 0
    local buttonOffsetY = options.GetAddonButtonOffsetY and options:GetAddonButtonOffsetY() or 0

    self.holder:SetSize(shellSize, shellSize)
    self.shell:ClearAllPoints()
    self.shell:SetPoint("CENTER", self.holder, "CENTER", 0, 0)
    self.shell:SetSize(shellSize, shellSize)

    self.buttonBar:ClearAllPoints()
    if buttonBarVisible then
        local buttonAnchor, buttonBaseX, buttonBaseY = GetEdgeAnchorPoint(buttonPosition)
        self.buttonBar:SetPoint(buttonAnchor, mapAnchor, buttonAnchor, buttonBaseX + buttonOffsetX,
            buttonBaseY + buttonOffsetY)
    end

    self.titleText:ClearAllPoints()
    self.detailText:ClearAllPoints()
    if zoneTop then
        self.titleText:SetPoint("TOPLEFT", mapAnchor, "TOPLEFT", 8 + zoneOffsetX, -10 + zoneOffsetY)
        self.titleText:SetPoint("TOPRIGHT", mapAnchor, "TOPRIGHT", -8 + zoneOffsetX, -10 + zoneOffsetY)
        self.detailText:SetPoint("TOPLEFT", self.titleText, "BOTTOMLEFT", 0, -2)
        self.detailText:SetPoint("TOPRIGHT", self.titleText, "BOTTOMRIGHT", 0, -2)
    elseif zoneBottom then
        self.detailText:SetPoint("BOTTOMLEFT", mapAnchor, "BOTTOMLEFT", 8 + zoneOffsetX, 8 + zoneOffsetY)
        self.detailText:SetPoint("BOTTOMRIGHT", mapAnchor, "BOTTOMRIGHT", -8 + zoneOffsetX, 8 + zoneOffsetY)
        self.titleText:SetPoint("BOTTOMLEFT", mapAnchor, "BOTTOMLEFT", 8 + zoneOffsetX, 22 + zoneOffsetY)
        self.titleText:SetPoint("BOTTOMRIGHT", mapAnchor, "BOTTOMRIGHT", -8 + zoneOffsetX, 22 + zoneOffsetY)
    end
    self.titleText:SetShown(showZone)

    self.leftInfoText:ClearAllPoints()
    self.leftInfoText:SetJustifyH(clockPosition and clockPosition:find("right") and "RIGHT" or "LEFT")
    if showClock then
        local clockAnchor, clockBaseX, clockBaseY = GetInsetAnchorPoint(clockPosition)
        self.leftInfoText:SetPoint(clockAnchor, mapAnchor, clockAnchor, clockBaseX + clockOffsetX,
            clockBaseY + clockOffsetY)
    end
    self.leftInfoText:SetShown(showClock)

    self.rightInfoText:ClearAllPoints()
    self.rightInfoText:SetJustifyH(coordinatesPosition and coordinatesPosition:find("right") and "RIGHT" or "LEFT")
    if showCoordinates then
        local coordinatesAnchor, coordinatesBaseX, coordinatesBaseY = GetInsetAnchorPoint(coordinatesPosition)
        self.rightInfoText:SetPoint(coordinatesAnchor, mapAnchor, coordinatesAnchor,
            coordinatesBaseX + coordinatesOffsetX,
            coordinatesBaseY + coordinatesOffsetY)
    end
    self.rightInfoText:SetShown(showCoordinates)

    self.buttonBar:SetShown(buttonBarVisible == true)

    self.mailBadge:SetShown(options:GetShowMailIndicator() and HasNewMail and HasNewMail() == true)
end

function MinimapModule:UpdateZoneText()
    local options = GetOptions()
    if not options or not self.holder then
        return
    end

    if not options:GetShowZoneText() then
        self.titleText:SetText("")
        self.detailText:SetText("")
        self.detailText:Hide()
        return
    end

    local zone = (GetRealZoneText and GetRealZoneText()) or (GetZoneText and GetZoneText()) or "World"
    local subzone = (GetSubZoneText and GetSubZoneText()) or ""
    local instanceType = "none"
    local difficultyName = nil
    if GetInstanceInfo then
        local _, foundInstanceType, _, foundDifficultyName = GetInstanceInfo()
        instanceType = foundInstanceType or "none"
        difficultyName = foundDifficultyName
    end
    local detail = ""

    if type(difficultyName) == "string" and difficultyName ~= "" and instanceType ~= "none" then
        detail = difficultyName
    elseif options:GetShowSubzone() and type(subzone) == "string" and subzone ~= "" and subzone ~= zone then
        detail = subzone
    end

    self.titleText:SetText(zone ~= "" and zone or "World")
    self.detailText:SetText(detail)
    self.detailText:SetShown(detail ~= "")
end

function MinimapModule:UpdateCoordinateText()
    local options = GetOptions()
    if not options or not self.rightInfoText then
        return
    end

    if not options:GetShowCoordinates() or not C_Map then
        self.rightInfoText:SetText("")
        return
    end

    local precision = options.GetCoordinatePrecision and options:GetCoordinatePrecision() or 1
    local xValue, yValue = ResolvePlayerMapPosition()

    if type(xValue) == "number" and type(yValue) == "number" then
        self.rightInfoText:SetText(format("%s, %s",
            FormatCoordinateValue(xValue * 100, precision),
            FormatCoordinateValue(yValue * 100, precision)))
    else
        self.rightInfoText:SetText(format("%s, %s",
            FormatCoordinateValue(nil, precision),
            FormatCoordinateValue(nil, precision)))
    end
end

function MinimapModule:UpdateClockText()
    local options = GetOptions()
    if not options or not self.leftInfoText then
        return
    end

    if not options:GetShowClock() then
        self.leftInfoText:SetText("")
        return
    end

    local hour, minute
    if options:GetUseLocalTime() then
        hour = tonumber(date("%H"))
        minute = tonumber(date("%M"))
    else
        if GetGameTime then
            hour, minute = GetGameTime()
        end
    end

    self.leftInfoText:SetText(FormatClock(hour, minute, options:GetUse24HourClock()))
end

function MinimapModule:UpdateMailBadge()
    local options = GetOptions()
    if not options or not self.mailBadge then
        return
    end

    local shouldShow = options:GetShowMailIndicator() and HasNewMail and HasNewMail() == true
    self.mailBadge:SetShown(shouldShow == true)
    if shouldShow then
        local pulse = (GetTime() * 3) % (2 * math.pi)
        local alpha = 0.55 + ((math.sin(pulse) + 1) * 0.225)
        self.mailBadge:SetAlpha(alpha)
    end
end

function MinimapModule:UpdateButtonBarAlpha(elapsed)
    local options = GetOptions()
    if not options or not self.buttonBar or not self.buttonBar:IsShown() then
        return
    end

    local hovered = IsCursorOverFrame(self.shell) or IsCursorOverFrame(self.buttonBar)
    local activeAlpha = options.GetAddonButtonActiveAlpha and options:GetAddonButtonActiveAlpha() or 1
    local inactiveAlpha = options.GetAddonButtonInactiveAlpha and options:GetAddonButtonInactiveAlpha() or 0.16
    local targetAlpha = (options:GetFadeAddonButtonsOnHover() and not hovered) and inactiveAlpha or activeAlpha
    local blend = min(1, (elapsed or 0.016) * 10)
    self.currentButtonAlpha = Lerp(self.currentButtonAlpha or targetAlpha, targetAlpha, blend)
    self.buttonBar:SetAlpha(self.currentButtonAlpha)
end

function MinimapModule:UpdateDynamicText(force)
    self:UpdateZoneText()
    self:UpdateCoordinateText()
    self:UpdateClockText()
    self:UpdateMailBadge()

    if force == true then
        self:ApplyLayout()
    end
end

function MinimapModule:RefreshMoverHandle()
    local moversModule = _G.TwichMoverModule
    if not moversModule then
        return
    end

    if moversModule._PositionHandle then
        moversModule:_PositionHandle("UI_minimap")
    end
    if moversModule._RefreshHandleVisibility then
        moversModule:_RefreshHandleVisibility("UI_minimap")
    end
end

function MinimapModule:BuildDesignerExtras()
    local options = GetOptions()
    if not options then
        return {}
    end

    return {
        {
            type = "section",
            tab = "Layout",
            label = "Frame",
        },
        {
            label = "Size",
            type = "range",
            tab = "Layout",
            min = 160,
            max = 320,
            step = 1,
            get = function()
                return options:GetSize()
            end,
            set = function(value)
                options:SetSize(nil, value)
            end,
        },
        {
            label = "Circular",
            type = "toggle",
            tab = "Layout",
            get = function()
                return options:GetCircular()
            end,
            set = function(value)
                options:SetCircular(nil, value)
            end,
        },
        {
            type = "section",
            tab = "Content",
            label = "Overlay Text",
        },
        {
            label = "Zone Text",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowZoneText()
            end,
            set = function(value)
                options:SetShowZoneText(nil, value)
            end,
        },
        {
            label = "Coordinates",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowCoordinates()
            end,
            set = function(value)
                options:SetShowCoordinates(nil, value)
            end,
        },
        {
            label = "Clock",
            type = "toggle",
            tab = "Content",
            get = function()
                return options:GetShowClock()
            end,
            set = function(value)
                options:SetShowClock(nil, value)
            end,
        },
        {
            type = "section",
            tab = "Buttons",
            label = "Addon Buttons",
        },
        {
            label = "Collect Buttons",
            type = "toggle",
            tab = "Buttons",
            get = function()
                return options:GetManageAddonButtons()
            end,
            set = function(value)
                options:SetManageAddonButtons(nil, value)
            end,
        },
        {
            label = "Fade Until Hovered",
            type = "toggle",
            tab = "Buttons",
            hidden = function()
                return not options:GetManageAddonButtons()
            end,
            get = function()
                return options:GetFadeAddonButtonsOnHover()
            end,
            set = function(value)
                options:SetFadeAddonButtonsOnHover(nil, value)
            end,
        },
        {
            label = "Button Size",
            type = "range",
            tab = "Buttons",
            min = 18,
            max = 34,
            step = 1,
            hidden = function()
                return not options:GetManageAddonButtons()
            end,
            get = function()
                return options:GetAddonButtonSize()
            end,
            set = function(value)
                options:SetAddonButtonSize(nil, value)
            end,
        },
    }
end

function MinimapModule:RegisterWithMoverModule()
    local moversModule = _G.TwichMoverModule
    local options = GetOptions()
    if not moversModule or type(moversModule.RegisterMover) ~= "function" or not options then
        return
    end

    moversModule:RegisterMover("UI_minimap", {
        label = "Minimap",
        category = "Interface",
        headerToggle = {
            label = "Enabled",
            get = function()
                return options:GetEnabled()
            end,
            set = function(value)
                options:SetEnabled(nil, value)
            end,
        },
        headerAction = {
            label = "Pulse",
            accent = { 0.95, 0.77, 0.28 },
            func = function()
                self:ShowPreview()
            end,
            disabled = function()
                return not options:GetEnabled()
            end,
        },
        getPoint = function()
            return options.GetAnchorPoint and options:GetAnchorPoint() or "BOTTOMLEFT"
        end,
        getRelativePoint = function()
            return options.GetRelativePoint and options:GetRelativePoint() or
                (options.GetAnchorPoint and options:GetAnchorPoint() or "BOTTOMLEFT")
        end,
        getX = function()
            return options:GetAnchorX()
        end,
        getY = function()
            return options:GetAnchorY()
        end,
        getW = function()
            local frame = self:EnsureShell()
            return frame and frame:GetWidth() or 260
        end,
        getH = function()
            local frame = self:EnsureShell()
            return frame and frame:GetHeight() or 320
        end,
        setPos = function(x, y)
            options:SetAnchorPosition(Round(x), Round(y))
        end,
        setAnchor = function(point, x, y)
            if options.SetAnchor then
                options:SetAnchor(point, Round(x), Round(y))
            else
                options:SetAnchorPosition(Round(x), Round(y))
            end
        end,
        isEnabled = function()
            return options:GetEnabled()
        end,
        extras = self:BuildDesignerExtras(),
    })
end

function MinimapModule:ApplySettings(reason)
    local options = GetOptions()
    if not options then
        return
    end

    self:SaveBaseState()
    self:EnsureShell()
    self:CollectAddonButtons()
    self:ApplyStyle()
    self:ApplyMinimapState()
    self:ApplyLayout()
    self:ApplyPosition()
    self:HideDefaultChrome()
    self:UpdateDynamicText(true)
    self.holder:Show()
    self.previewUntil = reason == "preview" and (GetTime() + 1.6) or self.previewUntil
    self:RefreshMoverHandle()
end

function MinimapModule:GetDebugSummaryLine()
    local options = GetOptions()
    local clusterParent = MinimapCluster and SafeCall(MinimapCluster.GetParent, MinimapCluster) or nil
    local clusterParentName = clusterParent and SafeCall(clusterParent.GetName, clusterParent) or nil
    local minimapParent = Minimap and SafeCall(Minimap.GetParent, Minimap) or nil
    local minimapParentName = minimapParent and SafeCall(minimapParent.GetName, minimapParent) or nil

    return format(
        "Enabled: %s  |  Holder: %s  |  Shell: %s  |  Cluster Parent: %s  |  Minimap Parent: %s  |  Buttons: %s",
        SafeDebugString(options and options:GetEnabled()),
        SafeDebugString(self.holder and self.holder:IsShown()),
        SafeDebugString(self.shell and self.shell:IsShown()),
        SafeDebugString(clusterParentName),
        SafeDebugString(minimapParentName),
        SafeDebugString(self.managedButtonCount or 0))
end

function MinimapModule:BuildDebugReport()
    local options = GetOptions()
    local lines = {
        "TwichUI Minimap Debug Report",
        format("moduleEnabled=%s optionEnabled=%s pendingApply=%s previewUntil=%s",
            SafeDebugString(self:IsEnabled()),
            SafeDebugString(options and options:GetEnabled()),
            SafeDebugString(self.pendingApplyReason),
            SafeDebugString(self.previewUntil)),
        format(
            "settings size=%s circular=%s zone=%s subzone=%s coords=%s clock=%s localTime=%s mail=%s manageButtons=%s buttonSize=%s",
            SafeDebugString(options and options:GetSize()),
            SafeDebugString(options and options:GetCircular()),
            SafeDebugString(options and options:GetShowZoneText()),
            SafeDebugString(options and options:GetShowSubzone()),
            SafeDebugString(options and options:GetShowCoordinates()),
            SafeDebugString(options and options:GetShowClock()),
            SafeDebugString(options and options:GetUseLocalTime()),
            SafeDebugString(options and options:GetShowMailIndicator()),
            SafeDebugString(options and options:GetManageAddonButtons()),
            SafeDebugString(options and options:GetAddonButtonSize())),
        format("anchor=(%s,%s)",
            SafeDebugString(options and options:GetAnchorX()),
            SafeDebugString(options and options:GetAnchorY())),
        format("holder=%s", DescribeFrame(self.holder)),
        format("holderPoint=%s", DescribePoint(self.holder)),
        format("shell=%s", DescribeFrame(self.shell)),
        format("shellPoint=%s", DescribePoint(self.shell)),
        format("buttonBar=%s", DescribeFrame(self.buttonBar)),
        format("minimapCluster=%s", DescribeFrame(MinimapCluster)),
        format("minimapClusterPoint=%s", DescribePoint(MinimapCluster)),
        format("minimap=%s", DescribeFrame(Minimap)),
        format("minimapPoint=%s", DescribePoint(Minimap)),
        format("mask=%s shape=%s",
            SafeDebugString(Minimap and Minimap.GetMaskTexture and Minimap:GetMaskTexture() or nil),
            SafeDebugString(_G.GetMinimapShape and _G.GetMinimapShape() or nil)),
        format(
            "titleShown=%s detailShown=%s leftInfo=%s rightInfo=%s mailShown=%s buttonBarShown=%s managedButtonCount=%s",
            SafeDebugString(self.titleText and self.titleText:IsShown()),
            SafeDebugString(self.detailText and self.detailText:IsShown()),
            SafeDebugString(self.leftInfoText and self.leftInfoText:GetText()),
            SafeDebugString(self.rightInfoText and self.rightInfoText:GetText()),
            SafeDebugString(self.mailBadge and self.mailBadge:IsShown()),
            SafeDebugString(self.buttonBar and self.buttonBar:IsShown()),
            SafeDebugString(self.managedButtonCount or 0)),
        "",
        "Managed Buttons",
    }

    local managedTotal = 0
    if self.managedButtons then
        for frame in pairs(self.managedButtons) do
            managedTotal = managedTotal + 1
            table_insert(lines, format("  %d. %s | point=%s", managedTotal, DescribeFrame(frame), DescribePoint(frame)))
        end
    end

    if managedTotal == 0 then
        table_insert(lines, "  none")
    end

    table_insert(lines, "")
    table_insert(lines, "Hidden Blizzard Chrome")
    for _, frameName in ipairs(HIDDEN_FRAME_NAMES) do
        local frame = _G[frameName]
        table_insert(lines, format("  %s: %s", frameName, DescribeFrame(frame)))
    end

    return table_concat(lines, "\n")
end

function MinimapModule:CaptureDebugSnapshot(shouldShow)
    local console = GetDebugConsole()
    if not console or type(console.Log) ~= "function" then
        return false
    end

    console:Log(DEBUG_SOURCE_KEY, self:BuildDebugReport(), shouldShow == true)
    return true
end

function MinimapModule:ShowPreview()
    if not self:IsEnabled() then
        local options = GetOptions()
        if options then
            options:SetEnabled(nil, true)
        end
        return
    end

    self.previewUntil = GetTime() + 1.6
    self:ApplySettings("preview")
end

function MinimapModule:OnThemeChanged(key)
    if key ~= nil and key ~= "primary" and key ~= "surface" and key ~= "panel" then
        return
    end

    self:RequestApply("theme")
end

function MinimapModule:OnUpdate(elapsed)
    if not self:IsEnabled() or not self.holder or not self.holder:IsShown() then
        return
    end

    self.cursorElapsed = (self.cursorElapsed or 0) + elapsed
    self.coordElapsed = (self.coordElapsed or 0) + elapsed
    self.clockElapsed = (self.clockElapsed or 0) + elapsed
    self.rescanElapsed = (self.rescanElapsed or 0) + elapsed

    if self.coordElapsed >= COORDS_INTERVAL then
        self.coordElapsed = 0
        self:UpdateCoordinateText()
        self:UpdateMailBadge()
    end

    if self.clockElapsed >= CLOCK_INTERVAL then
        self.clockElapsed = 0
        self:UpdateClockText()
        self:UpdateZoneText()
    end

    if self.rescanElapsed >= RESCAN_INTERVAL then
        self.rescanElapsed = 0
        self:CollectAddonButtons()
        self:ApplyLayout()
        self:RefreshMoverHandle()
    end

    if self.cursorElapsed >= CURSOR_CHECK_INTERVAL then
        self.cursorElapsed = 0
        self:UpdateButtonBarAlpha(CURSOR_CHECK_INTERVAL)
    end

    if self.previewUntil and GetTime() < self.previewUntil then
        local accentR, accentG, accentB = self:GetFrameAccentColor()
        local phase = (GetTime() * 8) % (2 * math.pi)
        local alpha = 0.35 + ((math.sin(phase) + 1) * 0.30)
        self.shellAccent:SetColorTexture(accentR, accentG, accentB, alpha)
    elseif self.previewUntil then
        self.previewUntil = nil
        self:ApplyStyle()
    end
end

function MinimapModule:OnEnable()
    if not Minimap or not MinimapCluster then
        return
    end

    self.managedButtons = self.managedButtons or {}
    self:EnsureShell()
    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", function()
        self:RequestApply("entering-world")
    end)
    self:RegisterEvent("ZONE_CHANGED", function()
        self:UpdateZoneText()
    end)
    self:RegisterEvent("ZONE_CHANGED_INDOORS", function()
        self:UpdateZoneText()
    end)
    self:RegisterEvent("ZONE_CHANGED_NEW_AREA", function()
        self:UpdateZoneText()
    end)
    self:RegisterEvent("UPDATE_PENDING_MAIL", function()
        self:UpdateMailBadge()
    end)
    self:RegisterEvent("ADDON_LOADED", function()
        if C_Timer and C_Timer.After then
            C_Timer.After(0.25, function()
                if self:IsEnabled() then
                    self:RequestApply("addon-loaded")
                end
            end)
        end
    end)
    self:RegisterEvent("PLAYER_REGEN_ENABLED", function()
        if self.pendingApplyReason then
            self:RequestApply(self.pendingApplyReason)
        end
    end)

    self:RegisterWithMoverModule()

    local debugConsole = GetDebugConsole()
    if debugConsole and debugConsole.RegisterSource then
        debugConsole:RegisterSource(DEBUG_SOURCE_KEY, {
            title = "Minimap",
            order = 54,
            aliases = { "mm", "map" },
            maxLines = 80,
            isEnabled = function()
                return true
            end,
            buildReport = function()
                return self:BuildDebugReport()
            end,
        })
    end

    self:ApplySettings("enable")
end

function MinimapModule:OnDisable()
    self:UnregisterAllEvents()
    self:UnregisterAllMessages()
    self.pendingApplyReason = nil
    self:RestoreManagedButtons()
    self:RestoreBaseState()
    self:RestoreDefaultChrome()
    if self.holder then
        self.holder:Hide()
    end
    if _G.TwichMoverModule and type(_G.TwichMoverModule.UnregisterMover) == "function" then
        _G.TwichMoverModule:UnregisterMover("UI_minimap")
    end
end
