--[[
    LFG Finder Browser UI - Oak-inspired browser layout for TwichUI.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)
local LFG = T:GetModule("LFGFinder")

local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local UIParent = _G.UIParent
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local floor = _G.math.floor
local min = _G.math.min
local max = _G.math.max
local tonumber = _G.tonumber
local tostring = _G.tostring
local type = _G.type
local ipairs = _G.ipairs
local format = _G.format
local unpack = _G.unpack or unpack

local FRAME_WIDTH = 900
local FRAME_HEIGHT = 442
local TITLE_HEIGHT = 28
local FILTER_HEIGHT = 34
local HEADER_HEIGHT = 22
local ROW_HEIGHT = 34
local ROWS_VISIBLE = 9
local SCROLLBAR_WIDTH = 10
local LIST_WIDTH = FRAME_WIDTH - 36 - SCROLLBAR_WIDTH

local ROLE_TEXTURE = "Interface\\LFGFrame\\UI-LFG-ICON-PORTRAITROLES"
local ROLE_COORDS = {
    TANK = { 0 / 64, 19 / 64, 22 / 64, 41 / 64 },
    HEALER = { 20 / 64, 39 / 64, 1 / 64, 20 / 64 },
    DAMAGER = { 20 / 64, 39 / 64, 22 / 64, 41 / 64 },
}
local ROLE_ORDER = { "TANK", "HEALER", "DAMAGER", "DAMAGER", "DAMAGER" }
local DIFFICULTY_ORDER = { "ANY", "MYTHIC_PLUS", "RAID", "PVP" }
local DIFFICULTY_LABELS = {
    ANY = "Any",
    MYTHIC_PLUS = "M+",
    RAID = "Raid",
    PVP = "PvP",
}
local KEY_PRESETS = {
    { label = "Any Keys",   min = 2,  max = 99 },
    { label = "+2 to +9",   min = 2,  max = 9 },
    { label = "+10 to +14", min = 10, max = 14 },
    { label = "+15+",       min = 15, max = 99 },
}

local function Clamp(value, low, high)
    return max(low, min(high, value))
end

local function TrimText(text, maxLength)
    if text == nil then
        return ""
    end

    if type(text) ~= "string" then
        return tostring(text)
    end

    local okLen, length = pcall(function()
        return #text
    end)
    if not okLen then
        -- Secret/protected strings cannot be manipulated in tainted context; return as-is for SetText.
        return text
    end

    if length <= maxLength then
        return text
    end

    local okSub, shortened = pcall(function()
        return text:sub(1, maxLength - 1)
    end)
    if okSub and shortened then
        return shortened .. "..."
    end

    return text
end

local function GetRoleCoords(role)
    return unpack(ROLE_COORDS[role or "DAMAGER"] or ROLE_COORDS.DAMAGER)
end

local function ApplyFrameBackdrop(frame, bgR, bgG, bgB, bgA, borderR, borderG, borderB, borderA, edgeSize)
    frame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeSize = edgeSize or 1,
    })
    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, borderA)
end

local function ApplyThemeFontString(module, fontString, size, r, g, b, alpha)
    if not fontString then
        return
    end

    fontString:SetFont(module:GetThemeFont(), size or 10, "")
    fontString:SetTextColor(r or 1, g or 0.95, b or 0.85, alpha or 1)
end

local function EnsureButtonFontString(module, btn, size)
    local fontString = btn:GetFontString()
    if not fontString then
        fontString = btn:CreateFontString(nil, "OVERLAY")
        fontString:SetPoint("CENTER", btn, "CENTER", 0, 0)
        btn:SetFontString(fontString)
    end

    ApplyThemeFontString(module, fontString, size or 10)
    return fontString
end

local function CreateColumnHeader(parent, text, width, xOffset, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, HEADER_HEIGHT)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", xOffset, 0)
    button:SetScript("OnClick", onClick)

    button.text = button:CreateFontString(nil, "OVERLAY")
    button.text:SetPoint("LEFT", button, "LEFT", 4, 0)
    button.text:SetPoint("RIGHT", button, "RIGHT", -4, 0)
    button.text:SetJustifyH("LEFT")
    button.text:SetFont(STANDARD_TEXT_FONT, 10, "")
    button.text:SetText(text)

    return button
end

local function GetActivityText(result)
    local primary = result.dungeonName or result.activityName
    if primary and primary ~= "" and primary ~= "Unknown Activity" then
        return primary
    end
    return result.listingTitle or result.displayName or result.name or "Activity"
end

local function GetTitleText(result)
    return result.listingTitle or result.displayName or result.name or "Untitled Listing"
end

local function GetMetaText(result)
    local leader = result.leaderName or "Unknown leader"
    local mode = result.mode or "generic"
    local modeLabel = mode == "mythic_plus" and "M+"
        or mode == "raid" and "Raid"
        or mode == "legacy_raid" and "Legacy"
        or mode == "rated_pvp" and "Rated"
        or mode == "pvp" and "PvP"
        or mode == "delve" and "Delve"
        or mode == "open_world" and "World"
        or "Listing"
    return leader .. "  |  " .. modeLabel
end

local function GetModeColor(result)
    local mode = result and result.mode or "generic"
    if mode == "mythic_plus" or mode == "dungeon" then
        return 0.33, 0.87, 0.93
    elseif mode == "raid" or mode == "legacy_raid" then
        return 0.96, 0.82, 0.46
    elseif mode == "rated_pvp" or mode == "pvp" then
        return 0.92, 0.46, 0.62
    elseif mode == "delve" then
        return 0.72, 0.92, 0.50
    end
    return 0.80, 0.84, 0.88
end

