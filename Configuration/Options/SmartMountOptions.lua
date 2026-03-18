--[[
    Options for the SmartMount module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class SmartMountConfigurationOptions
local Options = ConfigurationModule.Options.SmartMount or {}
ConfigurationModule.Options.SmartMount = Options

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().smartMount then
        ConfigurationModule:GetProfileDB().smartMount = {}
    end
    return ConfigurationModule:GetProfileDB().smartMount
end

function Options:GetEnabled(info)
    return self:GetDB().enabled or false
end

function Options:SetEnabled(info, value)
    self:GetDB().enabled = value
    if (value) then
        local smartMount = T:GetModule("SmartMount")
        smartMount:Enable()
    else
        local smartMount = T:GetModule("SmartMount")
        smartMount:Disable()
    end
end

function Options:GetSelectedFlyingMount(info)
    return self:GetDB().flyingMount or nil
end

function Options:SetSelectedFlyingMount(info, value)
    self:GetDB().flyingMount = value
end

function Options:GetSelectedGroundMount(info)
    return self:GetDB().groundMount or nil
end

function Options:SetSelectedGroundMount(info, value)
    self:GetDB().groundMount = value
end

function Options:GetSelectedAquaticMount(info)
    return self:GetDB().aquaticMount or nil
end

function Options:SetSelectedAquaticMount(info, value)
    self:GetDB().aquaticMount = value
end

function Options:GetDismountIfMounted(info)
    return self:GetDB().dismountIfMounted or false
end

function Options:SetDismountIfMounted(info, value)
    self:GetDB().dismountIfMounted = value
end

function Options:GetUseAquaticMounts(info)
    return self:GetDB().useAquaticMounts or false
end

function Options:SetUseAquaticMounts(info, value)
    self:GetDB().useAquaticMounts = value
end

function Options:GetUseDruidFlightForm(info)
    return self:GetDB().useDruidFlightForm or false
end

function Options:SetUseDruidFlightForm(info, value)
    self:GetDB().useDruidFlightForm = value
end

function Options:GetUseDruidTravelForm(info)
    return self:GetDB().useDruidTravelForm or false
end

function Options:SetUseDruidTravelForm(info, value)
    self:GetDB().useDruidTravelForm = value
end

function Options:GetSmartMountKeybinding(info)
    return self:GetDB().smartMountKeybinding or ""
end

function Options:SetSmartMountKeybinding(info, value)
    self:GetDB().smartMountKeybinding = value

    ---@type SmartMountModule
    local smartMount = T:GetModule("SmartMount")
    smartMount:SetKeybinding()
end
