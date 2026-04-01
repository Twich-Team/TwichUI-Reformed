--[[
    Configuration for chat enhancements.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local ConfigurationOptions = ConfigurationModule.Options --[[@as any]]
local ConfigurationModuleRuntime = ConfigurationModule --[[@as any]]

---@type TexturesTool
local Textures = T.Tools and T.Tools.Textures

---@type QuestAutomationConfigurationOptions
local QAOptions = ConfigurationModule.Options.QuestAutomation

---@type QuestLogCleanerConfigurationOptions
local QLCOptions = ConfigurationModule.Options.QuestLogCleaner

---@type GossipHotkeysConfigurationOptions
local GHCOptions = ConfigurationModule.Options.GossipHotkeys

---@type MythicPlusToolsConfigurationOptions
local MPTOptions = ConfigurationOptions.MythicPlusTools

---@type PreyTweaksConfigurationOptions
local PTOptions = ConfigurationOptions.PreyTweaks

---@type TeleportsConfigurationOptions
local TPOptions = ConfigurationOptions.Teleports

---@type WorldQuestsConfigurationOptions
local WQOptions = ConfigurationOptions.WorldQuests

---@type SatchelWatchConfigurationOptions
local SWOptions = ConfigurationOptions.SatchelWatch

---@type ChoresConfigurationOptions
local ChoresOptions = ConfigurationOptions.Chores
local PreyIcon =
"Interface\\AddOns\\TwichUI_Reformed\\Modules\\Chores\\Plumber\\Art\\ExpansionLandingPage\\Icons\\InProgressPrey.png"

---@type GatheringConfigurationOptions
local GatheringOptions = ConfigurationOptions.Gathering

---@type EasyFishConfigurationOptions
local EasyFishOptions = ConfigurationOptions.EasyFish

local function BuildIconStyleLabel(style, text)
    local icon = Textures and Textures.GetPlayerClassTextureString and Textures:GetPlayerClassTextureString(14, style)
    if icon then
        return ("%s %s"):format(icon, text)
    end

    return text
end

local function BuildGossipHotkeysTab()
    local tab = {
        type = "group",
        name = "Gossip Hotkeys",
        order = 4,
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

local function BuildMythicPlusToolsTab()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Mythic+ Tools",
        order = 3,
        args = {
            desc = {
                type = "description",
                order = 1,
                name =
                "Mythic+ quality-of-life helpers for keystones, death notifications, utility timers, and interrupts.",
            },
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable the Mythic+ Tools module.",
                order = 2,
                handler = MPTOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            debugGroup = W.IGroup(5, "Debugging", {
                desc = W.Description(1,
                    "Capture optional Mythic+ Tools debug output in the shared /tui debug console. Leave this disabled during normal play to avoid extra logging overhead."),
                enableDebug = {
                    type = "toggle",
                    name = "Enable Debug Capture",
                    desc = "Record Mythic+ Tools runtime debug lines into the shared TwichUI debug console.",
                    order = 1,
                    width = 1.75,
                    disabled = function() return not MPTOptions:GetEnabled() end,
                    handler = MPTOptions,
                    get = "GetDebugEnabled",
                    set = "SetDebugEnabled",
                },
                openDebug = {
                    type = "execute",
                    name = "Open Debug Console",
                    desc = "Open the shared TwichUI debug console focused on Mythic+ Tools.",
                    order = 2,
                    handler = MPTOptions,
                    func = "OpenDebugConsole",
                },
            }),
            keystoneHelpers = W.IGroup(10, "Keystone Helpers", {
                autoSlot = {
                    type = "toggle",
                    name = "Auto Slot Keystone",
                    desc = "Automatically slot your keystone when the receptacle opens.",
                    order = 1,
                    width = 1.5,
                    handler = MPTOptions,
                    get = "GetAutoSlotKeystoneEnabled",
                    set = "SetAutoSlotKeystoneEnabled",
                },
                autoStart = {
                    type = "toggle",
                    name = "Auto Start After Pull Timer",
                    desc =
                    "When a BigWigs or DBM pull timer starts and your keystone is already slotted, start the key when the timer finishes if you are leader or assistant.",
                    order = 2,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetAutoStartDungeonEnabled",
                    set = "SetAutoStartDungeonEnabled",
                },
            }),
            deathNotifications = W.IGroup(20, "Death Notifications", {
                enable = {
                    type = "toggle",
                    name = "Enable Death Notifications",
                    desc = "Send Mythic+ death alerts through the TwichUI notification panel.",
                    order = 1,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetDeathNotificationEnabled",
                    set = "SetDeathNotificationEnabled",
                },
                displayDuration = {
                    type = "range",
                    name = "Display Duration",
                    desc = "How long death notifications remain visible.",
                    order = 2,
                    min = 2,
                    max = 30,
                    step = 1,
                    width = 1.5,
                    handler = MPTOptions,
                    get = "GetDeathNotificationDisplayTime",
                    set = "SetDeathNotificationDisplayTime",
                },
                sound = {
                    type = "select",
                    dialogControl = "LSM30_Sound",
                    name = "Notification Sound",
                    desc = "Sound to play when a tracked party member dies in an active key.",
                    order = 3,
                    width = 2,
                    values = function()
                        local values = { __none = "None" }
                        local sounds = LibStub("LibSharedMedia-3.0"):HashTable("sound") or {}
                        for key, value in pairs(sounds) do
                            values[key] = value
                        end
                        return values
                    end,
                    handler = MPTOptions,
                    get = "GetDeathNotificationSound",
                    set = "SetDeathNotificationSound",
                },
                tank = {
                    type = "toggle",
                    name = "Tank",
                    desc = "Notify when the tank dies.",
                    order = 4,
                    width = 1.25,
                    handler = MPTOptions,
                    get = "GetNotifyForTankDeaths",
                    set = "SetNotifyForTankDeaths",
                },
                healer = {
                    type = "toggle",
                    name = "Healer",
                    desc = "Notify when the healer dies.",
                    order = 5,
                    width = 1.25,
                    handler = MPTOptions,
                    get = "GetNotifyForHealerDeaths",
                    set = "SetNotifyForHealerDeaths",
                },
                dps = {
                    type = "toggle",
                    name = "DPS",
                    desc = "Notify when a damage dealer dies.",
                    order = 6,
                    width = 1.25,
                    handler = MPTOptions,
                    get = "GetNotifyForDPSDeaths",
                    set = "SetNotifyForDPSDeaths",
                },
                self = {
                    type = "toggle",
                    name = "Self",
                    desc = "Notify when you die.",
                    order = 7,
                    width = 1.25,
                    handler = MPTOptions,
                    get = "GetNotifyForSelfDeaths",
                    set = "SetNotifyForSelfDeaths",
                },
                wipeSpam = {
                    type = "toggle",
                    name = "Suppress Wipe Spam",
                    desc =
                    "Reduce repeated death toasts during near-full wipes while still tracking the running death total.",
                    order = 8,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetSuppressWipeSpam",
                    set = "SetSuppressWipeSpam",
                },
                test = {
                    type = "execute",
                    name = "Test Death Notification",
                    desc = "Play a sample Mythic+ death notification.",
                    order = 9,
                    handler = MPTOptions,
                    func = "TestDeathNotification",
                },
            }),
            mythicPlusTimer = W.IGroup(30, "Mythic+ Timer", {
                enable = {
                    type = "toggle",
                    name = "Enable Mythic+ Timer",
                    desc = "Show the TwichUI Mythic+ timer during active keys.",
                    order = 1,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetMythicPlusTimerEnabled",
                    set = "SetMythicPlusTimerEnabled",
                },
                locked = {
                    type = "toggle",
                    name = "Lock Timer Frame",
                    desc = "Lock the Mythic+ timer in place. Disable to drag and resize it.",
                    order = 2,
                    width = 1.5,
                    handler = MPTOptions,
                    get = "GetMythicPlusTimerLocked",
                    set = "SetMythicPlusTimerLocked",
                },
                reset = {
                    type = "execute",
                    name = "Reset Timer Position",
                    desc = "Move the Mythic+ timer back to its default position.",
                    order = 3,
                    handler = MPTOptions,
                    func = "ResetMythicPlusTimerPosition",
                },
                preview = {
                    type = "execute",
                    name = "Start Timer Preview",
                    desc =
                    "Show a live-style Mythic+ timer preview with milestone bars, forces, deaths, and configured checkpoints.",
                    order = 4,
                    handler = MPTOptions,
                    func = "StartMythicPlusTimerPreview",
                },
                stopPreview = {
                    type = "execute",
                    name = "Stop Timer Preview",
                    desc = "Hide the Mythic+ timer preview.",
                    order = 5,
                    handler = MPTOptions,
                    func = "StopMythicPlusTimerPreview",
                },
                frameStyle = {
                    type = "select",
                    name = "Timer Style",
                    desc =
                    "Choose whether the Mythic+ timer uses a framed shell or a transparent data-first presentation.",
                    order = 6,
                    width = 1.6,
                    values = {
                        framed = "Framed",
                        transparent = "Transparent",
                    },
                    handler = MPTOptions,
                    get = "GetMythicPlusTimerStyle",
                    set = "SetMythicPlusTimerStyle",
                },
                scale = {
                    type = "range",
                    name = "Timer Scale",
                    desc = "Scale the Mythic+ timer frame without changing the shared tracker typography defaults.",
                    order = 7,
                    min = 0.7,
                    max = 1.5,
                    step = 0.01,
                    width = 1.6,
                    handler = MPTOptions,
                    get = "GetMythicPlusTimerScale",
                    set = "SetMythicPlusTimerScale",
                },
                bossCheckpoints = {
                    type = "toggle",
                    name = "Show Checkpoints",
                    desc =
                    "Display configured boss and custom checkpoint rows with target percentages underneath the timer bars.",
                    order = 8,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetMythicPlusTimerShowBossCheckpoints",
                    set = "SetMythicPlusTimerShowBossCheckpoints",
                },
            }),
            interrupts = W.IGroup(40, "Interrupt Tracker", {
                enable = {
                    type = "toggle",
                    name = "Enable Interrupt Tracker",
                    desc = "Show a movable interrupt tracker for your current group.",
                    order = 1,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetInterruptTrackerEnabled",
                    set = "SetInterruptTrackerEnabled",
                },
                readySound = {
                    type = "select",
                    dialogControl = "LSM30_Sound",
                    name = "Ready Sound",
                    desc = "Optional sound to play when a tracked interrupt becomes ready again.",
                    order = 2,
                    width = 2,
                    values = function()
                        local values = { __none = "None" }
                        local sounds = LibStub("LibSharedMedia-3.0"):HashTable("sound") or {}
                        for key, value in pairs(sounds) do
                            values[key] = value
                        end
                        return values
                    end,
                    handler = MPTOptions,
                    get = "GetInterruptReadySound",
                    set = "SetInterruptReadySound",
                },
                locked = {
                    type = "toggle",
                    name = "Lock Interrupt Frame",
                    desc = "Lock the interrupt tracker in place. Disable to drag it.",
                    order = 3,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetInterruptTrackerLocked",
                    set = "SetInterruptTrackerLocked",
                },
                reset = {
                    type = "execute",
                    name = "Reset Interrupt Position",
                    desc = "Move the interrupt tracker back to its default position.",
                    order = 4,
                    handler = MPTOptions,
                    func = "ResetInterruptTrackerPosition",
                },
                preview = {
                    type = "execute",
                    name = "Start Interrupt Preview",
                    desc = "Show a live-style interrupt preview with sample party members.",
                    order = 5,
                    handler = MPTOptions,
                    func = "StartInterruptPreview",
                },
                stopPreview = {
                    type = "execute",
                    name = "Stop Interrupt Preview",
                    desc = "Hide the interrupt preview.",
                    order = 6,
                    handler = MPTOptions,
                    func = "StopInterruptPreview",
                },
            }),
            appearance = W.IGroup(50, "Tracker Appearance", {
                trackerStyle = {
                    type = "select",
                    name = "Tracker Style",
                    desc = "Choose the visual style for the Interrupt Tracker frame.",
                    order = 0,
                    width = 1.6,
                    values = {
                        paneled = "Paneled (default)",
                        bare = "Bare Bars",
                    },
                    handler = MPTOptions,
                    get = "GetTrackerStyle",
                    set = "SetTrackerStyle",
                },
                trackerFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Tracker Font",
                    desc = "Font used by the interrupt tracker and timer tracker.",
                    order = 1,
                    width = 2,
                    values = function()
                        local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                        local values = {
                            __default = "Default",
                        }

                        for key, value in pairs(fonts) do
                            values[key] = value
                        end

                        return values
                    end,
                    handler = MPTOptions,
                    get = "GetTrackerFont",
                    set = "SetTrackerFont",
                },
                trackerFontSize = {
                    type = "range",
                    name = "Tracker Font Size",
                    desc = "Base font size used by the tracker rows.",
                    order = 2,
                    min = 8,
                    max = 24,
                    step = 1,
                    handler = MPTOptions,
                    get = "GetTrackerFontSize",
                    set = "SetTrackerFontSize",
                },
                trackerFontOutline = {
                    type = "select",
                    name = "Tracker Font Outline",
                    desc = "Outline style used by the tracker text.",
                    order = 3,
                    values = {
                        default = "Default",
                        none = "None",
                        outline = "Outline",
                        thick = "Thick Outline",
                    },
                    handler = MPTOptions,
                    get = "GetTrackerFontOutline",
                    set = "SetTrackerFontOutline",
                },
                trackerBarTexture = {
                    type = "select",
                    dialogControl = "LSM30_Statusbar",
                    name = "Tracker Bar Texture",
                    desc = "Status bar texture used by both Mythic+ trackers.",
                    order = 4,
                    width = 2,
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("statusbar") or {} end,
                    handler = MPTOptions,
                    get = "GetTrackerBarTexture",
                    set = "SetTrackerBarTexture",
                },
                trackerRowGap = {
                    type = "range",
                    name = "Row Gap",
                    desc = "Vertical gap between tracker rows.",
                    order = 5,
                    min = 0,
                    max = 30,
                    step = 1,
                    handler = MPTOptions,
                    get = "GetTrackerRowGap",
                    set = "SetTrackerRowGap",
                },
                trackerIconSize = {
                    type = "range",
                    name = "Icon Size",
                    desc = "Size of the tracker row icons.",
                    order = 6,
                    min = 14,
                    max = 48,
                    step = 1,
                    handler = MPTOptions,
                    get = "GetTrackerIconSize",
                    set = "SetTrackerIconSize",
                },
                trackerBarHeight = {
                    type = "range",
                    name = "Bar Height",
                    desc = "Height of the tracker status bars.",
                    order = 7,
                    min = 10,
                    max = 40,
                    step = 1,
                    handler = MPTOptions,
                    get = "GetTrackerBarHeight",
                    set = "SetTrackerBarHeight",
                },
            }),
            visibility = W.IGroup(55, "Frame Visibility", {
                frameVisibilityMode = {
                    type = "select",
                    name = "Show Frames",
                    desc = "Choose when the Mythic+ tracker frames should be visible.",
                    order = 1,
                    width = 1.6,
                    values = {
                        always = "Always",
                        combat = "In Combat",
                        group = "In Group",
                        dungeon = "In Dungeon",
                        mythicplus = "In Mythic+",
                    },
                    handler = MPTOptions,
                    get = "GetFrameVisibilityMode",
                    set = "SetFrameVisibilityMode",
                },
            }),
            interruptAppearance = W.IGroup(60, "Interrupt Colors", {
                useClassBarColor = {
                    type = "toggle",
                    name = "Use Class Color For Bars",
                    desc = "Color interrupt cooldown bars by player class instead of a static color.",
                    order = 1,
                    width = 1.8,
                    handler = MPTOptions,
                    get = "GetInterruptUseClassBarColor",
                    set = "SetInterruptUseClassBarColor",
                },
                barColor = {
                    type = "color",
                    name = "Static Bar Color",
                    desc = "Bar color used when class-colored interrupt bars are disabled.",
                    order = 2,
                    hasAlpha = false,
                    disabled = function() return MPTOptions:GetInterruptUseClassBarColor() end,
                    handler = MPTOptions,
                    get = "GetInterruptBarColor",
                    set = "SetInterruptBarColor",
                },
                readyBarColorMode = {
                    type = "select",
                    name = "Ready Bar Color",
                    desc = "Choose how ready interrupt bars are colored.",
                    order = 3,
                    width = 1.6,
                    values = {
                        default = "Default",
                        class = "Class Color",
                        static = "Static Color",
                    },
                    handler = MPTOptions,
                    get = "GetInterruptReadyBarColorMode",
                    set = "SetInterruptReadyBarColorMode",
                },
                readyBarColor = {
                    type = "color",
                    name = "Ready Static Color",
                    desc = "Color used for ready interrupt bars when Ready Bar Color is set to Static Color.",
                    order = 4,
                    hasAlpha = false,
                    disabled = function() return MPTOptions:GetInterruptReadyBarColorMode() ~= "static" end,
                    handler = MPTOptions,
                    get = "GetInterruptReadyBarColor",
                    set = "SetInterruptReadyBarColor",
                },
                useClassFontColor = {
                    type = "toggle",
                    name = "Use Class Color For Names",
                    desc = "Color interrupt tracker names by class instead of a static font color.",
                    order = 5,
                    width = 1.8,
                    handler = MPTOptions,
                    get = "GetInterruptUseClassFontColor",
                    set = "SetInterruptUseClassFontColor",
                },
                fontColor = {
                    type = "color",
                    name = "Static Name Color",
                    desc = "Font color used when class-colored interrupt names are disabled.",
                    order = 6,
                    hasAlpha = false,
                    disabled = function() return MPTOptions:GetInterruptUseClassFontColor() end,
                    handler = MPTOptions,
                    get = "GetInterruptFontColor",
                    set = "SetInterruptFontColor",
                },
            }),
            statusText = W.IGroup(70, "Status Text", {
                statusTextFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Status Font",
                    desc = "Font used for active timer and cooldown status text.",
                    order = 1,
                    width = 2,
                    values = function()
                        local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                        local values = {
                            __default = "Default",
                        }

                        for key, value in pairs(fonts) do
                            values[key] = value
                        end

                        return values
                    end,
                    handler = MPTOptions,
                    get = "GetStatusTextFont",
                    set = "SetStatusTextFont",
                },
                statusTextColor = {
                    type = "color",
                    name = "Status Text Color",
                    desc = "Color used for active timer and cooldown status text.",
                    order = 2,
                    hasAlpha = false,
                    handler = MPTOptions,
                    get = "GetStatusTextColor",
                    set = "SetStatusTextColor",
                },
                readyTextFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Ready Font",
                    desc = "Font used when a tracker row is ready.",
                    order = 3,
                    width = 2,
                    values = function()
                        local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                        local values = {
                            __default = "Default",
                        }

                        for key, value in pairs(fonts) do
                            values[key] = value
                        end

                        return values
                    end,
                    handler = MPTOptions,
                    get = "GetReadyTextFont",
                    set = "SetReadyTextFont",
                },
                readyTextColor = {
                    type = "color",
                    name = "Ready Text Color",
                    desc = "Color used when a tracker row is ready.",
                    order = 4,
                    hasAlpha = false,
                    handler = MPTOptions,
                    get = "GetReadyTextColor",
                    set = "SetReadyTextColor",
                },
                showReadyText = {
                    type = "toggle",
                    name = "Show Ready Text",
                    desc = "Display the word Ready when a row is available. Disable to leave the bar full with no label.",
                    order = 5,
                    width = 1.8,
                    handler = MPTOptions,
                    get = "GetShowReadyText",
                    set = "SetShowReadyText",
                },
            }),
        },
    }
