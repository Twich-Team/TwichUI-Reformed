---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class BagsModule : AceModule, AceEvent-3.0, AceTimer-3.0
local Bags = T:NewModule("Bags", "AceEvent-3.0", "AceTimer-3.0")
Bags:SetEnabledState(false)
_G.TwichUIBagsRuntime = Bags

local _G = _G
local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local C_Container = _G.C_Container
local C_Item = _G.C_Item
local GameTooltip = _G.GameTooltip
local InCombatLockdown = _G.InCombatLockdown
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsAltKeyDown = _G.IsAltKeyDown
local HandleModifiedItemClick = _G.HandleModifiedItemClick
local ChatEdit_InsertLink = _G.ChatEdit_InsertLink
local ItemLocation = _G.ItemLocation
local CooldownFrame_Set = _G.CooldownFrame_Set
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER or 0
local NUM_TOTAL_EQUIPPED_BAG_SLOTS = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS or 4

local LibStub = _G.LibStub
local Masque = LibStub and LibStub("Masque", true)
local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
local DEBUG_SOURCE_KEY = "bags"

local floor = math.floor
local ceil = math.ceil
local max = math.max
local min = math.min
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local wipe = table.wipe
local sort = table.sort

local COLOR_ACCENT = { 0.14, 0.8, 1.0 }
local COLOR_PANEL_BG = { 0.04, 0.05, 0.08 }

local BASE_CATEGORY_ORDER = {
    "recent",
    "equipment",
    "consumables",
    "tradegoods",
    "quest",
    "junk",
    "misc",
}

local CATEGORY_LABELS = {
    recent = "Recent",
    equipment = "Equipment",
    consumables = "Consumables",
    tradegoods = "Trade Goods",
    quest = "Quest",
    junk = "Junk",
    misc = "Misc",
}

local ITEM_CLASS = (_G.Enum and _G.Enum.ItemClass) or {}
local ITEM_CLASS_IDS = {
    consumable = ITEM_CLASS.Consumable or _G.LE_ITEM_CLASS_CONSUMABLE or 0,
    container = ITEM_CLASS.Container or _G.LE_ITEM_CLASS_CONTAINER or 1,
    weapon = ITEM_CLASS.Weapon or _G.LE_ITEM_CLASS_WEAPON or 2,
    gem = ITEM_CLASS.Gem or _G.LE_ITEM_CLASS_GEM or 3,
    armor = ITEM_CLASS.Armor or _G.LE_ITEM_CLASS_ARMOR or 4,
    reagent = ITEM_CLASS.Reagent or _G.LE_ITEM_CLASS_REAGENT or 5,
    tradegoods = ITEM_CLASS.Tradegoods or _G.LE_ITEM_CLASS_TRADEGOODS or 7,
    recipe = ITEM_CLASS.Recipe or _G.LE_ITEM_CLASS_RECIPE or 9,
    quest = ITEM_CLASS.Questitem or _G.LE_ITEM_CLASS_QUESTITEM or 12,
}

local function GetCategoryByItemType(itemType)
    if not itemType then
        return nil
    end

    if itemType == _G.ITEM_CLASS_WEAPON or itemType == _G.ITEM_CLASS_ARMOR or itemType == _G.ITEM_CLASS_GEM then
        return "equipment"
    end

    if itemType == _G.ITEM_CLASS_CONSUMABLE then
        return "consumables"
    end

    if itemType == _G.ITEM_CLASS_TRADEGOODS or itemType == _G.ITEM_CLASS_REAGENT or itemType == _G.ITEM_CLASS_RECIPE then
        return "tradegoods"
    end

    if itemType == _G.ITEM_CLASS_QUESTITEM then
        return "quest"
    end

    return nil
end

local function ResolveItemMetadata(itemID, itemLink)
    local instant = _G.GetItemInfoInstant or (C_Item and C_Item.GetItemInfoInstant)
    if instant then
        local _, itemType, _, equipLoc, _, classID = instant(itemID or itemLink)
        return classID, itemType, equipLoc
    end

    local _, _, _, _, _, itemType, _, _, equipLoc = _G.GetItemInfo(itemLink or itemID)
    return nil, itemType, equipLoc
end

local function GetOptions()
    local config = T:GetModule("Configuration", true)
    return config and config.Options and config.Options.Bags
end

local function GetDB()
    local options = GetOptions()
    return options and options:GetDB() or {}
end

local function IsDebugEnabled()
    local options = GetOptions()
    return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
end

local function LogBagsDebug(messageFormat, ...)
    if not (DebugConsole and DebugConsole.Logf and IsDebugEnabled()) then
        return
    end

    DebugConsole:Logf(DEBUG_SOURCE_KEY, false, messageFormat, ...)
end

local function CreatePanel(parent, r, g, b, a, edgeA)
    local panel = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    panel:SetBackdropColor(r or 0.05, g or 0.06, b or 0.09, a or 0.95)
    panel:SetBackdropBorderColor(COLOR_ACCENT[1], COLOR_ACCENT[2], COLOR_ACCENT[3], edgeA or 0.25)
    return panel
end

local function BuildLocationKey(bagID, slotID)
    return tostring(bagID) .. ":" .. tostring(slotID)
end

local function StripColorCodes(text)
    text = tostring(text or "")
    text = text:gsub("|c%x%x%x%x%x%x%x%x", "")
    text = text:gsub("|r", "")
    return text
end

