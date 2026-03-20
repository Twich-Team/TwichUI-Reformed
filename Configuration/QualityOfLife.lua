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

local function BuildGossipHotkeysTab()
    local tab = {
        type = "group",
        name = "Gossip Hotkeys",
        order = 1,
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
        order = 10,
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

local function BuildQuestLogCleanerTab()
    ---@type QuestTools
    local QT = T.Tools.Quest

    local tab = {
        type = "group",
        name = "Quest Log Cleaner",
        order = 10,
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
        order = 5,
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

local function BuildConfiguration()
    local optionsTab = ConfigurationModule.Widgets.NewConfigurationSection(35, "Quality of Life")

    optionsTab.args = {
        tile = ConfigurationModule.Widgets.TitleWidget(0, "Quality of Life"),
        desc = {
            type = "description",
            order = 1,
            name = "Features to improve your overall user experience.",
        },
        questAutomationTab = BuildQuestAutomationTab(),
        questLogCleanerTab = BuildQuestLogCleanerTab(),
        gossipHotkeysTab = BuildGossipHotkeysTab(),
        satchelWatchTab = BuildSatchelWatchTab(),
    }

    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("Quality of Life", BuildConfiguration)