end


local function BuildSatchelWatchTab()
    local W = ConfigurationModule.Widgets
    local pveFrameLoadUI = (_G --[[@as any]]).PVEFrame_LoadUI
    local legacyLoadAddOn = (_G --[[@as any]]).LoadAddOn

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
    local roleIconTypeValues = {
        standard = string.format("Standard (Blizzard)  |A:%s:22:22|a |A:%s:22:22|a |A:%s:22:22|a",
            "UI-LFG-RoleIcon-Tank",
            "UI-LFG-RoleIcon-Healer",
            "UI-LFG-RoleIcon-DPS"),
        twich = table.concat({
            "Twich Icons",
            "|TInterface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_Tank:19:16:0:0|t",
            "|TInterface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_Healer:21:22:0:0|t",
            "|TInterface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\Role_DPS:19:22:0:0|t",
        }, "  "),
    }

    local tab = {
        type = "group",
        name = "Satchel Watch",
        order = 7,
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
                roleIconType = {
                    type = "select",
                    name = "Role Icon Style",
                    desc = "Choose whether Satchel Watch notifications use Blizzard role icons or the TwichUI variants.",
                    order = 2,
                    width = "full",
                    values = roleIconTypeValues,
                    handler = SWOptions,
                    get = "GetRoleIconType",
                    set = "SetRoleIconType",
                },
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
                },
            }),
            periodicCheckGroup = W.IGroup(35, "Periodic Check", {
                desc = W.Description(1, T.Tools.Text.Color(T.Tools.Colors.GRAY,
                    "Periodic satchel checks are disabled by default because they repeatedly query LFG data and can generate extra background work even when Blizzard has not reported any changes.")),
                periodicCheckEnabled = {
                    type = "toggle",
                    name = "Enable Periodic Check",
                    desc =
                    "Periodically refresh satchel availability even if Blizzard does not fire an LFG update event.",
                    order = 2,
                    width = 1.75,
                    handler = SWOptions,
                    get = "GetPeriodicCheckEnabled",
                    set = "SetPeriodicCheckEnabled",
                },
                periodicCheckInterval = {
                    type = "range",
                    name = "Periodic Check Interval",
                    desc =
                    "How often Satchel Watch should refresh satchel availability when periodic checking is enabled.",
                    order = 3,
                    min = 30,
                    max = 60,
                    step = 1,
                    width = 1.5,
                    disabled = function() return not SWOptions:GetPeriodicCheckEnabled() end,
                    handler = SWOptions,
                    get = "GetPeriodicCheckInterval",
                    set = "SetPeriodicCheckInterval",
                },
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

local function BuildPreyTweaksTab()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Prey Tweaks",
        order = 7,
        args = {
            desc = {
                type = "description",
                order = 1,
                name = "Replace the Blizzard prey widget with a TwichUI-native overlay and optional prey automation.",
            },
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable Prey Tweaks.",
                order = 2,
                handler = PTOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            displayGroup = W.IGroup(10, "Display", {
                displayMode = {
                    type = "select",
                    name = "Display Style",
                    desc = "Choose how prey progress is displayed.",
                    order = 1,
                    width = 1.5,
                    values = {
                        bar = "Bar",
                        text = "Text",
                    },
                    handler = PTOptions,
                    get = "GetDisplayMode",
                    set = "SetDisplayMode",
                },
                hideBlizzardWidget = {
                    type = "toggle",
                    name = "Hide Blizzard Widget",
                    desc = "Hide the Blizzard prey widget while the TwichUI overlay is active.",
                    order = 2,
                    width = 1.5,
                    handler = PTOptions,
                    get = "GetHideBlizzardWidget",
                    set = "SetHideBlizzardWidget",
                },
                showValueText = {
                    type = "toggle",
                    name = "Show Value Text",
                    desc = "Show the prey phase percentage text on the overlay.",
                    order = 3,
                    width = 1.5,
                    handler = PTOptions,
                    get = "GetShowValueText",
                    set = "SetShowValueText",
                },
                showStageBadge = {
                    type = "toggle",
                    name = "Show Stage Label",
                    desc = "Show the current prey phase label.",
                    order = 4,
                    width = 1.5,
                    handler = PTOptions,
                    get = "GetShowStageBadge",
                    set = "SetShowStageBadge",
                },
                scale = {
                    type = "range",
                    name = "Scale",
                    desc = "Scale the prey overlay.",
                    order = 5,
                    min = 0.5,
                    max = 2,
                    step = 0.05,
                    width = 1.5,
                    handler = PTOptions,
                    get = "GetScale",
                    set = "SetScale",
                },
                barTexture = {
                    type = "select",
                    dialogControl = "LSM30_Statusbar",
                    name = "Bar Texture",
                    desc = "Status bar texture used by the Bar display style.",
                    order = 6,
                    width = 2,
                    hidden = function() return PTOptions:GetDisplayMode() ~= "bar" end,
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("statusbar") or {} end,
                    handler = PTOptions,
                    get = "GetBarTexture",
                    set = "SetBarTexture",
                },
                ringBackgroundStyle = {
                    type = "select",
                    name = "Ring Background",
                    desc = "Control how much of the static ring backing is visible behind the prey progress arc.",
                    order = 7,
                    width = 1.5,
                    hidden = function() return PTOptions:GetDisplayMode() ~= "ring" end,
                    values = {
                        full = "Full",
                        faint = "Faint",
                        none = "None",
                    },
                    handler = PTOptions,
                    get = "GetRingBackgroundStyle",
                    set = "SetRingBackgroundStyle",
                },
            }),
            positionGroup = W.IGroup(20, "Position", {
                ringOffsetX = {
                    type = "range",
                    name = "Ring Offset X",
                    desc = "Horizontal offset for the Ring display.",
                    order = 1,
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = PTOptions,
                    get = "GetRingOffsetX",
                    set = "SetRingOffsetX",
                },
                ringOffsetY = {
                    type = "range",
                    name = "Ring Offset Y",
                    desc = "Vertical offset for the Ring display.",
                    order = 2,
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = PTOptions,
                    get = "GetRingOffsetY",
                    set = "SetRingOffsetY",
                },
                barOffsetX = {
                    type = "range",
                    name = "Bar Offset X",
                    desc = "Horizontal offset for the Bar display.",
                    order = 3,
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = PTOptions,
                    get = "GetBarOffsetX",
                    set = "SetBarOffsetX",
                },
                barOffsetY = {
                    type = "range",
                    name = "Bar Offset Y",
                    desc = "Vertical offset for the Bar display.",
                    order = 4,
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = PTOptions,
                    get = "GetBarOffsetY",
                    set = "SetBarOffsetY",
                },
                textOffsetX = {
                    type = "range",
                    name = "Text Offset X",
                    desc = "Horizontal offset for the Text display.",
                    order = 5,
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = PTOptions,
                    get = "GetTextOffsetX",
                    set = "SetTextOffsetX",
                },
                textOffsetY = {
                    type = "range",
                    name = "Text Offset Y",
                    desc = "Vertical offset for the Text display.",
                    order = 6,
                    min = -200,
                    max = 200,
                    step = 1,
                    handler = PTOptions,
                    get = "GetTextOffsetY",
                    set = "SetTextOffsetY",
                },
            }),
            textStyleGroup = W.IGroup(25, "Text", {
                valueFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Value Font",
                    desc = "Font used for the prey value text.",
                    order = 1,
                    width = 2,
                    values = function()
                        local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                        local values = {
                            __default = "Default",
                        }

                        for key, value in pairs(fonts) do
                            values[key] = value
                        end

                        return values
                    end,
                    handler = PTOptions,
                    get = "GetValueFont",
                    set = "SetValueFont",
                },
                valueFontSize = {
                    type = "range",
                    name = "Value Font Size",
                    desc = "Font size used for the prey value text.",
                    order = 2,
                    min = 8,
                    max = 32,
                    step = 1,
                    handler = PTOptions,
                    get = "GetValueFontSize",
                    set = "SetValueFontSize",
                },
                valueFontOutline = {
                    type = "select",
                    name = "Value Outline",
                    desc = "Outline style used for the prey value text.",
                    order = 3,
                    values = {
                        default = "Default",
                        none = "None",
                        outline = "Outline",
                        thick = "Thick Outline",
                    },
                    handler = PTOptions,
                    get = "GetValueFontOutline",
                    set = "SetValueFontOutline",
                },
                stageFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Stage Font",
                    desc = "Font used for the prey stage label.",
                    order = 4,
                    width = 2,
                    values = function()
                        local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                        local values = {
                            __default = "Default",
                        }

                        for key, value in pairs(fonts) do
                            values[key] = value
                        end

                        return values
                    end,
                    handler = PTOptions,
                    get = "GetStageFont",
                    set = "SetStageFont",
                },
                stageFontSize = {
                    type = "range",
                    name = "Stage Font Size",
                    desc = "Font size used for the prey stage label.",
                    order = 5,
                    min = 8,
                    max = 32,
                    step = 1,
                    handler = PTOptions,
                    get = "GetStageFontSize",
                    set = "SetStageFontSize",
                },
                stageFontOutline = {
                    type = "select",
                    name = "Stage Outline",
                    desc = "Outline style used for the prey stage label.",
                    order = 6,
                    values = {
                        default = "Default",
                        none = "None",
                        outline = "Outline",
                        thick = "Thick Outline",
                    },
                    handler = PTOptions,
                    get = "GetStageFontOutline",
                    set = "SetStageFontOutline",
                },
            }),
            testGroup = W.IGroup(28, "Tests", {
                cold = {
                    type = "execute",
                    name = "Test 0%",
                    desc = "Show a cold prey ring test at 0%.",
                    order = 1,
                    handler = PTOptions,
                    func = "TestRingCold",
                },
                warm = {
                    type = "execute",
                    name = "Test 34%",
                    desc = "Show a warm prey ring test at 34%.",
                    order = 2,
                    handler = PTOptions,
                    func = "TestRingWarm",
                },
                hot = {
                    type = "execute",
                    name = "Test 67%",
                    desc = "Show a hot prey ring test at 67%.",
                    order = 3,
                    handler = PTOptions,
                    func = "TestRingHot",
                },
                final = {
                    type = "execute",
                    name = "Test 100%",
                    desc = "Show a final prey ring test at 100%.",
                    order = 4,
                    handler = PTOptions,
                    func = "TestRingFinal",
                },
                clear = {
                    type = "execute",
                    name = "Clear Test",
                    desc = "Return the prey overlay to live data.",
                    order = 5,
                    handler = PTOptions,
                    func = "ClearRingTest",
                },
            }),
            soundGroup = W.IGroup(30, "Sound", {
                playPhaseChangeSound = {
                    type = "toggle",
                    name = "Play Phase Change Sound",
                    desc = "Play a sound when prey advances to a hotter phase.",
                    order = 1,
                    width = 1.75,
                    handler = PTOptions,
                    get = "GetPlayPhaseChangeSound",
                    set = "SetPlayPhaseChangeSound",
                },
                phaseChangeSound = {
                    type = "select",
                    dialogControl = "LSM30_Sound",
                    name = "Phase Change Sound",
                    desc = "Sound to play when prey changes phase.",
                    order = 2,
                    width = 2,
                    disabled = function() return not PTOptions:GetPlayPhaseChangeSound() end,
                    values = function() return LibStub("LibSharedMedia-3.0"):HashTable("sound") or {} end,
                    handler = PTOptions,
                    get = "GetPhaseChangeSound",
                    set = "SetPhaseChangeSound",
                },
                testPhaseSound = {
                    type = "execute",
                    name = "Test Sound",
                    desc = "Play the selected prey phase sound.",
                    order = 3,
                    disabled = function() return not PTOptions:GetPlayPhaseChangeSound() end,
                    handler = PTOptions,
                    func = "TestPhaseChangeSound",
                },
            }),
            trackingGroup = W.IGroup(40, "Quest Tracking", {
                autoWatch = {
                    type = "toggle",
                    name = "Auto Watch Prey Quest",
                    desc = "Automatically watch the active prey quest.",
                    order = 1,
                    width = 1.75,
                    handler = PTOptions,
                    get = "GetAutoWatchPreyQuest",
                    set = "SetAutoWatchPreyQuest",
                },
                autoSuperTrack = {
                    type = "toggle",
                    name = "Auto Super Track Prey Quest",
                    desc = "Automatically super track the active prey quest.",
                    order = 2,
                    width = 1.75,
                    handler = PTOptions,
                    get = "GetAutoSuperTrackPreyQuest",
                    set = "SetAutoSuperTrackPreyQuest",
                },
                autoTurnIn = {
                    type = "toggle",
                    name = "Auto Turn In Prey Quest",
                    desc = "Automatically complete prey quests when the completion window opens.",
                    order = 3,
                    width = 1.75,
                    handler = PTOptions,
                    get = "GetAutoTurnInPreyQuest",
                    set = "SetAutoTurnInPreyQuest",
                },
            }),
            huntGroup = W.IGroup(50, "Hunt Automation", {
                autoPurchaseRandomHunt = {
                    type = "toggle",
                    name = "Auto Purchase Random Hunt",
                    desc = "Automatically request a random hunt from Astalor Bloodsworn when his gossip window opens.",
                    order = 1,
                    width = 1.75,
                    handler = PTOptions,
                    get = "GetAutoPurchaseRandomHunt",
                    set = "SetAutoPurchaseRandomHunt",
                },
                randomHuntDifficulty = {
                    type = "select",
                    name = "Random Hunt Difficulty",
                    desc = "Difficulty to request when auto purchasing a random hunt.",
                    order = 2,
                    width = 1.5,
                    values = {
                        normal = "Normal",
                        hard = "Hard",
                        nightmare = "Nightmare",
                    },
                    disabled = function() return not PTOptions:GetAutoPurchaseRandomHunt() end,
                    handler = PTOptions,
                    get = "GetRandomHuntDifficulty",
                    set = "SetRandomHuntDifficulty",
                },
                remnantThreshold = {
                    type = "range",
                    name = "Remnant Reserve",
                    desc = "Minimum Remnants of Anguish to keep after buying a hunt.",
                    order = 3,
                    min = 0,
                    max = 2500,
                    step = 50,
                    width = 1.5,
                    disabled = function() return not PTOptions:GetAutoPurchaseRandomHunt() end,
                    handler = PTOptions,
                    get = "GetRemnantThreshold",
                    set = "SetRemnantThreshold",
                },
                autoSelectHuntReward = {
                    type = "toggle",
                    name = "Auto Select Hunt Reward",
                    desc = "Automatically choose prey rewards using your preferred and fallback types.",
                    order = 4,
                    width = 1.75,
                    handler = PTOptions,
                    get = "GetAutoSelectHuntReward",
                    set = "SetAutoSelectHuntReward",
                },
                preferredReward = {
                    type = "select",
                    name = "Preferred Reward",
                    desc = "Preferred reward type when a prey reward choice is offered.",
                    order = 5,
                    width = 1.5,
                    values = {
                        dawncrest = "Dawncrest",
                        remnant = "Remnant",
                        gold = "Gold",
                        marl = "Voidlight Marl",
                    },
                    disabled = function() return not PTOptions:GetAutoSelectHuntReward() end,
                    handler = PTOptions,
                    get = "GetPreferredHuntReward",
                    set = "SetPreferredHuntReward",
                },
                fallbackReward = {
                    type = "select",
                    name = "Fallback Reward",
                    desc = "Fallback reward type when the preferred type is unavailable.",
                    order = 6,
                    width = 1.5,
                    values = {
                        dawncrest = "Dawncrest",
                        remnant = "Remnant",
                        gold = "Gold",
                        marl = "Voidlight Marl",
                    },
                    disabled = function() return not PTOptions:GetAutoSelectHuntReward() end,
                    handler = PTOptions,
                    get = "GetFallbackHuntReward",
                    set = "SetFallbackHuntReward",
                },
            }),
        },
    }
