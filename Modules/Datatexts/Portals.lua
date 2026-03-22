--[[
    Datatext providing quick access to favorite portals.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

---@class PortalDataText
---@field definition DatatextDefinition the datatext definition
---@field panel ElvUI_DT_Panel the panel instance for the datatext
---@field menuList table
---@field flaggedForRebuild boolean indicates if the menu needs to be rebuilt
local PDT = DataTextModule:NewModule("PortalDataText")

local function GetOptions()
    return DataTextModule.GetOptions()
end

local function GetTeleportsModule()
    local qualityOfLife = T:GetModule("QualityOfLife", true)
    if not qualityOfLife then
        return nil
    end

    return qualityOfLife:GetModule("Teleports", true)
end

local function GetHearthstoneDestination(itemID)
    if not itemID or not C_TooltipInfo then return nil end
    local ttData
    if PlayerHasToy and PlayerHasToy(itemID) and C_TooltipInfo.GetToyByItemID then
        ttData = C_TooltipInfo.GetToyByItemID(itemID)
    elseif C_TooltipInfo.GetItemByID then
        ttData = C_TooltipInfo.GetItemByID(itemID)
    end
    if not ttData or not ttData.lines then
        return nil
    end
    for i, line in ipairs(ttData.lines) do
        local leftText = line.leftText
        if leftText and leftText:find("Returns you to") then
            -- Extract only up to the first period after 'Returns you to'
            local dest = leftText:match("Returns you to ([^.]+)")
            if dest then
                dest = dest:gsub("^%s+", ""):gsub("%s+$", "")
                return dest
            end
        end
    end
    return nil
end

local function OnEnter(panel)
    local tt = DataTextModule:GetElvUITooltip()
    if not tt then return end
    tt:ClearLines()

    -- tt:AddLine("Click to access portals")
    -- tt:AddLine(" ")


    function ColorGray(text)
        return T.Tools.Text.Color(T.Tools.Colors.GRAY, text)
    end

    -- Dynamically show hearthstone destination
    local Options = GetOptions()
    local favoriteHearthstone = Options.GetFavoriteHearthstone and (Options:GetFavoriteHearthstone() or 0) or 0
    if favoriteHearthstone == 0 then
        favoriteHearthstone = 6948 -- regular Hearthstone item
    end
    local dest = GetHearthstoneDestination(favoriteHearthstone)
    if dest then
        tt:AddLine(ColorGray("Left-click: Teleports Popup"))
        tt:AddLine(ColorGray("Right-click: Hearthstone to " .. dest))
    else
        tt:AddLine(ColorGray("Left-click: Teleports Popup"))
        tt:AddLine(ColorGray("Right-click: Hearthstone"))
    end
    tt:AddLine(ColorGray("Shift+Right-Click: Dalaran Hearthstone"))
    tt:Show()
end

local function PortalOnClick(self, button)
    if button ~= "LeftButton" then
        return
    end

    local teleports = GetTeleportsModule()
    if teleports and teleports:IsEnabled() and teleports.ToggleDatatextPopup then
        teleports:ToggleDatatextPopup(self)
    end
end

function PDT:GetMenuList()
    if self.menuList and not self.flaggedForRebuild then
        return self.menuList
    end

    local menuList = {}
    self.menuList = menuList

    tinsert(menuList, {
        text = "Hearthstones",
        isTitle = true,
        notCheckable = true,
    })
    local Options = GetOptions()

    local function AddHearthEntry(itemID)
        if not itemID or itemID == 0 then
            return
        end

        local name, icon

        if C_ToyBox and C_ToyBox.GetToyInfo then
            local _, toyName, toyIcon = C_ToyBox.GetToyInfo(itemID)
            name = toyName or name
            icon = toyIcon or icon
        end

        if (not name) and C_Item and C_Item.GetItemInfo then
            local itemName, _, _, _, _, _, _, _, _, itemTexture = C_Item.GetItemInfo(itemID)
            name = itemName or name
            icon = itemTexture or icon
        end

        if not name then
            return
        end

        local label = tostring(name)
        if icon and T.Tools and T.Tools.Text and T.Tools.Text.Icon then
            label = T.Tools.Text.Icon(icon) .. " " .. label
        end

        tinsert(menuList, {
            text = label,
            notCheckable = true,
            func = function()
                UseHearthstone(itemID)
            end,
        })
    end

    -- Favorite hearthstone (falls back to normal Hearthstone if none selected)
    local favoriteHearthstone = Options.GetFavoriteHearthstone and (Options:GetFavoriteHearthstone() or 0) or 0
    if favoriteHearthstone == 0 then
        favoriteHearthstone = 6948 -- regular Hearthstone item
    end
    AddHearthEntry(favoriteHearthstone)

    -- Dalaran Hearthstone toy
    local dalaranHearthstoneID = 140192
    AddHearthEntry(dalaranHearthstoneID)

    -- Garrison Hearthstone item
    local garrisonHearthstoneID = 110560
    AddHearthEntry(garrisonHearthstoneID)


    self.flaggedForRebuild = false
    return menuList
end

function PDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Portals",
        events = nil,
        onEventFunc = function(...) PDT:OnEvent(...) end,
        onUpdateFunc = nil,
        onClickFunc = PortalOnClick,
        onEnterFunc = OnEnter,

    }
    DataTextModule:Inform(PDT.definition)
end

function PDT:UpdateButton()
    local function IsActiveOnPanel()
        local panelText = (self.panel and self.panel.text and self.panel.text.GetText) and self.panel.text:GetText() or
            nil
        if not panelText then
            return false
        end

        -- Strip WoW color codes so we can compare the raw label text.
        panelText = panelText:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
        return panelText == "Portals"
    end

    if not self.clickButton then
        local btn = CreateFrame("Button", nil, self.panel, "SecureActionButtonTemplate")
        btn:SetAllPoints(self.panel)
        btn:RegisterForClicks("RightButtonUp", "RightButtonDown")
        btn:SetFrameLevel((self.panel.GetFrameLevel and self.panel:GetFrameLevel() or 1) + 5)
        btn:EnableMouse(false)

        -- Preserve hover UX by forwarding hover events.
        btn:SetScript("OnEnter", function(button)
            if not IsActiveOnPanel() then
                self:UpdateButton()
            end

            local parent = button and button.GetParent and button:GetParent() or nil
            if parent and parent.GetScript then
                local onEnter = parent:GetScript("OnEnter")
                if onEnter then
                    onEnter(parent)
                end
            end
        end)

        -- Forward non-right clicks to the datatext's OnClick handler so the
        -- left-click menu still works with this secure button layered on top.
        btn:SetScript("OnMouseUp", function(button, mouseButton)
            if mouseButton == "RightButton" then
                return
            end

            if not IsActiveOnPanel() then
                return
            end

            if PortalOnClick then
                local parent = button and button.GetParent and button:GetParent() or nil
                if parent then
                    PortalOnClick(parent, mouseButton)
                end
            end
        end)

        btn:SetScript("OnLeave", function(button)
            local parent = button and button.GetParent and button:GetParent() or nil
            if parent and parent.GetScript then
                local onLeave = parent:GetScript("OnLeave")
                if onLeave then
                    onLeave(parent)
                end
            end
        end)

        btn:SetScript("PreClick", function(button)
            if not IsActiveOnPanel() then
                self:UpdateButton()
            end
        end)

        self.clickButton = btn
    elseif self.clickButton:GetParent() ~= self.panel then
        self.clickButton:SetParent(self.panel)
        self.clickButton:SetAllPoints(self.panel)
    end

    local Options = GetOptions()

    local favoriteHearthstone = Options:GetFavoriteHearthstone()

    if not favoriteHearthstone then
        favoriteHearthstone = 6948 -- default to regular hearthstone if no favorite is set
    end

    local btn = self.clickButton
    if not btn then return end
    local isActiveOnPanel = IsActiveOnPanel()
    btn:EnableMouse(isActiveOnPanel and true or false)

    -- Clear attributes first.
    btn:SetAttribute("type", nil)
    btn:SetAttribute("type1", nil)
    btn:SetAttribute("type2", nil)
    btn:SetAttribute("macrotext", nil)
    btn:SetAttribute("macrotext1", nil)
    btn:SetAttribute("macrotext2", nil)

    -- Clear modifier overrides for right-click (button 2)
    btn:SetAttribute("shift-type2", nil)
    btn:SetAttribute("shift-macrotext2", nil)

    if not isActiveOnPanel then
        return
    end

    -- Use favorite hearthstone on right-click of the datatext (button 2).
    btn:SetAttribute("type2", "macro")
    btn:SetAttribute("macrotext2", "/use item:" .. tostring(favoriteHearthstone))

    -- Use Dalaran Hearthstone on Shift+Right-click of the datatext.
    local dalaranHearthstoneID = 140192
    btn:SetAttribute("shift-type2", "macro")
    btn:SetAttribute("shift-macrotext2", "/use item:" .. tostring(dalaranHearthstoneID))
end

function PDT:OnEvent(panel, event, ...)
    if not self.panel then
        self.panel = panel


        if not self.clickButton then
            self:UpdateButton()
        end
    end

    if event == DataTextModule.CommonEvents.ELVUI_FORCE_UPDATE then
        self:Refresh()
    end
end

function PDT:Refresh()
    if not self.panel then return end

    local Options = DataTextModule.GetOptions()

    local r, g, b
    if not Options:GetPortalsUseCustomColor() then
        r, g, b = DataTextModule:GetElvUIValueColor()
    else
        r, g, b = Options:GetPortalsTextColor()
    end

    self.panel.text:SetText(T.Tools.Text.ColorRGB(r, g, b, "Portals"))

    -- Ensure the secure click button is configured after the label text is set,
    -- so IsActiveOnPanel() can correctly detect that this panel is showing Portals.
    if self.UpdateButton then
        self:UpdateButton()
    end
end

---@return number[]
function PDT:FindToyHearthstones()
    -- ensure the toybox is not filtered
    C_ToyBox.SetFilterString("")

    local SEARCH_TEXT = "returns you to"

    local function DoesItemHaveTooltipText(itemID, searchText)
        local ttData = C_TooltipInfo.GetItemByID(itemID)
        if ttData and ttData.lines then
            for i, line in ipairs(ttData.lines) do
                local leftText = line.leftText
                if leftText and leftText ~= "" and leftText:lower():find(searchText) then
                    return true
                end
            end
        end
        return false
    end

    local toyHearthstones = {}

    local totalToys = C_ToyBox.GetNumToys() or 0
    for index = 1, totalToys do
        -- this is an index of OWNED and FILTERED TOYS
        local toyItemID = C_ToyBox.GetToyFromIndex(index)
        if not toyItemID then
            break
        end

        if DoesItemHaveTooltipText(toyItemID, SEARCH_TEXT) then
            table.insert(toyHearthstones, toyItemID)
        end
    end
    return toyHearthstones
end
