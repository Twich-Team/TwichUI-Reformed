--[[
    Configuration for chat enhancements.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@type QuestAutomationConfigurationOptions
local QAOptions = ConfigurationModule.Options.QuestAutomation

---@type QuestLogCleanerConfigurationOptions
local QLCOptions = ConfigurationModule.Options.QuestLogCleaner

---@type GossipHotkeysConfigurationOptions
local GHCOptions = ConfigurationModule.Options.GossipHotkeys

---@type SatchelWatchConfigurationOptions
local SWOptions = ConfigurationModule.Options.SatchelWatch

---@type ChoresConfigurationOptions
local ChoresOptions = ConfigurationModule.Options.Chores

---@type EasyFishConfigurationOptions
local EasyFishOptions = ConfigurationModule.Options.EasyFish

local function BuildGossipHotkeysTab()
    local tab = {
        type = "group",
        name = "Gossip Hotkeys",
        order = 3,
        args = {
            desc = {
                type = "description",
                order = 1,
                name =
                "Apply hotkeys to NPC gossip for fast and easy interactions. When enabled, keys 1-9 will correspond to the first nine gossip options.",
            },
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Apply hotkeys to NPC gossip for fast and easy interactions.",
                order = 2,
                handler = GHCOptions,
                get = "IsModuleEnabled",
                set = "SetModuleEnabled",
            },
        }
    }
    return tab
end

local function BuildSatchelWatchTab()
    local W = ConfigurationModule.Widgets
    local pveFrameLoadUI = _G.PVEFrame_LoadUI
    local legacyLoadAddOn = _G.LoadAddOn

    if type(pveFrameLoadUI) == "function" then
        pveFrameLoadUI()
    end

    if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
        if type(C_AddOns.IsAddOnLoaded) == "function" then
            if not C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
                C_AddOns.LoadAddOn("Blizzard_GroupFinder")
            end
            if not C_AddOns.IsAddOnLoaded("Blizzard_PVE") then
                C_AddOns.LoadAddOn("Blizzard_PVE")
            end
        else
            C_AddOns.LoadAddOn("Blizzard_GroupFinder")
            C_AddOns.LoadAddOn("Blizzard_PVE")
        end
    elseif type(legacyLoadAddOn) == "function" then
        legacyLoadAddOn("Blizzard_GroupFinder")
        legacyLoadAddOn("Blizzard_PVE")
    end

    local currentExpansionLevel = type(GetAccountExpansionLevel) == "function" and GetAccountExpansionLevel() or nil

    local tab = {
        type = "group",
        name = "Satchel Watch",
        order = 6,
        args = {
            desc = {
                type = "description",
                order = 1,
                name = "Watches LFG for satchels for your configured role, and notifies you when one is available.",
            },
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Watches LFG for satchels for your configured role, and notifies you when one is available.",
                order = 2,
                handler = SWOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            rolesGroup = W.IGroup(10, "Roles", {
                desc = W.Description(1, "Select the roles for which you wish to be notified of satchel availability."),
                tank = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format("UI-LFG-RoleIcon-Tank") .. "Tank",
                    desc = "Notify for Tank satchels.",
                    order = 3,
                    width = 1.5,
                    handler = SWOptions,
                    get = "GetNotifyForTanks",
                    set = "SetNotifyForTanks",
                },
                healer = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format("UI-LFG-RoleIcon-Healer") .. "Healer",
                    desc = "Notify for Healer satchels.",
                    order = 4,
                    width = 1.5,
                    handler = SWOptions,
                    get = "GetNotifyForHealers",
                    set = "SetNotifyForHealers",
                },
                dps = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format("UI-LFG-RoleIcon-DPS") .. "DPS",
                    desc = "Notify for DPS satchels.",
                    order = 5,
                    width = 1.5,
                    handler = SWOptions,
                    get = "GetNotifyForDPS",
                    set = "SetNotifyForDPS",
                },
            }),
            groupType = W.IGroup(
                20, "Group Type", {
                    desc = W.Description(1,
                        "Select the group types for which you wish to be notified of satchel availability."),
                    regular = {
                        type = "toggle",
                        name = "Normal Dungeon",
                        desc = "Monitor normal random dungeons for satchels.",
                        order = 2,
                        width = 1.5,
                        handler = SWOptions,
                        get = "GetNotifyForRegularDungeon",
                        set = "SetNotifyForRegularDungeon",
                    },
                    heroic = {
                        type = "toggle",
                        name = "Heroic Dungeon",
                        desc = "Monitor heroic random dungeons for satchels.",
                        order = 3,
                        width = 1.5,
                        handler = SWOptions,
                        get = "GetNotifyForHeroicDungeon",
                        set = "SetNotifyForHeroicDungeon",
                    },
                    onlyForRaids = {
                        type = "toggle",
                        name = "Raids",
                        desc = "Monitor raids for satchels.",
                        order = 4,
                        width = 1.5,
                        handler = SWOptions,
                        get = "GetNotifyOnlyForRaids",
                        set = "SetNotifyOnlyForRaids",
                    },
                }
            ),
            rulesGroup = W.IGroup(30, "Rules", {
                desc = W.Description(1, "Configure additional rules for when a notification is provided."),
                notInGroup = {
                    type = "toggle",
                    name = "Not in Group",
                    desc = "Only provide notifications when you are not currently in a group.",
                    order = 1,
                    width = 1.5,
                    handler = SWOptions,
                    get = "GetNotifyOnlyWhenNotInGroup",
                    set = "SetNotifyOnlyWhenNotInGroup",
                },
                notCompleted = {
                    type = "toggle",
                    name = "Not Completed",
                    desc =
                    "Only monitor activities you have not fully completed for the current lockout. For raid wings, this skips wings you have already cleared that week.",
                    order = 2,
                    width = 1.5,
                    handler = SWOptions,
                    get = "GetNotifyOnlyWhenNotCompleted",
                    set = "SetNotifyOnlyWhenNotCompleted",
                },
                resetIgnored = {
                    type = "execute",
                    name = "Reset Ignored Entries",
                    desc = "Resume monitoring any dungeons you previously ignored from a SatchelWatch notification.",
                    order = 3,
                    width = 1.5,
                    handler = SWOptions,
                    func = "ResetIgnoredEntries",
                }
            }),
            soundGroup = W.IGroup(40, "Sound", {
                displayDuration = {
                    type = "range",
                    name = "Display Duration",
                    desc = "How long SatchelWatch notifications remain visible before dismissing automatically.",
                    order = 1,
                    min = 2,
                    max = 60,
                    step = 1,
                    width = 1.5,
                    handler = SWOptions,
                    get = "GetNotificationDisplayTime",
                    set = "SetNotificationDisplayTime",
                },
                sound = {
                    type = "select",
                    dialogControl = "LSM30_Sound",
                    name = "Notification Sound",
                    desc = "Sound to play when a satchel is available.",
                    order = 2,
                    width = 2,
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                    handler = SWOptions,
                    get = "GetSound",
                    set = "SetSound",
                },
                test = {
                    type = "execute",
                    name = "Test Notification",
                    desc = "Play a test notification with the selected sound.",
                    order = 3,
                    handler = SWOptions,
                    func = "TestNotification",
                }
            }),
            raidWingsGroup = W.IGroup(50, "Raid Wings", {
                desc = W.Description(1,
                    "Select which current-expansion raid wings to monitor for satchel availability."),
            })
        }
    }

    local raidWingArgs = tab.args.raidWingsGroup.args
    local order = 2

    if type(GetNumRFDungeons) == "function" and type(GetRFDungeonInfo) == "function" then
        for index = 1, GetNumRFDungeons() do
            local dungeonID = GetRFDungeonInfo(index)
            local name
            local expansionLevel

            if type(dungeonID) == "number" then
                name, _, _, _, _, _, _, _, expansionLevel = GetLFGDungeonInfo(dungeonID)
            end

            if dungeonID and name and (not currentExpansionLevel or expansionLevel == currentExpansionLevel) then
                raidWingArgs[tostring(dungeonID)] = {
                    type = "toggle",
                    name = name,
                    desc = ("Monitor %s for satchel availability."):format(name),
                    order = order,
                    handler = SWOptions,
                    get = "GetRaidWingEnabled",
                    set = "SetRaidWingEnabled",
                }
                order = order + 1
            end
        end
    end

    if order == 2 then
        raidWingArgs.unavailable = W.Description(2,
            "Current-expansion Raid Finder wing data is not currently available. Open the Group Finder if you need to refresh the list.")
    end

    return tab
