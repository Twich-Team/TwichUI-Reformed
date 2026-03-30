---@diagnostic disable: undefined-field, inject-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

local abs = math.abs
local floor = math.floor
local format = string.format
local date = date
local ipairs = ipairs
local pairs = pairs
local sort = table.sort
local tinsert = table.insert
local wipe = wipe

local BreakUpLargeNumbers = _G.BreakUpLargeNumbers
local CreateFrame = _G.CreateFrame
local GameTime_GetGameTime = _G.GameTime_GetGameTime
local GetAddOnMemoryUsage = _G.GetAddOnMemoryUsage
local GetFramerate = _G.GetFramerate
local GetGameTime = _G.GetGameTime
local GetLatestThreeSenders = _G.GetLatestThreeSenders
local GetLootSpecialization = _G.GetLootSpecialization
local GetNetStats = _G.GetNetStats
local GetNumSpecializations = _G.GetNumSpecializations
local GetServerTime = _G.GetServerTime
local GetSpecialization = _G.GetSpecialization
local GetSpecializationInfo = _G.GetSpecializationInfo
local GetTime = _G.GetTime
local HasNewMail = _G.HasNewMail
local C_Mail = _G.C_Mail
local C_Timer = _G.C_Timer
local IsControlKeyDown = _G.IsControlKeyDown
local InCombatLockdown = _G.InCombatLockdown
local IsShiftKeyDown = _G.IsShiftKeyDown
local SecondsToTime = _G.SecondsToTime
local SetLootSpecialization = _G.SetLootSpecialization
local ToggleCharacter = _G.ToggleCharacter
local ToggleFriendsFrame = _G.ToggleFriendsFrame
local ToggleCalendar = _G.ToggleCalendar
local TogglePlayerSpellsFrame = _G.TogglePlayerSpellsFrame
local UpdateAddOnMemoryUsage = _G.UpdateAddOnMemoryUsage

local C_AddOns = _G.C_AddOns
local C_BattleNet = _G.C_BattleNet
local C_ClassTalents = _G.C_ClassTalents
local C_CurrencyInfo = _G.C_CurrencyInfo
local C_DateAndTime = _G.C_DateAndTime
local C_FriendList = _G.C_FriendList
local C_SpecializationInfo = _G.C_SpecializationInfo
local C_Traits = _G.C_Traits

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local MailFrame = _G.MailFrame
local PLAYER_STATUS = _G.PLAYER_STATUS
local TIMEMANAGER_TOOLTIP_LOCALTIME = _G.TIMEMANAGER_TOOLTIP_LOCALTIME or "Local Time"
local TIMEMANAGER_TOOLTIP_REALMTIME = _G.TIMEMANAGER_TOOLTIP_REALMTIME or "Realm Time"
local UIParent = _G.UIParent
local collectgarbage = collectgarbage
local STARTER_BUILD_CONFIG_ID = _G.Constants and _G.Constants.TraitConsts and
    _G.Constants.TraitConsts.STARTER_BUILD_TRAIT_CONFIG_ID or nil

local UPDATE_FAST = 1
local UPDATE_SLOW = 5
local FRIENDS_REFRESH_REQUEST_INTERVAL = 15
local SPEC_ICON_FORMAT = "|T%s:%d:%d:0:0:64:64:4:60:4:60|t"
local SYSTEM_MEMORY_LIVE_INTERVAL = 3
local SYSTEM_MEMORY_FRAME_WIDTH = 500
local SYSTEM_MEMORY_FRAME_HEIGHT = 480
local SYSTEM_MEMORY_ROW_HEIGHT = 20
local friendsRequestRefreshToken = 0
local lastFriendsRefreshRequestAt = 0
local DURABILITY_SLOTS = {
    { id = 1,  label = _G.INVTYPE_HEAD },
    { id = 3,  label = _G.INVTYPE_SHOULDER },
    { id = 5,  label = _G.INVTYPE_CHEST },
    { id = 6,  label = _G.INVTYPE_WAIST },
    { id = 7,  label = _G.INVTYPE_LEGS },
    { id = 8,  label = _G.INVTYPE_FEET },
    { id = 9,  label = _G.INVTYPE_WRIST },
    { id = 10, label = _G.INVTYPE_HAND },
    { id = 16, label = _G.INVTYPE_WEAPONMAINHAND },
    { id = 17, label = _G.INVTYPE_WEAPONOFFHAND },
}

---@return DatatextConfigurationOptions
local function GetOptions()
    ---@type ConfigurationModule
    local configurationModule = T:GetModule("Configuration")
    return configurationModule.Options.Datatext
end

local function GetDatatextDB(key)
    local options = GetOptions()
    return options and options.GetDatatextDB and options:GetDatatextDB(key) or {}
end

local function GetColorOverride(key)
    local db = GetDatatextDB(key)
    if db.customColor == true and type(db.textColor) == "table" then
        return db.textColor[1] or 1, db.textColor[2] or 1, db.textColor[3] or 1, db.textColor[4] or 1
    end

    return nil
end

local function GetInlineColorOverride(key, enabledField, colorField)
    local db = GetDatatextDB(key)
    if db[enabledField] == true and type(db[colorField]) == "table" then
        return db[colorField][1] or 1, db[colorField][2] or 1, db[colorField][3] or 1, db[colorField][4] or 1
    end

    return nil
end

local function ColorizeText(text, r, g, b, a)
    if not text then
        return ""
    end

    if r == nil or g == nil or b == nil then
        return text
    end

    local alpha = math.max(0, math.min(255, floor((a or 1) * 255 + 0.5)))
    local red = math.max(0, math.min(255, floor(r * 255 + 0.5)))
    local green = math.max(0, math.min(255, floor(g * 255 + 0.5)))
    local blue = math.max(0, math.min(255, floor(b * 255 + 0.5)))
    return format("|c%02x%02x%02x%02x%s|r", alpha, red, green, blue, text)
end

local function SetPanelText(panel, text, key, defaultR, defaultG, defaultB, defaultA)
    if not (panel and panel.text) then
        return
    end

    local previousText = panel.text:GetText()
    panel.text:SetText(text or "")
    local r, g, b, a = GetColorOverride(key)
    if r then
        panel.text:SetTextColor(r, g, b, a or 1)
        DataTextModule:MaybeFlashPanel(panel, key, previousText, text or "")
        return
    end

    panel.text:SetTextColor(defaultR or 1, defaultG or 1, defaultB or 1, defaultA or 1)
    DataTextModule:MaybeFlashPanel(panel, key, previousText, text or "")
end

local function AddTooltipHintLine(tooltip, text)
    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, text))
end

local function AbbreviateName(name, maxLength)
    local text = tostring(name or "")
    if #text <= (maxLength or 12) then
        return text
    end

    return text:sub(1, math.max(1, (maxLength or 12) - 1)) .. "…"
end

local function FormatQuantity(value)
    if type(value) ~= "number" then
        return "0"
    end

    if value >= 1000000 then
        return format("%.1fm", value / 1000000)
    end

    if value >= 1000 then
        return format("%.1fk", value / 1000)
    end

    return tostring(floor(value + 0.5))
end

local function FormatPercent(value)
    if type(value) ~= "number" then
        return "0%"
    end
    return format("%d%%", floor(value + 0.5))
end

local function IconText(texture, size)
    if not texture then
        return ""
    end

    local iconSize = tonumber(size) or 14
    return format(SPEC_ICON_FORMAT, tostring(texture), iconSize, iconSize)
end

local function TimeSettings()
    local db = GetDatatextDB("time")
    return {
        localTime = db.localTime == true,
        twentyFourHour = db.twentyFourHour ~= false,
        showAmPm = db.showAmPm ~= false,
        showSeconds = db.showSeconds == true,
        showDailyReset = db.showDailyReset ~= false,
        showWeeklyReset = db.showWeeklyReset ~= false,
    }
end

local function SpecSettings()
    local db = GetDatatextDB("specialization")
    return {
        showIcon = db.showIcon ~= false,
        iconOnly = db.iconOnly == true,
        abbreviate = db.abbreviate ~= false,
        displayStyle = type(db.displayStyle) == "string" and db.displayStyle or "SPEC",
    }
end

local function GetSpecInfoByIndex(specIndex)
    if type(GetSpecializationInfo) ~= "function" or type(specIndex) ~= "number" or specIndex <= 0 then
        return nil
    end

    local specID, name, _, icon, _, role = GetSpecializationInfo(specIndex)
    if not specID then
        return nil
    end

    return {
        index = specIndex,
        id = specID,
        name = tostring(name or "Unknown"),
        icon = icon,
        role = role,
    }
end

local function GetSpecInfoByID(specID)
    if type(GetNumSpecializations) ~= "function" then
        return nil
    end

    local numSpecs = GetNumSpecializations() or 0
    for specIndex = 1, numSpecs do
        local info = GetSpecInfoByIndex(specIndex)
        if info and info.id == specID then
            return info
        end
    end

    return nil
end

local function GetCurrentSpecInfo()
    if type(GetSpecialization) ~= "function" then
        return nil
    end

    local specIndex = GetSpecialization()
    if not specIndex then
        return nil
    end

    return GetSpecInfoByIndex(specIndex)
end

local function GetLootSpecInfo(currentSpecInfo)
    if type(GetLootSpecialization) ~= "function" then
        return currentSpecInfo, true
    end

    local lootSpecID = GetLootSpecialization() or 0
    if lootSpecID == 0 then
        return currentSpecInfo, true
    end

    return GetSpecInfoByID(lootSpecID), false
end

local function GetActiveLoadoutName(currentSpecInfo)
    if not currentSpecInfo then
        return nil
    end

    if C_ClassTalents and type(C_ClassTalents.GetHasStarterBuild) == "function" and
        type(C_ClassTalents.GetStarterBuildActive) == "function" and
        C_ClassTalents.GetHasStarterBuild() and C_ClassTalents.GetStarterBuildActive() then
        return _G.TALENT_FRAME_DROP_DOWN_STARTER_BUILD or "Starter Build"
    end

    if not (C_ClassTalents and type(C_ClassTalents.GetLastSelectedSavedConfigID) == "function" and C_Traits and
            type(C_Traits.GetConfigInfo) == "function") then
        return nil
    end

    local configID = C_ClassTalents.GetLastSelectedSavedConfigID(currentSpecInfo.id)
    if not configID then
        return nil
    end

    local configInfo = C_Traits.GetConfigInfo(configID)
    return configInfo and configInfo.name or nil
