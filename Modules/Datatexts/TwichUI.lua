---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
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
end

function BrandDT:OnLeave(panel)
    SetBrandText(panel)
end

function BrandDT:OnClick()
    if ConfigurationModule and ConfigurationModule.OpenOptionsUI then
        ConfigurationModule:OpenOptionsUI()
    end
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