local function SortItems(a, b)
    local qa = tonumber(a.quality) or 0
    local qb = tonumber(b.quality) or 0
    if qa ~= qb then
        return qa > qb
    end

    local na = StripColorCodes(a.itemName)
    local nb = StripColorCodes(b.itemName)
    if na ~= nb then
        return na < nb
    end

    if (a.itemID or 0) ~= (b.itemID or 0) then
        return (a.itemID or 0) < (b.itemID or 0)
    end

    if (a.bagID or 0) ~= (b.bagID or 0) then
        return (a.bagID or 0) < (b.bagID or 0)
    end

    return (a.slotID or 0) < (b.slotID or 0)
end

local function GetItemGUID(bagID, slotID)
    if not (C_Item and C_Item.GetItemGUID and ItemLocation and ItemLocation.CreateFromBagAndSlot) then
        return nil
    end

    local location = ItemLocation:CreateFromBagAndSlot(bagID, slotID)
    if not location then
        return nil
    end

    local ok, guid = pcall(C_Item.GetItemGUID, location)
    if ok then
        return guid
    end

    return nil
end

local function IsContainerSlotRange(slot)
    return slot >= BACKPACK_CONTAINER and slot <= NUM_TOTAL_EQUIPPED_BAG_SLOTS
end

function Bags:OnInitialize()
    self.data = {
        byCategory = {},
        allItems = {},
    }

    self.knownGUIDs = {}
    self.newByGUID = {}
    self.newByLocation = {}
    self.newTrackingPrimed = false
    self.equipmentSetByGUID = {}
    self.equipmentSetNames = {}

    self.sectionFrames = {}
    self.sectionOrder = {}
    self.buttonPool = {}
    self.activeButtons = {}

    if DebugConsole and DebugConsole.RegisterSource then
        DebugConsole:RegisterSource(DEBUG_SOURCE_KEY, {
            title = "Bags",
            order = 34,
            aliases = { "bags", "bag" },
            maxLines = 240,
            isEnabled = function()
                return IsDebugEnabled()
            end,
            buildReport = function()
                return self:BuildDebugReport()
            end,
        })
    end
end

function Bags:OnEnable()
    self:EnsureFrame()
    self:ApplyFrameStyle()
    self:RegisterEvent("BAG_UPDATE_DELAYED", "OnBagEvent")
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "OnBagEvent")
    self:RegisterEvent("BAG_CLOSED", "OnBagEvent")
    self:RegisterEvent("ITEM_LOCK_CHANGED", "OnBagEvent")

    self:InstallBagHooks()
    self:HideBlizzardContainers()
    self:RequestRefresh(true)
end

function Bags:OnDisable()
    self:UnregisterAllEvents()
    self:CancelTimers()
    self:UninstallBagHooks()
    if self.frame then
        self.frame:Hide()
    end
    self:ShowBlizzardBackpackButtons(true)
end

function Bags:CancelTimers()
    if self.refreshTimer then
        self:CancelTimer(self.refreshTimer)
        self.refreshTimer = nil
    end
    if self.newItemTicker then
        self:CancelTimer(self.newItemTicker)
        self.newItemTicker = nil
    end
end

function Bags:OnBagEvent()
    self:RequestRefresh(false)
end

function Bags:RequestRefresh(force)
    self.pendingForceRefresh = self.pendingForceRefresh or force == true
    if self.refreshTimer then
        return
    end

    self.refreshTimer = self:ScheduleTimer(function()
        self.refreshTimer = nil
        self:Refresh(self.pendingForceRefresh)
        self.pendingForceRefresh = nil
    end, 0.05)
end

function Bags:StartNewItemTicker()
    if self.newItemTicker then
        return
    end

    self.newItemTicker = self:ScheduleRepeatingTimer(function()
        if not (self.frame and self.frame:IsShown()) then
            return
        end

        if self:ClearExpiredNewItems() then
            self:RequestRefresh(true)
        end
    end, 1.0)
end

function Bags:StopNewItemTicker()
    if self.newItemTicker then
        self:CancelTimer(self.newItemTicker)
        self.newItemTicker = nil
    end
end