end

local function FormatSpecLabel(info, settings, maxLength)
    if not info then
        return "Unknown"
    end

    local label = settings.abbreviate and AbbreviateName(info.name, maxLength or 12) or info.name
    if settings.iconOnly == true then
        if settings.showIcon ~= false and info.icon then
            return IconText(info.icon, 14)
        end
        return label
    end

    if settings.showIcon ~= false and info.icon then
        return format("%s %s", IconText(info.icon, 14), label)
    end

    return label
end

local function BuildSpecializationText()
    local settings = SpecSettings()
    local currentSpec = GetCurrentSpecInfo()
    if not currentSpec then
        return "Spec"
    end

    local text = FormatSpecLabel(currentSpec, settings, 14)
    local showLoot = settings.displayStyle == "SPEC_LOOT" or settings.displayStyle == "FULL"
    local showLoadout = settings.displayStyle == "SPEC_LOADOUT" or settings.displayStyle == "FULL"

    if showLoot then
        local lootSpec, isDefaultLoot = GetLootSpecInfo(currentSpec)
        if settings.iconOnly == true then
            if lootSpec and not isDefaultLoot then
                text = format("%s %s", text, FormatSpecLabel(lootSpec, settings, 14))
            end
        else
            local lootLabel = isDefaultLoot and "Default" or FormatSpecLabel(lootSpec, settings, 14)
            text = format("%s / Loot %s", text, lootLabel)
        end
    end

    if showLoadout then
        local loadoutName = GetActiveLoadoutName(currentSpec)
        if type(loadoutName) == "string" and loadoutName ~= "" then
            local displayLoadout = settings.abbreviate and AbbreviateName(loadoutName, settings.iconOnly and 10 or 16) or
                loadoutName
            if settings.iconOnly == true then
                text = format("%s %s", text, displayLoadout)
            else
                text = format("%s / %s", text, displayLoadout)
            end
        end
    end

    return text
end

local function OpenTalentsFrame()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return
    end

    if not _G.PlayerSpellsFrame and C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        pcall(C_AddOns.LoadAddOn, "Blizzard_ClassTalentUI")
    end

    if type(TogglePlayerSpellsFrame) == "function" then
        local suggestedTab = _G.PlayerSpellsMicroButton and _G.PlayerSpellsMicroButton.suggestedTab or nil
        TogglePlayerSpellsFrame(suggestedTab)
    end
end

local function EnsureTalentsFrameForLoadouts()
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        return nil
    end

    if not _G.PlayerSpellsFrame then
        if type(_G.PlayerSpellsFrame_LoadUI) == "function" then
            pcall(_G.PlayerSpellsFrame_LoadUI)
        elseif C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
            pcall(C_AddOns.LoadAddOn, "Blizzard_ClassTalentUI")
        end
    end

    local talentsFrame = _G.PlayerSpellsFrame and _G.PlayerSpellsFrame.TalentsFrame or nil
    if talentsFrame and type(talentsFrame.LoadConfigByPredicate) == "function" then
        return talentsFrame
    end

    return nil
end

local function GetActiveLoadoutConfigID(currentSpecInfo)
    if not currentSpecInfo then
        return nil
    end

    if STARTER_BUILD_CONFIG_ID and C_ClassTalents and type(C_ClassTalents.GetHasStarterBuild) == "function" and
        type(C_ClassTalents.GetStarterBuildActive) == "function" and C_ClassTalents.GetHasStarterBuild() and
        C_ClassTalents.GetStarterBuildActive() then
        return STARTER_BUILD_CONFIG_ID
    end

    if C_ClassTalents and type(C_ClassTalents.GetLastSelectedSavedConfigID) == "function" then
        return C_ClassTalents.GetLastSelectedSavedConfigID(currentSpecInfo.id)
    end

    return nil
end

local function SelectTalentLoadout(configID)
    local talentsFrame = EnsureTalentsFrameForLoadouts()
    if not talentsFrame or not configID then
        return
    end

    talentsFrame:LoadConfigByPredicate(function(_, candidateConfigID)
        return candidateConfigID == configID
    end)
end

