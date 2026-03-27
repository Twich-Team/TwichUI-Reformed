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
    {
        id          = "standard",
        name        = "Standard",
        description = "Add a description here.",
        role        = "any", -- "any" | "dps" | "healer" | "tank"
        frames      = {
            ChatFrame1 = { x = 0.01017, y = 0.03472, w = 0.12500, h = 0.11806 },
        },
        apply       = function()
            local T = unpack(_G.TwichRx)
            T:GetModule("SetupWizard"):RestoreConfigSnapshot({
                chatEnhancement = {
                    controlButtons = {},
                    headerDatatext = {},
                    routingEntries = {},
                    tabStyle = "unified"
                },
                chores = {
                    categories = {},
                    preyDifficulties = {},
                    raidWings = {}
                },
                datatext = {
                    chores = {
                        tracker = {}
                    },
                    currencies = {
                        customDatatexts = {},
                        displayStyle = "ICON_TEXT_ABBR",
                        displayedCurrency = "GOLD",
                        showGoldInTooltip = true,
                        showMax = true,
                        tooltipCurrencyIDs = {}
                    },
                    enabled = true,
                    mythicplus = {},
                    portals = {},
                    standalone = {
                        enabled = true,
                        locked = true,
                        panels = {
                            panel1 = {
                                enabled = true,
                                height = 28,
                                id = "panel1",
                                name = "Primary Panel",
                                point = "BOTTOM",
                                relativePoint = "BOTTOM",
                                segments = 3,
                                slot1 = "TwichUI: Chores",
                                slot2 = "TwichUI: Mythic+",
                                slot3 = "TwichUI: Portals",
                                slot4 = "NONE",
                                slot5 = "NONE",
                                useStyleOverrides = false,
                                width = 3440,
                                x = 0,
                                y = 6
                            }
                        },
                        style = {
                            accentAlpha = 0.95,
                            accentColor = { 0.96, 0.76, 0.24, 1 },
                            backgroundAlpha = 0.94,
                            backgroundColor = { 0.05, 0.06, 0.08, 1 },
                            borderAlpha = 0.85,
                            borderColor = { 0.24, 0.26, 0.32, 1 },
                            dividerAlpha = 0.28,
                            font = "Friz Quadrata TT",
                            fontOutline = false,
                            fontSize = 12,
                            hoverBarAlpha = 0.92,
                            hoverBarColor = { 0.96, 0.76, 0.24, 1 },
                            hoverGlowAlpha = 0.09,
                            hoverGlowColor = { 0.96, 0.76, 0.24, 1 },
                            menuFont = "Friz Quadrata TT",
                            menuFontSize = 12,
                            showDragHandle = true,
                            textAlign = "CENTER",
                            textShadowAlpha = 0.85,
                            tooltipFont = "Friz Quadrata TT",
                            tooltipFontSize = 11
                        }
                    }
                },
            })
        end,
    },
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
