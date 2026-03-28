---@diagnostic disable: undefined-global, undefined-field, return-type-mismatch
local E = _G.ElvUI and _G.ElvUI[1]
local T = unpack(TwichRx)

local AceGUI = LibStub("AceGUI-3.0")

-- Visual constants for the Best-in-Slot item widget
local WIDGET_HEIGHT = 40
local WIDGET_WIDTH = 200
local ICON_SIZE = 32

local ACEGUI_ITEM_TYPE = "TwichUI_Item"

local Type, Version = ACEGUI_ITEM_TYPE, 1

local NO_ITEM_TEXT = "No Item"

local function GetWidgetColors()
    local ThemeModule = T:GetModule("Theme", true)
    local accent = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("accentColor") or { 0.95, 0.76, 0.26 }
    local border = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("borderColor") or { 0.24, 0.26, 0.32 }
    local bg = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("backgroundColor") or { 0.06, 0.06, 0.08 }
    return accent, border, bg
end

---Builds a simple AceGUI widget for displaying an item in lists.
---@return AceGUIWidget
local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent)
    frame:Hide()

    frame:SetSize(WIDGET_WIDTH, WIDGET_HEIGHT)
    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    else
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    do
        local _, border, bg = GetWidgetColors()
        if frame.SetBackdropColor then
            frame:SetBackdropColor(bg[1] * 0.7, bg[2] * 0.72, bg[3] * 0.8, 0.9)
        end
        if frame.SetBackdropBorderColor then
            frame:SetBackdropBorderColor(border[1], border[2], border[3], 0.28)
        end
    end

    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")

    -- icon
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetPoint("LEFT", frame, "LEFT", 4, 0)

    -- icon border for empty slots
    local iconBorder = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBorder:SetPoint("CENTER", icon)
    iconBorder:SetSize(ICON_SIZE, ICON_SIZE)
    iconBorder:SetTemplate("Transparent")

    -- iconBorder:SetBackdrop({
    --     edgeFile = E.media.border,
    --     edgeSize = E.PixelMode and 1 or 2,
    -- })
    -- iconBorder:SetBackdropBorderColor(unpack(E.media.bordercolor))
    iconBorder:Hide()

    -- item name text
    local text = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    text:SetPoint("LEFT", icon, "RIGHT", 8, 0)
    text:SetPoint("RIGHT", frame, "RIGHT", -4, 0)
    text:SetJustifyH("LEFT")
    text:SetWordWrap(false)


    ---@class TwichUI_ItemWidget : AceGUIWidget
    ---@field icon Texture
    ---@field iconBorder Frame
    ---@field text FontString
    ---@field itemID integer|nil
    ---@field itemLink string|nil
    local widget = {}
    widget.type = Type
    widget.frame = frame
    widget.icon = icon
    widget.iconBorder = iconBorder
    widget.text = text
    widget.itemID = nil
    widget.itemLink = nil
    frame.obj = widget

    local methods = {}

    ---Called when AceGUI acquires this widget for (re)use.
    function methods:OnAcquire()
        self:SetWidth(WIDGET_WIDTH)
        self:SetHeight(WIDGET_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetItem(nil)
    end

    ---Called when the widget is released back to the pool.
    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.itemID = nil
        self.itemLink = nil
        if self.icon then
            self.icon:SetTexture(nil)
        end
        if self.iconBorder then
            self.iconBorder:Hide()
        end
        if self.text then
            self.text:SetText("")
            self.text:SetTextColor(1, 1, 1)
        end
        self.frame:SetScript("OnClick", nil)
    end

    ---Register a click callback invoked when the widget's frame is clicked.
    ---@param func fun()
    function methods:ClickCallback(func)
        if not func then
            self.frame:SetScript("OnClick", nil)
            return
        end

        self.frame:SetScript("OnClick", function()
            func()
        end)
    end

    ---Populate the widget to represent the given item.
    ---Accepts either an itemID (number) or an item link (string).
    ---@param item integer|string|nil
    function methods:SetItem(item)
        local itemID, itemLink

        if type(item) == "number" then
            itemID = item
        elseif type(item) == "string" then
            itemLink = item
            local idFromLink = item:match("item:(%d+)")
            if idFromLink then
                itemID = tonumber(idFromLink)
            end
        end

        self.itemID = itemID
        self.itemLink = itemLink

        if not itemID and not itemLink then
            if self.icon then
                self.icon:SetTexture(nil)
            end

            if self.iconBorder then
                self.iconBorder:SetBackdropBorderColor(unpack(E.media.bordercolor))
                self.iconBorder:Show()
            end

            if self.text then
                self.text:SetText(NO_ITEM_TEXT)
                self.text:SetTextColor(1, 1, 1)
            end
            return
        end

        local function ApplyItemInfo()
            local source = self.itemLink or self.itemID
            if not source then return end

            local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(source)
            if not itemName then return end


            if self.icon then
                self.icon:SetTexture(itemTexture)
            end

            if self.iconBorder then
                self.iconBorder:Hide()
            end

            if self.text then
                local r, g, b = 1, 1, 1
                if itemQuality then
                    r, g, b = C_Item.GetItemQualityColor(itemQuality)
                end
                self.text:SetText(itemName)
                self.text:SetTextColor(r, g, b)
            end
        end

        -- Try immediate info first.
        ApplyItemInfo()

        -- If not yet cached, ensure we update when it becomes available.
        local source = self.itemLink or self.itemID
        if source and Item then
            if type(source) == "string" and Item.CreateFromItemLink and not C_Item.GetItemInfo(source) then
                local itemObj = Item:CreateFromItemLink(source)
                itemObj:ContinueOnItemLoad(function()
                    if self.itemLink == itemLink and self.itemID == itemID then
                        ApplyItemInfo()
                    end
                end)
            elseif type(source) == "number" and Item.CreateFromItemID and not C_Item.GetItemInfo(source) then
                local itemObj = Item:CreateFromItemID(source)
                itemObj:ContinueOnItemLoad(function()
                    if self.itemLink == itemLink and self.itemID == itemID then
                        ApplyItemInfo()
                    end
                end)
            end
        end
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    frame:SetScript("OnEnter", function(self)
        local accent = GetWidgetColors()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(accent[1], accent[2], accent[3], 0.9)
        end
        local obj = self.obj
        if not obj or (not obj.itemID and not obj.itemLink) then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if obj.itemLink then
            GameTooltip:SetHyperlink(obj.itemLink)
        elseif obj.itemID then
            GameTooltip:SetItemByID(obj.itemID)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        local _, border = GetWidgetColors()
        if self.SetBackdropBorderColor then
            self:SetBackdropBorderColor(border[1], border[2], border[3], 0.28)
        end
    end)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
