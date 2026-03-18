local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@class UISecure
local UI = Tools.UI or {}
Tools.UI = UI

local _G = _G
local tinsert = tinsert
local pairs = pairs
local type = type
local tonumber = tonumber
local InCombatLockdown = InCombatLockdown

-- Store pending macro executions
local pendingMacros = {}

local function ProcessPendingMacros()
    if #pendingMacros == 0 then
        return
    end

    if InCombatLockdown and InCombatLockdown() then
        pendingMacros = {}
        return
    end

    local callback = table.remove(pendingMacros, 1)
    if callback and type(callback) == "function" then
        callback()
    end

    if #pendingMacros > 0 then
        _G.C_Timer.After(0.01, ProcessPendingMacros)
    end
end

---@class TwichUISecureMenuEntry
---@field text string           -- Display text (already includes any icon formatting)
---@field width number|nil      -- Optional fixed width for this row
---@field tooltip string|nil    -- Optional tooltip text
---@field macrotext string|nil  -- If set, runs as a secure macro: type="macro", macrotext
---@field item string|number|nil-- If set, secure type="item", attribute "item"
---@field spell string|number|nil -- If set, secure type="spell", attribute "spell"
---@field disabled boolean|nil  -- If true, row is visible but not clickable

---@class TwichUISecureMenu
---@field frame Frame
---@field buttons Button[]
---@field entries TwichUISecureMenuEntry[]
---@field Toggle fun(self:TwichUISecureMenu, anchor:Frame, point:string|nil, relativePoint:string|nil, x:number|nil, y:number|nil)
---@field Hide fun(self:TwichUISecureMenu)
---@field SetEntries fun(self:TwichUISecureMenu, entries:TwichUISecureMenuEntry[])

local function GetBorderAndBackdrop()
    ---@diagnostic disable-next-line: undefined-field
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.media and E.media.bordercolor and E.media.backdropfadecolor then
        local br, bg, bb = unpack(E.media.bordercolor)
        local fr, fg, fb, fa = unpack(E.media.backdropfadecolor)
        return br or 0, bg or 0, bb or 0, fr or 0.06, fg or 0.06, fb or 0.06, fa or 0.9
    end
    return 0, 0, 0, 0.06, 0.06, 0.06, 0.9
end

local function SkinBackdrop(frame)
    local br, bg, bb, fr, fg, fb, fa = GetBorderAndBackdrop()
    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(fr, fg, fb, fa)
    frame:SetBackdropBorderColor(br, bg, bb, 1)
end

local function CreateRow(menu, index)
    local parent = menu.frame
    local button = CreateFrame("Button", nil, parent, "SecureActionButtonTemplate,BackdropTemplate")
    button:SetHeight(20)
    button:SetFrameStrata(parent:GetFrameStrata())
    button:SetFrameLevel(parent:GetFrameLevel() + 1)
    button:SetPoint("LEFT", parent, "LEFT", 4, 0)
    button:SetPoint("RIGHT", parent, "RIGHT", -4, 0)

    if index == 1 then
        button:SetPoint("TOP", parent, "TOP", 0, -4)
    else
        local prev = menu.buttons[index - 1]
        button:SetPoint("TOP", prev, "BOTTOM", 0, -1)
    end

    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    SkinBackdrop(button)

    local label = button:CreateFontString(nil, "OVERLAY")
    label:SetPoint("LEFT", button, "LEFT", 6, 0)
    label:SetPoint("RIGHT", button, "RIGHT", -6, 0)
    label:SetJustifyH("LEFT")

    local fontObj = _G.GameFontHighlightSmall or _G.GameFontNormalSmall or _G.GameFontHighlight
    if fontObj and label.SetFontObject then
        label:SetFontObject(fontObj)
    end

    button.__twichuiLabel = label

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(1, 1, 1, 1)
        local entry = self.__twichuiEntry
        if entry and entry.tooltip and _G.GameTooltip then
            _G.GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            _G.GameTooltip:SetText(entry.tooltip, 1, 1, 1, true)
            _G.GameTooltip:Show()
        end
    end)

    button:SetScript("OnLeave", function(self)
        local br, bg, bb = GetBorderAndBackdrop()
        self:SetBackdropBorderColor(br, bg, bb, 1)
        if _G.GameTooltip then
            _G.GameTooltip:Hide()
        end
    end)



    menu.buttons[index] = button
    return button
end

