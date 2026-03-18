--[[
        Best in Slot -- Frame

        Responsibilities:
        - Provides the main Best in Slot user interface frame.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

local AceGUI = LibStub("AceGUI-3.0")

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
    end)
    -- Set initial Tab (this will fire the OnGroupSelected callback)
    tab:SelectTab("gearSelector")

    -- add to the frame container
    f:AddChild(tab)
end