local function BuildLoadoutMenuList()
    local currentSpec = GetCurrentSpecInfo()
    local menuList = {
        { text = "Loadouts", isTitle = true, notCheckable = true },
    }

    if not currentSpec or not (C_ClassTalents and type(C_ClassTalents.GetConfigIDsBySpecID) == "function") then
        tinsert(menuList, {
            text = T.Tools.Text.Color(T.Tools.Colors.GRAY, "No loadouts available"),
            notCheckable = true,
            disabled = true,
        })
        return menuList
    end

    local activeConfigID = GetActiveLoadoutConfigID(currentSpec)
    local buildIDs = C_ClassTalents.GetConfigIDsBySpecID(currentSpec.id)
    local orderedBuildIDs = {}
    for _, configID in ipairs(buildIDs or {}) do
        orderedBuildIDs[#orderedBuildIDs + 1] = configID
    end

    if STARTER_BUILD_CONFIG_ID and type(C_ClassTalents.GetHasStarterBuild) == "function" and C_ClassTalents.GetHasStarterBuild() then
        orderedBuildIDs[#orderedBuildIDs + 1] = STARTER_BUILD_CONFIG_ID
    end

    for _, configID in ipairs(orderedBuildIDs) do
        local label = nil
        if STARTER_BUILD_CONFIG_ID and configID == STARTER_BUILD_CONFIG_ID then
            label = _G.TALENT_FRAME_DROP_DOWN_STARTER_BUILD or "Starter Build"
        elseif C_Traits and type(C_Traits.GetConfigInfo) == "function" then
            local configInfo = C_Traits.GetConfigInfo(configID)
            label = configInfo and configInfo.name or nil
        end

        if label and label ~= "" then
            tinsert(menuList, {
                text = label,
                checked = function()
                    return activeConfigID == configID
                end,
                func = function()
                    SelectTalentLoadout(configID)
                end,
            })
        end
    end

    if #menuList == 1 then
        tinsert(menuList, {
            text = T.Tools.Text.Color(T.Tools.Colors.GRAY, "No loadouts available"),
            notCheckable = true,
            disabled = true,
        })
    end

    return menuList
end

local function BuildSpecMenuList()
    local menuList = {
        { text = _G.SPECIALIZATION or "Specialization", isTitle = true, notCheckable = true },
    }

    local currentSpec = GetCurrentSpecInfo()
    local numSpecs = type(GetNumSpecializations) == "function" and (GetNumSpecializations() or 0) or 0
    for specIndex = 1, numSpecs do
        local info = GetSpecInfoByIndex(specIndex)
        if info then
            local icon = info.icon and (IconText(info.icon, 14) .. " ") or ""
            tinsert(menuList, {
                text = icon .. info.name,
                checked = function()
                    return currentSpec and currentSpec.index == specIndex
                end,
                func = function()
                    local setSpec = (C_SpecializationInfo and C_SpecializationInfo.SetSpecialization) or
                        _G.SetSpecialization
                    if type(setSpec) == "function" then
                        setSpec(specIndex)
                    end
                end,
            })
        end
    end

    return menuList
end

local function BuildLootSpecMenuList()
    local currentSpec = GetCurrentSpecInfo()
    local menuList = {
        { text = _G.SELECT_LOOT_SPECIALIZATION or "Loot Specialization", isTitle = true, notCheckable = true },
        {
            text = currentSpec and format(_G.LOOT_SPECIALIZATION_DEFAULT or "Default (%s)", currentSpec.name) or
                "Default",
            checked = function()
                return type(GetLootSpecialization) == "function" and (GetLootSpecialization() or 0) == 0
            end,
            func = function()
                if type(SetLootSpecialization) == "function" then
                    SetLootSpecialization(0)
                end
            end,
        },
    }

    local numSpecs = type(GetNumSpecializations) == "function" and (GetNumSpecializations() or 0) or 0
    for specIndex = 1, numSpecs do
        local info = GetSpecInfoByIndex(specIndex)
        if info then
            local icon = info.icon and (IconText(info.icon, 14) .. " ") or ""
            tinsert(menuList, {
                text = icon .. info.name,
                checked = function()
                    return type(GetLootSpecialization) == "function" and (GetLootSpecialization() or 0) == info.id
                end,
                func = function()
                    if type(SetLootSpecialization) == "function" then
                        SetLootSpecialization(info.id)
                    end
                end,
            })
        end
    end

    return menuList
end

local function SetSpecializationPanelText(panel)
    SetPanelText(panel, BuildSpecializationText(), "specialization", 0.82, 0.9, 1, 1)
end


local function FormatMemoryUsage(value)
    local memory = tonumber(value) or 0
    if memory >= 1024 then
        if memory >= 10240 then
            return format("%.1f MB", memory / 1024)
        end
        return format("%.2f MB", memory / 1024)
    end

    return format("%.0f KB", memory)
end
local function GetTimeParts(useLocal, showSeconds)
    local hour, minute, second
    if useLocal then
        local now = date("*t")
        hour = now.hour
        minute = now.min
        second = now.sec
    else
        local gameHour, gameMinute = GetGameTime()
        hour = gameHour or 0
        minute = gameMinute or 0
        if showSeconds then
            second = tonumber(date("%S")) or 0
        else
            second = 0
        end
    end

    return hour or 0, minute or 0, second or 0
end

local function FormatClockText(useLocal, twentyFourHour, showSeconds, showAmPm)
    local hour, minute, second = GetTimeParts(useLocal, showSeconds)
    if twentyFourHour then
        if showSeconds then
            return format("%02d:%02d:%02d", hour, minute, second)
        end
        return format("%02d:%02d", hour, minute)
    end

    local suffix = hour >= 12 and "PM" or "AM"
    local displayHour = hour % 12
    if displayHour == 0 then
        displayHour = 12
    end

    local timeText
    if showSeconds then
        timeText = format("%d:%02d:%02d", displayHour, minute, second)
    else
        timeText = format("%d:%02d", displayHour, minute)
    end

    if showAmPm == false then
        return timeText
    end

    local amPmR, amPmG, amPmB, amPmA = GetInlineColorOverride("time", "customAmPmColor", "amPmColor")
    local suffixText = ColorizeText(suffix, amPmR, amPmG, amPmB, amPmA)
    return format("%s %s", timeText, suffixText)
end

local function ToResetText(secondsRemaining)
    if type(secondsRemaining) ~= "number" or secondsRemaining <= 0 or type(SecondsToTime) ~= "function" then
        return nil
    end

    return SecondsToTime(secondsRemaining, true, nil, 3)
end

local function SystemSettings()
    local db = GetDatatextDB("system")
    return {
        latencySource = db.latencySource == "HOME" and "HOME" or "WORLD",
        showLabels = db.showLabels ~= false,
        showLatencySource = db.showLatencySource ~= false,
    }
end

local function GetLatencyValues()
    local _, _, homePing, worldPing = GetNetStats()
    return homePing or 0, worldPing or 0
end

local function GetFpsValue()
    return floor((GetFramerate and GetFramerate() or 0) + 0.5)
end

local function GetStatusColor(value, kind)
    if kind == "fps" then
        if value >= 60 then return 0.25, 0.95, 0.48 end
        if value >= 30 then return 0.95, 0.84, 0.28 end
        return 0.96, 0.35, 0.35
    end

    if value <= 60 then return 0.25, 0.95, 0.48 end
    if value <= 120 then return 0.95, 0.84, 0.28 end
    return 0.96, 0.35, 0.35
end

local function SkinSystemButton(button, color)
    local UI = T.Tools and T.Tools.UI
    if UI and UI.SkinTwichButton then
        UI.SkinTwichButton(button, color)
    end
end

local function UpdateSystemCheckboxAppearance(checkButton)
    if not checkButton then
        return
    end

    local checked = checkButton:GetChecked() == true
    local hovered = checkButton:IsMouseOver()

    if checkButton.Background then
        if checked then
            checkButton.Background:SetColorTexture(0.98, 0.76, 0.22, hovered and 0.24 or 0.18)
        else
            checkButton.Background:SetColorTexture(0.1, 0.12, 0.16, hovered and 0.95 or 0.88)
        end
    end

    if checkButton.Border then
        if checked then
            checkButton.Border:SetColorTexture(0.98, 0.76, 0.22, hovered and 0.95 or 0.82)
        else
            checkButton.Border:SetColorTexture(0.28, 0.32, 0.4, hovered and 0.95 or 0.82)
        end
    end

    if checkButton.CheckMark then
        checkButton.CheckMark:SetShown(checked)
        checkButton.CheckMark:SetVertexColor(1, 0.95, 0.82, hovered and 1 or 0.92)
    end

    if checkButton.Glow then
        checkButton.Glow:SetShown(hovered or checked)
        checkButton.Glow:SetColorTexture(0.98, 0.76, 0.22, checked and 0.16 or 0.08)
    end
end

local function SkinSystemCheckbox(checkButton)
    if not checkButton or checkButton.__twichuiSystemStyled then
        return
    end

    local normalTexture = checkButton.GetNormalTexture and checkButton:GetNormalTexture() or nil
    local pushedTexture = checkButton.GetPushedTexture and checkButton:GetPushedTexture() or nil
    local highlightTexture = checkButton.GetHighlightTexture and checkButton:GetHighlightTexture() or nil
    local disabledTexture = checkButton.GetDisabledTexture and checkButton:GetDisabledTexture() or nil
    local checkedTexture = checkButton.GetCheckedTexture and checkButton:GetCheckedTexture() or nil

    for _, texture in ipairs({ normalTexture, pushedTexture, highlightTexture, disabledTexture, checkedTexture }) do
        if texture then
            texture:SetAlpha(0)
            if texture.Hide then
                texture:Hide()
            end
        end
    end

    checkButton.Background = checkButton:CreateTexture(nil, "BACKGROUND")
    checkButton.Background:SetPoint("TOPLEFT", checkButton, "TOPLEFT", 1, -1)
    checkButton.Background:SetPoint("BOTTOMRIGHT", checkButton, "BOTTOMRIGHT", -1, 1)

    checkButton.Border = checkButton:CreateTexture(nil, "BORDER")
    checkButton.Border:SetAllPoints(checkButton)

    checkButton.Glow = checkButton:CreateTexture(nil, "ARTWORK")
    checkButton.Glow:SetPoint("TOPLEFT", checkButton, "TOPLEFT", -2, 2)
    checkButton.Glow:SetPoint("BOTTOMRIGHT", checkButton, "BOTTOMRIGHT", 2, -2)
    checkButton.Glow:Hide()

    checkButton.CheckMark = checkButton:CreateTexture(nil, "OVERLAY")
    checkButton.CheckMark:SetPoint("CENTER", checkButton, "CENTER", 0, 0)
    checkButton.CheckMark:SetSize(10, 10)
    checkButton.CheckMark:SetTexture("Interface\\Buttons\\WHITE8X8")
    checkButton.CheckMark:SetTexCoord(0, 1, 0, 1)
    checkButton.CheckMark:Hide()

    checkButton:SetScript("OnEnter", function(self)
        UpdateSystemCheckboxAppearance(self)
    end)
    checkButton:SetScript("OnLeave", function(self)
        UpdateSystemCheckboxAppearance(self)
    end)
    checkButton:HookScript("OnClick", function(self)
        UpdateSystemCheckboxAppearance(self)
    end)
    checkButton:HookScript("OnMouseUp", function(self)
        UpdateSystemCheckboxAppearance(self)
    end)
    checkButton:HookScript("OnShow", function(self)
        UpdateSystemCheckboxAppearance(self)
    end)

    checkButton.__twichuiSystemStyled = true
    UpdateSystemCheckboxAppearance(checkButton)
end

local function SkinSystemScrollBar(scrollFrame)
    if not scrollFrame or scrollFrame.__twichuiSystemScrollStyled then
        return
    end

    local scrollBar = scrollFrame.ScrollBar
    if not scrollBar then
        return
    end

    for _, region in ipairs({ scrollBar:GetRegions() }) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            region:SetAlpha(0)
        end
    end

    local function styleScrollButton(button, glyph)
        if not button then
            return
        end

        SkinSystemButton(button, { 0.98, 0.76, 0.22 })
        button:SetSize(16, 16)
        if scrollBar.GetFrameLevel and button.SetFrameLevel then
            button:SetFrameLevel(scrollBar:GetFrameLevel() + 4)
        end
        button:Show()

        if not button.Glyph then
            button.Glyph = button:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            button.Glyph:SetPoint("CENTER", button, "CENTER", 0, 0)
        end

        button.Glyph:SetText(glyph)
        button.Glyph:SetTextColor(1, 0.95, 0.84)
    end

    scrollBar:ClearAllPoints()
    scrollBar:SetPoint("TOPRIGHT", scrollFrame, "TOPRIGHT", 16, -19)
    scrollBar:SetPoint("BOTTOMRIGHT", scrollFrame, "BOTTOMRIGHT", 16, 19)
    scrollBar:SetWidth(16)

    if scrollBar.ScrollUpButton then
        styleScrollButton(scrollBar.ScrollUpButton, "^")
        scrollBar.ScrollUpButton:ClearAllPoints()
        scrollBar.ScrollUpButton:SetPoint("BOTTOM", scrollBar, "TOP", 0, 4)
    end

    if scrollBar.ScrollDownButton then
        styleScrollButton(scrollBar.ScrollDownButton, "v")
        scrollBar.ScrollDownButton:ClearAllPoints()
        scrollBar.ScrollDownButton:SetPoint("TOP", scrollBar, "BOTTOM", 0, -4)
    end

    scrollBar.Track = scrollBar:CreateTexture(nil, "BACKGROUND")
    scrollBar.Track:SetPoint("TOPLEFT", scrollBar, "TOPLEFT", 3, -3)
    scrollBar.Track:SetPoint("BOTTOMRIGHT", scrollBar, "BOTTOMRIGHT", -3, 3)
    scrollBar.Track:SetColorTexture(0.08, 0.09, 0.12, 0.95)

    scrollBar.TrackBorder = scrollBar:CreateTexture(nil, "BORDER")
    scrollBar.TrackBorder:SetPoint("TOPLEFT", scrollBar.Track, "TOPLEFT", -1, 1)
    scrollBar.TrackBorder:SetPoint("BOTTOMRIGHT", scrollBar.Track, "BOTTOMRIGHT", 1, -1)
    scrollBar.TrackBorder:SetColorTexture(0.2, 0.22, 0.28, 0.9)

    local thumb = scrollBar.GetThumbTexture and scrollBar:GetThumbTexture() or nil
    if thumb then
        thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
        thumb:SetSize(6, 18)
        thumb:SetVertexColor(0.98, 0.76, 0.22, 0.82)
        if thumb.SetDrawLayer then
            thumb:SetDrawLayer("ARTWORK", 1)
        end

        scrollBar.ThumbGlow = scrollBar:CreateTexture(nil, "ARTWORK")
        scrollBar.ThumbGlow:SetPoint("TOPLEFT", thumb, "TOPLEFT", -1, 1)
        scrollBar.ThumbGlow:SetPoint("BOTTOMRIGHT", thumb, "BOTTOMRIGHT", 1, -1)
        scrollBar.ThumbGlow:SetColorTexture(0.98, 0.76, 0.22, 0.1)
        if scrollBar.ThumbGlow.SetDrawLayer then
            scrollBar.ThumbGlow:SetDrawLayer("ARTWORK", 0)
        end

        scrollBar:HookScript("OnEnter", function()
            thumb:SetVertexColor(1, 0.84, 0.34, 0.95)
            if scrollBar.ThumbGlow then
                scrollBar.ThumbGlow:SetColorTexture(0.98, 0.76, 0.22, 0.14)
            end
        end)
        scrollBar:HookScript("OnLeave", function()
            thumb:SetVertexColor(0.98, 0.76, 0.22, 0.82)
            if scrollBar.ThumbGlow then
                scrollBar.ThumbGlow:SetColorTexture(0.98, 0.76, 0.22, 0.1)
            end
        end)
    end

    scrollFrame.__twichuiSystemScrollStyled = true
end

local function SkinButton(button)
    SkinSystemButton(button, { 0.98, 0.76, 0.22 })
end

local function ApplySystemMemoryFrameSkin(frame)
    if not frame or frame.__twichuiSkinApplied then
        return
    end

    frame:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame:SetBackdropColor(0.05, 0.06, 0.08, 0.96)
    frame:SetBackdropBorderColor(0.24, 0.26, 0.32, 0.95)

    frame.BackgroundFill = frame:CreateTexture(nil, "BACKGROUND")
    frame.BackgroundFill:SetAllPoints(frame)
    frame.BackgroundFill:SetColorTexture(0.04, 0.05, 0.07, 0.94)

    frame.InnerGlow = frame:CreateTexture(nil, "BORDER")
    frame.InnerGlow:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.InnerGlow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -1, 1)
    frame.InnerGlow:SetColorTexture(0.98, 0.76, 0.22, 0.04)
    frame.__twichuiSkinApplied = true
end

local function CreateSystemMemoryFrame(name)
    local frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
    frame:SetSize(SYSTEM_MEMORY_FRAME_WIDTH, SYSTEM_MEMORY_FRAME_HEIGHT)
    frame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    frame:SetFrameStrata("MEDIUM")
    frame:SetFrameLevel(20)
    frame:SetClampedToScreen(true)
    frame:EnableMouse(true)
    frame:SetMovable(true)
    frame:Hide()

    ApplySystemMemoryFrameSkin(frame)

    frame.TitleBar = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.TitleBar:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    frame.TitleBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -1, -1)
    frame.TitleBar:SetHeight(32)
    frame.TitleBar:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 0, right = 0, top = 0, bottom = 0 },
    })
    frame.TitleBar:SetBackdropColor(0.09, 0.11, 0.15, 0.98)
    frame.TitleBar:SetBackdropBorderColor(0.98, 0.76, 0.22, 0.18)
    frame.TitleBar:EnableMouse(true)
    frame.TitleBar:RegisterForDrag("LeftButton")
    frame.TitleBar:SetScript("OnDragStart", function(bar)
        local parent = bar:GetParent()
        if parent and parent.StartMoving then
            parent:StartMoving()
        end
    end)
    frame.TitleBar:SetScript("OnDragStop", function(bar)
        local parent = bar:GetParent()
        if parent and parent.StopMovingOrSizing then
            parent:StopMovingOrSizing()
        end
    end)

    frame.Title = frame.TitleBar:CreateFontString(nil, "OVERLAY")
    frame.Title:SetPoint("LEFT", frame.TitleBar, "LEFT", 12, 0)
    frame.Title:SetFont(STANDARD_TEXT_FONT, 14, "OUTLINE")
    frame.Title:SetTextColor(1, 0.94, 0.82)
    frame.Title:SetText("Addon Memory Usage")

    frame.RefreshButton = CreateFrame("Button", nil, frame.TitleBar, "UIPanelButtonTemplate")
    frame.RefreshButton:SetSize(64, 20)
    frame.RefreshButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -34, 0)
    frame.RefreshButton:SetText("Refresh")
    SkinButton(frame.RefreshButton)

    frame.CollectButton = CreateFrame("Button", nil, frame.TitleBar, "UIPanelButtonTemplate")
    frame.CollectButton:SetSize(64, 20)
    frame.CollectButton:SetPoint("RIGHT", frame.RefreshButton, "LEFT", -8, 0)
    frame.CollectButton:SetText("Collect")
    SkinButton(frame.CollectButton)

    frame.LiveToggle = CreateFrame("CheckButton", nil, frame.TitleBar)
    frame.LiveToggle:SetSize(18, 18)
    frame.LiveToggle:SetPoint("RIGHT", frame.CollectButton, "LEFT", -24, 0)
    frame.LiveToggle:SetHitRectInsets(-4, -4, -4, -4)
    SkinSystemCheckbox(frame.LiveToggle)

    frame.LiveLabel = frame.TitleBar:CreateFontString(nil, "OVERLAY")
    frame.LiveLabel:SetPoint("RIGHT", frame.LiveToggle, "LEFT", -6, 0)
    frame.LiveLabel:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    frame.LiveLabel:SetTextColor(0.82, 0.85, 0.9)
    frame.LiveLabel:SetJustifyH("RIGHT")
    frame.LiveLabel:SetText("Live")

    frame.CloseButton = CreateFrame("Button", nil, frame.TitleBar, "UIPanelButtonTemplate")
    frame.CloseButton:SetSize(22, 20)
    frame.CloseButton:SetPoint("RIGHT", frame.TitleBar, "RIGHT", -8, 0)
    frame.CloseButton:SetText("x")
    SkinButton(frame.CloseButton)

    frame.ContentInset = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    frame.ContentInset:SetPoint("TOPLEFT", frame, "TOPLEFT", 10, -40)
    frame.ContentInset:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -10, 10)
    frame.ContentInset:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    frame.ContentInset:SetBackdropColor(0.07, 0.08, 0.11, 0.94)
    frame.ContentInset:SetBackdropBorderColor(0.18, 0.2, 0.26, 0.9)

    frame.SummaryText = frame.ContentInset:CreateFontString(nil, "OVERLAY")
    frame.SummaryText:SetPoint("TOPLEFT", frame.ContentInset, "TOPLEFT", 10, -10)
    frame.SummaryText:SetPoint("TOPRIGHT", frame.ContentInset, "TOPRIGHT", -10, -10)
    frame.SummaryText:SetJustifyH("LEFT")
    frame.SummaryText:SetFont(STANDARD_TEXT_FONT, 12, "OUTLINE")
    frame.SummaryText:SetTextColor(0.9, 0.92, 0.96)

    frame.HeaderRow = CreateFrame("Frame", nil, frame.ContentInset)
    frame.HeaderRow:SetPoint("TOPLEFT", frame.SummaryText, "BOTTOMLEFT", 0, -8)
    frame.HeaderRow:SetPoint("TOPRIGHT", frame.SummaryText, "BOTTOMRIGHT", 0, -8)
    frame.HeaderRow:SetHeight(18)

    frame.HeaderName = frame.HeaderRow:CreateFontString(nil, "OVERLAY")
    frame.HeaderName:SetPoint("LEFT", frame.HeaderRow, "LEFT", 0, 0)
    frame.HeaderName:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    frame.HeaderName:SetTextColor(0.68, 0.72, 0.8)
    frame.HeaderName:SetText("Addon")

    frame.HeaderValue = frame.HeaderRow:CreateFontString(nil, "OVERLAY")
    frame.HeaderValue:SetPoint("RIGHT", frame.HeaderRow, "RIGHT", -4, 0)
    frame.HeaderValue:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    frame.HeaderValue:SetTextColor(0.68, 0.72, 0.8)
    frame.HeaderValue:SetText("Memory")

    frame.ScrollFrame = CreateFrame("ScrollFrame", nil, frame.ContentInset, "UIPanelScrollFrameTemplate")
    frame.ScrollFrame:SetPoint("TOPLEFT", frame.HeaderRow, "BOTTOMLEFT", 0, -6)
    frame.ScrollFrame:SetPoint("BOTTOMRIGHT", frame.ContentInset, "BOTTOMRIGHT", -24, 8)
    SkinSystemScrollBar(frame.ScrollFrame)

    frame.ScrollChild = CreateFrame("Frame", nil, frame.ScrollFrame)
    frame.ScrollChild:SetSize(1, 1)
    frame.ScrollFrame:SetScrollChild(frame.ScrollChild)
    frame.ScrollFrame:HookScript("OnSizeChanged", function(scrollFrame)
        if scrollFrame and scrollFrame:GetWidth() and scrollFrame:GetWidth() > 0 then
            frame.ScrollChild:SetWidth(scrollFrame:GetWidth())
        end
    end)
    frame.__twichuiLiveElapsed = 0
    frame.__twichuiLiveEnabled = false
    frame.Rows = {}

    frame:SetScript("OnUpdate", function(memoryFrame, elapsed)
        if not memoryFrame.__twichuiLiveEnabled then
            return
        end

        memoryFrame.__twichuiLiveElapsed = (memoryFrame.__twichuiLiveElapsed or 0) + (elapsed or 0)
        if memoryFrame.__twichuiLiveElapsed < SYSTEM_MEMORY_LIVE_INTERVAL then
            return
        end

        memoryFrame.__twichuiLiveElapsed = 0
        if memoryFrame:IsShown() and memoryFrame.__twichuiOwner and memoryFrame.__twichuiOwner.RenderMemoryFrame then
            memoryFrame.__twichuiOwner:RenderMemoryFrame()
        end
    end)

    return frame
