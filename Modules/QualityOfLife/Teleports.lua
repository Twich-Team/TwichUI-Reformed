---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class TeleportsModule : AceModule
---@field worldMapButton Button|nil
---@field worldMapPanel Frame|nil
---@field datatextPopup Frame|nil
---@field worldMapInitialized boolean|nil
---@field refreshQueued boolean|nil
local Teleports = QOL:NewModule("Teleports", "AceEvent-3.0")

local PLAYER_CLASS = select(2, UnitClass("player"))
local PLAYER_RACE = select(2, UnitRace("player"))
local PLAYER_FACTION = UnitFactionGroup("player")

local CURRENT_SEASON_DUNGEONS = {
    { spellID = 393273,  name = "Algeth'ar Academy" },
    { spellID = 1254559, name = "Maisara Caverns" },
    { spellID = 1254572, name = "Magisters' Terrace" },
    { spellID = 1254563, name = "Nexus-Point Xenas" },
    { spellID = 1254555, name = "Pit of Saron" },
    { spellID = 1254551, name = "Seat of the Triumvirate" },
    { spellID = 1254557, name = "Skyreach" },
    { spellID = 1254400, name = "Windrunner Spire" },
}

local RAID_TELEPORTS = {
    { spellID = 373190,  name = "Castle Nathria" },
    { spellID = 373191,  name = "Sanctum of Domination" },
    { spellID = 373192,  name = "Sepulcher of the First Ones" },
    { spellID = 432254,  name = "Vault of the Incarnates" },
    { spellID = 432257,  name = "Aberrus, the Shadowed Crucible" },
    { spellID = 432258,  name = "Amirdrassil, the Dream's Hope" },
    { spellID = 1226482, name = "Liberation of Undermine" },
    { spellID = 1239155, name = "Manaforge Omega" },
}

local CURRENT_CONTENT_RAID_TELEPORTS = {
    { spellID = 1226482, name = "Liberation of Undermine" },
}

local HEARTHSTONE_ENTRIES = {
    { itemID = 6948,   name = "Hearthstone" },
    { itemID = 140192, name = "Dalaran Hearthstone" },
    { itemID = 110560, name = "Garrison Hearthstone" },
}

local OTHER_ITEM_ENTRIES = {
    { itemID = 253629, name = "Personal Key to the Arcantina" },
}

local MAGE_TELEPORTS_ALLIANCE = {
    3561, 3562, 3565, 32271, 33690, 49359, 53140, 88342, 132621, 176248, 193759, 224869, 281403, 344587,
    395277, 446540, 1259190,
}

local MAGE_TELEPORTS_HORDE = {
    3567, 3563, 3566, 32272, 35715, 49358, 53140, 88344, 132627, 176242, 193759, 224869, 281404, 344587,
    395277, 446540, 1259190,
}

local MAGE_PORTALS_ALLIANCE = {
    10059, 11416, 11419, 32266, 49360, 33691, 53142, 88345, 120146, 132620, 176246, 224871, 281400, 344597,
    395289, 446534, 1259194,
}

local MAGE_PORTALS_HORDE = {
    11417, 11418, 11420, 32267, 49361, 35717, 53142, 88346, 132626, 176244, 224871, 281402, 344597, 395289,
    446534, 1259194,
}

local UTILITY_SPELLS = {
    DRUID = { 18960, 193753 },
    DEATHKNIGHT = { 50977 },
    MONK = { 126892 },
    SHAMAN = { 556 },
}

local RACIAL_SPELLS = {
    Vulpera = { 312370, 312372 },
    DarkIronDwarf = { 265225 },
    Haranir = { 1238686 },
}

local NormalizeSpellEntry

local function GetOptions()
    return T:GetModule("Configuration").Options.Teleports
end

local function GetDatatextOptions()
    return T:GetModule("Configuration").Options.Datatext
end

local function GetSpellInfoSafe(spellID)
    if not spellID or not C_Spell or not C_Spell.GetSpellInfo then
        return nil
    end

    return C_Spell.GetSpellInfo(spellID)
end

local function GetSpellName(spellID, fallback)
    local info = GetSpellInfoSafe(spellID)
    return (info and info.name) or fallback
end

local function GetSpellIcon(spellID)
    local info = GetSpellInfoSafe(spellID)
    return (info and info.iconID) or 134400
end

local function GetItemName(itemID, fallback)
    if not itemID then
        return fallback
    end

    if C_ToyBox and C_ToyBox.GetToyInfo then
        local _, toyName = C_ToyBox.GetToyInfo(itemID)
        if toyName then
            return toyName
        end
    end

    if C_Item and C_Item.GetItemNameByID then
        local itemName = C_Item.GetItemNameByID(itemID)
        if itemName and itemName ~= "" then
            return itemName
        end
    end

    local itemName = GetItemInfo(itemID)
    if itemName and itemName ~= "" then
        return itemName
    end

    return fallback
end

local function GetItemIcon(itemID)
    if not itemID or not C_Item or not C_Item.GetItemInfoInstant then
        return 134400
    end

    local _, _, _, _, icon = C_Item.GetItemInfoInstant(itemID)
    return icon or 134400
end

local function IsSpellKnownSafe(spellID)
    if not spellID then
        return false
    end

    if C_Spell and C_Spell.IsSpellKnown and C_Spell.IsSpellKnown(spellID) then
        return true
    end

    if C_SpellBook and C_SpellBook.IsSpellInSpellBook then
        return C_SpellBook.IsSpellInSpellBook(spellID)
    end

    return false
