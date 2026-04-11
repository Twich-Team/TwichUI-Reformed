---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local Widgets = ConfigurationModule.Widgets

---@type MapTweaksConfigurationOptions
local MapOptions = ConfigurationModule.Options.MapTweaks

---@type GameTweaksConfigurationOptions
local GameOptions = ConfigurationModule.Options.GameTweaks

local function Toggle(path, name, desc, order, options, width, disabled)
    return {
        type = "toggle",
        name = name,
        desc = desc,
        order = order,
        width = width,
        disabled = disabled,
        get = function() return options:GetValue(path, false) == true end,
        set = function(_, value) options:SetValue(path, value == true) end,
    }
end

local function Checkbox(path, name, desc, order, options, disabled)
    local option = Toggle(path, name, desc, order, options, "full", disabled)
    option.uiStyle = "checkbox"
    return option
end

local function Range(path, name, desc, order, options, minValue, maxValue, step, width, disabled)
    return {
        type = "range",
        name = name,
        desc = desc,
        order = order,
        min = minValue,
        max = maxValue,
        step = step,
        width = width,
        disabled = disabled,
        get = function() return options:GetValue(path, minValue) end,
        set = function(_, value) options:SetValue(path, value) end,
    }
end

local function Input(path, name, desc, order, options, width, disabled)
    return {
        type = "input",
        name = name,
        desc = desc,
        order = order,
        width = width,
        disabled = disabled,
        get = function() return tostring(options:GetValue(path, "") or "") end,
        set = function(_, value) options:SetValue(path, value or "") end,
    }
end

local function Select(path, name, desc, order, options, values, width, disabled)
    return {
        type = "select",
        name = name,
        desc = desc,
        order = order,
        width = width,
        disabled = disabled,
        values = values,
        get = function() return options:GetValue(path, next(values)) end,
        set = function(_, value) options:SetValue(path, value) end,
    }
end

local function Color(path, name, desc, order, options, disabled)
    return {
        type = "color",
        name = name,
        desc = desc,
        order = order,
        hasAlpha = true,
        disabled = disabled,
        get = function()
            return options:GetValue({ "tint", "r" }, 0.6), options:GetValue({ "tint", "g" }, 0.6),
                options:GetValue({ "tint", "b" }, 1), options:GetValue({ "tint", "a" }, 1)
        end,
        set = function(_, r, g, b, a)
            options:SetValue({ "tint", "r" }, r)
            options:SetValue({ "tint", "g" }, g)
            options:SetValue({ "tint", "b" }, b)
            options:SetValue({ "tint", "a" }, a)
        end,
    }
end

local function FeatureTab(order, name, description, args)
    local tabArgs = {
        desc = {
            type = "description",
            order = 1,
            name = description,
        },
    }

    for key, value in pairs(args or {}) do
        tabArgs[key] = value
    end

    return {
        type = "group",
        name = name,
        order = order,
        args = tabArgs,
    }
end

