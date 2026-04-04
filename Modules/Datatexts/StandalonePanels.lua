---@diagnostic disable: inject-field, undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

local LSM = T.Libs and T.Libs.LSM or LibStub("LibSharedMedia-3.0", true)
local CreateFrame = _G.CreateFrame
local GameTooltip = _G.GameTooltip
local PlaySound = _G.PlaySound
local SOUNDKIT = _G.SOUNDKIT
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local UIParent = _G.UIParent

local SLOT_COUNT = 6
local FRAME_INSET = 6
local SLOT_GAP = 4
local PANEL_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 1, right = 1, top = 1, bottom = 1 },
}
local DRAG_HANDLE_BACKDROP = {
    bgFile = "Interface\\Buttons\\WHITE8X8",
    edgeFile = "Interface\\Buttons\\WHITE8X8",
    edgeSize = 1,
    insets = { left = 0, right = 0, top = 0, bottom = 0 },
}

local function GetOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule and configurationModule.Options and configurationModule.Options.Datatext or nil
end

local function GetStandaloneDB()
    local options = GetOptions()
    return options and options.GetStandaloneDB and options:GetStandaloneDB() or nil
end

local function GetStyleDB()
    local db = GetStandaloneDB()
    return db and db.style or nil
end

local function GetResolvedPanelStyle(panelID)
    local options = GetOptions()
    if options and options.GetResolvedStandaloneStyle then
        return options:GetResolvedStandaloneStyle(panelID)
    end

    return GetStyleDB()
end

local function GetFontPath(style)
    local fontName = style and style.font or nil
    if LSM and type(fontName) == "string" and fontName ~= "" then
        return LSM:Fetch("font", fontName, true) or STANDARD_TEXT_FONT
    end

    return STANDARD_TEXT_FONT
end