end

local function BuildTeleportsTab()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Teleports",
        order = 8,
        args = {
            desc = {
                type = "description",
                order = 1,
                name =
                "Adds a TwichUI teleport browser to the world map and optionally extends the Portals datatext with a season-focused teleport popup.",
            },
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable the Teleports module.",
                order = 2,
                handler = TPOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            integrationGroup = W.IGroup(10, "Integrations", {
                showWorldMapTab = {
                    type = "toggle",
                    name = "World Map Tab",
                    desc = "Add a teleport browser tab to the world map side tabs.",
                    order = 1,
                    width = 1.5,
                    disabled = function() return not TPOptions:GetEnabled() end,
                    handler = TPOptions,
                    get = "GetShowWorldMapTab",
                    set = "SetShowWorldMapTab",
                },
                showDatatextPopup = {
                    type = "toggle",
                    name = "Portals Datatext Popup",
                    desc =
                    "Use the Portals datatext left-click to open a teleport popup instead of the old disabled menu path.",
                    order = 2,
                    width = 1.5,
                    disabled = function() return not TPOptions:GetEnabled() end,
                    handler = TPOptions,
                    get = "GetShowDatatextPopup",
                    set = "SetShowDatatextPopup",
                },
                datatextIncludeRaids = {
                    type = "toggle",
                    name = "Datatext Includes Raids",
                    desc =
                    "Include current-content raid teleports in the Portals datatext popup alongside current-season dungeons.",
                    order = 3,
                    width = 1.5,
                    disabled = function() return not TPOptions:GetEnabled() or not TPOptions:GetShowDatatextPopup() end,
                    handler = TPOptions,
                    get = "GetDatatextIncludeRaids",
                    set = "SetDatatextIncludeRaids",
                },
            }),
            contentGroup = W.IGroup(20, "Browser Content", {
                showOnlyKnown = {
                    type = "toggle",
                    name = "Show Only Available",
                    desc = "Hide teleports you do not currently know or own in both the map browser and datatext popup.",
                    order = 1,
                    width = 1.5,
                    disabled = function() return not TPOptions:GetEnabled() end,
                    handler = TPOptions,
                    get = "GetShowOnlyKnown",
                    set = "SetShowOnlyKnown",
                },
                showHearthstones = {
                    type = "toggle",
                    name = "Show Hearthstones",
                    desc = "Include hearthstones and other item teleports in both the map browser and datatext popup.",
                    order = 2,
                    width = 1.5,
                    disabled = function() return not TPOptions:GetEnabled() end,
                    handler = TPOptions,
                    get = "GetShowHearthstones",
                    set = "SetShowHearthstones",
                },
                showUtilityTeleports = {
                    type = "toggle",
                    name = "Show Class and Racial Travel",
                    desc = "Include class, mage, and racial travel spells in both the map browser and datatext popup.",
                    order = 3,
                    width = 1.75,
                    disabled = function() return not TPOptions:GetEnabled() end,
                    handler = TPOptions,
                    get = "GetShowUtilityTeleports",
                    set = "SetShowUtilityTeleports",
                },
            }),
            testGroup = W.IGroup(30, "Preview", {
                open = {
                    type = "execute",
                    name = "Open Popup Preview",
                    desc = "Open the datatext-style teleport popup in the middle of the screen.",
                    order = 1,
                    disabled = function() return not TPOptions:GetEnabled() end,
                    handler = TPOptions,
                    func = "OpenPreview",
                },
                close = {
                    type = "execute",
                    name = "Close Popup Preview",
                    desc = "Close the popup preview if it is open.",
                    order = 2,
                    disabled = function() return not TPOptions:GetEnabled() end,
                    handler = TPOptions,
                    func = "ClosePreview",
                },
            }),
        },
    }