end

local function IsItemOwned(itemID)
    if not itemID then
        return false
    end

    if C_ToyBox and C_ToyBox.GetToyInfo and C_ToyBox.GetToyInfo(itemID) then
        return PlayerHasToy and PlayerHasToy(itemID) or false
    end

    if C_Item and C_Item.GetItemCount then
        return (C_Item.GetItemCount(itemID) or 0) > 0
    end

    return false
end

local function FormatCooldown(seconds)
    if not seconds or seconds <= 0 then
        return ""
    end

    if seconds >= 3600 then
        return string.format("%dh", math.floor(seconds / 3600))
    end

    if seconds >= 60 then
        return string.format("%dm", math.floor(seconds / 60))
    end

    return string.format("%ds", math.floor(seconds))
end

local function GetEntryCooldown(entry)
    if not entry then
        return 0
    end

    local startTime, duration, isEnabled

    if entry.spellID and C_Spell and C_Spell.GetSpellCooldown then
        local info = C_Spell.GetSpellCooldown(entry.spellID)
        if info then
            startTime = info.startTime
            duration = info.duration
            isEnabled = info.isEnabled
        end
    elseif entry.itemID and C_Item and C_Item.GetItemCooldown then
        startTime, duration, isEnabled = C_Item.GetItemCooldown(entry.itemID)
    end

    if not duration or duration <= 1.5 or isEnabled == false then
        return 0
    end

    -- startTime from C_Spell.GetSpellCooldown is a "secret" value that carries Blizzard
    -- taint.  Comparing it directly (e.g. startTime <= 0) propagates the taint into our
    -- addon and causes a Lua error.  Use pcall for both the guard check and the remaining-
    -- time calculation so that if the value is tainted the operation silently returns 0
    -- rather than erroring and halting the frame render.
    local ok, remaining = pcall(function()
        if not startTime or startTime <= 0 then
            return 0
        end
        return math.max(0, (startTime + duration) - GetTime())
    end)
    if not ok then
        return 0
    end
    return remaining
end

local function GetEntryStatus(entry)
    if not entry.known then
        return "Unavailable"
    end

    local cooldown = GetEntryCooldown(entry)
    if cooldown > 0 then
        return FormatCooldown(cooldown)
    end

    return ""
end

local function GetBackdropColors()
    local bgR, bgG, bgB, bgA = 0.06, 0.06, 0.08, 0.98
    local borderR, borderG, borderB = 0.25, 0.25, 0.3
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.media then
        if E.media.backdropcolor then
            bgR, bgG, bgB = unpack(E.media.backdropcolor)
        elseif E.media.backdropfadecolor then
            bgR, bgG, bgB = unpack(E.media.backdropfadecolor)
        end

        if E.media.bordercolor then
            borderR, borderG, borderB = unpack(E.media.bordercolor)
        end
    end

    return bgR, bgG, bgB, bgA, borderR, borderG, borderB
end

local function CreateBackdrop(frame)
    if frame.backdropApplied then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        tile = false,
        tileSize = 0,
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    local bgR, bgG, bgB, bgA, borderR, borderG, borderB = GetBackdropColors()

    frame:SetBackdropColor(bgR, bgG, bgB, bgA)
    frame:SetBackdropBorderColor(borderR, borderG, borderB, 1)

    frame.BackgroundFill = frame:CreateTexture(nil, "BACKGROUND", nil, -1)
    frame.BackgroundFill:SetAllPoints(frame)
    frame.BackgroundFill:SetColorTexture(bgR, bgG, bgB, math.min(1, math.max(bgA, 0.96)))

    frame.InnerGlow = frame:CreateTexture(nil, "BORDER")
    frame.InnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.InnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.InnerGlow:SetColorTexture(borderR, borderG, borderB, 0.08)
    frame.backdropApplied = true
end

local ApplyWorldMapTabIconLayout

local function RefreshWorldMapTabIcon(button)
    if not button or not button.Icon then
        return
    end

    button.Icon:SetTexture(GetSpellIcon(10059))
    if ApplyWorldMapTabIconLayout then
        ApplyWorldMapTabIconLayout(button)
    end
end

local function SkinCloseButton(button)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinCloseButton then
        UI.SkinCloseButton(button)
    end
end

local function SkinScrollBar(scrollFrame)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinScrollBar then
        UI.SkinScrollBar(scrollFrame)
    end
end

local function ApplyWorldMapTabSkin(button)
    local UI = T.Tools and T.Tools.UI
    local skins = UI and UI.GetElvUISkins and UI.GetElvUISkins()
    if not skins then
        return
    end

    if skins.HandleTab then
        pcall(skins.HandleTab, skins, button)
    elseif skins.HandleButton then
        pcall(skins.HandleButton, skins, button)
    end

    if not button.twichCheckedHighlight then
        local checkedHighlight = button:CreateTexture(nil, "OVERLAY")
        checkedHighlight:SetDrawLayer("BACKGROUND", 0)
        checkedHighlight:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -2)
        checkedHighlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
        checkedHighlight:SetColorTexture(1, 0.82, 0, 0.25)
        checkedHighlight:Hide()
        button.twichCheckedHighlight = checkedHighlight

        local function UpdateCheckedHighlight(checked)
            local isChecked = checked
            if isChecked == nil and button.GetChecked then
                isChecked = button:GetChecked()
            end

            if isChecked then
                button.twichCheckedHighlight:Show()
            else
                button.twichCheckedHighlight:Hide()
            end
        end

        hooksecurefunc(button, "SetChecked", function(_, checked)
            UpdateCheckedHighlight(checked)
            RefreshWorldMapTabIcon(button)
        end)

        button:HookScript("OnShow", function()
            UpdateCheckedHighlight(nil)
            RefreshWorldMapTabIcon(button)
        end)
    end

    if not button.twichHoverHighlight then
        local highlight = button:GetHighlightTexture()
        if not highlight then
            highlight = button:CreateTexture(nil, "HIGHLIGHT")
        end
        highlight:ClearAllPoints()
        highlight:SetPoint("TOPLEFT", button, "TOPLEFT", 4, -2)
        highlight:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -4, 4)
        highlight:SetColorTexture(1, 1, 1, 0.15)
        highlight:SetBlendMode("ADD")
        button:SetHighlightTexture(highlight)
        button.twichHoverHighlight = highlight
    end

    button:SetSize(38, 46)
