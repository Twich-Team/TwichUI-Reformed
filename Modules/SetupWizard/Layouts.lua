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
        useClassColor   = false,
        primaryColor    = { 0.10, 0.72, 0.74 },
        accentColor     = { 0.96, 0.76, 0.24 },
        backgroundColor = { 0.05, 0.06, 0.08 },
        borderColor     = { 0.24, 0.26, 0.32 },
    },
    {
        id              = "midnight",
        name            = "Midnight",
        description     = "Deep violet with a cobalt accent.",
        useClassColor   = false,
        primaryColor    = { 0.47, 0.30, 0.88 },
        accentColor     = { 0.29, 0.62, 1.00 },
        backgroundColor = { 0.04, 0.04, 0.10 },
        borderColor     = { 0.22, 0.18, 0.38 },
    },
    {
        id              = "crimson",
        name            = "Crimson",
        description     = "Bold red tones for a combat-ready feel.",
        useClassColor   = false,
        primaryColor    = { 0.85, 0.22, 0.22 },
        accentColor     = { 0.96, 0.74, 0.22 },
        backgroundColor = { 0.08, 0.04, 0.04 },
        borderColor     = { 0.38, 0.18, 0.18 },
    },
    {
        id              = "verdant",
        name            = "Verdant",
        description     = "Natural greens for a calm, composed look.",
        useClassColor   = false,
        primaryColor    = { 0.29, 0.76, 0.50 },
        accentColor     = { 0.74, 0.94, 0.18 },
        backgroundColor = { 0.04, 0.07, 0.05 },
        borderColor     = { 0.18, 0.30, 0.20 },
    },
    {
        id              = "classbound",
        name            = "Classbound",
        description     = "Uses your class color for primary and accent while keeping a neutral surface.",
        useClassColor   = true,
        primaryColor    = { 0.10, 0.72, 0.74 },
        accentColor     = { 0.10, 0.72, 0.74 },
        backgroundColor = { 0.05, 0.06, 0.08 },
        borderColor     = { 0.24, 0.26, 0.32 },
    },
}

-- ─── Layout definitions ────────────────────────────────────────────────────
-- Adding a new entry here automatically populates the layout picker in the wizard.

