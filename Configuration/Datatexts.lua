--[[
    Configuration for additional datatexts.

    TODO: Clean this up
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@type DatatextConfigurationOptions
local Options = ConfigurationModule.Options.Datatext

local function TooltipHide()
    if _G.GameTooltip and _G.GameTooltip.Hide then
        _G.GameTooltip:Hide()
    end
end

local function TooltipForHearthstoneItem(itemID)
    return function(row)
        if not _G.GameTooltip or not _G.GameTooltip.SetOwner then return end
        _G.GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
        if _G.GameTooltip.SetToyByItemID then
            _G.GameTooltip:SetToyByItemID(itemID)
        elseif _G.GameTooltip.SetItemByID then
            _G.GameTooltip:SetItemByID(itemID)
        end
        _G.GameTooltip:Show()
    end
end

local hearthstoneSelector

local function BuildHearthstoneCandidates()
    local collected = {}
    table.insert(collected, {
        value = 0,
        name = "None",
        icon = nil,
        search = "none",
    })

    ---@type DataTextModule
    local DataTextModule = T:GetModule("Datatexts")
    local PortalDataText = DataTextModule and DataTextModule:GetModule("PortalDataText", true)
    if not PortalDataText or not PortalDataText.FindToyHearthstones then
        return collected
    end

    local ok, toyItemIDs = pcall(PortalDataText.FindToyHearthstones, PortalDataText)
    if not ok or type(toyItemIDs) ~= "table" then
        return collected
    end

    for _, itemID in ipairs(toyItemIDs) do
        local _, name, icon = C_ToyBox.GetToyInfo(itemID)
        if name then
            table.insert(collected, {
                value = itemID,
                name = tostring(name or ""),
                icon = icon,
                search = tostring(name or ""),
                onEnter = TooltipForHearthstoneItem(itemID),
                onLeave = TooltipHide,
            })
        end
    end

    return collected
end

local function OpenHearthstoneSelector()
    if not hearthstoneSelector then
        hearthstoneSelector = T.Tools.UI.CreateSearchSelector("TwichUIHearthstoneSelector",
            { hint = "Search hearthstones" }) or nil
    end

    if not hearthstoneSelector then
        return
    end

    local current = Options.GetFavoriteHearthstone and (Options:GetFavoriteHearthstone() or 0) or 0

    local E = _G.ElvUI and _G.ElvUI[1]
    local optionsFrame = (E and (E.OptionsUI or E.OptionsFrame)) or _G.UIParent
    hearthstoneSelector:Open({
        title = "Select Favorite Hearthstone",
        candidates = BuildHearthstoneCandidates(),
        selectedValue = current,
        relativeTo = optionsFrame,
        onSelect = function(value)
            if Options.SetFavoriteHearthstone then
                Options:SetFavoriteHearthstone(nil, tonumber(value) or 0)
                ConfigurationModule:Refresh()
            end
        end,
    })
end

local function TriggerDatatextFlash(datatextName, dbKey)
    ---@type DataTextModule|nil
    local datatextModule = T:GetModule("Datatexts", true)
    if datatextModule and datatextModule.TestDatatextFlash then
        datatextModule:TestDatatextFlash(datatextName, dbKey)
    end
end

local function BuildGoldGoblinConfiguration()
    local W = ConfigurationModule.Widgets
    local goldGoblin = {
        type = "group",
        name = "Gold",
        order = 20,
        args = {
            title = W.TitleWidget(0, "Gold"),
            desc = W.Description(1,
                "Provides a DataText for quick access to gold-making information and profession shortcuts."),
            goldDisplay = W.IGroup(5, "Gold Display", {
                displayMode = {
                    type = "select",
                    name = "Display Mode",
                    desc = "How to display the gold amount.",
                    order = 1,
                    values = {
                        full = "Full",
                        compact = "Short",
                    },
                    handler = Options,
                    get = "GetGoblinGoldDisplayMode",
                    set = "SetGoblinGoldDisplayMode",
                },
                flashOnUpdate = {
                    type = "toggle",
                    name = "Flash on Update",
                    desc = "Play a short highlight pulse when your displayed gold amount changes.",
                    order = 2,
                    get = function()
                        return Options:GetDatatextDB("goblin").flashOnUpdate == true
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("goblin").flashOnUpdate = value == true
                    end,
                },
                testFlash = {
                    type = "execute",
                    name = "Test Flash",
                    desc = "Preview the gold datatext flash on any visible panel using it.",
                    order = 3,
                    width = 1,
                    func = function()
                        TriggerDatatextFlash("TwichUI: Gold Goblin", "goblin")
                    end,
                },
            }),
            tooltipOptions = W.IGroup(10, "Professions", {
                showProfessions = {
                    type = "toggle",
                    name = "Show in Tooltip",
                    desc =
                    "Show your profession information in the tooltip that appears when you hover over the datatext.",
                    order = 1,
                    handler = Options,
                    get = "GetGoblinShowProfessions",
                    set = "SetGoblinShowProfessions",
                },
                professionsDisplayMode = {
                    type = "select",
                    name = "Display Mode",
                    desc = "How to display profession information in the tooltip.",
                    order = 2,
                    values = {
                        both = "Level and modifier",
                        level = "Level only",
                        modifiers = "Modifier only",
                        total = "Level + Modifier"
                    },
                    handler = Options,
                    get = "GetGoblinProfessionDisplayMode",
                    set = "SetGoblinProfessionDisplayMode"
                },
                professionsShowMaxSkillLevel = {
                    type = "toggle",
                    name = "Show Max Skill Level",
                    desc = "Show the max skill level in the profession tooltip info.",
                    order = 3,
                    handler = Options,
                    get = "GetGoblinProfessionShowMaxSkillLevel",
                    set = "SetGoblinProfessionShowMaxSkillLevel"
                }
            }),
            addonsOptions = W.IGroup(20, "AddOn Shortcuts", {
                showShortcuts = {
                    type = "toggle",
                    name = "Add Shortcut Menu",
                    desc = "Adds a menu to access configured addons when the datatext is right-clicked.",
                    order = 1,
                    handler = Options,
                    get = "GetGoblinAddonShortcutsEnabled",
                    set = "SetGoblinAddonShortcutsEnabled"
                },
                addons = W.IGroup(2, "AddOns", {
                    desc = W.Description(0, "AddOns can only be enabled if they are installed and enabled.")
                })
            })
        },
    }

    ---@type GoblinDataText
    local GDT = T:GetModule("Datatexts"):GetModule("Goblin")

    local addonList = {}

    for key, addon in pairs(GDT.SUPPORTED_ADDONS) do
        table.insert(addonList, addon)
    end

    table.sort(addonList, function(a, b)
        return (a.prettyName or "") < (b.prettyName or "")
    end)


    local idx = 1

    for key, addon in pairs(addonList) do
        local optionKey = addon.prettyName or key

        -- ensure addon is loaded
        goldGoblin.args.addonsOptions.args.addons.args[optionKey] = {
            type = "toggle",
            name = T.Tools.Text.Icon(addon.iconTexture) .. " " .. addon.prettyName,
            desc = "Show a shortcut for " .. addon.prettyName .. " in the right-click menu.",
            order = idx,

            -- Ace-compatible get/set with info arg
            get = function(info)
                local addOnName = info[#info] -- "TradeSkillMaster"
                return Options:GetIsGoblinAddonEnabled(addOnName)
            end,
            set = function(info, value)
                local addOnName = info[#info]
                Options:SetIsGoblinAddonEnabled(addOnName, value)
                GDT.addonMenuListFlaggedForRebuild = true
            end,
            disabled = function()
                return not addon.availableFunc()
            end,
        }

        idx = idx + 1
    end

    return goldGoblin
end

local function BuildPortalsConfiguration()
    local W = ConfigurationModule.Widgets
    local portals = {
        type = "group",
        name = "Portals",
        order = 30,
        args = {
            title = W.TitleWidget(0, "Portals"),
            desc = W.Description(1, "Provides a DataText for quick access to favorite portals."),
            desc2 = W.Description(2,
                T.Tools.Text.Color(T.Tools.Colors.SECONDARY, "NOTE:") ..
                " When Quality of Life > Teleports is enabled, left-click also opens the teleport browser."),
            color = W.IGroup(10, "Colors", {
                customColor = {
                    type = "toggle",
                    name = "Custom Text Color",
                    desc = "Use a custom color for the text.",
                    handler = Options,
                    get = "GetPortalsUseCustomColor",
                    set = "SetPortalsUseCustomColor",
                    order = 1,
                },
                flashOnUpdate = {
                    type = "toggle",
                    name = "Flash on Update",
                    desc = "Play a short highlight pulse when the portals datatext value changes.",
                    order = 2,
                    get = function()
                        return Options:GetDatatextDB("portals").flashOnUpdate == true
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("portals").flashOnUpdate = value == true
                    end,
                },
                testFlash = {
                    type = "execute",
                    name = "Test Flash",
                    desc = "Preview the portals datatext flash on any visible panel using it.",
                    order = 3,
                    width = 1,
                    func = function()
                        TriggerDatatextFlash("TwichUI: Portals", "portals")
                    end,
                },
                textColor = {
                    type = "color",
                    name = "Text Color",
                    desc = "Color of the text.",
                    order = 4,
                    disabled = function()
                        return not Options:GetDatatextDB("portals").customColor
                    end,
                    hasAlpha = true,
                    handler = Options,
                    get = "GetPortalsTextColor",
                    set = "SetPortalsTextColor",
                }
            }),
            hearthstone = W.IGroup(20, "Favorite Hearthstone", {
                selectFavorite = {
                    type = "execute",
                    width = 2,
                    name = function()
                        if not Options.GetFavoriteHearthstone then
                            return "None"
                        end
                        local itemID = Options:GetFavoriteHearthstone() or 0
                        if itemID == 0 then
                            return "None"
                        end
                        local _, name, icon = C_ToyBox.GetToyInfo(itemID)
                        local label = tostring(name or ("Item " .. itemID))
                        if icon and T.Tools and T.Tools.Text and T.Tools.Text.Icon then
                            return T.Tools.Text.Icon(tostring(icon)) .. " " .. label
                        end
                        return label
                    end,
                    desc = "Select which hearthstone toy to treat as your favorite for the Portals DataText.",
                    order = 1,
                    func = function()
                        OpenHearthstoneSelector()
                    end,
                },
            }),
        }
    }
    return portals
end

local function BuildMythicPlusConfiguration()
    local W = ConfigurationModule.Widgets
    local mythicPlus = {
        type = "group",
        name = "Mythic+",
        order = 25,
        args = {
            title = W.TitleWidget(0, "Mythic+"),
            desc = W.Description(1,
                "Provides a DataText for your Mythic+ score, weekly affixes, seasonal dungeon bests, and reward progress."),
            color = W.IGroup(10, "Colors", {
                customColor = {
                    type = "toggle",
                    name = "Custom Text Color",
                    desc = "Use a custom color for the Mythic+ datatext.",
                    handler = Options,
                    get = "GetMythicPlusUseCustomColor",
                    set = "SetMythicPlusUseCustomColor",
                    order = 1,
                },
                flashOnUpdate = {
                    type = "toggle",
                    name = "Flash on Update",
                    desc = "Play a short highlight pulse when the Mythic+ datatext value changes.",
                    order = 2,
                    get = function()
                        return Options:GetDatatextDB("mythicplus").flashOnUpdate == true
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("mythicplus").flashOnUpdate = value == true
                    end,
                },
                testFlash = {
                    type = "execute",
                    name = "Test Flash",
                    desc = "Preview the Mythic+ datatext flash on any visible panel using it.",
                    order = 3,
                    width = 1,
                    func = function()
                        TriggerDatatextFlash("TwichUI: Mythic+", "mythicplus")
                    end,
                },
                textColor = {
                    type = "color",
                    name = "Text Color",
                    desc = "Color of the Mythic+ datatext.",
                    order = 4,
                    disabled = function()
                        return not Options:GetDatatextDB("mythicplus").customColor
                    end,
                    hasAlpha = true,
                    handler = Options,
                    get = "GetMythicPlusTextColor",
                    set = "SetMythicPlusTextColor",
                },
            }),
            tooltip = W.IGroup(20, "Tooltip", {
                showAffixes = {
                    type = "toggle",
                    name = "Show Weekly Affixes",
                    desc = "Show the current week's affixes in the tooltip.",
                    order = 1,
                    handler = Options,
                    get = "GetMythicPlusShowAffixes",
                    set = "SetMythicPlusShowAffixes",
                },
                showDungeonBests = {
                    type = "toggle",
                    name = "Show Season Bests",
                    desc = "Show your best score and best key level for each dungeon in the tooltip.",
                    order = 2,
                    handler = Options,
                    get = "GetMythicPlusShowDungeonBests",
                    set = "SetMythicPlusShowDungeonBests",
                },
                showRewardProgress = {
                    type = "toggle",
                    name = "Show Reward Progress",
                    desc = "Show seasonal reward milestone progress bars in the tooltip.",
                    order = 3,
                    handler = Options,
                    get = "GetMythicPlusShowRewardProgress",
                    set = "SetMythicPlusShowRewardProgress",
                },
            }),
        },
    }

    return mythicPlus
end

local function BuildChoresConfiguration()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Chores",
        order = 25,
        args = {
            title = W.TitleWidget(0, "Chores"),
            desc = W.Description(1,
                "Provides a DataText that summarizes your remaining weekly chores and shows the outstanding items in the tooltip."),
            helper = W.Description(2,
                T.Tools.Text.Color(T.Tools.Colors.GRAY,
                    "This DataText reads from the Quality of Life > Chores tracker. Disable categories there if you do not want them counted.")),
            color = W.IGroup(10, "Colors", {
                customColor = {
                    type = "toggle",
                    name = "Custom Text Color",
                    desc = "Use a custom color for the chore count.",
                    order = 1,
                    handler = Options,
                    get = "GetChoresUseCustomColor",
                    set = "SetChoresUseCustomColor",
                },
                flashOnUpdate = {
                    type = "toggle",
                    name = "Flash on Update",
                    desc = "Play a short highlight pulse when the chores summary changes.",
                    order = 2,
                    get = function()
                        return Options:GetDatatextDB("chores").flashOnUpdate == true
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("chores").flashOnUpdate = value == true
                    end,
                },
                testFlash = {
                    type = "execute",
                    name = "Test Flash",
                    desc = "Preview the chores datatext flash on any visible panel using it.",
                    order = 3,
                    width = 1,
                    func = function()
                        TriggerDatatextFlash("TwichUI: Chores", "chores")
                    end,
                },
                textColor = {
                    type = "color",
                    name = "Text Color",
                    desc = "Color of the chore count.",
                    order = 4,
                    hasAlpha = true,
                    disabled = function()
                        return not Options:GetDatatextDB("chores").customColor
                    end,
                    handler = Options,
                    get = "GetChoresTextColor",
                    set = "SetChoresTextColor",
                },
                customDoneColor = {
                    type = "toggle",
                    name = "Custom Done Color",
                    desc = "Override the default green color used when all tracked chores are complete.",
                    order = 5,
                    handler = Options,
                    get = "GetChoresUseCustomDoneColor",
                    set = "SetChoresUseCustomDoneColor",
                },
                doneTextColor = {
                    type = "color",
                    name = "Done Color",
                    desc = "Color used for the datatext when all tracked chores are complete.",
                    order = 6,
                    hasAlpha = true,
                    disabled = function()
                        return not Options:GetDatatextDB("chores").customDoneColor
                    end,
                    handler = Options,
                    get = "GetChoresDoneTextColor",
                    set = "SetChoresDoneTextColor",
                },
            }),
            tooltipFonts = W.IGroup(20, "Tooltip Fonts", {
                headerFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Header Font",
                    desc = "Font used for chore section headers in the tooltip.",
                    order = 1,
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("font") or {} end,
                    handler = Options,
                    get = "GetChoresTooltipHeaderFont",
                    set = "SetChoresTooltipHeaderFont",
                },
                headerFontSize = {
                    type = "range",
                    name = "Header Font Size",
                    desc = "Font size used for chore section headers in the tooltip.",
                    order = 2,
                    min = 8,
                    max = 24,
                    step = 1,
                    handler = Options,
                    get = "GetChoresTooltipHeaderFontSize",
                    set = "SetChoresTooltipHeaderFontSize",
                },
                entryFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Entry Font",
                    desc = "Font used for chore entries and objective lines in the tooltip.",
                    order = 3,
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("font") or {} end,
                    handler = Options,
                    get = "GetChoresTooltipEntryFont",
                    set = "SetChoresTooltipEntryFont",
                },
                entryFontSize = {
                    type = "range",
                    name = "Entry Font Size",
                    desc = "Font size used for chore entries and objective lines in the tooltip.",
                    order = 4,
                    min = 8,
                    max = 24,
                    step = 1,
                    handler = Options,
                    get = "GetChoresTooltipEntryFontSize",
                    set = "SetChoresTooltipEntryFontSize",
                },
            }),
        },
    }
end

local function BuildGatheringConfiguration()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Gathering",
        order = 24,
        args = {
            title = W.TitleWidget(0, "Gathering"),
            desc = W.Description(1,
                "Shows gathering session value and gold-per-hour stats, with quick controls from the datatext menu."),
            color = W.IGroup(10, "Colors", {
                customColor = {
                    type = "toggle",
                    name = "Custom Text Color",
                    desc = "Use a custom color for the gathering datatext.",
                    order = 1,
                    handler = Options,
                    get = "GetGatheringUseCustomColor",
                    set = "SetGatheringUseCustomColor",
                },
                flashOnUpdate = {
                    type = "toggle",
                    name = "Flash on Update",
                    desc = "Play a short highlight pulse when the gathering summary changes.",
                    order = 2,
                    get = function()
                        return Options:GetDatatextDB("gathering").flashOnUpdate == true
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("gathering").flashOnUpdate = value == true
                    end,
                },
                testFlash = {
                    type = "execute",
                    name = "Test Flash",
                    desc = "Preview the gathering datatext flash on any visible panel using it.",
                    order = 3,
                    width = 1,
                    func = function()
                        TriggerDatatextFlash("TwichUI: Gathering", "gathering")
                    end,
                },
                textColor = {
                    type = "color",
                    name = "Text Color",
                    desc = "Color of the gathering datatext.",
                    order = 4,
                    hasAlpha = true,
                    disabled = function()
                        return not Options:GetDatatextDB("gathering").customColor
                    end,
                    handler = Options,
                    get = "GetGatheringTextColor",
                    set = "SetGatheringTextColor",
                },
            }),
        },
    }
