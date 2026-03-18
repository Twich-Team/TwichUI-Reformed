--[[
    Options for the gossip hotkeys module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class GossipHotkeysConfigurationOptions
local Options = ConfigurationModule.Options.GossipHotkeys or {}
ConfigurationModule.Options.GossipHotkeys = Options

---@return table gossipHotkeysDB the profile-level gossip hotkeys configuration database.
function Options:GetGossipHotkeysDB()
    if not ConfigurationModule:GetProfileDB().gossipHotkeys then
        ConfigurationModule:GetProfileDB().gossipHotkeys = {}
    end
    return ConfigurationModule:GetProfileDB().gossipHotkeys
end

function Options:IsModuleEnabled(info)
    local db = self:GetGossipHotkeysDB()
    return db.enabled or false
end

function Options:SetModuleEnabled(info, value)
    local db = self:GetGossipHotkeysDB()
    db.enabled = value

    -- Immediately enable/disable the underlying module so changes take
    -- effect without requiring a full UI reload.
    local ok, QOL = pcall(T.GetModule, T, "QualityOfLife", true)
    if ok and QOL and QOL.GetModule then
        local ok2, module = pcall(QOL.GetModule, QOL, "GossipHotkeys", true)
        if ok2 and module then
            if value and not module:IsEnabled() then
                module:Enable()
            elseif not value and module:IsEnabled() then
                module:Disable()
            end
        end
    end
end
