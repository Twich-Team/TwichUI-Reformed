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

local DismissNotification
local BeginFadeOut

local FADE_IN_DURATION = 0.2
local FADE_OUT_DURATION = 0.2

local function ClearAutoDismiss(frame)
    if not frame then
        return
    end

    frame.dismissContainer = nil
    frame.dismissWidget = nil
    frame.dismissRemaining = nil
    frame.dismissPaused = nil
    frame.fadeState = nil
    frame.fadeElapsed = nil
    frame.fadeStartAlpha = nil
    frame.fadeEndAlpha = nil
    frame:SetScript("OnUpdate", nil)
end

local function BeginFadeIn(frame)
    frame.fadeState = "in"
    frame.fadeElapsed = 0
    frame.fadeStartAlpha = 0
    frame.fadeEndAlpha = 1
    frame:SetAlpha(0)
end

local function ShowEncounterTooltip(frame)
    local encounters = frame and frame.tooltipEncounterData
    if not encounters or #encounters == 0 then
        return
    end

    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:AddLine("Bosses", 1, 1, 1)
    GameTooltip:AddLine(" ")
    for _, encounter in ipairs(encounters) do
        if encounter.isCompleted then
            GameTooltip:AddLine(encounter.name, 0.9, 0.2, 0.2)
        else
            GameTooltip:AddLine(encounter.name, 0.9, 0.9, 0.9)
        end
    end
    GameTooltip:Show()
end

BeginFadeOut = function(frame)
    if not frame or frame.fadeState == "out" then
        return
    end

    frame.fadeState = "out"
    frame.fadeElapsed = 0
    frame.fadeStartAlpha = frame:GetAlpha() or 1
    frame.fadeEndAlpha = 0
end

local function StartAutoDismiss(frame, container, widget, duration)
    if not frame then
        return
    end

    local displayDuration = tonumber(duration) or 10
    if displayDuration <= 0 then
        ClearAutoDismiss(frame)
        return
    end

    frame.dismissContainer = container
    frame.dismissWidget = widget
    frame.dismissRemaining = displayDuration
    frame.dismissPaused = false
    BeginFadeIn(frame)
    frame:SetScript("OnUpdate", function(self, elapsed)
        if self.fadeState == "in" then
            self.fadeElapsed = (self.fadeElapsed or 0) + elapsed
            local progress = math.min(self.fadeElapsed / FADE_IN_DURATION, 1)
            self:SetAlpha(self.fadeStartAlpha + ((self.fadeEndAlpha - self.fadeStartAlpha) * progress))

            if progress >= 1 then
                self.fadeState = nil
                self.fadeElapsed = nil
                self.fadeStartAlpha = nil
                self.fadeEndAlpha = nil
                self:SetAlpha(1)
            end
        end

        if self.fadeState == "out" then
            self.fadeElapsed = (self.fadeElapsed or 0) + elapsed
            local progress = math.min(self.fadeElapsed / FADE_OUT_DURATION, 1)
            self:SetAlpha(self.fadeStartAlpha + ((self.fadeEndAlpha - self.fadeStartAlpha) * progress))

            if progress >= 1 then
                local dismissContainer = self.dismissContainer
                local dismissWidget = self.dismissWidget

                self:SetAlpha(0)
                ClearAutoDismiss(self)
                DismissNotification(dismissContainer, dismissWidget)
            end

            return
        end

        if not self.dismissPaused and self.dismissRemaining then
            self.dismissRemaining = self.dismissRemaining - elapsed
            if self.dismissRemaining <= 0 then
                BeginFadeOut(self)
            end
        end
    end)
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
DismissNotification = function(container, widget)
    if not container or not widget or AceGUI:IsReleasing(container) then
        return
    end

    if widget.frame then
        widget.frame:SetAlpha(1)
        ClearAutoDismiss(widget.frame)
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
        frame:SetScript("OnEnter", function(self)
            self.dismissPaused = true
            ShowEncounterTooltip(self)
        end)
        frame:SetScript("OnLeave", function(self)
            self.dismissPaused = false
            GameTooltip:Hide()
        end)

        frame:SetScript("OnMouseDown", function(_, button)
            if button == "RightButton" then
                BeginFadeOut(frame)
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
    if widget.frame then
        StartAutoDismiss(widget.frame, container, widget, displayDuration)
    end
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