local function GetSortedPanelIDs(panels)
    local panelIDs = {}
    for panelID in pairs(panels or {}) do
        panelIDs[#panelIDs + 1] = panelID
    end

    table.sort(panelIDs, function(left, right)
        return tostring(left) < tostring(right)
    end)

    return panelIDs
end

local function AssignDefinitionPanel(definition, panel)
    if definition and definition.module then
        local target = DataTextModule.ResolveStandaloneCallbackTarget and
            DataTextModule:ResolveStandaloneCallbackTarget(definition.module, panel) or definition.module
        if target then
            target.panel = panel
        end
    end
end

local function GetPanelAssignment(panelDefinition, slotIndex)
    return panelDefinition and panelDefinition["slot" .. tostring(slotIndex)] or nil
end

local function HasAssignedDatatext(panelDefinition, segments)
    for slotIndex = 1, segments do
        local assignment = GetPanelAssignment(panelDefinition, slotIndex)
        if type(assignment) == "string" and assignment ~= "" and assignment ~= "NONE" then
            return true
        end
    end

    return false
end

local function ResolveMenuFlag(entry, key)
    local value = entry and entry[key] or nil
    if type(value) == "function" then
        local ok, result = pcall(value)
        return ok and result == true or false
    end

    return value == true
end

local function PlayInteractionClick()
    if type(PlaySound) == "function" and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON then
        PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
    end
end

local function CleanupStandaloneSlotState(slot)
    if not slot then
        return
    end

    local instance = slot.__twichuiStandaloneInstance
    if instance then
        if type(instance.ReleaseTooltipBars) == "function" then
            pcall(instance.ReleaseTooltipBars, instance)
        end

        if type(instance.ReleaseStandaloneResources) == "function" then
            pcall(instance.ReleaseStandaloneResources, instance)
        end

        if instance.clickButton and instance.clickButton.Hide then
            instance.clickButton:Hide()
            if instance.clickButton.EnableMouse then
                instance.clickButton:EnableMouse(false)
            end
        end

        if instance.trackerFrame and instance.trackerFrame.Hide then
            instance.trackerFrame:Hide()
        end
    end

    slot.__twichuiStandaloneInstance = nil
    slot.__twichuiStandaloneBaseModule = nil
end

local function EnsureStandaloneSlotInstance(slot, definition)
    local module = definition and definition.module or nil
    if type(module) ~= "table" then
        CleanupStandaloneSlotState(slot)
        return nil
    end

    if slot.__twichuiStandaloneBaseModule ~= module or not slot.__twichuiStandaloneInstance then
        CleanupStandaloneSlotState(slot)
        slot.__twichuiStandaloneInstance = setmetatable({
            baseModule = module,
            panel = slot,
            definition = definition,
            standalone = true,
        }, { __index = module })
        slot.__twichuiStandaloneBaseModule = module
    end

    return slot.__twichuiStandaloneInstance
end

local function CleanupStandalonePanel(frame)
    for slotIndex = 1, SLOT_COUNT do
        CleanupStandaloneSlotState(frame and frame.slots and frame.slots[slotIndex] or nil)
    end
end

local function HandleStandaloneSlotOnUpdate(self, elapsed)
    local definition = self and self.datatextDefinition or nil
    if not (definition and definition.onUpdateFunc) then
        return
    end

    AssignDefinitionPanel(definition, self)
    definition.onUpdateFunc(self, elapsed)
end

local function ApplySlotTextAlignment(slot, textAlign)
    if not (slot and slot.text) then
        return
    end

    local resolvedAlign = tostring(textAlign or "CENTER")
    if resolvedAlign ~= "LEFT" and resolvedAlign ~= "RIGHT" then
        resolvedAlign = "CENTER"
    end

    local availableWidth = math.max(1, (slot:GetWidth() or 0) - 16)
    local availableHeight = math.max(1, (slot:GetHeight() or 0) - 2)

    slot.text:ClearAllPoints()
    if resolvedAlign == "LEFT" then
        slot.text:SetPoint("LEFT", slot, "LEFT", 8, 0)
    elseif resolvedAlign == "RIGHT" then
        slot.text:SetPoint("RIGHT", slot, "RIGHT", -8, 0)
    else
        slot.text:SetPoint("CENTER", slot, "CENTER", 0, 0)
    end

    slot.text:SetWidth(availableWidth)
    slot.text:SetHeight(availableHeight)
    slot.text:SetJustifyH(resolvedAlign)
    slot.text:SetJustifyV("MIDDLE")
end

function DataTextModule:GetStandaloneDatatextChoices()
    local choices = {
        NONE = "None",
    }

    for name, definition in pairs(self.DatatextRegistry or {}) do
        choices[name] = definition.prettyName or name:gsub("^TwichUI:%s*", "")
    end

    return choices
end

function DataTextModule:ConvertMenuList(menuList)
    local converted = {}

    for _, entry in ipairs(menuList or {}) do
        if type(entry) == "table" and type(entry.text) == "string" and entry.text ~= "" then
            converted[#converted + 1] = {
                text = entry.text,
                tooltip = entry.tooltip,
                func = entry.func,
                item = entry.item,
                spell = entry.spell,
                macrotext = entry.macrotext,
                checked = ResolveMenuFlag(entry, "checked"),
                disabled = ResolveMenuFlag(entry, "disabled"),
                isTitle = entry.isTitle == true,
                isNotRadio = entry.isNotRadio == true,
                keepShownOnClick = entry.keepShownOnClick == true,
                notCheckable = entry.notCheckable == true or entry.isTitle == true,
            }
        end
    end

    return converted
end

function DataTextModule:ShowStandaloneMenu(panel, menuList)
    local ui = T.Tools and T.Tools.UI or nil
    local entries = self:ConvertMenuList(menuList)
    if not ui or #entries == 0 then
        return
    end

    if ui.CreateSecureMenu then
        if not self.standaloneMenu then
            self.standaloneMenu = ui.CreateSecureMenu("TwichUIStandaloneDataTextMenu")
            if self.standaloneMenu then
                self.standaloneMenu.RefreshEntries = function(menu)
                    menu:SetEntries(self:ConvertMenuList(menu.rawMenuList))
                end
            end
        end

        if self.standaloneMenu then
            self.standaloneMenu.rawMenuList = menuList
            self.standaloneMenu.styleOverride = GetResolvedPanelStyle(panel and panel.ownerPanel and
                panel.ownerPanel.panelID)
            self.standaloneMenu:SetEntries(entries)
            self.standaloneMenu:Toggle(panel, "TOPLEFT", "BOTTOMLEFT", 0, -4)
            return
        end
    end

    if ui.ShowSecureDropdown then
        ui.ShowSecureDropdown(entries, panel or UIParent)
    end
end

function DataTextModule:HideStandaloneMenu()
    if self.standaloneMenu and self.standaloneMenu.Hide then
        self.standaloneMenu.styleOverride = nil
        self.standaloneMenu:Hide()
    end
end

function DataTextModule:ForceRefreshStandaloneSlot(slot)
    local definition = slot and slot.datatextDefinition or nil
    if not definition then
        return
    end

    AssignDefinitionPanel(definition, slot)

    if definition.onEventFunc then
        definition.onEventFunc(slot, self.CommonEvents.ELVUI_FORCE_UPDATE)
        return
    end

    if definition.onUpdateFunc then
        definition.onUpdateFunc(slot, 0)
        return
    end

    if definition.module and type(definition.module.Refresh) == "function" then
        local target = self.ResolveStandaloneCallbackTarget and
            self:ResolveStandaloneCallbackTarget(definition.module, slot) or definition.module
        if target then
            target.panel = slot
            target:Refresh()
        end
    end
end

function DataTextModule:HandleStandaloneEvent(slot, event, ...)
    local definition = slot and slot.datatextDefinition or nil
    if not definition then
        return
    end

    AssignDefinitionPanel(definition, slot)

    if definition.onEventFunc then
        definition.onEventFunc(slot, event, ...)
    elseif event == "PLAYER_ENTERING_WORLD" then
        self:ForceRefreshStandaloneSlot(slot)
    end
end

local function CreateStandaloneSlot(frame, slotIndex)
    local slot = CreateFrame("Button", nil, frame, "BackdropTemplate")
    slot:SetFrameLevel((frame:GetFrameLevel() or 1) + 5)
    slot:EnableMouse(true)
    slot:RegisterForClicks("AnyUp")
    slot.ownerPanel = frame
    slot.slotIndex = slotIndex
    slot.__twichuiStandalonePanel = true
    slot:SetHitRectInsets(0, 0, 0, 0)

    slot.highlight = slot:CreateTexture(nil, "HIGHLIGHT")
    slot.highlight:SetAllPoints(slot)
    slot.highlight:SetColorTexture(1, 1, 1, 0.04)
    slot.highlight:SetAlpha(0)

    slot.fill = slot:CreateTexture(nil, "BACKGROUND")
    slot.fill:SetAllPoints(slot)
    slot.fill:SetColorTexture(1, 1, 1, 0.018)

    slot.hoverGlow = slot:CreateTexture(nil, "ARTWORK")
    slot.hoverGlow:SetAllPoints(slot)
    slot.hoverGlow:SetColorTexture(0.96, 0.76, 0.24, 0.08)
    slot.hoverGlow:SetAlpha(0)

    slot.hoverBar = slot:CreateTexture(nil, "ARTWORK")
    slot.hoverBar:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 6, 0)
    slot.hoverBar:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -6, 0)
    slot.hoverBar:SetHeight(1)
    slot.hoverBar:SetColorTexture(0.96, 0.76, 0.24, 0.9)
    slot.hoverBar:SetAlpha(0)

    slot.text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ApplySlotTextAlignment(slot, "CENTER")
    slot.text:SetWordWrap(false)

    slot:SetScript("OnEvent", function(self, event, ...)
        DataTextModule:HandleStandaloneEvent(self, event, ...)
    end)

    slot:SetScript("OnEnter", function(self)
        local definition = self.datatextDefinition
        self.__twichuiLeaveRequest = (self.__twichuiLeaveRequest or 0) + 1
        self.highlight:SetAlpha(1)
        self.hoverGlow:SetAlpha(1)
        self.hoverBar:SetAlpha(1)
        if not definition then
            return
        end

        DataTextModule:SetTooltipOwner(self)
        AssignDefinitionPanel(definition, self)
        if definition.onEnterFunc then
            definition.onEnterFunc(self)
        end
    end)

    slot:SetScript("OnLeave", function(self)
        local definition = self.datatextDefinition
        self.highlight:SetAlpha(0)
        self.hoverGlow:SetAlpha(0)
        self.hoverBar:SetAlpha(0)

        if definition and definition.onLeaveFunc then
            AssignDefinitionPanel(definition, self)
            definition.onLeaveFunc(self)
            return
        end

        DataTextModule:RunDeferredPanelLeave(self, function()
            local tooltip = DataTextModule:GetStandaloneTooltip()
            if tooltip and tooltip.Hide then
                DataTextModule:HideDatatextTooltip(tooltip)
            end

            DataTextModule:ClearTooltipOwner(self)
        end)
    end)

    slot:SetScript("OnClick", function(self, button)
        local definition = self.datatextDefinition
        if not definition or not definition.onClickFunc then
            return
        end

        PlayInteractionClick()
        AssignDefinitionPanel(definition, self)
        definition.onClickFunc(self, button)
    end)

    frame.slots[slotIndex] = slot
    return slot