function Bags:EnsureFrame()
    if self.frame then
        return self.frame
    end

    local frame = CreatePanel(UIParent, COLOR_PANEL_BG[1], COLOR_PANEL_BG[2], COLOR_PANEL_BG[3], 0.97, 0.32)
    frame:SetSize(860, 640)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, -20)
    frame:SetMovable(true)
    frame:SetClampedToScreen(true)
    frame:SetFrameStrata("HIGH")
    frame:SetFrameLevel(35)
    frame:RegisterForDrag("LeftButton")
    frame:EnableMouse(true)
    frame:Hide()

    frame:SetScript("OnDragStart", function(selfFrame)
        if InCombatLockdown and InCombatLockdown() then
            return
        end

        if GetDB().lockFrame then
            return
        end

        selfFrame:StartMoving()
    end)

    frame:SetScript("OnDragStop", function(selfFrame)
        selfFrame:StopMovingOrSizing()
        self:SaveFramePosition()
    end)

    frame:SetScript("OnShow", function()
        self:StartNewItemTicker()
        self:RequestRefresh(true)
    end)

    frame:SetScript("OnHide", function()
        self:StopNewItemTicker()
    end)

    frame.TitleBar = CreatePanel(frame, 0.06, 0.08, 0.11, 0.98, 0)
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    frame.TitleBar:SetHeight(30)
    frame.TitleBar:SetBackdropBorderColor(0, 0, 0, 0)
    frame.TitleBar:EnableMouse(true)
    frame.TitleBar:RegisterForDrag("LeftButton")
    frame.TitleBar:SetScript("OnDragStart", function()
        frame:GetScript("OnDragStart")(frame)
    end)
    frame.TitleBar:SetScript("OnDragStop", function()
        frame:GetScript("OnDragStop")(frame)
    end)

    frame.SortButton = CreateFrame("Button", nil, frame.TitleBar, "BackdropTemplate")
    frame.SortButton:SetSize(110, 20)
    frame.SortButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -34, 0)
    frame.SortButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.SortButton:SetBackdropColor(0.05, 0.09, 0.14, 0.95)
    frame.SortButton:SetBackdropBorderColor(0.2, 0.82, 1.0, 0.45)
    frame.SortButton.Text = frame.SortButton:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    frame.SortButton.Text:SetPoint("CENTER", frame.SortButton, "CENTER", 0, 0)
    frame.SortButton.Text:SetText("Sort Bags")
    frame.SortButton.Text:SetTextColor(0.85, 0.95, 1)
    frame.SortButton:SetScript("OnClick", function()
        if type(_G.SortBags) == "function" then
            _G.SortBags()
        end
        self:RequestRefresh(true)
    end)

    frame.CloseButton = CreateFrame("Button", nil, frame.TitleBar, "BackdropTemplate")
    frame.CloseButton:SetSize(20, 20)
    frame.CloseButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -6, 0)
    frame.CloseButton:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.CloseButton:SetBackdropColor(0.14, 0.06, 0.08, 0.95)
    frame.CloseButton:SetBackdropBorderColor(1, 0.42, 0.42, 0.45)
    frame.CloseButton.Text = frame.CloseButton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    frame.CloseButton.Text:SetPoint("CENTER", frame.CloseButton, "CENTER", 0, 0)
    frame.CloseButton.Text:SetText("x")
    frame.CloseButton.Text:SetTextColor(1, 0.88, 0.88)
    frame.CloseButton:SetScript("OnClick", function()
        self:Hide()
    end)

    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
    frame.ScrollFrame:SetPoint("TOPLEFT", frame, "TOPLEFT", 12, -44)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -28, 12)
    if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichScrollBar then
        T.Tools.UI.SkinTwichScrollBar(frame.ScrollFrame, COLOR_ACCENT, true)
    end

    if frame.ScrollFrame.ScrollBar then
        if frame.ScrollFrame.ScrollBar.ScrollUpButton then
            frame.ScrollFrame.ScrollBar.ScrollUpButton:Hide()
            frame.ScrollFrame.ScrollBar.ScrollUpButton:EnableMouse(false)
        end
        if frame.ScrollFrame.ScrollBar.ScrollDownButton then
            frame.ScrollFrame.ScrollBar.ScrollDownButton:Hide()
            frame.ScrollFrame.ScrollBar.ScrollDownButton:EnableMouse(false)
        end
    end

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ScrollFrame)
    frame.ScrollChild:SetSize(1, 1)
    frame.ScrollFrame:SetScrollChild(frame.ScrollChild)

    frame.ScrollFrame:HookScript("OnSizeChanged", function(scroll)
        local width = max(1, (scroll:GetWidth() or 1) - 8)
        frame.ScrollChild:SetWidth(width)
        if frame:IsShown() then
            self:RequestRefresh(true)
        end
    end)

    self.frame = frame
    self:RestoreFramePosition()
    return frame
end

function Bags:ApplyFrameStyle()
    local frame = self:EnsureFrame()
    local db = GetDB()

    frame:SetScale(max(0.7, min(1.4, tonumber(db.scale) or 1)))
    frame:SetAlpha(max(0.55, min(1.0, tonumber(db.alpha) or 1)))

    local locked = db.lockFrame == true
    frame:SetMovable(not locked)
end

function Bags:RestoreFramePosition()
    local frame = self:EnsureFrame()
    local db = GetDB()
    local pos = db.position or {}

    frame:ClearAllPoints()
    frame:SetPoint(pos.point or "CENTER", UIParent, pos.relativePoint or "CENTER", pos.x or 0, pos.y or -20)
end

function Bags:SaveFramePosition()
    local frame = self:EnsureFrame()
    local point, _, relativePoint, x, y = frame:GetPoint(1)
    local db = GetDB()
    db.position = {
        point = point,
        relativePoint = relativePoint,
        x = floor((x or 0) + 0.5),
        y = floor((y or 0) + 0.5),
    }
end

function Bags:GetMasqueGroup()
    if not Masque then
        return nil
    end

    if not self.masqueGroup then
        local ok, group = pcall(Masque.Group, Masque, "TwichUI Reformed", "Bags")
        if ok then
            self.masqueGroup = group
        end
    end

    return self.masqueGroup
end

function Bags:ApplyMasqueState(button, removeOnly)
    local group = self:GetMasqueGroup()
    if not group then
        return
    end

    if button._masqueAdded then
        pcall(group.RemoveButton, group, button)
        button._masqueAdded = nil
    end

    local db = GetDB()
    if removeOnly or db.useMasque ~= true then
        return
    end

    local icon = button.icon or button.Icon or button.IconTexture
    local data = {
        Icon = icon,
        Cooldown = button.Cooldown,
        Count = button.Count,
        Border = button.IconBorder,
        Normal = button:GetNormalTexture(),
        Pushed = button:GetPushedTexture(),
        Highlight = button:GetHighlightTexture(),
    }

    if pcall(group.AddButton, group, button, data) then
        button._masqueAdded = true
    end
end

