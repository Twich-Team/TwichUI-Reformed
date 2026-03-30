--[[
    Primary configuration section for Mythic+ Tools.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@type MythicPlusToolsConfigurationOptions
local MPTOptions = ConfigurationModule.Options.MythicPlusTools

local function GetFontValues()
    local fonts = LibStub("LibSharedMedia-3.0"):HashTable("font") or {}
    local values = {
        __default = "Default",
    }

    for key, value in pairs(fonts) do
        values[key] = value
    end

    return values
end

local function GetStatusBarValues()
    return LibStub("LibSharedMedia-3.0"):HashTable("statusbar") or {}
end

local function GetSoundValues()
    local values = { __none = "None" }
    local sounds = LibStub("LibSharedMedia-3.0"):HashTable("sound") or {}
    for key, value in pairs(sounds) do
        values[key] = value
    end
    return values
end

local function BuildCheckpointTabArgs()
    local W = ConfigurationModule.Widgets
    local checkpoints = MPTOptions:GetSelectedDungeonCheckpoints()
    local bossCheckpointCount = 0
    for _, checkpoint in ipairs(checkpoints) do
        if checkpoint.kind == "boss" then
            bossCheckpointCount = bossCheckpointCount + 1
        end
    end

    local args = {}
    if #checkpoints == 0 then
        args.empty = {
            type = "group",
            name = "No Checkpoints",
            order = 1,
            args = {
                desc = W.Description(1, "No checkpoint data is available for the selected dungeon yet."),
            },
        }
        return args
    end

    for index, checkpoint in ipairs(checkpoints) do
        local checkpointData = checkpoint
        local isCustom = checkpointData.kind == "custom"
        local isLastBoss = checkpointData.kind == "boss" and tonumber(checkpointData.bossIndex) == bossCheckpointCount
        local title = isCustom and (checkpointData.name or ("Custom Checkpoint " .. index)) or
            (checkpointData.name or ("Boss " .. index))

        local groupArgs = {
            summary = W.Description(1,
                isCustom and "Custom minion checkpoint. It will stay sorted by target percent automatically." or
                "Boss checkpoint. The target percent marks how much trash should be complete before the boss dies."),
            percent = {
                type = "range",
                name = "Target Forces %",
                desc = isLastBoss and "The final boss checkpoint is always 100%." or
                    "Enemy-forces target for this checkpoint.",
                order = 2,
                min = 0,
                max = 100,
                step = 0.5,
                width = 1.6,
                disabled = function()
                    return isLastBoss
                end,
                get = function()
                    return tonumber(checkpointData.percent) or 0
                end,
                set = function(_, value)
                    MPTOptions:UpdateSelectedDungeonCheckpoint(checkpointData.id, { percent = value })
                end,
            },
            notify = {
                type = "toggle",
                name = "Send Notification",
                desc = "Show a Mythic+ checkpoint notification when this checkpoint is reached.",
                order = 3,
                width = 1.5,
                get = function()
                    return checkpointData.notifyEnabled ~= false
                end,
                set = function(_, value)
                    MPTOptions:UpdateSelectedDungeonCheckpoint(checkpointData.id, { notifyEnabled = value == true })
                end,
            },
        }

        if isCustom then
            groupArgs.name = {
                type = "input",
                name = "Checkpoint Name",
                desc = "Label shown for this custom checkpoint.",
                order = 4,
                width = 1.8,
                get = function()
                    return tostring(checkpointData.name or "")
                end,
                set = function(_, value)
                    MPTOptions:UpdateSelectedDungeonCheckpoint(checkpointData.id, { name = value })
                end,
            }
            groupArgs.remove = {
                type = "execute",
                name = "Remove",
                desc = "Delete this custom checkpoint.",
                order = 5,
                func = function()
                    MPTOptions:RemoveSelectedDungeonCheckpoint(checkpointData.id)
                end,
            }
        else
            groupArgs.bossInfo = W.Description(4,
                isLastBoss and "Final boss checkpoints stay pinned to 100% enemy forces." or
                "Boss checkpoint names come from the dungeon journal and stay aligned with the timer rows.")
        end

        args["checkpoint" .. index] = {
            type = "group",
            name = title,
            order = index,
            args = groupArgs,
        }
    end

    return args
end

local function BuildMinionCheckpointArgs()
    local W = ConfigurationModule.Widgets
    return {
        desc = W.Description(1,
            "Choose a seasonal dungeon here, then use the checkpoint tabs below to tune boss targets and custom minion checkpoints."),
        management = W.IGroup(2, "Dungeon", {
            dungeon = {
                type = "select",
                name = "Dungeon",
                desc = "Choose which seasonal dungeon you are editing.",
                order = 1,
                width = 1.9,
                values = function()
                    return MPTOptions:GetSeasonalDungeonValues()
                end,
                handler = MPTOptions,
                get = "GetSelectedCheckpointMapID",
                set = "SetSelectedCheckpointMapID",
            },
            addCustom = {
                type = "execute",
                name = "Add Custom Checkpoint",
                desc = "Insert a custom minion checkpoint into the selected dungeon.",
                order = 2,
                handler = MPTOptions,
                func = "AddSelectedDungeonCheckpoint",
            },
            reset = {
                type = "execute",
                name = "Reset Dungeon Checkpoints",
                desc = "Restore the selected dungeon back to its default boss checkpoints.",
                order = 3,
                handler = MPTOptions,
                func = "ResetSelectedDungeonCheckpoints",
            },
            preview = W.Description(4,
                "These controls stay pinned above the checkpoint tabs so you can switch dungeons or add checkpoints without leaving the current checkpoint view."),
        }),
        checkpoints = {
            type = "group",
            name = "Checkpoints",
            order = 3,
            childGroups = "tab",
            args = BuildCheckpointTabArgs(),
        },
    }
end

local function BuildConfiguration()
    local W = ConfigurationModule.Widgets
    local optionsTab = W.NewConfigurationSection(34, "Mythic+ Tools")
    optionsTab.childGroups = "tree"

    optionsTab.args = {
        title = W.TitleWidget(0, "Mythic+ Tools"),
        description = W.Description(1,
            "Curated Mythic+ utility for keystone automation, the in-house timer, and the interrupt tracker."),
        general = {
            type = "group",
            name = "General",
            order = 2,
            args = {
                desc = W.Description(1,
                    "Enable the Mythic+ Tools suite and decide when its frames should be visible."),
                enable = {
                    type = "toggle",
                    name = "Enable",
                    desc = "Enable the Mythic+ Tools module.",
                    order = 2,
                    handler = MPTOptions,
                    get = "GetEnabled",
                    set = "SetEnabled",
                },
                frameVisibilityMode = {
                    type = "select",
                    name = "Show Frames",
                    desc = "Choose when the Mythic+ timer and interrupt tracker should be visible.",
                    order = 3,
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
            },
        },
        keystoneHelpers = {
            type = "group",
            name = "Keystone Helpers",
            order = 10,
            args = {
                desc = W.Description(1,
                    "Automate the mechanical parts of key setup without touching route or combat decision-making."),
                autoSlot = {
                    type = "toggle",
                    name = "Auto Slot Keystone",
                    desc = "Automatically slot your keystone when the receptacle opens.",
                    order = 2,
                    width = 1.5,
                    handler = MPTOptions,
                    get = "GetAutoSlotKeystoneEnabled",
                    set = "SetAutoSlotKeystoneEnabled",
                },
                autoStart = {
                    type = "toggle",
                    name = "Auto Start After Pull Timer",
                    desc =
                    "Start the key when a BigWigs or DBM pull timer ends if your keystone is already slotted and you can start the run.",
                    order = 3,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetAutoStartDungeonEnabled",
                    set = "SetAutoStartDungeonEnabled",
                },
            },
        },
        mythicPlusTimer = {
            type = "group",
            name = "Mythic+ Timer",
            order = 30,
            childGroups = "tab",
            args = {
                configuration = {
                    type = "group",
                    name = "Configuration",
                    order = 1,
                    args = {
                        desc = W.Description(1,
                            "Configure the in-house timer frame. By default it inherits the Shared Defaults section below, then applies any timer-specific overrides you set here."),
                        enable = {
                            type = "toggle",
                            name = "Enable Mythic+ Timer",
                            desc = "Show the Mythic+ timer during active keys.",
                            order = 2,
                            width = 1.75,
                            handler = MPTOptions,
                            get = "GetMythicPlusTimerEnabled",
                            set = "SetMythicPlusTimerEnabled",
                        },
                        locked = {
                            type = "toggle",
                            name = "Lock Timer Frame",
                            desc = "Lock the timer in place. Disable to drag and resize it.",
                            order = 3,
                            width = 1.5,
                            handler = MPTOptions,
                            get = "GetMythicPlusTimerLocked",
                            set = "SetMythicPlusTimerLocked",
                        },
                        frameStyle = {
                            type = "select",
                            name = "Timer Style",
                            desc = "Choose whether the timer uses a framed shell or a transparent data-first layout.",
                            order = 4,
                            width = 1.6,
                            values = {
                                framed = "Framed",
                                transparent = "Transparent",
                            },
                            handler = MPTOptions,
                            get = "GetMythicPlusTimerStyle",
                            set = "SetMythicPlusTimerStyle",
                        },
                        layout = {
                            type = "select",
                            name = "Screen Side Alignment",
                            desc =
                            "Choose whether the top timer text block aligns for a frame placed on the left or right side of the screen. Bar row ordering stays the same.",
                            order = 5,
                            width = 1.6,
                            values = {
                                left = "Left Side",
                                right = "Right Side",
                            },
                            handler = MPTOptions,
                            get = "GetMythicPlusTimerLayout",
                            set = "SetMythicPlusTimerLayout",
                        },
                        showHeader = {
                            type = "toggle",
                            name = "Show Title Bar",
                            desc = "Show the title/header bar in framed mode. Transparent mode always hides it.",
                            order = 5.5,
                            width = 1.5,
                            disabled = function() return MPTOptions:GetMythicPlusTimerStyle() ~= "framed" end,
                            handler = MPTOptions,
                            get = "GetMythicPlusTimerShowHeader",
                            set = "SetMythicPlusTimerShowHeader",
                        },
                        scale = {
                            type = "range",
                            name = "Timer Scale",
                            desc = "Scale the timer frame without changing the shared tracker sizing defaults.",
                            order = 6,
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
                            order = 7,
                            width = 1.75,
                            handler = MPTOptions,
                            get = "GetMythicPlusTimerShowBossCheckpoints",
                            set = "SetMythicPlusTimerShowBossCheckpoints",
                        },
                        reset = {
                            type = "execute",
                            name = "Reset Timer Position",
                            desc = "Move the Mythic+ timer back to its default position.",
                            order = 8,
                            handler = MPTOptions,
                            func = "ResetMythicPlusTimerPosition",
                        },
                        preview = {
                            type = "execute",
                            name = "Start Timer Preview",
                            desc =
                            "Show a live-style timer preview with milestone bars, forces, deaths, and configured checkpoints.",
                            order = 9,
                            handler = MPTOptions,
                            func = "StartMythicPlusTimerPreview",
                        },
                        stopPreview = {
                            type = "execute",
                            name = "Stop Timer Preview",
                            desc = "Hide the Mythic+ timer preview.",
                            order = 10,
                            handler = MPTOptions,
                            func = "StopMythicPlusTimerPreview",
                        },
                        appearance = W.IGroup(20, "Timer Appearance Overrides", {
                            font = {
                                type = "select",
                                dialogControl = "LSM30_Font",
                                name = "Font",
                                desc = "Font used by the timer frame. Defaults to Shared Defaults when unchanged.",
                                order = 1,
                                width = 2,
                                values = GetFontValues,
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerFont",
                                set = "SetMythicPlusTimerFont",
                            },
                            fontSize = {
                                type = "range",
                                name = "Font Size",
                                desc = "Base font size used by timer text and labels.",
                                order = 2,
                                min = 8,
                                max = 28,
                                step = 1,
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerFontSize",
                                set = "SetMythicPlusTimerFontSize",
                            },
                            fontOutline = {
                                type = "select",
                                name = "Font Outline",
                                desc = "Outline style used by the timer text.",
                                order = 3,
                                values = {
                                    default = "Default",
                                    none = "None",
                                    outline = "Outline",
                                    thick = "Thick Outline",
                                },
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerFontOutline",
                                set = "SetMythicPlusTimerFontOutline",
                            },
                            fontColor = {
                                type = "color",
                                name = "Font Color",
                                desc = "Primary text color used by the timer. Secondary text is derived from this color.",
                                order = 4,
                                hasAlpha = false,
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerFontColor",
                                set = "SetMythicPlusTimerFontColor",
                            },
                            barTexture = {
                                type = "select",
                                dialogControl = "LSM30_Statusbar",
                                name = "Bar Texture",
                                desc = "Status bar texture used by the timer bars.",
                                order = 5,
                                width = 2,
                                values = GetStatusBarValues,
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerBarTexture",
                                set = "SetMythicPlusTimerBarTexture",
                            },
                            barColorMode = {
                                type = "select",
                                name = "Bar Color Mode",
                                desc = "Keep the built-in milestone colors or tint all timer bars with a custom color.",
                                order = 6,
                                width = 1.6,
                                values = {
                                    milestone = "Milestone Colors",
                                    custom = "Custom Color",
                                },
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerBarColorMode",
                                set = "SetMythicPlusTimerBarColorMode",
                            },
                            barColor = {
                                type = "color",
                                name = "Custom Bar Color",
                                desc = "Color used for all timer bars when Bar Color Mode is set to Custom Color.",
                                order = 7,
                                hasAlpha = false,
                                disabled = function() return MPTOptions:GetMythicPlusTimerBarColorMode() ~= "custom" end,
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerBarColor",
                                set = "SetMythicPlusTimerBarColor",
                            },
                            rowGap = {
                                type = "range",
                                name = "Row Gap",
                                desc = "Vertical spacing between timer bars.",
                                order = 8,
                                min = 0,
                                max = 30,
                                step = 1,
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerRowGap",
                                set = "SetMythicPlusTimerRowGap",
                            },
                            barHeight = {
                                type = "range",
                                name = "Bar Height",
                                desc = "Height of the timer progress bars.",
                                order = 9,
                                min = 10,
                                max = 40,
                                step = 1,
                                handler = MPTOptions,
                                get = "GetMythicPlusTimerBarHeight",
                                set = "SetMythicPlusTimerBarHeight",
                            },
                            resetAppearance = {
                                type = "execute",
                                name = "Reset Timer Overrides",
                                desc =
                                "Clear the timer-specific overrides so it fully inherits the Shared Defaults again.",
                                order = 10,
                                handler = MPTOptions,
                                func = "ResetMythicPlusTimerAppearance",
                            },
                        }),
                    },
                },
                minionCheckpoints = {
                    type = "group",
                    name = "Minion Checkpoints",
                    order = 2,
                    args = BuildMinionCheckpointArgs(),
                },
            },
        },
        interruptTracker = {
            type = "group",
            name = "Interrupt Tracker",
            order = 40,
            args = {
                desc = W.Description(1,
                    "Track party interrupt cooldowns in a movable frame tuned for dungeon decision-making."),
                enable = {
                    type = "toggle",
                    name = "Enable Interrupt Tracker",
                    desc = "Show a movable interrupt tracker for your current group.",
                    order = 2,
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
                    order = 3,
                    width = 2,
                    values = GetSoundValues,
                    handler = MPTOptions,
                    get = "GetInterruptReadySound",
                    set = "SetInterruptReadySound",
                },
                locked = {
                    type = "toggle",
                    name = "Lock Interrupt Frame",
                    desc = "Lock the interrupt tracker in place. Disable to drag it.",
                    order = 4,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetInterruptTrackerLocked",
                    set = "SetInterruptTrackerLocked",
                },
                reset = {
                    type = "execute",
                    name = "Reset Interrupt Position",
                    desc = "Move the interrupt tracker back to its default position.",
                    order = 5,
                    handler = MPTOptions,
                    func = "ResetInterruptTrackerPosition",
                },
                preview = {
                    type = "execute",
                    name = "Start Interrupt Preview",
                    desc = "Show a live-style interrupt preview with sample party members.",
                    order = 6,
                    handler = MPTOptions,
                    func = "StartInterruptPreview",
                },
                stopPreview = {
                    type = "execute",
                    name = "Stop Interrupt Preview",
                    desc = "Hide the interrupt preview.",
                    order = 7,
                    handler = MPTOptions,
                    func = "StopInterruptPreview",
                },
                colors = W.IGroup(20, "Interrupt Colors", {
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
            },
        },
        sharedAppearance = {
            type = "group",
            name = "Shared Defaults",
            order = 50,
            args = {
                desc = W.Description(1,
                    "These defaults feed both Mythic+ frames. The timer inherits them unless you override specific values in the Mythic+ Timer section."),
                trackerStyle = {
                    type = "select",
                    name = "Interrupt Frame Style",
                    desc = "Choose the visual style for the Interrupt Tracker frame.",
                    order = 2,
                    width = 1.6,
                    values = {
                        paneled = "Paneled",
                        bare = "Bare Bars",
                    },
                    handler = MPTOptions,
                    get = "GetTrackerStyle",
                    set = "SetTrackerStyle",
                },
                trackerFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Shared Font",
                    desc = "Default font for Mythic+ Tools frames.",
                    order = 3,
                    width = 2,
                    values = GetFontValues,
                    handler = MPTOptions,
                    get = "GetTrackerFont",
                    set = "SetTrackerFont",
                },
                trackerFontSize = {
                    type = "range",
                    name = "Shared Font Size",
                    desc = "Default font size used by Mythic+ Tools frames.",
                    order = 4,
                    min = 8,
                    max = 24,
                    step = 1,
                    handler = MPTOptions,
                    get = "GetTrackerFontSize",
                    set = "SetTrackerFontSize",
                },
                trackerFontOutline = {
                    type = "select",
                    name = "Shared Font Outline",
                    desc = "Outline style used by Mythic+ Tools text.",
                    order = 5,
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
                    name = "Shared Bar Texture",
                    desc = "Default status bar texture used by Mythic+ Tools frames.",
                    order = 6,
                    width = 2,
                    values = GetStatusBarValues,
                    handler = MPTOptions,
                    get = "GetTrackerBarTexture",
                    set = "SetTrackerBarTexture",
                },
                trackerRowGap = {
                    type = "range",
                    name = "Shared Row Gap",
                    desc = "Default vertical gap between rows.",
                    order = 7,
                    min = 0,
                    max = 30,
                    step = 1,
                    handler = MPTOptions,
                    get = "GetTrackerRowGap",
                    set = "SetTrackerRowGap",
                },
                trackerIconSize = {
                    type = "range",
                    name = "Interrupt Icon Size",
                    desc = "Size of interrupt tracker row icons.",
                    order = 8,
                    min = 14,
                    max = 48,
                    step = 1,
                    handler = MPTOptions,
                    get = "GetTrackerIconSize",
                    set = "SetTrackerIconSize",
                },
                trackerBarHeight = {
                    type = "range",
                    name = "Shared Bar Height",
                    desc = "Default height of status bars.",
                    order = 9,
                    min = 10,
                    max = 40,
                    step = 1,
                    handler = MPTOptions,
                    get = "GetTrackerBarHeight",
                    set = "SetTrackerBarHeight",
                },
                statusTextFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Status Font",
                    desc = "Font used for shared status text defaults.",
                    order = 10,
                    width = 2,
                    values = GetFontValues,
                    handler = MPTOptions,
                    get = "GetStatusTextFont",
                    set = "SetStatusTextFont",
                },
                statusTextColor = {
                    type = "color",
                    name = "Status Text Color",
                    desc = "Color used for shared status text defaults.",
                    order = 11,
                    hasAlpha = false,
                    handler = MPTOptions,
                    get = "GetStatusTextColor",
                    set = "SetStatusTextColor",
                },
                readyTextFont = {
                    type = "select",
                    dialogControl = "LSM30_Font",
                    name = "Ready Font",
                    desc = "Font used when a shared tracker row is ready.",
                    order = 12,
                    width = 2,
                    values = GetFontValues,
                    handler = MPTOptions,
                    get = "GetReadyTextFont",
                    set = "SetReadyTextFont",
                },
                readyTextColor = {
                    type = "color",
                    name = "Ready Text Color",
                    desc = "Color used when a shared tracker row is ready.",
                    order = 13,
                    hasAlpha = false,
                    handler = MPTOptions,
                    get = "GetReadyTextColor",
                    set = "SetReadyTextColor",
                },
                showReadyText = {
                    type = "toggle",
                    name = "Show Ready Text",
                    desc = "Display the word Ready when an interrupt row becomes available.",
                    order = 14,
                    width = 1.8,
                    handler = MPTOptions,
                    get = "GetShowReadyText",
                    set = "SetShowReadyText",
                },
            },
        },
        debug = {
            type = "group",
            name = "Debugging",
            order = 60,
            args = {
                desc = W.Description(1,
                    "Capture optional Mythic+ Tools runtime output in the shared /tui debug console."),
                enableDebug = {
                    type = "toggle",
                    name = "Enable Debug Capture",
                    desc = "Record Mythic+ Tools runtime debug lines into the shared TwichUI debug console.",
                    order = 2,
                    width = 1.75,
                    handler = MPTOptions,
                    get = "GetDebugEnabled",
                    set = "SetDebugEnabled",
                },
                openDebug = {
                    type = "execute",
                    name = "Open Debug Console",
                    desc = "Open the shared TwichUI debug console focused on Mythic+ Tools.",
                    order = 3,
                    handler = MPTOptions,
                    func = "OpenDebugConsole",
                },
                timerPreview = {
                    type = "execute",
                    name = "Preview Timer",
                    desc = "Turn on the Mythic+ timer preview from the debugging section.",
                    order = 4,
                    handler = MPTOptions,
                    func = "StartMythicPlusTimerPreview",
                },
                timerBossAnimation = {
                    type = "execute",
                    name = "Debug Boss Animation",
                    desc = "Play the timer's boss-kill animation using the current preview or live frame.",
                    order = 5,
                    handler = MPTOptions,
                    func = "DebugMythicPlusTimerBossAnimation",
                },
                timerUpgradeAnimation = {
                    type = "execute",
                    name = "Debug Upgrade Animation",
                    desc = "Play the timer's keystone upgrade animation using the current preview or live frame.",
                    order = 6,
                    handler = MPTOptions,
                    func = "DebugMythicPlusTimerUpgradeAnimation",
                },
            },
        },
    }

    return optionsTab
end

ConfigurationModule:RegisterConfigurationFunction("Mythic+ Tools", BuildConfiguration)
