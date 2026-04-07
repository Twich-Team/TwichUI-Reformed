---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class BagsConfigurationOptions
local Options = ConfigurationModule.Options.Bags or {}
ConfigurationModule.Options.Bags = Options

local function GetModule()
    ---@type BagsModule
    return T:GetModule("Bags", true)
end

function Options:GetDB()
    local cfg = ConfigurationModule:GetProfileDB()
    if not cfg.bags then
        cfg.bags = {}
    end
    return cfg.bags
end

function Options:GetEnabled()
    local enabled = self:GetDB().enabled
    if enabled == nil then
        return true
    end
    return enabled == true
end

function Options:SetEnabled(_, value)
    self:GetDB().enabled = value == true
    local module = GetModule()
    if not module then
        return
    end

    if value then
        module:Enable()
    else
        module:Disable()
    end
end

function Options:GetLockFrame()
    return self:GetDB().lockFrame == true
end

function Options:SetLockFrame(_, value)
    self:GetDB().lockFrame = value == true
    local module = GetModule()
    if module and module.ApplyFrameStyle then
        module:ApplyFrameStyle()
    end
end

function Options:GetShowNewItems()
    local v = self:GetDB().showNewItems
    if v == nil then
        return true
    end
    return v == true
end

function Options:SetShowNewItems(_, value)
    self:GetDB().showNewItems = value == true
    local module = GetModule()
    if module and module.RequestRefresh then
        module:RequestRefresh(true)
    end
end

function Options:GetNewItemTimeout()
    return tonumber(self:GetDB().newItemTimeout) or 180
end

function Options:SetNewItemTimeout(_, value)
    self:GetDB().newItemTimeout = tonumber(value) or 180
end

function Options:GetShowEmptyCategories()
    return self:GetDB().showEmptyCategories == true
end

function Options:SetShowEmptyCategories(_, value)
    self:GetDB().showEmptyCategories = value == true
    local module = GetModule()
    if module and module.RequestRefresh then
        module:RequestRefresh(true)
    end
end

function Options:GetShowEquipmentSetCategories()
    local v = self:GetDB().showEquipmentSetCategories
    if v == nil then
        return true
    end
    return v == true
end

function Options:SetShowEquipmentSetCategories(_, value)
    self:GetDB().showEquipmentSetCategories = value == true
    local module = GetModule()
    if module and module.RequestRefresh then
        module:RequestRefresh(true)
    end
end

function Options:GetIconSize()
    return tonumber(self:GetDB().iconSize) or 34
end

function Options:SetIconSize(_, value)
    self:GetDB().iconSize = tonumber(value) or 34
    local module = GetModule()
    if module and module.RequestRefresh then
        module:RequestRefresh(true)
    end
end

function Options:GetColumns()
    return tonumber(self:GetDB().columns) or 12
end

function Options:SetColumns(_, value)
    self:GetDB().columns = tonumber(value) or 12
    local module = GetModule()
    if module and module.RequestRefresh then
        module:RequestRefresh(true)
    end
end

function Options:GetItemSpacing()
    return tonumber(self:GetDB().itemSpacing) or 6
end

function Options:SetItemSpacing(_, value)
    self:GetDB().itemSpacing = tonumber(value) or 6
    local module = GetModule()
    if module and module.RequestRefresh then
        module:RequestRefresh(true)
    end
end

function Options:GetSectionSpacing()
    return tonumber(self:GetDB().sectionSpacing) or 14
end

function Options:SetSectionSpacing(_, value)
    self:GetDB().sectionSpacing = tonumber(value) or 14
    local module = GetModule()
    if module and module.RequestRefresh then
        module:RequestRefresh(true)
    end
end

function Options:GetScale()
    return tonumber(self:GetDB().scale) or 1
end

function Options:SetScale(_, value)
    self:GetDB().scale = tonumber(value) or 1
    local module = GetModule()
    if module and module.ApplyFrameStyle then
        module:ApplyFrameStyle()
    end
end

function Options:GetAlpha()
    return tonumber(self:GetDB().alpha) or 1
end

function Options:SetAlpha(_, value)
    self:GetDB().alpha = tonumber(value) or 1
    local module = GetModule()
    if module and module.ApplyFrameStyle then
        module:ApplyFrameStyle()
    end
end

function Options:GetUseMasque()
    return self:GetDB().useMasque == true
end

function Options:SetUseMasque(_, value)
    self:GetDB().useMasque = value == true
    local module = GetModule()
    if module and module.RequestRefresh then
        module:RequestRefresh(true)
    end
end

function Options:GetDebugEnabled()
    return self:GetDB().debugEnabled == true
end

function Options:SetDebugEnabled(_, value)
    self:GetDB().debugEnabled = value == true
end

function Options:ToggleFrame()
    local module = GetModule()
    if module and module.Toggle then
        module:Toggle()
    end
end

function Options:ResetFramePosition()
    local db = self:GetDB()
    db.position = nil
    local module = GetModule()
    if module and module.RestoreFramePosition then
        module:RestoreFramePosition()
    end
end

function Options:OpenDebugConsole()
    local debugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if debugConsole and debugConsole.Show then
        debugConsole:Show("bags")
    end
end

function Options:IsMasqueAvailable()
    local lib = _G.LibStub and _G.LibStub("Masque", true)
    return lib ~= nil
end
