----------------------------------------------------
-- AceGUI widget: TwichUI_EmptyPanel (no X)
----------------------------------------------------

local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_EmptyPanel"
local Type, Version = WIDGET_TYPE, 1

---@return AceGUIWidget
local function EmptyPanelConstructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()

    frame:SetTemplate("Transparent")

    frame:SetMovable(false)
    frame:EnableMouse(true)

    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", frame, "TOPLEFT", 4, -4)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 4)

    local widget = {}
    widget.type = Type
    widget.frame = frame
    widget.content = content
    widget.growDirection = "DOWN"

    local methods = {}

    function methods:OnAcquire()
        self.frame:SetParent(UIParent)
        self.frame:SetWidth(300)
        self.frame:Show()
    end

    function methods:OnRelease()
        self.frame:Hide()
        self.frame:ClearAllPoints()
        self.frame:SetParent(nil)
    end

    ---@param direction "UP"|"DOWN"
    function methods:SetGrowDirection(direction)
        if type(direction) ~= "string" then return end

        direction = direction:upper()
        if direction ~= "UP" and direction ~= "DOWN" then return end

        self.growDirection = direction
    end

    function methods:LayoutFinished(_, height)
        height = height or 0

        -- Padding matches the content's insets set above.
        local topPadding = 4
        local bottomPadding = 4

        self.frame:SetHeight(height + topPadding + bottomPadding)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, EmptyPanelConstructor, Version)