end

local function GetLoadedAddOnMemoryEntries()
    local entries = {}
    local totalMemory = 0
    local addOnCount = C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetNumAddOns() or 0

    if type(UpdateAddOnMemoryUsage) == "function" then
        UpdateAddOnMemoryUsage()
    end

    for index = 1, addOnCount do
        local isLoaded = C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded(index)
        if isLoaded then
            local name, title = C_AddOns.GetAddOnInfo(index)
            local memory = type(GetAddOnMemoryUsage) == "function" and (GetAddOnMemoryUsage(index) or 0) or 0
            totalMemory = totalMemory + memory
            tinsert(entries, {
                name = tostring((title and title ~= "") and title or name or ("AddOn " .. tostring(index))),
                addonName = tostring(name or title or ("AddOn " .. tostring(index))),
                memory = memory,
            })
        end
    end

    sort(entries, function(left, right)
        if left.memory == right.memory then
            return left.name < right.name
        end
        return left.memory > right.memory
    end)

    return entries, totalMemory
end

local function GetSystemRow(frame, index)
    local row = frame.Rows[index]
    if row then
        return row
    end

    row = CreateFrame("Frame", nil, frame.ScrollChild)
    row:SetHeight(SYSTEM_MEMORY_ROW_HEIGHT)
    row:EnableMouse(true)

    row.Background = row:CreateTexture(nil, "BACKGROUND")
    row.Background:SetAllPoints(row)

    row.Highlight = row:CreateTexture(nil, "BORDER")
    row.Highlight:SetAllPoints(row)
    row.Highlight:SetColorTexture(0.98, 0.76, 0.22, 0.12)
    row.Highlight:Hide()

    row.Name = row:CreateFontString(nil, "OVERLAY")
    row.Name:SetPoint("LEFT", row, "LEFT", 8, 0)
    row.Name:SetPoint("RIGHT", row, "RIGHT", -120, 0)
    row.Name:SetJustifyH("LEFT")
    row.Name:SetFont(STANDARD_TEXT_FONT, 11, "")

    row.Value = row:CreateFontString(nil, "OVERLAY")
    row.Value:SetPoint("RIGHT", row, "RIGHT", -8, 0)
    row.Value:SetJustifyH("RIGHT")
    row.Value:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")

    row:SetScript("OnEnter", function(self)
        if self.Highlight then
            self.Highlight:Show()
        end
        if self.Name then
            self.Name:SetTextColor(1, 0.97, 0.88)
        end
    end)
    row:SetScript("OnLeave", function(self)
        if self.Highlight then
            self.Highlight:Hide()
        end
        if self.Name then
            self.Name:SetTextColor(0.9, 0.92, 0.96)
        end
    end)

    frame.Rows[index] = row
    return row