end

local function ApplyPanelBackdrop(frame, style)
    if frame and frame.SetBackdrop and not frame.__twichuiBackdropInitialized then
        frame:SetBackdrop(PANEL_BACKDROP)
        frame.__twichuiBackdropInitialized = true
    end

    frame:SetBackdropColor(style.backgroundColor[1], style.backgroundColor[2], style.backgroundColor[3],
        style.backgroundAlpha)
    frame:SetBackdropBorderColor(style.borderColor[1], style.borderColor[2], style.borderColor[3], style.borderAlpha)
end

function DataTextModule:EnsureStandalonePanelFrame(panelID)
    self.standalonePanels = self.standalonePanels or {}

    local frame = self.standalonePanels[panelID]
    if frame then
        return frame
    end

    frame = CreateFrame("Frame", "TwichUIStandaloneDataText_" .. panelID, UIParent, "BackdropTemplate")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:SetFrameStrata("LOW")
    frame.defaultFrameStrata = frame:GetFrameStrata() or "LOW"
    frame.panelID = panelID
    frame.slots = {}
    frame.dividers = {}

    frame.accent = frame:CreateTexture(nil, "ARTWORK")
    frame.accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.accent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.accent:SetHeight(2)

    frame.glow = frame:CreateTexture(nil, "BACKGROUND")
    frame.glow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.glow:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.glow:SetHeight(12)

    frame.innerGlow = frame:CreateTexture(nil, "BORDER")
    frame.innerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.innerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)

    frame.bottomGlow = frame:CreateTexture(nil, "BACKGROUND")
    frame.bottomGlow:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 1, 1)
    frame.bottomGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.bottomGlow:SetHeight(10)

    frame.dragHandle = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.dragHandle:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.dragHandle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", 0, 0)
    frame.dragHandle:SetHeight(6)
    frame.dragHandle:EnableMouse(true)
    frame.dragHandle:RegisterForDrag("LeftButton")
    frame.dragHandle:SetScript("OnDragStart", function(handle)
        local db = GetStandaloneDB()
        if not db or db.locked == true then
            return
        end

        handle:GetParent():StartMoving()
    end)
    frame.dragHandle:SetScript("OnDragStop", function(handle)
        local parent = handle:GetParent()
        parent:StopMovingOrSizing()

        local point, _, relativePoint, x, y = parent:GetPoint(1)
        local db = GetStandaloneDB()
        local panelDefinition = db and db.panels and db.panels[parent.panelID] or nil
        if panelDefinition then
            panelDefinition.point = point or panelDefinition.point
            panelDefinition.relativePoint = relativePoint or panelDefinition.relativePoint
            panelDefinition.x = x or 0
            panelDefinition.y = y or 0
        end
    end)

    for slotIndex = 1, SLOT_COUNT do
        CreateStandaloneSlot(frame, slotIndex)
        if slotIndex < SLOT_COUNT then
            local divider = frame:CreateTexture(nil, "BORDER")
            divider:SetWidth(1)
            frame.dividers[slotIndex] = divider
        end
    end

    self.standalonePanels[panelID] = frame
    return frame