local function GetRatingColor(rating)
    rating = tonumber(rating) or 0
    if rating >= 3200 then
        return 1.00, 0.55, 0.25
    elseif rating >= 2800 then
        return 0.83, 0.35, 1.00
    elseif rating >= 2400 then
        return 0.34, 0.73, 1.00
    elseif rating >= 1800 then
        return 0.25, 0.92, 0.52
    elseif rating > 0 then
        return 0.95, 0.82, 0.36
    end
    return 0.62, 0.66, 0.72
end

local function BuildRoleLayout(result)
    local slots = {}
    local players = result.players or {}
    local usedPlayers = {}

    for slotIndex, expectedRole in ipairs(ROLE_ORDER) do
        for playerIndex, player in ipairs(players) do
            if not usedPlayers[playerIndex] and player.role == expectedRole then
                slots[slotIndex] = player
                usedPlayers[playerIndex] = true
                break
            end
        end
    end

    local roleCounts = result.roleCounts or {}
    local remaining = {
        TANK = tonumber(roleCounts.TANK) or 0,
        HEALER = tonumber(roleCounts.HEALER) or 0,
        DAMAGER = tonumber(roleCounts.DAMAGER) or 0,
    }
    for _, player in ipairs(players) do
        remaining[player.role] = max(0, (remaining[player.role] or 0) - 1)
    end

    for slotIndex, expectedRole in ipairs(ROLE_ORDER) do
        if not slots[slotIndex] and (remaining[expectedRole] or 0) > 0 then
            slots[slotIndex] = { role = expectedRole }
            remaining[expectedRole] = remaining[expectedRole] - 1
        end
    end

    return slots
end

function LFG:GetThemeModule()
    if self._themeCache then return self._themeCache end
    self._themeCache = T:GetModule("Theme", true)
    return self._themeCache
end

function LFG:GetThemeColor(key, fallback)
    local theme = self:GetThemeModule()
    if theme and type(theme.GetColor) == "function" then
        local c = theme:GetColor(key)
        if type(c) == "table" then
            return c[1] or 0.1, c[2] or 0.72, c[3] or 0.74
        end
    end

    if fallback then
        return fallback[1], fallback[2], fallback[3]
    end

    return 0.1, 0.72, 0.74
end

function LFG:GetThemeFont()
    local theme = self:GetThemeModule()
    if theme and type(theme.Get) == "function" then
        local fontName = theme:Get("globalFont")
        if fontName and fontName ~= "__default" then
            local LSM = T.Libs and T.Libs.LSM
            if LSM then
                return LSM:Fetch("font", fontName) or STANDARD_TEXT_FONT
            end
        end
    end
    return STANDARD_TEXT_FONT
end

function LFG:ApplyThemeBackdrop(frame)
    local theme = self:GetThemeModule()
    if not theme then return end

    local bg = theme:GetColor("backgroundColor") or { 0.05, 0.06, 0.08 }
    local border = theme:GetColor("borderColor") or { 0.24, 0.26, 0.32 }
    local bgAlpha = theme:Get("backgroundAlpha") or 0.94
    local borderAlpha = theme:Get("borderAlpha") or 0.85

    ApplyFrameBackdrop(frame, bg[1], bg[2], bg[3], bgAlpha, border[1], border[2], border[3], borderAlpha, 1)
end

function LFG:ApplyThemeTitleBar(frame)
    local theme = self:GetThemeModule()
    if not theme then return end
    local primary = theme:GetColor("primaryColor") or { 0.10, 0.72, 0.74 }
    ApplyFrameBackdrop(frame, primary[1] * 0.32, primary[2] * 0.32, primary[3] * 0.32, 0.82, primary[1], primary[2],
        primary[3], 0.45, 1)
end

function LFG:ApplyThemePanel(frame)
    local theme = self:GetThemeModule()
    if not theme then return end
    local bg = theme:GetColor("backgroundColor") or { 0.05, 0.06, 0.08 }
    local border = theme:GetColor("borderColor") or { 0.24, 0.26, 0.32 }
    ApplyFrameBackdrop(frame, bg[1] * 1.08, bg[2] * 1.08, bg[3] * 1.08, 0.72, border[1], border[2], border[3], 0.42, 1)
end

function LFG:ApplyThemeButton(btn, isActive, isMuted)
    local theme = self:GetThemeModule()
    if not theme then return end
    local accent = theme:GetColor("accentColor") or { 0.96, 0.76, 0.24 }
    local border = theme:GetColor("borderColor") or { 0.24, 0.26, 0.32 }
    local bg = theme:GetColor("backgroundColor") or { 0.05, 0.06, 0.08 }

    local bgR = bg[1] * 1.12
    local bgG = bg[2] * 1.12
    local bgB = bg[3] * 1.12
    local alpha = isMuted and 0.42 or 0.72
    local borderR, borderG, borderB = border[1], border[2], border[3]

    if isActive then
        bgR = accent[1] * 0.25
        bgG = accent[2] * 0.25
        bgB = accent[3] * 0.25
        borderR, borderG, borderB = accent[1], accent[2], accent[3]
        alpha = 0.92
    end

    ApplyFrameBackdrop(btn, bgR, bgG, bgB, alpha, borderR, borderG, borderB, 0.85, 1)
    local fs = EnsureButtonFontString(self, btn, 10)
    if isMuted then
        fs:SetTextColor(0.65, 0.68, 0.72)
    elseif isActive then
        fs:SetTextColor(1, 0.97, 0.90)
    else
        fs:SetTextColor(0.92, 0.92, 0.92)
    end
end