end

local function RefreshNamedDatatext(datatextName)
    ---@type DataTextModule|nil
    local datatextModule = T:GetModule("Datatexts", true)
    if datatextModule and datatextModule.RefreshDataText then
        datatextModule:RefreshDataText(datatextName)
    end
end

local function EnsureDatatextColor(dbKey, defaultColor)
    local db = Options:GetDatatextDB(dbKey)
    if type(db.textColor) ~= "table" then
        db.textColor = {
            defaultColor[1] or 1,
            defaultColor[2] or 1,
            defaultColor[3] or 1,
            defaultColor[4] or 1,
        }
    end
    return db
end

local function EnsureDatatextInlineColor(dbKey, fieldName, defaultColor)
    local db = Options:GetDatatextDB(dbKey)
    if type(db[fieldName]) ~= "table" then
        db[fieldName] = {
            defaultColor[1] or 1,
            defaultColor[2] or 1,
            defaultColor[3] or 1,
            defaultColor[4] or 1,
        }
    end
    return db
end

local function BuildInlineColorGroup(W, order, dbKey, datatextName, label, defaultColor)
    defaultColor = defaultColor or { 1, 1, 1, 1 }
    return W.IGroup(order, label or "Colors", {
        customColor = {
            type = "toggle",
            name = "Custom Text Color",
            desc = "Use a custom color for the text.",
            order = 1,
            get = function()
                local db = Options:GetDatatextDB(dbKey)
                return db.customColor == true
            end,
            set = function(_, value)
                local db = Options:GetDatatextDB(dbKey)
                db.customColor = value == true
                RefreshNamedDatatext(datatextName)
            end,
        },
        flashOnUpdate = {
            type = "toggle",
            name = "Flash on Update",
            desc = "Play a short highlight pulse when the displayed datatext value changes.",
            order = 2,
            get = function()
                local db = Options:GetDatatextDB(dbKey)
                return db.flashOnUpdate == true
            end,
            set = function(_, value)
                local db = Options:GetDatatextDB(dbKey)
                db.flashOnUpdate = value == true
            end,
        },
        testFlash = {
            type = "execute",
            name = "Test Flash",
            desc = "Preview the flash animation on any visible panel using this datatext.",
            order = 3,
            width = 1,
            func = function()
                TriggerDatatextFlash(datatextName, dbKey)
            end,
        },
        textColor = {
            type = "color",
            name = "Text Color",
            desc = "Color of the datatext.",
            order = 4,
            hasAlpha = true,
            disabled = function()
                local db = Options:GetDatatextDB(dbKey)
                return db.customColor ~= true
            end,
            get = function()
                local db = EnsureDatatextColor(dbKey, defaultColor)
                return unpack(db.textColor)
            end,
            set = function(_, r, g, b, a)
                local db = EnsureDatatextColor(dbKey, defaultColor)
                db.textColor = { r, g, b, a }
                RefreshNamedDatatext(datatextName)
            end,
        },
    })