end

function DataTextModule:ApplyStandalonePanelStyle(frame, panelDefinition)
    local style = GetResolvedPanelStyle(panelDefinition and panelDefinition.id)
    if not (frame and style and panelDefinition) then
        return
    end

    ApplyPanelBackdrop(frame, style)
    frame.accent:SetColorTexture(style.accentColor[1], style.accentColor[2], style.accentColor[3], style.accentAlpha)
    frame.glow:SetColorTexture(style.accentColor[1], style.accentColor[2], style.accentColor[3], 0)
    frame.innerGlow:SetColorTexture(style.accentColor[1], style.accentColor[2], style.accentColor[3], 0)
    frame.bottomGlow:SetColorTexture(style.accentColor[1], style.accentColor[2], style.accentColor[3], 0)

    if frame.dragHandle and frame.dragHandle.SetBackdrop then
        if not frame.dragHandle.__twichuiBackdropInitialized then
            frame.dragHandle:SetBackdrop(DRAG_HANDLE_BACKDROP)
            frame.dragHandle.__twichuiBackdropInitialized = true
        end
        frame.dragHandle:SetBackdropColor(style.accentColor[1], style.accentColor[2], style.accentColor[3], 0.14)
        frame.dragHandle:SetBackdropBorderColor(style.accentColor[1], style.accentColor[2], style.accentColor[3], 0)
    end

    local fontPath = GetFontPath(style)
    local fontFlags = style.fontOutline == true and "OUTLINE" or ""
    local textAlign = tostring(style.textAlign or "CENTER")
    if textAlign ~= "LEFT" and textAlign ~= "RIGHT" then
        textAlign = "CENTER"
    end

    for slotIndex = 1, SLOT_COUNT do
        local slot = frame.slots[slotIndex]
        if slot and slot.text then
            slot.text:SetFont(fontPath, style.fontSize, fontFlags)
            ApplySlotTextAlignment(slot, textAlign)
            slot.text:SetShadowColor(0, 0, 0, style.textShadowAlpha)
            slot.text:SetShadowOffset(1, -1)
            slot.text:SetTextColor(0.96, 0.97, 0.99)
            slot.fill:SetColorTexture(style.accentColor[1], style.accentColor[2], style.accentColor[3], 0)
            local hgc = style.hoverGlowColor or style.accentColor
            slot.hoverGlow:SetColorTexture(hgc[1], hgc[2], hgc[3], style.hoverGlowAlpha or 0.09)
            local hbc = style.hoverBarColor or style.accentColor
            slot.hoverBar:SetColorTexture(hbc[1], hbc[2], hbc[3], style.hoverBarAlpha or 0.92)
        end

        local divider = frame.dividers[slotIndex]
        if divider then
            divider:SetColorTexture(style.borderColor[1], style.borderColor[2], style.borderColor[3], style.dividerAlpha)
        end
    end

    frame.dragHandle:SetShown(style.showDragHandle == true and GetStandaloneDB() and GetStandaloneDB().locked ~= true)
end