SetupWizardModule.AVAILABLE_LAYOUTS = {
    -- Captured: 2026-03-28  |  3440x1440  |  layout id: signature
    -- Captured: 2026-03-30  |  3440x1440  |  layout id: standard
    -- Captured: 2026-03-30  |  3440x1440  |  layout id: standard
    -- Captured: 2026-04-04  |  3440x1440  |  layout id: standard
    -- Captured: 2026-04-04  |  3440x1440  |  layout id: Standard
    {
        id                  = "Standard",
        name                = "Standard",
        description         =
        "The original TwichUI layout, designed to focus information into the center of the screen. Applicable for use by any role in Mythic+ or Raiding.",
        role                = "any", -- "any" | "dps" | "healer" | "tank"
        referenceResolution = { w = 3440, h = 1440 },
        frames              = {
            ChatFrame1      = { x = 0.00000, y = 0.02083, w = 0.17500, h = 0.19931, scaleMode = "height" },
            UF_boss         = { x = 0.35392, y = 0.91285, w = 0.29215, h = 0.08403 },
            UF_castbar      = { x = 0.44593, y = 0.22361, w = 0.10814, h = 0.01944 },
            UF_focus        = { x = 0.64041, y = 0.59792, w = 0.06395, h = 0.02361 },
            UF_party        = { x = 0.00000, y = 0.00000, w = 0.00000, h = 0.00000 },
            UF_pet          = { x = 0.65407, y = 0.48542, w = 0.04942, h = 0.01944 },
            UF_player       = { x = 0.35814, y = 0.28056, w = 0.08721, h = 0.03472 },
            UF_raid         = { x = 0.00000, y = 0.00000, w = 0.00000, h = 0.00000 },
            UF_tank         = { x = 0.00000, y = 0.00000, w = 0.00000, h = 0.00000 },
            UF_target       = { x = 0.55494, y = 0.27014, w = 0.08721, h = 0.04514 },
            UF_targettarget = { x = 0.64331, y = 0.29444, w = 0.05814, h = 0.02083 },
        },
        apply               = function()
            local T = unpack(_G.TwichRx)
            T:GetModule("SetupWizard"):RestoreConfigSnapshot({
                actionBars = {
                    _cooldownSwipeDefaultsMigrated = true,
                    bars = {
                        bar1 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 10,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = true,
                            mouseover = false,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1.02,
                            showAccent = false,
                            showBorder = false,
                            showCooldownSwipe = true,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 1503,
                            y = 387
                        },
                        bar10 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOM",
                            relativePoint = "BOTTOM",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 0,
                            y = 316
                        },
                        bar11 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOM",
                            relativePoint = "BOTTOM",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 0,
                            y = 354
                        },
                        bar12 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOM",
                            relativePoint = "BOTTOM",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 0,
                            y = 392
                        },
                        bar13 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOM",
                            relativePoint = "BOTTOM",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 0,
                            y = 430
                        },
                        bar14 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOM",
                            relativePoint = "BOTTOM",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 0,
                            y = 468
                        },
                        bar15 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOM",
                            relativePoint = "BOTTOM",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 0,
                            y = 506
                        },
                        bar2 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 34,
                            buttonsPerRow = 12,
                            enabled = true,
                            mouseover = true,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 804,
                            y = 1393
                        },
                        bar3 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 34,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = true,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 2448,
                            y = 633
                        },
                        bar4 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 10,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = true,
                            mouseover = false,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1.02,
                            showAccent = false,
                            showBorder = false,
                            showCooldownSwipe = true,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[bonusbar:5] hide;show",
                            x = 1503,
                            y = 349
                        },
                        bar5 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 5,
                            buttonSize = 32,
                            buttonsPerRow = 1,
                            enabled = true,
                            mouseover = true,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1.23,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 490,
                            y = 69
                        },
                        bar6 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = true,
                            mouseover = true,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 812,
                            y = 1349
                        },
                        bar7 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 10,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 1499,
                            y = 171
                        },
                        bar8 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOM",
                            relativePoint = "BOTTOM",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 0,
                            y = 240
                        },
                        bar9 = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 12,
                            buttonSize = 32,
                            buttonsPerRow = 12,
                            enabled = false,
                            mouseover = false,
                            point = "BOTTOM",
                            relativePoint = "BOTTOM",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 0,
                            y = 278
                        },
                        extraAction = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 1,
                            buttonSize = 52,
                            buttonsPerRow = 1,
                            enabled = true,
                            mouseover = false,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[extrabar] show; hide",
                            x = 1073,
                            y = 212
                        },
                        pet = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 10,
                            buttonSize = 30,
                            buttonsPerRow = 10,
                            enabled = true,
                            mouseover = false,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle][vehicleui][overridebar] hide; [pet] show; hide",
                            x = 603,
                            y = 30
                        },
                        stance = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 10,
                            buttonSize = 30,
                            buttonsPerRow = 10,
                            enabled = true,
                            mouseover = false,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1,
                            showAccent = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[petbattle] hide; show",
                            x = 953,
                            y = 30
                        },
                        vehicleExit = {
                            _cooldownSwipeDefaultsMigrated = true,
                            alpha = 1,
                            backdrop = true,
                            buttonCount = 1,
                            buttonSize = 32,
                            buttonsPerRow = 1,
                            enabled = true,
                            mouseover = false,
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            scale = 1,
                            showAccent = true,
                            showBorder = true,
                            showCooldownSwipe = false,
                            simpleVisibility = {},
                            simpleVisibilityMode = "raw",
                            visibility = "[vehicleui] show; hide",
                            x = 1080,
                            y = 163
                        }
                    },
                    buttonSpacing = 4,
                    countFontSize = 11,
                    debugEnabled = true,
                    enabled = true,
                    fontOutline = "NONE",
                    hotkeyFontSize = 11,
                    lockBars = true,
                    macroFontSize = 9,
                    procGlowColor = { 0.94902, 0.776471, 0.439216 },
                    procGlowStyle = "proc",
                    procGlowUseThemeColor = false,
                    showCooldownSwipe = true,
                    showCooldownText = true,
                    showCounts = true,
                    showGrid = true,
                    showHotkeys = true,
                    showMacroNames = false,
                    textColor = { 0.921569, 0.941177, 0.960784 },
                    textFont = "Inter",
                    textShadow = true,
                    useMasque = true
                },
                bestInSlot = {
                    displayTime = 30,
                    enabled = true,
                    soundEnabled = true
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
                    channelColors = {
                        battleNetWhisper = {
                            b = 1,
                            g = 1,
                            r = 0
                        }
                    },
                    chatBgColor = {
                        a = 0.7,
                        b = 0.12549,
                        g = 0.0941177,
                        r = 0.0823529
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
                        a = 0.8,
                        b = 0.12549,
                        g = 0.0941177,
                        r = 0.0823529
                    },
                    headerDatatext = {
                        enabled = true,
                        font = "Inter Bold",
                        fontSize = 14,
                        slot1 = "TwichUI: Friends",
                        slotWidth = 84
                    },
                    hideHeader = true,
                    hideRealm = true,
                    messageFadeMinAlpha = 0,
                    messageFadesEnabled = true,
                    msgBgColor = {
                        a = 0.3,
                        b = 0.12549,
                        g = 0.0941177,
                        r = 0.0823529
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
                    tabFont = "Inter ExtraBold",
                    tabFontSize = 14,
                    tabNameFade = true,
                    tabStyle = "unified",
                    timestampFormat = "%I:%M %p",
                    timestampWidth = 70
                },
                chores = {
                    categories = {
                        abundance = false,
                        dungeon = false,
                        specialAssignment = false
                    },
                    countBountifulDelvesTowardTotal = false,
                    countProfessionsTowardTotal = false,
                    preyDifficulties = {
                        hard = false,
                        normal = false
                    },
                    raidWings = {
                        ["3126"] = false,
                        ["3155"] = false,
                        ["3156"] = false,
                        ["3159"] = false,
                        ["3160"] = false
                    },
                    trackBountifulDelves = false
                },
                customBindings = {
                    bindings = {
                        [1] = {
                            actionType = "spell",
                            actionValue = "Flash of Light",
                            enabled = true,
                            id = 1,
                            keybind = "SHIFT-G",
                            macroText = "",
                            name = "Binding 1",
                            specialization = 65
                        }
                    },
                    enabled = true,
                    nextId = 2
                },
                datatext = {
                    auctionMountShortcutEnabled = true,
                    chores = {
                        doneTextColor = { 0.2, 0.82, 0.32, 1 },
                        textColor = { 1, 1, 1, 1 },
                        tooltipEntryFont = "Inter",
                        tooltipHeaderFont = "Inter Bold",
                        tracker = {
                            collapsedSections = {
                                abundance = true,
                                dungeon = false,
                                prey = false,
                                professionEnchanting = false,
                                professionJewelcrafting = false,
                                raidFinder = true,
                                specialAssignment = true,
                                stormarion = true
                            },
                            locked = false,
                            position = {
                                point = "TOPLEFT",
                                relativePoint = "TOPLEFT",
                                x = 0,
                                y = 0
                            },
                            size = {},
                            visible = false
                        },
                        trackerBackgroundTransparency = 0.8,
                        trackerEntryFont = "Inter Bold",
                        trackerFrameTransparency = 1,
                        trackerHeaderFont = "Inter ExtraBold",
                        trackerMode = "framed"
                    },
                    currencies = {
                        customDatatexts = {},
                        displayStyle = "ICON",
                        displayedCurrency = "3347",
                        flashOnUpdate = false,
                        showGoldInTooltip = false,
                        showMax = false,
                        textColor = { 1, 1, 1, 1 },
                        tooltipCurrencyIDs = {
                            [1] = 3383,
                            [2] = 3343,
                            [3] = 3341,
                            [4] = 3345,
                            [5] = 3347,
                            [6] = 3378,
                            [7] = 3212,
                            [8] = 3028,
                            [9] = 3310
                        }
                    },
                    durability = {
                        flashOnUpdate = true,
                        textColor = { 1, 0.84, 0.28, 1 }
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
                        favoriteHearthstoneItemID = 263933,
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
                                slot6 = "NONE",
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
                                segments = 6,
                                slot1 = "TwichUI: Time",
                                slot2 = "TwichUI: Chores",
                                slot3 = "TwichUI: Specialization",
                                slot4 = "TwichUI: Mythic+",
                                slot5 = "TwichUI: Currencies",
                                slot6 = "TwichUI: Durability",
                                style = {
                                    menuFont = "Inter",
                                    tooltipFont = "Inter",
                                    tooltipFontSize = 12
                                },
                                transparentTheme = true,
                                useStyleOverrides = true,
                                width = 775,
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
                                segments = 6,
                                slot1 = "NONE",
                                slot2 = "TwichUI: System",
                                slot3 = "TwichUI: Portals",
                                slot4 = "TwichUI: Mount",
                                slot5 = "TwichUI: Mail",
                                slot6 = "TwichUI: Gold Goblin",
                                style = {
                                    hoverBarAlpha = 0.92,
                                    hoverBarColor = { 0.94902, 0.776471, 0.439216, 1 },
                                    hoverGlowAlpha = 0.09,
                                    hoverGlowColor = { 0.94902, 0.776471, 0.439216, 1 },
                                    menuFont = "Inter",
                                    tooltipFont = "Inter",
                                    tooltipFontSize = 12
                                },
                                transparentTheme = true,
                                useStyleOverrides = true,
                                width = 775,
                                x = 0,
                                y = 0
                            },
                            panel4 = {
                                enabled = true,
                                height = 28,
                                id = "panel4",
                                name = "Center",
                                point = "BOTTOM",
                                relativePoint = "BOTTOM",
                                segments = 1,
                                slot1 = "TwichUI: TwichUI",
                                slot2 = "NONE",
                                slot3 = "NONE",
                                slot4 = "NONE",
                                slot5 = "NONE",
                                slot6 = "NONE",
                                style = {
                                    hoverBarAlpha = 0.92,
                                    hoverBarColor = { 0.94902, 0.776471, 0.439216, 1 },
                                    hoverGlowAlpha = 0.1,
                                    hoverGlowColor = { 0.94902, 0.776471, 0.439216, 1 }
                                },
                                transparentTheme = true,
                                useStyleOverrides = true,
                                width = 100,
                                x = 0,
                                y = 0
                            }
                        },
                        style = {
                            fontSize = 13,
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
                    toys = {
                        textColor = { 1, 1, 1, 1 }
                    },
                    vendorMountShortcutEnabled = true
                },
                dungeonTracking = {
                    classIconStyle = "pixel",
                    enabled = true,
                    leavePhrase = "tyfp",
                    notificationDisplayTime = 45
                },
                dynamicFlight = {
                    anchorX = -1,
                    anchorY = -346,
                    enabled = true,
                    locked = true,
                    mainFont = "Exo2 Bold",
                    secondaryFont = "Exo2 Bold",
                    style = "transparent",
                    width = 350
                },
                easyFish = {
                    enabled = false
                },
                gathering = {
                    enabled = false,
                    hudTerrainTransparent = true,
                    sessionState = {
                        active = false,
                        elapsedSeconds = 0,
                        goldPerHour = 0,
                        hasSession = false,
                        items = {},
                        savedAt = 1775332928,
                        totalValue = 0
                    }
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
                    interruptTrackerLocked = true,
                    interruptX = 867,
                    interruptY = 45,
                    mythicPlusCheckpointNotificationSound = "TwichUI Alert 2",
                    mythicPlusTimerBarHeight = 28,
                    mythicPlusTimerFontSize = 14,
                    mythicPlusTimerLocked = true,
                    mythicPlusTimerMinionCheckpoints = {
                        dungeons = {
                            ["161"] = {
                                checkpoints = {
                                    [1] = {
                                        bossIndex = 1,
                                        id = "boss_1",
                                        kind = "boss",
                                        name = "Ranjit",
                                        notifyEnabled = true,
                                        percent = 25
                                    },
                                    [2] = {
                                        bossIndex = 2,
                                        id = "boss_2",
                                        kind = "boss",
                                        name = "Araknath",
                                        notifyEnabled = true,
                                        percent = 50
                                    },
                                    [3] = {
                                        bossIndex = 3,
                                        id = "boss_3",
                                        kind = "boss",
                                        name = "Rukhran",
                                        notifyEnabled = true,
                                        percent = 75
                                    },
                                    [4] = {
                                        bossIndex = 4,
                                        id = "boss_4",
                                        kind = "boss",
                                        name = "High Sage Viryx",
                                        notifyEnabled = true,
                                        percent = 100
                                    }
                                }
                            },
                            ["239"] = {
                                checkpoints = {
                                    [1] = {
                                        bossIndex = 1,
                                        id = "boss_1",
                                        kind = "boss",
                                        name = "Zuraal the Ascended",
                                        notifyEnabled = true,
                                        percent = 25
                                    },
                                    [2] = {
                                        bossIndex = 2,
                                        id = "boss_2",
                                        kind = "boss",
                                        name = "Saprish",
                                        notifyEnabled = true,
                                        percent = 50
                                    },
                                    [3] = {
                                        bossIndex = 3,
                                        id = "boss_3",
                                        kind = "boss",
                                        name = "Viceroy Nezhar",
                                        notifyEnabled = true,
                                        percent = 75
                                    },
                                    [4] = {
                                        bossIndex = 4,
                                        id = "boss_4",
                                        kind = "boss",
                                        name = "L'ura",
                                        notifyEnabled = true,
                                        percent = 100
                                    }
                                }
                            },
                            ["402"] = {
                                checkpoints = {
                                    [1] = {
                                        bossIndex = 1,
                                        id = "boss_1",
                                        kind = "boss",
                                        name = "Vexamus",
                                        notifyEnabled = true,
                                        percent = 25
                                    },
                                    [2] = {
                                        bossIndex = 2,
                                        id = "boss_2",
                                        kind = "boss",
                                        name = "Overgrown Ancient",
                                        notifyEnabled = true,
                                        percent = 50
                                    },
                                    [3] = {
                                        bossIndex = 3,
                                        id = "boss_3",
                                        kind = "boss",
                                        name = "Crawth",
                                        notifyEnabled = true,
                                        percent = 75
                                    },
                                    [4] = {
                                        bossIndex = 4,
                                        id = "boss_4",
                                        kind = "boss",
                                        name = "Echo of Doragosa",
                                        notifyEnabled = true,
                                        percent = 100
                                    }
                                }
                            },
                            ["556"] = {
                                checkpoints = {
                                    [1] = {
                                        bossIndex = 1,
                                        id = "boss_1",
                                        kind = "boss",
                                        name = "Forgemaster Garfrost",
                                        notifyEnabled = true,
                                        percent = 20
                                    },
                                    [2] = {
                                        bossIndex = 2,
                                        id = "boss_2",
                                        kind = "boss",
                                        name = "Ick and Krick",
                                        notifyEnabled = true,
                                        percent = 67
                                    },
                                    [3] = {
                                        id = "custom_1",
                                        kind = "custom",
                                        name = "Before Tunnel",
                                        notifyEnabled = true,
                                        percent = 80
                                    },
                                    [4] = {
                                        bossIndex = 3,
                                        id = "boss_3",
                                        kind = "boss",
                                        name = "Scourgelord Tyrannus",
                                        notifyEnabled = true,
                                        percent = 100
                                    }
                                }
                            },
                            ["557"] = {
                                checkpoints = {
                                    [1] = {
                                        bossIndex = 1,
                                        id = "boss_1",
                                        kind = "boss",
                                        name = "Emberdawn",
                                        notifyEnabled = true,
                                        percent = 25
                                    },
                                    [2] = {
                                        bossIndex = 2,
                                        id = "boss_2",
                                        kind = "boss",
                                        name = "Derelict Duo",
                                        notifyEnabled = true,
                                        percent = 50
                                    },
                                    [3] = {
                                        bossIndex = 3,
                                        id = "boss_3",
                                        kind = "boss",
                                        name = "Commander Kroluk",
                                        notifyEnabled = true,
                                        percent = 75
                                    },
                                    [4] = {
                                        bossIndex = 4,
                                        id = "boss_4",
                                        kind = "boss",
                                        name = "The Restless Heart",
                                        notifyEnabled = true,
                                        percent = 100
                                    }
                                }
                            },
                            ["558"] = {
                                checkpoints = {
                                    [1] = {
                                        bossIndex = 1,
                                        id = "boss_1",
                                        kind = "boss",
                                        name = "Selin Fireheart",
                                        notifyEnabled = true,
                                        percent = 25
                                    },
                                    [2] = {
                                        bossIndex = 2,
                                        id = "boss_2",
                                        kind = "boss",
                                        name = "Vexallus",
                                        notifyEnabled = true,
                                        percent = 50
                                    },
                                    [3] = {
                                        bossIndex = 3,
                                        id = "boss_3",
                                        kind = "boss",
                                        name = "Priestess Delrissa",
                                        notifyEnabled = true,
                                        percent = 75
                                    },
                                    [4] = {
                                        bossIndex = 4,
                                        id = "boss_4",
                                        kind = "boss",
                                        name = "Kael'thas Sunstrider",
                                        notifyEnabled = true,
                                        percent = 100
                                    }
                                }
                            },
                            ["559"] = {
                                checkpoints = {
                                    [1] = {
                                        bossIndex = 1,
                                        id = "boss_1",
                                        kind = "boss",
                                        name = "Chief Corewright Kasreth",
                                        notifyEnabled = true,
                                        percent = 25
                                    },
                                    [2] = {
                                        bossIndex = 2,
                                        id = "boss_2",
                                        kind = "boss",
                                        name = "Corewarden Nysarra",
                                        notifyEnabled = true,
                                        percent = 50
                                    },
                                    [3] = {
                                        bossIndex = 3,
                                        id = "boss_3",
                                        kind = "boss",
                                        name = "Lothraxion",
                                        notifyEnabled = true,
                                        percent = 75
                                    },
                                    [4] = {
                                        bossIndex = 4,
                                        id = "boss_4",
                                        kind = "boss",
                                        name = "Custom Checkpoint 4",
                                        notifyEnabled = true,
                                        percent = 100
                                    }
                                }
                            },
                            ["560"] = {
                                checkpoints = {
                                    [1] = {
                                        bossIndex = 1,
                                        id = "boss_1",
                                        kind = "boss",
                                        name = "Muro'jin and Nekraxx",
                                        notifyEnabled = true,
                                        percent = 33
                                    },
                                    [2] = {
                                        bossIndex = 2,
                                        id = "boss_2",
                                        kind = "boss",
                                        name = "Vordaza",
                                        notifyEnabled = true,
                                        percent = 63
                                    },
                                    [3] = {
                                        bossIndex = 3,
                                        id = "boss_3",
                                        kind = "boss",
                                        name = "Rak'tul, Vessel of Souls",
                                        notifyEnabled = true,
                                        percent = 100
                                    }
                                }
                            }
                        },
                        selectedMapID = 557
                    },
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
                preyTweaks = {
                    autoSelectHuntReward = true,
                    autoSuperTrackPreyQuest = true,
                    autoTurnInPreyQuest = true,
                    autoWatchPreyQuest = true,
                    barOffsetY = -60,
                    displayMode = "bar",
                    enabled = true,
                    playPhaseChangeSound = true,
                    valueFontSize = 16
                },
                questAutomation = {
                    autoCompleteWithRewards = true,
                    automaticAccept = true,
                    automaticTurnIn = true,
                    enabled = true,
                    questType = {
                        meta = true,
                        repeatable = true
                    }
                },
                raidFrames = {
                    enabled = false
                },
                satchelWatch = {
                    enabled = true,
                    ignoredDungeonIDs = {},
                    notifyForHealers = true,
                    notifyForHeroicDungeon = false,
                    notifyForRegularDungeon = false,
                    notifyOnlyForRaids = true,
                    notifyOnlyWhenNotCompleted = true,
                    notifyOnlyWhenNotInGroup = true,
                    periodicCheckEnabled = true,
                    raid_3126 = true,
                    raid_3155 = false,
                    raid_3156 = true,
                    raid_3159 = true,
                    raid_3160 = false,
                    roleIconType = "twich",
                    sound = "TwichUI Alert 2"
                },
                smartMount = {
                    dismountIfMounted = true,
                    enabled = true,
                    flyingMount = 2733,
                    groundMount = 885,
                    smartMountKeybinding = "SHIFT-SPACE"
                },
                teleports = {
                    collapsedSections = {
                        ["map:Current Season"] = false
                    },
                    enabled = true,
                    popupPosition = {
                        point = "CENTER",
                        relativePoint = "CENTER",
                        x = -157.4,
                        y = 80.9997
                    }
                },
                theme = {
                    accentColor = { 0.752941, 0.654902, 0.533333 },
                    appliedThemePreset = "__custom",
                    backgroundAlpha = 0.8,
                    backgroundColor = { 0.0823529, 0.0941177, 0.12549 },
                    borderAlpha = 0.85,
                    borderColor = { 0.24, 0.26, 0.32 },
                    classIconStyle = "pixel",
                    globalFont = "Inter Bold",
                    primaryColor = { 0.752941, 0.654902, 0.533333 },
                    soundProfile = "Standard",
                    statusBarTexture = "TwichUI Bright"
                },
                unitFrames = {
                    _migrated = {
                        groupRowSpacing = true,
                        healerOnlyPower = true,
                        partyRoleIconDefault = true,
                        partyRoleIconFilterDefault = true,
                        partyTankGrowthDirection = true,
                        tankRoleFilterDefault = true,
                        tankRoleIconDefault = true
                    },
                    auras = {
                        scopes = {
                            boss = {
                                barHeight = 14,
                                barMode = false,
                                enabled = false,
                                filter = "ALL",
                                iconSize = 16,
                                maxIcons = 8,
                                onlyMine = false,
                                spacing = 2,
                                yOffset = 6
                            },
                            party = {
                                barHeight = 14,
                                barMode = false,
                                enabled = false,
                                filter = "HARMFUL",
                                iconSize = 14,
                                indicators = {
                                    [1] = {
                                        _resolvedCacheKey = "filter:DISPELLABLE:mine:false",
                                        anchor = "TOPLEFT",
                                        borderAnim = "chase",
                                        borderColor = { 0.1, 0.72, 0.74, 1 },
                                        chaseColor = { 1, 1, 1, 1 },
                                        chaseCount = 12,
                                        chasePixelH = 4,
                                        chasePixelW = 20,
                                        enabled = true,
                                        extraLayers = {
                                            [1] = {
                                                anchor = "TOPLEFT",
                                                borderAnim = "solid",
                                                borderColor = { 0.9, 0.3, 0.32, 1 },
                                                overlayAlpha = 0.2,
                                                overlayColor = { 0.1, 0.72, 0.74, 0.2 },
                                                type = "overlay"
                                            },
                                            [2] = {
                                                anchor = "CENTER",
                                                borderAnim = "solid",
                                                countFontName = "Inter",
                                                countFontSize = 10,
                                                countOutlineMode = "NONE",
                                                durAnchor = "CENTER",
                                                durationFontName = "Inter Bold",
                                                durationFontSize = 14,
                                                durationOutlineMode = "NONE",
                                                durationShadowEnabled = true,
                                                iconSize = 30,
                                                relativeAnchor = "CENTER",
                                                type = "icons"
                                            }
                                        },
                                        growDirection = "RIGHT",
                                        iconSize = 18,
                                        maxCount = 5,
                                        offsetX = 0,
                                        offsetY = 0,
                                        onlyMine = false,
                                        relativeAnchor = "TOPLEFT",
                                        slotName = "Dispellable by You",
                                        source = "DISPELLABLE",
                                        spacing = 2,
                                        type = "border"
                                    },
                                    [2] = {
                                        _resolvedCacheKey = "filter:DISPELLABLE_OR_BOSS:mine:false",
                                        anchor = "CENTER",
                                        durAnchor = "CENTER",
                                        durationFontSize = 14,
                                        enabled = true,
                                        growDirection = "RIGHT",
                                        iconSize = 30,
                                        maxCount = 5,
                                        offsetX = 0,
                                        offsetY = 0,
                                        onlyMine = false,
                                        relativeAnchor = "CENTER",
                                        slotName = "Boss Effects",
                                        source = "DISPELLABLE_OR_BOSS",
                                        spacing = 2,
                                        type = "icons"
                                    },
                                    [3] = {
                                        _resolvedCacheKey = "filter:HELPFUL:mine:true",
                                        anchor = "BOTTOMLEFT",
                                        durAnchor = "CENTER",
                                        durationFontName = "Inter Bold",
                                        durationFontSize = 12,
                                        enabled = true,
                                        growDirection = "RIGHT",
                                        iconSize = 24,
                                        maxCount = 5,
                                        offsetX = 1,
                                        offsetY = 0,
                                        onlyMine = true,
                                        relativeAnchor = "BOTTOMLEFT",
                                        showCount = false,
                                        slotName = "Your Helpful Auras",
                                        source = "HELPFUL",
                                        spacing = 2,
                                        type = "icons"
                                    }
                                },
                                maxIcons = 6,
                                onlyMine = false,
                                spacing = 2,
                                yOffset = 5
                            },
                            raid = {
                                barHeight = 14,
                                barMode = false,
                                enabled = false,
                                filter = "HARMFUL",
                                iconSize = 14,
                                indicators = {
                                    [1] = {
                                        _resolvedCacheKey = "filter:DISPELLABLE:mine:false",
                                        anchor = "TOPLEFT",
                                        borderAnim = "chase",
                                        borderColor = { 0.1, 0.72, 0.74, 1 },
                                        chaseColor = { 1, 1, 1, 1 },
                                        chaseCount = 12,
                                        chasePixelH = 4,
                                        chasePixelW = 20,
                                        enabled = true,
                                        extraLayers = {
                                            [1] = {
                                                anchor = "TOPLEFT",
                                                borderAnim = "solid",
                                                borderColor = { 0.9, 0.3, 0.32, 1 },
                                                overlayAlpha = 0.2,
                                                overlayColor = { 0.1, 0.72, 0.74, 0.2 },
                                                type = "overlay"
                                            },
                                            [2] = {
                                                anchor = "CENTER",
                                                borderAnim = "solid",
                                                countFontName = "Inter",
                                                countFontSize = 10,
                                                countOutlineMode = "NONE",
                                                durAnchor = "CENTER",
                                                durationFontName = "Inter Bold",
                                                durationFontSize = 14,
                                                durationOutlineMode = "NONE",
                                                durationShadowEnabled = true,
                                                iconSize = 25,
                                                relativeAnchor = "CENTER",
                                                type = "icons"
                                            }
                                        },
                                        growDirection = "RIGHT",
                                        iconSize = 18,
                                        maxCount = 5,
                                        offsetX = 0,
                                        offsetY = 0,
                                        onlyMine = false,
                                        relativeAnchor = "TOPLEFT",
                                        slotName = "Dispellable by You",
                                        source = "DISPELLABLE",
                                        spacing = 2,
                                        type = "border"
                                    },
                                    [2] = {
                                        _resolvedCacheKey = "filter:DISPELLABLE_OR_BOSS:mine:false",
                                        anchor = "CENTER",
                                        durAnchor = "CENTER",
                                        durationFontSize = 14,
                                        enabled = true,
                                        growDirection = "RIGHT",
                                        iconSize = 25,
                                        maxCount = 5,
                                        offsetX = 0,
                                        offsetY = 0,
                                        onlyMine = false,
                                        relativeAnchor = "CENTER",
                                        slotName = "Boss Effects",
                                        source = "DISPELLABLE_OR_BOSS",
                                        spacing = 2,
                                        type = "icons"
                                    },
                                    [3] = {
                                        _resolvedCacheKey = "filter:HELPFUL:mine:true",
                                        anchor = "LEFT",
                                        durAnchor = "CENTER",
                                        durationFontName = "Inter Bold",
                                        durationFontSize = 12,
                                        enabled = true,
                                        growDirection = "RIGHT",
                                        iconSize = 20,
                                        maxCount = 5,
                                        offsetX = 1,
                                        offsetY = 0,
                                        onlyMine = true,
                                        relativeAnchor = "LEFT",
                                        showCount = false,
                                        slotName = "Your Helpful Auras",
                                        source = "HELPFUL",
                                        spacing = 2,
                                        type = "icons"
                                    }
                                },
                                maxIcons = 6,
                                onlyMine = false,
                                spacing = 2,
                                yOffset = 5
                            },
                            singles = {
                                barHeight = 14,
                                barMode = false,
                                enabled = true,
                                filter = "ALL",
                                iconSize = 19,
                                maxIcons = 8,
                                onlyMine = false,
                                spacing = 2,
                                yOffset = 6
                            },
                            tank = {
                                barHeight = 14,
                                barMode = false,
                                enabled = false,
                                filter = "HARMFUL",
                                iconSize = 14,
                                indicators = {
                                    [1] = {
                                        _resolvedCacheKey = "filter:DISPELLABLE:mine:false",
                                        anchor = "TOPLEFT",
                                        borderAnim = "chase",
                                        borderColor = { 0.1, 0.72, 0.74, 1 },
                                        chaseColor = { 1, 1, 1, 1 },
                                        chaseCount = 12,
                                        chasePixelH = 4,
                                        chasePixelW = 20,
                                        enabled = true,
                                        extraLayers = {
                                            [1] = {
                                                anchor = "TOPLEFT",
                                                borderAnim = "solid",
                                                borderColor = { 0.9, 0.3, 0.32, 1 },
                                                overlayAlpha = 0.2,
                                                overlayColor = { 0.1, 0.72, 0.74, 0.2 },
                                                type = "overlay"
                                            },
                                            [2] = {
                                                anchor = "CENTER",
                                                borderAnim = "solid",
                                                countFontName = "Inter",
                                                countFontSize = 10,
                                                countOutlineMode = "NONE",
                                                durAnchor = "CENTER",
                                                durationFontName = "Inter Bold",
                                                durationFontSize = 14,
                                                durationOutlineMode = "NONE",
                                                durationShadowEnabled = true,
                                                iconSize = 25,
                                                relativeAnchor = "CENTER",
                                                type = "icons"
                                            }
                                        },
                                        growDirection = "RIGHT",
                                        iconSize = 18,
                                        maxCount = 5,
                                        offsetX = 0,
                                        offsetY = 0,
                                        onlyMine = false,
                                        relativeAnchor = "TOPLEFT",
                                        slotName = "Dispellable by You",
                                        source = "DISPELLABLE",
                                        spacing = 2,
                                        type = "border"
                                    },
                                    [2] = {
                                        _resolvedCacheKey = "filter:DISPELLABLE_OR_BOSS:mine:false",
                                        anchor = "CENTER",
                                        durAnchor = "CENTER",
                                        durationFontSize = 14,
                                        enabled = true,
                                        growDirection = "RIGHT",
                                        iconSize = 25,
                                        maxCount = 5,
                                        offsetX = 0,
                                        offsetY = 0,
                                        onlyMine = false,
                                        relativeAnchor = "CENTER",
                                        slotName = "Boss Effects",
                                        source = "DISPELLABLE_OR_BOSS",
                                        spacing = 2,
                                        type = "icons"
                                    },
                                    [3] = {
                                        _resolvedCacheKey = "filter:HELPFUL:mine:true",
                                        anchor = "LEFT",
                                        durAnchor = "CENTER",
                                        durationFontName = "Inter Bold",
                                        durationFontSize = 12,
                                        enabled = true,
                                        growDirection = "RIGHT",
                                        iconSize = 20,
                                        maxCount = 5,
                                        offsetX = 1,
                                        offsetY = 0,
                                        onlyMine = true,
                                        relativeAnchor = "LEFT",
                                        showCount = false,
                                        slotName = "Your Helpful Auras",
                                        source = "HELPFUL",
                                        spacing = 2,
                                        type = "icons"
                                    }
                                },
                                maxIcons = 6,
                                onlyMine = false,
                                spacing = 2,
                                yOffset = 5
                            }
                        }
                    },
                    bgTexture = "TwichUI AngledLines",
                    castbar = {
                        auras = {
                            scopes = {
                                auras = {
                                    scopes = {
                                        boss = {
                                            barHeight = 14,
                                            barMode = false,
                                            enabled = true,
                                            filter = "HARMFUL",
                                            iconSize = 16,
                                            maxIcons = 8,
                                            onlyMine = false,
                                            spacing = 2,
                                            yOffset = 6
                                        },
                                        party = {
                                            barHeight = 12,
                                            barMode = false,
                                            enabled = true,
                                            filter = "HARMFUL",
                                            iconSize = 14,
                                            maxIcons = 6,
                                            onlyMine = false,
                                            spacing = 2,
                                            yOffset = 5
                                        },
                                        raid = {
                                            barHeight = 10,
                                            barMode = false,
                                            enabled = false,
                                            filter = "HARMFUL",
                                            iconSize = 12,
                                            maxIcons = 4,
                                            onlyMine = false,
                                            spacing = 1,
                                            yOffset = 4
                                        },
                                        singles = {
                                            barHeight = 14,
                                            barMode = false,
                                            enabled = true,
                                            filter = "ALL",
                                            iconSize = 18,
                                            maxIcons = 8,
                                            onlyMine = false,
                                            spacing = 2,
                                            yOffset = 6
                                        },
                                        tank = {
                                            barHeight = 12,
                                            barMode = false,
                                            enabled = true,
                                            filter = "ALL",
                                            iconSize = 14,
                                            maxIcons = 6,
                                            onlyMine = false,
                                            spacing = 2,
                                            yOffset = 5
                                        }
                                    }
                                },
                                boss = {
                                    barHeight = 14,
                                    barMode = false,
                                    enabled = true,
                                    filter = "HARMFUL",
                                    iconSize = 16,
                                    maxIcons = 8,
                                    onlyMine = false,
                                    spacing = 2,
                                    yOffset = 6
                                },
                                castbar = {
                                    color = { 0.96, 0.76, 0.24, 1 },
                                    enabled = true,
                                    height = 20,
                                    iconSize = 20,
                                    showIcon = true,
                                    showSpellText = true,
                                    showTimeText = true,
                                    spellFontSize = 11,
                                    timeFontSize = 10,
                                    useCustomColor = false,
                                    width = 260
                                },
                                castbars = {
                                    boss = {
                                        color = { 0.96, 0.4, 0.24, 1 },
                                        enabled = true,
                                        fontSize = 9,
                                        height = 12,
                                        showIcon = true,
                                        showText = true,
                                        showTimeText = true,
                                        timeFontSize = 9,
                                        useCustomColor = false,
                                        yOffset = 2
                                    },
                                    party = {
                                        color = { 0.96, 0.76, 0.24, 1 },
                                        enabled = false,
                                        fontSize = 8,
                                        height = 8,
                                        showIcon = false,
                                        showText = false,
                                        showTimeText = false,
                                        timeFontSize = 8,
                                        useCustomColor = false,
                                        yOffset = 1
                                    },
                                    raid = {
                                        color = { 0.96, 0.76, 0.24, 1 },
                                        enabled = false,
                                        fontSize = 8,
                                        height = 6,
                                        showIcon = false,
                                        showText = false,
                                        showTimeText = false,
                                        timeFontSize = 8,
                                        useCustomColor = false,
                                        yOffset = 1
                                    },
                                    target = {
                                        color = { 0.96, 0.76, 0.24, 1 },
                                        enabled = true,
                                        fontSize = 9,
                                        height = 12,
                                        showIcon = true,
                                        showText = true,
                                        showTimeText = true,
                                        timeFontSize = 9,
                                        useCustomColor = false,
                                        yOffset = 2
                                    }
                                },
                                party = {
                                    barHeight = 12,
                                    barMode = false,
                                    enabled = true,
                                    filter = "HARMFUL",
                                    iconSize = 14,
                                    maxIcons = 6,
                                    onlyMine = false,
                                    spacing = 2,
                                    yOffset = 5
                                },
                                raid = {
                                    barHeight = 10,
                                    barMode = false,
                                    enabled = false,
                                    filter = "HARMFUL",
                                    iconSize = 12,
                                    maxIcons = 4,
                                    onlyMine = false,
                                    spacing = 1,
                                    yOffset = 4
                                },
                                singles = {
                                    barHeight = 14,
                                    barMode = false,
                                    enabled = true,
                                    filter = "ALL",
                                    iconSize = 18,
                                    maxIcons = 8,
                                    onlyMine = false,
                                    spacing = 2,
                                    yOffset = 6
                                },
                                tank = {
                                    barHeight = 12,
                                    barMode = false,
                                    enabled = true,
                                    filter = "ALL",
                                    iconSize = 14,
                                    maxIcons = 6,
                                    onlyMine = false,
                                    spacing = 2,
                                    yOffset = 5
                                }
                            }
                        },
                        castbars = {
                            boss = {
                                color = { 0.96, 0.4, 0.24, 1 },
                                enabled = true,
                                fontSize = 9,
                                height = 12,
                                showIcon = true,
                                showText = true,
                                showTimeText = true,
                                timeFontSize = 9,
                                useCustomColor = false,
                                yOffset = 2
                            },
                            party = {
                                color = { 0.96, 0.76, 0.24, 1 },
                                enabled = false,
                                fontSize = 8,
                                height = 8,
                                showIcon = false,
                                showText = false,
                                showTimeText = false,
                                timeFontSize = 8,
                                useCustomColor = false,
                                yOffset = 1
                            },
                            raid = {
                                color = { 0.96, 0.76, 0.24, 1 },
                                enabled = false,
                                fontSize = 8,
                                height = 6,
                                showIcon = false,
                                showText = false,
                                showTimeText = false,
                                timeFontSize = 8,
                                useCustomColor = false,
                                yOffset = 1
                            },
                            target = {
                                color = { 0.96, 0.76, 0.24, 1 },
                                enabled = true,
                                fontSize = 9,
                                height = 12,
                                showIcon = true,
                                showText = true,
                                showTimeText = true,
                                timeFontSize = 9,
                                useCustomColor = false,
                                yOffset = 2
                            }
                        },
                        color = { 0.752941, 0.654902, 0.533333, 1 },
                        enabled = true,
                        fantasyEffectScale = 1.2,
                        fantasyTheme = "holy",
                        height = 28,
                        iconPosition = "inside",
                        iconSide = "left",
                        iconSize = 28,
                        showIcon = true,
                        showSpellText = true,
                        showTimeText = true,
                        spellFontSize = 14,
                        style = "fantasy",
                        timeFontSize = 14,
                        useCustomColor = true,
                        useThemeAccentFill = false,
                        width = 372
                    },
                    castbars = {
                        boss = {
                            color = { 0.96, 0.76, 0.24, 1 },
                            detached = false,
                            enabled = true,
                            fontSize = 12,
                            height = 15,
                            point = "TOPLEFT",
                            relativePoint = "BOTTOMLEFT",
                            showIcon = false,
                            showText = true,
                            showTimeText = true,
                            timeFontSize = 12,
                            useCustomColor = false,
                            width = 220,
                            xOffset = 0,
                            yOffset = 2
                        },
                        party = {
                            color = { 0.96, 0.76, 0.24, 1 },
                            detached = false,
                            enabled = false,
                            fontSize = 8,
                            height = 10,
                            point = "TOPLEFT",
                            relativePoint = "BOTTOMLEFT",
                            showIcon = false,
                            showText = false,
                            showTimeText = false,
                            timeFontSize = 8,
                            useCustomColor = false,
                            width = 180,
                            xOffset = 0,
                            yOffset = 1
                        },
                        raid = {
                            color = { 0.96, 0.76, 0.24, 1 },
                            detached = false,
                            enabled = false,
                            fontSize = 8,
                            height = 6,
                            point = "TOPLEFT",
                            relativePoint = "BOTTOMLEFT",
                            showIcon = false,
                            showText = false,
                            showTimeText = false,
                            timeFontSize = 8,
                            useCustomColor = false,
                            width = 112,
                            xOffset = 0,
                            yOffset = 1
                        },
                        target = {
                            color = { 0.196078, 0.631373, 0.85098, 1 },
                            detached = false,
                            enabled = true,
                            fontSize = 14,
                            height = 20,
                            iconPosition = "inside",
                            iconSize = 18,
                            point = "TOPLEFT",
                            relativePoint = "BOTTOMLEFT",
                            showIcon = true,
                            showText = true,
                            showTimeText = true,
                            timeFontSize = 14,
                            useCustomColor = true,
                            width = 260,
                            xOffset = 0,
                            yOffset = 2
                        }
                    },
                    classBar = {
                        backgroundColor = { 0.0823529, 0.0941177, 0.12549, 1 },
                        borderColor = { 0.145098, 0.168627, 0.211765, 1 },
                        color = { 0.94902, 0.776471, 0.439216, 1 },
                        enabled = true,
                        height = 15,
                        matchFrameWidth = true,
                        point = "TOPLEFT",
                        relativePoint = "BOTTOMLEFT",
                        spacing = 1,
                        useCustomBackground = true,
                        useCustomBorder = true,
                        useCustomColor = true,
                        width = 527,
                        xOffset = 0,
                        yOffset = -2
                    },
                    colors = {
                        background = { 0.0823529, 0.0941177, 0.12549, 1 },
                        border = { 0.24, 0.26, 0.32, 1 },
                        cast = { 0.96, 0.76, 0.24, 1 },
                        health = { 0.545098, 0.290196, 0.890196, 1 },
                        power = { 0.1, 0.72, 0.74, 1 },
                        scopes = {
                            boss = {
                                cast = { 0.196078, 0.631373, 0.85098, 0.960784 },
                                power = { 0.458824, 0.537255, 0.74902, 1 },
                                powerBackground = { 0.133333, 0.14902, 0.176471, 1 }
                            },
                            party = {
                                background = { 0.133333, 0.14902, 0.176471, 1 },
                                cast = { 0.780392, 0.796079, 0.847059, 1 },
                                powerBackground = { 0.0823529, 0.0941177, 0.12549, 1 },
                                powerColorMode = "powertype"
                            },
                            raid = {
                                background = { 0.133333, 0.14902, 0.176471, 1 },
                                cast = { 0.780392, 0.796079, 0.847059, 1 },
                                powerBackground = { 0.0823529, 0.0941177, 0.12549, 1 },
                                powerColorMode = "powertype"
                            },
                            singles = {
                                power = { 0.1, 0.72, 0.74, 1 },
                                powerBackground = { 0.105882, 0.12549, 0.160784, 0.8 },
                                powerBorder = { 0.458824, 0.537255, 0.74902, 1 }
                            },
                            tank = {
                                background = { 0.133333, 0.14902, 0.176471, 1 },
                                cast = { 0.780392, 0.796079, 0.847059, 1 },
                                powerBackground = { 0.0823529, 0.0941177, 0.12549, 1 },
                                powerColorMode = "powertype"
                            }
                        }
                    },
                    debug = {
                        unitFramesDiagnostics = {
                            enabled = false,
                            intervalSec = 2,
                            minMemoryDeltaKB = 512,
                            verbose = false
                        }
                    },
                    distanceFade = {
                        enabled = true,
                        outsideAlpha = 0.45
                    },
                    enabled = true,
                    frameAlpha = 1,
                    groups = {
                        boss = {
                            columnAnchorPoint = "TOP",
                            columnSpacing = 8,
                            enabled = true,
                            growthDirection = "LEFT",
                            height = 36,
                            unitsPerColumn = 2,
                            width = 220,
                            xOffset = 5,
                            yOffset = -20
                        },
                        party = {
                            columnAnchorPoint = "LEFT",
                            columnSpacing = 8,
                            enabled = true,
                            growthDirection = "DOWN",
                            healerOnlyPower = true,
                            height = 75,
                            infoBar = {
                                bgColor = { 0.0509804, 0.0588235, 0.0784314, 0.37 },
                                enabled = false,
                                fontName = "Exo2 Bold",
                                outlineMode = "NONE",
                                text1 = {
                                    fontSize = 14,
                                    tag = "[name(8)]",
                                    useClassColor = true
                                },
                                text2 = {
                                    fontSize = 14,
                                    justify = "CENTER",
                                    tag = ""
                                },
                                text3 = {
                                    fontSize = 14,
                                    tag = "[perhp]%"
                                }
                            },
                            maxColumns = 5,
                            offlineIndicator = {
                                enabled = true
                            },
                            point = "TOP",
                            readyCheckIndicator = {
                                offsetY = 0,
                                point = "CENTER",
                                relativePoint = "CENTER",
                                size = 32
                            },
                            resurrectIndicator = {
                                enabled = true,
                                relativePoint = "CENTER"
                            },
                            roleIcon = {
                                alpha = 0.85,
                                corner = "BOTTOMRIGHT",
                                enabled = true,
                                filter = "nonDps",
                                iconType = "twich",
                                insetX = 2,
                                insetY = 8,
                                size = 24
                            },
                            rowSpacing = 8,
                            showPlayer = true,
                            showSolo = true,
                            spiritIndicator = {
                                enabled = true,
                                size = 47
                            },
                            summonIndicator = {
                                enabled = true,
                                relativePoint = "CENTER"
                            },
                            unitsPerColumn = 1,
                            width = 180,
                            xOffset = 0,
                            yOffset = -8
                        },
                        raid = {
                            columnAnchorPoint = "LEFT",
                            columnSpacing = 6,
                            enabled = true,
                            groupBy = "GROUP",
                            groupingOrder = "1,2,3,4,5,6,7,8",
                            healerOnlyPower = true,
                            height = 40,
                            infoBar = {
                                bgColor = { 0.0823529, 0.0941177, 0.12549, 1 },
                                borderColor = { 0.0588235, 0.0666667, 0.0784314, 1 },
                                enabled = true,
                                fontName = "Exo2 Bold",
                                height = 13,
                                numTexts = 2,
                                outlineMode = "NONE",
                                shadowEnabled = true,
                                text1 = {
                                    fontSize = 12,
                                    tag = "[name(8)]",
                                    useClassColor = true
                                },
                                text2 = {
                                    fontSize = 10,
                                    justify = "RIGHT",
                                    tag = "[perhp]",
                                    useClassColor = true
                                },
                                text3 = {
                                    fontSize = 14,
                                    tag = "[perhp]%"
                                }
                            },
                            maxColumns = 5,
                            offlineIndicator = {
                                enabled = true
                            },
                            point = "TOP",
                            readyCheckIndicator = {
                                offsetY = 2,
                                point = "CENTER",
                                relativePoint = "CENTER",
                                size = 24
                            },
                            resurrectIndicator = {
                                enabled = true,
                                relativePoint = "CENTER"
                            },
                            roleIcon = {
                                alpha = 0.85,
                                corner = "TOPRIGHT",
                                enabled = true,
                                filter = "nonDps",
                                iconType = "twich",
                                insetX = 1,
                                insetY = 1,
                                size = 18
                            },
                            rowSpacing = 18,
                            showPlayer = false,
                            showSolo = true,
                            spiritIndicator = {
                                enabled = true,
                                offsetY = 3
                            },
                            summonIndicator = {
                                enabled = true,
                                relativePoint = "CENTER"
                            },
                            unitsPerColumn = 5,
                            width = 125,
                            xOffset = 0,
                            yOffset = -8
                        },
                        tank = {
                            columnAnchorPoint = "LEFT",
                            columnSpacing = 6,
                            enabled = true,
                            groupBy = "GROUP",
                            groupingOrder = "1,2,3,4,5,6,7,8",
                            growthDirection = "UP",
                            healerOnlyPower = true,
                            height = 40,
                            infoBar = {
                                bgColor = { 0.0823529, 0.0941177, 0.12549, 1 },
                                borderColor = { 0.0588235, 0.0666667, 0.0784314, 1 },
                                enabled = true,
                                fontName = "Exo2 Bold",
                                height = 13,
                                numTexts = 2,
                                outlineMode = "NONE",
                                shadowEnabled = true,
                                text1 = {
                                    fontSize = 12,
                                    tag = "[name(8)]",
                                    useClassColor = true
                                },
                                text2 = {
                                    fontSize = 10,
                                    justify = "RIGHT",
                                    tag = "[perhp]",
                                    useClassColor = true
                                },
                                text3 = {
                                    fontSize = 14,
                                    tag = "[perhp]%"
                                }
                            },
                            maxColumns = 5,
                            point = "TOP",
                            roleFilter = "TANK",
                            roleIcon = {
                                alpha = 0.85,
                                corner = "TOPRIGHT",
                                enabled = true,
                                filter = "nonDps",
                                iconType = "twich",
                                insetX = 1,
                                insetY = 1,
                                size = 18
                            },
                            rowSpacing = 18,
                            showPlayer = false,
                            showPower = false,
                            showSolo = true,
                            unitsPerColumn = 5,
                            width = 150,
                            xOffset = 0,
                            yOffset = -8
                        }
                    },
                    healthColorByScope = {
                        boss = {
                            color = { 0.780392, 0.258824, 0.227451, 1 },
                            mode = "custom"
                        },
                        party = {
                            color = { 0.780392, 0.258824, 0.227451, 1 },
                            mode = "class"
                        },
                        raid = {
                            color = { 0.780392, 0.258824, 0.227451, 1 },
                            mode = "class"
                        },
                        singles = {
                            color = { 0.94902, 0.776471, 0.439216, 1 },
                            mode = "class"
                        },
                        tank = {
                            color = { 0.780392, 0.258824, 0.227451, 1 },
                            mode = "class"
                        }
                    },
                    highlights = {
                        enemyTargetMode = "border",
                        enemyTargetWidth = 2,
                        mouseoverColor = { 1, 1, 1, 0.08 },
                        showEnemyTarget = true,
                        showMouseover = true,
                        showTarget = true,
                        showThreat = true,
                        targetColor = { 0.780392, 0.796079, 0.847059, 0.4 },
                        targetMode = "glow",
                        targetWidth = 2,
                        threatColor = { 1, 0.239216, 0.180392, 0.7 },
                        threatMode = "glow",
                        threatWidth = 2
                    },
                    layout = {
                        boss = {
                            point = "CENTER",
                            relativePoint = "CENTER",
                            x = 0,
                            y = 655
                        },
                        boss1 = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 1775,
                            y = 1328
                        },
                        boss2 = {},
                        boss3 = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 1837,
                            y = 1135
                        },
                        boss4 = {},
                        boss5 = {},
                        castbar = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 1534,
                            y = 322
                        },
                        focus = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 2203,
                            y = 861
                        },
                        party = {
                            point = "CENTER",
                            relativePoint = "CENTER",
                            x = 0,
                            y = -475
                        },
                        partyMember = {},
                        pet = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 2250,
                            y = 699
                        },
                        player = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 1232,
                            y = 404
                        },
                        player_power = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 1534,
                            y = 439
                        },
                        raid = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 1398,
                            y = 46
                        },
                        raidMember = {},
                        tank = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 1209,
                            y = 49
                        },
                        tankMember = {},
                        target = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 1909,
                            y = 389
                        },
                        target_power = {},
                        targettarget = {
                            point = "BOTTOMLEFT",
                            relativePoint = "BOTTOMLEFT",
                            x = 2213,
                            y = 424
                        },
                        targettarget_power = {},
                        unit = {}
                    },
                    lockFrames = true,
                    powerColorMode = "powertype",
                    powerTypeColors = {
                        MANA = { 0, 0.501961, 1, 1 }
                    },
                    scale = 1,
                    showHealthText = true,
                    showPowerText = true,
                    smoothBars = true,
                    spellGroups = {
                        g1 = {
                            label = "",
                            spellIds = ""
                        }
                    },
                    testMode = false,
                    testPreviewParty = true,
                    testPreviewRaid = false,
                    text = {
                        fontName = "Exo2 Bold",
                        healthFontSize = 10,
                        healthFormat = "missing",
                        nameFontSize = 11,
                        nameFormat = "full",
                        outlineMode = "NONE",
                        powerFontSize = 9,
                        powerFormat = "percent",
                        scopes = {
                            boss = {
                                customHealthTag = "[perhp]%",
                                fontName = "Exo2 Bold",
                                healthFontSize = 20,
                                healthFormat = "custom",
                                healthOffsetX = -4,
                                healthOffsetY = 0,
                                healthPoint = "RIGHT",
                                healthRelativePoint = "RIGHT",
                                nameFontSize = 18,
                                nameFormat = "full",
                                nameOffsetX = 4,
                                nameOffsetY = 0,
                                namePoint = "LEFT",
                                nameRelativePoint = "LEFT",
                                outlineMode = "NONE",
                                powerFontSize = 10,
                                powerFormat = "percent",
                                powerOffsetX = -4,
                                powerOffsetY = 0,
                                powerPoint = "RIGHT",
                                powerRelativePoint = "RIGHT",
                                shadowColor = { 0, 0, 0, 0.85 },
                                shadowEnabled = true,
                                shadowOffsetX = 1,
                                shadowOffsetY = -1
                            },
                            party = {
                                customHealthTag = "[perhp]",
                                customNameTag = "[name(8)]",
                                fontName = "Exo2 Bold",
                                healthFontSize = 16,
                                healthFormat = "custom",
                                healthOffsetX = -4,
                                healthOffsetY = -2,
                                healthPoint = "TOPRIGHT",
                                healthRelativePoint = "TOPRIGHT",
                                nameFontSize = 14,
                                nameFormat = "custom",
                                nameOffsetX = 2,
                                nameOffsetY = -2,
                                namePoint = "TOPLEFT",
                                nameRelativePoint = "TOPLEFT",
                                outlineMode = "NONE",
                                powerFontSize = 10,
                                powerFormat = "percent",
                                powerOffsetX = -10,
                                powerOffsetY = 0,
                                powerPoint = "CENTER",
                                powerRelativePoint = "RIGHT",
                                shadowColor = { 0, 0, 0, 0.85 },
                                shadowEnabled = true,
                                shadowOffsetX = 1,
                                shadowOffsetY = -1
                            },
                            raid = {
                                customHealthTag = "",
                                customNameTag = "[name(8)]",
                                fontName = "Exo2 Bold",
                                healthFontSize = 16,
                                healthFormat = "none",
                                healthOffsetX = -4,
                                healthOffsetY = -2,
                                healthPoint = "TOPRIGHT",
                                healthRelativePoint = "TOPRIGHT",
                                nameFontSize = 14,
                                nameFormat = "none",
                                nameOffsetX = 2,
                                nameOffsetY = -2,
                                namePoint = "TOPLEFT",
                                nameRelativePoint = "TOPLEFT",
                                outlineMode = "NONE",
                                powerFontSize = 10,
                                powerFormat = "none",
                                powerOffsetX = -10,
                                powerOffsetY = 0,
                                powerPoint = "CENTER",
                                powerRelativePoint = "RIGHT",
                                shadowColor = { 0, 0, 0, 0.85 },
                                shadowEnabled = true,
                                shadowOffsetX = 1,
                                shadowOffsetY = -1
                            },
                            singles = {
                                fontName = "Exo2 Bold",
                                healthFontSize = 10,
                                healthFormat = "current",
                                healthOffsetX = -4,
                                healthOffsetY = 0,
                                healthPoint = "RIGHT",
                                healthRelativePoint = "RIGHT",
                                nameFontSize = 11,
                                nameFormat = "full",
                                nameOffsetX = 4,
                                nameOffsetY = 0,
                                namePoint = "LEFT",
                                nameRelativePoint = "LEFT",
                                outlineMode = "OUTLINE",
                                powerFontSize = 9,
                                powerFormat = "percent",
                                powerOffsetX = -4,
                                powerOffsetY = 0,
                                powerPoint = "RIGHT",
                                powerRelativePoint = "RIGHT",
                                shadowColor = { 0, 0, 0, 0.85 },
                                shadowEnabled = false,
                                shadowOffsetX = 1,
                                shadowOffsetY = -1
                            },
                            tank = {
                                customHealthTag = "",
                                customNameTag = "[name(8)]",
                                fontName = "Exo2 Bold",
                                healthFontSize = 16,
                                healthFormat = "none",
                                healthOffsetX = -4,
                                healthOffsetY = -2,
                                healthPoint = "TOPRIGHT",
                                healthRelativePoint = "TOPRIGHT",
                                nameFontSize = 14,
                                nameFormat = "none",
                                nameOffsetX = 2,
                                nameOffsetY = -2,
                                namePoint = "TOPLEFT",
                                nameRelativePoint = "TOPLEFT",
                                outlineMode = "NONE",
                                powerFontSize = 10,
                                powerFormat = "none",
                                powerOffsetX = -10,
                                powerOffsetY = 0,
                                powerPoint = "CENTER",
                                powerRelativePoint = "RIGHT",
                                shadowColor = { 0, 0, 0, 0.85 },
                                shadowEnabled = true,
                                shadowOffsetX = 1,
                                shadowOffsetY = -1
                            }
                        },
                        shadowColor = { 0, 0, 0, 0.85 },
                        shadowEnabled = false,
                        shadowOffsetX = 1,
                        shadowOffsetY = -1
                    },
                    units = {
                        boss = {
                            enabled = true,
                            height = 35,
                            powerHeight = 8,
                            showPower = true,
                            width = 500
                        },
                        boss1 = {
                            enabled = true,
                            height = 36,
                            powerHeight = 8,
                            showPower = true,
                            width = 220
                        },
                        boss2 = {
                            enabled = true,
                            height = 36,
                            powerHeight = 8,
                            showPower = true,
                            width = 220
                        },
                        boss3 = {
                            enabled = true,
                            height = 36,
                            powerHeight = 8,
                            showPower = true,
                            width = 220
                        },
                        boss4 = {
                            enabled = true,
                            height = 36,
                            powerHeight = 8,
                            showPower = true,
                            width = 220
                        },
                        boss5 = {
                            enabled = true,
                            height = 36,
                            powerHeight = 8,
                            showPower = true,
                            width = 220
                        },
                        castbar = {},
                        focus = {
                            colors = {},
                            enabled = true,
                            healthColor = {},
                            height = 34,
                            powerDetached = false,
                            powerHeight = 8,
                            powerOffsetX = 0,
                            powerOffsetY = -1,
                            powerPoint = "TOPLEFT",
                            powerRelativePoint = "BOTTOMLEFT",
                            powerWidth = 220,
                            showPower = true,
                            text = {},
                            width = 220
                        },
                        party = {},
                        partyMember = {
                            healPrediction = {
                                healAbsorbColor = { 0.0588235, 0.0705882, 0.0901961, 0.4 },
                                maxOverflow = 1
                            }
                        },
                        pet = {
                            enabled = true,
                            height = 28,
                            powerDetached = false,
                            powerHeight = 7,
                            powerOffsetX = 0,
                            powerOffsetY = -1,
                            powerPoint = "TOPLEFT",
                            powerRelativePoint = "BOTTOMLEFT",
                            powerWidth = 170,
                            showPower = true,
                            text = {},
                            width = 170
                        },
                        player = {
                            auras = {
                                barBackground = { 0.133333, 0.14902, 0.176471, 1 },
                                barBackgroundTexture = "TwichUI AngledLines",
                                barFontName = "Inter Bold",
                                barFontSize = 14,
                                barHeight = 20,
                                barMode = true,
                                buffBarColor = { 0.14902, 0.470588, 0.870588, 0.85 },
                                buffBarFontSize = 14,
                                debuffBarColor = { 0.780392, 0.258824, 0.227451, 0.901961 },
                                debuffBarFontSize = 14,
                                enabled = true,
                                filter = "HARMFUL",
                                onlyMine = true,
                                spacing = 1,
                                yOffset = 30
                            },
                            classArtworkEnabled = false,
                            classArtworkOffsetX = -13,
                            classArtworkOffsetY = 13,
                            classArtworkScale = 0.5,
                            colors = {
                                background = { 0.133333, 0.14902, 0.176471, 1 },
                                power = { 0.196078, 0.631373, 0.85098, 1 },
                                powerBorder = { 0.105882, 0.12549, 0.160784, 0.8 }
                            },
                            combatIndicator = {
                                enabled = true,
                                iconType = "twich",
                                offsetY = 0,
                                point = "CENTER",
                                relativePoint = "CENTER",
                                size = 40
                            },
                            enabled = true,
                            healPrediction = {
                                maxOverflow = 1
                            },
                            healthColor = {
                                color = { 0.752941, 0.654902, 0.533333, 1 },
                                mode = "theme"
                            },
                            height = 50,
                            highlights = {
                                showTarget = false
                            },
                            indicators = {},
                            powerDetached = true,
                            powerFx = {
                                effectScale = 1,
                                enabled = true,
                                theme = "moon"
                            },
                            powerHeight = 15,
                            powerOffsetX = 0,
                            powerOffsetY = 120,
                            powerPoint = "CENTER",
                            powerRelativePoint = "TOP",
                            powerWidth = 372,
                            restingIndicator = {
                                enabled = true,
                                iconType = "twich",
                                offsetX = 5,
                                offsetY = 2,
                                point = "CENTER",
                                relativePoint = "CENTER",
                                size = 40
                            },
                            showPower = true,
                            text = {
                                customHealthTag = "[perhp]",
                                customNameTag = "[name(3)]",
                                customPowerTag = "[perpp]",
                                fontName = "Exo2 Bold",
                                healthColor = { 1, 1, 1, 1 },
                                healthFontSize = 24,
                                healthFormat = "custom",
                                healthOffsetY = 15,
                                healthPoint = "TOPRIGHT",
                                healthRelativePoint = "TOPRIGHT",
                                nameColor = { 1, 1, 1, 1 },
                                nameFontSize = 24,
                                nameFormat = "full",
                                nameJustify = "LEFT",
                                nameOffsetX = 0,
                                nameOffsetY = 23,
                                namePoint = "TOPLEFT",
                                nameRelativePoint = "TOPLEFT",
                                outlineMode = "NONE",
                                powerFontSize = 18,
                                powerFormat = "custom",
                                powerOffsetY = 10,
                                powerPoint = "CENTER",
                                powerRelativePoint = "CENTER",
                                shadowEnabled = true
                            },
                            width = 300
                        },
                        player_power = {},
                        raid = {},
                        raidMember = {
                            healPrediction = {
                                maxOverflow = 1
                            }
                        },
                        tank = {},
                        tankMember = {
                            healPrediction = {
                                maxOverflow = 1
                            }
                        },
                        target = {
                            auras = {
                                barBackground = { 0.133333, 0.14902, 0.176471, 1 },
                                barBackgroundTexture = "TwichUI AngledLines",
                                barColor = { 0.27451, 0.309804, 0.392157, 1 },
                                barFontName = "Inter Bold",
                                barFontSize = 14,
                                barHeight = 20,
                                barMode = true,
                                barTexture = "TwichUI Bright",
                                buffBarColor = { 0.196078, 0.631373, 0.85098, 0.960784 },
                                buffBarFontSize = 14,
                                buffUseThemeAccentBackground = false,
                                buffUseThemeAccentFill = true,
                                debuffBarColor = { 0.780392, 0.258824, 0.227451, 0.9 },
                                debuffBarFontSize = 14,
                                enabled = true,
                                filter = "ALL",
                                onlyMine = true,
                                spacing = 1,
                                yOffset = 30
                            },
                            colors = {
                                background = { 0.133333, 0.14902, 0.176471, 1 },
                                power = { 0.196078, 0.631373, 0.85098, 1 },
                                powerBorder = { 0.105882, 0.12549, 0.160784, 0.8 },
                                powerColorMode = "powertype"
                            },
                            enabled = true,
                            healPrediction = {
                                maxOverflow = 1.1,
                                playerColor = { 0.34, 0.84, 0.54, 0.75 }
                            },
                            healthColor = {
                                color = { 0.94902, 0.776471, 0.439216, 1 },
                                mode = "class"
                            },
                            height = 65,
                            highlights = {
                                showTarget = false
                            },
                            powerDetached = false,
                            powerHeight = 12,
                            powerOffsetX = 0,
                            powerOffsetY = 120,
                            powerPoint = "CENTER",
                            powerRelativePoint = "CENTER",
                            powerWidth = 372,
                            showPower = true,
                            text = {
                                customHealthTag = "[perhp]",
                                customNameTag = "[name(8)]",
                                customPowerTag = "[perpp]",
                                fontName = "Exo2 Bold",
                                healthFontSize = 24,
                                healthFormat = "custom",
                                healthOffsetY = 15,
                                healthPoint = "TOPRIGHT",
                                healthRelativePoint = "TOPRIGHT",
                                nameColor = { 1, 1, 1, 1 },
                                nameFontSize = 24,
                                nameFormat = "custom",
                                nameJustify = "LEFT",
                                nameOffsetX = 0,
                                nameOffsetY = 23,
                                namePoint = "TOPLEFT",
                                nameRelativePoint = "TOPLEFT",
                                outlineMode = "NONE",
                                powerFontSize = 12,
                                powerFormat = "custom",
                                powerOffsetX = -15,
                                powerOffsetY = 0,
                                powerPoint = "CENTER",
                                powerRelativePoint = "RIGHT",
                                shadowEnabled = true
                            },
                            width = 300
                        },
                        targettarget = {
                            auras = {
                                barMode = true,
                                enabled = false,
                                filter = "HELPFUL",
                                onlyMine = false
                            },
                            colors = {
                                background = { 0.133333, 0.14902, 0.176471, 1 },
                                power = { 0.196078, 0.631373, 0.85098, 1 },
                                powerBackground = { 0.05, 0.06, 0.08, 0.85 },
                                powerBorder = { 0.105882, 0.12549, 0.160784, 0.8 },
                                powerColorMode = "powertype"
                            },
                            enabled = true,
                            healthColor = {
                                color = { 0.94902, 0.776471, 0.439216, 1 },
                                mode = "class"
                            },
                            height = 30,
                            highlights = {
                                showTarget = false
                            },
                            infoBar = {
                                enabled = false
                            },
                            powerDetached = false,
                            powerHeight = 15,
                            powerOffsetX = 0,
                            powerOffsetY = 120,
                            powerPoint = "CENTER",
                            powerRelativePoint = "CENTER",
                            powerWidth = 372,
                            showPower = false,
                            text = {
                                customHealthTag = "[perhp]",
                                customNameTag = "[name(3)]",
                                customPowerTag = "[perpp]",
                                fontName = "Exo2 Bold",
                                healthFontSize = 18,
                                healthFormat = "custom",
                                healthOffsetX = -2,
                                healthOffsetY = 0,
                                healthPoint = "RIGHT",
                                healthRelativePoint = "RIGHT",
                                nameColor = { 1, 1, 1, 1 },
                                nameFontSize = 14,
                                nameFormat = "full",
                                nameJustify = "LEFT",
                                nameOffsetX = 2,
                                nameOffsetY = 0,
                                namePoint = "LEFT",
                                nameRelativePoint = "LEFT",
                                outlineMode = "NONE",
                                powerFontSize = 22,
                                powerFormat = "custom",
                                powerOffsetY = 0,
                                powerPoint = "RIGHT",
                                powerRelativePoint = "RIGHT",
                                shadowEnabled = true
                            },
                            width = 200
                        },
                        unit = {}
                    },
                    useClassColor = false,
                    useThemeAccentHealth = false
                },
                worldQuests = {
                    enabled = true,
                    enabledFilters = {
                        dungeon = true,
                        gear = true,
                        gold = true,
                        items = true,
                        pet = true,
                        profession = true,
                        pvp = true,
                        rare = true,
                        reputation = true,
                        time = true,
                        tracked = true
                    },
                    hideUntrackedPOI = true,
                    selectedFilters = {}
                },
            })
        end,
    },
    -- Paste the block above into AVAILABLE_LAYOUTS in Layouts.lua

    -- Paste the block above into AVAILABLE_LAYOUTS in Layouts.lua
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