end

local currencySelector

local function OpenCurrencySelector(mode)
    if not currencySelector then
        currencySelector = T.Tools.UI.CreateSearchSelector("TwichUICurrencySelector", { hint = "Search currencies" }) or
            nil
    end

    if not currencySelector then
        return
    end

    local E = _G.ElvUI and _G.ElvUI[1]
    local optionsFrame = (E and (E.OptionsUI or E.OptionsFrame)) or _G.UIParent
    currencySelector:Open({
        title = mode == "tooltip" and "Add Tooltip Currency" or "Add Custom Currency Text",
        candidates = Options:GetCurrencySelectorCandidates(),
        selectedValue = 0,
        relativeTo = optionsFrame,
        onSelect = function(value)
            if mode == "tooltip" then
                Options:AddTooltipCurrency(value)
            else
                Options:AddCustomCurrencyDatatext(value)
            end
            ConfigurationModule:Refresh()
        end,
    })
end

local function BuildTimeConfiguration()
    local W = ConfigurationModule.Widgets
    return {
        type = "group",
        name = "Time",
        order = 5,
        args = {
            title = W.TitleWidget(0, "Time"),
            desc = W.Description(1,
                "Displays a lightweight clock with reset timers in the tooltip and quick access to the calendar."),
            display = W.IGroup(10, "Display", {
                localTime = {
                    type = "toggle",
                    name = "Use Local Time",
                    desc = "Show your local system time instead of realm time on the datatext.",
                    order = 1,
                    get = function()
                        return Options:GetDatatextDB("time").localTime == true
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("time").localTime = value == true
                        RefreshNamedDatatext("TwichUI: Time")
                    end,
                },
                twentyFourHour = {
                    type = "toggle",
                    name = "24-Hour Clock",
                    desc = "Use 24-hour time instead of AM/PM.",
                    order = 2,
                    get = function()
                        local db = Options:GetDatatextDB("time")
                        return db.twentyFourHour ~= false
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("time").twentyFourHour = value == true
                        RefreshNamedDatatext("TwichUI: Time")
                    end,
                },
                showAmPm = {
                    type = "toggle",
                    name = "Show AM/PM",
                    desc = "Show an AM/PM suffix when using the 12-hour clock.",
                    order = 3,
                    disabled = function()
                        local db = Options:GetDatatextDB("time")
                        return db.twentyFourHour ~= false
                    end,
                    get = function()
                        return Options:GetDatatextDB("time").showAmPm ~= false
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("time").showAmPm = value == true
                        RefreshNamedDatatext("TwichUI: Time")
                    end,
                },
                showSeconds = {
                    type = "toggle",
                    name = "Show Seconds",
                    desc = "Refresh the clock every second and include seconds in the display.",
                    order = 4,
                    get = function()
                        return Options:GetDatatextDB("time").showSeconds == true
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("time").showSeconds = value == true
                        RefreshNamedDatatext("TwichUI: Time")
                    end,
                },
                showDailyReset = {
                    type = "toggle",
                    name = "Daily Reset in Tooltip",
                    desc = "Show the time remaining until the daily reset in the tooltip.",
                    order = 5,
                    get = function()
                        local db = Options:GetDatatextDB("time")
                        return db.showDailyReset ~= false
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("time").showDailyReset = value == true
                    end,
                },
                showWeeklyReset = {
                    type = "toggle",
                    name = "Weekly Reset in Tooltip",
                    desc = "Show the time remaining until the weekly reset in the tooltip.",
                    order = 6,
                    get = function()
                        local db = Options:GetDatatextDB("time")
                        return db.showWeeklyReset ~= false
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("time").showWeeklyReset = value == true
                    end,
                },
            }),
            colors = W.IGroup(20, "Colors", {
                customColor = {
                    type = "toggle",
                    name = "Custom Text Color",
                    desc = "Use a custom color for the main time text.",
                    order = 1,
                    get = function()
                        local db = Options:GetDatatextDB("time")
                        return db.customColor == true
                    end,
                    set = function(_, value)
                        local db = Options:GetDatatextDB("time")
                        db.customColor = value == true
                        RefreshNamedDatatext("TwichUI: Time")
                    end,
                },
                textColor = {
                    type = "color",
                    name = "Text Color",
                    desc = "Color of the main time text.",
                    order = 2,
                    hasAlpha = true,
                    disabled = function()
                        local db = Options:GetDatatextDB("time")
                        return db.customColor ~= true
                    end,
                    get = function()
                        local db = EnsureDatatextColor("time", { 1, 1, 1, 1 })
                        return unpack(db.textColor)
                    end,
                    set = function(_, r, g, b, a)
                        local db = EnsureDatatextColor("time", { 1, 1, 1, 1 })
                        db.textColor = { r, g, b, a }
                        RefreshNamedDatatext("TwichUI: Time")
                    end,
                },
                customAmPmColor = {
                    type = "toggle",
                    name = "Custom AM/PM Color",
                    desc = "Use a custom color for the AM/PM suffix.",
                    order = 3,
                    disabled = function()
                        local db = Options:GetDatatextDB("time")
                        return db.twentyFourHour ~= false or db.showAmPm == false
                    end,
                    get = function()
                        local db = Options:GetDatatextDB("time")
                        return db.customAmPmColor == true
                    end,
                    set = function(_, value)
                        local db = Options:GetDatatextDB("time")
                        db.customAmPmColor = value == true
                        RefreshNamedDatatext("TwichUI: Time")
                    end,
                },
                amPmColor = {
                    type = "color",
                    name = "AM/PM Color",
                    desc = "Color of the AM/PM suffix.",
                    order = 4,
                    hasAlpha = true,
                    disabled = function()
                        local db = Options:GetDatatextDB("time")
                        return db.twentyFourHour ~= false or db.showAmPm == false or db.customAmPmColor ~= true
                    end,
                    get = function()
                        local db = EnsureDatatextInlineColor("time", "amPmColor", { 0.96, 0.76, 0.24, 1 })
                        return unpack(db.amPmColor)
                    end,
                    set = function(_, r, g, b, a)
                        local db = EnsureDatatextInlineColor("time", "amPmColor", { 0.96, 0.76, 0.24, 1 })
                        db.amPmColor = { r, g, b, a }
                        RefreshNamedDatatext("TwichUI: Time")
                    end,
                },
            }),
        },
    }
end

local function BuildSystemConfiguration()
    local W = ConfigurationModule.Widgets
    return {
        type = "group",
        name = "FPS / Latency",
        order = 6,
        args = {
            title = W.TitleWidget(0, "FPS / Latency"),
            desc = W.Description(1,
                "Shows framerate and your preferred latency source with a compact tooltip for connection health."),
            display = W.IGroup(10, "Display", {
                latencySource = {
                    type = "select",
                    name = "Latency Source",
                    desc = "Which latency value should be shown on the datatext.",
                    order = 1,
                    values = {
                        WORLD = "World",
                        HOME = "Home",
                    },
                    get = function()
                        return Options:GetDatatextDB("system").latencySource or "WORLD"
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("system").latencySource = value
                        RefreshNamedDatatext("TwichUI: System")
                    end,
                },
                showLabels = {
                    type = "toggle",
                    name = "Show Labels",
                    desc = "Include FPS and latency labels in the datatext instead of showing bare values.",
                    order = 2,
                    get = function()
                        local db = Options:GetDatatextDB("system")
                        return db.showLabels ~= false
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("system").showLabels = value == true
                        RefreshNamedDatatext("TwichUI: System")
                    end,
                },
                showLatencySource = {
                    type = "toggle",
                    name = "Show Latency Source",
                    desc = "Show whether the displayed latency is using the Home or World source in the datatext.",
                    order = 3,
                    get = function()
                        local db = Options:GetDatatextDB("system")
                        return db.showLatencySource ~= false
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("system").showLatencySource = value == true
                        RefreshNamedDatatext("TwichUI: System")
                    end,
                },
            }),
            colors = BuildInlineColorGroup(W, 20, "system", "TwichUI: System", "Custom Tint", { 1, 1, 1, 1 }),
        },
    }