function DataTextModule:ConfigureStandaloneSlot(slot, panelDefinition, slotIndex, segments)
    local previousDefinition = slot.datatextDefinition

    if slotIndex > segments then
        slot.datatextDefinition = nil
        if slot.__twichuiStandaloneEventsRegistered then
            slot:UnregisterAllEvents()
            slot.__twichuiStandaloneEventsRegistered = false
        end
        if slot.__twichuiHasOnUpdate then
            slot:SetScript("OnUpdate", nil)
            slot.__twichuiHasOnUpdate = false
        end
        CleanupStandaloneSlotState(slot)
        slot:Hide()
        return
    end

    local definitionName = GetPanelAssignment(panelDefinition, slotIndex)
    local definition = definitionName and definitionName ~= "NONE" and self.DatatextRegistry and
        self.DatatextRegistry[definitionName] or nil
    local definitionChanged = previousDefinition ~= definition

    if definitionChanged then
        CleanupStandaloneSlotState(slot)
    end

    slot.datatextDefinition = definition

    if not definition then
        if slot.__twichuiStandaloneEventsRegistered then
            slot:UnregisterAllEvents()
            slot.__twichuiStandaloneEventsRegistered = false
        end
        if slot.__twichuiHasOnUpdate then
            slot:SetScript("OnUpdate", nil)
            slot.__twichuiHasOnUpdate = false
        end
        slot:EnableMouse(false)
        slot.text:SetText("")
        slot:Show()
        return
    end

    slot:EnableMouse(true)
    EnsureStandaloneSlotInstance(slot, definition)

    if definitionChanged or not slot.__twichuiStandaloneEventsRegistered then
        slot:UnregisterAllEvents()
        if type(definition.events) == "table" then
            for _, eventName in ipairs(definition.events) do
                if eventName ~= self.CommonEvents.ELVUI_FORCE_UPDATE and eventName ~= self.CommonEvents.TWICHUI_FORCE_UPDATE then
                    slot:RegisterEvent(eventName)
                end
            end
        end
        slot:RegisterEvent("PLAYER_ENTERING_WORLD")
        slot.__twichuiStandaloneEventsRegistered = true
    end

    if definition.onUpdateFunc then
        if not slot.__twichuiHasOnUpdate then
            slot:SetScript("OnUpdate", HandleStandaloneSlotOnUpdate)
            slot.__twichuiHasOnUpdate = true
        end
    elseif slot.__twichuiHasOnUpdate then
        slot:SetScript("OnUpdate", nil)
        slot.__twichuiHasOnUpdate = false
    end

    slot.text:SetTextColor(0.96, 0.97, 0.99)
    slot:Show()
    self:ForceRefreshStandaloneSlot(slot)
end

function DataTextModule:LayoutStandalonePanel(frame, panelDefinition)
    local segments = math.max(1, math.min(SLOT_COUNT, tonumber(panelDefinition.segments) or SLOT_COUNT))
    local hasAssignments = HasAssignedDatatext(panelDefinition, segments)
    local innerWidth = math.max(1, (frame:GetWidth() or 1) - (FRAME_INSET * 2))
    local slotWidth = (innerWidth - ((segments - 1) * SLOT_GAP)) / segments
    local style = GetResolvedPanelStyle(panelDefinition and panelDefinition.id)
    local textAlign = style and style.textAlign or "CENTER"

    for slotIndex = 1, SLOT_COUNT do
        local slot = frame.slots[slotIndex]
        slot:ClearAllPoints()

        if slotIndex <= segments then
            local leftOffset = FRAME_INSET + ((slotIndex - 1) * (slotWidth + SLOT_GAP))
            slot:SetPoint("TOPLEFT", frame, "TOPLEFT", leftOffset, -FRAME_INSET)
            slot:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", leftOffset, FRAME_INSET)
            slot:SetWidth(slotWidth)
            ApplySlotTextAlignment(slot, textAlign)
        end

        local divider = frame.dividers[slotIndex]
        if divider then
            if hasAssignments and slotIndex < segments then
                local dividerOffset = FRAME_INSET + (slotIndex * slotWidth) + ((slotIndex - 1) * SLOT_GAP) +
                    (SLOT_GAP * 0.5)
                divider:ClearAllPoints()
                divider:SetPoint("TOPLEFT", frame, "TOPLEFT", dividerOffset, -7)
                divider:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", dividerOffset, 7)
                divider:Show()
            else
                divider:Hide()
            end
        end

        self:ConfigureStandaloneSlot(slot, panelDefinition, slotIndex, segments)
    end
end

function DataTextModule:ApplyStandalonePanelPosition(frame, panelDefinition)
    frame:ClearAllPoints()
    local point = panelDefinition.point or "BOTTOM"
    local relPoint = panelDefinition.relativePoint or point
    local x = panelDefinition.x or 0
    local y = panelDefinition.y or 0

    -- The PANEL_BACKDROP has edgeSize=1 with insets={bottom=1}, meaning the
    -- visible filled area starts 1px above the frame's actual bottom edge.
    -- When the panel is flush-bottom anchored at y=0 this creates a visible
    -- 1-2px gap between the panel and the screen edge.  Compensate by nudging
    -- the frame 1px below the screen edge so the backdrop fill aligns flush.
    if (point == "BOTTOM" or point == "BOTTOMLEFT" or point == "BOTTOMRIGHT")
        and relPoint == point and y == 0
    then
        y = -1
    end

    frame:SetPoint(point, UIParent, relPoint, x, y)
