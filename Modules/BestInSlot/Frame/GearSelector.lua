local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type BestInSlotModule
local BIS = T:GetModule("BestInSlot")

local AceGUI = LibStub("AceGUI-3.0")

--- @type BestInSlotFrame
local BISFrame = BIS.Frame

---@class GearSelectorTab
---@field Slots SlotData[]
local Tab = BISFrame.Tabs.GearSelector or {}
BISFrame.Tabs.GearSelector = Tab

---@alias SlotData { name: string, slotID: number, texture: string }

---@type SlotData[]
local SLOTS = {
    { name = "Head",           slotID = 1,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Head" },
    { name = "Neck",           slotID = 2,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Neck" },
    { name = "Shoulder",       slotID = 3,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Shoulder" },
    { name = "Back",           slotID = 15, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest" }, -- Back uses Chest icon usually or specific back icon
    { name = "Chest",          slotID = 5,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Chest" },
    { name = "Wrist",          slotID = 9,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Wrists" },
    { name = "Hands",          slotID = 10, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Hands" },
    { name = "Waist",          slotID = 6,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Waist" },
    { name = "Legs",           slotID = 7,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Legs" },
    { name = "Feet",           slotID = 8,  texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Feet" },
    { name = "First Ring",     slotID = 11, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
    { name = "Second Ring",    slotID = 12, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Finger" },
    { name = "First Trinket",  slotID = 13, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
    { name = "Second Trinket", slotID = 14, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-Trinket" },
    { name = "MainHand",       slotID = 16, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-MainHand" },
    { name = "OffHand",        slotID = 17, texture = "Interface\\PaperDoll\\UI-PaperDoll-Slot-SecondaryHand" },
}
Tab.Slots = SLOTS

function Tab:CreateSlotFrame(parentGroup, slotData, rootContainer)
    local widget = AceGUI:Create("TwichUI_GearSlot")
    widget:SetSlotData(slotData)
    widget:SetRootContainer(rootContainer)
    parentGroup:AddChild(widget)
    return widget
end

function Tab:Create(container)
    container:SetLayout("Fill")

    local scrollGroup = AceGUI:Create("ScrollFrame")
    scrollGroup:SetFullWidth(true)
    scrollGroup:SetFullHeight(true)
    scrollGroup:SetLayout("List")
    container:AddChild(scrollGroup)

    -- Row group that contains the two columns side by side
    local rowGroup = AceGUI:Create("SimpleGroup")
    rowGroup:SetFullWidth(true)
    rowGroup:SetLayout("Flow")
    scrollGroup:AddChild(rowGroup)

    -- Left column
    local leftGroup = AceGUI:Create("SimpleGroup")
    leftGroup:SetFullWidth(false)
    leftGroup:SetRelativeWidth(0.5)
    leftGroup:SetLayout("List")
    rowGroup:AddChild(leftGroup)

    -- Right column
    local rightGroup = AceGUI:Create("SimpleGroup")
    rightGroup:SetFullWidth(false)
    rightGroup:SetRelativeWidth(0.5)
    rightGroup:SetLayout("List")
    rowGroup:AddChild(rightGroup)

    -- Split slots into two columns; both columns start at the same vertical position
    local half = math.ceil(#SLOTS / 2)
    for i, slotData in ipairs(SLOTS) do
        if i <= half then
            self:CreateSlotFrame(leftGroup, slotData, container)
        else
            self:CreateSlotFrame(rightGroup, slotData, container)
        end
    end
end