end

local function BuildWorldQuestsTab()
    local W = ConfigurationModule.Widgets

    local filterToggles = {
        tracked = "Tracked",
        gear = "Loot",
        gold = "Gold",
        reputation = "Reputation",
        items = "Items",
        profession = "Profession",
        pvp = "PvP",
        pet = "Pet Battles",
        dungeon = "Dungeon",
        rare = "Rare",
        time = "Time Remaining",
    }

    local filterArgs = {}
    local orderIndex = 1
    for key, label in pairs(filterToggles) do
        filterArgs[key] = {
            type = "toggle",
            name = label,
            order = orderIndex,
            width = 1.25,
            disabled = function()
                return not WQOptions:GetEnabled()
            end,
            get = function()
                return WQOptions:GetFilterChipEnabled(key)
            end,
            set = function(_, value)
                WQOptions:SetFilterChipEnabled(key, value)
            end,
        }
        orderIndex = orderIndex + 1
    end

    return {
        type = "group",
        name = "World Quests",
        order = 8.5,
        args = {
            desc = {
                type = "description",
                order = 1,
                name =
                "Adds a TwichUI world quest browser to the world map with reward summaries, map filtering, tracking control, and quick waypoint actions.",
            },
            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable the World Quests browser.",
                order = 2,
                handler = WQOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            integrationGroup = W.IGroup(10, "Integrations", {
                showWorldMapTab = {
                    type = "toggle",
                    name = "World Map Tab",
                    desc = "Add the World Quests browser as a side tab on the world map.",
                    order = 1,
                    width = 1.5,
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    get = "GetShowWorldMapTab",
                    set = "SetShowWorldMapTab",
                },
                onlyCurrentZone = {
                    type = "toggle",
                    name = "Only Current Map",
                    desc = "Limit the browser to world quests returned directly for the currently displayed map.",
                    order = 2,
                    width = 1.5,
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    get = "GetOnlyCurrentZone",
                    set = "SetOnlyCurrentZone",
                },
                showChildZonesOnParentMaps = {
                    type = "toggle",
                    name = "Expand Parent Maps",
                    desc = "When viewing a continent or larger map, include the child zones beneath it.",
                    order = 3,
                    width = 1.5,
                    disabled = function() return not WQOptions:GetEnabled() or WQOptions:GetOnlyCurrentZone() end,
                    handler = WQOptions,
                    get = "GetShowChildZonesOnParentMaps",
                    set = "SetShowChildZonesOnParentMaps",
                },
            }),
            mapIconsGroup = W.IGroup(20, "Map Icon Behavior", {
                hideFilteredPOI = {
                    type = "toggle",
                    name = "Hide Filtered Icons",
                    desc = "Hide world quest icons on the world map when they do not match the active browser filters.",
                    order = 1,
                    width = 1.5,
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    get = "GetHideFilteredPOI",
                    set = "SetHideFilteredPOI",
                },
                hideUntrackedPOI = {
                    type = "toggle",
                    name = "Hide Untracked Icons",
                    desc = "Only keep tracked world quest icons visible on the map.",
                    order = 2,
                    width = 1.5,
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    get = "GetHideUntrackedPOI",
                    set = "SetHideUntrackedPOI",
                },
                showHoveredPOI = {
                    type = "toggle",
                    name = "Always Show Hovered Quest",
                    desc = "Temporarily reveal a hovered quest's map icon even when it would normally be hidden.",
                    order = 3,
                    width = 1.5,
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    get = "GetShowHoveredPOI",
                    set = "SetShowHoveredPOI",
                },
            }),
            browserGroup = W.IGroup(30, "Browser Behavior", {
                sortMethod = {
                    type = "select",
                    name = "Sort Method",
                    desc = "Choose how the world quest list is sorted.",
                    order = 1,
                    values = {
                        time = "Time Remaining",
                        zone = "Zone",
                        name = "Name",
                        rewards = "Reward Summary",
                    },
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    get = "GetSortMethod",
                    set = "SetSortMethod",
                },
                timeFilterHours = {
                    type = "range",
                    name = "Time Filter Threshold",
                    desc = "Maximum remaining time for the Time Remaining filter chip.",
                    order = 2,
                    min = 1,
                    max = 24,
                    step = 1,
                    suffix = " hours",
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    get = "GetTimeFilterHours",
                    set = "SetTimeFilterHours",
                },
            }),
            filtersGroup = W.IGroup(40, "Visible Filter Chips", filterArgs),
            previewGroup = W.IGroup(50, "Preview", {
                open = {
                    type = "execute",
                    name = "Open Map Browser",
                    desc = "Open the TwichUI world quest browser on the world map.",
                    order = 1,
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    func = "OpenPreview",
                },
                close = {
                    type = "execute",
                    name = "Close Map Browser",
                    desc = "Close the world quest browser if it is open.",
                    order = 2,
                    disabled = function() return not WQOptions:GetEnabled() end,
                    handler = WQOptions,
                    func = "ClosePreview",
                },
            }),
        },
    }
