--[[
    Options for the ChatEnhancement module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class DatatextConfigurationOptions
local Options = ConfigurationModule.Options.Datatext or {}
ConfigurationModule.Options.Datatext = Options

function Options:GetDB()
    if not ConfigurationModule:GetProfileDB().datatext then
        ConfigurationModule:GetProfileDB().datatext = {}
    end
    return ConfigurationModule:GetProfileDB().datatext
end

function Options:GetDatatextDB(datatextName)
    local db = self:GetDB()
    if not db[datatextName] then
        db[datatextName] = {}
    end
    return db[datatextName]
end

function Options:IsModuleEnabled(info)
    return self:GetDB().enabled or false
end

function Options:SetModuleEnabled(info, value)
    self:GetDB().enabled = value
    if (value) then
        local datatextModule = T:GetModule("Datatexts")
        datatextModule:Enable()
    else
        local datatextModule = T:GetModule("Datatexts")
        datatextModule:Disable()
        ConfigurationModule:PromptToReloadUI()
    end
end

local function RefreshDatatext(datatextName)
    ---@type DataTextModule
    local dtModule = T:GetModule("Datatexts")
    dtModule:RefreshDataText(datatextName)
end

--------- MOUNTS DATATEXT OPTIONS ---------
function Options:GetMountTextColor(info)
    local db = self:GetDatatextDB("mounts")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetMountTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("mounts")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Mount")
end

function Options:GetMountUseCustomColor(info)
    local db = self:GetDatatextDB("mounts")
    return db.customColor or false
end

function Options:SetMountUseCustomColor(info, value)
    local db = self:GetDatatextDB("mounts")
    db.customColor = value
    RefreshDatatext("TwichUI: Mount")
end

function Options:SetShowUtilityMounts(info, value)
    local db = self:GetDatatextDB("mounts")
    db.showUtilityMounts = value
    ---@type MountDataText
    local MountDataText = T:GetModule("Datatexts"):GetModule("MountDataText")
    MountDataText.flaggedForRebuild = true
    RefreshDatatext("TwichUI: Mount")
end

function Options:GetShowUtilityMounts(info)
    local db = self:GetDatatextDB("mounts")
    -- Default to true when unset, but respect false
    if db.showUtilityMounts == nil then
        return true
    end
    return db.showUtilityMounts
end

function Options:SetShowFavoriteMounts(info, value)
    local db = self:GetDatatextDB("mounts")
    db.showFavoriteMounts = value
    ---@type MountDataText
    local MountDataText = T:GetModule("Datatexts"):GetModule("MountDataText")
    MountDataText.flaggedForRebuild = true
    RefreshDatatext("TwichUI: Mount")
end

function Options:GetShowFavoriteMounts(info)
    local db = self:GetDatatextDB("mounts")
    -- Default to true when unset, but respect false
    if db.showFavoriteMounts == nil then
        return true
    end
    return db.showFavoriteMounts
end

function Options:GetVendorMount(info)
    local db = self:GetDatatextDB("mounts")
    return db.vendorMountID or 0
end

function Options:SetVendorMount(info, value)
    local db = self:GetDatatextDB("mounts")
    db.vendorMountID = value
    RefreshDatatext("TwichUI: Mount")
end

function Options:SetAuctionMount(info, value)
    local db = self:GetDatatextDB("mounts")
    db.auctionMountID = value
    RefreshDatatext("TwichUI: Mount")
end

function Options:GetAuctionMount(info)
    local db = self:GetDatatextDB("mounts")
    return db.auctionMountID or 0
end

function Options:IsVendorMountShortcutEnabled(info)
    return self:GetDB().vendorMountShortcutEnabled or false
end

function Options:SetVendorMountShortcutEnabled(info, value)
    self:GetDB().vendorMountShortcutEnabled = value
end

function Options:IsAuctionMountShortcutEnabled(info)
    return self:GetDB().auctionMountShortcutEnabled or false
end

function Options:SetAuctionMountShortcutEnabled(info, value)
    self:GetDB().auctionMountShortcutEnabled = value
end

function Options:GetPortalsUseCustomColor(info)
    local db = self:GetDatatextDB("portals")
    return db.customColor or false
end

function Options:SetPortalsUseCustomColor(info, value)
    local db = self:GetDatatextDB("portals")
    db.customColor = value
    RefreshDatatext("TwichUI: Portals")
end

function Options:GetPortalsTextColor(info)
    local db = self:GetDatatextDB("portals")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetPortalsTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("portals")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Portals")
end

function Options:GetMythicPlusUseCustomColor(info)
    local db = self:GetDatatextDB("mythicplus")
    return db.customColor or false
end

function Options:SetMythicPlusUseCustomColor(info, value)
    local db = self:GetDatatextDB("mythicplus")
    db.customColor = value
    RefreshDatatext("TwichUI: Mythic+")
end

function Options:GetMythicPlusTextColor(info)
    local db = self:GetDatatextDB("mythicplus")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetMythicPlusTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("mythicplus")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Mythic+")
end

function Options:GetMythicPlusShowAffixes(info)
    local db = self:GetDatatextDB("mythicplus")
    if db.showAffixes == nil then
        return true
    end
    return db.showAffixes
end

function Options:SetMythicPlusShowAffixes(info, value)
    local db = self:GetDatatextDB("mythicplus")
    db.showAffixes = value
end

function Options:GetMythicPlusShowDungeonBests(info)
    local db = self:GetDatatextDB("mythicplus")
    if db.showDungeonBests == nil then
        return true
    end
    return db.showDungeonBests
end

function Options:SetMythicPlusShowDungeonBests(info, value)
    local db = self:GetDatatextDB("mythicplus")
    db.showDungeonBests = value
end

function Options:GetMythicPlusShowRewardProgress(info)
    local db = self:GetDatatextDB("mythicplus")
    if db.showRewardProgress == nil then
        return true
    end
    return db.showRewardProgress
end

function Options:SetMythicPlusShowRewardProgress(info, value)
    local db = self:GetDatatextDB("mythicplus")
    db.showRewardProgress = value
end

function Options:GetFavoriteHearthstone(info)
    local db = self:GetDatatextDB("portals")
    return db.favoriteHearthstoneItemID or 0
end

function Options:SetFavoriteHearthstone(info, value)
    local db = self:GetDatatextDB("portals")
    db.favoriteHearthstoneItemID = tonumber(value) or 0
    RefreshDatatext("TwichUI: Portals")
end

function Options:GetChoresUseCustomColor(info)
    local db = self:GetDatatextDB("chores")
    return db.customColor or false
end

function Options:SetChoresUseCustomColor(info, value)
    local db = self:GetDatatextDB("chores")
    db.customColor = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTextColor(info)
    local db = self:GetDatatextDB("chores")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetChoresTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("chores")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresUseCustomDoneColor(info)
    local db = self:GetDatatextDB("chores")
    return db.customDoneColor == true
end

function Options:SetChoresUseCustomDoneColor(info, value)
    local db = self:GetDatatextDB("chores")
    db.customDoneColor = value == true
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresDoneTextColor(info)
    local db = self:GetDatatextDB("chores")
    if not db.doneTextColor then
        db.doneTextColor = { 0.2, 0.82, 0.32, 1 }
    end
    return unpack(db.doneTextColor)
end

function Options:SetChoresDoneTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("chores")
    db.doneTextColor = { r, g, b, a }
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTooltipHeaderFont(info)
    local db = self:GetDatatextDB("chores")
    return db.tooltipHeaderFont or "Friz Quadrata TT"
end

function Options:SetChoresTooltipHeaderFont(info, value)
    local db = self:GetDatatextDB("chores")
    db.tooltipHeaderFont = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTooltipHeaderFontSize(info)
    local db = self:GetDatatextDB("chores")
    return db.tooltipHeaderFontSize or 12
end

function Options:SetChoresTooltipHeaderFontSize(info, value)
    local db = self:GetDatatextDB("chores")
    db.tooltipHeaderFontSize = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTooltipEntryFont(info)
    local db = self:GetDatatextDB("chores")
    return db.tooltipEntryFont or "Friz Quadrata TT"
end

function Options:SetChoresTooltipEntryFont(info, value)
    local db = self:GetDatatextDB("chores")
    db.tooltipEntryFont = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTooltipEntryFontSize(info)
    local db = self:GetDatatextDB("chores")
    return db.tooltipEntryFontSize or 11
end

function Options:SetChoresTooltipEntryFontSize(info, value)
    local db = self:GetDatatextDB("chores")
    db.tooltipEntryFontSize = value
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetGatheringUseCustomColor(info)
    local db = self:GetDatatextDB("gathering")
    return db.customColor == true
end

function Options:SetGatheringUseCustomColor(info, value)
    local db = self:GetDatatextDB("gathering")
    db.customColor = value == true
    RefreshDatatext("TwichUI_GatheringDataText")
end

function Options:GetGatheringTextColor(info)
    local db = self:GetDatatextDB("gathering")
    if not db.textColor then
        db.textColor = { 1, 1, 1, 1 }
    end
    return unpack(db.textColor)
end

function Options:SetGatheringTextColor(info, r, g, b, a)
    local db = self:GetDatatextDB("gathering")
    db.textColor = { r, g, b, a }
    RefreshDatatext("TwichUI_GatheringDataText")
end

function Options:GetChoresTrackerMode(info)
    local db = self:GetDatatextDB("chores")
    return db.trackerMode or "framed"
end

function Options:SetChoresTrackerMode(info, value)
    local db = self:GetDatatextDB("chores")
    db.trackerMode = value or "framed"
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTrackerFrameTransparency(info)
    local db = self:GetDatatextDB("chores")
    local value = db.trackerFrameTransparency
    if type(value) ~= "number" then
        return 1
    end
    return math.min(1, math.max(0.2, value))
end

function Options:SetChoresTrackerFrameTransparency(info, value)
    local db = self:GetDatatextDB("chores")
    db.trackerFrameTransparency = math.min(1, math.max(0.2, tonumber(value) or 1))
    RefreshDatatext("TwichUI: Chores")
end

function Options:GetChoresTrackerBackgroundTransparency(info)
    local db = self:GetDatatextDB("chores")
    local value = db.trackerBackgroundTransparency
    if type(value) ~= "number" then
        return 0.95
    end
    return math.min(1, math.max(0, value))
end

function Options:SetChoresTrackerBackgroundTransparency(info, value)
    local db = self:GetDatatextDB("chores")
    db.trackerBackgroundTransparency = math.min(1, math.max(0, tonumber(value) or 0.95))
    RefreshDatatext("TwichUI: Chores")
end

--- GOBLIN DATATEXT OPTIONS ---
function Options:GetGoblinGoldDisplayMode(info)
    local db = self:GetDatatextDB("goblin")
    return db.displayMode or "full"
end

function Options:SetGoblinGoldDisplayMode(info, value)
    local db = self:GetDatatextDB("goblin")
    db.displayMode = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetGoblinShowProfessions(info)
    local db = self:GetDatatextDB("goblin")
    return db.showProfessions or false
end

function Options:SetGoblinShowProfessions(info, value)
    local db = self:GetDatatextDB("goblin")
    db.showProfessions = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetGoblinProfessionDisplayMode(info)
    local db = self:GetDatatextDB("goblin")
    return db.professionDisplayMode or "both"
end

function Options:SetGoblinProfessionDisplayMode(info, value)
    local db = self:GetDatatextDB("goblin")
    db.professionDisplayMode = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetGoblinProfessionShowMaxSkillLevel(info)
    local db = self:GetDatatextDB("goblin")
    return db.professionShowMaxSkillLevel or false
end

function Options:SetGoblinProfessionShowMaxSkillLevel(info, value)
    local db = self:GetDatatextDB("goblin")
    db.professionShowMaxSkillLevel = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetGoblinAddonShortcutsEnabled(info)
    local db = self:GetDatatextDB("goblin")
    return db.addonShortcutsEnabled or false
end

function Options:SetGoblinAddonShortcutsEnabled(info, value)
    local db = self:GetDatatextDB("goblin")
    db.addonShortcutsEnabled = value
    RefreshDatatext("TwichUI: Gold Goblin")
end

function Options:GetIsGoblinAddonEnabled(addonName)
    local db = self:GetDatatextDB("goblin")
    if not db.enabledAddons then
        db.enabledAddons = {}
    end
    return db.enabledAddons[addonName] or false
end

function Options:SetIsGoblinAddonEnabled(addonName, value)
    local db = self:GetDatatextDB("goblin")
    if not db.enabledAddons then
        db.enabledAddons = {}
    end
    db.enabledAddons[addonName] = value
end