end

local function BuildMailConfiguration()
    local W = ConfigurationModule.Widgets
    return {
        type = "group",
        name = "Mail",
        order = 7,
        args = {
            title = W.TitleWidget(0, "Mail"),
            desc = W.Description(1, "Shows whether you have pending mail and lists the latest senders in the tooltip."),
            display = W.IGroup(10, "Display", {
                iconOnly = {
                    type = "toggle",
                    name = "Compact Label",
                    desc = "Keep the datatext label compact instead of switching between Mail and New Mail.",
                    order = 1,
                    get = function()
                        return Options:GetDatatextDB("mail").iconOnly == true
                    end,
                    set = function(_, value)
                        Options:GetDatatextDB("mail").iconOnly = value == true
                        RefreshNamedDatatext("TwichUI: Mail")
                    end,
                },
            }),
            colors = BuildInlineColorGroup(W, 20, "mail", "TwichUI: Mail", "Custom Tint", { 0.75, 0.78, 0.84, 1 }),
        },
    }
end

local function BuildFriendsConfiguration()
    local W = ConfigurationModule.Widgets
    return {
        type = "group",
        name = "Friends",
        order = 8,
        args = {
            title = W.TitleWidget(0, "Friends"),
            desc = W.Description(1, "Summarizes online WoW and Battle.net friends and opens the friends list on click."),
            behavior = W.IGroup(5, "Behavior", {
                countWoWOnly = {
                    type = "toggle",
                    name = "Count WoW Clients Only",
                    desc = "Only count friends who are currently online in World of Warcraft in the datatext total.",
                    order = 1,
                    handler = Options,
                    get = "GetFriendsCountWoWOnly",
                    set = "SetFriendsCountWoWOnly",
                },
            }),
            colors = BuildInlineColorGroup(W, 10, "friends", "TwichUI: Friends", "Custom Tint", { 0.4, 0.86, 0.52, 1 }),
        },
    }
end

local function BuildDurabilityConfiguration()
    local W = ConfigurationModule.Widgets
    return {
        type = "group",
        name = "Durability",
        order = 9,
        args = {
            title = W.TitleWidget(0, "Durability"),
            desc = W.Description(1,
                "Tracks your lowest equipped durability and lists worn item durability in the tooltip."),
            colors = BuildInlineColorGroup(W, 10, "durability", "TwichUI: Durability", "Custom Tint",
                { 1, 0.84, 0.28, 1 }),
        },
    }
end

local function BuildSpecializationConfiguration()
    local W = ConfigurationModule.Widgets
    return {
        type = "group",
        name = "Specialization",
        order = 10,
        args = {
            title = W.TitleWidget(0, "Specialization"),
            desc = W.Description(1,
                "Shows your active talent specialization with quick menus for spec switching, loot specialization, and direct access to the talents frame."),
            display = W.IGroup(10, "Display", {
                displayStyle = {
                    type = "select",
                    name = "Display Style",
                    desc =
                    "Choose whether the datatext shows your spec only, adds loot specialization, adds loadout, or shows all available details.",
                    order = 1,
                    values = {
                        SPEC = "Spec Only",
                        SPEC_LOOT = "Spec + Loot Spec",
                        SPEC_LOADOUT = "Spec + Loadout",
                        FULL = "Spec + Loot Spec + Loadout",
                    },
                    get = function()
                        local db = Options:GetDatatextDB("specialization")
                        return db.displayStyle or "SPEC"
                    end,
                    set = function(_, value)
                        local db = Options:GetDatatextDB("specialization")
                        db.displayStyle = value or "SPEC"
                        RefreshNamedDatatext("TwichUI: Specialization")
                    end,
                },
                showIcon = {
                    type = "toggle",
                    name = "Show Icon",
                    desc = "Include the spec icon in the datatext.",
                    order = 2,
                    get = function()
                        local db = Options:GetDatatextDB("specialization")
                        return db.showIcon ~= false
                    end,
                    set = function(_, value)
                        local db = Options:GetDatatextDB("specialization")
                        db.showIcon = value == true
                        RefreshNamedDatatext("TwichUI: Specialization")
                    end,
                },
                iconOnly = {
                    type = "toggle",
                    name = "Icon Only",
                    desc = "Use a tighter icon-first presentation for the active spec.",
                    order = 3,
                    disabled = function()
                        local db = Options:GetDatatextDB("specialization")
                        return db.showIcon == false
                    end,
                    get = function()
                        local db = Options:GetDatatextDB("specialization")
                        return db.iconOnly == true
                    end,
                    set = function(_, value)
                        local db = Options:GetDatatextDB("specialization")
                        db.iconOnly = value == true
                        RefreshNamedDatatext("TwichUI: Specialization")
                    end,
                },
                abbreviate = {
                    type = "toggle",
                    name = "Abbreviate Text",
                    desc = "Shorten spec and loadout names to fit tighter panels more cleanly.",
                    order = 4,
                    get = function()
                        local db = Options:GetDatatextDB("specialization")
                        return db.abbreviate ~= false
                    end,
                    set = function(_, value)
                        local db = Options:GetDatatextDB("specialization")
                        db.abbreviate = value == true
                        RefreshNamedDatatext("TwichUI: Specialization")
                    end,
                },
            }),
            colors = BuildInlineColorGroup(W, 20, "specialization", "TwichUI: Specialization", "Custom Tint",
                { 0.82, 0.9, 1, 1 }),
        },
    }
end

