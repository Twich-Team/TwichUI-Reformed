--[[
    Provides standard color palette for the addon.
]]
---@type TwichUI
local TwichRx = _G.TwichRx
local T, W, I, C = unpack(TwichRx)

--- @class ThirdPartyAPIModule : AceModule
--- @field TSM TradeSkillMasterAPI
local TPA = T:NewModule("ThirdPartyAPI")

function TPA:CreateFailureMessage(addonName, command)
    return string.format("Could not open %s; %s is unavailable. Do you have %s installed and enabled?", addonName,
        command, addonName)
end

function TPA:OpenThroughSlashCommand(addonName, command)
    local ok = T.Tools.Game:RunSlashCommandIfAvailable(command)
    if not ok then
        T:Print(self:CreateFailureMessage(addonName, command))
    end
end

function TPA:OpenWeeklyKnowledge()
    self:OpenThroughSlashCommand("Weekly Knowledge", "/wk")
end