---@param key string
---@return TwichUISecureMenu
function UI.CreateSecureMenu(key)
    local frame = CreateFrame("Frame", key, _G.UIParent, "SecureFrameTemplate,BackdropTemplate")
    frame:SetSize(200, 10)
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(300)
    frame:SetClampedToScreen(true)
    frame:Hide()

    SkinBackdrop(frame)

    local menu = {
        frame = frame,
        buttons = {},
        entries = {},
    }

    ---@param entries TwichUISecureMenuEntry[]
    function menu:SetEntries(entries)
        self.entries = entries or {}

        local visible = 0
        for i = 1, #self.entries do
            local entry = self.entries[i]
            if entry and type(entry.text) == "string" and entry.text ~= "" then
                visible = visible + 1
                local row = self.buttons[visible] or CreateRow(self, visible)
                row.__twichuiEntry = entry

                row.__twichuiLabel:SetText(entry.text)

                -- Clear previous attributes
                row:SetAttribute("type", nil)
                row:SetAttribute("item", nil)
                row:SetAttribute("spell", nil)
                row:SetAttribute("macrotext", nil)

                -- Set secure attributes based on entry type
                if entry.item then
                    row:SetAttribute("type", "item")
                    row:SetAttribute("item", entry.item)
                elseif entry.spell then
                    row:SetAttribute("type", "spell")
                    row:SetAttribute("spell", entry.spell)
                elseif entry.macrotext then
                    row:SetAttribute("type", "macro")
                    row:SetAttribute("macrotext", entry.macrotext)
                end

                if entry.disabled then
                    row:EnableMouse(false)
                    row:SetAlpha(0.5)
                else
                    row:EnableMouse(true)
                    row:SetAlpha(1.0)
                end

                row:Show()

                if entry.disabled then
                    row:EnableMouse(false)
                    row:SetAlpha(0.5)
                else
                    row:EnableMouse(true)
                    row:SetAlpha(1.0)
                end
            end
        end

        for i = visible + 1, #self.buttons do
            self.buttons[i]:Hide()
            self.buttons[i].__twichuiEntry = nil
        end

        if visible == 0 then
            frame:SetHeight(10)
            return
        end

        -- Use a formula-based calculation for now; height will be recalculated in Toggle()
        -- after the frame is positioned and button layouts are finalized
        frame:SetHeight(10 + visible * 22)
    end

    function menu:Hide()
        if self.frame:IsShown() then
            self.frame:Hide()
        end
    end

    local function RecalculateFrameHeight(self)
        local visible = 0
        for i = 1, #self.buttons do
            if self.buttons[i]:IsVisible() then
                visible = visible + 1
            end
        end

        if visible == 0 then
            self.frame:SetHeight(10)
            return
        end

        local first = self.buttons[1]
        local last = self.buttons[visible]
        if first and last and first:IsVisible() and last:IsVisible() and first.GetTop and last.GetBottom then
            local top = first:GetTop()
            local bottom = last:GetBottom()
            if top and bottom then
                local h = (top - bottom) + 8
                if h < 10 then h = 10 end
                self.frame:SetHeight(h)
                return
            end
        end

        -- Fallback to formula if GetTop/GetBottom are not available
        self.frame:SetHeight(10 + visible * 22)
    end

    ---@param anchor Frame
    ---@param point string|nil
    ---@param relativePoint string|nil
    ---@param x number|nil
    ---@param y number|nil
    function menu:Toggle(anchor, point, relativePoint, x, y)
        if self.frame:IsShown() then
            self:Hide()
            return
        end

        if InCombatLockdown and InCombatLockdown() then
            return
        end

        point = point or "TOPLEFT"
        relativePoint = relativePoint or "BOTTOMLEFT"
        x = tonumber(x) or 0
        y = tonumber(y) or -4

        if anchor and anchor.GetCenter then
            self.frame:ClearAllPoints()
            self.frame:SetPoint(point, anchor, relativePoint, x, y)
        else
            self.frame:ClearAllPoints()
            self.frame:SetPoint("CENTER", _G.UIParent, "CENTER", 0, 0)
        end

        self.frame:Show()

        -- Recalculate frame height now that the frame is positioned and button layout is finalized
        RecalculateFrameHeight(self)
    end

    return menu
end

-- Blizzard UIDropDownMenu-based secure menu for datatexts
local function ShowSecureDropdown(entries, anchor)
    if not entries or #entries == 0 then return end
    if not TwichUI_SecureDropdown then
        CreateFrame("Frame", "TwichUI_SecureDropdown", UIParent, "UIDropDownMenuTemplate")
    end
    local dropdown = TwichUI_SecureDropdown
    local function OnClick(self, arg1, arg2, checked)
        if arg1 and arg1.type == "item" and arg1.item then
            UseItemByName(arg1.item)
        elseif arg1 and arg1.type == "spell" and arg1.spell then
            CastSpellByID(arg1.spell)
        elseif arg1 and arg1.type == "macro" and arg1.macrotext then
            RunMacroText(arg1.macrotext)
        end
    end
    local menu = {}
    for _, entry in ipairs(entries) do
        local info = {}
        info.text = entry.text
        info.notCheckable = true
        info.func = OnClick
        info.arg1 = entry
        table.insert(menu, info)
    end
    -- Ensure Blizzard's UIDropDownMenu is loaded (modern WoW API)
    if not EasyMenu then
        local loaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_UIDropDownMenu")
        if not loaded then
            if C_AddOns and C_AddOns.LoadAddOn then
                local loadedNow = C_AddOns.LoadAddOn("Blizzard_UIDropDownMenu")
                if not loadedNow and not C_AddOns.IsAddOnLoaded("Blizzard_UIDropDownMenu") then
                    return
                end
            else
                return
            end
        end
    end
    EasyMenu(menu, dropdown, anchor or UIParent, "cursor", 0, 0, "MENU")
end
UI.ShowSecureDropdown = ShowSecureDropdown