end

ApplyWorldMapTabIconLayout = function(button)
    if not button or not button.Icon then
        return
    end

    local isSkinned = C_AddOns and C_AddOns.IsAddOnLoaded and
        (C_AddOns.IsAddOnLoaded("ElvUI") or C_AddOns.IsAddOnLoaded("NDui"))
    local offsetX = isSkinned and 0 or -2

    button.Icon:ClearAllPoints()
    button.Icon:SetPoint("CENTER", button, "CENTER", offsetX, 0)
    button.Icon:SetSize(20, 20)
    button.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    button.Icon:SetDrawLayer("ARTWORK")
    button.Icon:Show()
end

local function CreateBrowserFrame(name, parent, width, height, showCloseButton)
    local frame = CreateFrame("Frame", name, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:Hide()
    CreateBackdrop(frame)

    local bgR, bgG, bgB, _, borderR, borderG, borderB = GetBackdropColors()

    frame.TitleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TitleBar:SetHeight(32)
    frame.TitleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 1 },
    })
    frame.TitleBar:SetBackdropColor(bgR * 0.75, bgG * 0.75, bgB * 0.75, 0.98)
    frame.TitleBar:SetBackdropBorderColor(borderR, borderG, borderB, 0.35)

    frame.TitleAccent = frame.TitleBar:CreateTexture(nil, "ARTWORK")
    frame.TitleAccent:SetPoint("TOPLEFT", frame.TitleBar, "TOPLEFT", 0, 0)
    frame.TitleAccent:SetPoint("TOPRIGHT", frame.TitleBar, "TOPRIGHT", 0, 0)
    frame.TitleAccent:SetHeight(2)
    frame.TitleAccent:SetColorTexture(0.96, 0.78, 0.24, 0.95)

    frame.TitleIcon = frame.TitleBar:CreateTexture(nil, "OVERLAY")
    frame.TitleIcon:SetPoint("LEFT", frame.TitleBar, "LEFT", 10, 0)
    frame.TitleIcon:SetSize(16, 16)
    frame.TitleIcon:SetTexture(GetSpellIcon(10059))
    frame.TitleIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    frame.Title:SetPoint("LEFT", frame.TitleIcon, "RIGHT", 8, 0)
    frame.Title:SetPoint("RIGHT", frame.TitleBar, "RIGHT", showCloseButton and -32 or -12, 0)
    frame.Title:SetJustifyH("LEFT")
    frame.Title:SetText("Teleports")
    if frame.Title.SetTextColor then
        frame.Title:SetTextColor(1, 0.94, 0.82)
    end

    if showCloseButton then
        frame.CloseButton = CreateFrame("Button", nil, frame.TitleBar, "UIPanelCloseButton")
        frame.CloseButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -2, 0)
        SkinCloseButton(frame.CloseButton)
        frame.CloseButton:SetScript("OnClick", function() frame:Hide() end)
    end

    frame.EmptyText = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.EmptyText:SetPoint("CENTER", frame, "CENTER", 0, -8)
    frame.EmptyText:SetTextColor(0.75, 0.75, 0.75)
    frame.EmptyText:Hide()

    frame.ContentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -40)
    frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)
    frame.ContentInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.ContentInset:SetBackdropColor(bgR * 0.82, bgG * 0.82, bgB * 0.82, 0.98)
    frame.ContentInset:SetBackdropBorderColor(borderR, borderG, borderB, 0.45)

    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame.ContentInset, "UIPanelScrollFrameTemplate")
    frame.ScrollFrame:SetPoint("TOPLEFT", frame.ContentInset, "TOPLEFT", 8, -8)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame.ContentInset, "BOTTOMRIGHT", -20, 8)
    SkinScrollBar(frame.ScrollFrame)

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ScrollFrame)
    frame.ScrollChild:SetSize(1, 1)
    frame.ScrollFrame:SetScrollChild(frame.ScrollChild)
    frame.ScrollFrame:HookScript("OnSizeChanged", function(scroll)
        local availableWidth = math.max(1, (scroll:GetWidth() or 1) - 8)
        frame.ScrollChild:SetWidth(availableWidth)
    end)

    frame.headers = {}
    frame.rows = {}
    frame.mode = "map"

    return frame
end