end

local function BuildEasyFishTab()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Easy Fish",
        order = 2,
        args = {
            desc = {
                type = "description",
                order = 1,
                name =
                "Easy Fish binds a single key to cast Fishing and then reel in the bobber with the same key while temporarily muting other game sounds.",
            },
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable or disable Easy Fish.",
                order = 2,
                handler = EasyFishOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            keybinding = {
                type = "keybinding",
                name = "Fishing Keybinding",
                desc = "Set the keybind used to cast Fishing and reel in your bobber.",
                order = 3,
                handler = EasyFishOptions,
                get = "GetEasyFishKeybinding",
                set = "SetEasyFishKeybinding",
            },
            soundGroup = W.IGroup(10, "Enhanced Sounds", {
                desc = W.Description(1,
                    "While fishing, Easy Fish can mute other audio and keep the bobber easier to hear."),
                muteOtherSounds = {
                    type = "toggle",
                    name = "Mute Other Sounds",
                    desc = "Temporarily mute other game sounds while your fishing channel is active.",
                    order = 2,
                    handler = EasyFishOptions,
                    get = "GetMuteOtherSounds",
                    set = "SetMuteOtherSounds",
                },
                enhancedSoundsScale = {
                    type = "range",
                    name = "Enhanced Sounds Volume",
                    desc = "Volume used for the remaining fishing audio while enhanced sounds are active.",
                    order = 3,
                    min = 0,
                    max = 1,
                    step = 0.05,
                    isPercent = true,
                    width = 1.5,
                    disabled = function()
                        return not EasyFishOptions:GetMuteOtherSounds()
                    end,
                    handler = EasyFishOptions,
                    get = "GetEnhancedSoundsScale",
                    set = "SetEnhancedSoundsScale",
                },
            }),
        },
    }
