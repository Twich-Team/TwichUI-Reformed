--[[
    Datatext providing quick access to favorite and utility mounts.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local SummonByID = C_MountJournal.SummonByID

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

---@class MountDataText : AceEvent-3.0
---@field definition DatatextDefinition the datatext definition
---@field panel ElvUI_DT_Panel the panel instance for the datatext
---@field menuList table
---@field flaggedForRebuild boolean indicates if the menu needs to be rebuilt
local MDT = DataTextModule:NewModule("MountDataText", "AceEvent-3.0")

---@return DatatextConfigurationOptions options
local function GetOptions()
    return T:GetModule("Configuration").Options.Datatext
end

--- Refreshes the datatext display
function MDT:Refresh()
    if not self.panel then
        return
    end

    local Options = GetOptions()

    -- The display of this text doesnt change, so update it now
    local r, g, b
    if not Options:GetMountUseCustomColor() then
        r, g, b = DataTextModule:GetElvUIValueColor()
    else
        r, g, b = Options:GetMountTextColor()
    end

    self.panel.text:SetText(T.Tools.Text.ColorRGB(r, g, b, "Mounts"))
end

--- Handles events for the datatext
function MDT:OnEvent(panel, event, ...)
    -- lazy load the panel reference
    if not self.panel then
        self.panel = panel
    end

    if event == DataTextModule.CommonEvents.ELVUI_FORCE_UPDATE then
        self:Refresh()
    end
end

--- Builds the menu that is shown when the datatext is clicked
function MDT:GetMenuList()
    if self.menuList and not self.flaggedForRebuild then
        return self.menuList
    end

    local menuList = {}
    self.menuList = menuList

    ---@param mountInfo {name: string, spellID: number, icon: string, mountID: number, isFavorite: boolean}
    local function AddMountEntry(mountInfo)
        local mountID = tonumber(mountInfo.mountID) or 0
        tinsert(menuList, {
            text = T.Tools.Text.Icon(mountInfo.icon) .. " " .. mountInfo.name,
            notCheckable = true,
            spell = mountInfo.spellID,
            func = (mountID > 0) and function()
                SummonByID(mountID)
            end or nil,
        })
    end

    ---@type MountUtilityModule
    local MountUtilityModule = T:GetModule("MountUtility")
    local Options = GetOptions()
    local showUtility = Options:GetShowUtilityMounts()
    local showFavorites = Options:GetShowFavoriteMounts()


    -- Build lookup of utility mounts by mountID so we can
    -- avoid showing the same mount in both Favorites and Utility.
    local favoriteMounts = MountUtilityModule:GetPlayerMounts("FAVORITE")
    local utilityMounts = MountUtilityModule:GetPlayerMounts("UTILITY")
    local utilityByID = {}
    for _, mountInfo in ipairs(utilityMounts) do
        if mountInfo.mountID then
            utilityByID[mountInfo.mountID] = true
        end
    end

    -- Only show favorites that are not also utility mounts.
    if showFavorites then
        tinsert(menuList, {
            text = "Favorite Mounts",
            isTitle = true,
            notCheckable = true,
        })
        for _, mountInfo in ipairs(favoriteMounts) do
            if not (mountInfo.mountID and utilityByID[mountInfo.mountID]) then
                AddMountEntry(mountInfo)
            end
        end
    end


    if showUtility then
        tinsert(menuList, {
            text = "Utility Mounts",
            isTitle = true,
            notCheckable = true,
        })
        for _, mountInfo in ipairs(utilityMounts) do
            AddMountEntry(mountInfo)
        end
    end

    self.menuList = menuList
    self.flaggedForRebuild = false
    return menuList
end

function ColorGray(text)
    return T.Tools.Text.Color(T.Tools.Colors.GRAY, text)
end

function MDT:OnEnter(panel)
    local tt = DataTextModule:GetElvUITooltip()
    if not tt then
        return
    end
    tt:ClearLines()

    ---@type MountUtilityModule
    local MountUtilityModule = T:GetModule("MountUtility")
    if MountUtilityModule.flaggedForRefresh then
        tt:AddLine(T.Tools.Text.Color(T.Tools.Colors.RED,
            "NOTE: Mounts will be updated when the mount journal closes"))
        tt:AddLine(" ")
    end

    local Options = GetOptions()
    local spaceNeeded = true
    if Options:GetShowFavoriteMounts() or Options:GetShowUtilityMounts() then
        tt:AddLine("Click to access mounts")
    else
        spaceNeeded = false
    end
    local spaceAdded = false

    if Options:IsVendorMountShortcutEnabled() then
        if not spaceAdded and spaceNeeded then
            tt:AddLine(" ")
            spaceAdded = true
        end
        tt:AddLine(ColorGray("Right-click: Summon vendor mount"))
    end
    if Options:IsAuctionMountShortcutEnabled() then
        if not spaceAdded and spaceNeeded then
            tt:AddLine(" ")
            spaceAdded = true
        end
        tt:AddLine(ColorGray("Shift+Right-click: Summon auction mount"))
    end

    DataTextModule:ShowDatatextTooltip(tt)
end

function MDT:OnLeave()
    local tt = DataTextModule:GetActiveDatatextTooltip()
    if tt and tt.Hide then
        DataTextModule:HideDatatextTooltip(tt)
    end
end

--- Handles click events for the datatext
function MDT:OnClick(panel, button)
    if button == "RightButton" then
        local Options = GetOptions()
        if IsShiftKeyDown() and Options:IsAuctionMountShortcutEnabled() then
            local mountID = Options:GetAuctionMount()
            SummonByID(mountID)
            return
        elseif Options:IsVendorMountShortcutEnabled() then
            local mountID = Options:GetVendorMount()
            SummonByID(mountID)
            return
        end
    end

    self.flaggedForRebuild = true
    local menuList = self:GetMenuList()
    DataTextModule:ShowMenu(panel, menuList)
end

--- Handles the custom PLAYER_MOUNT_CACHE_UPDATED event to flag the menu for rebuild
function MDT:PlayerMountCacheUpdated()
    self.flaggedForRebuild = true
end

function MDT:PlayerMountCacheDirty()
end

function MDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Mount",
        prettyName = "Mounts",
        events = nil,
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }
    DataTextModule:Inform(self.definition)
end

--- Called when the module is enabled
function MDT:OnEnable()
    -- listen to mount cache updates to refresh the menu when required
    self:RegisterMessage("PLAYER_MOUNT_CACHE_UPDATED", "PlayerMountCacheUpdated")
end