local function EnsureHeader(frame, index)
    local header = frame.headers[index]
    if header then
        return header
    end

    header = CreateFrame("Button", nil, frame.ScrollChild, "BackdropTemplate")
    header:SetHeight(24)
    header:SetPoint("LEFT", frame.ScrollChild, "LEFT", 0, 0)
    header:SetPoint("RIGHT", frame.ScrollChild, "RIGHT", 0, 0)
    header:RegisterForClicks("LeftButtonUp")
    header:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    header:SetBackdropColor(0.92, 0.74, 0.18, 0.10)
    header:SetBackdropBorderColor(0.92, 0.74, 0.18, 0.18)

    header.Arrow = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.Arrow:SetPoint("LEFT", header, "LEFT", 8, 0)
    header.Arrow:SetTextColor(1, 0.88, 0.45)

    header.Text = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    header.Text:SetPoint("LEFT", header.Arrow, "RIGHT", 8, 0)
    header.Text:SetPoint("RIGHT", header, "RIGHT", -8, 0)
    header.Text:SetJustifyH("LEFT")
    header.Text:SetTextColor(1, 0.93, 0.82)

    header.Highlight = header:CreateTexture(nil, "HIGHLIGHT")
    header.Highlight:SetAllPoints(header)
    header.Highlight:SetColorTexture(1, 1, 1, 0.05)

    frame.headers[index] = header
    return header
end

local function ConfigureSecureAction(button, entry)
    if InCombatLockdown() then
        return
    end

    button:SetAttribute("type", nil)
    button:SetAttribute("spell", nil)
    button:SetAttribute("macrotext", nil)

    if not entry or not entry.known then
        return
    end

    if entry.spellID then
        button:SetAttribute("type", "spell")
        button:SetAttribute("spell", entry.spellID)
        return
    end

    if entry.itemID then
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", "/use item:" .. tostring(entry.itemID))
    end
end

local function EnsureRow(frame, index)
    local row = frame.rows[index]
    if row then
        return row
    end

    row = CreateFrame("Button", nil, frame.ScrollChild, "SecureActionButtonTemplate")
    row:SetHeight(42)
    row:SetPoint("LEFT", frame.ScrollChild, "LEFT", 0, 0)
    row:SetPoint("RIGHT", frame.ScrollChild, "RIGHT", 0, 0)
    row:RegisterForClicks("AnyUp", "AnyDown")
    row:EnableMouse(true)

    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(1, 1, 1, 0.025)

    row.inner = row:CreateTexture(nil, "BORDER")
    row.inner:SetPoint("TOPLEFT", row, "TOPLEFT", 1, -1)
    row.inner:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -1, 1)
    row.inner:SetColorTexture(1, 1, 1, 0.015)

    row.hover = row:CreateTexture(nil, "HIGHLIGHT")
    row.hover:SetAllPoints(row)
    row.hover:SetColorTexture(0.96, 0.78, 0.24, 0.08)

    row.divider = row:CreateTexture(nil, "BORDER")
    row.divider:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", 8, 0)
    row.divider:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", -8, 0)
    row.divider:SetHeight(1)
    row.divider:SetColorTexture(1, 1, 1, 0.04)

    row.iconBackdrop = row:CreateTexture(nil, "BORDER")
    row.iconBackdrop:SetPoint("LEFT", row, "LEFT", 4, 0)
    row.iconBackdrop:SetSize(34, 34)
    row.iconBackdrop:SetColorTexture(0, 0, 0, 0.24)

    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(30, 30)
    row.icon:SetPoint("CENTER", row.iconBackdrop, "CENTER", 0, 0)
    row.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.label = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.label:SetPoint("LEFT", row.iconBackdrop, "RIGHT", 12, 0)
    row.label:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.label:SetJustifyH("LEFT")
    row.label:SetWordWrap(false)
    row.label:SetMaxLines(1)

    row.status = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.status:SetPoint("RIGHT", row, "RIGHT", -10, 0)
    row.status:SetWidth(56)
    row.status:SetJustifyH("RIGHT")
    row.status:SetTextColor(0.86, 0.82, 0.72)

    row.UpdateLayout = function(self, showStatus)
        self.label:ClearAllPoints()
        self.label:SetPoint("LEFT", self.iconBackdrop, "RIGHT", 12, 0)
        if showStatus then
            self.label:SetPoint("RIGHT", self.status, "LEFT", -8, 0)
        else
            self.label:SetPoint("RIGHT", self, "RIGHT", -10, 0)
        end
    end

    row:UpdateLayout(false)

    row:SetScript("OnEnter", function(self)
        if not self.entry then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if self.entry.spellID then
            GameTooltip:SetSpellByID(self.entry.spellID)
        elseif self.entry.itemID then
            GameTooltip:SetItemByID(self.entry.itemID)
        else
            GameTooltip:SetText(self.entry.label or "Teleport")
        end

        if not self.entry.known then
            GameTooltip:AddLine("Unavailable to this character.", 1, 0.25, 0.25)
            GameTooltip:Show()
        end
    end)

    row:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    frame.rows[index] = row
    return row
end

NormalizeSpellEntry = function(entry)
    return {
        label = entry.name or GetSpellName(entry.spellID, entry.name),
        icon = GetSpellIcon(entry.spellID),
        spellID = entry.spellID,
        known = IsSpellKnownSafe(entry.spellID),
        uid = "spell:" .. tostring(entry.spellID),
    }
end

local function NormalizeItemEntry(entry)
    return {
        label = GetItemName(entry.itemID, entry.name),
        icon = GetItemIcon(entry.itemID),
        itemID = entry.itemID,
        known = IsItemOwned(entry.itemID),
        uid = "item:" .. tostring(entry.itemID),
    }
end