end

local function BuildEasyFishTab()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Easy Fish",
        order = 3,
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
        order = 6,
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

local function BuildChoresTab()
    local W = ConfigurationModule.Widgets

    local pveFrameLoadUI = (_G --[[@as any]]).PVEFrame_LoadUI
    local legacyLoadAddOn = (_G --[[@as any]]).LoadAddOn

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

    ---@type ChoresModule
    local ChoresModule = T:GetModule("Chores")

    local preyDifficultyArgs = {
        desc = W.Description(1,
            T.Tools.Text.Color(T.Tools.Colors.GRAY,
                "Choose which unlocked Prey difficulties are tracked. Each enabled difficulty contributes up to four hunts to the Prey section.")),
    }

    local preyDifficultyOrder = 2
    local preyDifficulties = ChoresModule and ChoresModule.GetPreyDifficultyDefinitions and
        ChoresModule:GetPreyDifficultyDefinitions() or {}

    for _, difficulty in ipairs(preyDifficulties) do
        preyDifficultyArgs[difficulty.key] = {
            type = "toggle",
            name = difficulty.name,
            desc = ("Track %s Prey hunts in the Chores tooltip."):format(difficulty.name),
            order = preyDifficultyOrder,
            width = 1.5,
            disabled = function()
                return not ChoresOptions:GetTrackPrey()
            end,
            get = function()
                return ChoresOptions:IsPreyDifficultyEnabled(difficulty.key)
            end,
            set = function(_, value)
                ChoresOptions:SetPreyDifficultyEnabled(difficulty.key, value)
            end,
        }
        preyDifficultyOrder = preyDifficultyOrder + 1
    end

    local professionArgs = {
        desc = W.Description(1,
            T.Tools.Text.Color(T.Tools.Colors.GRAY,
                "Enable or disable Midnight profession chore tracking for learned professions.")),
    }

    local professionOrder = 2
    do
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
        childGroups = "tab",
        args = {
            tracking = {
                type = "group",
                name = "Tracking",
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
                        prey = {
                            type = "toggle",
                            name = T.Tools.Text.Icon(PreyIcon) .. " Prey",
                            desc =
                            "Track Prey hunts by difficulty and show the total hunts remaining in the Chores tooltip.",
                            order = 2,
                            width = 1.5,
                            handler = ChoresOptions,
                            get = "GetTrackPrey",
                            set = "SetTrackPrey",
                        },
                        bountifulDelves = {
                            type = "toggle",
                            name = "|A:delves-bountiful:16:16|a Bountiful Delves",
                            desc =
                            "Track current bountiful delves and show your current coffer keys in the datatext tooltip.",
                            order = 3,
                            width = 1.5,
                            handler = ChoresOptions,
                            get = "GetTrackBountifulDelves",
                            set = "SetTrackBountifulDelves",
                        },
                        bountifulDelvesWithKeyOnly = {
                            type = "toggle",
                            name = "Only Track With Key",
                            desc =
                            "Only include the Bountiful Delves tracker section when you have at least one Restored Coffer Key.",
                            order = 4,
                            width = 1.5,
                            disabled = function()
                                return not ChoresOptions:GetTrackBountifulDelves()
                            end,
                            handler = ChoresOptions,
                            get = "GetOnlyTrackBountifulDelvesWithKey",
                            set = "SetOnlyTrackBountifulDelvesWithKey",
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
                        prey = {
                            type = "toggle",
                            name = T.Tools.Text.Icon(PreyIcon) .. " Prey",
                            desc = "Count tracked Prey hunts toward the Chores total.",
                            order = 3,
                            width = 1.5,
                            disabled = function()
                                return not ChoresOptions:GetTrackPrey()
                            end,
                            handler = ChoresOptions,
                            get = "GetCountPreyTowardTotal",
                            set = "SetCountPreyTowardTotal",
                        },
                        bountifulDelves = {
                            type = "toggle",
                            name = "|A:delves-bountiful:16:16|a Bountiful Delves",
                            desc = "Count tracked bountiful delves toward the Chores total.",
                            order = 4,
                            width = 1.5,
                            handler = ChoresOptions,
                            get = "GetCountBountifulDelvesTowardTotal",
                            set = "SetCountBountifulDelvesTowardTotal",
                        },
                    }),
                    preyDifficulties = W.IGroup(7, "Prey Difficulties", preyDifficultyArgs),
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
                        dungeon = BuildCategoryToggle(9, "dungeon",
                            "Interface\\Icons\\achievement_dungeon_azjolkahet_dungeon",
                            "Dungeon",
                            "Track the weekly Midnight dungeon quest.", "Dungeon"),
                    }),
                    professionChores = W.IGroup(15, "Profession Chores", professionArgs),
                    raidWings = W.IGroup(20, "Raid Finder Wings", raidWingArgs),
                },
            },
            trackerFrame = {
                type = "group",
                name = "Tracker Frame",
                order = 2,
                args = {
                    desc = W.Description(1,
                        "Configure the pinned Chores tracker opened by right-clicking the Chores datatext. Use /tui chores to jump here directly."),
                    mode = {
                        type = "select",
                        name = "Tracker Style",
                        desc =
                        "Choose whether the pinned tracker uses the framed card look or only shows the inner category panels.",
                        order = 2,
                        values = {
                            framed = "Framed",
                            minimal = "Inner Categories Only",
                        },
                        handler = ChoresOptions,
                        get = "GetTrackerFrameMode",
                        set = "SetTrackerFrameMode",
                    },
                    headerFont = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = "Header Font",
                        desc =
                        "Font used for the tracker title and category headers. Tooltip Header reuses the Chores tooltip header font.",
                        order = 3,
                        width = 2,
                        values = function()
                            local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                            local values = {
                                __tooltipHeader = "Tooltip Header",
                            }

                            for key, value in pairs(fonts) do
                                values[key] = value
                            end

                            return values
                        end,
                        handler = ChoresOptions,
                        get = "GetTrackerHeaderFont",
                        set = "SetTrackerHeaderFont",
                    },
                    headerFontSize = {
                        type = "range",
                        name = "Header Font Size",
                        desc = "Font size used for the tracker title and category headers.",
                        order = 4,
                        min = 8,
                        max = 24,
                        step = 1,
                        handler = ChoresOptions,
                        get = "GetTrackerHeaderFontSize",
                        set = "SetTrackerHeaderFontSize",
                    },
                    entryFont = {
                        type = "select",
                        dialogControl = "LSM30_Font",
                        name = "Content Font",
                        desc =
                        "Font used for tracker entries and empty-state text. Tooltip Entry reuses the Chores tooltip entry font.",
                        order = 5,
                        width = 2,
                        values = function()
                            local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
                            local values = {
                                __tooltipEntry = "Tooltip Entry",
                            }

                            for key, value in pairs(fonts) do
                                values[key] = value
                            end

                            return values
                        end,
                        handler = ChoresOptions,
                        get = "GetTrackerEntryFont",
                        set = "SetTrackerEntryFont",
                    },
                    entryFontSize = {
                        type = "range",
                        name = "Content Font Size",
                        desc = "Font size used for tracker entries and empty-state text.",
                        order = 6,
                        min = 8,
                        max = 24,
                        step = 1,
                        handler = ChoresOptions,
                        get = "GetTrackerEntryFontSize",
                        set = "SetTrackerEntryFontSize",
                    },
                    frameTransparency = {
                        type = "range",
                        name = "Frame Transparency",
                        desc = "Controls the overall opacity of the pinned tracker window.",
                        order = 7,
                        min = 0.2,
                        max = 1,
                        step = 0.01,
                        isPercent = true,
                        handler = ChoresOptions,
                        get = "GetTrackerFrameTransparency",
                        set = "SetTrackerFrameTransparency",
                    },
                    backgroundTransparency = {
                        type = "range",
                        name = "Background Transparency",
                        desc = "Controls the opacity of the tracker backgrounds and category panels.",
                        order = 8,
                        min = 0,
                        max = 1,
                        step = 0.01,
                        isPercent = true,
                        handler = ChoresOptions,
                        get = "GetTrackerBackgroundTransparency",
                        set = "SetTrackerBackgroundTransparency",
                    },
                    keybinding = {
                        type = "keybinding",
                        name = "Toggle Tracker Frame",
                        desc = "Optional keybinding that opens or closes the pinned Chores tracker frame.",
                        order = 9,
                        handler = ChoresOptions,
                        get = "GetTrackerFrameConfigKeybinding",
                        set = "SetTrackerFrameConfigKeybinding",
                    },
                    helper = W.Description(10,
                        T.Tools.Text.Color(T.Tools.Colors.GRAY,
                            "Right-click the Chores datatext to open the pinned tracker. Drag the bottom-right corner to resize it, and use the lock icon to pin it in place.")),
                },
            },
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
        gatheringTab = ConfigurationModuleRuntime.BuildGatheringTab and ConfigurationModuleRuntime.BuildGatheringTab() or nil,
        easyFishTab = BuildEasyFishTab(),
        gossipHotkeysTab = BuildGossipHotkeysTab(),
        preyTweaksTab = BuildPreyTweaksTab(),
        questAutomationTab = BuildQuestAutomationTab(),
        questLogCleanerTab = BuildQuestLogCleanerTab(),
        satchelWatchTab = BuildSatchelWatchTab(),
        smartMountTab = ConfigurationModuleRuntime.BuildSmartMountTab and ConfigurationModuleRuntime.BuildSmartMountTab(9),
        teleportsTab = BuildTeleportsTab(),
        worldQuestsTab = BuildWorldQuestsTab(),
    }

    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("Quality of Life", BuildConfiguration)