end

local function SetSystemPanelText(panel)
    local settings = SystemSettings()
    local fps = GetFpsValue()
    local homePing, worldPing = GetLatencyValues()
    local latency = settings.latencySource == "HOME" and homePing or worldPing
    local fpsR, fpsG, fpsB = GetStatusColor(fps, "fps")
    local pingR, pingG, pingB = GetStatusColor(latency, "ping")

    local text
    if settings.showLabels then
        local sourceText = settings.showLatencySource and
            T.Tools.Text.Color(T.Tools.Colors.GRAY, settings.latencySource == "HOME" and "Home" or "World") or
            nil

        text = format(sourceText and "%s %s  %s %s" or "%s %s  %s",
            T.Tools.Text.ColorRGB(fpsR, fpsG, fpsB, format("%d FPS", fps)),
            T.Tools.Text.Color(T.Tools.Colors.GRAY, "•"),
            T.Tools.Text.ColorRGB(pingR, pingG, pingB, format("%d ms", latency)),
            sourceText)
    else
        text = format("%s %s %s",
            T.Tools.Text.ColorRGB(fpsR, fpsG, fpsB, tostring(fps)),
            T.Tools.Text.Color(T.Tools.Colors.GRAY, "•"),
            T.Tools.Text.ColorRGB(pingR, pingG, pingB, tostring(latency)))
    end

    SetPanelText(panel, text, "system")
end

local function MailSettings()
    local db = GetDatatextDB("mail")
    return {
        iconOnly = db.iconOnly == true,
    }
end

local function SetMailPanelText(panel)
    -- C_Mail.HasNewMail is available in newer WoW builds; fall back to global HasNewMail
    local hasMail = (C_Mail and C_Mail.HasNewMail and C_Mail.HasNewMail())
        or (HasNewMail and HasNewMail())
        or false
    local settings = MailSettings()
    local label
    if settings.iconOnly then
        label = hasMail and T.Tools.Text.Color(T.Tools.Colors.WARNING, "Mail") or
            T.Tools.Text.Color(T.Tools.Colors.GRAY, "Mail")
    else
        label = hasMail and "New Mail" or "Mail"
    end

    if hasMail then
        SetPanelText(panel, label, "mail", 1, 0.84, 0.28, 1)
    else
        SetPanelText(panel, label, "mail", 0.75, 0.78, 0.84, 1)
    end
end

local function GetOnlineFriendSummary()
    local wowOnline = 0
    local wowTotal = 0
    if C_FriendList and type(C_FriendList.GetNumFriends) == "function" then
        wowTotal = C_FriendList.GetNumFriends() or 0
    elseif type(_G.GetNumFriends) == "function" then
        wowTotal = _G.GetNumFriends() or 0
    end

    -- Count online WoW friends by iterating individual friend entries so the
    -- result stays consistent with the CollectWowFriends() path used by the
    -- tooltip.  GetNumOnlineFriends() can return a stale or zeroed value while
    -- the per-entry connected flag is always current.
    if C_FriendList and type(C_FriendList.GetFriendInfoByIndex) == "function" then
        for i = 1, wowTotal do
            local info = C_FriendList.GetFriendInfoByIndex(i)
            if info and info.connected then
                wowOnline = wowOnline + 1
            end
        end
    elseif C_FriendList and type(C_FriendList.GetNumOnlineFriends) == "function" then
        wowOnline = C_FriendList.GetNumOnlineFriends() or 0
    else
        wowOnline = wowTotal
    end

    local bnetTotal, bnetOnline = 0, 0
    if type(_G.BNGetNumFriends) == "function" then
        bnetTotal, bnetOnline = _G.BNGetNumFriends()
        bnetTotal = bnetTotal or 0
        bnetOnline = bnetOnline or 0
    end

    return wowOnline, wowTotal, bnetOnline, bnetTotal
end

local function RefreshFriendsDatatext()
    if DataTextModule and type(DataTextModule.RefreshDataText) == "function" then
        DataTextModule:RefreshDataText("TwichUI: Friends")
    end
end

local function RequestUpdatedWowFriends(scheduleRefresh)
    if not (C_FriendList and type(C_FriendList.ShowFriends) == "function") then
        return false
    end

    local now = type(GetTime) == "function" and GetTime() or 0
    if now > 0 and lastFriendsRefreshRequestAt > 0 and (now - lastFriendsRefreshRequestAt) < FRIENDS_REFRESH_REQUEST_INTERVAL then
        return false
    end

    lastFriendsRefreshRequestAt = now
    C_FriendList.ShowFriends()

    if scheduleRefresh and C_Timer and type(C_Timer.After) == "function" then
        friendsRequestRefreshToken = friendsRequestRefreshToken + 1
        local refreshToken = friendsRequestRefreshToken
        local function refreshIfCurrent()
            if friendsRequestRefreshToken == refreshToken then
                RefreshFriendsDatatext()
            end
        end

        C_Timer.After(1, refreshIfCurrent)
        C_Timer.After(3, refreshIfCurrent)
    end

    return true
end

local function SetFriendsPanelText(panel)
    local wowOnline, _, bnetOnline = GetOnlineFriendSummary()
    local friendsDB = GetDatatextDB("friends")
    local countWoWOnly = friendsDB.countWoWOnly == true
    local totalOnline = wowOnline + (countWoWOnly and 0 or bnetOnline)
    local text = totalOnline > 0 and format("Friends %d", totalOnline) or "Friends"
    if totalOnline > 0 then
        SetPanelText(panel, text, "friends", 0.4, 0.86, 0.52, 1)
    else
        SetPanelText(panel, text, "friends", 0.75, 0.78, 0.84, 1)
    end
end

local function CollectWowFriends()
    local collected = {}
    if not (C_FriendList and type(C_FriendList.GetNumFriends) == "function" and type(C_FriendList.GetFriendInfoByIndex) == "function") then
        return collected
    end

    local numFriends = C_FriendList.GetNumFriends() or 0
    for index = 1, numFriends do
        local info = C_FriendList.GetFriendInfoByIndex(index)
        if info and info.connected then
            collected[#collected + 1] = {
                name = info.name,
                level = info.level,
                zone = info.area,
                className = info.className,
                afk = info.afk == true,
                dnd = info.dnd == true,
            }
        end
    end

    sort(collected, function(left, right)
        return tostring(left.name or "") < tostring(right.name or "")
    end)

    return collected
end

local function CollectBNetFriends()
    local collected = {}
    if not (C_BattleNet and type(C_BattleNet.GetFriendAccountInfo) == "function" and type(_G.BNGetNumFriends) == "function") then
        return collected
    end

    local total = _G.BNGetNumFriends() or 0
    for index = 1, total do
        local accountInfo = C_BattleNet.GetFriendAccountInfo(index)
        if accountInfo and accountInfo.gameAccountInfo and accountInfo.gameAccountInfo.isOnline then
            local gameInfo = accountInfo.gameAccountInfo
            collected[#collected + 1] = {
                accountName = accountInfo.accountName,
                battleTag = accountInfo.battleTag,
                characterName = gameInfo.characterName,
                clientProgram = gameInfo.clientProgram,
                className = gameInfo.className,
                areaName = gameInfo.areaName,
                richPresence = accountInfo.richPresence,
                afk = accountInfo.isAFK == true,
                dnd = accountInfo.isDND == true,
            }
        end
    end

    sort(collected, function(left, right)
        return tostring(left.accountName or left.battleTag or "") < tostring(right.accountName or right.battleTag or "")
    end)

    return collected
end

local function GetDurabilityState()
    local lowestPercent = 100
    local rows = {}
    local getInventoryItemDurability = _G.GetInventoryItemDurability

    for _, slot in ipairs(DURABILITY_SLOTS) do
        local currentDura, maxDura = nil, nil
        if type(getInventoryItemDurability) == "function" then
            currentDura, maxDura = getInventoryItemDurability(slot.id)
        end
        if currentDura and maxDura and maxDura > 0 then
            local percent = (currentDura / maxDura) * 100
            if percent < lowestPercent then
                lowestPercent = percent
            end

            rows[#rows + 1] = {
                slotLabel = slot.label,
                percent = percent,
                texture = _G.GetInventoryItemTexture and _G.GetInventoryItemTexture("player", slot.id) or nil,
            }
        end
    end

    if #rows == 0 then
        lowestPercent = 100
    end

    sort(rows, function(left, right)
        return left.percent < right.percent
    end)

    return lowestPercent, rows
end

local function SetDurabilityPanelText(panel)
    if not (panel and panel.text) then
        return
    end

    local percent = select(1, GetDurabilityState())
    local r, g, b
    local overrideR, overrideG, overrideB, overrideA = GetColorOverride("durability")
    if overrideR then
        r, g, b = overrideR, overrideG, overrideB
    else
        r, g, b = GetStatusColor(100 - percent, "ping")
    end

    local previousText = panel.text:GetText()
    local percentText = ColorizeText(FormatPercent(percent), r, g, b, overrideA or 1)
    panel.text:SetText(format("Durability %s", percentText))
    panel.text:SetTextColor(1, 1, 1, 1)
    DataTextModule:MaybeFlashPanel(panel, "durability", previousText, panel.text:GetText() or "")
