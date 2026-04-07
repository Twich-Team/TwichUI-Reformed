---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@type BagsConfigurationOptions
local BagsOptions = ConfigurationModule.Options.Bags

local function BuildBagsConfiguration()
    local W = ConfigurationModule.Widgets

    return {
        type = "group",
        name = "Bags",
        order = 20,
        args = {
            title = W.TitleWidget(0, "Bags"),
            desc = W.Description(1,
                "Standalone TwichUI bag replacement inspired by Baganator: categorized sections, recents highlighting, draggable frame, and optional Masque skinning."),

            enable = {
                type = "toggle",
                name = "Enable",
                desc = "Enable the TwichUI Bags module and route bag toggles to this frame.",
                order = 2,
                handler = BagsOptions,
                get = "GetEnabled",
                set = "SetEnabled",
            },

            controls = W.IGroup(5, "Controls", {
                open = {
                    type = "execute",
                    name = "Toggle Bags",
                    desc = "Open or close the TwichUI Bags frame.",
                    order = 1,
                    handler = BagsOptions,
                    func = "ToggleFrame",
                },
                lockFrame = {
                    type = "toggle",
                    name = "Lock Frame",
                    desc = "Prevent dragging the bags frame.",
                    order = 2,
                    width = 1.2,
                    handler = BagsOptions,
                    get = "GetLockFrame",
                    set = "SetLockFrame",
                },
                resetFrame = {
                    type = "execute",
                    name = "Reset Position",
                    desc = "Restore default frame position.",
                    order = 3,
                    width = 1.2,
                    handler = BagsOptions,
                    func = "ResetFramePosition",
                },
            }),

            layout = W.IGroup(10, "Layout", {
                iconSize = {
                    type = "range",
                    name = "Item Size",
                    desc = "Size of each item icon.",
                    order = 1,
                    min = 24,
                    max = 54,
                    step = 1,
                    width = 1.4,
                    handler = BagsOptions,
                    get = "GetIconSize",
                    set = "SetIconSize",
                },
                columns = {
                    type = "range",
                    name = "Columns",
                    desc = "How many item columns each section uses.",
                    order = 2,
                    min = 6,
                    max = 20,
                    step = 1,
                    width = 1.2,
                    handler = BagsOptions,
                    get = "GetColumns",
                    set = "SetColumns",
                },
                itemSpacing = {
                    type = "range",
                    name = "Item Spacing",
                    desc = "Spacing between item icons.",
                    order = 3,
                    min = 2,
                    max = 12,
                    step = 1,
                    width = 1.2,
                    handler = BagsOptions,
                    get = "GetItemSpacing",
                    set = "SetItemSpacing",
                },
                sectionSpacing = {
                    type = "range",
                    name = "Section Spacing",
                    desc = "Vertical spacing between category sections.",
                    order = 4,
                    min = 8,
                    max = 24,
                    step = 1,
                    width = 1.2,
                    handler = BagsOptions,
                    get = "GetSectionSpacing",
                    set = "SetSectionSpacing",
                },
                showEmpty = {
                    type = "toggle",
                    name = "Show Empty Categories",
                    desc = "Keep section headers visible even when that category has no items.",
                    order = 5,
                    width = 1.4,
                    handler = BagsOptions,
                    get = "GetShowEmptyCategories",
                    set = "SetShowEmptyCategories",
                },
                showEquipmentSets = {
                    type = "toggle",
                    name = "Show Equipment Set Categories",
                    desc = "Create dynamic sections for each saved equipment set (for example: Set: Ret Set).",
                    order = 6,
                    width = 1.6,
                    handler = BagsOptions,
                    get = "GetShowEquipmentSetCategories",
                    set = "SetShowEquipmentSetCategories",
                },
            }),

            visuals = W.IGroup(20, "Visuals", {
                scale = {
                    type = "range",
                    name = "Frame Scale",
                    desc = "Scale of the entire bags frame.",
                    order = 1,
                    min = 0.7,
                    max = 1.4,
                    step = 0.01,
                    isPercent = false,
                    width = 1.3,
                    handler = BagsOptions,
                    get = "GetScale",
                    set = "SetScale",
                },
                alpha = {
                    type = "range",
                    name = "Frame Opacity",
                    desc = "Opacity of the bags frame.",
                    order = 2,
                    min = 0.55,
                    max = 1.0,
                    step = 0.01,
                    isPercent = true,
                    width = 1.3,
                    handler = BagsOptions,
                    get = "GetAlpha",
                    set = "SetAlpha",
                },
                useMasque = {
                    type = "toggle",
                    name = "Use Masque",
                    desc = "Apply Masque skin styling to bag icons when Masque is installed.",
                    order = 3,
                    width = 1.4,
                    disabled = function() return not BagsOptions:IsMasqueAvailable() end,
                    handler = BagsOptions,
                    get = "GetUseMasque",
                    set = "SetUseMasque",
                },
            }),

            recents = W.IGroup(30, "New Items", {
                showNew = {
                    type = "toggle",
                    name = "Highlight New Items",
                    desc = "Show new-item pulse highlights and include the Recent category.",
                    order = 1,
                    width = 1.6,
                    handler = BagsOptions,
                    get = "GetShowNewItems",
                    set = "SetShowNewItems",
                },
                timeout = {
                    type = "range",
                    name = "Recent Timeout",
                    desc = "How long an item stays marked as new after it is acquired (seconds).",
                    order = 2,
                    min = 5,
                    max = 600,
                    step = 5,
                    width = 1.5,
                    disabled = function() return not BagsOptions:GetShowNewItems() end,
                    handler = BagsOptions,
                    get = "GetNewItemTimeout",
                    set = "SetNewItemTimeout",
                },
            }),

            debug = W.IGroup(40, "Debug", {
                enableDebug = {
                    type = "toggle",
                    name = "Enable Bags Debug Logs",
                    desc = "Route Bags internals to the TwichUI Debug Console source: bags.",
                    order = 1,
                    width = 1.6,
                    handler = BagsOptions,
                    get = "GetDebugEnabled",
                    set = "SetDebugEnabled",
                },
                openDebug = {
                    type = "execute",
                    name = "Open Bags Debug Console",
                    desc = "Open the Debug Console directly on the Bags source.",
                    order = 2,
                    width = 1.4,
                    handler = BagsOptions,
                    func = "OpenDebugConsole",
                },
            }),
        },
    }
end

ConfigurationModule:RegisterConfigurationFunction("Bags", BuildBagsConfiguration)