local function BuildMapTab()
    return {
        type = "group",
        name = "Map Tweaks",
        order = 1,
        childGroups = "tab",
        args = {
            enable = {
                type = "toggle",
                name = "Enable Map Tweaks",
                desc = "Enable the TwichUI map tweak module.",
                order = 1,
                width = 1.5,
                handler = MapOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            unlock = FeatureTab(10, "Unlock Map", "Manage world map positioning and dragging.", {
                enable = Toggle({ "unlock", "enabled" }, "Enable Unlock Map",
                    "Allow TwichUI to manage the map frame position.", 2, MapOptions, 1.5,
                    function() return not MapOptions:GetEnabled() end),
                movement = Toggle({ "unlock", "movement" }, "Allow Drag Movement",
                    "Allow dragging the unlocked map frame.", 3, MapOptions, 1.5,
                    function()
                        return not MapOptions:GetEnabled() or
                            not MapOptions:GetValue({ "unlock", "enabled" }, false)
                    end),
                reset = {
                    type = "execute",
                    name = "Reset Map Position",
                    desc = "Reset both windowed and maximized map positions.",
                    order = 4,
                    disabled = function() return not MapOptions:GetEnabled() end,
                    func = function() MapOptions:ResetMapPosition() end,
                },
            }),
            exploration = FeatureTab(20, "Exploration", "Reveal unexplored overlays and optionally tint them.", {
                enable = Toggle({ "reveal", "enabled" }, "Enable Exploration Reveal",
                    "Reveal unexplored map tiles using embedded overlay data.", 2, MapOptions, 1.75,
                    function() return not MapOptions:GetEnabled() end),
                tint = Toggle({ "tint", "enabled" }, "Enable Tint",
                    "Tint zone-level unexplored tiles instead of drawing them at full brightness.", 3, MapOptions, 1.5,
                    function()
                        return not MapOptions:GetEnabled() or
                            not MapOptions:GetValue({ "reveal", "enabled" }, false)
                    end),
                color = Color({ "tint" }, "Tint Color", "Choose the unexplored-area tint color and opacity.", 4,
                    MapOptions,
                    function()
                        return not MapOptions:GetEnabled() or
                            not MapOptions:GetValue({ "reveal", "enabled" }, false) or
                            not MapOptions:GetValue({ "tint", "enabled" }, false)
                    end),
            }),
            behavior = FeatureTab(30, "Behavior", "Handle map visibility and reading emotes.", {
                fade = Toggle({ "fade", "enabled" }, "Disable Map Fade", "Keep the map visible while moving.", 2,
                    MapOptions, 1.5, function() return not MapOptions:GetEnabled() end),
                emote = Toggle({ "emote", "enabled" }, "Disable Reading Emote",
                    "Cancel the READ emote when opening the world map.", 3, MapOptions, 1.75,
                    function() return not MapOptions:GetEnabled() end),
            }),
        },
    }
end

local function BuildGameTab()
    local isDisabled = function() return not GameOptions:GetEnabled() end
    local transformsDisabled = function()
        return isDisabled() or not GameOptions:GetValue({ "system", "noTransforms" }, false)
    end

    return {
        type = "group",
        name = "Gameplay Tweaks",
        order = 2,
        childGroups = "tab",
        args = {
            enable = {
                type = "toggle",
                name = "Enable Gameplay Tweaks",
                desc = "Enable the TwichUI gameplay tweak module.",
                order = 1,
                width = 1.75,
                handler = GameOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            summon = FeatureTab(10, "Summons", "Auto-accept summons after a configurable delay.", {
                enable = Toggle({ "automation", "autoAcceptSummon" }, "Enable Auto Accept Summons",
                    "Auto accept summons after the configured delay when out of combat.", 2, GameOptions, 1.9, isDisabled),
                summonDelay = Range({ "automation", "summonDelay" }, "Summon Delay",
                    "Seconds before a summon is accepted automatically.", 3, GameOptions, 0, 15, 1, 1.5,
                    function()
                        return isDisabled() or
                            not GameOptions:GetValue({ "automation", "autoAcceptSummon" }, false)
                    end),
            }),
            resurrection = FeatureTab(20, "Resurrections", "Configure automatic resurrection acceptance.", {
                enable = Toggle({ "automation", "autoAcceptRes" }, "Enable Auto Accept Resurrections",
                    "Automatically accept normal resurrection requests.", 2, GameOptions, 2.0, isDisabled),
                resNoCombat = Toggle({ "automation", "resNoCombat" }, "Skip In-Combat Casters",
                    "Do not auto accept resurrection requests from units that are still in combat.", 3, GameOptions, 1.8,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoAcceptRes" }, false) end),
                resNoAfterlife = Toggle({ "automation", "resNoAfterlife" }, "Skip Afterlife Res",
                    "Ignore afterlife-style resurrection requests.", 4, GameOptions, 1.5,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoAcceptRes" }, false) end),
            }),
            pvpRelease = FeatureTab(30, "PvP Release", "Release automatically in PvP with optional zone exclusions.", {
                enable = Toggle({ "automation", "autoReleasePvP" }, "Enable Auto Release In PvP",
                    "Release automatically in battlegrounds and supported PvP world zones.", 2, GameOptions, 1.9,
                    isDisabled),
                releaseDelay = Range({ "automation", "releaseDelayMs" }, "Release Delay (ms)",
                    "Delay before automatic release. Hold Shift to cancel during the countdown.", 3, GameOptions, 0, 3000,
                    100, 1.7,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoReleasePvP" }, false) end),
                excludeAlterac = Toggle({ "automation", "excludeAlterac" }, "Exclude Alterac Valley",
                    "Do not auto release in Alterac Valley.", 4, GameOptions, 1.5,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoReleasePvP" }, false) end),
                excludeWinterg = Toggle({ "automation", "excludeWintergrasp" }, "Exclude Wintergrasp",
                    "Do not auto release in Wintergrasp.", 5, GameOptions, 1.5,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoReleasePvP" }, false) end),
                excludeTolBarad = Toggle({ "automation", "excludeTolBarad" }, "Exclude Tol Barad",
                    "Do not auto release in Tol Barad.", 6, GameOptions, 1.5,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoReleasePvP" }, false) end),
                excludeAshran = Toggle({ "automation", "excludeAshran" }, "Exclude Ashran",
                    "Do not auto release in Ashran.", 7, GameOptions, 1.5,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoReleasePvP" }, false) end),
            }),
            autoSell = FeatureTab(40, "Auto Sell", "Sell junk automatically with exclusions and summary controls.", {
                enable = Toggle({ "automation", "autoSellJunk" }, "Enable Auto Sell Junk",
                    "Sell poor-quality items automatically when visiting a vendor.", 2, GameOptions, 1.6, isDisabled),
                sellSummary = Toggle({ "automation", "autoSellShowSummary" }, "Show Sell Summary",
                    "Print the total sale value to chat after selling junk.", 3, GameOptions, 1.5,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoSellJunk" }, false) end),
                sellGreyGear = Toggle({ "automation", "autoSellExcludeGreyGear" }, "Keep Unbound Grey Gear",
                    "Do not auto sell unbound grey armor and weapons.", 4, GameOptions, 1.75,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoSellJunk" }, false) end),
                sellExclude = Input({ "automation", "autoSellExcludeList" }, "Sell Exclusions",
                    "Comma-separated item IDs that should never be sold automatically.", 5, GameOptions, 2.0,
                    function() return isDisabled() or not GameOptions:GetValue({ "automation", "autoSellJunk" }, false) end),
            }),
            autoRepair = FeatureTab(50, "Auto Repair",
                "Repair gear automatically and control whether guild funds are used.", {
                    enable = Toggle({ "automation", "autoRepairGear" }, "Enable Auto Repair Gear",
                        "Repair gear automatically when interacting with a repair-capable merchant.", 2, GameOptions,
                        1.75,
                        isDisabled),
                    repairGuild = Toggle({ "automation", "autoRepairGuildFunds" }, "Use Guild Funds",
                        "Use guild repair funds when available.", 3, GameOptions, 1.5,
                        function()
                            return isDisabled() or
                                not GameOptions:GetValue({ "automation", "autoRepairGear" }, false)
                        end),
                    repairSummary = Toggle({ "automation", "autoRepairShowSummary" }, "Show Repair Summary",
                        "Print the repair cost to chat.", 4, GameOptions, 1.5,
                        function()
                            return isDisabled() or
                                not GameOptions:GetValue({ "automation", "autoRepairGear" }, false)
                        end),
                }),
            partyInvites = FeatureTab(60, "Party Invites", "Accept trusted invites or block untrusted ones.", {
                acceptFriends = Toggle({ "social", "acceptPartyFriends" }, "Auto Accept Trusted Party Invites",
                    "Automatically accept party invites from trusted players when not queued.", 2, GameOptions, 2.1,
                    isDisabled),
                noParty = Toggle({ "social", "noPartyInvites" }, "Block Untrusted Party Invites",
                    "Decline party invites from players who are not trusted.", 3, GameOptions, 1.9, isDisabled),
                noRequested = Toggle({ "social", "noRequestedInvites" }, "Block Requested Invites",
                    "Decline requests to invite another player to your group unless they are trusted.", 4, GameOptions,
                    1.8, isDisabled),
            }),
            duels = FeatureTab(70, "Duels", "Handle duel and pet battle duel requests.", {
                noDuel = Toggle({ "social", "noDuelRequests" }, "Block Duel Requests",
                    "Decline duel requests unless the challenger is trusted.", 2, GameOptions, 1.5, isDisabled),
                noPetDuel = Toggle({ "social", "noPetDuels" }, "Block Pet Battle Duels",
                    "Decline pet battle duel requests unless the challenger is trusted.", 3, GameOptions, 1.75,
                    isDisabled),
            }),
            quests = FeatureTab(80, "Quest Sharing", "Handle shared quests and quest sync invitations.", {
                noShared = Toggle({ "social", "noSharedQuests" }, "Block Shared Quests",
                    "Decline shared quests unless the sender is trusted.", 2, GameOptions, 1.5, isDisabled),
                sync = Toggle({ "social", "syncFromFriends" }, "Auto Accept Quest Sync",
                    "Automatically accept quest session invites from trusted players.", 3, GameOptions, 1.75, isDisabled),
            }),
            roleChecks = FeatureTab(90, "Role Checks", "Automatically confirm group role checks.", {
                role = Toggle({ "social", "autoConfirmRole" }, "Enable Auto Confirm Role Check",
                    "Automatically confirm ready role checks.", 2, GameOptions, 1.8, isDisabled),
            }),
            whisperInvites = FeatureTab(100, "Whisper Invites",
                "Invite players when they whisper your configured keyword.", {
                    whisper = Toggle({ "social", "inviteFromWhisper" }, "Enable Invite From Whisper",
                        "Invite players who whisper the configured keyword.", 2, GameOptions, 1.7, isDisabled),
                    whisperKey = Input({ "social", "inviteKeyword" }, "Invite Keyword",
                        "Whisper keyword used to request an invite.", 3, GameOptions, 1.4,
                        function()
                            return isDisabled() or
                                not GameOptions:GetValue({ "social", "inviteFromWhisper" }, false)
                        end),
                    whisperFriends = Toggle({ "social", "inviteFriendsOnly" }, "Trusted Players Only",
                        "Only accept whisper invites from trusted players.", 4, GameOptions, 1.5,
                        function()
                            return isDisabled() or
                                not GameOptions:GetValue({ "social", "inviteFromWhisper" }, false)
                        end),
                }),
            trust = FeatureTab(110, "Trust Sources", "Choose which player relationships count as trusted.", {
                noFriend = Toggle({ "social", "noFriendRequests" }, "Block Friend Requests",
                    "Automatically decline Battle.net friend invites.", 2, GameOptions, 1.5, isDisabled),
                guild = Toggle({ "social", "friendlyGuild" }, "Trust Guild Members",
                    "Treat guild members as trusted for social automation.", 3, GameOptions, 1.5, isDisabled),
                communities = Toggle({ "social", "friendlyCommunities" }, "Trust Communities",
                    "Treat community members as trusted for social automation.", 4, GameOptions, 1.5, isDisabled),
            }),
            popups = FeatureTab(150, "Alerts & Popups", "Hide or suppress Blizzard popups and banners.", {
                noAlerts = Toggle({ "frames", "noAlerts" }, "Hide Alerts", "Hide standard Blizzard alert toasts.", 2,
                    GameOptions, 1.25, isDisabled),
                bodyguard = Toggle({ "frames", "hideBodyguard" }, "Hide Bodyguard Gossip",
                    "Automatically close bodyguard gossip windows.", 3, GameOptions, 1.5, isDisabled),
                talking = Toggle({ "frames", "hideTalkingFrame" }, "Hide Talking Head", "Hide Talking Head popups.", 4,
                    GameOptions, 1.4, isDisabled),
                bossBanner = Toggle({ "frames", "hideBossBanner" }, "Hide Boss Banner", "Suppress boss banner popups.", 5,
                    GameOptions, 1.5, isDisabled),
                eventToasts = Toggle({ "frames", "hideEventToasts" }, "Hide Event Toasts", "Suppress event toast popups.",
                    6, GameOptions, 1.5, isDisabled),
            }),
            bars = FeatureTab(160, "Bars & Buttons", "Hide selected Blizzard bars, buttons, and rest visuals.", {
                cleanup = Toggle({ "frames", "hideCleanupBtns" }, "Hide Clean-Up Buttons",
                    "Hide the bag and bank clean-up buttons.", 2, GameOptions, 1.6, isDisabled),
                classBar = Toggle({ "frames", "noClassBar" }, "Hide Stance Bar", "Hide the Blizzard stance/form bar.", 3,
                    GameOptions, 1.5, isDisabled),
                rested = Toggle({ "frames", "noRestedSleep" }, "Hide Rested Sleep",
                    "Hide the sleeping/rested animation on the Blizzard player frame.", 4, GameOptions, 1.5, isDisabled),
            }),
            visuals = FeatureTab(170, "Visual Effects", "Control screen effects, weather density, and camera distance.",
                {
                    glow = Toggle({ "system", "noScreenGlow" }, "Disable Screen Glow",
                        "Disable the ffxGlow post-process effect.", 2, GameOptions, 1.5, isDisabled),
                    effects = Toggle({ "system", "noScreenEffects" }, "Disable Screen Effects",
                        "Disable death, nether, and Venari screen effects.", 3, GameOptions, 1.75, isDisabled),
                    weather = Toggle({ "system", "setWeatherDensity" }, "Set Weather Density",
                        "Control the density of weather effects.", 4, GameOptions, 1.5, isDisabled),
                    weatherLevel = Select({ "system", "weatherLevel" }, "Weather Density", "Weather density level.", 5,
                        GameOptions, { [0] = "Off", [1] = "Low", [2] = "Medium", [3] = "High" }, 1.5,
                        function()
                            return isDisabled() or
                                not GameOptions:GetValue({ "system", "setWeatherDensity" }, false)
                        end),
                    zoom = Toggle({ "system", "maxCameraZoom" }, "Increase Camera Zoom",
                        "Raise the maximum camera zoom distance.", 6, GameOptions, 1.6, isDisabled),
                }),
            audio = FeatureTab(180, "Audio", "Mute selected sounds and keep audio synced to output devices.", {
                restedEmotes = Toggle({ "system", "noRestedEmotes" }, "Silence Rested Emotes",
                    "Mute emote sounds while resting, pet battling, or in selected social zones.", 2, GameOptions, 1.8,
                    isDisabled),
                audioSync = Toggle({ "system", "keepAudioSynced" }, "Keep Audio Synced",
                    "Restart the sound system when the OS output device changes.", 3, GameOptions, 1.6, isDisabled),
                muteGame = Toggle({ "system", "muteGameSounds" }, "Mute Game Sounds",
                    "Mute the configured general sound file IDs.", 4, GameOptions, 1.5, isDisabled),
                muteGameIds = Input({ "system", "muteGameSoundIDs" }, "Game Sound IDs",
                    "Comma-separated sound file IDs to mute while Game Sounds is enabled.", 5, GameOptions, 2.0,
                    function() return isDisabled() or not GameOptions:GetValue({ "system", "muteGameSounds" }, false) end),
                muteLocationPings = Toggle({ "system", "mutePingSounds" }, "Mute Location Ping Sounds",
                    "Silence the Blizzard ping-system sound that plays when players ping map or world locations.", 6,
                    GameOptions, 1.8, isDisabled),
                toySection = {
                    type = "group",
                    name = "Toys",
                    order = 7,
                    args = {
                        muteToys = Toggle({ "system", "muteToySounds" }, "Mute Toy Sounds",
                            "Mute the configured toy-related sound file IDs.", 1, GameOptions, 1.5, isDisabled),
                        toySoundIds = Input({ "system", "muteToySoundIDs" }, "Toy Sound IDs",
                            "Comma-separated toy sound file IDs to mute while Toy Sounds is enabled.", 2, GameOptions,
                            2.0,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteToySounds" }, false)
                            end),
                        intro = {
                            type = "description",
                            order = 3,
                            name =
                            "Enable common noisy toy groups here to add their known sound IDs automatically while Toy Sounds is enabled.",
                        },
                        anima = Checkbox({ "system", "presetToys", "anima" }, "Experimental Anima Cell",
                            "Mute the Experimental Anima Cell toy loop.", 4, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteToySounds" }, false)
                            end),
                        balls = Checkbox({ "system", "presetToys", "balls" }, "Foot Balls",
                            "Mute Foot Ball toy impact and net sounds.", 5, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteToySounds" }, false)
                            end),
                        harp = Checkbox({ "system", "presetToys", "harp" }, "Fae Harp",
                            "Mute the Fae Harp toy and shared harp emitter sounds.", 6, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteToySounds" }, false)
                            end),
                        meerah = Checkbox({ "system", "presetToys", "meerah" }, "Meerah's Jukebox",
                            "Mute Meerah's Jukebox voice line audio.", 7, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteToySounds" }, false)
                            end),
                    },
                },
                mountSection = {
                    type = "group",
                    name = "Mount",
                    order = 8,
                    args = {
                        muteMounts = Toggle({ "system", "muteMountSounds" }, "Mute Mount Sounds",
                            "Mute the configured mount-related sound file IDs.", 1, GameOptions, 1.5, isDisabled),
                        mountSoundIds = Input({ "system", "muteMountSoundIDs" }, "Mount Sound IDs",
                            "Comma-separated mount sound file IDs to mute.", 2, GameOptions, 2.0,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                        intro = {
                            type = "description",
                            order = 3,
                            name =
                            "Enable common noisy mount families here to add their known sound IDs automatically while Mount Sounds is enabled.",
                        },
                        bikes = Checkbox({ "system", "presetMounts", "bikes" }, "Bikes",
                            "Mute common chopper and motorcycle mount sounds.", 4, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                        brooms = Checkbox({ "system", "presetMounts", "brooms" }, "Brooms",
                            "Mute broom mount summon, takeoff, and landing sounds.", 5, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                        calamitousCarrion = Checkbox({ "system", "presetMounts", "calamitousCarrion" },
                            "Calamitous Carrion",
                            "Mute the constant hex-eagle chirps and vocalizations used by Calamitous Carrion.", 6,
                            GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                        dragonriding = Checkbox({ "system", "presetMounts", "dragonriding" }, "Dragonriding",
                            "Mute curated dragonriding and drake family sounds.", 7, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                        gyrocopters = Checkbox({ "system", "presetMounts", "gyrocopters" }, "Gyrocopters",
                            "Mute gyrocopter and airplane-like mount loops and gear shifts.", 8, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                        rabbits = Checkbox({ "system", "presetMounts", "rabbits" }, "Rabbits",
                            "Mute divine rabbit mount hops and fidgets.", 9, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                        rockets = Checkbox({ "system", "presetMounts", "rockets" }, "Rockets",
                            "Mute rocket mount movement and idle sounds.", 10, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                        travelers = Checkbox({ "system", "presetMounts", "travelers" }, "Travelers",
                            "Mute traveling vendor greetings and farewells on vendor mounts.", 11, GameOptions,
                            function()
                                return isDisabled() or
                                    not GameOptions:GetValue({ "system", "muteMountSounds" }, false)
                            end),
                    },
                },
                muteCustom = Toggle({ "system", "muteCustomSounds" }, "Mute Custom Sounds",
                    "Mute any custom sound IDs you provide.", 9, GameOptions, 1.5, isDisabled),
                muteCustomIds = Input({ "system", "muteCustomSoundIDs" }, "Custom Sound IDs",
                    "Comma-separated custom sound file IDs to mute.", 10, GameOptions, 2.0,
                    function() return isDisabled() or not GameOptions:GetValue({ "system", "muteCustomSounds" }, false) end),
            }),
            interactions = FeatureTab(200, "Loot & Interaction",
                "Reduce confirmation friction for loot, movies, and item destruction.", {
                    loot = Toggle({ "system", "noConfirmLoot" }, "Disable Loot Warnings",
                        "Accept loot-roll and item-trade confirmation popups automatically.", 2, GameOptions, 1.75,
                        isDisabled),
                    movies = Toggle({ "system", "fasterMovieSkip" }, "Faster Movie Skip",
                        "Skip cinematics and movies without the extra confirmation step.", 3, GameOptions, 1.6,
                        isDisabled),
                    destroy = Toggle({ "system", "easyItemDestroy" }, "Easy Item Destroy",
                        "Remove the need to type delete when destroying items.", 4, GameOptions, 1.6, isDisabled),
                }),
            transforms = FeatureTab(210, "Transforms", "Cancel selected transform auras automatically.", {
                enable = Toggle({ "system", "noTransforms" }, "Enable Remove Transforms",
                    "Cancel the selected transform auras automatically, including curated Leatrix-style presets.", 2,
                    GameOptions, 1.75, isDisabled),
                craftingSection = {
                    type = "group",
                    name = "Crafting Professions",
                    order = 3,
                    args = {
                        blacksmithing = Checkbox({ "system", "presetTransforms", "blacksmithing" }, "Blacksmithing",
                            "Remove the Suited for Smithing transform when it is applied.", 1, GameOptions,
                            transformsDisabled),
                        jewelcrafting = Checkbox({ "system", "presetTransforms", "jewelcrafting" }, "Jewelcrafting",
                            "Remove the An Eye For Shine transform when it is applied.", 2, GameOptions,
                            transformsDisabled),
                        tailoring = Checkbox({ "system", "presetTransforms", "tailoring" }, "Tailoring",
                            "Remove the Wrapped Up In Weaving transform when it is applied.", 3, GameOptions,
                            transformsDisabled),
                        engineering = Checkbox({ "system", "presetTransforms", "engineering" }, "Engineering",
                            "Remove the Ready To Build transform when it is applied.", 4, GameOptions,
                            transformsDisabled),
                        enchanting = Checkbox({ "system", "presetTransforms", "enchanting" }, "Enchanting",
                            "Remove the A Looker's Charm transform when it is applied.", 5, GameOptions,
                            transformsDisabled),
                        alchemy = Checkbox({ "system", "presetTransforms", "alchemy" }, "Alchemy",
                            "Remove the Spark of Madness transform when it is applied.", 6, GameOptions,
                            transformsDisabled),
                        inscription = Checkbox({ "system", "presetTransforms", "inscription" }, "Inscription",
                            "Remove the Artist's Duds transform when it is applied.", 7, GameOptions,
                            transformsDisabled),
                        leatherworking = Checkbox({ "system", "presetTransforms", "leatherworking" },
                            "Leatherworking", "Remove the Sculpting Leather Finery transform when it is applied.",
                            8, GameOptions, transformsDisabled),
                    },
                },
                gatheringSection = {
                    type = "group",
                    name = "Gathering Professions",
                    order = 4,
                    args = {
                        herbalism = Checkbox({ "system", "presetTransforms", "herbalism" }, "Herbalism",
                            "Remove the A Cultivator's Colors transform when it is applied.", 1, GameOptions,
                            transformsDisabled),
                        mining = Checkbox({ "system", "presetTransforms", "mining" }, "Mining",
                            "Remove the Rockin' Mining Gear transform when it is applied.", 2, GameOptions,
                            transformsDisabled),
                        skinning = Checkbox({ "system", "presetTransforms", "skinning" }, "Skinning",
                            "Remove the Dressed To Kill transform when it is applied.", 3, GameOptions,
                            transformsDisabled),
                    },
                },
                secondarySection = {
                    type = "group",
                    name = "Secondary Professions",
                    order = 5,
                    args = {
                        cooking = Checkbox({ "system", "presetTransforms", "cooking" }, "Cooking",
                            "Remove the What's Cookin', Good Lookin' transform when it is applied.", 1, GameOptions,
                            transformsDisabled),
                        fishing = Checkbox({ "system", "presetTransforms", "fishing" }, "Fishing",
                            "Remove the Fishing For Attention transform when it is applied.", 2, GameOptions,
                            transformsDisabled),
                    },
                },
                toySection = {
                    type = "group",
                    name = "Toys",
                    order = 6,
                    args = {
                        aqir = Checkbox({ "system", "presetTransforms", "aqir" }, "Aqir Egg Cluster",
                            "Remove the Aqir Egg Cluster transform when it is applied.", 1, GameOptions,
                            transformsDisabled),
                        atomic = Checkbox({ "system", "presetTransforms", "atomic" }, "Atomic Recalibrator",
                            "Remove the Atomic Recalibrator transform when it is applied.", 2, GameOptions,
                            transformsDisabled),
                        atomGoblin = Checkbox({ "system", "presetTransforms", "atomGoblin" },
                            "Atomic Regoblinator", "Remove the Atomic Regoblinator transform when it is applied.",
                            3, GameOptions, transformsDisabled),
                        blight = Checkbox({ "system", "presetTransforms", "blight" }, "Detoxified Blight Grenade",
                            "Remove the Detoxified Blight Grenade transform when it is applied.", 4, GameOptions,
                            transformsDisabled),
                        witch = Checkbox({ "system", "presetTransforms", "witch" }, "Lucille's Sewing Needle",
                            "Remove the Lucille's Sewing Needle transform when it is applied.", 5, GameOptions,
                            transformsDisabled),
                        spraybots = Checkbox({ "system", "presetTransforms", "spraybots" }, "Spraybots",
                            "Remove Spraybot transforms when they are applied.", 6, GameOptions, transformsDisabled),
                    },
                },
                eventSection = {
                    type = "group",
                    name = "Events",
                    order = 7,
                    args = {
                        hallowed = Checkbox({ "system", "presetTransforms", "hallowed" },
                            "Hallow's End: Hallowed Wand",
                            "Remove Hallowed Wand transforms when they are applied.", 1, GameOptions,
                            transformsDisabled),
                        lantern = Checkbox({ "system", "presetTransforms", "lantern" },
                            "Hallow's End: Weighted Jack-o'-Lantern",
                            "Remove the Weighted Jack-o'-Lantern transform when it is applied.", 2, GameOptions,
                            transformsDisabled),
                        nobleBunny = Checkbox({ "system", "presetTransforms", "nobleBunny" },
                            "Noblegarden: Noblegarden Bunny",
                            "Remove Noblegarden bunny transforms when they are applied.", 3, GameOptions,
                            transformsDisabled),
                        turkey = Checkbox({ "system", "presetTransforms", "turkey" },
                            "Pilgrim's Bounty: Turkey Shooter",
                            "Remove the Turkey Shooter transform when it is applied.", 4, GameOptions,
                            transformsDisabled),
                    },
                },
                itemSection = {
                    type = "group",
                    name = "Items",
                    order = 8,
                    args = {
                        cursedPickaxe = Checkbox({ "system", "presetTransforms", "cursedPickaxe" },
                            "Cursed Pickaxe",
                            "Remove the Cursed Pickaxe transform when it is applied.", 1, GameOptions,
                            transformsDisabled),
                        noggenfogger = Checkbox({ "system", "presetTransforms", "noggenfogger" },
                            "Noggenfogger Elixir",
                            "Remove the slow fall and shrink Noggenfogger effects while keeping the skeleton transform intact.",
                            2, GameOptions, transformsDisabled),
                    },
                },
                transformIDs = Input({ "system", "transformSpellIDs" }, "Custom Transform Spell IDs",
                    "Comma-separated aura spell IDs to cancel in addition to the selected presets.", 9, GameOptions,
                    2.0, transformsDisabled),
            }),
            tradingPost = FeatureTab(220, "Trading Post",
                "Disable preview toggles automatically when opening the Trading Post.", {
                    perksCombat = Toggle({ "system", "addOptNoCombatBox" }, "Disable Combat Preview",
                        "Uncheck the Trading Post combat animation toggle when the frame opens.", 2, GameOptions, 1.8,
                        isDisabled),
                    perksMount = Toggle({ "system", "addOptNoMountBox" }, "Disable Mount Special Preview",
                        "Uncheck the Trading Post mount-special preview toggle when the frame opens.", 3, GameOptions,
                        2.0,
                        isDisabled),
                }),
            errorText = FeatureTab(230, "Error Messages", "Control suppression of Blizzard UI error spam.", {
                errors = Toggle({ "text", "hideErrorMessages" }, "Hide Error Messages",
                    "Suppress most UI error spam while keeping critical errors optional.", 2, GameOptions, 1.5,
                    isDisabled),
                critical = Toggle({ "text", "showCriticalErrors" }, "Keep Critical Errors",
                    "Keep inventory, death, and queue-critical error messages visible.", 3, GameOptions, 1.5,
                    function() return isDisabled() or not GameOptions:GetValue({ "text", "hideErrorMessages" }, false) end),
            }),
        },
    }
end

local function BuildConfiguration()
    local section = Widgets.NewConfigurationSection(36, "World & Gameplay Tweaks")
    section.args = {
        title = Widgets.TitleWidget(0, "World & Gameplay Tweaks"),
        desc = {
            type = "description",
            order = 1,
            name = "TwichUI-native reimplementations of selected Leatrix Maps and Leatrix Plus quality-of-life features.",
        },
        mapTweaks = BuildMapTab(),
        gameTweaks = BuildGameTab(),
    }
    return section
end

ConfigurationModule:RegisterConfigurationFunction("World & Gameplay Tweaks", BuildConfiguration)