function LFG:ApplyApplyButtonStyle(btn, isApplied, hovered)
    if isApplied then
        -- Dimmed green "Already applied" state
        ApplyFrameBackdrop(btn, 0.06, 0.16, 0.08, 0.72, 0.22, 0.52, 0.26, 0.70, 1)
        local fs = EnsureButtonFontString(self, btn, 10)
        fs:SetTextColor(0.48, 0.85, 0.52)
    elseif hovered then
        -- Bright teal hover
        ApplyFrameBackdrop(btn, 0.08, 0.32, 0.34, 0.95, 0.22, 0.82, 0.86, 0.95, 1)
        local fs = EnsureButtonFontString(self, btn, 10)
        fs:SetTextColor(1, 1, 1)
    else
        -- Normal teal-outlined ready state
        ApplyFrameBackdrop(btn, 0.06, 0.20, 0.22, 0.82, 0.10, 0.72, 0.74, 0.85, 1)
        local fs = EnsureButtonFontString(self, btn, 10)
        fs:SetTextColor(0.34, 0.92, 0.94)
    end
end

function LFG:CreateBrowserButton(parent, width, text, onClick)
    local button = CreateFrame("Button", nil, parent, "BackdropTemplate")
    button:SetSize(width, 22)
    self:ApplyThemeButton(button, false, false)
    button:SetText(text)
    button:SetScript("OnClick", onClick)
    return button
end

function LFG:SetSortState(sortKey)
    local options = self:GetOptions()
    if not options then return end

    local currentSort = self:GetSortColumn()
    local ascending = self:GetSortAscending()
    if currentSort == sortKey then
        ascending = not ascending
    else
        ascending = false
    end

    if type(options.SetSortColumn) == "function" then
        options:SetSortColumn(nil, sortKey)
    end
    if type(options.SetSortAscending) == "function" then
        options:SetSortAscending(nil, ascending)
    end

    self:SortResults()
    self._browserScrollOffset = 0
    self:RefreshBrowserUIImpl()
end

function LFG:GetActiveKeyPresetIndex()
    local filters = self:GetActiveFilters()
    for index, preset in ipairs(KEY_PRESETS) do
        if filters.keyMin == preset.min and filters.keyMax == preset.max then
            return index
        end
    end
    return 1
end

function LFG:CycleDifficultyFilter()
    local options = self:GetOptions()
    if not options or type(options.SetSelectedDifficulty) ~= "function" then return end
    local current = type(options.GetSelectedDifficulty) == "function" and options:GetSelectedDifficulty() or "ANY"
    local nextIndex = 1
    for index, token in ipairs(DIFFICULTY_ORDER) do
        if token == current then
            nextIndex = index + 1
            break
        end
    end
    if nextIndex > #DIFFICULTY_ORDER then
        nextIndex = 1
    end
    options:SetSelectedDifficulty(nil, DIFFICULTY_ORDER[nextIndex])
    self._browserScrollOffset = 0
    self:RefreshBrowserUIImpl()
end

function LFG:CycleKeyRangePreset()
    local options = self:GetOptions()
    if not options then return end
    local nextIndex = self:GetActiveKeyPresetIndex() + 1
    if nextIndex > #KEY_PRESETS then
        nextIndex = 1
    end
    local preset = KEY_PRESETS[nextIndex]
    if type(options.SetMinKeystone) == "function" then
        options:SetMinKeystone(nil, preset.min)
    end
    if type(options.SetMaxKeystone) == "function" then
        options:SetMaxKeystone(nil, preset.max)
    end
    self._browserScrollOffset = 0
    self:RefreshBrowserUIImpl()
end

function LFG:AdjustMinimumRating(delta)
    local options = self:GetOptions()
    if not options or type(options.SetMinimumRating) ~= "function" then return end
    local current = type(options.GetMinimumRating) == "function" and tonumber(options:GetMinimumRating()) or 0
    current = Clamp((current or 0) + delta, 0, 4000)
    options:SetMinimumRating(nil, current)
    self._browserScrollOffset = 0
    self:RefreshBrowserUIImpl()
end

function LFG:ToggleBrowserFilter(optionGetter, optionSetter)
    local options = self:GetOptions()
    if not options or type(options[optionSetter]) ~= "function" then return end
    local current = type(options[optionGetter]) == "function" and options[optionGetter](options) or false
    options[optionSetter](options, nil, not current)
    self._browserScrollOffset = 0
    self:RefreshBrowserUIImpl()
end

local ROLE_LABEL = { TANK = "[T]", HEALER = "[H]", DAMAGER = "[D]" }
local ROLE_COLOR = {
    TANK    = { 0.00, 0.44, 0.87 },
    HEALER  = { 0.27, 0.78, 0.27 },
    DAMAGER = { 0.77, 0.12, 0.23 },
}

local function GetClassColor(classFile)
    local RAID_CLASS_COLORS = _G.RAID_CLASS_COLORS
    if RAID_CLASS_COLORS and classFile then
        local c = RAID_CLASS_COLORS[classFile:upper()]
        if c then
            return c.r or 1, c.g or 1, c.b or 1
        end
    end
    return 0.82, 0.82, 0.82
end

-- Builds an inline |T...:|t icon escape for the class icon atlas or class-create texture.
local CLASS_ICON_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local CLASS_ICON_SIZE = 256
local function GetClassIconEscape(classFile, size)
    size = size or 16
    local tcoords = _G.CLASS_ICON_TCOORDS and classFile and _G.CLASS_ICON_TCOORDS[classFile:upper()]
    if not tcoords then
        return ""
    end
    -- tcoords = { left, right, top, bottom } in 0-1, texture is CLASS_ICON_SIZE x CLASS_ICON_SIZE
    local left   = floor(tcoords[1] * CLASS_ICON_SIZE)
    local right  = floor(tcoords[2] * CLASS_ICON_SIZE)
    local top    = floor(tcoords[3] * CLASS_ICON_SIZE)
    local bottom = floor(tcoords[4] * CLASS_ICON_SIZE)
    return format("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t",
        CLASS_ICON_TEXTURE, size, size,
        CLASS_ICON_SIZE, CLASS_ICON_SIZE,
        left, right, top, bottom)
end