function Bags:AcquireButton(parent)
    local button = table.remove(self.buttonPool)
    if not button then
        local ok, templatedButton = pcall(CreateFrame, "Button", nil, parent, "ContainerFrameItemButtonTemplate")
        if ok and templatedButton then
            button = templatedButton
        else
            button = CreateFrame("Button", nil, parent)
        end
        button:SetSize(34, 34)

        if button.SetBackdrop then
            button:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
        else
            button.Chrome = CreateFrame("Frame", nil, button, "BackdropTemplate")
            button.Chrome:SetAllPoints(button)
            button.Chrome:EnableMouse(false)
            button.Chrome:SetFrameLevel(max(0, button:GetFrameLevel() - 1))
            button.Chrome:SetBackdrop({
                bgFile = "Interface\\Buttons\\WHITE8X8",
                edgeFile = "Interface\\Buttons\\WHITE8X8",
                edgeSize = 1,
                insets = { left = 1, right = 1, top = 1, bottom = 1 },
            })
        end

        if not button.icon then
            button.icon = button:CreateTexture(nil, "ARTWORK")
            button.icon:SetPoint("TOPLEFT", button, "TOPLEFT", 2, -2)
            button.icon:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
            button.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        end

        if not button.Count then
            button.Count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
            button.Count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -2, 2)
            button.Count:SetJustifyH("RIGHT")
        end

        if not button.Cooldown then
            button.Cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
            button.Cooldown:SetAllPoints(button)
        end

        if not button.IconBorder then
            button.IconBorder = button:CreateTexture(nil, "OVERLAY")
            button.IconBorder:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
            button.IconBorder:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 0, 0)
            button.IconBorder:SetTexture("Interface\\Buttons\\WHITE8X8")
            button.IconBorder:SetVertexColor(1, 1, 1, 0)
        end

        button.NewOverlay = button:CreateTexture(nil, "OVERLAY")
        button.NewOverlay:SetPoint("TOPLEFT", button, "TOPLEFT", 1, -1)
        button.NewOverlay:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
        button.NewOverlay:SetColorTexture(0.22, 0.85, 0.28, 0.35)
        button.NewOverlay:SetAlpha(0)

        button.NewPulse = button:CreateAnimationGroup()
        local fadeIn = button.NewPulse:CreateAnimation("Alpha")
        fadeIn:SetOrder(1)
        fadeIn:SetFromAlpha(0.15)
        fadeIn:SetToAlpha(0.75)
        fadeIn:SetDuration(0.3)
        fadeIn:SetSmoothing("IN_OUT")
        local fadeOut = button.NewPulse:CreateAnimation("Alpha")
        fadeOut:SetOrder(2)
        fadeOut:SetFromAlpha(0.75)
        fadeOut:SetToAlpha(0.15)
        fadeOut:SetDuration(0.34)
        fadeOut:SetSmoothing("IN_OUT")
        button.NewPulse:SetLooping("REPEAT")

        button:SetScript("OnEnter", function(btn)
            if not btn.itemData then
                return
            end

            GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
            if btn.itemData.bagID ~= nil and btn.itemData.slotID ~= nil and GameTooltip.SetBagItem then
                GameTooltip:SetBagItem(btn.itemData.bagID, btn.itemData.slotID)
            elseif btn.itemData.itemLink then
                GameTooltip:SetHyperlink(btn.itemData.itemLink)
            end
            GameTooltip:Show()
        end)

        button:SetScript("OnLeave", function()
            GameTooltip:Hide()
        end)

        button:SetScript("OnClick", function(btn, mouseButton)
            local data = btn.itemData
            if not data then
                return
            end

            self:ClearNewByLocation(data.bagID, data.slotID)

            local link = data.itemLink
            if mouseButton == "LeftButton" then
                if IsShiftKeyDown() or IsControlKeyDown() or IsAltKeyDown() then
                    if link and HandleModifiedItemClick and HandleModifiedItemClick(link) then
                        return
                    end
                    if link and ChatEdit_InsertLink then
                        ChatEdit_InsertLink(link)
                    end
                    return
                end

                if C_Container and C_Container.PickupContainerItem then
                    C_Container.PickupContainerItem(data.bagID, data.slotID)
                end
            elseif mouseButton == "RightButton" then
                if C_Container and C_Container.UseContainerItem then
                    C_Container.UseContainerItem(data.bagID, data.slotID)
                end
            end
        end)
    end

    button:SetParent(parent)
    button:Show()
    table.insert(self.activeButtons, button)
    return button
end

function Bags:ReleaseAllButtons()
    for _, button in ipairs(self.activeButtons) do
        button:Hide()
        button:ClearAllPoints()
        button.itemData = nil
        button.NewPulse:Stop()
        button.NewOverlay:SetAlpha(0)
        self:ApplyMasqueState(button, true)
        table.insert(self.buttonPool, button)
    end

    wipe(self.activeButtons)
end