end

local function GetCurrencyDB()
    local db = GetDatatextDB("currencies")
    if type(db.tooltipCurrencyIDs) ~= "table" then
        db.tooltipCurrencyIDs = {}
    end
    if type(db.customDatatexts) ~= "table" then
        db.customDatatexts = {}
    end
    if type(db.displayStyle) ~= "string" or db.displayStyle == "" then
        db.displayStyle = "ICON_TEXT_ABBR"
    end
    if type(db.displayedCurrency) ~= "string" or db.displayedCurrency == "" then
        db.displayedCurrency = "GOLD"
    end
    if db.showMax == nil then
        db.showMax = true
    end
    if db.showGoldInTooltip == nil then
        db.showGoldInTooltip = true
    end
    return db
end

local function GetCurrencyInfoByID(currencyID)
    if not (C_CurrencyInfo and type(C_CurrencyInfo.GetCurrencyInfo) == "function") then
        return nil
    end

    local info = C_CurrencyInfo.GetCurrencyInfo(currencyID)
    if type(info) ~= "table" or not info.name then
        return nil
    end

    return info
end

local function GetCurrencyMovingCapProgress(info)
    if type(info) ~= "table" then
        return nil, nil
    end

    if info.useTotalEarnedForMaxQty ~= true then
        return nil, nil
    end

    local maxQuantity = tonumber(info.maxQuantity)
    local totalEarned = tonumber(info.totalEarned)
    if not maxQuantity or maxQuantity <= 0 or totalEarned == nil or totalEarned < 0 then
        return nil, nil
    end

    return totalEarned, maxQuantity
end

local function IsCurrencyAtWeeklyCap(info)
    if type(info) ~= "table" then
        return false
    end

    local weeklyMax = tonumber(info.maxWeeklyQuantity)
    if not weeklyMax or weeklyMax <= 0 then
        return false
    end

    local earnedThisWeek = tonumber(info.quantityEarnedThisWeek)
    if not earnedThisWeek then
        earnedThisWeek = tonumber(info.totalEarned)
    end

    return type(earnedThisWeek) == "number" and earnedThisWeek >= weeklyMax
end

local function IsCurrencyAtCollectionCap(info)
    if IsCurrencyAtWeeklyCap(info) then
        return true
    end

    local earnedQuantity, maxQuantity = GetCurrencyMovingCapProgress(info)
    return type(earnedQuantity) == "number" and type(maxQuantity) == "number" and earnedQuantity >= maxQuantity
end

local function BuildCurrencyQuantityText(info, colorAtCap)
    local quantityText = BreakUpLargeNumbers and BreakUpLargeNumbers(info.quantity or 0) or tostring(info.quantity or 0)
    if colorAtCap and IsCurrencyAtCollectionCap(info) then
        return T.Tools.Text.Color(T.Tools.Colors.RED, quantityText)
    end

    return quantityText
end

local function BuildCurrencyMaxSuffix(info)
    if type(info) ~= "table" then
        return ""
    end

    local earnedQuantity, maxQuantity = GetCurrencyMovingCapProgress(info)
    if type(earnedQuantity) == "number" and type(maxQuantity) == "number" then
        local earnedText = BreakUpLargeNumbers and BreakUpLargeNumbers(earnedQuantity) or tostring(earnedQuantity)
        local maxText = BreakUpLargeNumbers and BreakUpLargeNumbers(maxQuantity) or tostring(maxQuantity)
        local spendableQuantity = tonumber(info.quantity) or 0
        if spendableQuantity ~= earnedQuantity then
            return T.Tools.Text.Color(T.Tools.Colors.GRAY, format(" (%s/%s)", earnedText, maxText))
        end

        return T.Tools.Text.Color(T.Tools.Colors.GRAY, format(" / %s", maxText))
    end

    if type(info.maxQuantity) == "number" and info.maxQuantity > 0 then
        return T.Tools.Text.Color(T.Tools.Colors.GRAY,
            format(" / %s",
                BreakUpLargeNumbers and BreakUpLargeNumbers(info.maxQuantity) or tostring(info.maxQuantity)))
    end

    return ""
end

local function CurrencyDisplayText(currencyID, style, showMax)
    local info = GetCurrencyInfoByID(currencyID)
    if not info then
        return nil
    end

    local icon = info.iconFileID and T.Tools.Text.Icon(tostring(info.iconFileID)) or ""
    local quantity = BuildCurrencyQuantityText(info, true)
    local name = tostring(info.name or "Currency")
    local text

    if style == "ICON" then
        text = format("%s %s", icon, quantity)
    elseif style == "ICON_TEXT" then
        text = format("%s %s %s", icon, name, quantity)
    else
        text = format("%s %s %s", icon, AbbreviateName(name, 12), quantity)
    end

    if showMax then
        text = text .. BuildCurrencyMaxSuffix(info)
    end

    return text, info
end

local CurrencyDT = DataTextModule:NewModule("CurrencyDataText")

function CurrencyDT:GetCustomDefinitionName(currencyID)
    return format("TwichUI: Currency: %d", tonumber(currencyID) or 0)
end

function CurrencyDT:GetCustomDefinitionPrettyName(currencyID)
    local info = GetCurrencyInfoByID(currencyID)
    local name = info and info.name or format("Currency %d", tonumber(currencyID) or 0)
    return format("Currency: %s", name)
end

function CurrencyDT:SyncCustomDatatexts()
    local db = GetCurrencyDB()
    self.customCurrencyDefinitions = self.customCurrencyDefinitions or {}

    local keep = {}
    for currencyID in pairs(db.customDatatexts) do
        local numericCurrencyID = tonumber(currencyID)
        local definitionName = self:GetCustomDefinitionName(numericCurrencyID)
        keep[definitionName] = true

        if not self.customCurrencyDefinitions[definitionName] then
            local definition = {
                name = definitionName,
                prettyName = self:GetCustomDefinitionPrettyName(numericCurrencyID),
                events = {
                    "CHAT_MSG_CURRENCY",
                    "CURRENCY_DISPLAY_UPDATE",
                    "PERKS_PROGRAM_CURRENCY_REFRESH",
                    "PLAYER_ENTERING_WORLD",
                },
                onEventFunc = function(panel)
                    local settings = GetCurrencyDB().customDatatexts[numericCurrencyID]
                    local info = GetCurrencyInfoByID(numericCurrencyID)
                    if not settings or not info then
                        SetPanelText(panel, "Currency", "currencies")
                        return
                    end

                    local icon = settings.showIcon ~= false and info.iconFileID and
                        (T.Tools.Text.Icon(tostring(info.iconFileID)) .. " ") or ""
                    local quantity = BuildCurrencyQuantityText(info, true)
                    local nameStyle = settings.nameStyle or "abbr"
                    local text
                    if nameStyle == "none" then
                        text = quantity
                    else
                        local displayName = nameStyle == "full" and info.name or AbbreviateName(info.name, 12)
                        text = format("%s%s %s", icon, displayName, quantity)
                    end

                    if settings.showMax ~= false then
                        text = text .. BuildCurrencyMaxSuffix(info)
                    end

                    SetPanelText(panel, text, "currencies")
                end,
                onClickFunc = function()
                    if type(ToggleCharacter) == "function" then
                        ToggleCharacter("TokenFrame")
                    end
                end,
                onEnterFunc = function(panel)
                    local tooltip = DataTextModule:GetElvUITooltip()
                    if not tooltip then
                        return
                    end

                    tooltip:ClearLines()
                    if tooltip.SetCurrencyByID then
                        tooltip:SetCurrencyByID(numericCurrencyID)
                    else
                        local info = GetCurrencyInfoByID(numericCurrencyID)
                        tooltip:AddLine(info and info.name or format("Currency %d", numericCurrencyID))
                    end
                    DataTextModule:ShowDatatextTooltip(tooltip)
                end,
                onLeaveFunc = function()
                    local tooltip = DataTextModule:GetActiveDatatextTooltip()
                    if tooltip and tooltip.Hide then
                        DataTextModule:HideDatatextTooltip(tooltip)
                    end
                end,
                module = self,
            }

            self.customCurrencyDefinitions[definitionName] = definition
            DataTextModule:RegisterDefinition(definition)
        else
            local definition = self.customCurrencyDefinitions[definitionName]
            definition.prettyName = self:GetCustomDefinitionPrettyName(numericCurrencyID)
        end
    end

    for definitionName in pairs(self.customCurrencyDefinitions) do
        if not keep[definitionName] then
            self.customCurrencyDefinitions[definitionName] = nil
            DataTextModule:RemoveDatatext(definitionName)
        end
    end
end

function CurrencyDT:OnEvent(panel)
    local db = GetCurrencyDB()
    local displayed = db.displayedCurrency or "GOLD"

    if displayed == "GOLD" then
        SetPanelText(panel, T.Tools.Text.FormatCopperShort(_G.GetMoney and _G.GetMoney() or 0), "currencies")
        return
    end

    local currencyID = tonumber(displayed)
    local text = currencyID and CurrencyDisplayText(currencyID, db.displayStyle, db.showMax)
    if text then
        SetPanelText(panel, text, "currencies")
    else
        SetPanelText(panel, T.Tools.Text.FormatCopperShort(_G.GetMoney and _G.GetMoney() or 0), "currencies")
    end
end

function CurrencyDT:OnClick()
    if type(ToggleCharacter) == "function" then
        ToggleCharacter("TokenFrame")
    end
end

