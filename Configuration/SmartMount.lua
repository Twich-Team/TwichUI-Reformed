local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class SmartMountConfigurationOptions
local Options = ConfigurationModule.Options.SmartMount

-- ─── Keybind capture popup ──────────────────────────────────────────────────
-- Bypasses the AceGUI "keybinding" widget (which ElvUI overrides at a higher
-- LibStub version and doesn't correctly ignore bare modifier-key presses).
-- This frame is TwichUI-owned: modifier keys are always filtered out and the
-- resulting string is in WoW's canonical SetBinding format (e.g. "SHIFT-SPACE").

local MODIFIER_ONLY = {
    LSHIFT = true, RSHIFT = true,
    LCTRL  = true, RCTRL  = true,
    LALT   = true, RALT   = true,
}

local keybindCaptureFrame = nil

local function GetKeybindCaptureFrame()
    if keybindCaptureFrame then return keybindCaptureFrame end

    local CreateFrame = _G.CreateFrame
    local UIParent    = _G.UIParent
    local IsShiftKeyDown   = _G.IsShiftKeyDown
    local IsControlKeyDown = _G.IsControlKeyDown
    local IsAltKeyDown     = _G.IsAltKeyDown

    local f = CreateFrame("Frame", "TwichUIKeybindCapture", UIParent, "BackdropTemplate")
    f:SetSize(300, 90)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(200)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.05, 0.06, 0.08, 0.97)
    f:SetBackdropBorderColor(0.10, 0.72, 0.74, 1)
    f:EnableKeyboard(true)
    f:SetPropagateKeyboardInput(false)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOP", f, "TOP", 0, -14)
    title:SetText("|cff19c9c7Smart Mount|r — Press a key combination")
    title:SetTextColor(0.85, 0.90, 0.95)

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("CENTER", f, "CENTER", 0, 4)
    hint:SetText("Press ESC to cancel, Backspace to clear")
    hint:SetTextColor(0.50, 0.52, 0.58)

    local cancelBtn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    cancelBtn:SetSize(70, 22)
    cancelBtn:SetPoint("BOTTOM", f, "BOTTOM", 0, 10)
    cancelBtn:SetText("Cancel")
    cancelBtn:SetScript("OnClick", function() f:Hide() end)

    f:SetScript("OnKeyDown", function(self, key)
        -- Swallow the event so WoW doesn't process it (e.g. jump on SPACE).
        f:SetPropagateKeyboardInput(false)

        -- Ignore bare modifier presses — wait for the actual key.
        if MODIFIER_ONLY[key] then return end

        if key == "ESCAPE" then
            f:Hide()
            return
        end

        -- Build the canonical binding string.
        local binding = ""
        if IsShiftKeyDown()   then binding = binding .. "SHIFT-" end
        if IsControlKeyDown() then binding = binding .. "CTRL-"  end
        if IsAltKeyDown()     then binding = binding .. "ALT-"   end

        if key == "BACKSPACE" then
            -- Empty string = clear the binding.
            binding = ""
        else
            binding = binding .. key
        end

        if f.onCapture then
            f.onCapture(binding)
        end
        f:Hide()
    end)

    keybindCaptureFrame = f
    return f
end

local function OpenKeybindCapture(onCapture)
    local f = GetKeybindCaptureFrame()
    f.onCapture = onCapture
    f:Show()
    f:SetFrameLevel(200)
end