local function BuildUtilitySpellPool()
    local entries = {}

    if PLAYER_CLASS == "MAGE" then
        local spells = PLAYER_FACTION == "Alliance" and MAGE_TELEPORTS_ALLIANCE or MAGE_TELEPORTS_HORDE
        local portals = PLAYER_FACTION == "Alliance" and MAGE_PORTALS_ALLIANCE or MAGE_PORTALS_HORDE
        for _, spellID in ipairs(spells) do
            table.insert(entries, { spellID = spellID })
        end
        for _, spellID in ipairs(portals) do
            table.insert(entries, { spellID = spellID })
        end
    end

    for _, spellID in ipairs(UTILITY_SPELLS[PLAYER_CLASS] or {}) do
        table.insert(entries, { spellID = spellID })
    end

    for _, spellID in ipairs(RACIAL_SPELLS[PLAYER_RACE] or {}) do
        table.insert(entries, { spellID = spellID })
    end

    return entries
end

local function NormalizeMatchText(text)
    if type(text) ~= "string" then
        return ""
    end

    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    text = text:lower()
    text = text:gsub("%+", " ")
    text = text:gsub("[^%w%s]", " ")
    text = text:gsub("%s+", " ")

    return text:match("^%s*(.-)%s*$") or ""
end

function Teleports:FindGroupFinderTeleportInfo(activityName, listingName)
    local haystack = NormalizeMatchText(table.concat({
        type(activityName) == "string" and activityName or "",
        type(listingName) == "string" and listingName or "",
    }, " "))

    if haystack == "" then
        return nil
    end

    local bestMatch = nil
    local bestLength = 0

    for _, source in ipairs({ CURRENT_SEASON_DUNGEONS, RAID_TELEPORTS }) do
        for _, rawEntry in ipairs(source) do
            local entry = NormalizeSpellEntry(rawEntry)
            local matchText = NormalizeMatchText(entry.label)
            if matchText ~= "" and haystack:find(matchText, 1, true) and #matchText > bestLength then
                bestMatch = entry
                bestLength = #matchText
            end
        end
    end

    return bestMatch
end

function Teleports:OpenNotificationTeleportBrowser(anchorFrame)
    if not self:IsEnabled() then
        self:Enable()
    end

    self:ShowDatatextPopup(anchorFrame)
end

function Teleports:GetFavoriteHearthstoneEntry()
    local datatextOptions = GetDatatextOptions()
    local favoriteItemID = datatextOptions and datatextOptions.GetFavoriteHearthstone and
        datatextOptions:GetFavoriteHearthstone()
    if not favoriteItemID or favoriteItemID == 0 then
        favoriteItemID = 6948
    end

    return { itemID = favoriteItemID, name = "Favorite Hearthstone" }
end

function Teleports:GetDB()
    local options = GetOptions()
    return options and options.GetDB and options:GetDB() or {}
end

function Teleports:GetCollapsedSections()
    local db = self:GetDB()
    db.collapsedSections = db.collapsedSections or {}
    return db.collapsedSections
end

function Teleports:IsSectionCollapsed(mode, title)
    return self:GetCollapsedSections()[mode .. ":" .. title] == true
end

function Teleports:SetSectionCollapsed(mode, title, isCollapsed)
    self:GetCollapsedSections()[mode .. ":" .. title] = isCollapsed == true
end

function Teleports:ToggleSectionCollapsed(frame, mode, title)
    self:SetSectionCollapsed(mode, title, not self:IsSectionCollapsed(mode, title))
    self:RenderBrowser(frame, mode)
end

function Teleports:GetPopupPositionDB()
    local db = self:GetDB()
    db.popupPosition = db.popupPosition or {}
    return db.popupPosition
end

function Teleports:SavePopupPosition(frame)
    if not frame or not frame.GetPoint then
        return
    end

    local point, _, relativePoint, xOfs, yOfs = frame:GetPoint(1)
    local db = self:GetPopupPositionDB()
    db.point = point or "CENTER"
    db.relativePoint = relativePoint or point or "CENTER"
    db.x = xOfs or 0
    db.y = yOfs or 0
end

function Teleports:ApplyPopupPosition(frame, anchorFrame)
    if not frame then
        return
    end

    local db = self:GetPopupPositionDB()
    frame:ClearAllPoints()

    if db.point and db.relativePoint then
        frame:SetPoint(db.point, UIParent, db.relativePoint, db.x or 0, db.y or 0)
        return
    end

    if anchorFrame and anchorFrame.GetCenter then
        frame:SetPoint("TOP", anchorFrame, "BOTTOM", 0, -6)
    else
        frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end
end

function Teleports:MakePopupDraggable(frame)
    if not frame or frame.dragInitialized then
        return
    end

    frame:SetMovable(true)
    frame:RegisterForDrag("LeftButton")

    local dragHandle = CreateFrame("Button", nil, frame)
    dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -6)
    dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", frame.CloseButton and -28 or -8, -6)
    dragHandle:SetHeight(20)
    dragHandle:RegisterForDrag("LeftButton")
    dragHandle:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)

    dragHandle:SetScript("OnDragStart", function()
        if not InCombatLockdown() then
            frame:StartMoving()
        end
    end)

    dragHandle:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        self:SavePopupPosition(frame)
    end)

    frame:SetScript("OnHide", function(hiddenFrame)
        hiddenFrame:StopMovingOrSizing()
    end)

    frame.dragHandle = dragHandle
    frame.dragInitialized = true
end