function CurrencyDT:OnEnter()
    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    local db = GetCurrencyDB()
    local shownCurrencyIDs = {}
    tooltip:ClearLines()
    tooltip:AddLine("Currencies")

    for _, currencyID in ipairs(db.tooltipCurrencyIDs) do
        local info = GetCurrencyInfoByID(currencyID)
        if info then
            shownCurrencyIDs[currencyID] = true
            local icon = info.iconFileID and T.Tools.Text.Icon(tostring(info.iconFileID)) or ""
            local rightText = BuildCurrencyQuantityText(info, true)
            if db.showMax then
                rightText = rightText .. BuildCurrencyMaxSuffix(info)
            end
            tooltip:AddDoubleLine(format("%s %s", icon, info.name), rightText, 1, 1, 1, 1, 1, 1)
        end
    end

    for currencyID, settings in pairs(db.customDatatexts) do
        local numericCurrencyID = tonumber(currencyID)
        if settings and settings.includeInTooltip == true and numericCurrencyID and not shownCurrencyIDs[numericCurrencyID] then
            local info = GetCurrencyInfoByID(numericCurrencyID)
            if info then
                local icon = info.iconFileID and T.Tools.Text.Icon(tostring(info.iconFileID)) or ""
                local rightText = BuildCurrencyQuantityText(info, true)
                if settings.showMax ~= false then
                    rightText = rightText .. BuildCurrencyMaxSuffix(info)
                end
                tooltip:AddDoubleLine(format("%s %s", icon, info.name), rightText, 1, 1, 1, 1, 1, 1)
            end
        end
    end

    if #db.tooltipCurrencyIDs > 0 or next(db.customDatatexts) ~= nil then
        tooltip:AddLine(" ")
    end

    if db.showGoldInTooltip ~= false then
        tooltip:AddDoubleLine("Gold", T.Tools.Text.FormatCopper(_G.GetMoney and _G.GetMoney() or 0), 1, 1, 1, 1, 1, 1)
    end
    AddTooltipHintLine(tooltip, "Click: Open currencies")
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function CurrencyDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function CurrencyDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Currencies",
        prettyName = "Currencies",
        events = {
            "PLAYER_MONEY",
            "SEND_MAIL_MONEY_CHANGED",
            "SEND_MAIL_COD_CHANGED",
            "PLAYER_TRADE_MONEY",
            "TRADE_MONEY_CHANGED",
            "CHAT_MSG_CURRENCY",
            "CURRENCY_DISPLAY_UPDATE",
            "PERKS_PROGRAM_CURRENCY_REFRESH",
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
    self:SyncCustomDatatexts()
end

---@class TimeDataText : AceModule
local TimeDT = DataTextModule:NewModule("TimeDataText")

function TimeDT:OnEvent()
    if self.panel then
        self:OnUpdate(self.panel, UPDATE_SLOW)
    end
end

function TimeDT:OnUpdate(panel, elapsed)
    panel.__twichuiTimeUpdate = (panel.__twichuiTimeUpdate or 0) + elapsed
    local settings = TimeSettings()
    local interval = settings.showSeconds and UPDATE_FAST or UPDATE_SLOW
    if panel.__twichuiTimeUpdate < interval then
        return
    end
    panel.__twichuiTimeUpdate = 0
    SetPanelText(panel,
        FormatClockText(settings.localTime, settings.twentyFourHour, settings.showSeconds, settings.showAmPm), "time")
end

function TimeDT:OnClick(_, button)
    if button == "RightButton" and _G.TimeManagerFrame then
        _G.TimeManagerFrame:Show()
        return
    end

    if type(ToggleCalendar) == "function" then
        ToggleCalendar()
    elseif _G.GameTimeFrame and _G.GameTimeFrame.Click then
        _G.GameTimeFrame:Click()
    end
end

function TimeDT:OnEnter()
    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    local settings = TimeSettings()
    tooltip:ClearLines()
    tooltip:AddLine("Time")
    tooltip:AddDoubleLine(settings.localTime and TIMEMANAGER_TOOLTIP_LOCALTIME or TIMEMANAGER_TOOLTIP_REALMTIME,
        FormatClockText(settings.localTime, settings.twentyFourHour, true, settings.showAmPm), 1, 1, 1, 1, 1, 1)
    tooltip:AddDoubleLine(settings.localTime and TIMEMANAGER_TOOLTIP_REALMTIME or TIMEMANAGER_TOOLTIP_LOCALTIME,
        FormatClockText(not settings.localTime, settings.twentyFourHour, true, settings.showAmPm), 0.75, 0.78, 0.84, 1, 1,
        1)

    if settings.showDailyReset and C_DateAndTime and type(C_DateAndTime.GetSecondsUntilDailyReset) == "function" then
        local resetText = ToResetText(C_DateAndTime.GetSecondsUntilDailyReset())
        if resetText then
            tooltip:AddLine(" ")
            tooltip:AddDoubleLine("Daily Reset", resetText, 1, 1, 1, 1, 1, 1)
        end
    end

    if settings.showWeeklyReset and C_DateAndTime and type(C_DateAndTime.GetSecondsUntilWeeklyReset) == "function" then
        local resetText = ToResetText(C_DateAndTime.GetSecondsUntilWeeklyReset())
        if resetText then
            tooltip:AddDoubleLine("Weekly Reset", resetText, 1, 1, 1, 1, 1, 1)
        end
    end

    tooltip:AddLine(" ")
    AddTooltipHintLine(tooltip, "Click: Open calendar")
    AddTooltipHintLine(tooltip, "Right-click: Open time manager")
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function TimeDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function TimeDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Time",
        prettyName = "Time",
        events = {
            "PLAYER_ENTERING_WORLD",
            "LOADING_SCREEN_ENABLED",
            "UPDATE_INSTANCE_INFO",
            "BOSS_KILL",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = DataTextModule:CreateBoundCallback(self, "OnUpdate"),
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end

---@class SpecializationDataText : AceModule
local SpecializationDT = DataTextModule:NewModule("SpecializationDataText")

function SpecializationDT:OnEvent(panel)
    SetSpecializationPanelText(panel)
end

function SpecializationDT:OnClick(panel, button)
    if button == "RightButton" then
        DataTextModule:ShowMenu(panel, BuildLootSpecMenuList())
        return
    end

    if type(IsControlKeyDown) == "function" and IsControlKeyDown() then
        DataTextModule:ShowMenu(panel, BuildLoadoutMenuList())
        return
    end

    if type(IsShiftKeyDown) == "function" and IsShiftKeyDown() then
        OpenTalentsFrame()
        return
    end

    DataTextModule:ShowMenu(panel, BuildSpecMenuList())
end

function SpecializationDT:OnEnter()
    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    local currentSpec = GetCurrentSpecInfo()
    local lootSpec, isDefaultLoot = GetLootSpecInfo(currentSpec)
    local loadoutName = GetActiveLoadoutName(currentSpec)
    local numSpecs = type(GetNumSpecializations) == "function" and (GetNumSpecializations() or 0) or 0

    tooltip:ClearLines()
    tooltip:AddLine("Specialization")

    if currentSpec then
        tooltip:AddLine(" ")
        for specIndex = 1, numSpecs do
            local info = GetSpecInfoByIndex(specIndex)
            if info then
                local marker = (currentSpec.index == specIndex) and
                    T.Tools.Text.ColorRGB(0.4, 0.86, 0.52, "Active") or
                    T.Tools.Text.Color(T.Tools.Colors.GRAY, "Inactive")
                tooltip:AddDoubleLine((info.icon and (IconText(info.icon, 14) .. " ") or "") .. info.name, marker, 1, 1,
                    1, 1,
                    1, 1)
            end
        end

        tooltip:AddLine(" ")
        tooltip:AddDoubleLine("Talent Spec", currentSpec.name, 1, 1, 1, 1, 1, 1)
        tooltip:AddDoubleLine("Loot Spec",
            isDefaultLoot and format(_G.LOOT_SPECIALIZATION_DEFAULT or "Default (%s)", currentSpec.name) or
            (lootSpec and lootSpec.name or "Unknown"), 1, 1, 1, 1, 1, 1)
        if type(loadoutName) == "string" and loadoutName ~= "" then
            tooltip:AddDoubleLine("Loadout", loadoutName, 1, 1, 1, 1, 1, 1)
        end
    else
        tooltip:AddLine(" ")
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Specialization data is not available right now."))
    end

    tooltip:AddLine(" ")
    AddTooltipHintLine(tooltip, "Click: Change specialization")
    AddTooltipHintLine(tooltip, "Control-click: Change loadout")
    AddTooltipHintLine(tooltip, "Shift-click: Open talents")
    AddTooltipHintLine(tooltip, "Right-click: Change loot specialization")
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function SpecializationDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function SpecializationDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Specialization",
        prettyName = "Specialization",
        events = {
            "ACTIVE_TALENT_GROUP_CHANGED",
            "CHARACTER_POINTS_CHANGED",
            "PLAYER_ENTERING_WORLD",
            "PLAYER_LOOT_SPEC_UPDATED",
            "PLAYER_SPECIALIZATION_CHANGED",
            "PLAYER_TALENT_UPDATE",
            "TRAIT_CONFIG_CREATED",
            "TRAIT_CONFIG_DELETED",
            "TRAIT_CONFIG_LIST_UPDATED",
            "TRAIT_CONFIG_UPDATED",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end

---@class SystemDataText : AceModule
local SystemDT = DataTextModule:NewModule("SystemDataText")

function SystemDT:GetMemoryFrame()
    if not self.memoryFrame then
        self.memoryFrame = CreateSystemMemoryFrame("TwichUISystemMemoryFrame")
        self.memoryFrame.__twichuiOwner = self
        self.memoryFrame.CloseButton:SetScript("OnClick", function()
            self:HideMemoryFrame()
        end)
        self.memoryFrame.RefreshButton:SetScript("OnClick", function()
            self:RenderMemoryFrame()
        end)
        self.memoryFrame.CollectButton:SetScript("OnClick", function()
            self:CollectGarbage()
        end)
        self.memoryFrame.LiveToggle:SetScript("OnClick", function(button)
            local checked = button:GetChecked() == true
            self:SetMemoryFrameLive(checked)
            UpdateSystemCheckboxAppearance(button)
        end)
    end

    return self.memoryFrame
end

function SystemDT:SetMemoryFrameLive(enabled)
    local frame = self:GetMemoryFrame()
    if not frame then
        return
    end

    frame.__twichuiLiveEnabled = enabled == true
    frame.__twichuiLiveElapsed = 0
    if frame.LiveToggle and frame.LiveToggle:GetChecked() ~= frame.__twichuiLiveEnabled then
        frame.LiveToggle:SetChecked(frame.__twichuiLiveEnabled)
    end
    if frame.LiveToggle then
        UpdateSystemCheckboxAppearance(frame.LiveToggle)
    end
end

function SystemDT:CollectGarbage()
    if type(collectgarbage) == "function" then
        collectgarbage("collect")
    end

    self:RenderMemoryFrame()
end

function SystemDT:RenderMemoryFrame()
    local frame = self:GetMemoryFrame()
    if not frame then
        return
    end

    local scrollWidth = frame.ScrollFrame and frame.ScrollFrame.GetWidth and frame.ScrollFrame:GetWidth() or 1
    frame.ScrollChild:SetWidth(math.max(1, scrollWidth))

    local entries, totalMemory = GetLoadedAddOnMemoryEntries()
    frame.SummaryText:SetText(format("Loaded AddOns: %d  %s  Total: %s",
        #entries,
        T.Tools.Text.Color(T.Tools.Colors.GRAY, "•"),
        FormatMemoryUsage(totalMemory)))

    local contentHeight = 0
    for index, entry in ipairs(entries) do
        local row = GetSystemRow(frame, index)
        row:ClearAllPoints()
        row:SetPoint("TOPLEFT", frame.ScrollChild, "TOPLEFT", 0, -contentHeight)
        row:SetPoint("TOPRIGHT", frame.ScrollChild, "TOPRIGHT", 0, -contentHeight)
        row.Background:SetColorTexture(1, 1, 1, index % 2 == 0 and 0.02 or 0.05)
        row.Name:SetText(entry.name)
        row.Name:SetTextColor(0.9, 0.92, 0.96)
        row.Value:SetText(FormatMemoryUsage(entry.memory))
        local valueR, valueG, valueB = GetStatusColor(entry.memory / 1024, "ping")
        row.Value:SetTextColor(valueR, valueG, valueB)
        row:Show()
        contentHeight = contentHeight + SYSTEM_MEMORY_ROW_HEIGHT
    end

    for index = #entries + 1, #frame.Rows do
        frame.Rows[index]:Hide()
    end

    frame.ScrollChild:SetHeight(math.max(frame.ScrollFrame:GetHeight() or 1, contentHeight + 2))
end

function SystemDT:ShowMemoryFrame()
    local frame = self:GetMemoryFrame()
    if not frame then
        return
    end

    self:RenderMemoryFrame()
    frame.__twichuiLiveElapsed = 0
    frame:Show()
end

function SystemDT:HideMemoryFrame()
    if self.memoryFrame then
        self.memoryFrame:Hide()
    end
end

function SystemDT:ToggleMemoryFrame()
    local frame = self:GetMemoryFrame()
    if frame and frame:IsShown() then
        self:HideMemoryFrame()
    else
        self:ShowMemoryFrame()
    end
end

function SystemDT:OnUpdate(panel, elapsed)
    panel.__twichuiSystemUpdate = (panel.__twichuiSystemUpdate or 0) + elapsed
    if panel.__twichuiSystemUpdate < UPDATE_FAST then
        return
    end
    panel.__twichuiSystemUpdate = 0
    SetSystemPanelText(panel)
end

function SystemDT:OnEnter()
    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    local fps = GetFpsValue()
    local homePing, worldPing = GetLatencyValues()
    tooltip:ClearLines()
    tooltip:AddLine("FPS / Latency")
    tooltip:AddDoubleLine("FPS", tostring(fps), 1, 1, 1, GetStatusColor(fps, "fps"))
    tooltip:AddDoubleLine("Home", format("%d ms", homePing), 1, 1, 1, GetStatusColor(homePing, "ping"))
    tooltip:AddDoubleLine("World", format("%d ms", worldPing), 1, 1, 1, GetStatusColor(worldPing, "ping"))
    AddTooltipHintLine(tooltip, "Click: Toggle addon memory usage")
    AddTooltipHintLine(tooltip, "Use Collect to force garbage cleanup")
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function SystemDT:OnClick()
    self:ToggleMemoryFrame()
end

function SystemDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function SystemDT:OnInitialize()
    self.definition = {
        name = "TwichUI: System",
        prettyName = "FPS / Latency",
        events = {
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = function(panel)
            SetSystemPanelText(panel)
        end,
        onUpdateFunc = DataTextModule:CreateBoundCallback(self, "OnUpdate"),
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end

---@class MailDataText : AceModule
local MailDT = DataTextModule:NewModule("MailDataText")

function MailDT:OnEvent(panel, event)
    SetMailPanelText(panel)
    -- UPDATE_PENDING_MAIL fires when the server notifies new mail is incoming, but
    -- HasNewMail() may not reflect the new state until the next frame. Re-check once
    -- after a short delay to catch that case.
    if event == "UPDATE_PENDING_MAIL" and C_Timer and C_Timer.After then
        C_Timer.After(0.1, function()
            SetMailPanelText(panel)
        end)
    end
end

function MailDT:OnEnter()
    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    tooltip:ClearLines()
    local hasMail = (C_Mail and C_Mail.HasNewMail and C_Mail.HasNewMail())
        or (HasNewMail and HasNewMail())
        or false
    tooltip:AddLine(hasMail and "New Mail" or "Mail")

    local senders = { GetLatestThreeSenders() }
    local hasSenders = false
    for _, sender in ipairs(senders) do
        if type(sender) == "string" and sender ~= "" then
            if not hasSenders then
                tooltip:AddLine(" ")
                hasSenders = true
            end
            tooltip:AddLine(sender, 1, 1, 1)
        end
    end

    if not hasSenders then
        tooltip:AddLine(" ")
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "No recent senders"))
    end

    DataTextModule:ShowDatatextTooltip(tooltip)
end

function MailDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function MailDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Mail",
        prettyName = "Mail",
        events = {
            "MAIL_INBOX_UPDATE",
            "UPDATE_PENDING_MAIL",
            "MAIL_CLOSED",
            "MAIL_SHOW",
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = nil,
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end

---@class FriendsDataText : AceModule
local FriendsDT = DataTextModule:NewModule("FriendsDataText")

function FriendsDT:OnEvent(panel, event)
    SetFriendsPanelText(panel)

    if event == "PLAYER_ENTERING_WORLD" or event == "BN_CONNECTED" then
        RequestUpdatedWowFriends(true)
    end
end

function FriendsDT:OnEnter()
    RequestUpdatedWowFriends(true)

    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    local wowFriends = CollectWowFriends()
    local bnetFriends = CollectBNetFriends()

    tooltip:ClearLines()
    tooltip:AddLine("Friends")
    tooltip:AddDoubleLine("WoW", tostring(#wowFriends), 1, 1, 1, 0.4, 0.86, 0.52)
    tooltip:AddDoubleLine("Battle.net", tostring(#bnetFriends), 1, 1, 1, 0.38, 0.72, 1)

    if #wowFriends > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("WoW Friends")
        for _, friendInfo in ipairs(wowFriends) do
            local status = friendInfo.afk and " AFK" or (friendInfo.dnd and " DND" or "")
            local line = format("%s  %s", tostring(friendInfo.name or "Friend"),
                T.Tools.Text.Color(T.Tools.Colors.GRAY, tostring(friendInfo.zone or "Unknown")))
            tooltip:AddLine(line .. status, 1, 1, 1)
        end
    end

    if #bnetFriends > 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine("Battle.net")
        for _, friendInfo in ipairs(bnetFriends) do
            local presence = friendInfo.characterName or friendInfo.richPresence or friendInfo.clientProgram or "Online"
            tooltip:AddLine(format("%s  %s", tostring(friendInfo.accountName or friendInfo.battleTag or "Friend"),
                T.Tools.Text.Color(T.Tools.Colors.GRAY, tostring(presence))), 1, 1, 1)
        end
    end

    if #wowFriends == 0 and #bnetFriends == 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Nobody is online right now."))
    end

    tooltip:AddLine(" ")
    AddTooltipHintLine(tooltip, "Click: Open friends list")
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function FriendsDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function FriendsDT:OnClick()
    if type(ToggleFriendsFrame) == "function" then
        ToggleFriendsFrame()
    end
end

function FriendsDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Friends",
        prettyName = "Friends",
        events = {
            "BN_FRIEND_ACCOUNT_ONLINE",
            "BN_FRIEND_ACCOUNT_OFFLINE",
            "BN_FRIEND_INFO_CHANGED",
            "BN_CONNECTED",
            "BN_DISCONNECTED",
            "FRIENDLIST_UPDATE",
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end

---@class DurabilityDataText : AceModule
local DurabilityDT = DataTextModule:NewModule("DurabilityDataText")

function DurabilityDT:OnEvent(panel)
    SetDurabilityPanelText(panel)
end

function DurabilityDT:OnEnter()
    local tooltip = DataTextModule:GetElvUITooltip()
    if not tooltip then
        return
    end

    local _, rows = GetDurabilityState()
    tooltip:ClearLines()
    tooltip:AddLine("Durability")

    if #rows == 0 then
        tooltip:AddLine(" ")
        tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "No tracked equipped durability."))
        DataTextModule:ShowDatatextTooltip(tooltip)
        return
    end

    tooltip:AddLine(" ")
    for _, row in ipairs(rows) do
        local icon = row.texture and T.Tools.Text.Icon(row.texture) or ""
        local r, g, b = GetStatusColor(100 - row.percent, "ping")
        tooltip:AddDoubleLine(format("%s %s", icon, row.slotLabel), FormatPercent(row.percent), 1, 1, 1, r, g, b)
    end

    tooltip:AddLine(" ")
    AddTooltipHintLine(tooltip, "Click: Open character frame")
    DataTextModule:ShowDatatextTooltip(tooltip)
end

function DurabilityDT:OnLeave()
    local tooltip = DataTextModule:GetActiveDatatextTooltip()
    if tooltip and tooltip.Hide then
        DataTextModule:HideDatatextTooltip(tooltip)
    end
end

function DurabilityDT:OnClick()
    if type(ToggleCharacter) == "function" then
        ToggleCharacter("PaperDollFrame")
    end
end

function DurabilityDT:OnInitialize()
    self.definition = {
        name = "TwichUI: Durability",
        prettyName = "Durability",
        events = {
            "UPDATE_INVENTORY_DURABILITY",
            "MERCHANT_SHOW",
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = DataTextModule:CreateBoundCallback(self, "OnEvent"),
        onUpdateFunc = nil,
        onClickFunc = DataTextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DataTextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DataTextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DataTextModule:Inform(self.definition)
end