end

function DataTextModule:RefreshStandalonePanels()
    local db = GetStandaloneDB()
    self.standalonePanels = self.standalonePanels or {}

    if not db or db.enabled ~= true then
        self:HideStandalonePanels()
        return
    end

    local activePanels = {}
    for _, panelID in ipairs(GetSortedPanelIDs(db.panels or {})) do
        local panelDefinition = db.panels[panelID]
        local frame = self:EnsureStandalonePanelFrame(panelID)
        activePanels[panelID] = true

        if panelDefinition and panelDefinition.enabled ~= false then
            frame:SetSize(panelDefinition.width or 360, panelDefinition.height or 28)
            self:ApplyStandalonePanelPosition(frame, panelDefinition)
            self:ApplyStandalonePanelStyle(frame, panelDefinition)
            self:LayoutStandalonePanel(frame, panelDefinition)
            frame:Show()
        else
            CleanupStandalonePanel(frame)
            frame:Hide()
        end
    end

    for panelID, frame in pairs(self.standalonePanels) do
        if not activePanels[panelID] then
            CleanupStandalonePanel(frame)
            frame:Hide()
        end
    end

    -- (Re-)register visible panels with the central mover system.
    C_Timer.After(0, function() DataTextModule:RegisterStandalonePanelsWithMoverModule() end)
end

-- ── Central Mover System registration ────────────────────────────────────────
-- Called from RefreshStandalonePanels so the registry stays in sync whenever
-- the user adds, removes, or reconfigures panels.
function DataTextModule:RegisterStandalonePanelsWithMoverModule()
    local moversModule = _G.TwichMoverModule
    if not moversModule or type(moversModule.RegisterMover) ~= "function" then return end

    local db = GetStandaloneDB()
    if not db or not db.panels then return end

    for panelID, panelDefinition in pairs(db.panels) do
        if not panelDefinition then
        else
            local pid = panelID  -- capture for closure
            moversModule:RegisterMover("SP_" .. pid, {
                label    = "Panel: " .. tostring(pid),
                category = "Datatexts",
                getX     = function()
                    local xdb = GetStandaloneDB()
                    local pd  = xdb and xdb.panels and xdb.panels[pid]
                    return pd and (pd.x or 0) or 0
                end,
                getY     = function()
                    local xdb = GetStandaloneDB()
                    local pd  = xdb and xdb.panels and xdb.panels[pid]
                    return pd and (pd.y or 0) or 0
                end,
                getPoint = function()
                    local xdb = GetStandaloneDB()
                    local pd  = xdb and xdb.panels and xdb.panels[pid]
                    return pd and pd.point or "BOTTOMLEFT"
                end,
                getRelativePoint = function()
                    local xdb = GetStandaloneDB()
                    local pd  = xdb and xdb.panels and xdb.panels[pid]
                    return pd and (pd.relativePoint or pd.point) or "BOTTOMLEFT"
                end,
                getW     = function()
                    local xdb = GetStandaloneDB()
                    local pd  = xdb and xdb.panels and xdb.panels[pid]
                    return pd and pd.width or nil
                end,
                getH     = function()
                    local xdb = GetStandaloneDB()
                    local pd  = xdb and xdb.panels and xdb.panels[pid]
                    return pd and pd.height or nil
                end,
                setPos   = function(x, y)
                    local xdb = GetStandaloneDB()
                    local pd  = xdb and xdb.panels and xdb.panels[pid]
                    if pd then
                        pd.point         = "BOTTOMLEFT"
                        pd.relativePoint = "BOTTOMLEFT"
                        pd.x             = x
                        pd.y             = y
                        local frame = DataTextModule.standalonePanels and DataTextModule.standalonePanels[pid]
                        if frame then
                            frame:ClearAllPoints()
                            frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
                        end
                    end
                end,
                setSize  = nil,   -- panel width/height managed in configuration panel
                isEnabled = function()
                    local xdb = GetStandaloneDB()
                    local pd  = xdb and xdb.panels and xdb.panels[pid]
                    return not pd or pd.enabled ~= false
                end,
            })
        end
    end
end

function DataTextModule:HideStandalonePanels()
    for _, frame in pairs(self.standalonePanels or {}) do
        CleanupStandalonePanel(frame)
        frame:Hide()
    end

    local tooltip = self:GetStandaloneTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end

    self:HideStandaloneMenu()
end

function DataTextModule:RefreshStandaloneDataText(datatextName)
    for _, frame in pairs(self.standalonePanels or {}) do
        for slotIndex = 1, SLOT_COUNT do
            local slot = frame.slots and frame.slots[slotIndex] or nil
            local definition = slot and slot.datatextDefinition or nil
            if definition and definition.name == datatextName then
                self:ForceRefreshStandaloneSlot(slot)
            end
        end
    end
    -- Also refresh any embedded bars (e.g. chat header)
    for _, bar in pairs(self.embeddedPanels or {}) do
        for slotIndex = 1, (bar.maxSlots or SLOT_COUNT) do
            local slot = bar.slots and bar.slots[slotIndex] or nil
            local definition = slot and slot.datatextDefinition or nil
            if definition and definition.name == datatextName then
                self:ForceRefreshStandaloneSlot(slot)
            end
        end
    end
