--[[
        Best in Slot -- Frame

        Responsibilities:
        - Provides the main Best in Slot user interface frame.
]]
---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

local AceGUI = LibStub("AceGUI-3.0")
local C_Timer = _G.C_Timer

local function GetThemeColors()
    local ThemeModule = T:GetModule("Theme", true)
    local primary = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("primaryColor") or { 0.16, 0.78, 0.78 }
    local accent = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("accentColor") or { 0.95, 0.76, 0.26 }
    local surface = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("backgroundColor") or
    { 0.06, 0.06, 0.08 }
    local border = ThemeModule and ThemeModule.GetColor and ThemeModule:GetColor("borderColor") or { 0.24, 0.26, 0.32 }

    return primary, accent, surface, border
end

local function ApplyBackdrop(frame, bg, bd, bgAlpha, bdAlpha)
    if not frame then
        return
    end

    if frame.SetTemplate then
        frame:SetTemplate("Transparent")
    elseif frame.SetBackdrop then
        frame:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
            insets = { left = 1, right = 1, top = 1, bottom = 1 },
        })
    end

    if frame.SetBackdropColor then
        frame:SetBackdropColor(bg[1], bg[2], bg[3], bgAlpha or 0.96)
    end
    if frame.SetBackdropBorderColor then
        frame:SetBackdropBorderColor(bd[1], bd[2], bd[3], bdAlpha or 0.34)
    end
end

local function StyleFrameWidget(widget)
    if not widget or not widget.frame then
        return
    end

    local primary, accent, surface, border = GetThemeColors()
    local frame = widget.frame
    ApplyBackdrop(frame, { surface[1] * 0.78, surface[2] * 0.8, surface[3] * 0.9 }, border, 0.98, 0.42)

    if widget.titletext then
        widget.titletext:SetTextColor(1, 0.95, 0.84)
    end

    if widget.statusbg then
        widget.statusbg:Hide()
    end

    if frame.TitleBg then
        frame.TitleBg:SetVertexColor(surface[1] * 0.8, surface[2] * 0.82, surface[3] * 0.88, 0.95)
    end
    if frame.TitleText then
        frame.TitleText:SetTextColor(1, 0.95, 0.84)
    end

    if frame.CloseButton then
        local close = frame.CloseButton
        if T.Tools and T.Tools.UI and T.Tools.UI.SkinCloseButton then
            T.Tools.UI.SkinCloseButton(close)
        end
        close:SetAlpha(0.92)
    end

    if not frame.TwichUIAccent then
        frame.TwichUIAccent = frame:CreateTexture(nil, "ARTWORK")
        frame.TwichUIAccent:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.TwichUIAccent:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
        frame.TwichUIAccent:SetHeight(2)
    end
    frame.TwichUIAccent:SetColorTexture(accent[1], accent[2], accent[3], 0.95)

    if not frame.TwichUIInnerGlow then
        frame.TwichUIInnerGlow = frame:CreateTexture(nil, "BACKGROUND")
        frame.TwichUIInnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
        frame.TwichUIInnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    end
    frame.TwichUIInnerGlow:SetColorTexture(primary[1], primary[2], primary[3], 0.04)
end