function Teleports:CollectSectionEntries(source, kind)
    local normalized = {}
    local seen = {}
    local showOnlyKnown = GetOptions():GetShowOnlyKnown()

    for _, entry in ipairs(source or {}) do
        local item = kind == "item" and NormalizeItemEntry(entry) or NormalizeSpellEntry(entry)
        if item and not seen[item.uid] then
            seen[item.uid] = true
            if item.known or not showOnlyKnown then
                table.insert(normalized, item)
            end
        end
    end

    table.sort(normalized, function(left, right)
        return (left.label or "") < (right.label or "")
    end)

    return normalized
end

function Teleports:BuildSections(mode)
    local sections = {}
    local options = GetOptions()

    local function AddSection(title, entries)
        if entries and #entries > 0 then
            table.insert(sections, {
                title = title,
                entries = entries,
            })
        end
    end

    AddSection("Current Season", self:CollectSectionEntries(CURRENT_SEASON_DUNGEONS, "spell"))

    if mode == "map" then
        AddSection("Raid Teleports", self:CollectSectionEntries(RAID_TELEPORTS, "spell"))
    elseif options:GetDatatextIncludeRaids() then
        AddSection("Raid Teleports", self:CollectSectionEntries(CURRENT_CONTENT_RAID_TELEPORTS, "spell"))
    end

    if options:GetShowHearthstones() then
        local hearthstones = {
            self:GetFavoriteHearthstoneEntry(),
            HEARTHSTONE_ENTRIES[2],
            HEARTHSTONE_ENTRIES[3],
        }
        AddSection("Hearthstones", self:CollectSectionEntries(hearthstones, "item"))
        AddSection("Other", self:CollectSectionEntries(OTHER_ITEM_ENTRIES, "item"))
    end

    if options:GetShowUtilityTeleports() then
        AddSection("Class and Racial Travel", self:CollectSectionEntries(BuildUtilitySpellPool(), "spell"))
    end

    return sections
end

function Teleports:BuildDatatextQuickCastSections()
    local sections = {}

    local function CollectKnown(source, kind)
        local collected = self:CollectSectionEntries(source, kind)
        local knownEntries = {}

        for _, entry in ipairs(collected) do
            if entry.known then
                table.insert(knownEntries, entry)
            end
        end

        return knownEntries
    end

    local function AddSection(title, entries)
        if entries and #entries > 0 then
            table.insert(sections, {
                title = title,
                entries = entries,
            })
        end
    end

    AddSection("Current Season", CollectKnown(CURRENT_SEASON_DUNGEONS, "spell"))

    local hearthstones = {
        self:GetFavoriteHearthstoneEntry(),
        HEARTHSTONE_ENTRIES[2],
        HEARTHSTONE_ENTRIES[3],
    }

    AddSection("Hearthstones", CollectKnown(hearthstones, "item"))
    AddSection("Other", CollectKnown(OTHER_ITEM_ENTRIES, "item"))

    return sections
end

function Teleports:RenderBrowser(frame, mode)
    if not frame then
        return
    end

    if InCombatLockdown() then
        self.refreshQueued = true
        frame.EmptyText:SetText("Teleport bindings cannot be refreshed in combat.")
        frame.EmptyText:Show()
        return
    end

    local sections = self:BuildSections(mode)
    local nextHeader = 1
    local nextRow = 1
    local contentHeight = 0
    local contentWidth = math.max(1, (frame.ScrollFrame:GetWidth() or 1) - 8)

    frame.ScrollChild:SetWidth(contentWidth)

    frame.EmptyText:SetShown(#sections == 0)
    if #sections == 0 then
        frame.EmptyText:SetText("No teleports matched the current filters.")
    end

    for sectionIndex, section in ipairs(sections) do
        local isCollapsed = self:IsSectionCollapsed(mode, section.title)
        local header = EnsureHeader(frame, nextHeader)
        header.Text:SetText(section.title)
        header.Arrow:SetText(isCollapsed and ">" or "v")
        header.mode = mode
        header.sectionTitle = section.title
        header.owner = self
        header.browserFrame = frame
        header:SetScript("OnClick", function(button)
            button.owner:ToggleSectionCollapsed(button.browserFrame, button.mode, button.sectionTitle)
        end)
        header:ClearAllPoints()
        if sectionIndex > 1 then
            contentHeight = contentHeight + 12
        end
        header:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 0, -contentHeight)
        header:SetPoint("RIGHT", frame.ScrollChild, "RIGHT", 0, 0)
        header:Show()
        contentHeight = contentHeight + header:GetHeight() + 6
        nextHeader = nextHeader + 1

        if not isCollapsed then
            for _, entry in ipairs(section.entries) do
                local row = EnsureRow(frame, nextRow)
                row.entry = entry
                row.icon:SetTexture(entry.icon)
                row.label:SetText(entry.label or "Teleport")
                local statusText = GetEntryStatus(entry)
                row.status:SetText(statusText)
                row.status:SetShown(statusText ~= "")
                row:UpdateLayout(statusText ~= "")
                row.label:SetTextColor(entry.known and 1 or 0.56, entry.known and 0.96 or 0.56,
                    entry.known and 0.90 or 0.56)
                row.icon:SetDesaturated(not entry.known)
                row.bg:SetAlpha((nextRow % 2 == 0) and 0.05 or 0.02)
                row.divider:SetShown(true)
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 0, -contentHeight)
                row:SetPoint("RIGHT", frame.ScrollChild, "RIGHT", 0, 0)
                row:Show()
                ConfigureSecureAction(row, entry)
                contentHeight = contentHeight + row:GetHeight() + 6
                nextRow = nextRow + 1
            end
        end
    end

    for index = nextHeader, #frame.headers do
        frame.headers[index]:Hide()
    end

    for index = nextRow, #frame.rows do
        frame.rows[index]:Hide()
        frame.rows[index].entry = nil
    end

    frame.ScrollChild:SetHeight(math.max(1, contentHeight + 8))