local function BuildSmartMountTab(order)
    local groundSelector = nil
    local flyingSelector = nil
    local aquaticSelector = nil

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

    local function TooltipHide()
        if _G.GameTooltip and _G.GameTooltip.Hide then
            _G.GameTooltip:Hide()
        end
    end

    local function BuildMountCandidates(isAquatic)
        -- Always rebuild the candidate list so each selector (ground/flying/aquatic)
        -- gets the correct filter set instead of reusing the first one.
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
        if isAquatic then
            mounts = MountUtilityModule:GetPlayerMounts("AQUATIC")
        else
            mounts = MountUtilityModule:GetPlayerMounts("ALL")
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

    local function OpenMountSelector(kind)
        local selector = nil
        local currentlySelected = nil
        local title = nil
        local current = 0

        if kind == "ground" then
            if not groundSelector then
                groundSelector = T.Tools.UI.CreateSearchSelector("TwichUIGroundMountSelector", { hint = "Search mounts" }) or
                    nil
            end
            selector = groundSelector
            title = "Select Ground Mount"
            currentlySelected = Options:GetSelectedGroundMount()
        elseif kind == "aquatic" then
            if not aquaticSelector then
                aquaticSelector = T.Tools.UI.CreateSearchSelector("TwichUIAquaticMountSelector",
                        { hint = "Search mounts" }) or
                    nil
            end
            selector = aquaticSelector
            title = "Select Aquatic Mount"
            currentlySelected = Options:GetSelectedAquaticMount()
        else
            if not flyingSelector then
                flyingSelector = T.Tools.UI.CreateSearchSelector("TwichUIFlyingMountSelector", { hint = "Search mounts" }) or
                    nil
            end
            selector = flyingSelector
            title = "Select Flying Mount"
            currentlySelected = Options:GetSelectedFlyingMount()
        end

        if not selector then
            return
        end

        current = currentlySelected or 0

        local E = _G.ElvUI and _G.ElvUI[1]
        local optionsFrame = (E and (E.OptionsUI or E.OptionsFrame)) or _G.UIParent
        selector:Open({
            title = title,
            candidates = BuildMountCandidates(kind == "aquatic"),
            selectedValue = current,
            relativeTo = optionsFrame,
            onSelect = function(value)
                if kind == "ground" then
                    Options:SetSelectedGroundMount(nil, tonumber(value) or 0)
                elseif kind == "aquatic" then
                    Options:SetSelectedAquaticMount(nil, tonumber(value) or 0)
                else
                    Options:SetSelectedFlyingMount(nil, tonumber(value) or 0)
                end
                ConfigurationModule:Refresh()
            end,
        })
    end

    return {
        type = "group",
        name = "Smart Mount",
        order = order or 8,
        args = {
            title = ConfigurationModule.Widgets.TitleWidget(1, "Smart Mount"),
            description = {
                type = "description",
                order = 2,
                name =
                "Smart mount enables the /smartmount command, which will automatically choose between your selected mounts based on your current situation."
            },
            enableSmartMount = {
                type = "toggle",
                name = "Enable",
                desc = "Enables or disables the Smart Mount feature.",
                handler = Options,
                get = "GetEnabled",
                set = "SetEnabled",
                order = 5,
            },
            enableDismountIfMounted = {
                type = "toggle",
                name = "Dismount if Mounted",
                desc = "Using the slash command while already mounted will dismount you.",
                handler = Options,
                get = "GetDismountIfMounted",
                set = "SetDismountIfMounted",
                order = 6,
            },
            enableAquaticMounts = {
                type = "toggle",
                name = "Use Aquatic Mounts",
                desc = "Will choose aquatic mounts when swimming if available.",
                handler = Options,
                get = "GetUseAquaticMounts",
                set = "SetUseAquaticMounts",
                order = 7,
            },
            keybinding = {
                type = "execute",
                name = function()
                    local k = Options:GetSmartMountKeybinding()
                    if k and k ~= "" then
                        return "Bound: |cffffd700" .. k .. "|r  (click to change)"
                    end
                    return "Set Keybinding  |cff808080(unbound)|r"
                end,
                desc = "Click to capture a new keybind. Press Backspace inside the capture window to clear it.",
                order = 8,
                func = function()
                    OpenKeybindCapture(function(binding)
                        Options:SetSmartMountKeybinding(nil, binding)
                        ConfigurationModule:Refresh()
                    end)
                end,
            },
            cache = {
                type = "group",
                name = "Cache",
                order = 11,
                args = {
                    description = {
                        type = "description",
                        name =
                        "The addon attempts to keep its list of known mounts updated automatically. If you think the cache is out of date, you can refresh it here.",
                        order = 1,
                    },
                    refreshCache = {
                        type = "execute",
                        width = "full",
                        name = "Refresh Mount Cache",
                        desc = "Clears and rebuilds the mount cache used by the Smart Mount system.",
                        order = 2,
                        func = function()
                            ---@type MountUtilityModule
                            local MountUtilityModule = T:GetModule("MountUtility")
                            MountUtilityModule:RefreshMountCache()
                            ConfigurationModule:Refresh()
                        end,
                    }
                }
            },
            favoriteMounts = {
                type = "group",
                name = "Selected Mounts",
                order = 10,
                args = {
                    description = {
                        type = "description",
                        name = "Choose which mount to use in flying and ground-only situations.",
                        order = 1,
                    },
                    groundMountGroup = {
                        type = "group",
                        name = "Ground Mount",
                        inline = true,
                        order = 2,
                        args = {
                            favoriteGroundMount = {
                                type = "execute",
                                width = "full",
                                name = function()
                                    local currentlySelected = Options:GetSelectedGroundMount() or 0
                                    --- @type MountUtilityModule
                                    local MountUtilityModule = T:GetModule("MountUtility")
                                    return tostring(MountUtilityModule:GetMountLabelByID(currentlySelected))
                                end,
                                desc = "Summoned when flying is not allowed.",
                                order = 2,
                                func = function()
                                    OpenMountSelector("ground")
                                end,

                            }
                        },
                    },
                    flyingMountGroup = {
                        type = "group",
                        name = "Flying Mount",
                        inline = true,
                        order = 3,
                        args = {
                            favoriteFlyingMount = {
                                type = "execute",
                                width = "full",
                                name = function()
                                    local currentlySelected = Options:GetSelectedFlyingMount() or 0
                                    --- @type MountUtilityModule
                                    local MountUtilityModule = T:GetModule("MountUtility")
                                    return tostring(MountUtilityModule:GetMountLabelByID(currentlySelected))
                                end,
                                desc = "Summoned when flying is allowed.",
                                order = 2,
                                func = function()
                                    OpenMountSelector("flying")
                                end,

                            }
                        },
                    },
                    aquaticMountGroup = {
                        type = "group",
                        name = "Aquatic Mount",
                        inline = true,
                        order = 3,
                        args = {
                            favoriteAquaticMount = {
                                type = "execute",
                                width = "full",
                                disabled = function()
                                    return not Options:GetUseAquaticMounts()
                                end,
                                name = function()
                                    local currentlySelected = Options:GetSelectedAquaticMount() or 0
                                    --- @type MountUtilityModule
                                    local MountUtilityModule = T:GetModule("MountUtility")
                                    return tostring(MountUtilityModule:GetMountLabelByID(currentlySelected))
                                end,
                                desc = "Summoned when you are swimming.",
                                order = 2,
                                func = function()
                                    OpenMountSelector("aquatic")
                                end,

                            }
                        },
                    }

                }
            }
        }
    }
end

ConfigurationModule.BuildSmartMountTab = BuildSmartMountTab
