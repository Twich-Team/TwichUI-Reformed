---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local ReloadUI = _G.ReloadUI

---@class BrandDataText : AceModule
local BrandDT = DataTextModule:NewModule("BrandDataText")

local function SetBrandText(panel)
    if not (panel and panel.text) then
        return
    end

    panel.text:SetText("TwichUI")
    panel.text:SetTextColor(0.96, 0.94, 0.86)
end

function BrandDT:OnEnter(panel)
    if not panel or not panel.text then
        return
    end

    panel.text:SetTextColor(1.0, 0.78, 0.28)

    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then return end

    tooltip:ClearLines()
    tooltip:AddLine("TwichUI Reformed")
    tooltip:AddLine(" ")
    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Left-click  — Open menu"))
    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Right-click — Reload UI"))
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function BrandDT:OnLeave(panel)
    SetBrandText(panel)
    DataTextModule:HideDatatextTooltip(DataTextModule:GetActiveDatatextTooltip())
end

function BrandDT:OnClick(panel, button)
    if button == "RightButton" then
        ReloadUI()
        return
    end

    -- Left-click: show quick-access menu
    local moversModule = _G.TwichMoverModule
    local moversActive = moversModule and moversModule:IsActive() or false

    local menuList = {
        {
            text = "Open Settings",
            func = function()
                if ConfigurationModule and ConfigurationModule.OpenOptionsUI then
                    ConfigurationModule:OpenOptionsUI()
                end
            end,
        },
        {
            text = moversActive and "Lock Movers" or "Unlock Movers",
            func = function()
                if moversModule then
                    moversModule:Toggle()
                end
            end,
        },
    }

    DataTextModule:ShowMenu(panel, menuList)
end

function BrandDT:OnInitialize()
    ---@class DatatextDefinition
    self.definition = {
        name = "TwichUI: TwichUI",
        prettyName = "TwichUI",
        events = {
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = function(panel)
            SetBrandText(panel)
        end,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end