local function BuildCurrenciesConfiguration()
    local W = ConfigurationModule.Widgets
    local tooltipEntries = Options:GetTooltipCurrencyEntries()
    local customEntries = Options:GetCustomCurrencyDatatextEntries()

    local tooltipArgs = {
        addTooltipCurrency = {
            type = "execute",
            name = "Add Tooltip Currency",
            desc = "Add a currency to the base Currencies tooltip.",
            order = 1,
            width = 1.5,
            func = function()
                OpenCurrencySelector("tooltip")
            end,
        },
    }

    if #tooltipEntries == 0 then
        tooltipArgs.empty = W.Description(5,
            T.Tools.Text.Color(T.Tools.Colors.GRAY, "No extra currencies are pinned to the tooltip yet."))
    else
        for index, entry in ipairs(tooltipEntries) do
            tooltipArgs["tooltipCurrency" .. tostring(entry.id)] = {
                type = "execute",
                name = ((entry.icon and T.Tools.Text.Icon(tostring(entry.icon)) .. " ") or "") .. tostring(entry.name),
                desc = "Remove this currency from the tooltip list.",
                order = 10 + index,
                func = function()
                    Options:RemoveTooltipCurrency(entry.id)
                    ConfigurationModule:Refresh()
                end,
            }
        end
    end

    local customArgs = {
        addCustomCurrency = {
            type = "execute",
            name = "Add Custom Currency Text",
            desc = "Create a standalone datatext for one of your known currencies.",
            order = 1,
            width = 1.5,
            func = function()
                OpenCurrencySelector("custom")
            end,
        },
    }

    if #customEntries == 0 then
        customArgs.empty = W.Description(5,
            T.Tools.Text.Color(T.Tools.Colors.GRAY, "No custom currency datatexts have been created yet."))
    else
        for index, entry in ipairs(customEntries) do
            customArgs["customCurrency" .. tostring(entry.id)] = {
                type = "group",
                name = ((entry.icon and T.Tools.Text.Icon(tostring(entry.icon)) .. " ") or "") .. tostring(entry.name),
                order = 10 + index,
                args = {
                    showIcon = {
                        type = "toggle",
                        name = "Show Icon",
                        desc = "Include the currency icon in the custom datatext.",
                        order = 1,
                        get = function()
                            return Options:GetCustomCurrencyDatatextSetting(entry.id, "showIcon", true)
                        end,
                        set = function(_, value)
                            Options:SetCustomCurrencyDatatextSetting(entry.id, "showIcon", value == true)
                        end,
                    },
                    nameStyle = {
                        type = "select",
                        name = "Name Style",
                        desc = "How the currency name should appear on the custom datatext.",
                        order = 2,
                        values = {
                            full = "Full",
                            abbr = "Short",
                            none = "None",
                        },
                        get = function()
                            return Options:GetCustomCurrencyDatatextSetting(entry.id, "nameStyle", "abbr")
                        end,
                        set = function(_, value)
                            Options:SetCustomCurrencyDatatextSetting(entry.id, "nameStyle", value)
                        end,
                    },
                    showMax = {
                        type = "toggle",
                        name = "Show Max Quantity",
                        desc = "Append the maximum quantity when the currency has one.",
                        order = 3,
                        get = function()
                            return Options:GetCustomCurrencyDatatextSetting(entry.id, "showMax", true)
                        end,
                        set = function(_, value)
                            Options:SetCustomCurrencyDatatextSetting(entry.id, "showMax", value == true)
                        end,
                    },
                    includeInTooltip = {
                        type = "toggle",
                        name = "Include in Base Tooltip",
                        desc = "Show this custom currency in the base Currencies tooltip as well.",
                        order = 4,
                        get = function()
                            return Options:GetCustomCurrencyDatatextSetting(entry.id, "includeInTooltip", true)
                        end,
                        set = function(_, value)
                            Options:SetCustomCurrencyDatatextSetting(entry.id, "includeInTooltip", value == true)
                        end,
                    },
                    remove = {
                        type = "execute",
                        name = "Remove",
                        desc = "Remove this custom currency datatext.",
                        order = 10,
                        width = 1.0,
                        func = function()
                            Options:RemoveCustomCurrencyDatatext(entry.id)
                            ConfigurationModule:Refresh()
                        end,
                    },
                },
            }
        end
    end

    return {
        type = "group",
        name = "Currencies",
        order = 10,
        args = {
            title = W.TitleWidget(0, "Currencies"),
            desc = W.Description(1,
                "Shows a primary currency on the datatext, builds a curated tooltip list, and lets you create standalone custom currency texts."),
            display = W.IGroup(10, "Display", {
                displayedCurrency = {
                    type = "select",
                    name = "Displayed Resource",
                    desc = "What the base Currencies datatext should show.",
                    order = 1,
                    values = function()
                        return Options:GetCurrencyDisplayChoices()
                    end,
                    handler = Options,
                    get = "GetCurrenciesDisplaySource",
                    set = "SetCurrenciesDisplaySource",
                },
                displayStyle = {
                    type = "select",
                    name = "Display Style",
                    desc = "How currency names should be presented on the base datatext.",
                    order = 2,
                    values = {
                        ICON = "Icon + Value",
                        ICON_TEXT = "Icon + Full Name",
                        ICON_TEXT_ABBR = "Icon + Short Name",
                    },
                    handler = Options,
                    get = "GetCurrenciesDisplayStyle",
                    set = "SetCurrenciesDisplayStyle",
                },
                showMax = {
                    type = "toggle",
                    name = "Show Max Quantity",
                    desc = "Append the maximum quantity when the selected currency has one.",
                    order = 3,
                    handler = Options,
                    get = "GetCurrenciesShowMax",
                    set = "SetCurrenciesShowMax",
                },
                showGoldInTooltip = {
                    type = "toggle",
                    name = "Show Gold in Tooltip",
                    desc = "Include your current gold total in the currencies tooltip.",
                    order = 4,
                    handler = Options,
                    get = "GetCurrenciesShowGoldInTooltip",
                    set = "SetCurrenciesShowGoldInTooltip",
                },
            }),
            colors = {
                type = "group",
                name = "Colors",
                order = 20,
                inline = true,
                args = {
                    customColor = {
                        type = "toggle",
                        name = "Custom Text Color",
                        desc = "Use a custom color for the base currencies datatext.",
                        order = 1,
                        handler = Options,
                        get = "GetCurrenciesUseCustomColor",
                        set = "SetCurrenciesUseCustomColor",
                    },
                    flashOnUpdate = {
                        type = "toggle",
                        name = "Flash on Update",
                        desc = "Play a short highlight pulse when the displayed currency value changes.",
                        order = 2,
                        get = function()
                            return Options:GetDatatextDB("currencies").flashOnUpdate == true
                        end,
                        set = function(_, value)
                            Options:GetDatatextDB("currencies").flashOnUpdate = value == true
                        end,
                    },
                    testFlash = {
                        type = "execute",
                        name = "Test Flash",
                        desc = "Preview the currencies datatext flash on any visible panel using it.",
                        order = 3,
                        width = 1,
                        func = function()
                            TriggerDatatextFlash("TwichUI: Currencies", "currencies")
                        end,
                    },
                    textColor = {
                        type = "color",
                        name = "Text Color",
                        desc = "Color of the base currencies datatext.",
                        order = 4,
                        hasAlpha = true,
                        disabled = function()
                            return not Options:GetCurrenciesUseCustomColor()
                        end,
                        handler = Options,
                        get = "GetCurrenciesTextColor",
                        set = "SetCurrenciesTextColor",
                    },
                },
            },
            tooltipCurrencies = W.IGroup(30, "Tooltip Currencies", tooltipArgs),
            customDatatexts = W.IGroup(40, "Custom Currency Texts", customArgs),
        },
    }
end