function Bags:EnsureSection(parent, key)
    local section = self.sectionFrames[key]
    if section then
        return section
    end

    section = CreatePanel(parent, 0.06, 0.07, 0.1, 0.95, 0.2)
    section.Header = section:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    section.Header:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -9)
    section.Header:SetPoint("RIGHT", section, "RIGHT", -10, 0)
    section.Header:SetJustifyH("LEFT")
    section.Header:SetTextColor(0.93, 0.9, 0.78)

    section.Count = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.Count:SetPoint("TOPRIGHT", section, "TOPRIGHT", -10, -10)
    section.Count:SetJustifyH("RIGHT")
    section.Count:SetTextColor(0.64, 0.76, 0.94)

    section.Divider = section:CreateTexture(nil, "BORDER")
    section.Divider:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -26)
    section.Divider:SetPoint("TOPRIGHT", section, "TOPRIGHT", -10, -26)
    section.Divider:SetHeight(1)
    section.Divider:SetColorTexture(COLOR_ACCENT[1], COLOR_ACCENT[2], COLOR_ACCENT[3], 0.25)

    section.HeaderButton = CreateFrame("Button", nil, section)
    section.HeaderButton:SetPoint("TOPLEFT", section, "TOPLEFT", 0, 0)
    section.HeaderButton:SetPoint("TOPRIGHT", section, "TOPRIGHT", 0, 0)
    section.HeaderButton:SetHeight(26)

    section.CollapseIndicator = section:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    section.CollapseIndicator:SetPoint("TOPLEFT", section, "TOPLEFT", 10, -10)
    section.CollapseIndicator:SetTextColor(0.88, 0.9, 0.95)
    section.CollapseIndicator:SetText("-")

    section.Header:ClearAllPoints()
    section.Header:SetPoint("TOPLEFT", section.CollapseIndicator, "TOPRIGHT", 6, 0)
    section.Header:SetPoint("RIGHT", section, "RIGHT", -80, 0)

    section.HeaderButton:SetScript("OnClick", function()
        local db = GetDB()
        db.collapsedSections = db.collapsedSections or {}
        db.collapsedSections[key] = not db.collapsedSections[key]
        self:RequestRefresh(true)
    end)

    self.sectionFrames[key] = section
    table.insert(self.sectionOrder, key)
    return section
end

function Bags:HideSections()
    for _, key in ipairs(self.sectionOrder) do
        local section = self.sectionFrames[key]
        if section then
            section:Hide()
        end
    end
end

function Bags:GetItemCategory(item)
    if not item then
        return "misc"
    end

    if (item.quality or 0) == 0 then
        return "junk"
    end

    if item.isRecent then
        return "recent"
    end

    if item.itemEquipLoc and item.itemEquipLoc ~= "" then
        return "equipment"
    end

    local classID = tonumber(item.classID)
    if classID and (classID == ITEM_CLASS_IDS.armor or classID == ITEM_CLASS_IDS.weapon or classID == ITEM_CLASS_IDS.gem) then
        return "equipment"
    end

    if classID and classID == ITEM_CLASS_IDS.consumable then
        return "consumables"
    end

    if classID and (classID == ITEM_CLASS_IDS.tradegoods or classID == ITEM_CLASS_IDS.reagent or classID == ITEM_CLASS_IDS.recipe) then
        return "tradegoods"
    end

    if classID and classID == ITEM_CLASS_IDS.quest then
        return "quest"
    end

    local fallbackCategory = GetCategoryByItemType(item.itemType)
    if fallbackCategory then
        return fallbackCategory
    end

    return "misc"
end