end

-- ---------------------------------------------------------------------------
-- Embedded Datatext Bar
-- Lightweight bars parented to an existing frame (e.g. chat header).
-- No backdrop, drag handle, or decorations -- caller owns positioning/style.
-- ---------------------------------------------------------------------------

local EMBEDDED_FRAME_INSET = 3
local EMBEDDED_SLOT_GAP = 3

local function CreateEmbeddedSlot(bar, slotIndex)
    local slot = CreateFrame("Button", nil, bar)
    slot:SetFrameLevel((bar:GetFrameLevel() or 1) + 2)
    slot:EnableMouse(true)
    slot:RegisterForClicks("AnyUp")
    slot.ownerPanel = bar
    slot.slotIndex = slotIndex
    slot.__twichuiStandalonePanel = true
    slot.__twichuiEmbeddedSlot = true
    slot:SetHitRectInsets(0, 0, 0, 0)

    slot.highlight = slot:CreateTexture(nil, "HIGHLIGHT")
    slot.highlight:SetAllPoints(slot)
    slot.highlight:SetColorTexture(1, 1, 1, 0.05)
    slot.highlight:SetAlpha(0)

    slot.hoverGlow = slot:CreateTexture(nil, "ARTWORK")
    slot.hoverGlow:SetAllPoints(slot)
    slot.hoverGlow:SetColorTexture(0.96, 0.76, 0.24, 0.09)
    slot.hoverGlow:SetAlpha(0)

    slot.hoverBar = slot:CreateTexture(nil, "ARTWORK")
    slot.hoverBar:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", 4, 0)
    slot.hoverBar:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -4, 0)
    slot.hoverBar:SetHeight(1)
    slot.hoverBar:SetColorTexture(0.96, 0.76, 0.24, 0.9)
    slot.hoverBar:SetAlpha(0)

    slot.text = slot:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    ApplySlotTextAlignment(slot, "CENTER")
    slot.text:SetWordWrap(false)

    slot:SetScript("OnEvent", function(self, event, ...)
        DataTextModule:HandleStandaloneEvent(self, event, ...)
    end)

    slot:SetScript("OnEnter", function(self)
        local definition = self.datatextDefinition
        self.__twichuiLeaveRequest = (self.__twichuiLeaveRequest or 0) + 1
        self.highlight:SetAlpha(1)
        self.hoverGlow:SetAlpha(1)
        self.hoverBar:SetAlpha(1)
        if not definition then return end
        DataTextModule:SetTooltipOwner(self)
        AssignDefinitionPanel(definition, self)
        if definition.onEnterFunc then
            definition.onEnterFunc(self)
        end
    end)

    slot:SetScript("OnLeave", function(self)
        local definition = self.datatextDefinition
        self.highlight:SetAlpha(0)
        self.hoverGlow:SetAlpha(0)
        self.hoverBar:SetAlpha(0)
        if definition and definition.onLeaveFunc then
            AssignDefinitionPanel(definition, self)
            definition.onLeaveFunc(self)
            return
        end
        DataTextModule:RunDeferredPanelLeave(self, function()
            local tooltip = DataTextModule:GetStandaloneTooltip()
            if tooltip and tooltip.Hide then
                DataTextModule:HideDatatextTooltip(tooltip)
            end
            DataTextModule:ClearTooltipOwner(self)
        end)
    end)

    slot:SetScript("OnClick", function(self, button)
        local definition = self.datatextDefinition
        if not definition or not definition.onClickFunc then return end
        PlayInteractionClick()
        AssignDefinitionPanel(definition, self)
        definition.onClickFunc(self, button)
    end)

    bar.slots[slotIndex] = slot
    return slot
end

--- Creates (or retrieves) a lightweight datatext bar Frame parented to parentFrame.
--- The bar has no backdrop, glow, or drag handle -- visual styling is handled externally.
--- @param parentFrame Frame The frame to parent the bar to.
--- @param barID string A unique identifier for the bar.
--- @param maxSlots number? Maximum number of slots (1-6, default 3).
function DataTextModule:EnsureEmbeddedDatatextBar(parentFrame, barID, maxSlots)
    self.embeddedPanels = self.embeddedPanels or {}

    local bar = self.embeddedPanels[barID]
    if bar then
        return bar
    end

    maxSlots = math.max(1, math.min(SLOT_COUNT, tonumber(maxSlots) or 3))

    bar = CreateFrame("Frame", "TwichUIEmbeddedDT_" .. barID, parentFrame)
    bar:SetFrameLevel((parentFrame:GetFrameLevel() or 1) + 6)
    bar:EnableMouse(false)
    bar.panelID = barID
    bar.maxSlots = maxSlots
    bar.slots = {}
    bar.dividers = {}
    bar.__twichuiEmbeddedBar = true
    bar.defaultFrameStrata = parentFrame:GetFrameStrata() or "MEDIUM"

    for slotIndex = 1, maxSlots do
        CreateEmbeddedSlot(bar, slotIndex)
        if slotIndex < maxSlots then
            local divider = bar:CreateTexture(nil, "BORDER")
            divider:SetWidth(1)
            bar.dividers[slotIndex] = divider
        end
    end

    self.embeddedPanels[barID] = bar
    return bar