end

function Teleports:HideWorldMapPanel()
    if self.worldMapPanel then
        self.worldMapPanel:Hide()
    end

    if self.worldMapButton and self.worldMapButton.SetChecked then
        self.worldMapButton:SetChecked(false)
        RefreshWorldMapTabIcon(self.worldMapButton)
    end
end

function Teleports:ShowWorldMapPanel()
    if not self.worldMapPanel then
        return
    end

    local worldQuests = QOL.GetModule and QOL:GetModule("WorldQuests", true)
    if worldQuests and worldQuests.HideWorldMapPanel then
        worldQuests:HideWorldMapPanel()
    end

    self.worldMapPanel.Title:SetText("Teleports")
    self:RenderBrowser(self.worldMapPanel, "map")
    self.worldMapPanel:Show()

    if self.worldMapButton and self.worldMapButton.SetChecked then
        self.worldMapButton:SetChecked(true)
        RefreshWorldMapTabIcon(self.worldMapButton)
    end
end

function Teleports:ToggleWorldMapPanel()
    if not self.worldMapPanel then
        return
    end

    if self.worldMapPanel:IsShown() then
        self:HideWorldMapPanel()
    else
        self:ShowWorldMapPanel()
    end
end

function Teleports:HideDatatextPopup()
    if self.datatextPopup then
        self.datatextPopup:Hide()
    end
end

function Teleports:ShowDatatextPopup(anchorFrame)
    if not self.datatextPopup then
        self.datatextPopup = CreateBrowserFrame("TwichUI_TeleportsDatatextPopup", UIParent, 420, 360, true)
        self.datatextPopup:SetFrameStrata("DIALOG")
        self.datatextPopup:SetFrameLevel(20)
        self:MakePopupDraggable(self.datatextPopup)
    end

    self:ApplyPopupPosition(self.datatextPopup, anchorFrame)

    self.datatextPopup.Title:SetText("Season Teleports")
    self:RenderBrowser(self.datatextPopup, "datatext")
    self.datatextPopup:Show()
end

function Teleports:ToggleDatatextPopup(anchorFrame)
    if not GetOptions():GetShowDatatextPopup() then
        return false
    end

    if self.datatextPopup and self.datatextPopup:IsShown() then
        self:HideDatatextPopup()
    else
        self:ShowDatatextPopup(anchorFrame)
    end

    return true
end

function Teleports:OpenStandaloneBrowser()
    self:ShowDatatextPopup(nil)
end

function Teleports:HookWorldMapTabSiblings()
    local questMapFrame = _G.QuestMapFrame
    if not questMapFrame then
        return
    end

    local function HidePanel()
        Teleports:HideWorldMapPanel()
    end

    for _, tab in ipairs({ questMapFrame.QuestsTab, questMapFrame.EventsTab, questMapFrame.MapLegendTab }) do
        if tab and not tab.twichTeleportsHooked then
            tab:HookScript("OnMouseUp", function(_, mouseButton)
                if mouseButton == "LeftButton" then
                    HidePanel()
                end
            end)
            tab.twichTeleportsHooked = true
        end
    end

    for _, contentFrame in ipairs({ questMapFrame.QuestsFrame, questMapFrame.EventsFrame, questMapFrame.MapLegendFrame }) do
        if contentFrame and not contentFrame.twichTeleportsHooked then
            hooksecurefunc(contentFrame, "Show", HidePanel)
            contentFrame.twichTeleportsHooked = true
        end
    end
end

function Teleports:CreateWorldMapPanel()
    local questMapFrame = _G.QuestMapFrame
    local parentFrame = questMapFrame or _G.WorldMapFrame
    if not parentFrame then
        return
    end

    local contentAnchor = questMapFrame and questMapFrame.ContentsAnchor or parentFrame
    self.worldMapPanel = CreateBrowserFrame("TwichUI_TeleportsWorldMapPanel", parentFrame, 328, 440, false)
    self.worldMapPanel:SetFrameStrata(contentAnchor:GetFrameStrata())
    self.worldMapPanel:SetFrameLevel((contentAnchor:GetFrameLevel() or 1) + 20)
    self.worldMapPanel:ClearAllPoints()
    if questMapFrame and contentAnchor == questMapFrame.ContentsAnchor then
        self.worldMapPanel:SetPoint("TOPLEFT", contentAnchor, "TOPLEFT", 0, -29)
        self.worldMapPanel:SetPoint("BOTTOMRIGHT", contentAnchor, "BOTTOMRIGHT", -22, 0)
    else
        self.worldMapPanel:SetAllPoints(contentAnchor)
    end

    if self.worldMapPanel.BackgroundFill then
        local bgR, bgG, bgB, bgA = GetBackdropColors()
        self.worldMapPanel.BackgroundFill:SetColorTexture(bgR, bgG, bgB, bgA)
    end

    if not self.worldMapPanel.InnerBackground then
        local innerBackground = self.worldMapPanel.ScrollFrame:CreateTexture(nil, "BACKGROUND")
        innerBackground:SetPoint("TOPLEFT", self.worldMapPanel.ScrollFrame, "TOPLEFT", 0, 0)
        innerBackground:SetPoint("BOTTOMRIGHT", self.worldMapPanel.ScrollFrame, "BOTTOMRIGHT", 0, 0)
        self.worldMapPanel.InnerBackground = innerBackground
    end

    local bgR, bgG, bgB, bgA = GetBackdropColors()
    self.worldMapPanel.InnerBackground:SetColorTexture(bgR, bgG, bgB, bgA)