local function BuildStandaloneDatatextConfiguration()
    local W = ConfigurationModule.Widgets
    local sharedMedia = LibStub("LibSharedMedia-3.0", true)
    local fontValues = sharedMedia and sharedMedia:HashTable("font") or {}
    local pointValues = {
        TOPLEFT = "Top Left",
        TOP = "Top",
        TOPRIGHT = "Top Right",
        LEFT = "Left",
        CENTER = "Center",
        RIGHT = "Right",
        BOTTOMLEFT = "Bottom Left",
        BOTTOM = "Bottom",
        BOTTOMRIGHT = "Bottom Right",
    }

    local function RefreshStandalone(refreshConfig)
        Options:RefreshStandalonePanels()
        if refreshConfig then
            ConfigurationModule:Refresh()
        end
    end

    local function BuildPanelGroup(panelID, order)
        local panel = Options:GetStandalonePanel(panelID)
        local panelName = (panel and panel.name) or "Data Panel"
        local textAlignValues = {
            LEFT = "Left",
            CENTER = "Center",
            RIGHT = "Right",
        }
        local function GetCurrentPanel()
            return Options:GetStandalonePanel(panelID)
        end

        local function GetPanelValue(key, fallback)
            local current = GetCurrentPanel()
            if current and current[key] ~= nil then
                return current[key]
            end

            return fallback
        end

        local function GetResolvedPanelStyle()
            return Options:GetResolvedStandaloneStyle(panelID)
        end

        local function GetPanelStyleStore()
            local current = GetCurrentPanel()
            if not current then
                return nil
            end

            current.style = current.style or {}
            return current.style
        end

        local function IsPanelStyleDisabled()
            local current = GetCurrentPanel()
            return not (current and current.useStyleOverrides == true)
        end

        local function GetPanelStyleValue(key, fallback)
            local current = GetCurrentPanel()
            if current and current.useStyleOverrides == true and current.style and current.style[key] ~= nil then
                return current.style[key]
            end

            local resolved = GetResolvedPanelStyle()
            if resolved and resolved[key] ~= nil then
                return resolved[key]
            end

            return fallback
        end

        local function SetPanelStyleValue(key, value)
            local style = GetPanelStyleStore()
            if not style then
                return
            end

            style[key] = value
            RefreshStandalone()
        end

        local function SetPanelColorValue(colorKey, alphaKey, r, g, b, a)
            local style = GetPanelStyleStore()
            if not style then
                return
            end

            style[colorKey] = { r, g, b, 1 }
            if alphaKey then
                style[alphaKey] = a
            end
            RefreshStandalone()
        end

        return {
            type = "group",
            name = panelName,
            order = order,
            args = {
                title = W.TitleWidget(0, panelName),
                desc = W.Description(1,
                    "Data panel. Unlock panels to drag them using the slim top handle, or leave them empty to use them as styled backdrops."),
                identity = W.IGroup(10, "Identity", {
                    enabled = {
                        type = "toggle",
                        name = "Enable Panel",
                        order = 1,
                        get = function()
                            return GetPanelValue("enabled", true) ~= false
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.enabled = value == true
                            RefreshStandalone()
                        end,
                    },
                    name = {
                        type = "input",
                        name = "Panel Name",
                        order = 2,
                        width = 1.5,
                        get = function()
                            return GetPanelValue("name", "Data Panel")
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.name = value ~= "" and value or "Data Panel"
                            RefreshStandalone(true)
                        end,
                    },
                    point = {
                        type = "select",
                        name = "Anchor",
                        order = 3,
                        values = pointValues,
                        get = function()
                            return GetPanelValue("point", "BOTTOM")
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.point = value
                            current.relativePoint = value
                            RefreshStandalone()
                        end,
                    },
                }),
                size = W.IGroup(20, "Layout", {
                    segments = {
                        type = "select",
                        name = "Slots",
                        order = 1,
                        values = {
                            [1] = "One Slot",
                            [2] = "Two Slots",
                            [3] = "Three Slots",
                            [4] = "Four Slots",
                            [5] = "Five Slots",
                        },
                        sorting = { 1, 2, 3, 4, 5 },
                        get = function()
                            return GetPanelValue("segments", 3)
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.segments = tonumber(value) or 3
                            RefreshStandalone(true)
                        end,
                    },
                    width = {
                        type = "range",
                        name = "Width",
                        order = 2,
                        min = 80,
                        max = 4000,
                        step = 1,
                        get = function()
                            return GetPanelValue("width", 420)
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.width = value
                            RefreshStandalone()
                        end,
                    },
                    height = {
                        type = "range",
                        name = "Height",
                        order = 3,
                        min = 20,
                        max = 80,
                        step = 1,
                        get = function()
                            return GetPanelValue("height", 28)
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.height = value
                            RefreshStandalone()
                        end,
                    },
                    x = {
                        type = "range",
                        name = "X Offset",
                        order = 4,
                        min = -1800,
                        max = 1800,
                        step = 1,
                        get = function()
                            return GetPanelValue("x", 0)
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.x = value
                            RefreshStandalone()
                        end,
                    },
                    y = {
                        type = "range",
                        name = "Y Offset",
                        order = 5,
                        min = -1800,
                        max = 1800,
                        step = 1,
                        get = function()
                            return GetPanelValue("y", 0)
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.y = value
                            RefreshStandalone()
                        end,
                    },
                }),
                assignments = W.IGroup(30, "Assignments", {
                    slot1 = {
                        type = "select",
                        name = "Left Slot",
                        order = 1,
                        width = 1.5,
                        values = function()
                            return Options:GetStandaloneDatatextChoices()
                        end,
                        get = function()
                            return GetPanelValue("slot1", "NONE")
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.slot1 = value
                            RefreshStandalone()
                        end,
                    },
                    slot2 = {
                        type = "select",
                        name = "Middle Slot",
                        order = 2,
                        width = 1.5,
                        hidden = function()
                            return GetPanelValue("segments", 3) < 2
                        end,
                        values = function()
                            return Options:GetStandaloneDatatextChoices()
                        end,
                        get = function()
                            return GetPanelValue("slot2", "NONE")
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.slot2 = value
                            RefreshStandalone()
                        end,
                    },
                    slot3 = {
                        type = "select",
                        name = "Right Slot",
                        order = 3,
                        width = 1.5,
                        hidden = function()
                            return GetPanelValue("segments", 3) < 3
                        end,
                        values = function()
                            return Options:GetStandaloneDatatextChoices()
                        end,
                        get = function()
                            return GetPanelValue("slot3", "NONE")
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.slot3 = value
                            RefreshStandalone()
                        end,
                    },
                    slot4 = {
                        type = "select",
                        name = "Fourth Slot",
                        order = 4,
                        width = 1.5,
                        hidden = function()
                            return GetPanelValue("segments", 3) < 4
                        end,
                        values = function()
                            return Options:GetStandaloneDatatextChoices()
                        end,
                        get = function()
                            return GetPanelValue("slot4", "NONE")
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.slot4 = value
                            RefreshStandalone()
                        end,
                    },
                    slot5 = {
                        type = "select",
                        name = "Fifth Slot",
                        order = 5,
                        width = 1.5,
                        hidden = function()
                            return GetPanelValue("segments", 3) < 5
                        end,
                        values = function()
                            return Options:GetStandaloneDatatextChoices()
                        end,
                        get = function()
                            return GetPanelValue("slot5", "NONE")
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.slot5 = value
                            RefreshStandalone()
                        end,
                    },
                }),
                styleOverrides = W.IGroup(35, "Panel Style Overrides", {
                    useStyleOverrides = {
                        type = "toggle",
                        name = "Enable Per-Panel Overrides",
                        desc = "Override the shared Data Panel style for this panel only.",
                        order = 1,
                        get = function()
                            local current = GetCurrentPanel()
                            return current and current.useStyleOverrides == true or false
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end

                            current.useStyleOverrides = value == true
                            current.style = current.style or {}
                            RefreshStandalone(true)
                        end,
                    },
                    transparentTheme = {
                        type = "toggle",
                        name = "Transparent Theme",
                        desc =
                        "Hide the panel background, border, accent bar and dividers so only the text, hover underline and hover glow are visible.",
                        order = 3,
                        get = function()
                            local current = GetCurrentPanel()
                            return current and current.transparentTheme == true or false
                        end,
                        set = function(_, value)
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.transparentTheme = value == true
                            RefreshStandalone(true)
                        end,
                    },
                    resetStyleOverrides = {
                        type = "execute",
                        name = "Reset Panel Overrides",
                        order = 2,
                        disabled = function()
                            local current = GetCurrentPanel()
                            return not (current and type(current.style) == "table" and next(current.style) ~= nil)
                        end,
                        func = function()
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end

                            current.style = {}
                            current.useStyleOverrides = false
                            RefreshStandalone(true)
                        end,
                    },
                    font = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = "Font",
                        order = 10,
                        values = function()
                            return fontValues
                        end,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return GetPanelStyleValue("font", Options:GetStandaloneDB().style.font)
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("font", value)
                        end,
                    },
                    textAlign = {
                        type = "select",
                        name = "Text Alignment",
                        order = 11,
                        values = textAlignValues,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return tostring(GetPanelStyleValue("textAlign",
                                Options:GetStandaloneDB().style.textAlign or "CENTER"))
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("textAlign", value)
                        end,
                    },
                    fontSize = {
                        type = "range",
                        name = "Font Size",
                        order = 12,
                        min = 8,
                        max = 20,
                        step = 1,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return tonumber(GetPanelStyleValue("fontSize", Options:GetStandaloneDB().style.fontSize)) or
                                12
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("fontSize", value)
                        end,
                    },
                    tooltipFont = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = "Tooltip Font",
                        order = 13,
                        values = function()
                            return fontValues
                        end,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return GetPanelStyleValue("tooltipFont", Options:GetStandaloneDB().style.tooltipFont)
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("tooltipFont", value)
                        end,
                    },
                    tooltipFontSize = {
                        type = "range",
                        name = "Tooltip Font Size",
                        order = 14,
                        min = 8,
                        max = 24,
                        step = 1,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return tonumber(GetPanelStyleValue("tooltipFontSize",
                                Options:GetStandaloneDB().style.tooltipFontSize)) or 11
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("tooltipFontSize", value)
                        end,
                    },
                    menuFont = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = "Menu Font",
                        order = 15,
                        values = function()
                            return fontValues
                        end,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return GetPanelStyleValue("menuFont", Options:GetStandaloneDB().style.menuFont)
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("menuFont", value)
                        end,
                    },
                    menuFontSize = {
                        type = "range",
                        name = "Menu Font Size",
                        order = 16,
                        min = 8,
                        max = 20,
                        step = 1,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return tonumber(GetPanelStyleValue("menuFontSize",
                                Options:GetStandaloneDB().style.menuFontSize)) or 12
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("menuFontSize", value)
                        end,
                    },
                    fontOutline = {
                        type = "toggle",
                        name = "Outline Font",
                        order = 17,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return GetPanelStyleValue("fontOutline", false) == true
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("fontOutline", value == true)
                        end,
                    },
                    showDragHandle = {
                        type = "toggle",
                        name = "Show Drag Handle",
                        order = 18,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return GetPanelStyleValue("showDragHandle", true) == true
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("showDragHandle", value == true)
                        end,
                    },
                    textShadowAlpha = {
                        type = "range",
                        name = "Text Shadow",
                        order = 19,
                        min = 0,
                        max = 1,
                        step = 0.01,
                        isPercent = true,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return tonumber(GetPanelStyleValue("textShadowAlpha",
                                Options:GetStandaloneDB().style.textShadowAlpha)) or 0.85
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("textShadowAlpha", value)
                        end,
                    },
                    dividerAlpha = {
                        type = "range",
                        name = "Divider Strength",
                        order = 20,
                        min = 0,
                        max = 1,
                        step = 0.01,
                        isPercent = true,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            return tonumber(GetPanelStyleValue("dividerAlpha",
                                Options:GetStandaloneDB().style.dividerAlpha)) or 0.28
                        end,
                        set = function(_, value)
                            SetPanelStyleValue("dividerAlpha", value)
                        end,
                    },
                    backgroundColor = {
                        type = "color",
                        name = "Background Color",
                        order = 21,
                        hasAlpha = true,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            local color = GetPanelStyleValue("backgroundColor",
                                Options:GetStandaloneDB().style.backgroundColor)
                            return color[1], color[2], color[3],
                                tonumber(GetPanelStyleValue("backgroundAlpha",
                                    Options:GetStandaloneDB().style.backgroundAlpha)) or 0.94
                        end,
                        set = function(_, r, g, b, a)
                            SetPanelColorValue("backgroundColor", "backgroundAlpha", r, g, b, a)
                        end,
                    },
                    borderColor = {
                        type = "color",
                        name = "Border Color",
                        order = 22,
                        hasAlpha = true,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            local color = GetPanelStyleValue("borderColor", Options:GetStandaloneDB().style.borderColor)
                            return color[1], color[2], color[3],
                                tonumber(GetPanelStyleValue("borderAlpha", Options:GetStandaloneDB().style.borderAlpha)) or
                                0.9
                        end,
                        set = function(_, r, g, b, a)
                            SetPanelColorValue("borderColor", "borderAlpha", r, g, b, a)
                        end,
                    },
                    accentColor = {
                        type = "color",
                        name = "Accent Color",
                        order = 23,
                        hasAlpha = true,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            local color = GetPanelStyleValue("accentColor", Options:GetStandaloneDB().style.accentColor)
                            return color[1], color[2], color[3],
                                tonumber(GetPanelStyleValue("accentAlpha", Options:GetStandaloneDB().style.accentAlpha)) or
                                0.95
                        end,
                        set = function(_, r, g, b, a)
                            SetPanelColorValue("accentColor", "accentAlpha", r, g, b, a)
                        end,
                    },
                    hoverGlowColor = {
                        type = "color",
                        name = "Hover Glow Color",
                        desc = "Per-panel override for the hover glow color.",
                        order = 24,
                        hasAlpha = true,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            local sharedStyle = Options:GetStandaloneDB().style
                            local fallback = sharedStyle.hoverGlowColor or sharedStyle.accentColor
                            local fallbackAlpha = sharedStyle.hoverGlowAlpha or 0.09
                            local color = GetPanelStyleValue("hoverGlowColor", fallback)
                            return color[1], color[2], color[3],
                                tonumber(GetPanelStyleValue("hoverGlowAlpha", fallbackAlpha)) or 0.09
                        end,
                        set = function(_, r, g, b, a)
                            SetPanelColorValue("hoverGlowColor", "hoverGlowAlpha", r, g, b, a)
                        end,
                    },
                    hoverBarColor = {
                        type = "color",
                        name = "Hover Underline Color",
                        desc = "Per-panel override for the hover underline bar color.",
                        order = 25,
                        hasAlpha = true,
                        disabled = IsPanelStyleDisabled,
                        get = function()
                            local sharedStyle = Options:GetStandaloneDB().style
                            local fallback = sharedStyle.hoverBarColor or sharedStyle.accentColor
                            local fallbackAlpha = sharedStyle.hoverBarAlpha or 0.92
                            local color = GetPanelStyleValue("hoverBarColor", fallback)
                            return color[1], color[2], color[3],
                                tonumber(GetPanelStyleValue("hoverBarAlpha", fallbackAlpha)) or 0.92
                        end,
                        set = function(_, r, g, b, a)
                            SetPanelColorValue("hoverBarColor", "hoverBarAlpha", r, g, b, a)
                        end,
                    },
                }),
                actions = W.IGroup(40, "Actions", {
                    center = {
                        type = "execute",
                        name = "Center Panel",
                        order = 1,
                        func = function()
                            local current = GetCurrentPanel()
                            if not current then
                                return
                            end
                            current.point = "CENTER"
                            current.relativePoint = "CENTER"
                            current.x = 0
                            current.y = 0
                            RefreshStandalone()
                        end,
                    },
                    resetOverrides = {
                        type = "execute",
                        name = "Clear Style Overrides",
                        desc = "Remove all per-panel color and style overrides, reverting to the shared style.",
                        order = 2,
                        func = function()
                            Options:ResetPanelStyleOverrides(panelID)
                            local standaloneUI = ConfigurationModule.StandaloneUI
                            if standaloneUI and standaloneUI.RequestRenderCurrentPage then
                                standaloneUI:RequestRenderCurrentPage()
                            end
                        end,
                    },
                    remove = {
                        type = "execute",
                        name = "Remove Panel",
                        order = 3,
                        disabled = function()
                            return #Options:GetStandalonePanelIDs() <= 1
                        end,
                        func = function()
                            local standaloneUI = ConfigurationModule.StandaloneUI
                            if standaloneUI and standaloneUI.currentPageId == "datatexts" then
                                if standaloneUI.InvalidateTabSelection then
                                    standaloneUI:InvalidateTabSelection({ "DataTexts", "panels" })
                                end
                                standaloneUI.selectedTabs = standaloneUI.selectedTabs or {}
                                standaloneUI.selectedTabs["DataTexts.panels"] = "general"
                                standaloneUI.currentPath = { "DataTexts", "panels", "general" }
                            end
                            Options:DeleteStandalonePanel(panelID)
                        end,
                    },
                }),
            },
        }
    end

    local standaloneGroup = {
        type = "group",
        name = "Panels",
        order = 15,
        childGroups = "select",
        args = {
            general = {
                type = "group",
                name = "General",
                order = 1,
                args = {
                    title = W.TitleWidget(0, "Panels"),
                    desc = W.Description(1,
                        "Build data panels that can host datatexts, act as premium backdrops, or do both."),
                    switches = W.IGroup(10, "Behavior", {
                        enabled = {
                            type = "toggle",
                            name = "Enable Panels",
                            order = 1,
                            get = function()
                                return Options:GetStandaloneDB().enabled == true
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().enabled = value == true
                                RefreshStandalone()
                            end,
                        },
                        locked = {
                            type = "toggle",
                            name = "Lock Panels",
                            desc = "When disabled, drag panels by the slim top handle.",
                            order = 2,
                            get = function()
                                return Options:GetStandaloneDB().locked ~= false
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().locked = value == true
                                RefreshStandalone()
                            end,
                        },
                        addPanel = {
                            type = "execute",
                            name = "Add Panel",
                            order = 3,
                            disabled = function()
                                return #Options:GetStandalonePanelIDs() >= 8
                            end,
                            func = function()
                                local panelID = Options:CreateStandalonePanel()
                                local standaloneUI = ConfigurationModule.StandaloneUI
                                if panelID and standaloneUI and standaloneUI.currentPageId == "datatexts" then
                                    standaloneUI.selectedTabs = standaloneUI.selectedTabs or {}
                                    standaloneUI.selectedTabs["DataTexts.panels"] = panelID
                                    standaloneUI.currentPath = { "DataTexts", "panels", panelID }
                                    if standaloneUI.RequestRenderCurrentPage then
                                        standaloneUI:RequestRenderCurrentPage()
                                    end
                                end
                            end,
                        },
                        refresh = {
                            type = "execute",
                            name = "Refresh Panels",
                            order = 4,
                            func = function()
                                RefreshStandalone()
                            end,
                        },
                    }),
                    style = W.IGroup(20, "Shared Style", {
                        textAlign = {
                            type = "select",
                            name = "Text Alignment",
                            order = 1,
                            values = {
                                LEFT = "Left",
                                CENTER = "Center",
                                RIGHT = "Right",
                            },
                            get = function()
                                return tostring(Options:GetStandaloneDB().style.textAlign or "CENTER")
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().style.textAlign = value
                                RefreshStandalone()
                            end,
                        },
                        font = {
                            type = "select",
                            dialogControl = "LSM30_Font",
                            name = "Font",
                            order = 2,
                            values = function()
                                return fontValues
                            end,
                            get = function()
                                return Options:GetStandaloneDB().style.font
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().style.font = value
                                RefreshStandalone()
                            end,
                        },
                        fontSize = {
                            type = "range",
                            name = "Font Size",
                            order = 3,
                            min = 8,
                            max = 20,
                            step = 1,
                            get = function()
                                return Options:GetStandaloneDB().style.fontSize
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().style.fontSize = value
                                RefreshStandalone()
                            end,
                        },
                        tooltipFont = {
                            type = "select",
                            dialogControl = "LSM30_Font",
                            name = "Tooltip Font",
                            order = 4,
                            values = function()
                                return fontValues
                            end,
                            handler = Options,
                            get = "GetSharedTooltipFont",
                            set = "SetSharedTooltipFont",
                        },
                        tooltipFontSize = {
                            type = "range",
                            name = "Tooltip Font Size",
                            order = 5,
                            min = 8,
                            max = 24,
                            step = 1,
                            handler = Options,
                            get = "GetSharedTooltipFontSize",
                            set = "SetSharedTooltipFontSize",
                        },
                        menuFont = {
                            type = "select",
                            dialogControl = "LSM30_Font",
                            name = "Menu Font",
                            order = 6,
                            values = function()
                                return fontValues
                            end,
                            get = function()
                                return Options:GetStandaloneDB().style.menuFont
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().style.menuFont = value
                                RefreshStandalone()
                            end,
                        },
                        menuFontSize = {
                            type = "range",
                            name = "Menu Font Size",
                            order = 7,
                            min = 8,
                            max = 20,
                            step = 1,
                            get = function()
                                return Options:GetStandaloneDB().style.menuFontSize
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().style.menuFontSize = value
                                RefreshStandalone()
                            end,
                        },
                        fontOutline = {
                            type = "toggle",
                            name = "Outline Font",
                            order = 8,
                            get = function()
                                return Options:GetStandaloneDB().style.fontOutline == true
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().style.fontOutline = value == true
                                RefreshStandalone()
                            end,
                        },
                        showDragHandle = {
                            type = "toggle",
                            name = "Show Drag Handle",
                            order = 9,
                            get = function()
                                return Options:GetStandaloneDB().style.showDragHandle == true
                            end,
                            set = function(_, value)
                                Options:GetStandaloneDB().style.showDragHandle = value == true
                                RefreshStandalone()
                            end,
                        },
                        backgroundColor = {
                            type = "color",
                            name = "Background Color",
                            order = 9,
                            hasAlpha = true,
                            get = function()
                                local resolved = Options:GetResolvedStandaloneStyle()
                                local color = resolved.backgroundColor or { 0.05, 0.06, 0.08 }
                                return color[1], color[2], color[3], resolved.backgroundAlpha or 0.94
                            end,
                            set = function(_, r, g, b, a)
                                local style = Options:GetStandaloneDB().style
                                style.backgroundColor = { r, g, b, 1 }
                                style.backgroundAlpha = a
                                RefreshStandalone()
                            end,
                        },
                        borderColor = {
                            type = "color",
                            name = "Border Color",
                            order = 10,
                            hasAlpha = true,
                            get = function()
                                local resolved = Options:GetResolvedStandaloneStyle()
                                local color = resolved.borderColor or { 0.24, 0.26, 0.32 }
                                return color[1], color[2], color[3], resolved.borderAlpha or 0.9
                            end,
                            set = function(_, r, g, b, a)
                                local style = Options:GetStandaloneDB().style
                                style.borderColor = { r, g, b, 1 }
                                style.borderAlpha = a
                                RefreshStandalone()
                            end,
                        },
                        accentColor = {
                            type = "color",
                            name = "Accent Color",
                            order = 11,
                            hasAlpha = true,
                            get = function()
                                local resolved = Options:GetResolvedStandaloneStyle()
                                local color = resolved.accentColor or { 0.96, 0.76, 0.24 }
                                return color[1], color[2], color[3], resolved.accentAlpha or 0.95
                            end,
                            set = function(_, r, g, b, a)
                                local style = Options:GetStandaloneDB().style
                                style.accentColor = { r, g, b, 1 }
                                style.accentAlpha = a
                                RefreshStandalone()
                            end,
                        },
                        hoverGlowColor = {
                            type = "color",
                            name = "Hover Glow Color",
                            desc = "Color of the full-slot glow when hovering a datatext slot.",
                            order = 12,
                            hasAlpha = true,
                            handler = Options,
                            get = "GetSharedHoverGlowColor",
                            set = "SetSharedHoverGlowColor",
                        },
                        hoverBarColor = {
                            type = "color",
                            name = "Hover Underline Color",
                            desc = "Color of the bottom underline bar when hovering a datatext slot.",
                            order = 13,
                            hasAlpha = true,
                            handler = Options,
                            get = "GetSharedHoverBarColor",
                            set = "SetSharedHoverBarColor",
                        },
                        resetStyle = {
                            type = "execute",
                            name = "Reset to Theme Defaults",
                            desc =
                            "Restore all shared style values (colors, fonts, alphas) to the current Theme settings.",
                            order = 99,
                            func = function()
                                Options:ResetSharedStyle()
                                local standaloneUI = ConfigurationModule.StandaloneUI
                                if standaloneUI and standaloneUI.RequestRenderCurrentPage then
                                    standaloneUI:RequestRenderCurrentPage()
                                end
                            end,
                        },
                    }),
                },
            },
        },
    }

    for index, panelID in ipairs(Options:GetStandalonePanelIDs()) do
        standaloneGroup.args[panelID] = BuildPanelGroup(panelID, 10 + index)
    end

    return standaloneGroup
