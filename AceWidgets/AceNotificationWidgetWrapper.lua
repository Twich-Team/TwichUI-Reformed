----------------------------------------------------
-- AceGUI widget: TwichUI_NotificationWrapper
-- A simple container that shows a message at the top
-- and lays out its child widget(s) directly underneath.
----------------------------------------------------

local AceGUI = LibStub("AceGUI-3.0")

local WIDGET_TYPE = "TwichUI_NotificationWrapper"
local Type, Version = WIDGET_TYPE, 1

---@return AceGUIWidget
local function Constructor()
    local frame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    frame:Hide()

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    end

    frame:SetMovable(false)
    frame:EnableMouse(false)

    -- Message label at the top of the wrapper
    local message = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    message:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -8)
    message:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -8, -8)
    message:SetJustifyH("LEFT")
    message:SetJustifyV("TOP")
    message:SetWordWrap(true)
    message:SetText("")

    -- Content area where the wrapped widget(s) will be placed
    local content = CreateFrame("Frame", nil, frame)
    content:SetPoint("TOPLEFT", message, "BOTTOMLEFT", 0, -8)
    content:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -8, 8)

    ---@class TwichUI_NotificationWrapperWidget : AceGUIWidget
    ---@field frame Frame
    ---@field content Frame
    ---@field message FontString
    local widget = {}
    widget.type = Type
    widget.frame = frame
    widget.content = content
    widget.message = message

    local methods = {}

    function methods:OnAcquire()
        self.frame:SetParent(UIParent)
        self.frame:SetWidth(300)
        self.frame:Show()

        -- When used inside an AceGUI container with List/Flow layouts,
        -- this makes the wrapper stretch to the container's width.
        if self.SetFullWidth then
            self:SetFullWidth(true)
        end

        self:SetMessage("")
    end

    function methods:OnRelease()
        self:SetMessage("")
        self.frame:Hide()
        self.frame:ClearAllPoints()
        self.frame:SetParent(nil)
    end

    function methods:SetFontSize(size)
        if not size or size <= 0 then return end
        self.fontSize = size
        if self.message then
            local font, _, flags = self.message:GetFont()
            self.message:SetFont(font, size, flags)
        end
    end

    ---Set the message text displayed above the wrapped widget.
    ---@param text string|nil
    function methods:SetMessage(text)
        text = text or ""
        if not self.message then return end

        self.message:SetText(text)

        -- Ask AceGUI to re-layout children so LayoutFinished
        -- gets called and we can resize the frame appropriately.
        if self.DoLayout then
            self:DoLayout()
        end
    end

    ---AceGUI layout callback used to finalise the wrapper height.
    ---@param _ any
    ---@param height number|nil  Height of children within the content frame.
    function methods:LayoutFinished(_, height)
        height = height or 0

        local topPadding = 8
        local bottomPadding = 8
        local spacing = 8

        local messageHeight = 0
        if self.message then
            local text = self.message:GetText()
            if text and text ~= "" then
                messageHeight = self.message:GetStringHeight() or 0
            end
        end

        local totalHeight = topPadding + messageHeight + (messageHeight > 0 and spacing or 0) + height + bottomPadding
        self.frame:SetHeight(totalHeight)
    end

    for method, func in pairs(methods) do
        widget[method] = func
    end

    return AceGUI:RegisterAsContainer(widget)
end

AceGUI:RegisterWidgetType(Type, Constructor, Version)