end

function Teleports:CreateWorldMapButton()
    local questMapFrame = _G.QuestMapFrame
    local tabParent = questMapFrame or (_G.WorldMapFrame and _G.WorldMapFrame.BorderFrame)
    if not tabParent then
        return
    end

    local button = CreateFrame("Button", "TwichUI_TeleportsWorldMapTabButton", tabParent, "LargeSideTabButtonTemplate")
    button:SetFrameStrata("HIGH")
    button.tooltipText = "Teleports"
    self.tabSpacing = 1

    local referenceTab = questMapFrame and
        (questMapFrame.MapLegendTab or questMapFrame.EventsTab or questMapFrame.QuestsTab)
    if referenceTab then
        local width, height = referenceTab:GetSize()
        if width and height and width > 0 and height > 0 then
            button:SetSize(width, height)
        end
    end

    if button.Icon then
        button.Icon:SetTexture(GetSpellIcon(10059))
        ApplyWorldMapTabIconLayout(button)
    end

    ApplyWorldMapTabSkin(button)

    if not button.twichIconHooks then
        button:HookScript("OnShow", function() RefreshWorldMapTabIcon(button) end)
        button:HookScript("OnMouseDown", function() RefreshWorldMapTabIcon(button) end)
        button:HookScript("OnMouseUp", function() RefreshWorldMapTabIcon(button) end)
        button:HookScript("OnClick", function() RefreshWorldMapTabIcon(button) end)
        button.twichIconHooks = true
    end

    button:SetScript("OnMouseUp", function(_, mouseButton)
        if mouseButton == "LeftButton" then
            Teleports:ToggleWorldMapPanel()
        end
    end)

    local anchorTab = questMapFrame and
        (questMapFrame.MapLegendTab or questMapFrame.EventsTab or questMapFrame.QuestsTab)
    button:ClearAllPoints()
    if anchorTab then
        button:SetPoint("TOP", anchorTab, "BOTTOM", 0, -(self.tabSpacing or 1))
    elseif _G.WorldMapFrame and _G.WorldMapFrame.BorderFrame then
        button:SetPoint("TOPRIGHT", _G.WorldMapFrame.BorderFrame, "TOPRIGHT", -8, -100)
    end

    self.worldMapButton = button

    local worldQuests = QOL.GetModule and QOL:GetModule("WorldQuests", true)
    if worldQuests and worldQuests.LayoutWorldMapButton then
        worldQuests:LayoutWorldMapButton()
    end
end

function Teleports:TryInitializeWorldMapTab()
    if self.worldMapInitialized then
        return true
    end

    if not GetOptions():GetShowWorldMapTab() then
        return false
    end

    if not _G.WorldMapFrame and type(_G.WorldMapFrame_LoadUI) == "function" then
        pcall(_G.WorldMapFrame_LoadUI)
    end

    if not _G.WorldMapFrame then
        return false
    end

    self:CreateWorldMapButton()
    self:CreateWorldMapPanel()
    if not self.worldMapButton or not self.worldMapPanel then
        return false
    end

    self:HookWorldMapTabSiblings()
    self.worldMapInitialized = true
    return true
end

function Teleports:RefreshNow(reason)
    local options = GetOptions()
    if not self:IsEnabled() then
        return
    end

    if options:GetShowWorldMapTab() then
        self:TryInitializeWorldMapTab()
        if self.worldMapButton then
            self.worldMapButton:Show()
        end
    else
        if self.worldMapButton then
            self.worldMapButton:Hide()
        end
        self:HideWorldMapPanel()
    end

    local worldQuests = QOL.GetModule and QOL:GetModule("WorldQuests", true)
    if worldQuests and worldQuests.LayoutWorldMapButton then
        worldQuests:LayoutWorldMapButton()
    end

    if self.worldMapPanel and self.worldMapPanel:IsShown() then
        self:RenderBrowser(self.worldMapPanel, "map")
    end

    if self.datatextPopup and self.datatextPopup:IsShown() then
        self:RenderBrowser(self.datatextPopup, "datatext")
    end

    if reason == "PLAYER_REGEN_ENABLED" and self.refreshQueued then
        self.refreshQueued = false
    end
end

function Teleports:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RefreshNow")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "RefreshNow")
    self:RegisterEvent("SPELLS_CHANGED", "RefreshNow")
    self:RegisterEvent("BAG_UPDATE_DELAYED", "RefreshNow")
    if self.RegisterEvent and _G.C_ToyBox then
        self:RegisterEvent("TOYS_UPDATED", "RefreshNow")
    end

    self:RefreshNow("enable")
end

function Teleports:OnDisable()
    self:UnregisterAllEvents()
    self:HideWorldMapPanel()
    self:HideDatatextPopup()
    if self.worldMapButton then
        self.worldMapButton:Hide()
    end

    local worldQuests = QOL.GetModule and QOL:GetModule("WorldQuests", true)
    if worldQuests and worldQuests.LayoutWorldMapButton then
        worldQuests:LayoutWorldMapButton()
    end
end