end

local function BuildQuestLogCleanerTab()
    ---@type QuestTools
    local QT = T.Tools.Quest

    local tab = {
        type = "group",
        name = "Quest Log Cleaner",
        order = 5,
        args = {
            desc = {
                type = "description",
                order = 1,
                name = "Automatically abandon quests based on your preferences.",
            },
            execute = {
                type = "execute",
                name = "Clean Now",
                desc = "Automatically abandon quests based on your preferences.\n\n" .. T.Tools.Text.Color(
                    T.Tools.Colors.RED,
                    "NOTE: A confirmation will appear to review quests before abandoning."
                ),
                order = 2,
                func = function()
                    ---@type QuestLogCleaner
                    local QLC = T:GetModule("QualityOfLife"):GetModule("QuestLogCleaner")
                    QLC:GetQuestsToAbandon()
                    local confirmationText = QLC:BuildConfirmationText()
                    ConfigurationModule:ShowGenericConfirmationDialog(confirmationText, function()
                        QLC:Run()
                    end)
                end,
            },
            filters = ConfigurationModule.Widgets.IGroup(3, "Filters", {
                desc = {
                    type = "description",
                    order = 0,
                    name =
                    "Choose which types of quests to keep.",
                },
                dungeonQuestst = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format(QT.QuestTypes.DUNGEON.atlasIcon) .. " Dungeon",
                    desc = "Keep quests that are dungeon-related.",
                    order = 5,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepDungeonQuests",
                    set = "SetKeepDungeonQuests",
                },
                raidQuests = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format(QT.QuestTypes.RAID.atlasIcon) .. " Raid",
                    desc = "Keep quests that are raid-related.",
                    order = 6,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepRaidQuests",
                    set = "SetKeepRaidQuests",
                },
                keepCampaignQuests = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format(QT.QuestTypes.CAMPAIGN.atlasIcon) .. " Campaign",
                    desc = "Keep campaign quests.",
                    order = 2,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepCampaignQuests",
                    set = "SetKeepCampaignQuests",
                },
                keepImportantQuests = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format(QT.QuestTypes.IMPORTANT.atlasIcon) .. " Important",
                    desc = "Keep important quests.",
                    order = 3,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepImportantQuests",
                    set = "SetKeepImportantQuests",
                },
                keepMetaQuests = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format(QT.QuestTypes.META.atlasIcon) .. " Meta",
                    desc = "Keep meta quests.",
                    order = 4,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepMetaQuests",
                    set = "SetKeepMetaQuests",
                },
                keepRepeatableQuests = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format(QT.QuestTypes.REPEATABLE.atlasIcon) .. " Repeatable",
                    desc = "Keep repeatable quests.",
                    order = 5,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepRepeatableQuests",
                    set = "SetKeepRepeatableQuests",
                },
                keepDelveQuests = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format(QT.QuestTypes.DELVE.atlasIcon) .. " Delve",
                    desc = "Keep delve quests.",
                    order = 7,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepDelveQuests",
                    set = "SetKeepDelveQuests",
                },
                keepArtifactQuests = {
                    type = "toggle",
                    name = ("|A:%s:24:24|a "):format(QT.QuestTypes.ARTIFACT.atlasIcon) .. " Artifact",
                    desc = "Keep artifact quests.",
                    order = 8,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepArtifactQuests",
                    set = "SetKeepArtifactQuests",
                },
            }),
            modifiers = ConfigurationModule.Widgets.IGroup(4, "Modifiers", {
                onlyLowLevelQuests = {
                    type = "toggle",
                    name = "Near My Level",
                    desc = "Only keep quests that are within five levels of your level.",
                    order = 1,
                    width = 1.5,
                    handler = QLCOptions,
                    get = "GetKeepNearMyLevelQuests",
                    set = "SetKeepNearMyLevelQuests",
                },
            })
        }
    }

    return tab
