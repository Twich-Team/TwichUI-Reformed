local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_KeystoneNotification"
local Type, Version = WIDGET_TYPE, 1

local FRAME_WIDTH = 300
local FRAME_HEIGHT = 88
local ICON_SIZE = 36
local TEXT_LEFT_OFFSET = 58
local FALLBACK_ICON_TEXTURE = "Interface\\Icons\\INV_Misc_ShadowEgg"

local function GetHyperlinkType(link)
    if type(link) ~= "string" then
        return nil
    end

    return link:match("|H([^:|]+):")
end

local function Constructor()
    local frame = CreateFrame("Button", nil, UIParent, "BackdropTemplate")
    frame:Hide()
    frame:SetSize(FRAME_WIDTH, FRAME_HEIGHT)
    frame:EnableMouse(true)
    frame:RegisterForClicks("AnyUp")

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    local accent = frame:CreateTexture(nil, "ARTWORK")
    accent:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    accent:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    accent:SetWidth(4)
    accent:SetColorTexture(0.33, 0.65, 0.96, 1)

    local iconBackdrop = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    iconBackdrop:SetPoint("LEFT", frame, "LEFT", 12, 0)
    iconBackdrop:SetSize(ICON_SIZE + 4, ICON_SIZE + 4)
    if iconBackdrop.SetTemplate then
        iconBackdrop:SetTemplate("Default")
    end

    local icon = iconBackdrop:CreateTexture(nil, "ARTWORK")
    icon:SetPoint("CENTER", iconBackdrop, "CENTER", 0, 0)
    icon:SetSize(ICON_SIZE, ICON_SIZE)
    icon:SetTexture(FALLBACK_ICON_TEXTURE)

    local status = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    status:SetPoint("TOPLEFT", frame, "TOPLEFT", TEXT_LEFT_OFFSET, -10)
    status:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -10)
    status:SetJustifyH("LEFT")
    status:SetTextColor(0.33, 0.65, 0.96)
    status:SetText("MYTHIC+ KEY")

    local keyName = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    keyName:SetPoint("TOPLEFT", status, "BOTTOMLEFT", 0, -2)
    keyName:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, -2)
    keyName:SetJustifyH("LEFT")
    keyName:SetWordWrap(false)
    keyName:SetText("Mythic Keystone")

    local dungeon = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    dungeon:SetPoint("TOPLEFT", keyName, "BOTTOMLEFT", 0, -6)
    dungeon:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    dungeon:SetJustifyH("LEFT")
    dungeon:SetWordWrap(false)
    dungeon:SetText("Unknown Dungeon +0")

    local affixes = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    affixes:SetPoint("TOPLEFT", dungeon, "BOTTOMLEFT", 0, -6)
    affixes:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -10, 0)
    affixes:SetJustifyH("LEFT")
    affixes:SetWordWrap(true)
    affixes:SetText("Affixes unavailable")

    ---@class TwichUI_KeystoneNotificationWidget : AceGUIWidget
    ---@field frame Button
    ---@field accent Texture
    ---@field icon Texture
    ---@field iconBackdrop Frame
    ---@field status FontString
    ---@field keyName FontString
    ---@field dungeon FontString
    ---@field affixes FontString
    ---@field itemID number|nil
    ---@field itemLink string|nil
    local widget = {
        type = Type,
        frame = frame,
        accent = accent,
        icon = icon,
        iconBackdrop = iconBackdrop,
        status = status,
        keyName = keyName,
        dungeon = dungeon,
        affixes = affixes,
        itemID = nil,
        itemLink = nil,
    }
    frame.obj = widget

    local methods = {}

    local function ApplyItemInfo(self)
        local itemSource = self.itemID or self.itemLink
        if not itemSource then
            self.icon:SetTexture(FALLBACK_ICON_TEXTURE)
            self.keyName:SetText("Mythic Keystone")
            self.keyName:SetTextColor(1, 1, 1)
            return
        end

        local itemName, _, itemQuality, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemSource)
        if not itemName then
            self.icon:SetTexture(FALLBACK_ICON_TEXTURE)
            self.keyName:SetText("Mythic Keystone")
            self.keyName:SetTextColor(1, 1, 1)
            return
        end

        self.icon:SetTexture(itemTexture or FALLBACK_ICON_TEXTURE)

        local r, g, b = 1, 1, 1
        if itemQuality then
            r, g, b = C_Item.GetItemQualityColor(itemQuality)
        end

        self.keyName:SetText(itemName)
        self.keyName:SetTextColor(r, g, b)
    end

    function methods:OnAcquire()
        self:SetWidth(FRAME_WIDTH)
        self:SetHeight(FRAME_HEIGHT)
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetKeystoneNotification(nil, nil, "Unknown Dungeon", 0, "Affixes unavailable")
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:ClearAllPoints()
        self.frame:Hide()
        self.itemID = nil
        self.itemLink = nil
        self.icon:SetTexture(FALLBACK_ICON_TEXTURE)
        self.keyName:SetText("")
        self.dungeon:SetText("")
        self.affixes:SetText("")
    end

    ---@param itemID number|nil
    ---@param itemLink string|nil
    ---@param dungeonName string|nil
    ---@param level number|nil
    ---@param affixText string|nil
    function methods:SetKeystoneNotification(itemID, itemLink, dungeonName, level, affixText)
        self.itemID = itemID
        self.itemLink = itemLink

        self.dungeon:SetText(("%s +%d"):format(dungeonName or "Unknown Dungeon", level or 0))
        self.affixes:SetText(affixText ~= "" and (affixText or "") or "Affixes unavailable")

        ApplyItemInfo(self)

        local itemSource = itemID or itemLink
        if itemSource and Item then
            if type(itemSource) == "string" and Item.CreateFromItemLink and GetHyperlinkType(itemSource) == "item" and not C_Item.GetItemInfo(itemSource) then
                local itemObj = Item:CreateFromItemLink(itemSource)
                itemObj:ContinueOnItemLoad(function()
                    if self.itemID == itemID and self.itemLink == itemLink then
                        ApplyItemInfo(self)
                    end
                end)
            elseif type(itemSource) == "number" and Item.CreateFromItemID and not C_Item.GetItemInfo(itemSource) then
                local itemObj = Item:CreateFromItemID(itemSource)
                itemObj:ContinueOnItemLoad(function()
                    if self.itemID == itemID and self.itemLink == itemLink then
                        ApplyItemInfo(self)
                    end
                end)
            end
        end
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    frame:SetScript("OnEnter", function(self)
        local obj = self.obj
        if not obj or (not obj.itemID and not obj.itemLink) then
            return
        end

        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if obj.itemLink then
            GameTooltip:SetHyperlink(obj.itemLink)
        elseif type(obj.itemID) == "number" then
            GameTooltip:SetItemByID(obj.itemID)
        end
        GameTooltip:Show()
    end)

    frame:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)

    return AceGUI:RegisterAsWidget(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