function Bags:ScanEquipmentSets()
    wipe(self.equipmentSetByGUID)
    wipe(self.equipmentSetNames)

    local canScan = _G.C_EquipmentSet and _G.C_EquipmentSet.GetEquipmentSetIDs and _G.C_EquipmentSet.GetItemLocations and
        _G.EquipmentManager_UnpackLocation and ItemLocation and ItemLocation.CreateFromBagAndSlot and C_Item and C_Item.GetItemGUID
    if not canScan then
        return
    end

    for _, setID in ipairs(_G.C_EquipmentSet.GetEquipmentSetIDs() or {}) do
        local setName = _G.C_EquipmentSet.GetEquipmentSetInfo and select(1, _G.C_EquipmentSet.GetEquipmentSetInfo(setID)) or nil
        if type(setName) == "string" and setName ~= "" then
            self.equipmentSetNames[#self.equipmentSetNames + 1] = setName
            for _, locationID in pairs(_G.C_EquipmentSet.GetItemLocations(setID) or {}) do
                if locationID and locationID ~= -1 and locationID ~= 0 and locationID ~= 1 then
                    local player, bank, bags, _, slot, bag = _G.EquipmentManager_UnpackLocation(locationID)
                    if bags and (player or bank) and bag and slot then
                        local location = ItemLocation:CreateFromBagAndSlot(bag, slot)
                        if location then
                            local guid = C_Item.GetItemGUID(location)
                            if guid then
                                self.equipmentSetByGUID[guid] = self.equipmentSetByGUID[guid] or {}
                                self.equipmentSetByGUID[guid][setName] = true
                            end
                        end
                    end
                end
            end
        end
    end

    LogBagsDebug("equipment set scan complete sets=%d", #self.equipmentSetNames)
end

function Bags:BuildDebugReport()
    local knownCount, newCount = 0, 0
    for _ in pairs(self.knownGUIDs or {}) do
        knownCount = knownCount + 1
    end
    for _ in pairs(self.newByGUID or {}) do
        newCount = newCount + 1
    end

    local lines = {
        "Bags Module Report",
        "",
        string.format("Enabled: %s", tostring(self:IsEnabled())),
        string.format("Frame shown: %s", tostring(self.frame and self.frame:IsShown() or false)),
        string.format("Known GUIDs: %d", knownCount),
        string.format("Tracked new GUIDs: %d", newCount),
        string.format("Equipment sets scanned: %d", #(self.equipmentSetNames or {})),
        string.format("Visible categories: %d", #(self.data and self.data.displayOrder or {})),
    }

    return table.concat(lines, "\n")
end

function Bags:CollectItems()
    local db = GetDB()
    local includeEquipmentSets = db.showEquipmentSetCategories ~= false
    local allItems = {}
    local byCategory = {
        recent = {},
        equipment = {},
        consumables = {},
        tradegoods = {},
        quest = {},
        junk = {},
        misc = {},
    }

    local currentGUIDs = {}
    local currentLocationByGUID = {}
    local unknownMetaCount = 0

    if includeEquipmentSets then
        self:ScanEquipmentSets()
    else
        wipe(self.equipmentSetByGUID)
        wipe(self.equipmentSetNames)
    end

    for bagID = BACKPACK_CONTAINER, NUM_TOTAL_EQUIPPED_BAG_SLOTS do
        if IsContainerSlotRange(bagID) and C_Container and C_Container.GetContainerNumSlots and C_Container.GetContainerItemInfo then
            local slots = C_Container.GetContainerNumSlots(bagID) or 0
            for slotID = 1, slots do
                local info = C_Container.GetContainerItemInfo(bagID, slotID)
                if info and info.itemID then
                    local itemID = info.itemID
                    local itemLink = info.hyperlink
                    local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = _G.GetItemInfo(itemLink or itemID)
                    local itemClassID, itemTypeName, itemEquipLoc = ResolveItemMetadata(itemID, itemLink)
                    if not itemClassID and not itemTypeName and not itemEquipLoc then
                        unknownMetaCount = unknownMetaCount + 1
                    end

                    local guid = GetItemGUID(bagID, slotID)
                    if guid then
                        currentGUIDs[guid] = true
                        currentLocationByGUID[guid] = { bagID = bagID, slotID = slotID }
                    end

                    local isRecent = false
                    if guid and self.newByGUID[guid] then
                        isRecent = true
                    end

                    local data = {
                        bagID = bagID,
                        slotID = slotID,
                        itemID = itemID,
                        itemLink = itemLink,
                        itemName = itemName or ("item:" .. tostring(itemID)),
                        icon = info.iconFileID or itemTexture,
                        quality = itemQuality or info.quality or 0,
                        itemType = itemTypeName,
                        itemEquipLoc = itemEquipLoc,
                        count = info.stackCount or 1,
                        isLocked = info.isLocked == true,
                        classID = itemClassID,
                        guid = guid,
                        isRecent = isRecent,
                    }

                    if guid and self.equipmentSetByGUID[guid] then
                        data.equipmentSets = self.equipmentSetByGUID[guid]
                    end

                    local category = self:GetItemCategory(data)
                    data.category = category

                    table.insert(allItems, data)
                    table.insert(byCategory[category], data)
                end
            end
        end
    end

    self:UpdateNewTracking(currentGUIDs, currentLocationByGUID)

    -- Re-assign recents after update to catch newly acquired items in this cycle.
    if db.showNewItems ~= false then
        for _, item in ipairs(allItems) do
            if item.guid and self.newByGUID[item.guid] then
                item.isRecent = true
                if item.category ~= "recent" then
                    table.insert(byCategory.recent, item)
                end
            end
        end
    else
        wipe(byCategory.recent)
    end

    for _, key in ipairs(BASE_CATEGORY_ORDER) do
        sort(byCategory[key], SortItems)
    end

    local dynamicSetKeys = {}
    if includeEquipmentSets then
        local setNames = {}
        for _, setName in ipairs(self.equipmentSetNames) do
            setNames[#setNames + 1] = setName
        end
        sort(setNames)

        for _, setName in ipairs(setNames) do
            local key = "set::" .. setName
            dynamicSetKeys[#dynamicSetKeys + 1] = key
            byCategory[key] = byCategory[key] or {}
            CATEGORY_LABELS[key] = "Set: " .. setName
        end

        for _, item in ipairs(allItems) do
            if item.equipmentSets then
                for setName in pairs(item.equipmentSets) do
                    local key = "set::" .. setName
                    if byCategory[key] then
                        byCategory[key][#byCategory[key] + 1] = item
                    end
                end
            end
        end

        for _, key in ipairs(dynamicSetKeys) do
            sort(byCategory[key], SortItems)
        end
    end

    local displayOrder = { "recent" }
    for _, key in ipairs(dynamicSetKeys) do
        displayOrder[#displayOrder + 1] = key
    end
    for _, key in ipairs(BASE_CATEGORY_ORDER) do
        if key ~= "recent" then
            displayOrder[#displayOrder + 1] = key
        end
    end

    self.data.allItems = allItems
    self.data.byCategory = byCategory
    self.data.dynamicSetKeys = dynamicSetKeys
    self.data.displayOrder = displayOrder

    LogBagsDebug("collect items total=%d recent=%d equipment=%d consumables=%d trade=%d misc=%d unknownMeta=%d", #allItems,
        #(byCategory.recent or {}), #(byCategory.equipment or {}), #(byCategory.consumables or {}),
        #(byCategory.tradegoods or {}), #(byCategory.misc or {}), unknownMetaCount)
end

function Bags:UpdateNewTracking(currentGUIDs, locationByGUID)
    local now = _G.GetTime and _G.GetTime() or 0
    local showNewItems = GetDB().showNewItems ~= false

    if not showNewItems then
        wipe(self.newByGUID)
        wipe(self.newByLocation)
        self.knownGUIDs = currentGUIDs
        self.newTrackingPrimed = true
        return
    end

    if not self.newTrackingPrimed then
        self.newTrackingPrimed = true
        self.knownGUIDs = currentGUIDs
        wipe(self.newByGUID)
        wipe(self.newByLocation)
        return
    end

    for guid in pairs(self.newByGUID) do
        if not currentGUIDs[guid] then
            local entry = self.newByGUID[guid]
            if entry then
                self.newByLocation[BuildLocationKey(entry.bagID, entry.slotID)] = nil
            end
            self.newByGUID[guid] = nil
        end
    end

    local timeoutSeconds = tonumber(GetDB().newItemTimeout) or 180
    for guid, entry in pairs(self.newByGUID) do
        local latest = locationByGUID[guid]
        if latest then
            local oldKey = BuildLocationKey(entry.bagID, entry.slotID)
            local newKey = BuildLocationKey(latest.bagID, latest.slotID)
            entry.bagID = latest.bagID
            entry.slotID = latest.slotID
            self.newByLocation[oldKey] = nil
            self.newByLocation[newKey] = guid
        end

        if timeoutSeconds > 0 and (now - (entry.seenAt or now)) >= timeoutSeconds then
            local key = BuildLocationKey(entry.bagID, entry.slotID)
            self.newByLocation[key] = nil
            self.newByGUID[guid] = nil
        end
    end

    for guid in pairs(currentGUIDs) do
        if not self.knownGUIDs[guid] and not self.newByGUID[guid] then
            local loc = locationByGUID[guid]
            if loc then
                self.newByGUID[guid] = {
                    bagID = loc.bagID,
                    slotID = loc.slotID,
                    seenAt = now,
                }
                self.newByLocation[BuildLocationKey(loc.bagID, loc.slotID)] = guid
            end
        end
    end

    self.knownGUIDs = currentGUIDs
end

function Bags:ClearExpiredNewItems()
    local timeout = tonumber(GetDB().newItemTimeout) or 180
    if timeout <= 0 then
        return false
    end

    local now = _G.GetTime and _G.GetTime() or 0
    local removed = false

    for guid, entry in pairs(self.newByGUID) do
        if (now - (entry.seenAt or now)) >= timeout then
            self.newByGUID[guid] = nil
            self.newByLocation[BuildLocationKey(entry.bagID, entry.slotID)] = nil
            removed = true
        end
    end

    return removed
end

function Bags:ClearNewByLocation(bagID, slotID)
    if bagID == nil or slotID == nil then
        return
    end

    local key = BuildLocationKey(bagID, slotID)
    local guid = self.newByLocation[key]
    if guid then
        self.newByLocation[key] = nil
        self.newByGUID[guid] = nil
    end
end

function Bags:Render()
    local frame = self:EnsureFrame()
    local db = GetDB()

    self:ReleaseAllButtons()
    self:HideSections()

    local contentWidth = max(260, ((frame.ScrollFrame and frame.ScrollFrame:GetWidth()) or frame.ScrollChild:GetWidth() or 1) - 8)
    local iconSize = max(24, min(54, tonumber(db.iconSize) or 34))
    local columns = max(6, min(20, tonumber(db.columns) or 12))
    local spacing = max(2, min(12, tonumber(db.itemSpacing) or 6))
    local sectionGap = max(8, min(24, tonumber(db.sectionSpacing) or 14))
    local showEmpty = db.showEmptyCategories == true
    local collapsed = db.collapsedSections or {}
    local displayOrder = self.data.displayOrder or BASE_CATEGORY_ORDER
    local headerHeight = 22

    frame.ScrollChild:SetWidth(contentWidth)

    local y = 0
    local visibleSections = 0

    for _, category in ipairs(displayOrder) do
        local items = self.data.byCategory[category] or {}
        if #items > 0 or showEmpty then
            visibleSections = visibleSections + 1
            local section = self:EnsureSection(frame.ScrollChild, category)
            section:ClearAllPoints()
            section:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 0, -y)
            section:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", 0, -y)
            section:SetFrameLevel(frame.ScrollChild:GetFrameLevel() + 2)

            section.Header:SetText(CATEGORY_LABELS[category] or category)
            section.Count:SetText(("%d items"):format(#items))
            local isCollapsed = collapsed[category] == true
            section.CollapseIndicator:SetText(isCollapsed and "+" or "-")
            section.Divider:SetShown(not isCollapsed)

            local rows = max(1, ceil(#items / columns))
            local sectionHeight = headerHeight + 6
            if not isCollapsed then
                sectionHeight = headerHeight + 6 + (rows * iconSize) + max(0, rows - 1) * spacing + 8
            end
            section:SetHeight(sectionHeight)
            section:Show()

            local xBase = 12
            local yBase = headerHeight + 4
            if not isCollapsed then
                for index, item in ipairs(items) do
                    local row = floor((index - 1) / columns)
                    local col = (index - 1) % columns
                    local button = self:AcquireButton(section)
                    button:ClearAllPoints()
                    button:SetSize(iconSize, iconSize)
                    button:SetPoint("TOPLEFT", section, "TOPLEFT", xBase + (col * (iconSize + spacing)),
                        -(yBase + row * (iconSize + spacing)))
                    button:SetFrameLevel(section:GetFrameLevel() + 10)
                    if button.Chrome then
                        button.Chrome:SetFrameLevel(button:GetFrameLevel() - 1)
                    end
                    button.itemData = item

                    local icon = button.icon or button.Icon or button.IconTexture
                    if icon then
                        icon:SetTexture(item.icon)
                        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
                        icon:SetDesaturated(item.isLocked == true)
                    end

                    if button.Count then
                        button.Count:SetText((item.count and item.count > 1) and item.count or "")
                    end

                    if button.IconBorder then
                        local color = _G.ITEM_QUALITY_COLORS and _G.ITEM_QUALITY_COLORS[item.quality or 1]
                        if color then
                            button.IconBorder:SetVertexColor(color.r, color.g, color.b, 0.85)
                            button.IconBorder:Show()
                        else
                            button.IconBorder:Hide()
                        end
                    end

                    local start, duration, enable = 0, 0, false
                    if C_Container and C_Container.GetContainerItemCooldown then
                        start, duration, enable = C_Container.GetContainerItemCooldown(item.bagID, item.slotID)
                    end
                    if button.Cooldown and CooldownFrame_Set then
                        CooldownFrame_Set(button.Cooldown, start or 0, duration or 0, enable and 1 or 0)
                    end

                    local isNew = item.guid and self.newByGUID[item.guid] ~= nil
                    if isNew and db.showNewItems ~= false then
                        button.NewOverlay:SetAlpha(0.55)
                        if not button.NewPulse:IsPlaying() then
                            button.NewPulse:Play()
                        end
                    else
                        button.NewPulse:Stop()
                        button.NewOverlay:SetAlpha(0)
                    end

                    self:ApplyMasqueState(button, false)

                    if button.SetBackdropColor and button.SetBackdropBorderColor then
                        button:SetBackdropColor(0.04, 0.05, 0.08, 0.95)
                        if isNew then
                            button:SetBackdropBorderColor(COLOR_ACCENT[1], COLOR_ACCENT[2], COLOR_ACCENT[3], 0.9)
                        else
                            button:SetBackdropBorderColor(0, 0, 0, 0.35)
                        end
                    elseif button.Chrome then
                        button.Chrome:SetBackdropColor(0.04, 0.05, 0.08, 0.95)
                        if isNew then
                            button.Chrome:SetBackdropBorderColor(COLOR_ACCENT[1], COLOR_ACCENT[2], COLOR_ACCENT[3], 0.9)
                        else
                            button.Chrome:SetBackdropBorderColor(0, 0, 0, 0.35)
                        end
                    end
                end
            end

            y = y + sectionHeight + sectionGap
        end
    end

    if visibleSections == 0 then
        local emptySection = self:EnsureSection(frame.ScrollChild, "__empty")
        emptySection:ClearAllPoints()
        emptySection:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 0, -0)
        emptySection:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", 0, -0)
        emptySection:SetHeight(80)
        emptySection.Header:SetText("No items")
        emptySection.Count:SetText("Your bags are empty.")
        emptySection:Show()
        y = 90
    else
        local emptySection = self.sectionFrames.__empty
        if emptySection then
            emptySection:Hide()
        end
    end

    frame.ScrollChild:SetHeight(max(1, y + 8))
end

function Bags:Refresh(force)
    if not self.frame then
        self:EnsureFrame()
    end

    if not self:IsEnabled() then
        return
    end

    self:HideBlizzardContainers()
    self:CollectItems()
    self:Render()

    if force then
        self:ApplyFrameStyle()
    end
end

function Bags:Show()
    local frame = self:EnsureFrame()
    frame:Show()
    frame:Raise()
    self:RequestRefresh(true)
end

function Bags:Hide()
    if self.frame then
        self.frame:Hide()
    end
end

function Bags:Toggle()
    local frame = self:EnsureFrame()
    if frame:IsShown() then
        self:Hide()
    else
        self:Show()
    end
end

function Bags:ShowBlizzardBackpackButtons(show)
    local targets = {
        "MainMenuBarBackpackButton",
        "CharacterBag0Slot",
        "CharacterBag1Slot",
        "CharacterBag2Slot",
        "CharacterBag3Slot",
        "CharacterReagentBag0Slot",
    }

    for _, name in ipairs(targets) do
        local frame = _G[name]
        if frame then
            if show then
                frame:SetAlpha(1)
                frame:Show()
            else
                frame:SetAlpha(0)
                frame:Hide()
            end
        end
    end
end

function Bags:HideBlizzardContainers()
    self:ShowBlizzardBackpackButtons(false)

    local combined = _G.ContainerFrameCombinedBags
    if combined and combined.Hide then
        combined:Hide()
    end

    for index = 1, 20 do
        local frame = _G["ContainerFrame" .. index]
        if frame and frame.Hide then
            frame:Hide()
        end
    end
end

function Bags:InstallBagHooks()
    if self.bagHooksInstalled then
        return
    end

    self.originalBagFuncs = {
        ToggleBackpack = _G.ToggleBackpack,
        OpenBackpack = _G.OpenBackpack,
        CloseBackpack = _G.CloseBackpack,
        ToggleAllBags = _G.ToggleAllBags,
        OpenAllBags = _G.OpenAllBags,
        CloseAllBags = _G.CloseAllBags,
        ToggleBag = _G.ToggleBag,
        OpenBag = _G.OpenBag,
        CloseBag = _G.CloseBag,
    }

    _G.ToggleBackpack = function()
        self:Toggle()
    end
    _G.OpenBackpack = function()
        self:Show()
    end
    _G.CloseBackpack = function()
        self:Hide()
    end
    _G.ToggleAllBags = function()
        self:Toggle()
    end
    _G.OpenAllBags = function()
        self:Show()
    end
    _G.CloseAllBags = function()
        self:Hide()
    end
    _G.ToggleBag = function()
        self:Toggle()
    end
    _G.OpenBag = function()
        self:Show()
    end
    _G.CloseBag = function()
        self:Hide()
    end

    self.bagHooksInstalled = true
end

function Bags:UninstallBagHooks()
    if not self.bagHooksInstalled then
        return
    end

    local originals = self.originalBagFuncs or {}
    for name, func in pairs(originals) do
        if type(func) == "function" then
            _G[name] = func
        end
    end

    self.originalBagFuncs = nil
    self.bagHooksInstalled = nil
end