end

local function BuildDatatextConfiguration()
    local AW = ConfigurationModule.Widgets
    local function TooltipForMountSpell(spellID)
        return function(row)
            if not _G.GameTooltip or not _G.GameTooltip.SetOwner then return end
            _G.GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            if _G.GameTooltip.SetMountBySpellID then
                _G.GameTooltip:SetMountBySpellID(spellID)
            elseif _G.GameTooltip.SetSpellByID then
                _G.GameTooltip:SetSpellByID(spellID)
            end
            _G.GameTooltip:Show()
        end
    end
    local function BuildMountCandidates(type)
        local collectedMounts = {}
        table.insert(collectedMounts, {
            value = 0,
            name = "None",
            icon = nil,
            search = "none",
        })

        ---@type MountUtilityModule
        local MountUtilityModule = T:GetModule("MountUtility")

        local mounts
        if type == "vendor" then
            mounts = MountUtilityModule:GetPlayerUtilityMountsByCapability("VENDOR")
        else
            mounts = MountUtilityModule:GetPlayerUtilityMountsByCapability("AUCTION")
        end

        for _, m in ipairs(mounts) do
            local id = tonumber(m.mountID) or 0
            if id > 0 then
                table.insert(collectedMounts, {
                    value = id,
                    name = tostring(m.name or ""),
                    icon = m.icon,
                    search = tostring(m.name or ""),
                    onEnter = TooltipForMountSpell(m.spellID),
                    onLeave = TooltipHide
                })
            end
        end

        return collectedMounts
    end

    local vendorSelector, auctionSelector
    local function OpenMountSelector(kind)
        local selector = nil
        local currentlySelected = nil
        local title = nil
        local current = 0

        if kind == "vendor" then
            if not vendorSelector then
                vendorSelector = T.Tools.UI.CreateSearchSelector("TwichUIVendorMountSelector", { hint = "Search mounts" }) or
                    nil
            end
            selector = vendorSelector
            title = "Select Vendor Mount"
            currentlySelected = Options:GetVendorMount()
        elseif kind == "auction" then
            if not auctionSelector then
                auctionSelector = T.Tools.UI.CreateSearchSelector("TwichUIAuctionMountSelector",
                    { hint = "Search mounts" }) or nil
            end
            selector = auctionSelector
            title = "Select Auction Mount"
            currentlySelected = Options:GetAuctionMount()
        end

        if not selector then
            return
        end

        current = currentlySelected or 0

        local E = _G.ElvUI and _G.ElvUI[1]
        local optionsFrame = (E and (E.OptionsUI or E.OptionsFrame)) or _G.UIParent
        selector:Open({
            title = title,
            candidates = BuildMountCandidates(kind),
            selectedValue = current,
            relativeTo = optionsFrame,
            onSelect = function(value)
                if kind == "vendor" then
                    Options:SetVendorMount(nil, tonumber(value) or 0)
                else
                    Options:SetAuctionMount(nil, tonumber(value) or 0)
                end
                ConfigurationModule:Refresh()
            end,
        })
    end

    local datatextsTab = AW.NewConfigurationSection(10, "Data Panels")
    datatextsTab.childGroups = "tree"
    local customizeTexts = {
        type = "group",
        name = "Customize Texts",
        order = 30,
        childGroups = "tree",
        args = {
            title = AW.TitleWidget(0, "Customize Texts"),
            desc = AW.Description(1,
                "Tune the content, colors, tooltip behavior, and shortcuts for each datatext."),
            time = BuildTimeConfiguration(),
            system = BuildSystemConfiguration(),
            mail = BuildMailConfiguration(),
            friends = BuildFriendsConfiguration(),
            durability = BuildDurabilityConfiguration(),
            specialization = BuildSpecializationConfiguration(),
            currencies = BuildCurrenciesConfiguration(),
            mounts = {
                type = "group",
                name = "Mounts",
                order = 20,
                args = {
                    title = AW.TitleWidget(0, "Mounts"),
                    desc = AW.Description(1, "Provides a datatext for quick access to favorite and utility mounts."),
                    helper1 = AW.Description(2,
                        T.Tools.Text.Color(T.Tools.Colors.GRAY,
                            "Set favorite mounts in the Blizzard Mount Journal. Utility mounts are discovered automatically and added to the menu.")),
                    color = AW.IGroup(10, "Colors", {
                        customColor = {
                            type = "toggle",
                            name = "Custom Text Color",
                            desc = "Use a custom color for the text.",
                            handler = Options,
                            get = "GetMountUseCustomColor",
                            set = "SetMountUseCustomColor",
                            order = 1,
                        },
                        textColor = {
                            type = "color",
                            name = "Text Color",
                            desc = "Color of the text.",
                            order = 2,
                            disabled = function()
                                return not Options:GetDatatextDB("mounts").customColor
                            end,
                            hasAlpha = true,
                            handler = Options,
                            get = "GetMountTextColor",
                            set = "SetMountTextColor",
                        }
                    }),
                    menuOptions = AW.IGroup(20, "Menu Options", {
                        showUtilityMounts = {
                            type = "toggle",
                            name = "Show Utility Mounts",
                            desc = "Show utility mounts (Auction House, Vendor, and similar) in the menu.",
                            order = 1,
                            handler = Options,
                            get = "GetShowUtilityMounts",
                            set = "SetShowUtilityMounts",
                        },
                        showFavoriteMounts = {
                            type = "toggle",
                            name = "Show Favorite Mounts",
                            desc = "Show favorite mounts in the menu.",
                            order = 2,
                            handler = Options,
                            get = "GetShowFavoriteMounts",
                            set = "SetShowFavoriteMounts",
                        }
                    }),
                    vendorMountShortcut = AW.IGroup(40, "Vendor Mount Shortcut", {
                        enable = {
                            type = "toggle",
                            name = "Enable Shortcut",
                            desc = "Right-clicking on the datatext will summon your vendor mount.",
                            order = 1,
                            handler = Options,
                            get = "IsVendorMountShortcutEnabled",
                            set = "SetVendorMountShortcutEnabled",
                        },
                        vendorMount = {
                            type = "execute",
                            disabled = function()
                                return not Options:IsVendorMountShortcutEnabled()
                            end,
                            width = 1.5,
                            name = function()
                                local currentlySelected = Options:GetVendorMount() or 0
                                local MountUtilityModule = T:GetModule("MountUtility")
                                return tostring(MountUtilityModule:GetMountLabelByID(currentlySelected))
                            end,
                            desc = "Summoned when the datatext is right-clicked.",
                            order = 2,
                            func = function()
                                OpenMountSelector("vendor")
                            end,
                        }

                    }),
                    auctionMountShortcut = AW.IGroup(30, "Auction Mount Shortcut", {
                        enable = {
                            type = "toggle",
                            name = "Enable Shortcut",
                            desc = "Shift+Right-clicking on the datatext will summon your auction mount.",
                            order = 1,
                            handler = Options,
                            get = "IsAuctionMountShortcutEnabled",
                            set = "SetAuctionMountShortcutEnabled",
                        },
                        auctionMount = {
                            type = "execute",
                            disabled = function()
                                return not Options:IsAuctionMountShortcutEnabled()
                            end,
                            width = 1.5,
                            name = function()
                                local currentlySelected = Options:GetAuctionMount() or 0
                                local MountUtilityModule = T:GetModule("MountUtility")
                                return tostring(MountUtilityModule:GetMountLabelByID(currentlySelected))
                            end,
                            desc = "Summoned when the datatext is Shift+right-clicked.",
                            order = 2,
                            func = function()
                                OpenMountSelector("auction")
                            end,
                        }
                    }),
                }
            },
            gathering = BuildGatheringConfiguration(),
            chores = BuildChoresConfiguration(),
            portals = BuildPortalsConfiguration(),
            mythicPlus = BuildMythicPlusConfiguration(),
            goldGoblin = BuildGoldGoblinConfiguration(),
        },
    }
    datatextsTab.args = {
        title = AW.TitleWidget(0, "Data Panels"),
        desc = AW.Description(1, "Build data panels and customize the texts they host."),
        enable = {
            type = "toggle",
            name = "Enable",
            desc = "Enable data panels and the datatext system.",
            order = 3,
            width = "half",
            handler = Options,
            get = "IsModuleEnabled",
            set = "SetModuleEnabled",
        },
        panels = BuildStandaloneDatatextConfiguration(),
        customizeTexts = customizeTexts,

    }
    return datatextsTab
end

ConfigurationModule:RegisterConfigurationFunction("DataTexts", BuildDatatextConfiguration)