local function StyleTabGroupWidget(tab)
    if not tab then
        return
    end

    local _, accent, surface, border = GetThemeColors()
    if tab.border then
        ApplyBackdrop(tab.border, { surface[1] * 0.76, surface[2] * 0.78, surface[3] * 0.86 }, border, 0.88, 0.24)
    end

    if tab.content then
        ApplyBackdrop(tab.content, { surface[1] * 0.68, surface[2] * 0.7, surface[3] * 0.78 }, border, 0.78, 0.2)
    end

    if type(tab.tabs) == "table" then
        for _, tabButton in ipairs(tab.tabs) do
            local button = tabButton and tabButton.frame or tabButton
            if button and button.SetBackdrop then
                ApplyBackdrop(button, { surface[1] * 0.65, surface[2] * 0.67, surface[3] * 0.74 }, border, 0.88, 0.2)
            end
            if button and T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
                T.Tools.UI.SkinTwichButton(button, accent)
            end
            if button and button.text then
                button.text:SetTextColor(0.92, 0.94, 0.98)
            end
            if button and not button.TwichUIAccent then
                button.TwichUIAccent = button:CreateTexture(nil, "ARTWORK")
                button.TwichUIAccent:SetPoint("BOTTOMLEFT", button, "BOTTOMLEFT", 1, 1)
                button.TwichUIAccent:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -1, 1)
                button.TwichUIAccent:SetHeight(2)
            end
            if button and button.TwichUIAccent then
                button.TwichUIAccent:SetColorTexture(accent[1], accent[2], accent[3], 0.85)
            end
        end
    end

    if tab.frame and tab.frame.GetChildren then
        local function StyleTabButton(candidate)
            if not candidate then
                return
            end

            local text = (candidate.text and candidate.text.GetText and candidate.text:GetText()) or
                (candidate.GetText and candidate:GetText())
            if type(text) ~= "string" or text == "" then
                return
            end

            if candidate.SetBackdrop then
                ApplyBackdrop(candidate, { surface[1] * 0.65, surface[2] * 0.67, surface[3] * 0.74 }, border, 0.88, 0.2)
            end
            if T.Tools and T.Tools.UI and T.Tools.UI.SkinTwichButton then
                T.Tools.UI.SkinTwichButton(candidate, accent)
            end
            if candidate.text then
                candidate.text:SetTextColor(0.95, 0.96, 0.99)
            end
        end

        for _, child in ipairs({ tab.frame:GetChildren() }) do
            StyleTabButton(child)
            if child and child.GetChildren then
                for _, grandChild in ipairs({ child:GetChildren() }) do
                    StyleTabButton(grandChild)
                end
            end
        end
    end
end

--- @class BestInSlotFrame
--- @field frame AceGUIWidget the main frame
--- @field Tabs any
local BISFrame = BIS.Frame or {}
BIS.Frame = BISFrame
BISFrame.Tabs = {}

function BISFrame:DrawTab2(container)
    local desc = AceGUI:Create("Label")
    desc:SetText("Tab2")
    desc:SetFullWidth(true)
    container:AddChild(desc)
end

function BISFrame:SelectGroup(container, event, group)
    container:ReleaseChildren()
    if group == "gearSelector" then
        BISFrame.Tabs.GearSelector:Create(container)
    elseif group == "tab2" then
        self:DrawTab2(container)
    end
end

function BISFrame:Show()
    if self.frame and not AceGUI:IsReleasing(self.frame) then
        self.frame:Show()
    else
        self:Create()
    end
end

function BISFrame:Create()
    local f = AceGUI:Create("Frame")
    self.frame = f

    f:SetTitle("Best in Slot")
    f:SetStatusText("TwichUI Best in Slot")
    f:SetWidth(920)
    f:SetHeight(620)
    StyleFrameWidget(f)
    f:SetCallback("OnClose", function(widget)
        AceGUI:Release(widget)
        if self.frame == widget then
            self.frame = nil
        end
    end)
    f:SetLayout("Fill")

    -- Create the TabGroup
    local tab = AceGUI:Create("TabGroup")
    tab:SetLayout("Flow")
    -- Setup which tabs to show
    tab:SetTabs({ { text = "Gear Selector", value = "gearSelector" } })
    -- Register callback
    tab:SetCallback("OnGroupSelected", function(container, event, group)
        self:SelectGroup(container, event, group)
        if C_Timer and C_Timer.After then
            C_Timer.After(0, function()
                StyleTabGroupWidget(tab)
            end)
        else
            StyleTabGroupWidget(tab)
        end
    end)
    StyleTabGroupWidget(tab)
    -- Set initial Tab (this will fire the OnGroupSelected callback)
    tab:SelectTab("gearSelector")

    -- add to the frame container
    f:AddChild(tab)
end