end

--- Configures and lays out an embedded datatext bar from a panel definition table.
--- @param barID string The bar identifier from EnsureEmbeddedDatatextBar.
--- @param panelDefinition table Panel definition (slot1..slotN, segments fields).
--- @param styleTable table? Optional style: font, fontSize, accentR/G/B.
function DataTextModule:RefreshEmbeddedBar(barID, panelDefinition, styleTable)
    local bar = self.embeddedPanels and self.embeddedPanels[barID] or nil
    if not (bar and panelDefinition) then return end

    local maxSlots = bar.maxSlots or SLOT_COUNT
    local segments = math.max(1, math.min(maxSlots, tonumber(panelDefinition.segments) or maxSlots))

    -- Configure slot datatext assignments
    for slotIndex = 1, maxSlots do
        self:ConfigureStandaloneSlot(bar.slots[slotIndex], panelDefinition, slotIndex, segments)
    end

    -- Lay out slots within the bar
    local barWidth = math.max(1, bar:GetWidth() or 1)
    local innerWidth = math.max(1, barWidth - (EMBEDDED_FRAME_INSET * 2))
    local slotWidth = (innerWidth - ((segments - 1) * EMBEDDED_SLOT_GAP)) / segments
    local textAlign = (styleTable and styleTable.textAlign) or "CENTER"

    for slotIndex = 1, maxSlots do
        local slot = bar.slots[slotIndex]
        if not slot then break end
        slot:ClearAllPoints()
        if slotIndex <= segments then
            local leftOffset = EMBEDDED_FRAME_INSET + ((slotIndex - 1) * (slotWidth + EMBEDDED_SLOT_GAP))
            slot:SetPoint("TOPLEFT", bar, "TOPLEFT", leftOffset, 0)
            slot:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", leftOffset, 0)
            slot:SetWidth(slotWidth)
            ApplySlotTextAlignment(slot, textAlign)
        end
        local divider = bar.dividers[slotIndex]
        if divider then
            if slotIndex < segments then
                local divOffset = EMBEDDED_FRAME_INSET + (slotIndex * slotWidth) +
                    ((slotIndex - 1) * EMBEDDED_SLOT_GAP) + (EMBEDDED_SLOT_GAP * 0.5)
                divider:ClearAllPoints()
                divider:SetPoint("TOPLEFT", bar, "TOPLEFT", divOffset, -3)
                divider:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", divOffset, 3)
                divider:Show()
            else
                divider:Hide()
            end
        end
    end

    -- Apply text and accent style to slots
    if styleTable then
        local fontPath = STANDARD_TEXT_FONT
        if LSM and styleTable.font then
            fontPath = LSM:Fetch("font", styleTable.font, true) or STANDARD_TEXT_FONT
        end
        local fontSize = tonumber(styleTable.fontSize) or 11
        local fontFlags = styleTable.fontOutline and "OUTLINE" or ""
        local aR = styleTable.accentR or 0.96
        local aG = styleTable.accentG or 0.76
        local aB = styleTable.accentB or 0.24
        for slotIndex = 1, maxSlots do
            local slot = bar.slots[slotIndex]
            if slot then
                if slot.text then
                    slot.text:SetFont(fontPath, fontSize, fontFlags)
                    local tR = tonumber(styleTable.textR) or 0.92
                    local tG = tonumber(styleTable.textG) or 0.94
                    local tB = tonumber(styleTable.textB) or 0.96
                    slot.text:SetTextColor(tR, tG, tB)
                    slot.text:SetShadowColor(0, 0, 0, 0.5)
                    slot.text:SetShadowOffset(1, -1)
                end
                if slot.hoverBar then
                    slot.hoverBar:SetColorTexture(aR, aG, aB, 0.9)
                end
                if slot.hoverGlow then
                    slot.hoverGlow:SetColorTexture(aR, aG, aB, 0.09)
                end
            end
            local divider = bar.dividers[slotIndex]
            if divider then
                divider:SetColorTexture(aR, aG, aB, 0.18)
            end
        end
    end
end

--- Cleans up and hides an embedded datatext bar.
--- @param barID string The bar identifier.
function DataTextModule:HideEmbeddedBar(barID)
    local bar = self.embeddedPanels and self.embeddedPanels[barID] or nil
    if not bar then return end
    for slotIndex = 1, (bar.maxSlots or SLOT_COUNT) do
        CleanupStandaloneSlotState(bar.slots and bar.slots[slotIndex] or nil)
    end
    bar:Hide()
end