end

local function BuildQuestAutomationTab()
    local function BuildQuestTypeToggle(order, name, atlasStr)
        local atlasIcon = ("|A:%s:24:24|a "):format(atlasStr)

        return {
            type = "toggle",
            name = atlasIcon .. name,
            desc = ("Automatically accept and turn in %s quests."):format(name),
            order = order,
            width = 1.5,
            handler = QAOptions,
            get = function()
                return QAOptions:IsQuestTypeEnabled(name)
            end,
            set = function(_, value)
                QAOptions:SetQuestTypeEnabled(name, value)
            end,
        }
    end

    local tab = {
        type = "group",
        name = "Quest Automation",
        order = 4,
        args = {
            desc = {
                type = "description",
                order = 1,
                name = "Automatically accept and turn in quests based on your preferences.",
            },
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Automatically accept and turn in quests based on your preferences.",
                order = 2,
                handler = QAOptions,
                get = "IsModuleEnabled",
                set = "SetModuleEnabled",
            },
            functionGroup = ConfigurationModule.Widgets.IGroup(3, "Functions", {
                autoAccept = {
                    type = "toggle",
                    name = "Accept Quests",
                    desc = "Automatically accept quests when interacting with NPCs.",
                    order = 1,
                    width = 1.5,
                    handler = QAOptions,
                    get = "GetAutomaticAccept",
                    set = "SetAutomaticAccept",
                },
                autoTurnIn = {
                    type = "toggle",
                    name = "Turn In Quests",
                    desc = "Automatically turn in quests when interacting with NPCs.",
                    order = 2,
                    width = 1.5,
                    handler = QAOptions,
                    get = "GetAutomaticTurnIn",
                    set = "SetAutomaticTurnIn",
                },
                acceptRewards = {
                    type = "toggle",
                    name = "Accept Rewards",
                    desc = "Automatically accept quest rewards when turning in quests.\n\n" ..
                        T.Tools.Text.Color(T.Tools.Colors.RED,
                            "NOTE: This will automatically choose the quest reward with the highest vendor value."),
                    order = 4,
                    width = 1.5,
                    handler = QAOptions,
                    get = "GetAutoCompleteWithRewards",
                    set = "SetAutoCompleteWithRewards",
                },
                modifierKeyFunction = {
                    type = "select",
                    name = "Modifier Key Function",
                    desc = "The SHIFT modifier key can be set to either temporarily enable or disable functionality.",
                    order = 5,
                    width = 1.5,
                    values = {
                        ENABLE = "Temporarily Enable",
                        DISABLE = "Temporarily Disable",
                    },
                    handler = QAOptions,
                    get = "GetModifierKeyFunction",
                    set = "SetModifierKeyFunction",
                },
            }),
            filtersGroup = {
                type = "group",
                name = "Filters",
                inline = true,
                order = 4,
                args = {
                    desc = {
                        type = "description",
                        order = 0,
                        name =
                        "Filters act as a whitelist. For example, with no filters selected, no quests will be automated. With Meta selected, Meta quests will be automated.",
                    },
                },
            },
            modifiersGroup = ConfigurationModule.Widgets.IGroup(5, "Modifiers", {
                nearMyLevelToggle = {
                    type = "toggle",
                    name = "Near My Level",
                    desc = "Only automate quests that are within five levels of you.",
                    order = 1,
                    width = 1.5,
                    handler = QAOptions,
                    get = "GetOnlyQuestsNearMyLevel",
                    set = "SetOnlyQuestsNearMyLevel",
                }
            })
        }
    }

    ---@type QuestAutomationModule
    local QAM = T:GetModule("QualityOfLife"):GetModule("QuestAutomation")
    local beginIdx = 1
    for _, info in pairs(QAM.SupportedQuestTypes) do
        local toggle = BuildQuestTypeToggle(
            beginIdx,
            info.name,
            info.atlasIcon
        )
        tab.args.filtersGroup.args[info.name:lower()] = toggle
        beginIdx = beginIdx + 1
    end

    return tab
