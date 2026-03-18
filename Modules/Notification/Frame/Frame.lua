--[[
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type NotificationModule
local NM = T:GetModule("Notification")

local AceGUI = LibStub("AceGUI-3.0")

--- @class NotificationFrame
local NotificationFrame = NM.Frame or {}
NM.Frame = NotificationFrame

local function GetOptions()
    return T:GetModule("Configuration").Options.NotificationPanel
end

function NotificationFrame:Create()
    -- Reuse an existing container if we already have one.
    if self.frame and not AceGUI:IsReleasing(self.frame) then
        return self.frame
    end

    -- Use the custom container widget which has no built-in close button.
    local container = AceGUI:Create("TwichUI_EmptyPanel")
    self.frame = container

    -- Apply configurable growth direction and width if available.
    local options = GetOptions()
    local growthDirection = options and options:GetGrowthDirection() or "DOWN"
    local panelWidth = options and options.GetPanelWidth and options:GetPanelWidth() or 300

    if container.SetGrowDirection then
        container:SetGrowDirection(growthDirection)
    end

    -- Use a vertical list so multiple notifications can stack.
    container:SetLayout("List")

    -- Anchor the visible frame to the ElvUI mover/anchor if available,
    -- otherwise fall back to UIParent. Use the configured growth
    -- direction to decide which edge is fixed.
    if container.frame then
        local anchor = NM.anchor or UIParent

        -- Ensure the ElvUI anchor reflects the configured panel width so
        -- the notification container visually resizes.
        if NM.anchor and panelWidth then
            NM.anchor:SetWidth(panelWidth)
        end

        container.frame:ClearAllPoints()
        if growthDirection == "UP" then
            container.frame:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", 0, 0)
            container.frame:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
        else
            container.frame:SetPoint("TOPLEFT", anchor, "TOPLEFT", 0, 0)
            container.frame:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
        end

        -- Start hidden; we explicitly show when a notification is added.
        container.frame:Hide()
    end

    return container
end

---Remove a specific notification widget from the container and release it.
---@param container AceGUIWidget
---@param widget AceGUIWidget
local function DismissNotification(container, widget)
    if not container or not widget or AceGUI:IsReleasing(container) then
        return
    end

    local children = container.children
    local wasChild = false

    if children then
        for i = #children, 1, -1 do
            if children[i] == widget then
                table.remove(children, i)
                wasChild = true
                break
            end
        end
    end

    if wasChild then
        if widget.Release then
            widget:Release()
        end

        if container.DoLayout then
            container:DoLayout()
        end

        if container.children and #container.children == 0 and container.frame then
            container.frame:Hide()
        end
    end
end

--- @param widget AceGUIWidget
--- @param options NotificationOptions|nil
function NotificationFrame:DisplayNotification(widget, options)
    if not widget then return end

    -- Get or create the container this notification will live in.
    local container = self:Create()

    -- Add this notification to the stack instead of replacing existing ones.
    container:AddChild(widget)

    -- Allow the user to dismiss a notification with a right-click.
    if widget.frame then
        local frame = widget.frame
        frame:EnableMouse(true)

        frame:SetScript("OnMouseDown", function(_, button)
            if button == "RightButton" then
                DismissNotification(container, widget)
            end
        end)
    end

    -- Ensure the panel is visible while the notification is active.
    if container.frame then
        container.frame:Show()
    end

    container:DoLayout()

    -- Automatically clear this specific notification after 10 seconds,
    -- independent of any others that may be added later.
    local displayDuration = options and options.displayDuration or 10
    C_Timer.After(displayDuration, function()
        DismissNotification(container, widget)
    end)
end

function NotificationFrame:Refresh()
    -- Fully release the existing AceGUI container (and its children) so
    -- that any configuration changes are applied to a fresh instance.
    if self.frame then
        if not AceGUI:IsReleasing(self.frame) then
            AceGUI:Release(self.frame)
        end
        self.frame = nil
    end

    self:Create()
end