local function GetPlayerMythicScore(playerName)
    if not _G.C_PlayerInfo or not _G.C_PlayerInfo.GetPlayerMythicPlusRatingSummary then
        return nil
    end
    local ok, summary = pcall(_G.C_PlayerInfo.GetPlayerMythicPlusRatingSummary, playerName)
    if ok and type(summary) == "table" and tonumber(summary.currentSeasonScore) then
        return tonumber(summary.currentSeasonScore)
    end
    return nil
end

function LFG:BuildBrowserTooltip(result, owner)
    if not result or not GameTooltip then return end

    GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
    GameTooltip:SetText(GetTitleText(result), 1, 1, 1)
    GameTooltip:AddLine(GetActivityText(result), GetModeColor(result))
    GameTooltip:AddLine(GetMetaText(result), 0.82, 0.82, 0.82)

    if result.rating and result.rating > 0 then
        local r, g, b = GetRatingColor(result.rating)
        GameTooltip:AddLine(format("Group Rating: %d", result.rating), r, g, b)
    end
    if result.keyLevel and result.keyLevel > 0 then
        GameTooltip:AddLine(format("Key Level: +%d", result.keyLevel), 0.78, 0.92, 0.98)
    end

    -- Per-player breakdown
    local players = result.players or {}
    if #players > 0 then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Members:", 1, 0.9, 0.5)

        -- Sort: tank first, then healer, then dps
        local sorted = {}
        for _, p in ipairs(players) do sorted[#sorted + 1] = p end
        local ORDER = { TANK = 1, HEALER = 2, DAMAGER = 3 }
        table.sort(sorted, function(a, b)
            return (ORDER[a.role] or 9) < (ORDER[b.role] or 9)
        end)

        for _, player in ipairs(sorted) do
            local role = player.role or "DAMAGER"
            local roleLabel = ROLE_LABEL[role] or "[?]"
            local rc = ROLE_COLOR[role] or { 0.7, 0.7, 0.7 }
            local cr, cg, cb = GetClassColor(player.class)

            local nameStr = player.name or "Unknown"
            local specStr = player.specName and player.specName ~= "" and (" " .. player.specName) or ""
            local classStr = player.class and player.class ~= "" and
                (" " .. player.class:sub(1, 1):upper() .. player.class:sub(2):lower()) or ""

            -- Attempt per-player mythic score lookup
            local score = player.name and GetPlayerMythicScore(player.name) or nil
            local scoreStr = ""
            if score and score > 0 then
                local sr, sg, sb = GetRatingColor(score)
                scoreStr = format("  |  \124cff%02x%02x%02x%d\124r", floor(sr * 255), floor(sg * 255), floor(sb * 255),
                    score)
            end

            GameTooltip:AddDoubleLine(
                format("%s\124cff%02x%02x%02x%s\124r \124cff%02x%02x%02x%s\124r",
                    GetClassIconEscape(player.class, 16),
                    floor(rc[1] * 255), floor(rc[2] * 255), floor(rc[3] * 255), roleLabel,
                    floor(cr * 255), floor(cg * 255), floor(cb * 255), nameStr
                ),
                format("\124cffaaaaaa%s%s\124r%s", specStr ~= "" and specStr:sub(2) or "", classStr, scoreStr),
                1, 1, 1,
                0.72, 0.72, 0.72
            )
        end
    else
        local roleCounts = result.roleCounts or {}
        GameTooltip:AddLine(format("Group: %dT %dH %dD  |  %d/%d players",
            tonumber(roleCounts.TANK) or 0,
            tonumber(roleCounts.HEALER) or 0,
            tonumber(roleCounts.DAMAGER) or 0,
            tonumber(result.numMembers) or 0,
            tonumber(result.maxPlayers) or 0
        ), 0.88, 0.88, 0.88)
    end

    if result.note and result.note ~= "" then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine(result.note, 0.76, 0.76, 0.76, true)
    end

    if result.isApplied then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Already applied to this group.", 0.45, 1.0, 0.45)
    elseif result.isDeclined then
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("This group declined your application.", 1.0, 0.35, 0.35)
    end

    GameTooltip:Show()
end

function LFG:StyleBrowserRow(row, result, isAlt, isHovered)
    local bg = isAlt and { 0.08, 0.09, 0.11 } or { 0.06, 0.07, 0.09 }
    local border = { 0.22, 0.24, 0.28 }

    if result and result.isApplied then
        bg = { 0.10, 0.18, 0.12 }
        border = { 0.28, 0.56, 0.30 }
    elseif result and result.isDeclined then
        bg = { 0.15, 0.08, 0.08 }
        border = { 0.55, 0.22, 0.22 }
    end

    if isHovered then
        bg = { bg[1] * 1.18, bg[2] * 1.18, bg[3] * 1.18 }
        border = { border[1] * 1.15, border[2] * 1.15, border[3] * 1.15 }
    end

    ApplyFrameBackdrop(row, bg[1], bg[2], bg[3], 0.92, border[1], border[2], border[3], 0.88, 1)
end

function LFG:CreateResultRow(parent, index)
    local row = CreateFrame("Button", nil, parent, "BackdropTemplate")
    row:SetSize(LIST_WIDTH, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -((index - 1) * (ROW_HEIGHT + 2)))
    row:RegisterForClicks("LeftButtonUp")

    row.activity = row:CreateFontString(nil, "OVERLAY")
    row.activity:SetPoint("TOPLEFT", row, "TOPLEFT", 8, -6)
    row.activity:SetWidth(150)
    row.activity:SetJustifyH("LEFT")

    row.title = row:CreateFontString(nil, "OVERLAY")
    row.title:SetPoint("TOPLEFT", row, "TOPLEFT", 262, -6)
    row.title:SetWidth(250)
    row.title:SetJustifyH("LEFT")

    row.meta = row:CreateFontString(nil, "OVERLAY")
    row.meta:SetPoint("TOPLEFT", row.title, "BOTTOMLEFT", 0, -2)
    row.meta:SetWidth(250)
    row.meta:SetJustifyH("LEFT")

    row.rating = row:CreateFontString(nil, "OVERLAY")
    row.rating:SetPoint("TOPLEFT", row, "TOPLEFT", 530, -9)
    row.rating:SetWidth(74)
    row.rating:SetJustifyH("CENTER")

    row.age = row:CreateFontString(nil, "OVERLAY")
    row.age:SetPoint("TOPLEFT", row, "TOPLEFT", 606, -9)
    row.age:SetWidth(54)
    row.age:SetJustifyH("CENTER")

    row.note = row:CreateFontString(nil, "OVERLAY")
    row.note:SetPoint("TOPLEFT", row, "TOPLEFT", 668, -9)
    row.note:SetWidth(132)
    row.note:SetJustifyH("LEFT")

    row.roleSlots = {}
    for slotIndex = 1, 5 do
        local slot = CreateFrame("Frame", nil, row, "BackdropTemplate")
        slot:SetSize(18, 18)
        slot:SetPoint("TOPLEFT", row, "TOPLEFT", 164 + ((slotIndex - 1) * 18), -8)
        slot.icon = slot:CreateTexture(nil, "ARTWORK")
        slot.icon:SetAllPoints()
        slot.icon:SetTexture(ROLE_TEXTURE)
        slot.icon:SetTexCoord(GetRoleCoords("DAMAGER"))
        slot.bg = slot:CreateTexture(nil, "BACKGROUND")
        slot.bg:SetAllPoints()
        slot.bg:SetColorTexture(0, 0, 0, 0.35)
        row.roleSlots[slotIndex] = slot
    end

    row.applyBtn = CreateFrame("Button", nil, row, "BackdropTemplate")
    row.applyBtn:SetSize(58, 22)
    row.applyBtn:SetPoint("RIGHT", row, "RIGHT", -6, 0)
    do
        local fs = row.applyBtn:CreateFontString(nil, "OVERLAY")
        fs:SetAllPoints()
        fs:SetJustifyH("CENTER")
        fs:SetFont(STANDARD_TEXT_FONT, 10, "")
        row.applyBtn:SetFontString(fs)
    end
    row.applyBtn:SetScript("OnClick", function()
        if row.result and not row.result.isApplied then
            LFG:ApplyToGroup(row.result)
        end
    end)
    row.applyBtn:SetScript("OnEnter", function(btn)
        if not btn.isApplied then
            LFG:ApplyApplyButtonStyle(btn, false, true)
        end
    end)
    row.applyBtn:SetScript("OnLeave", function(btn)
        LFG:ApplyApplyButtonStyle(btn, btn.isApplied == true, false)
    end)

    row:SetScript("OnEnter", function(button)
        if button.result then
            LFG:BuildBrowserTooltip(button.result, button)
            button._hovered = true
            LFG:StyleBrowserRow(button, button.result, button._altShade, true)
        end
    end)
    row:SetScript("OnLeave", function(button)
        button._hovered = false
        if GameTooltip then
            GameTooltip:Hide()
        end
        LFG:StyleBrowserRow(button, button.result, button._altShade, false)
    end)

    return row
end

function LFG:PopulateBrowserRow(row, result, isAlt)
    row.result = result
    row._altShade = isAlt

    if not result then
        row:Hide()
        return
    end

    local modeR, modeG, modeB = GetModeColor(result)
    local ratingR, ratingG, ratingB = GetRatingColor(result.rating)

    ApplyThemeFontString(self, row.activity, 11, modeR, modeG, modeB)
    ApplyThemeFontString(self, row.title, 11, 0.96, 0.96, 0.96)
    ApplyThemeFontString(self, row.meta, 9, 0.70, 0.73, 0.78)
    ApplyThemeFontString(self, row.rating, 11, ratingR, ratingG, ratingB)
    ApplyThemeFontString(self, row.age, 10, 0.80, 0.82, 0.86)
    ApplyThemeFontString(self, row.note, 10, 0.72, 0.72, 0.72)

    row.activity:SetText(TrimText(GetActivityText(result), 22))
    row.title:SetText(TrimText(GetTitleText(result), 40))
    row.meta:SetText(TrimText(GetMetaText(result), 42))
    row.rating:SetText(result.rating and result.rating > 0 and format("%d", result.rating) or "--")
    row.age:SetText(self:FormatAge(result.age or 0))
    row.note:SetText(TrimText(result.note or "", 28))

    local slots = BuildRoleLayout(result)
    for index, slot in ipairs(row.roleSlots) do
        local player = slots[index]
        local role = player and player.role or ROLE_ORDER[index]
        slot.icon:SetTexCoord(GetRoleCoords(role))
        if player then
            slot.icon:SetVertexColor(1, 1, 1, 1)
            slot.bg:SetColorTexture(0.10, 0.10, 0.10, 0.35)
        else
            slot.icon:SetVertexColor(0.38, 0.38, 0.38, 0.35)
            slot.bg:SetColorTexture(0.02, 0.02, 0.02, 0.40)
        end
    end

    if result.isApplied then
        row.applyBtn.isApplied = true
        row.applyBtn:SetText("Applied")
        row.applyBtn:Disable()
        self:ApplyApplyButtonStyle(row.applyBtn, true, false)
    else
        row.applyBtn.isApplied = false
        row.applyBtn:SetText("Apply")
        row.applyBtn:Enable()
        self:ApplyApplyButtonStyle(row.applyBtn, false, false)
    end

    self:StyleBrowserRow(row, result, isAlt, row._hovered == true)
    row:Show()
end

function LFG:GetVisibleBrowserResults()
    local filteredResults = {}
    for _, result in ipairs(self.searchResults or {}) do
        if self:ResultPassesFilters(result) then
            filteredResults[#filteredResults + 1] = result
        end
    end
    return filteredResults
end

function LFG:UpdateBrowserSlider(filteredCount)
    if not self.browserSlider then
        return
    end

    local maxOffset = max(0, filteredCount - ROWS_VISIBLE)
    self._browserScrollOffset = Clamp(self._browserScrollOffset or 0, 0, maxOffset)

    self._ignoreBrowserSlider = true
    self.browserSlider:SetMinMaxValues(0, maxOffset)
    self.browserSlider:SetValue(self._browserScrollOffset)
    self._ignoreBrowserSlider = false

    local disabled = maxOffset <= 0
    self.browserSlider:SetEnabled(not disabled)
    self.browserSlider.thumb:SetAlpha(disabled and 0.35 or 1)
    self.browserSlider.track:SetAlpha(disabled and 0.28 or 0.65)
end

function LFG:RefreshFilterControls()
    if not self.filterButtons then
        return
    end

    local filters = self:GetActiveFilters()
    self.filterButtons.difficulty:SetText("Mode: " .. (DIFFICULTY_LABELS[filters.difficulty] or "Any"))
    self.filterButtons.keyRange:SetText("Keys: " .. KEY_PRESETS[self:GetActiveKeyPresetIndex()].label)
    self.filterButtons.rating:SetText(format("Score: %d+", tonumber(filters.minimumRating) or 0))
    self.filterButtons.tank:SetText("Tank")
    self.filterButtons.healer:SetText("Healer")
    self.filterButtons.dps:SetText("DPS")
    self.filterButtons.declined:SetText("Hide Declined")

    self:ApplyThemeButton(self.filterButtons.difficulty, false, false)
    self:ApplyThemeButton(self.filterButtons.keyRange, false, false)
    self:ApplyThemeButton(self.filterButtons.ratingDown, false, false)
    self:ApplyThemeButton(self.filterButtons.rating, false, false)
    self:ApplyThemeButton(self.filterButtons.ratingUp, false, false)
    self:ApplyThemeButton(self.filterButtons.refresh, false, false)
    self:ApplyThemeButton(self.filterButtons.tank, filters.needsTank == true, false)
    self:ApplyThemeButton(self.filterButtons.healer, filters.needsHealer == true, false)
    self:ApplyThemeButton(self.filterButtons.dps, filters.needsDPS == true, false)
    self:ApplyThemeButton(self.filterButtons.declined, filters.hideDeclined == true, false)
end

function LFG:RefreshBrowserUIImpl()
    if not self.rowPool then return end

    local filteredResults = self:GetVisibleBrowserResults()
    self:RefreshFilterControls()
    self:UpdateBrowserSlider(#filteredResults)

    local startIndex = (self._browserScrollOffset or 0) + 1
    for rowIndex, row in ipairs(self.rowPool) do
        local result = filteredResults[startIndex + rowIndex - 1]
        self:PopulateBrowserRow(row, result, rowIndex % 2 == 0)
    end

    if self.footerText then
        self.footerText:SetFormattedText("Showing %d of %d groups", #filteredResults, #(self.searchResults or {}))
    end
    if self.subtitleText then
        self.subtitleText:SetText("Oak-style browser: activity, comp, title, rating, age, notes")
    end
end

function LFG:SetLoadingProgressImpl(processed, total)
    if not self.loadingContainer or not self.loadingBar or not self.loadingText then
        return
    end

    processed = tonumber(processed) or 0
    total = tonumber(total) or 0

    if total <= 0 or processed >= total then
        self.loadingContainer:Hide()
        return
    end

    self.loadingContainer:Show()
    self.loadingBar:SetMinMaxValues(0, total)
    self.loadingBar:SetValue(processed)
    self.loadingText:SetFormattedText("Loading groups %d/%d", processed, total)
end

function LFG:RefreshFrameAppearanceImpl()
    if not self.mainFrame then return end

    self:ApplyThemeBackdrop(self.mainFrame)
    self:ApplyThemeTitleBar(self.titleBar)
    self:ApplyThemePanel(self.filterBar)
    self:ApplyThemePanel(self.headerBar)
    self:ApplyThemePanel(self.listFrame)

    local primaryR, primaryG, primaryB = self:GetThemeColor("primaryColor", { 0.10, 0.72, 0.74 })
    ApplyThemeFontString(self, self.titleText, 13, 1, 0.98, 0.92)
    ApplyThemeFontString(self, self.subtitleText, 10, 0.80, 0.84, 0.88)
    ApplyThemeFontString(self, self.footerText, 10, 0.76, 0.79, 0.84)

    for _, header in ipairs(self.headerButtons or {}) do
        ApplyFrameBackdrop(header, 0.10, 0.11, 0.13, 0.42, primaryR * 0.65, primaryG * 0.65, primaryB * 0.65, 0.55, 1)
        ApplyThemeFontString(self, header.text, 10, primaryR, primaryG, primaryB)
    end

    if self.browserSlider then
        self.browserSlider.track:SetColorTexture(0.12, 0.14, 0.17, 0.65)
        self.browserSlider.thumb:SetColorTexture(primaryR, primaryG, primaryB, 0.95)
    end

    if self.loadingContainer and self.loadingBar and self.loadingText then
        ApplyFrameBackdrop(self.loadingContainer, 0.08, 0.09, 0.11, 0.72, primaryR * 0.35, primaryG * 0.35,
            primaryB * 0.35, 0.65, 1)
        self.loadingBar:SetStatusBarColor(primaryR, primaryG, primaryB, 0.95)
        ApplyThemeFontString(self, self.loadingText, 9, 0.90, 0.92, 0.95)
    end

    self:RefreshFilterControls()
    self:RefreshBrowserUIImpl()
end

function LFG:CreateMainFrameImpl()
    if self.mainFrame then
        return
    end

    local anchor = _G.LFGListFrame or UIParent
    local frame = CreateFrame("Frame", "TwichLFGFinder", UIParent, "BackdropTemplate")
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 4, 0)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("DIALOG")
    frame:Hide()

    _G.TwichLFGFinder = frame
    if _G.UISpecialFrames then
        _G.tinsert(_G.UISpecialFrames, "TwichLFGFinder")
    end

    frame:SetScript("OnMouseDown", function(f, button)
        if button == "LeftButton" then
            f:StartMoving()
        end
    end)
    frame:SetScript("OnMouseUp", function(f)
        f:StopMovingOrSizing()
    end)

    self:ApplyThemeBackdrop(frame)

    local titleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    titleBar:SetSize(FRAME_WIDTH - 4, TITLE_HEIGHT)
    titleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 2, -2)
    self:ApplyThemeTitleBar(titleBar)

    local titleText = titleBar:CreateFontString(nil, "OVERLAY")
    titleText:SetPoint("LEFT", titleBar, "LEFT", 10, 0)
    ApplyThemeFontString(self, titleText, 13, 1, 0.98, 0.92)
    titleText:SetText("LFG Finder")

    local subtitleText = titleBar:CreateFontString(nil, "OVERLAY")
    subtitleText:SetPoint("LEFT", titleText, "RIGHT", 12, 0)
    ApplyThemeFontString(self, subtitleText, 10, 0.80, 0.84, 0.88)
    subtitleText:SetText("Compact browser")

    local loadingContainer = CreateFrame("Frame", nil, titleBar, "BackdropTemplate")
    loadingContainer:SetSize(210, 14)
    loadingContainer:SetPoint("RIGHT", titleBar, "RIGHT", -212, 0)
    loadingContainer:Hide()

    local loadingBar = CreateFrame("StatusBar", nil, loadingContainer)
    loadingBar:SetPoint("TOPLEFT", loadingContainer, "TOPLEFT", 1, -1)
    loadingBar:SetPoint("BOTTOMRIGHT", loadingContainer, "BOTTOMRIGHT", -1, 1)
    loadingBar:SetStatusBarTexture("Interface\\Buttons\\WHITE8x8")
    loadingBar:SetMinMaxValues(0, 1)
    loadingBar:SetValue(0)

    local loadingText = loadingContainer:CreateFontString(nil, "OVERLAY")
    loadingText:SetPoint("CENTER", loadingContainer, "CENTER", 0, 0)
    ApplyThemeFontString(self, loadingText, 9, 0.90, 0.92, 0.95)
    loadingText:SetText("Loading groups")

    local applicantBtn = self:CreateBrowserButton(titleBar, 96, "Applicants", function()
        LFG:SwitchMode("applicant")
    end)
    applicantBtn:SetPoint("RIGHT", titleBar, "RIGHT", -8, 0)

    local browserBtn = self:CreateBrowserButton(titleBar, 96, "Browse", function()
        LFG:SwitchMode("browser")
    end)
    browserBtn:SetPoint("RIGHT", applicantBtn, "LEFT", -6, 0)
    self:ApplyThemeButton(browserBtn, true, false)

    local filterBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    filterBar:SetSize(FRAME_WIDTH - 20, FILTER_HEIGHT)
    filterBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -(TITLE_HEIGHT + 8))
    self:ApplyThemePanel(filterBar)

    local difficultyBtn = self:CreateBrowserButton(filterBar, 86, "Mode", function()
        LFG:CycleDifficultyFilter()
    end)
    difficultyBtn:SetPoint("LEFT", filterBar, "LEFT", 6, 0)

    local keyRangeBtn = self:CreateBrowserButton(filterBar, 96, "Keys", function()
        LFG:CycleKeyRangePreset()
    end)
    keyRangeBtn:SetPoint("LEFT", difficultyBtn, "RIGHT", 6, 0)

    local ratingDown = self:CreateBrowserButton(filterBar, 22, "-", function()
        LFG:AdjustMinimumRating(-250)
    end)
    ratingDown:SetPoint("LEFT", keyRangeBtn, "RIGHT", 6, 0)

    local ratingBtn = self:CreateBrowserButton(filterBar, 96, "Score", function()
        LFG:AdjustMinimumRating(0 - (tonumber(LFG:GetActiveFilters().minimumRating) or 0))
    end)
    ratingBtn:SetPoint("LEFT", ratingDown, "RIGHT", 2, 0)

    local ratingUp = self:CreateBrowserButton(filterBar, 22, "+", function()
        LFG:AdjustMinimumRating(250)
    end)
    ratingUp:SetPoint("LEFT", ratingBtn, "RIGHT", 2, 0)

    local tankBtn = self:CreateBrowserButton(filterBar, 54, "Tank", function()
        LFG:ToggleBrowserFilter("GetNeedsTank", "SetNeedsTank")
    end)
    tankBtn:SetPoint("LEFT", ratingUp, "RIGHT", 8, 0)

    local healerBtn = self:CreateBrowserButton(filterBar, 58, "Healer", function()
        LFG:ToggleBrowserFilter("GetNeedsHealer", "SetNeedsHealer")
    end)
    healerBtn:SetPoint("LEFT", tankBtn, "RIGHT", 4, 0)

    local dpsBtn = self:CreateBrowserButton(filterBar, 48, "DPS", function()
        LFG:ToggleBrowserFilter("GetNeedsDPS", "SetNeedsDPS")
    end)
    dpsBtn:SetPoint("LEFT", healerBtn, "RIGHT", 4, 0)

    local declinedBtn = self:CreateBrowserButton(filterBar, 108, "Hide Declined", function()
        LFG:ToggleBrowserFilter("GetHideDeclined", "SetHideDeclined")
    end)
    declinedBtn:SetPoint("LEFT", dpsBtn, "RIGHT", 8, 0)

    local refreshBtn = self:CreateBrowserButton(filterBar, 68, "Refresh", function()
        LFG:RefreshSearchResults(true)
    end)
    refreshBtn:SetPoint("RIGHT", filterBar, "RIGHT", -6, 0)

    local headerBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    headerBar:SetSize(FRAME_WIDTH - 20, HEADER_HEIGHT)
    headerBar:SetPoint("TOPLEFT", filterBar, "BOTTOMLEFT", 0, -6)
    self:ApplyThemePanel(headerBar)

    local headerButtons = {
        CreateColumnHeader(headerBar, "Activity", 150, 8, function() LFG:SetSortState("dungeon") end),
        CreateColumnHeader(headerBar, "Comp", 92, 164, function() LFG:SetSortState("composition") end),
        CreateColumnHeader(headerBar, "Title", 250, 262, function() LFG:SetSortState("title") end),
        CreateColumnHeader(headerBar, "Rating", 72, 530, function() LFG:SetSortState("rating") end),
        CreateColumnHeader(headerBar, "Age", 54, 606, function() LFG:SetSortState("age") end),
        CreateColumnHeader(headerBar, "Note", 130, 668, function() LFG:SetSortState("note") end),
    }

    local listFrame = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    listFrame:SetSize(FRAME_WIDTH - 20, (ROWS_VISIBLE * (ROW_HEIGHT + 2)) + 8)
    listFrame:SetPoint("TOPLEFT", headerBar, "BOTTOMLEFT", 0, -4)
    self:ApplyThemePanel(listFrame)

    local rowsParent = CreateFrame("Frame", nil, listFrame)
    rowsParent:SetSize(LIST_WIDTH, listFrame:GetHeight() - 8)
    rowsParent:SetPoint("TOPLEFT", listFrame, "TOPLEFT", 4, -4)

    local rowPool = {}
    for index = 1, ROWS_VISIBLE do
        rowPool[index] = self:CreateResultRow(rowsParent, index)
    end

    local browserSlider = CreateFrame("Slider", nil, listFrame)
    browserSlider:SetPoint("TOPRIGHT", listFrame, "TOPRIGHT", -6, -6)
    browserSlider:SetPoint("BOTTOMRIGHT", listFrame, "BOTTOMRIGHT", -6, 6)
    browserSlider:SetOrientation("VERTICAL")
    browserSlider:SetWidth(SCROLLBAR_WIDTH)
    browserSlider:SetMinMaxValues(0, 0)
    browserSlider:SetValueStep(1)
    browserSlider:SetObeyStepOnDrag(true)
    browserSlider.track = browserSlider:CreateTexture(nil, "BACKGROUND")
    browserSlider.track:SetAllPoints()
    browserSlider.thumb = browserSlider:CreateTexture(nil, "ARTWORK")
    browserSlider.thumb:SetSize(SCROLLBAR_WIDTH, 42)
    browserSlider:SetThumbTexture(browserSlider.thumb)
    browserSlider:SetScript("OnValueChanged", function(_, value)
        if LFG._ignoreBrowserSlider then
            return
        end
        local stepped = floor((value or 0) + 0.5)
        if stepped ~= (LFG._browserScrollOffset or 0) then
            LFG._browserScrollOffset = stepped
            LFG:RefreshBrowserUIImpl()
        end
    end)
    listFrame:EnableMouseWheel(true)
    listFrame:SetScript("OnMouseWheel", function(_, delta)
        local minValue, maxValue = browserSlider:GetMinMaxValues()
        if maxValue <= 0 then
            return
        end
        local nextValue = Clamp((LFG._browserScrollOffset or 0) - delta, minValue, maxValue)
        browserSlider:SetValue(nextValue)
    end)

    local footerText = frame:CreateFontString(nil, "OVERLAY")
    footerText:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 8)
    ApplyThemeFontString(self, footerText, 10, 0.76, 0.79, 0.84)
    footerText:SetText("Showing 0 of 0 groups")

    self.mainFrame = frame
    self.titleBar = titleBar
    self.titleText = titleText
    self.subtitleText = subtitleText
    self.loadingContainer = loadingContainer
    self.loadingBar = loadingBar
    self.loadingText = loadingText
    self.filterBar = filterBar
    self.headerBar = headerBar
    self.headerButtons = headerButtons
    self.listFrame = listFrame
    self.rowsParent = rowsParent
    self.rowPool = rowPool
    self.browserSlider = browserSlider
    self.footerText = footerText
    self.browserBtn = browserBtn
    self.applicantBtn = applicantBtn
    self.filterButtons = {
        difficulty = difficultyBtn,
        keyRange = keyRangeBtn,
        ratingDown = ratingDown,
        rating = ratingBtn,
        ratingUp = ratingUp,
        tank = tankBtn,
        healer = healerBtn,
        dps = dpsBtn,
        declined = declinedBtn,
        refresh = refreshBtn,
    }
    self._browserScrollOffset = 0

    self:RefreshFrameAppearanceImpl()
    self:RefreshBrowserUIImpl()
end

function LFG:FormatComposition(roleCounts)
    local t = roleCounts.TANK or 0
    local h = roleCounts.HEALER or 0
    local d = roleCounts.DAMAGER or 0
    return format("%dT %dH %dD", t, h, d)
end

function LFG:FormatAge(ageSeconds)
    if ageSeconds < 60 then
        return "now"
    elseif ageSeconds < 3600 then
        return format("%dm", floor(ageSeconds / 60))
    elseif ageSeconds < 86400 then
        return format("%dh", floor(ageSeconds / 3600))
    else
        return format("%dd", floor(ageSeconds / 86400))
    end
end

function LFG:ApplyToGroup(result)
    if not result then return end
    C_LFGList.ApplyToGroup(result.id)
end