end

local function BuildChoresTab()
    local W = ConfigurationModule.Widgets

    local pveFrameLoadUI = _G.PVEFrame_LoadUI
    local legacyLoadAddOn = _G.LoadAddOn

    local function EnsureGroupFinderLoaded()
        if type(pveFrameLoadUI) == "function" then
            pveFrameLoadUI()
        end

        if C_AddOns and type(C_AddOns.LoadAddOn) == "function" then
            if type(C_AddOns.IsAddOnLoaded) == "function" then
                if not C_AddOns.IsAddOnLoaded("Blizzard_GroupFinder") then
                    C_AddOns.LoadAddOn("Blizzard_GroupFinder")
                end
                if not C_AddOns.IsAddOnLoaded("Blizzard_PVE") then
                    C_AddOns.LoadAddOn("Blizzard_PVE")
                end
            else
                C_AddOns.LoadAddOn("Blizzard_GroupFinder")
                C_AddOns.LoadAddOn("Blizzard_PVE")
            end
        elseif type(legacyLoadAddOn) == "function" then
            legacyLoadAddOn("Blizzard_GroupFinder")
            legacyLoadAddOn("Blizzard_PVE")
        end
    end

    local function GetCurrentExpansionRaidWings()
        EnsureGroupFinderLoaded()

        local raidWings = {}
        local currentExpansionLevel = type(GetAccountExpansionLevel) == "function" and GetAccountExpansionLevel() or nil

        if type(GetNumRFDungeons) ~= "function" or type(GetRFDungeonInfo) ~= "function" then
            return raidWings
        end

        for index = 1, GetNumRFDungeons() do
            local dungeonID = GetRFDungeonInfo(index)
            local name
            local expansionLevel

            if type(dungeonID) == "number" then
                name, _, _, _, _, _, _, _, expansionLevel = GetLFGDungeonInfo(dungeonID)
            end

            if type(dungeonID) == "number" and dungeonID > 0 and name and (not currentExpansionLevel or expansionLevel == currentExpansionLevel) then
                table.insert(raidWings, {
                    dungeonID = dungeonID,
                    name = name,
                })
            end
        end

        table.sort(raidWings, function(left, right)
            return left.name < right.name
        end)

        return raidWings
    end

    local function BuildCategoryToggle(order, key, icon, name, desc, iconAtlas)
        local iconMarkup = iconAtlas and ("|A:%s:16:16|a"):format(iconAtlas) or T.Tools.Text.Icon(icon)
        return {
            type = "toggle",
            name = iconMarkup .. " " .. name,
            desc = desc,
            order = order,
            width = 1.5,
            get = function()
                return ChoresOptions:IsCategoryEnabled(key)
            end,
            set = function(_, value)
                ChoresOptions:SetCategoryEnabled(key, value)
            end,
        }
    end

    local professionArgs = {
        desc = W.Description(1,
            T.Tools.Text.Color(T.Tools.Colors.GRAY,
                "Enable or disable Midnight profession chore tracking for learned professions.")),
    }

    local professionOrder = 2
    do
        ---@type ChoresModule
        local ChoresModule = T:GetModule("Chores")
        local professionCategories = ChoresModule and ChoresModule.GetProfessionCategoryDefinitions and
            ChoresModule:GetProfessionCategoryDefinitions() or {}

        for _, professionDefinition in ipairs(professionCategories) do
            professionArgs[professionDefinition.key] = {
                type = "toggle",
                name = T.Tools.Text.Icon(professionDefinition.icon) .. " " .. professionDefinition.name,
                desc = ("Track Midnight profession chores for %s."):format(professionDefinition.name),
                order = professionOrder,
                width = 1.5,
                get = function()
                    return ChoresOptions:IsCategoryEnabled(professionDefinition.key)
                end,
                set = function(_, value)
                    ChoresOptions:SetCategoryEnabled(professionDefinition.key, value)
                end,
            }
            professionOrder = professionOrder + 1
        end
    end

    if professionOrder == 2 then
        professionArgs.unavailable = W.Description(2,
            "No learned Midnight professions were detected. Open a profession window if the list needs to refresh.")
    end

    local raidWingArgs = {
        desc = W.Description(1,
            T.Tools.Text.Color(T.Tools.Colors.GRAY,
                "Track current-expansion Raid Finder wings and count incomplete wings in the Chores datatext.")),
    }

    local raidWingOrder = 2
    for _, raidWing in ipairs(GetCurrentExpansionRaidWings()) do
        raidWingArgs[tostring(raidWing.dungeonID)] = {
            type = "toggle",
            name = ("|A:%s:16:16|a "):format("Raid") .. raidWing.name,
            desc = ("Track Raid Finder wing: %s."):format(raidWing.name),
            order = raidWingOrder,
            width = 1.5,
            get = function()
                return ChoresOptions:IsRaidWingEnabled(raidWing.dungeonID)
            end,
            set = function(_, value)
                ChoresOptions:SetRaidWingEnabled(raidWing.dungeonID, value)
            end,
        }
        raidWingOrder = raidWingOrder + 1
    end

    if raidWingOrder == 2 then
        raidWingArgs.unavailable = W.Description(2,
            "Current-expansion Raid Finder wing data is not currently available. Open the Group Finder if you need to refresh the list.")
    end

    return {
        type = "group",
        name = "Chores",
        order = 1,
        args = {
            desc = W.Description(1,
                "Track a curated set of weekly chores and expose the remaining count to the Chores DataText."),
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable weekly chore tracking.",
                order = 2,
                width = "half",
                handler = ChoresOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            showCompleted = {
                type = "toggle",
                name = "Show Completed Chores",
                desc = "Show completed chores in the Chores datatext tooltip.",
                order = 3,
                width = 1.5,
                handler = ChoresOptions,
                get = "GetShowCompleted",
                set = "SetShowCompleted",
            },
            additionalTracking = W.IGroup(5, "Additional Tracking", {
                desc = W.Description(1,
                    T.Tools.Text.Color(T.Tools.Colors.GRAY,
                        "Enable additional weekly tracking groups for the Chores tooltip and optional datatext counting.")),
                bountifulDelves = {
                    type = "toggle",
                    name = "|A:delves-bountiful:16:16|a Bountiful Delves",
                    desc = "Track current bountiful delves and show your current coffer keys in the datatext tooltip.",
                    order = 2,
                    width = 1.5,
                    handler = ChoresOptions,
                    get = "GetTrackBountifulDelves",
                    set = "SetTrackBountifulDelves",
                },
            }),
            countTowardTotal = W.IGroup(6, "Count Toward Total", {
                desc = W.Description(1,
                    T.Tools.Text.Color(T.Tools.Colors.GRAY,
                        "Choose which tracked sections contribute to the top-level Chores total. Disabled sections still appear in the tooltip.")),
                professions = {
                    type = "toggle",
                    name = "Profession Chores",
                    desc = "Count tracked profession chores toward the Chores total.",
                    order = 2,
                    width = 1.5,
                    handler = ChoresOptions,
                    get = "GetCountProfessionsTowardTotal",
                    set = "SetCountProfessionsTowardTotal",
                },
                bountifulDelves = {
                    type = "toggle",
                    name = "|A:delves-bountiful:16:16|a Bountiful Delves",
                    desc = "Count tracked bountiful delves toward the Chores total.",
                    order = 3,
                    width = 1.5,
                    handler = ChoresOptions,
                    get = "GetCountBountifulDelvesTowardTotal",
                    set = "SetCountBountifulDelvesTowardTotal",
                },
            }),
            summary = W.IGroup(10, "Tracked Chores", {
                desc = W.Description(1,
                    T.Tools.Text.Color(T.Tools.Colors.GRAY,
                        "Disable any category you do not want counted. The datatext tooltip will only show enabled chores.")),
                delves = BuildCategoryToggle(2, "delves", nil, "Delver's Call",
                    "Track the Midnight Delver's Call weekly set.", "delves-regular"),
                abundance = BuildCategoryToggle(3, "abundance", nil, "Abundance",
                    "Track the Abundant Offerings weekly chore.", "UI-EventPoi-abundancebountiful"),
                unity = BuildCategoryToggle(4, "unity", "Interface\\Icons\\Inv_nullstone_void",
                    "Unity Against the Void",
                    "Track Unity Against the Void."),
                hope = BuildCategoryToggle(5, "hope", "Interface\\Icons\\Inv_achievement_zone_harandar",
                    "Legends of the Haranir",
                    "Track Legends of the Haranir."),
                soiree = BuildCategoryToggle(6, "soiree", nil, "Saltheril's Soiree",
                    "Track Saltheril's Soiree progress.", "UI-EventPoi-saltherilssoiree"),
                stormarion = BuildCategoryToggle(7, "stormarion", nil,
                    "Stormarion Assault",
                    "Track the Stormarion Assault weekly.", "UI-EventPoi-stormarionassault"),
                specialAssignment = BuildCategoryToggle(8, "specialAssignment", nil,
                    "Special Assignment",
                    "Track the rotating Special Assignments.", "worldquest-Capstone-questmarker-epic-locked"),
                dungeon = BuildCategoryToggle(9, "dungeon", "Interface\\Icons\\achievement_dungeon_azjolkahet_dungeon",
                    "Dungeon",
                    "Track the weekly Midnight dungeon quest.", "Dungeon"),
            }),
            professionChores = W.IGroup(15, "Profession Chores", professionArgs),
            raidWings = W.IGroup(20, "Raid Finder Wings", raidWingArgs),
        },
    }
end

local function BuildConfiguration()
    local optionsTab = ConfigurationModule.Widgets.NewConfigurationSection(35, "Quality of Life")

    optionsTab.args = {
        tile = ConfigurationModule.Widgets.TitleWidget(0, "Quality of Life"),
        desc = {
            type = "description",
            order = 1,
            name = "Features to improve your overall user experience.",
        },
        choresTab = BuildChoresTab(),
        easyFishTab = BuildEasyFishTab(),
        gossipHotkeysTab = BuildGossipHotkeysTab(),
        questAutomationTab = BuildQuestAutomationTab(),
        questLogCleanerTab = BuildQuestLogCleanerTab(),
        satchelWatchTab = BuildSatchelWatchTab(),
    }

    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("Quality of Life", BuildConfiguration)
