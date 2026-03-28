---@diagnostic disable: undefined-field
--[[
    TwichUI Setup Wizard — Layouts & Theme Presets

    ══ HOW TO ADD A LAYOUT ══════════════════════════════════════════════════════
      1. Arrange your UI exactly as you want the layout to look.
      2. Run:  /tui wizard capture <id> <name>
         e.g.: /tui wizard capture standard_wide "Standard Wide"
      3. Copy the output from the debug console (/tui debug wizard).
      4. Paste the table into AVAILABLE_LAYOUTS below.
      5. Increment WIZARD_VERSION in SetupWizardModule.lua so existing users
         see the layout picker again.

    ══ HOW TO ADD A THEME PRESET ════════════════════════════════════════════════
      Add a new entry to THEME_PRESETS. Keys map directly to ThemeModule defaults.
      Only the keys you define will override the ThemeModule defaults — unset
      keys fall through to the DEFAULT_THEME in ThemeModule.

    ══ LAYOUT DATA SCHEMA ═══════════════════════════════════════════════════════
      frames = {
          [frameKey] = {
              anchor = "BOTTOMLEFT",   -- WoW anchor point constant
              x      = 0.100,          -- x offset as fraction of screen width
              y      = 0.020,          -- y offset as fraction of screen height
              w      = 0.180,          -- (optional) width  as fraction of screen width
              h      = 0.022,          -- (optional) height as fraction of screen height
          },
          ...
      }
      Frame keys must match keys registered via SetupWizardModule:RegisterLayoutFrame().
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type SetupWizardModule
local SetupWizardModule = T:GetModule("SetupWizard")

-- ─── Theme presets ─────────────────────────────────────────────────────────
-- Adding a new entry here automatically populates the theme picker in the wizard.

SetupWizardModule.THEME_PRESETS = {
    {
        id              = "twich_default",
        name            = "TwichUI",
        description     = "The signature teal and gold scheme.",
        primaryColor    = { 0.10, 0.72, 0.74 },
        accentColor     = { 0.96, 0.76, 0.24 },
        backgroundColor = { 0.05, 0.06, 0.08 },
        borderColor     = { 0.24, 0.26, 0.32 },
    },
    {
        id              = "midnight",
        name            = "Midnight",
        description     = "Deep violet with a cobalt accent.",
        primaryColor    = { 0.47, 0.30, 0.88 },
        accentColor     = { 0.29, 0.62, 1.00 },
        backgroundColor = { 0.04, 0.04, 0.10 },
        borderColor     = { 0.22, 0.18, 0.38 },
    },
    {
        id              = "crimson",
        name            = "Crimson",
        description     = "Bold red tones for a combat-ready feel.",
        primaryColor    = { 0.85, 0.22, 0.22 },
        accentColor     = { 0.96, 0.74, 0.22 },
        backgroundColor = { 0.08, 0.04, 0.04 },
        borderColor     = { 0.38, 0.18, 0.18 },
    },
    {
        id              = "verdant",
        name            = "Verdant",
        description     = "Natural greens for a calm, composed look.",
        primaryColor    = { 0.29, 0.76, 0.50 },
        accentColor     = { 0.74, 0.94, 0.18 },
        backgroundColor = { 0.04, 0.07, 0.05 },
        borderColor     = { 0.18, 0.30, 0.20 },
    },
}

-- ─── Layout definitions ────────────────────────────────────────────────────
-- Adding a new entry here automatically populates the layout picker in the wizard.

SetupWizardModule.AVAILABLE_LAYOUTS = {
    -- Captured: 2026-03-27  |  3440x1440  |  layout id: standard
    -- Captured: 2026-03-27  |  3440x1440  |  layout id: standard
    -- Captured: 2026-03-27  |  3440x1440  |  layout id: standard
    {
        id          = "standard",
        name        = "Standard",
        description = "Add a description here.",
        role        = "any", -- "any" | "dps" | "healer" | "tank"
        frames      = {
            ChatFrame1 = { x = 0.00233, y = 0.02639, w = 0.17035, h = 0.16458 },
        },
        apply       = function()
            local T = unpack(_G.TwichRx)
            T:GetModule("SetupWizard"):RestoreConfigSnapshot({
                bestInSlot = {
                    displayTime = 30
                },
                chatEnhancement = {
                    ["Battle.netChatAlertEnabled"] = true,
                    PartyChatAlertEnabled = false,
                    WhisperChatAlertEnabled = true,
                    _chatBgExplicitlySet = true,
                    _chatBorderExplicitlySet = true,
                    _chatFontExplicitlySet = true,
                    _chatSchemaV = 4,
                    _tabAccentExplicitlySet = true,
                    _tabBorderExplicitlySet = true,
                    abbreviations = {},
                    alertsEnabled = true,
                    channelColors = {},
                    chatBgColor = {
                        a = 1,
                        b = 0.0784314,
                        g = 0.0666667,
                        r = 0.0588235
                    },
                    chatBorderColor = {
                        a = 0.85,
                        b = 0.32,
                        g = 0.26,
                        r = 0.24
                    },
                    chatFont = "Inter",
                    chatFontSize = 14,
                    chatHeight = 237,
                    chatLocked = true,
                    chatPositionX = 8,
                    chatPositionY = 38,
                    chatWidth = 586,
                    classIconStyle = "pixel",
                    controlButtons = {},
                    headerBgColor = {
                        a = 0.9,
                        b = 0.12,
                        g = 0.09,
                        r = 0.06
                    },
                    headerDatatext = {
                        enabled = true,
                        fontSize = 14,
                        slot1 = "TwichUI: Friends",
                        slotWidth = 80
                    },
                    hideHeader = true,
                    hideRealm = true,
                    messageFadeMinAlpha = 0,
                    messageFadesEnabled = true,
                    msgBgColor = {
                        a = 1,
                        b = 0.0784314,
                        g = 0.0666667,
                        r = 0.0588235
                    },
                    routingEntries = {},
                    rowGap = 2,
                    showClassIcons = true,
                    tabAccentColor = {
                        b = 0.74902,
                        g = 0.537255,
                        r = 0.458824
                    },
                    tabBorderColor = {
                        b = 0.211765,
                        g = 0.168627,
                        r = 0.145098
                    },
                    tabFontSize = 14,
                    tabNameFade = true,
                    tabStyle = "unified",
                    timestampFormat = "%I:%M %p",
                    timestampWidth = 70
                },
                chores = {
                    categories = {},
                    countBountifulDelvesTowardTotal = false,
                    countProfessionsTowardTotal = false,
                    preyDifficulties = {
                        hard = false,
                        normal = false
                    },
                    raidWings = {
                        ["3155"] = false,
                        ["3160"] = false
                    },
                    trackBountifulDelves = false
                },
                datatext = {
                    auctionMountShortcutEnabled = true,
                    chores = {
                        doneTextColor = { 0.2, 0.82, 0.32, 1 },
                        textColor = { 1, 1, 1, 1 },
                        tooltipEntryFont = "Inter",
                        tooltipHeaderFont = "Inter Bold",
                        tracker = {
                            collapsedSections = {},
                            locked = true,
                            position = {
                                point = "TOPLEFT",
                                relativePoint = "TOPLEFT",
                                x = 0,
                                y = 0
                            },
                            size = {},
                            visible = false
                        },
                        trackerMode = "minimal"
                    },
                    currencies = {
                        customDatatexts = {},
                        displayStyle = "ICON",
                        displayedCurrency = "3347",
                        showGoldInTooltip = false,
                        showMax = true,
                        textColor = { 1, 1, 1, 1 },
                        tooltipCurrencyIDs = { 3383, 3343, 3341, 3345, 3347 }
                    },
                    enabled = true,
                    friends = {
                        countWoWOnly = true,
                        textColor = { 0.4, 0.86, 0.52, 1 }
                    },
                    goblin = {
                        displayMode = "compact",
                        enabledAddons = {}
                    },
                    mail = {
                        iconOnly = false,
                        textColor = { 0.75, 0.78, 0.84, 1 }
                    },
                    mounts = {
                        auctionMountID = 2265,
                        textColor = { 1, 1, 1, 1 },
                        vendorMountID = 2237
                    },
                    mythicplus = {},
                    portals = {
                        favoriteHearthstoneItemID = 235016,
                        textColor = { 1, 1, 1, 1 }
                    },
                    specialization = {},
                    standalone = {
                        _styleSchemaV = 2,
                        enabled = true,
                        locked = true,
                        panels = {
                            panel1 = {
                                enabled = true,
                                height = 30,
                                id = "panel1",
                                name = "Primary Panel",
                                point = "BOTTOM",
                                relativePoint = "BOTTOM",
                                segments = 1,
                                slot1 = "NONE",
                                slot2 = "TwichUI: Mythic+",
                                slot3 = "TwichUI: Portals",
                                slot4 = "NONE",
                                slot5 = "NONE",
                                style = {},
                                useStyleOverrides = false,
                                width = 3440,
                                x = 0,
                                y = 0
                            },
                            panel2 = {
                                enabled = true,
                                height = 30,
                                id = "panel2",
                                name = "Left Side",
                                point = "BOTTOMLEFT",
                                relativePoint = "BOTTOMLEFT",
                                segments = 5,
                                slot1 = "TwichUI: Time",
                                slot2 = "TwichUI: Specialization",
                                slot3 = "TwichUI: Mythic+",
                                slot4 = "TwichUI: Chores",
                                slot5 = "TwichUI: Currencies",
                                style = {
                                    menuFont = "Inter",
                                    tooltipFont = "Inter",
                                    tooltipFontSize = 12
                                },
                                transparentTheme = true,
                                useStyleOverrides = true,
                                width = 602,
                                x = 0,
                                y = 0
                            },
                            panel3 = {
                                enabled = true,
                                height = 28,
                                id = "panel3",
                                name = "Right Side",
                                point = "BOTTOMRIGHT",
                                relativePoint = "BOTTOMRIGHT",
                                segments = 5,
                                slot1 = "TwichUI: System",
                                slot2 = "TwichUI: Portals",
                                slot3 = "TwichUI: Mount",
                                slot4 = "TwichUI: Mail",
                                slot5 = "TwichUI: Gold Goblin",
                                style = {
                                    menuFont = "Inter",
                                    tooltipFont = "Inter",
                                    tooltipFontSize = 12
                                },
                                transparentTheme = true,
                                useStyleOverrides = true,
                                width = 602,
                                x = 0,
                                y = 0
                            }
                        },
                        style = {
                            tooltipFont = "Inter"
                        }
                    },
                    system = {
                        showLabels = false,
                        showLatencySource = false,
                        textColor = { 1, 1, 1, 1 }
                    },
                    time = {
                        amPmColor = { 0.96, 0.76, 0.24, 1 },
                        customAmPmColor = false,
                        localTime = true,
                        textColor = { 1, 1, 1, 1 },
                        twentyFourHour = false
                    },
                    vendorMountShortcutEnabled = true
                },
                dungeonTracking = {
                    classIconStyle = "pixel",
                    enabled = true,
                    leavePhrase = "tyfp"
                },
                easyFish = {
                    enabled = false
                },
                gossipHotkeys = {
                    enabled = true
                },
                mythicPlusTools = {
                    _mptSchemaV = 1,
                    autoStartDungeon = true,
                    deathNotificationSound = "TwichUI Alert 4",
                    enabled = true,
                    interruptTrackerEnabled = false,
                    interruptX = 867,
                    interruptY = 45,
                    mythicPlusTimerBarHeight = 28,
                    mythicPlusTimerFontSize = 14,
                    mythicPlusTimerLocked = true,
                    mythicPlusTimerNotificationSound = "TwichUI Alert 1",
                    mythicPlusTimerRowGap = 0,
                    mythicPlusTimerStyle = "transparent",
                    timerHeight = 311,
                    timerWidth = 360,
                    timerX = -1540,
                    timerY = 564
                },
                notificationPanel = {
                    anchorLocked = true,
                    anchorX = -1078,
                    anchorY = 15.9997,
                    chatDockMode = "top",
                    friendsNotificationIconStyle = "pixel",
                    growthDirection = "UP",
                    panelWidth = 600,
                    useFriendNoteAsName = true
                },
                questAutomation = {
                    automaticTurnIn = true,
                    enabled = true,
                    questType = {
                        meta = true,
                        repeatable = true
                    }
                },
                smartMount = {
                    dismountIfMounted = true,
                    enabled = true,
                    flyingMount = 2733,
                    groundMount = 885,
                    smartMountKeybinding = "SHIFT-SPACE"
                },
                teleports = {
                    collapsedSections = {},
                    enabled = true,
                    popupPosition = {
                        point = "BOTTOMRIGHT",
                        relativePoint = "BOTTOMRIGHT",
                        x = -585.399,
                        y = 256
                    }
                },
                theme = {
                    accentColor = { 0.94902, 0.776471, 0.439216 },
                    backgroundAlpha = 1,
                    backgroundColor = { 0.0823529, 0.0941177, 0.12549 },
                    borderAlpha = 0.85,
                    borderColor = { 0.24, 0.26, 0.32 },
                    classIconStyle = "pixel",
                    globalFont = "Inter Bold",
                    primaryColor = { 0.458824, 0.537255, 0.74902 },
                    statusBarTexture = "TwichUI Bright"
                },
            })
        end,
    },
    -- Paste the block above into AVAILABLE_LAYOUTS in Layouts.lua
    -- Paste the block above into AVAILABLE_LAYOUTS in Layouts.lua
    -- Paste the block above into AVAILABLE_LAYOUTS in Layouts.lua
    -- {
    --     id          = "standard",
    --     name        = "Standard",
    --     description =
    --     "A clean, versatile setup for all content — Mythic+ and Raiding included. Positions scale automatically to your screen.",
    --     role        = "any",
    --     -- Frame positions populated via /tui wizard capture.
    --     -- Keys must match RegisterLayoutFrame() calls in modules.
    --     frames      = {
    --         -- Example (fill in after capture):
    --         -- DatatextPanelLeft  = { anchor = "BOTTOMLEFT",  x =  0.01,  y = 0.02, w = 0.16, h = 0.022 },
    --         -- DatatextPanelRight = { anchor = "BOTTOMRIGHT", x = -0.01,  y = 0.02, w = 0.16, h = 0.022 },

    --     },
    --     --- Called after frame positions are applied.
    --     --- Use this to configure module-level settings (enable/disable features, set
    --     --- datatext lists, etc.) that form part of this layout's character.
    --     apply       = function()
    --         -- e.g. CM.Options.Datatext:SetModuleEnabled(true)
    --     end,
    -- },
    -- ── Future layouts go here ──────────────────────────────────────────────
    -- After adding a layout, increment WIZARD_VERSION in SetupWizardModule.lua.
    --
    -- {
    --     id          = "healer",
    --     name        = "Healer",
    --     description = "Expanded raid frames and party-focused panel placement.",
    --     role        = "healer",
    --     frames      = { ... },
    --     apply       = function() ... end,
    -- },
}

-- ─── Accessor helpers ──────────────────────────────────────────────────────

--- Returns all available layouts.
function SetupWizardModule:GetAvailableLayouts()
    return self.AVAILABLE_LAYOUTS
end

--- Returns a layout by id, or nil if not found.
---@param id string
function SetupWizardModule:GetLayout(id)
    for _, layout in ipairs(self.AVAILABLE_LAYOUTS) do
        if layout.id == id then return layout end
    end
end

--- Returns all theme presets.
function SetupWizardModule:GetThemePresets()
    return self.THEME_PRESETS
end

--- Returns a theme preset by id, or nil if not found.
---@param id string
function SetupWizardModule:GetThemePreset(id)
    for _, preset in ipairs(self.THEME_PRESETS) do
        if preset.id == id then return preset end
    end
end
