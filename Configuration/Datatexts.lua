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

local function BuildGoldGoblinConfiguration()
    local W = ConfigurationModule.Widgets
    local goldGoblin = {
        type = "group",
        name = "Gold Goblin",
        order = 20,
        args = {
            title = W.TitleWidget(0, "Gold Goblin"),
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
                }
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
                " Additional functionality such as dungeon teleports will be added at a later time."),
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
                textColor = {
                    type = "color",
                    name = "Text Color",
                    desc = "Color of the text.",
                    order = 2,
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
                            return T.Tools.Text.Icon(icon) .. " " .. label
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
                textColor = {
                    type = "color",
                    name = "Text Color",
                    desc = "Color of the Mythic+ datatext.",
                    order = 2,
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

    local datatextsTab = AW.NewConfigurationSection(10, "DataTexts")
    datatextsTab.childGroups = "tree"
    datatextsTab.args = {
        title = AW.TitleWidget(0, "DataTexts"),
        desc = AW.Description(1, "Provides additional DataTexts for use in ElvUI."),
        enable = {
            type = "toggle",
            name = "Enable",
            desc = "Enable additional DataTexts.",
            order = 3,
            width = "half",
            handler = Options,
            get = "IsModuleEnabled",
            set = "SetModuleEnabled",
        },
        mounts = {
            type = "group",
            name = "Mounts",
            order = 20,
            args = {
                title = AW.TitleWidget(0, "Mounts"),
                desc = AW.Description(1, "Provides a DataText for quick access to favorite and utility mounts."),
                helper1 = AW.Description(2,
                    T.Tools.Text.Color(T.Tools.Colors.GRAY,
                        "To set your favorite mounts, do so in the Blizzard Mount Journal. Utility mounts will automatically be found and provided in the DataText menu.")),
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
                        desc = "Show utility mounts (Auction House, Vendor, etc.) in the menu.",
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
                            --- @type MountUtilityModule
                            local MountUtilityModule = T:GetModule("MountUtility")
                            return tostring(MountUtilityModule:GetMountLabelByID(currentlySelected))
                        end,
                        desc = "Summoned when the datatext is Right-clicked.",
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
                            --- @type MountUtilityModule
                            local MountUtilityModule = T:GetModule("MountUtility")
                            return tostring(MountUtilityModule:GetMountLabelByID(currentlySelected))
                        end,
                        desc = "Summoned when the datatext is Shift+Right-clicked.",
                        order = 2,
                        func = function()
                            OpenMountSelector("auction")
                        end,
                    }
                }),
            }
        },
        portals = BuildPortalsConfiguration(),
        mythicPlus = BuildMythicPlusConfiguration(),
        goldGoblin = BuildGoldGoblinConfiguration(),

    }
    return datatextsTab
end

ConfigurationModule:RegisterConfigurationFunction("DataTexts", BuildDatatextConfiguration)
