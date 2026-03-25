--[[
    Datatext providing gold-making information and quick access to professions
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)
---@type DataTextModule
local DatatextModule = T:GetModule("Datatexts")

---@class GoblinDataText : AceModule
---@field definition DatatextDefinition the datatext definition
---@field panel ElvUI_DT_Panel the panel instance for the datatext
---@field menuList table
---@field addonMenuList table
---@field flaggedForRebuild boolean indicates if the menu needs to be rebuilt
---@field addonMenuListFlaggedForRebuild boolean indicates if the addon menu needs to be rebuilt
---@field copper number current amount of copper the player has
---@field professions table list of the player's professions
local GDT = DatatextModule:NewModule("Goblin")

local GetMoney = GetMoney
local GetProfessions = GetProfessions

---@alias AddOnEntryConfig { prettyName: string, enabledByDefault: boolean, iconTexture: string, fallbackIconTexture: string|nil, openFunc: function|nil, availableFunc: function|nil }
---@class GoblinSupportedAddons <string, AddOnEntryConfig> the list of supported third-party addons for the Goblin datatext
GDT.SUPPORTED_ADDONS = {
    TradeSkillMaster = {
        prettyName = "TradeSkillMaster",
        enabledByDefault = false,
        iconTexture = "Interface\\AddOns\\TradeSkillMaster\\Media\\Logo",
        fallbackIconTexture = "Interface\\Icons\\INV_Misc_Coin_01",
        openFunc = function()
            ---@type ThirdPartyAPIModule
            local TPA = T:GetModule("ThirdPartyAPI")
            TPA.TSM:Open()
        end,
        availableFunc = function()
            return C_AddOns.IsAddOnLoaded("TradeSkillMaster")
        end
    },
    WeeklyKnowledge = {
        prettyName = "WeeklyKnowledge",
        enabledByDefault = false,
        iconTexture = "Interface\\AddOns\\WeeklyKnowledge\\Media\\icon",
        fallbackIconTexture = "Interface\\Icons\\INV_Misc_Coin_01",
        openFunc = function()
            ---@type ThirdPartyAPIModule
            local TPA = T:GetModule("ThirdPartyAPI")
            TPA:OpenWeeklyKnowledge()
        end,
        availableFunc = function()
            return C_AddOns.IsAddOnLoaded("WeeklyKnowledge")
        end
    },
    Farmer = {
        prettyName = "Farmer",
        enabledByDefault = false,
        iconTexture = "Interface\\Icons\\inv_misc_1h_farmhoe_a_01",
        fallbackIconTexture = "Interface\\Icons\\inv_misc_1h_farmhoe_a_01",
        openFunc = function()
            SlashCmdList.Farmer("radar")
        end,
        availableFunc = function()
            return C_AddOns.IsAddOnLoaded("Farmer")
        end
    }
}

local function GetOptions()
    return DatatextModule.GetOptions()
end

function GDT:GetPlayerProfessions()
    if self.professions then
        return self.professions
    end
    local profs = {}
    self.professions = profs

    local prof1, prof2, arch, fish, cook, firstAid = GetProfessions()
    local indices = { prof1, prof2, arch, fish, cook, firstAid }

    for _, idx in pairs(indices) do
        if idx then
            local name, icon, skillLevel, maxSkillLevel, numAbilities,
            spellOffset, skillLine, skillModifier = GetProfessionInfo(idx)
            if name then
                table.insert(profs, {
                    name = name,
                    icon = icon,
                    skillLevel = skillLevel,
                    maxSkillLevel = maxSkillLevel,
                    skillModifier = skillModifier,
                    idx = idx,
                })
            end
        end
    end

    return profs
end

function GDT:Refresh()
    if not self.panel then
        return
    end

    local Options = GetOptions()

    local displayMode = Options:GetGoblinGoldDisplayMode()
    local copper = self.copper or 0
    local display = '0'
    if displayMode == "full" then
        display = T.Tools.Text.FormatCopper(copper)
    else
        display = T.Tools.Text.FormatCopperShort(copper)
    end

    self.panel.text:SetText(display)
end

function GDT:OnEvent(panel, event, ...)
    if not self.panel then
        self.panel = panel
    end

    if event == "SKILL_LINES_CHANGED" or event == "CHAT_MSG_SKILL" then
        self.professions = nil
        return
    end

    self.copper = GetMoney()
    self:Refresh()
end

-- utility func to color text white
local function ColorWhite(text)
    return T.Tools.Text.Color(T.Tools.Colors.WHITE, text)
end

function GDT:HandleProfessionsTooltip(tt, Options)
    tt:AddLine("Professions")

    --- utility func to add a profession entry to the tooltip
    local function AddProfessionEntry(profInfo)
        local left = ColorWhite(T.Tools.Text.Icon(profInfo.icon) .. " " .. profInfo.name)
        local right = ""

        --- both mode
        if Options:GetGoblinProfessionDisplayMode() == "both" then
            local modifier = nil
            if profInfo.skillModifier > 0 then
                modifier = T.Tools.Text.Color(T.Tools.Colors.GREEN, "+" .. tostring(profInfo.skillModifier))
                right = profInfo.skillLevel .. " (" .. modifier .. ")"
            elseif profInfo.skillModifier < 0 then
                modifier = T.Tools.Text.Color(T.Tools.Colors.RED, "-" .. tostring(profInfo.skillModifier))
                right = profInfo.skillLevel .. " (" .. modifier .. ")"
            else
                right = profInfo.skillLevel
            end
            --- total mode
        elseif Options:GetGoblinProfessionDisplayMode() == "total" then
            local total = profInfo.skillLevel + profInfo.skillModifier
            local color = T.Tools.Colors.WHITE
            if profInfo.skillModifier > 0 then
                color = T.Tools.Colors.GREEN
            elseif profInfo.skillModifier < 0 then
                color = T.Tools.Colors.RED
            end
            right = T.Tools.Text.Color(color, tostring(total))
            --- level mode
        elseif Options:GetGoblinProfessionDisplayMode() == "level" then
            right = profInfo.skillLevel
            --- modifier only
        elseif Options:GetGoblinProfessionDisplayMode() == "modifiers" then
            local color = T.Tools.Colors.WHITE
            local plusMinus = ""

            if profInfo.skillModifier > 0 then
                color = T.Tools.Colors.GREEN
                plusMinus = "+"
            elseif profInfo.skillModifier < 0 then
                color = T.Tools.Colors.RED
                plusMinus = "-"
            end

            right = T.Tools.Text.Color(color, plusMinus .. tostring(profInfo.skillModifier))
        end


        if Options:GetGoblinProfessionShowMaxSkillLevel() then
            right = right .. "/" .. profInfo.maxSkillLevel
        end
        right = ColorWhite(right)


        tt:AddDoubleLine(left, right)
    end

    for _, profInfo in ipairs(self:GetPlayerProfessions()) do
        AddProfessionEntry(profInfo)
    end
end

function GDT:OnEnter()
    local tt = DatatextModule:GetElvUITooltip()
    if not tt then
        return
    end
    tt:ClearLines()

    local addSpaceBeforeHelperText = false
    local Options = GetOptions()

    if (Options:GetGoblinShowProfessions()) then
        addSpaceBeforeHelperText = true
        self:HandleProfessionsTooltip(tt, Options)
    end

    -- helper text
    if addSpaceBeforeHelperText then
        tt:AddLine(" ")
    end
    tt:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Click: Professions menu"))

    if Options:GetGoblinAddonShortcutsEnabled() then
        tt:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Right-Click: AddOns menu"))
    end
    DatatextModule:ShowDatatextTooltip(tt)
end

function GDT:OnLeave()
    local tt = DatatextModule:GetActiveDatatextTooltip()
    if tt and tt.Hide then
        DatatextModule:HideDatatextTooltip(tt)
    end
end

local function OpenProfessionByIndex(idx)
    if not idx then return end

    local name, icon, skillLevel, maxSkillLevel, numAbilities, spellOffset = GetProfessionInfo(idx)
    if spellOffset and numAbilities and numAbilities > 0 then
        CastSpell(spellOffset + 1, "spell")
    end
end

function GDT:GetAddOnMenuList()
    if self.addonMenuList and not self.addonMenuListFlaggedForRebuild then
        return self.addonMenuList
    end

    local menuList = {}
    self.addonMenuList = menuList

    tinsert(menuList, {
        text = "AddOns",
        isTitle = true,
        notCheckable = true,
    })

    local Options = GetOptions()
    local anyAdded = false

    local addonList = {}

    for key, addon in pairs(GDT.SUPPORTED_ADDONS) do
        table.insert(addonList, {
            key = key, -- or addon.prettyName / addon.internalName
            config = addon,
        })
    end

    table.sort(addonList, function(a, b)
        return (a.config.prettyName or "") < (b.config.prettyName or "")
    end)

    for _, entry in ipairs(addonList) do
        local addonKey = entry.key
        local addonConfig = entry.config

        if Options:GetIsGoblinAddonEnabled(addonKey) then
            if addonConfig.availableFunc and addonConfig.availableFunc() then
                anyAdded = true
                tinsert(menuList, {
                    text = ColorWhite(T.Tools.Text.Icon(addonConfig.iconTexture or addonConfig.fallbackIconTexture)
                        .. " " .. addonConfig.prettyName),
                    func = function()
                        if addonConfig.openFunc then
                            addonConfig.openFunc()
                        end
                    end,
                })
            end
        end
    end
    if not anyAdded then
        tinsert(menuList, {
            text = T.Tools.Text.Color(T.Tools.Colors.GRAY, "No addons enabled"),
            isTitle = true,
            notCheckable = true,
        })
    end

    return self.addonMenuList
end

function GDT:GetMenuList()
    if self.menuList and not self.flaggedForRebuild then
        return self.menuList
    end

    local menuList = {}
    self.menuList = menuList

    -- Professions
    tinsert(menuList, {
        text = "Professions",
        isTitle = true,
        notCheckable = true,
    })

    --- add the profession entry to the menulist
    local function AddProfessionEntry(profInfo)
        tinsert(menuList, {
            text = T.Tools.Text.Icon(profInfo.icon) .. " " .. profInfo.name,
            func = function() OpenProfessionByIndex(profInfo.idx) end,
            notCheckable = true,
        })
    end

    for _, profInfo in ipairs(self:GetPlayerProfessions()) do
        AddProfessionEntry(profInfo)
    end

    return self.menuList
end

function GDT:OnClick(panel, button)
    if button == "RightButton" then
        if GetOptions():GetGoblinAddonShortcutsEnabled() then
            local addonMenuList = self:GetAddOnMenuList()
            DatatextModule:ShowMenu(panel, addonMenuList)
        end
        return
    end
    local menuList = self:GetMenuList()
    DatatextModule:ShowMenu(panel, menuList)
end

function GDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Gold Goblin",
        prettyName = "Gold",
        events = { 'ACCOUNT_MONEY', 'PLAYER_MONEY', 'SEND_MAIL_MONEY_CHANGED', 'SEND_MAIL_COD_CHANGED',
            'PLAYER_TRADE_MONEY',
            'TRADE_MONEY_CHANGED', 'CURRENCY_DISPLAY_UPDATE', 'PERKS_PROGRAM_CURRENCY_REFRESH', 'PLAYER_LOGIN',
            'SKILL_LINES_CHANGED', 'CHAT_MSG_SKILL' },
        onEventFunc = DatatextModule:CreateBoundCallback(self, "OnEvent"),
        onEnterFunc = DatatextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DatatextModule:CreateBoundCallback(self, "OnLeave"),
        onClickFunc = DatatextModule:CreateBoundCallback(self, "OnClick"),
        module = self,
    }
    DatatextModule:Inform(self.definition)
end
