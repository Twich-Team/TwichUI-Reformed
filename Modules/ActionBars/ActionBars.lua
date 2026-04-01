---@diagnostic disable: undefined-field, inject-field, invisible, deprecated
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class ActionBarsModule : AceModule, AceEvent-3.0
local ActionBars = T:NewModule("ActionBars", "AceEvent-3.0")
_G.TwichUIActionBarsRuntime = ActionBars

local CreateFrame = _G.CreateFrame
local UIParent = _G.UIParent
local InCombatLockdown = _G.InCombatLockdown
local RegisterStateDriver = _G.RegisterStateDriver
local UnregisterStateDriver = _G.UnregisterStateDriver
local UIParent_ManageFramePositions = _G.UIParent_ManageFramePositions
local UpdateMicroButtons = _G.UpdateMicroButtons
local GetNumShapeshiftForms = _G.GetNumShapeshiftForms
local GetActionInfo = _G.GetActionInfo
local GetBindingKey = _G.GetBindingKey
local GetBindingText = _G.GetBindingText
local GetCurrentBindingSet = _G.GetCurrentBindingSet
local LoadBindings = _G.LoadBindings
local SaveBindings = _G.SaveBindings
local SetBinding = _G.SetBinding
local SetBindingClick = _G.SetBindingClick
local IsAltKeyDown = _G.IsAltKeyDown
local IsControlKeyDown = _G.IsControlKeyDown
local IsShiftKeyDown = _G.IsShiftKeyDown
local IsMetaKeyDown = _G.IsMetaKeyDown
local C_SpellActivationOverlay = _G.C_SpellActivationOverlay
local IsSpellOverlayed = (C_SpellActivationOverlay and C_SpellActivationOverlay.IsSpellOverlayed) or _G.IsSpellOverlayed
local NUM_PET_ACTION_SLOTS = _G.NUM_PET_ACTION_SLOTS or 10
local NUM_STANCE_SLOTS = _G.NUM_STANCE_SLOTS or 10
local C_Timer = _G.C_Timer
local GetTime = _G.GetTime
local LibStub = _G.LibStub
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local ActionButton_ShowGrid = _G.ActionButton_ShowGrid
local ActionButton_HideGrid = _G.ActionButton_HideGrid
local ActionButton_ShowOverlayGlow = _G.ActionButton_ShowOverlayGlow
local ActionButton_HideOverlayGlow = _G.ActionButton_HideOverlayGlow

local floor = math.floor
local max = math.max
local min = math.min
local ceil = math.ceil
local pairs = pairs
local ipairs = ipairs
local type = type
local tostring = tostring
local find = string.find
local format = string.format
local upper = string.upper
local unpackValues = table.unpack or _G.unpack

local LSM = (T.Libs and T.Libs.LSM) or (LibStub and LibStub("LibSharedMedia-3.0", true))
local LBG = LibStub and LibStub("LibButtonGlow-1.0", true)
local Masque = LibStub and LibStub("Masque", true)
local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
local ErrorLog = T.Tools and T.Tools.ErrorLog

local DEFAULT_VISIBILITY = "[petbattle] hide; show"
local DEFAULT_HOLDER_PADDING = 6
local MOUSEOVER_FADE_DELAY = 0.08
local DEBUG_SOURCE_KEY = "actionbars"
local PIXEL_GLOW_ALPHA = 0.9

local function SplitBindingTarget(target)
    if type(target) ~= "string" then
        return nil, nil, nil
    end

    local frameName, clickButton = target:match("^CLICK%s+([^:]+):(.+)$")
    if frameName and clickButton then
        return "click", frameName, clickButton
    end

    return "command", target, nil
end
local BLIZZARD_FRAMES_TO_HIDE = {
    "MainMenuBar",
    "MainActionBar",
    "MainMenuBarArtFrame",
    "MainMenuBarArtFrameBackground",
    "MainMenuBarLeftEndCap",
    "MainMenuBarRightEndCap",
    "MultiBarBottomLeft",
    "MultiBarBottomRight",
    "MultiBarLeft",
    "MultiBarRight",
    "MultiBar5",
    "MultiBar6",
    "MultiBar7",
    "ExtraActionBarFrame",
    "PetActionBarFrame",
    "PetActionBar",
    "StanceBarFrame",
    "StanceBar",
    "PossessBarFrame",
    "PossessActionBar",
    "OverrideActionBar",
    "OverrideActionBarExpBar",
    "MicroButtonAndBagsBar",
    "BagsBar",
    "MainStatusTrackingBarContainer",
    "StatusTrackingBarManager",
    "CharacterMicroButton",
    "SpellbookMicroButton",
    "TalentMicroButton",
    "PlayerSpellsMicroButton",
    "AchievementMicroButton",
    "QuestLogMicroButton",
    "GuildMicroButton",
    "LFDMicroButton",
    "EJMicroButton",
    "CollectionsMicroButton",
    "MainMenuMicroButton",
    "HelpMicroButton",
    "StoreMicroButton",
    "ProfessionMicroButton",
    "PVPMicroButton",
    "HousingMicroButton",
    "MainMenuBarBackpackButton",
    "CharacterBag0Slot",
    "CharacterBag1Slot",
    "CharacterBag2Slot",
    "CharacterBag3Slot",
    "CharacterReagentBag0Slot",
    "MainMenuBarPerformanceBar",
}

local BLIZZARD_OBJECTS_TO_HIDE = {
    "MainMenuExpBar",
    "ReputationWatchBar",
    "HonorWatchBar",
    "ArtifactWatchBar",
    "ExhaustionTick",
    "MainMenuBarTexture0",
    "MainMenuBarTexture1",
    "MainMenuBarTexture2",
    "MainMenuBarTexture3",
    "SlidingActionBarTexture0",
    "SlidingActionBarTexture1",
    "MainMenuBarMaxLevelBar0",
    "MainMenuBarMaxLevelBar1",
    "MainMenuBarMaxLevelBar2",
    "MainMenuBarMaxLevelBar3",
}

local CUSTOM_BAR_PAGES = {
    bar9 = 2,
    bar10 = 7,
    bar11 = 8,
    bar12 = 9,
    bar13 = 10,
    bar14 = 11,
    bar15 = 12,
}

local BAR_DEFINITIONS = {
    {
        key = "bar1",
        label = "Bar 1",
        prefix = "ActionButton",
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 36,
    },
    {
        key = "bar2",
        label = "Bar 2",
        prefix = "MultiBarBottomLeftButton",
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 34,
    },
    {
        key = "bar3",
        label = "Bar 3",
        prefix = "MultiBarBottomRightButton",
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 34,
    },
    {
        key = "bar4",
        label = "Bar 4",
        prefix = "MultiBarRightButton",
        maxButtons = 12,
        fallbackButtonsPerRow = 1,
        fallbackButtonSize = 32,
    },
    {
        key = "bar5",
        label = "Bar 5",
        prefix = "MultiBarLeftButton",
        maxButtons = 12,
        fallbackButtonsPerRow = 1,
        fallbackButtonSize = 32,
    },
    {
        key = "bar6",
        label = "Bar 6",
        prefix = "MultiBar5Button",
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar7",
        label = "Bar 7",
        prefix = "MultiBar6Button",
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar8",
        label = "Bar 8",
        prefix = "MultiBar7Button",
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar9",
        label = "Bar 9",
        actionPage = CUSTOM_BAR_PAGES.bar9,
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar10",
        label = "Bar 10",
        actionPage = CUSTOM_BAR_PAGES.bar10,
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar11",
        label = "Bar 11",
        actionPage = CUSTOM_BAR_PAGES.bar11,
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar12",
        label = "Bar 12",
        actionPage = CUSTOM_BAR_PAGES.bar12,
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar13",
        label = "Bar 13",
        actionPage = CUSTOM_BAR_PAGES.bar13,
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar14",
        label = "Bar 14",
        actionPage = CUSTOM_BAR_PAGES.bar14,
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "bar15",
        label = "Bar 15",
        actionPage = CUSTOM_BAR_PAGES.bar15,
        maxButtons = 12,
        fallbackButtonsPerRow = 12,
        fallbackButtonSize = 32,
    },
    {
        key = "extraAction",
        label = "Extra Action",
        buttonName = "ExtraActionButton1",
        maxButtons = 1,
        fallbackButtonsPerRow = 1,
        fallbackButtonSize = 52,
    },
    {
        key = "vehicleExit",
        label = "Vehicle Exit",
        buttonName = "MainMenuBarVehicleLeaveButton",
        maxButtons = 1,
        fallbackButtonsPerRow = 1,
        fallbackButtonSize = 32,
    },
    {
        key = "pet",
        label = "Pet Bar",
        prefix = "PetActionButton",
        maxButtons = NUM_PET_ACTION_SLOTS,
        fallbackButtonsPerRow = NUM_PET_ACTION_SLOTS,
        fallbackButtonSize = 30,
    },
    {
        key = "stance",
        label = "Stance Bar",
        prefix = "StanceButton",
        maxButtons = NUM_STANCE_SLOTS,
        fallbackButtonsPerRow = NUM_STANCE_SLOTS,
        fallbackButtonSize = 30,
    },
}

ActionBars.BAR_DEFINITIONS = BAR_DEFINITIONS

local function ClampNumber(value, minValue, maxValue, fallback)
    value = tonumber(value)
    if not value then
        return fallback
    end

    if value < minValue then
        return minValue
    end

    if value > maxValue then
        return maxValue
    end

    return value
end

local function SafeDebugString(value)
    if value == nil then
        return "nil"
    end

    local ok, result = pcall(tostring, value)
    if ok and type(result) == "string" then
        return result
    end

    return "<value>"
end

local function FormatFramePoint(frame)
    if not frame or type(frame.GetPoint) ~= "function" then
        return "point=nil"
    end

    local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(1)
    return string.format("%s <- %s.%s (%.0f, %.0f)",
        SafeDebugString(point),
        relativeTo and relativeTo.GetName and relativeTo:GetName() or "nil",
        SafeDebugString(relativePoint),
        tonumber(xOffset) or 0,
        tonumber(yOffset) or 0)
end

local function IsDebugEnabled()
    return DebugConsole and DebugConsole.IsSourceEnabled and DebugConsole:IsSourceEnabled(DEBUG_SOURCE_KEY) == true
end

local function LogDebug(message, shouldShow)
    if not DebugConsole or type(DebugConsole.Log) ~= "function" or not IsDebugEnabled() then
        return false
    end

    return DebugConsole:Log(DEBUG_SOURCE_KEY, SafeDebugString(message), shouldShow)
end

local function LogDebugf(shouldShow, messageFormat, ...)
    if not DebugConsole or type(DebugConsole.Logf) ~= "function" or not IsDebugEnabled() then
        return false
    end

    return DebugConsole:Logf(DEBUG_SOURCE_KEY, shouldShow, messageFormat, ...)
end

local function CapturePoints(frame)
    local points = {}
    local pointCount = frame and frame.GetNumPoints and frame:GetNumPoints() or 0
    for index = 1, pointCount do
        local point, relativeTo, relativePoint, xOffset, yOffset = frame:GetPoint(index)
        points[index] = {
            point = point,
            relativeTo = relativeTo,
            relativePoint = relativePoint,
            x = xOffset,
            y = yOffset,
        }
    end

    return points
end

local function RestorePoints(frame, points)
    if not frame then
        return
    end

    frame:ClearAllPoints()
    if type(points) ~= "table" or #points == 0 then
        return
    end

    for _, point in ipairs(points) do
        frame:SetPoint(point.point, point.relativeTo, point.relativePoint, point.x, point.y)
    end
end

local function CaptureFont(fontString)
    if not fontString or type(fontString.GetFont) ~= "function" then
        return nil
    end

    local fontPath, size, flags = fontString:GetFont()
    local shadowX, shadowY = 0, 0
    if type(fontString.GetShadowOffset) == "function" then
        shadowX, shadowY = fontString:GetShadowOffset()
    end

    local shadowR, shadowG, shadowB, shadowA = 0, 0, 0, 0
    if type(fontString.GetShadowColor) == "function" then
        shadowR, shadowG, shadowB, shadowA = fontString:GetShadowColor()
    end

    return {
        fontPath = fontPath,
        size = size,
        flags = flags,
        shadowX = shadowX,
        shadowY = shadowY,
        shadowR = shadowR,
        shadowG = shadowG,
        shadowB = shadowB,
        shadowA = shadowA,
        shown = fontString.IsShown and fontString:IsShown() or true,
    }
end

local function RestoreFont(fontString, fontState)
    if not fontString or type(fontState) ~= "table" then
        return
    end

    if fontState.fontPath and fontState.size and fontString.SetFont then
        fontString:SetFont(fontState.fontPath, fontState.size, fontState.flags or "")
    end

    if fontString.SetShadowOffset then
        fontString:SetShadowOffset(fontState.shadowX or 0, fontState.shadowY or 0)
    end
    if fontString.SetShadowColor then
        fontString:SetShadowColor(fontState.shadowR or 0, fontState.shadowG or 0, fontState.shadowB or 0, fontState.shadowA or 0)
    end

    if fontState.shown == true then
        fontString:Show()
    elseif fontState.shown == false then
        fontString:Hide()
    end
end

local function CaptureTexture(texture)
    if not texture then
        return nil
    end

    local left, right, top, bottom = 0, 1, 0, 1
    if texture.GetTexCoord then
        left, right, top, bottom = texture:GetTexCoord()
    end

    return {
        alpha = texture.GetAlpha and texture:GetAlpha() or 1,
        shown = texture.IsShown and texture:IsShown() or true,
        texture = texture.GetTexture and texture:GetTexture() or nil,
        blendMode = texture.GetBlendMode and texture:GetBlendMode() or nil,
        texCoord = { left, right, top, bottom },
    }
end

local function CaptureRegionState(region)
    if not region then
        return nil
    end

    local objectType = region.GetObjectType and region:GetObjectType() or nil
    local state = {
        alpha = region.GetAlpha and region:GetAlpha() or 1,
        shown = region.IsShown and region:IsShown() or true,
        objectType = objectType,
    }

    if objectType == "Texture" and region.GetTexture then
        state.texture = region:GetTexture()
    elseif objectType == "FontString" and region.GetText then
        state.text = region:GetText()
    end

    return state
end

local function RestoreTexture(texture, state)
    if not texture or type(state) ~= "table" then
        return
    end

    if texture.SetTexture and state.texture ~= nil then
        texture:SetTexture(state.texture)
    end
    if texture.SetTexCoord and state.texCoord then
        texture:SetTexCoord(unpackValues(state.texCoord))
    end
    if texture.SetBlendMode and state.blendMode ~= nil then
        texture:SetBlendMode(state.blendMode)
    end
    if texture.SetAlpha and state.alpha ~= nil then
        texture:SetAlpha(state.alpha)
    end

    if state.shown == true and texture.Show then
        texture:Show()
    elseif state.shown == false and texture.Hide then
        texture:Hide()
    end
end

local function RestoreRegionState(region, state)
    if not region or type(state) ~= "table" then
        return
    end

    if region.SetAlpha and state.alpha ~= nil then
        region:SetAlpha(state.alpha)
    end

    if state.objectType == "Texture" and region.SetTexture and state.texture ~= nil then
        region:SetTexture(state.texture)
    elseif state.objectType == "FontString" and region.SetText and state.text ~= nil then
        region:SetText(state.text or "")
    end

    if state.shown == true and region.Show then
        region:Show()
    elseif state.shown == false and region.Hide then
        region:Hide()
    end
end

local function SuppressRegion(region)
    if not region then
        return
    end

    local objectType = region.GetObjectType and region:GetObjectType() or nil
    if objectType == "Texture" and region.SetTexture then
        region:SetTexture(nil)
    elseif objectType == "FontString" and region.SetText then
        region:SetText("")
    end

    if region.SetAlpha then
        region:SetAlpha(0)
    end
    if region.Hide then
        region:Hide()
    end
end

local function SuppressFrameRegions(frame)
    if not frame then
        return
    end

    local regions = { frame:GetRegions() }
    for _, region in ipairs(regions) do
        SuppressRegion(region)
    end
end

local function GetButtonArtTextures(button)
    if not button then
        return {}
    end

    local buttonName = button.GetName and button:GetName() or nil
    local textures = {
        normal = button.GetNormalTexture and button:GetNormalTexture() or nil,
        pushed = button.GetPushedTexture and button:GetPushedTexture() or nil,
        highlight = button.GetHighlightTexture and button:GetHighlightTexture() or nil,
        checked = button.GetCheckedTexture and button:GetCheckedTexture() or nil,
        border = button.Border or (buttonName and _G[buttonName .. "Border"]) or nil,
        floatingBG = button.FloatingBG or (buttonName and _G[buttonName .. "FloatingBG"]) or nil,
        flash = button.Flash or (buttonName and _G[buttonName .. "Flash"]) or nil,
        newAction = button.NewActionTexture or (buttonName and _G[buttonName .. "NewActionTexture"]) or nil,
        spellHighlight = button.SpellHighlightTexture or (buttonName and _G[buttonName .. "SpellHighlightTexture"]) or nil,
        flyoutBorder = button.FlyoutBorder or (buttonName and _G[buttonName .. "FlyoutBorder"]) or nil,
        flyoutShadow = button.FlyoutBorderShadow or (buttonName and _G[buttonName .. "FlyoutBorderShadow"]) or nil,
    }

    return textures
end

local function CaptureButtonArtTextures(button)
    local captured = {}
    for key, texture in pairs(GetButtonArtTextures(button)) do
        captured[key] = CaptureTexture(texture)
    end
    return captured
end

local function RestoreButtonArtTextures(button, states)
    if type(states) ~= "table" then
        return
    end

    local textures = GetButtonArtTextures(button)
    for key, state in pairs(states) do
        RestoreTexture(textures[key], state)
    end
end

local function SuppressButtonArtTextures(button)
    for _, texture in pairs(GetButtonArtTextures(button)) do
        if texture then
            if texture.SetAlpha then
                texture:SetAlpha(0)
            end
            if texture.Hide then
                texture:Hide()
            end
        end
    end
end

local function SuppressButtonBorder(button)
    if not button then
        return
    end

    local buttonName = button.GetName and button:GetName() or nil
    local border = button.Border or (buttonName and _G[buttonName .. "Border"]) or nil
    if not border then
        return
    end

    if border.SetAlpha then
        border:SetAlpha(0)
    end
    if border.Hide then
        border:Hide()
    end
end

local function SuppressButtonAnimationEffects(button)
    if not button then
        return
    end

    local buttonName = button.GetName and button:GetName() or nil
    local flash = button.Flash or (buttonName and _G[buttonName .. "Flash"]) or nil
    local spellHighlight = button.SpellHighlightTexture or (buttonName and _G[buttonName .. "SpellHighlightTexture"]) or nil
    local pushed = button.GetPushedTexture and button:GetPushedTexture() or nil
    local checked = button.GetCheckedTexture and button:GetCheckedTexture() or nil

    if flash then
        if flash.SetTexture then
            flash:SetTexture(nil)
        end
        if flash.SetAlpha then
            flash:SetAlpha(0)
        end
        if flash.Hide then
            flash:Hide()
        end
    end

    if spellHighlight then
        if spellHighlight.SetTexture then
            spellHighlight:SetTexture(nil)
        end
        if spellHighlight.SetAlpha then
            spellHighlight:SetAlpha(0)
        end
        if spellHighlight.Hide then
            spellHighlight:Hide()
        end
    end

    if pushed then
        if pushed.SetAlpha then
            pushed:SetAlpha(0)
        end
        if pushed.Hide then
            pushed:Hide()
        end
    end

    if checked then
        if checked.SetAlpha then
            checked:SetAlpha(0)
        end
        if checked.Hide then
            checked:Hide()
        end
    end
end

local function CaptureAnimationGroupState(animationGroup)
    if not animationGroup then
        return nil
    end

    return {
        playing = animationGroup.IsPlaying and animationGroup:IsPlaying() or false,
    }
end

local function StopAnimationGroup(animationGroup)
    if animationGroup and animationGroup.Stop then
        animationGroup:Stop()
    end
end

local function CaptureSpellCastAnimState(button)
    local spellCastAnim = button and button.SpellCastAnimFrame or nil
    if not spellCastAnim then
        return nil
    end

    local fill = spellCastAnim.Fill
    local endBurst = spellCastAnim.EndBurst
    local finishCastAnim = endBurst and endBurst.FinishCastAnim or nil
    local castingAnim = fill and fill.CastingAnim or nil

    return {
        shown = spellCastAnim.IsShown and spellCastAnim:IsShown() or false,
        alpha = spellCastAnim.GetAlpha and spellCastAnim:GetAlpha() or 1,
        onShow = spellCastAnim.GetScript and spellCastAnim:GetScript("OnShow") or nil,
        fillShown = fill and fill.IsShown and fill:IsShown() or false,
        fillAlpha = fill and fill.GetAlpha and fill:GetAlpha() or 1,
        endBurstShown = endBurst and endBurst.IsShown and endBurst:IsShown() or false,
        endBurstAlpha = endBurst and endBurst.GetAlpha and endBurst:GetAlpha() or 1,
        castingAnim = CaptureAnimationGroupState(castingAnim),
        finishCastAnim = CaptureAnimationGroupState(finishCastAnim),
    }
end

local function RestoreSpellCastAnimState(button, state)
    if not button or type(state) ~= "table" then
        return
    end

    local spellCastAnim = button.SpellCastAnimFrame
    if not spellCastAnim then
        return
    end

    local fill = spellCastAnim.Fill
    local endBurst = spellCastAnim.EndBurst
    local finishCastAnim = endBurst and endBurst.FinishCastAnim or nil
    local castingAnim = fill and fill.CastingAnim or nil

    if spellCastAnim.SetScript then
        spellCastAnim:SetScript("OnShow", state.onShow)
    end
    if spellCastAnim.SetAlpha and state.alpha ~= nil then
        spellCastAnim:SetAlpha(state.alpha)
    end
    if state.shown == true and spellCastAnim.Show then
        spellCastAnim:Show()
    elseif state.shown == false and spellCastAnim.Hide then
        spellCastAnim:Hide()
    end

    if fill then
        if fill.SetAlpha and state.fillAlpha ~= nil then
            fill:SetAlpha(state.fillAlpha)
        end
        if state.fillShown == true and fill.Show then
            fill:Show()
        elseif state.fillShown == false and fill.Hide then
            fill:Hide()
        end
    end

    if endBurst then
        if endBurst.SetAlpha and state.endBurstAlpha ~= nil then
            endBurst:SetAlpha(state.endBurstAlpha)
        end
        if state.endBurstShown == true and endBurst.Show then
            endBurst:Show()
        elseif state.endBurstShown == false and endBurst.Hide then
            endBurst:Hide()
        end
    end

    if castingAnim and state.castingAnim and state.castingAnim.playing == true and castingAnim.Play then
        castingAnim:Play()
    end
    if finishCastAnim and state.finishCastAnim and state.finishCastAnim.playing == true and finishCastAnim.Play then
        finishCastAnim:Play()
    end
end

local function SuppressSpellCastAnim(button)
    local spellCastAnim = button and button.SpellCastAnimFrame or nil
    if not spellCastAnim then
        return
    end

    local fill = spellCastAnim.Fill
    local endBurst = spellCastAnim.EndBurst
    local finishCastAnim = endBurst and endBurst.FinishCastAnim or nil
    local castingAnim = fill and fill.CastingAnim or nil

    StopAnimationGroup(castingAnim)
    StopAnimationGroup(finishCastAnim)

    if spellCastAnim.SetScript then
        spellCastAnim:SetScript("OnShow", spellCastAnim.Hide)
    end
    if fill then
        if fill.SetAlpha then
            fill:SetAlpha(0)
        end
        if fill.Hide then
            fill:Hide()
        end
    end
    if endBurst then
        if endBurst.SetAlpha then
            endBurst:SetAlpha(0)
        end
        if endBurst.Hide then
            endBurst:Hide()
        end
    end
    if spellCastAnim.SetAlpha then
        spellCastAnim:SetAlpha(0)
    end
    if spellCastAnim.Hide then
        spellCastAnim:Hide()
    end
end

local function FetchThemeColor(theme, key, fallback)
    local color = theme and theme.Get and theme:Get(key) or nil
    if type(color) == "table" then
        return color[1] or fallback[1], color[2] or fallback[2], color[3] or fallback[3]
    end
    return fallback[1], fallback[2], fallback[3]
end

local function ResolveConfiguredColor(color, fallback)
    if type(color) == "table" then
        return color[1] or fallback[1], color[2] or fallback[2], color[3] or fallback[3]
    end

    return fallback[1], fallback[2], fallback[3]
end

local function RefreshBlizzardLayout()
    if type(UIParent_ManageFramePositions) == "function" then
        pcall(UIParent_ManageFramePositions)
    end

    if type(UpdateMicroButtons) == "function" then
        pcall(UpdateMicroButtons)
    end

    local statusTrackingBarManager = _G.StatusTrackingBarManager
    if statusTrackingBarManager then
        if type(statusTrackingBarManager.UpdateBarsShown) == "function" then
            pcall(statusTrackingBarManager.UpdateBarsShown, statusTrackingBarManager)
        end
        if type(statusTrackingBarManager.Update) == "function" then
            pcall(statusTrackingBarManager.Update, statusTrackingBarManager)
        end
    end
end

function ActionBars:GetOptions()
    return ConfigurationModule and ConfigurationModule.Options and ConfigurationModule.Options.ActionBars
end

function ActionBars:GetDB()
    local options = self:GetOptions()
    return options and options.GetDB and options:GetDB() or nil
end

function ActionBars:GetBarSettings(barKey)
    local options = self:GetOptions()
    return options and options.GetBarSettings and options:GetBarSettings(barKey) or nil
end

function ActionBars:OnInitialize()
    self.holders = {}
    self.movers = {}
    self.barButtons = {}
    self.customButtons = {}
    self.activeAlertSpells = {}
    self.originalButtons = {}
    self.originalFrames = {}
    self.originalRegions = {}
    self.hoverTokens = {}
    self.masqueGroups = {}
    self.masqueButtons = {}
    self.pendingRefresh = false
    self.pendingDisable = false
    self.keybindModeActive = false
    self.bindingsChanged = false

    self:CreateInfrastructure()

    self.blizzardHiddenRoot = CreateFrame("Frame", nil, UIParent)
    self.blizzardHiddenRoot:Hide()

    if DebugConsole and DebugConsole.RegisterSource then
        DebugConsole:RegisterSource(DEBUG_SOURCE_KEY, {
            title = "Action Bars",
            order = 24,
            aliases = { "actionbars", "bars", "ab" },
            maxLines = 200,
            isEnabled = function()
                local options = ActionBars:GetOptions()
                return options and options.GetDebugEnabled and options:GetDebugEnabled() or false
            end,
            buildReport = function()
                return ActionBars:BuildDebugReport()
            end,
        })
    end
end

function ActionBars:OnEnable()
    LogDebug("action bars enabled", false)
    self:RegisterEvent("PLAYER_ENTERING_WORLD", "RequestRefresh")
    self:RegisterEvent("SPELLS_CHANGED", "RefreshButtonStates")
    self:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED", "RefreshButtonStates")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORMS", "RequestRefresh")
    self:RegisterEvent("PET_BAR_UPDATE", "RequestRefresh")
    self:RegisterEvent("PET_BAR_UPDATE_USABLE", "RequestRefresh")
    self:RegisterEvent("UPDATE_EXTRA_ACTIONBAR", "RequestRefresh")
    self:RegisterEvent("UPDATE_VEHICLE_ACTIONBAR", "RequestRefresh")
    self:RegisterEvent("UNIT_ENTERED_VEHICLE", "RequestRefresh")
    self:RegisterEvent("UNIT_EXITED_VEHICLE", "RequestRefresh")
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
    self:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")
    self:RegisterEvent("UPDATE_BINDINGS", "RefreshButtonStates")
    self:RegisterEvent("ACTIONBAR_PAGE_CHANGED", "RefreshButtonStates")
    self:RegisterEvent("ACTIONBAR_SLOT_CHANGED", "RefreshButtonStates")
    self:RegisterEvent("ACTIONBAR_UPDATE_STATE", "RefreshButtonStates")
    self:RegisterEvent("ACTIONBAR_UPDATE_USABLE", "RefreshButtonStates")
    self:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN", "ApplyCooldownSettings")
    self:RegisterEvent("PLAYER_REGEN_ENABLED")
    self:RegisterMessage("TWICH_THEME_CHANGED", "OnThemeChanged")

    self:RequestRefresh()
end

function ActionBars:OnDisable()
    if self.keybindModeActive == true then
        self:DeactivateBindMode(false)
    end

    if InCombatLockdown() then
        self.pendingDisable = true
        LogDebug("disable deferred until leaving combat", false)
        return
    end

    self.pendingDisable = false
    self.pendingRefresh = false
    self:ClearMasqueGroups()
    self:RestoreOriginalLayout()
    self:UpdateMovers()
    RefreshBlizzardLayout()
    LogDebug("action bars disabled and original layout restored", false)
end

function ActionBars:PLAYER_REGEN_ENABLED()
    if self.pendingDisable == true then
        LogDebug("regen enabled processing deferred disable", false)
        self.pendingDisable = false
        local db = self:GetDB()
        if db and db.enabled == false and self:IsEnabled() then
            self:Disable()
        else
            self:OnDisable()
        end
        return
    end

    if self.pendingRefresh == true then
        LogDebug("regen enabled processing deferred refresh", false)
        self.pendingRefresh = false
        self:RefreshAll()
    end
end

function ActionBars:OnThemeChanged()
    self:RequestRefresh()
end

function ActionBars:RefreshModuleState()
    local db = self:GetDB()
    if not db then
        return
    end

    if db.enabled == false then
        if InCombatLockdown() then
            self.pendingDisable = true
            LogDebug("refresh module state requested disable in combat; deferring", false)
            return
        end

        if self:IsEnabled() then
            self:Disable()
        else
            self:RestoreOriginalLayout()
            self:UpdateMovers()
        end
        return
    end

    self.pendingDisable = false

    if not self:IsEnabled() then
        LogDebug("refresh module state enabling action bars module", false)
        self:Enable()
        return
    end

    self:RequestRefresh()
end

function ActionBars:SetLockState(locked)
    local db = self:GetDB()
    if not db then
        return
    end

    db.lockBars = locked == true
    if locked and self._moverInspector then
        self._moverInspector:Hide()
    end
    self:RequestRefresh()
end

function ActionBars:RequestRefresh()
    local db = self:GetDB()
    if not db or db.enabled == false then
        return
    end

    if InCombatLockdown() then
        self.pendingRefresh = true
        LogDebug("refresh requested in combat; deferring", false)
        return
    end

    self.pendingRefresh = false
    LogDebug("refresh requested", false)
    self:RefreshAll()
end

function ActionBars:BuildDebugReport()
    local lines = {
        "TwichUI Action Bars Debug Report",
        "",
    }

    local db = self:GetDB() or {}
    lines[#lines + 1] = string.format("enabled=%s lockBars=%s useMasque=%s showGrid=%s spacing=%s",
        tostring(db.enabled ~= false),
        tostring(db.lockBars == true),
        tostring(db.useMasque == true),
        tostring(db.showGrid == true),
        SafeDebugString(db.buttonSpacing))
    lines[#lines + 1] = string.format("moduleEnabled=%s inCombat=%s pendingRefresh=%s pendingDisable=%s",
        tostring(self.IsEnabled and self:IsEnabled() or false),
        tostring(InCombatLockdown and InCombatLockdown() or false),
        tostring(self.pendingRefresh == true),
        tostring(self.pendingDisable == true))
    lines[#lines + 1] = ""
    lines[#lines + 1] = "Blizzard Frames"

    for _, frameName in ipairs(BLIZZARD_FRAMES_TO_HIDE) do
        local frame = _G[frameName]
        if frame then
            local parent = frame.GetParent and frame:GetParent() or nil
            lines[#lines + 1] = string.format("%s shown=%s alpha=%.2f parent=%s hiddenRoot=%s point=%s",
                frameName,
                tostring(frame.IsShown and frame:IsShown() or false),
                tonumber(frame.GetAlpha and frame:GetAlpha() or 0) or 0,
                parent and parent.GetName and parent:GetName() or "nil",
                tostring(parent == self.blizzardHiddenRoot),
                FormatFramePoint(frame))
        else
            lines[#lines + 1] = string.format("%s missing", frameName)
        end
    end

    lines[#lines + 1] = ""
    lines[#lines + 1] = "Holders"
    for _, definition in ipairs(BAR_DEFINITIONS) do
        local holder = self.holders[definition.key]
        local barDB = self:GetBarSettings(definition.key) or {}
        local buttonCount = self.barButtons[definition.key] and #self.barButtons[definition.key] or 0
        lines[#lines + 1] = string.format("%s shown=%s size=%.0fx%.0f scale=%.2f alpha=%.2f enabled=%s buttons=%d",
            definition.key,
            tostring(holder and holder:IsShown() or false),
            holder and holder:GetWidth() or 0,
            holder and holder:GetHeight() or 0,
            holder and holder:GetScale() or 0,
            holder and holder:GetAlpha() or 0,
            tostring(barDB.enabled == true),
            buttonCount)
    end

    return table.concat(lines, "\n")
end

function ActionBars:PersistBarLayout(barKey, absX, absY)
    local settings = self:GetBarSettings(barKey)
    if not settings then
        return
    end

    settings.point = "BOTTOMLEFT"
    settings.relativePoint = "BOTTOMLEFT"
    settings.x = floor((absX or 0) + 0.5)
    settings.y = floor((absY or 0) + 0.5)
end

function ActionBars:GetMoverInspector()
    if self._moverInspector then
        return self._moverInspector
    end

    local function ResolveAddonFont(size)
        local path = STANDARD_TEXT_FONT
        local theme = T:GetModule("Theme", true)
        if LSM and theme then
            local name = theme.Get and theme:Get("globalFont")
            if name and name ~= "" and name ~= "__default" then
                local ok, fetched = pcall(LSM.Fetch, LSM, "font", name)
                if ok and type(fetched) == "string" and fetched ~= "" then
                    path = fetched
                end
            end
        end
        return path, size or 11
    end

    local panel = CreateFrame("Frame", "TwichUIActionBarMoverInspector", UIParent, "BackdropTemplate")
    panel:SetFrameStrata("TOOLTIP")
    panel:SetFrameLevel(9998)
    panel:SetSize(220, 118)
    panel:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    panel:SetBackdropColor(0.06, 0.07, 0.10, 0.97)
    panel:SetBackdropBorderColor(0.10, 0.72, 0.74, 1.0)
    panel:EnableMouse(true)
    panel:Hide()

    local function CancelHide()
        if panel._hideTimer then
            panel._hideTimer:Cancel()
            panel._hideTimer = nil
        end
    end

    local function ScheduleHide()
        CancelHide()
        panel._hideTimer = C_Timer.NewTimer(0.15, function()
            panel._hideTimer = nil
            if (panel.xBox and panel.xBox:HasFocus()) or (panel.yBox and panel.yBox:HasFocus()) then
                return
            end
            panel:Hide()
        end)
    end

    panel.CancelHide = CancelHide
    panel.ScheduleHide = ScheduleHide
    panel:SetScript("OnEnter", CancelHide)
    panel:SetScript("OnLeave", ScheduleHide)

    local function ApplyFont(widget, size)
        local path, resolvedSize = ResolveAddonFont(size)
        widget:SetFont(path, resolvedSize, "")
    end

    local title = panel:CreateFontString(nil, "OVERLAY")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 8, -8)
    title:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    title:SetJustifyH("LEFT")
    ApplyFont(title, 11)
    title:SetTextColor(0.10, 0.72, 0.74, 1)
    panel.title = title

    local shiftHint = panel:CreateFontString(nil, "OVERLAY")
    shiftHint:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -8)
    shiftHint:SetJustifyH("RIGHT")
    ApplyFont(shiftHint, 8)
    shiftHint:SetText("Shift = 10 px")
    shiftHint:SetTextColor(0.40, 0.40, 0.52)

    local div1 = panel:CreateTexture(nil, "ARTWORK")
    div1:SetHeight(1)
    div1:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -22)
    div1:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -22)
    div1:SetColorTexture(0.10, 0.72, 0.74, 0.35)

    local function MakeLabel(text, xOffset, yOffset)
        local label = panel:CreateFontString(nil, "OVERLAY")
        label:SetPoint("TOPLEFT", panel, "TOPLEFT", xOffset, yOffset)
        ApplyFont(label, 10)
        label:SetText(text)
        label:SetTextColor(0.55, 0.58, 0.68)
        return label
    end

    local function MakeEditBox(xOffset, yOffset, width)
        local editBox = CreateFrame("EditBox", nil, panel, "BackdropTemplate")
        editBox:SetSize(width, 20)
        editBox:SetPoint("TOPLEFT", panel, "TOPLEFT", xOffset, yOffset)
        editBox:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        editBox:SetBackdropColor(0.04, 0.05, 0.08, 1)
        editBox:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)
        editBox:SetTextInsets(5, 5, 2, 2)
        editBox:SetMaxLetters(7)
        editBox:SetAutoFocus(false)
        ApplyFont(editBox, 10)
        editBox:SetTextColor(1, 1, 1)
        editBox:SetJustifyH("RIGHT")
        editBox:EnableMouse(true)
        editBox:SetScript("OnEnter", CancelHide)
        editBox:SetScript("OnLeave", ScheduleHide)
        editBox:SetScript("OnEditFocusGained", CancelHide)
        return editBox
    end

    MakeLabel("X", 8, -35)
    MakeLabel("Y", 116, -35)
    panel.xBox = MakeEditBox(19, -30, 86)
    panel.yBox = MakeEditBox(127, -30, 82)

    local div2 = panel:CreateTexture(nil, "ARTWORK")
    div2:SetHeight(1)
    div2:SetPoint("TOPLEFT", panel, "TOPLEFT", 1, -55)
    div2:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -1, -55)
    div2:SetColorTexture(0.14, 0.16, 0.22, 1)

    local function RepositionPanel(mover)
        panel:ClearAllPoints()
        local moverTop = mover:GetTop() or 0
        local screenHeight = UIParent:GetHeight() or 768
        if moverTop > screenHeight * 0.55 then
            panel:SetPoint("TOP", mover, "BOTTOM", 0, -6)
        else
            panel:SetPoint("BOTTOM", mover, "TOP", 0, 6)
        end
    end

    local function ApplyPosition(x, y)
        local active = panel._active
        if not active or InCombatLockdown() then
            return
        end

        local mover = active.mover
        local barKey = mover and mover.barKey or nil
        local holder = barKey and ActionBars.holders[barKey] or nil
        local newX = floor((tonumber(x) or 0) + 0.5)
        local newY = floor((tonumber(y) or 0) + 0.5)
        if not mover or not barKey or not holder then
            return
        end

        ActionBars:PersistBarLayout(barKey, newX, newY)

        holder:ClearAllPoints()
        holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newX, newY)
        mover:ClearAllPoints()
        mover:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", newX, newY)

        panel.xBox:SetText(tostring(newX))
        panel.yBox:SetText(tostring(newY))
        panel.xBox:SetCursorPosition(0)
        panel.yBox:SetCursorPosition(0)
        RepositionPanel(mover)
    end

    local function RefreshBoxes()
        local active = panel._active
        if not active then
            return
        end

        local mover = active.mover
        panel.xBox:SetText(tostring(floor((mover:GetLeft() or 0) + 0.5)))
        panel.yBox:SetText(tostring(floor((mover:GetBottom() or 0) + 0.5)))
        panel.xBox:SetCursorPosition(0)
        panel.yBox:SetCursorPosition(0)
    end

    panel.RefreshBoxes = RefreshBoxes

    panel.xBox:SetScript("OnEnterPressed", function(editBox)
        local y = tonumber(panel.yBox:GetText()) or 0
        ApplyPosition(editBox:GetText(), y)
        editBox:ClearFocus()
    end)
    panel.xBox:SetScript("OnEscapePressed", function(editBox)
        RefreshBoxes()
        editBox:ClearFocus()
    end)
    panel.yBox:SetScript("OnEnterPressed", function(editBox)
        local x = tonumber(panel.xBox:GetText()) or 0
        ApplyPosition(x, editBox:GetText())
        editBox:ClearFocus()
    end)
    panel.yBox:SetScript("OnEscapePressed", function(editBox)
        RefreshBoxes()
        editBox:ClearFocus()
    end)

    local buttonSize = 20
    local gap = 3
    local centerX = 110

    local function MakeNudgeButton(label, dx, dy)
        local button = CreateFrame("Button", nil, panel, "BackdropTemplate")
        button:SetSize(buttonSize, buttonSize)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        button:SetBackdropColor(0.09, 0.11, 0.15, 1)
        button:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)

        local fontString = button:CreateFontString(nil, "OVERLAY")
        fontString:SetAllPoints(button)
        fontString:SetJustifyH("CENTER")
        fontString:SetJustifyV("MIDDLE")
        ApplyFont(fontString, 11)
        fontString:SetText(label)

        button:SetScript("OnEnter", function()
            button:SetBackdropColor(0.10, 0.72, 0.74, 0.22)
            button:SetBackdropBorderColor(0.10, 0.72, 0.74, 1)
            CancelHide()
        end)
        button:SetScript("OnLeave", function()
            button:SetBackdropColor(0.09, 0.11, 0.15, 1)
            button:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)
            ScheduleHide()
        end)
        button:SetScript("OnClick", function()
            if not panel._active or InCombatLockdown() then
                return
            end

            local step = IsShiftKeyDown() and 10 or 1
            local curX = tonumber(panel.xBox:GetText()) or 0
            local curY = tonumber(panel.yBox:GetText()) or 0
            ApplyPosition(curX + (dx * step), curY + (dy * step))
        end)

        return button
    end

    local row1Y = -63
    local row2Y = row1Y - buttonSize - gap
    local row3Y = row2Y - buttonSize - gap

    local buttonUp = MakeNudgeButton("^", 0, 1)
    local buttonLeft = MakeNudgeButton("<", -1, 0)
    local buttonRight = MakeNudgeButton(">", 1, 0)
    local buttonDown = MakeNudgeButton("v", 0, -1)

    buttonUp:SetPoint("TOPLEFT", panel, "TOPLEFT", centerX - (buttonSize / 2), row1Y)
    buttonLeft:SetPoint("TOPLEFT", panel, "TOPLEFT", centerX - (buttonSize / 2) - buttonSize - gap, row2Y)
    buttonRight:SetPoint("TOPLEFT", panel, "TOPLEFT", centerX - (buttonSize / 2) + buttonSize + gap, row2Y)
    buttonDown:SetPoint("TOPLEFT", panel, "TOPLEFT", centerX - (buttonSize / 2), row3Y)

    local center = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    center:SetSize(buttonSize, buttonSize)
    center:SetPoint("TOPLEFT", panel, "TOPLEFT", centerX - (buttonSize / 2), row2Y)
    center:EnableMouse(false)
    center:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    center:SetBackdropColor(0.05, 0.06, 0.09, 0.7)
    center:SetBackdropBorderColor(0.15, 0.17, 0.22, 0.6)

    local centerFont = center:CreateFontString(nil, "OVERLAY")
    centerFont:SetAllPoints(center)
    centerFont:SetJustifyH("CENTER")
    centerFont:SetJustifyV("MIDDLE")
    ApplyFont(centerFont, 8)
    centerFont:SetText("XY")
    centerFont:SetTextColor(0.38, 0.40, 0.50)

    self._moverInspector = panel
    return panel
end

function ActionBars:CreateInfrastructure()
    for _, definition in ipairs(BAR_DEFINITIONS) do
        local barKey = definition.key
        local barLabel = definition.label
        local holder = CreateFrame("Frame", "TwichUIActionBarHolder_" .. definition.key, UIParent,
            "SecureHandlerStateTemplate,BackdropTemplate")
        holder:SetClampedToScreen(true)
        holder:SetFrameStrata("MEDIUM")
        holder:SetFrameLevel(30)
        holder:EnableMouse(true)
        holder.barKey = barKey

        local mover = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        mover:SetFrameStrata("TOOLTIP")
        mover:SetFrameLevel(200)
        mover:SetMovable(true)
        mover:EnableMouse(true)
        mover:RegisterForDrag("LeftButton")
        mover.barKey = barKey

        mover.label = mover:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        mover.label:SetPoint("CENTER", mover, "CENTER", 0, 0)
        mover.label:SetText(barLabel)
        mover.holder = holder

        mover:SetScript("OnDragStart", function(frame)
            if InCombatLockdown() then
                return
            end

            frame:StartMoving()
            frame.isMoving = true
        end)

        mover:SetScript("OnDragStop", function(frame)
            if not frame.isMoving then
                return
            end

            frame:StopMovingOrSizing()
            frame.isMoving = false

            local x = frame:GetLeft() or 0
            local y = frame:GetBottom() or 0
            local inspector = ActionBars:GetMoverInspector()

            ActionBars:PersistBarLayout(frame.barKey, x, y)

            if frame.holder then
                frame.holder:ClearAllPoints()
                frame.holder:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
            end

            if inspector and inspector:IsShown() and inspector._active and inspector._active.mover == frame then
                inspector:ClearAllPoints()
                if (frame:GetTop() or 0) > ((UIParent:GetHeight() or 768) * 0.55) then
                    inspector:SetPoint("TOP", frame, "BOTTOM", 0, -6)
                else
                    inspector:SetPoint("BOTTOM", frame, "TOP", 0, 6)
                end
                inspector:RefreshBoxes()
            end

            self:RefreshAll()
        end)

        mover:SetScript("OnEnter", function(selfMover)
            local inspector = ActionBars:GetMoverInspector()
            inspector.CancelHide()
            inspector._active = { mover = selfMover }
            inspector.title:SetText(barLabel)
            inspector.RefreshBoxes()
            inspector:ClearAllPoints()
            if (selfMover:GetTop() or 0) > ((UIParent:GetHeight() or 768) * 0.55) then
                inspector:SetPoint("TOP", selfMover, "BOTTOM", 0, -6)
            else
                inspector:SetPoint("BOTTOM", selfMover, "TOP", 0, 6)
            end
            inspector:Show()
        end)
        mover:SetScript("OnLeave", function()
            ActionBars:GetMoverInspector().ScheduleHide()
        end)

        self.holders[barKey] = holder
        self.movers[barKey] = mover
    end
end

function ActionBars:GetButtonIcon(button)
    return button and (button.icon or button.Icon or _G[button:GetName() .. "Icon"]) or nil
end

function ActionBars:GetButtonCooldown(button)
    return button and (button.cooldown or button.Cooldown or _G[button:GetName() .. "Cooldown"]) or nil
end

function ActionBars:GetButtonHotKey(button)
    return button and (button.HotKey or _G[button:GetName() .. "HotKey"]) or nil
end

function ActionBars:GetButtonCount(button)
    return button and (button.Count or _G[button:GetName() .. "Count"]) or nil
end

function ActionBars:GetButtonMacroName(button)
    return button and (button.Name or _G[button:GetName() .. "Name"]) or nil
end

function ActionBars:GetButtonBindingTarget(button)
    if not button then
        return nil
    end

    if button.keyBoundTarget then
        return button.keyBoundTarget
    end

    local buttonName = button.GetName and button:GetName() or nil
    if not buttonName then
        return nil
    end

    if buttonName == "ExtraActionButton1" then
        return "EXTRAACTIONBUTTON1"
    end

    if button.commandName then
        return button.commandName
    end

    local action = tonumber(button.action or (button.GetAttribute and button:GetAttribute("action")) or nil)
    if action then
        local modAction = 1 + ((action - 1) % 12)
        if find(buttonName, "^TwichUIActionBar_") then
            return format("CLICK %s:LeftButton", buttonName)
        elseif action < 25 or action > 72 then
            return "ACTIONBUTTON" .. modAction
        elseif action > 60 then
            return "MULTIACTIONBAR1BUTTON" .. modAction
        elseif action > 48 then
            return "MULTIACTIONBAR2BUTTON" .. modAction
        elseif action > 36 then
            return "MULTIACTIONBAR4BUTTON" .. modAction
        elseif action > 24 then
            return "MULTIACTIONBAR3BUTTON" .. modAction
        end
    end

    return format("CLICK %s:LeftButton", buttonName)
end

function ActionBars:GetButtonBindings(button)
    local target = self:GetButtonBindingTarget(button)
    if not target then
        return {}
    end

    return { GetBindingKey(target) }
end

function ActionBars:GetButtonBindingLabel(button)
    local bindings = self:GetButtonBindings(button)
    local binding = bindings[1]
    if not binding or binding == "" then
        return ""
    end

    return GetBindingText and GetBindingText(binding, "KEY_", true) or binding
end

function ActionBars:SetBindingForTarget(chord, target)
    local targetType, firstArg, secondArg = SplitBindingTarget(target)
    if targetType == "click" and SetBindingClick then
        SetBindingClick(chord, firstArg, secondArg or "LeftButton")
        return
    end

    SetBinding(chord, firstArg)
end

function ActionBars:GetButtonDisplayName(button)
    if not button then
        return "Action"
    end

    local action = tonumber(button.action or (button.GetAttribute and button:GetAttribute("action")) or nil)
    if action and GetActionInfo then
        local actionType, actionID = GetActionInfo(action)
        if actionType == "spell" and actionID and _G.C_Spell and _G.C_Spell.GetSpellName then
            local spellName = _G.C_Spell.GetSpellName(actionID)
            if type(spellName) == "string" and spellName ~= "" then
                return spellName
            end
        elseif actionType == "macro" and actionID and _G.GetMacroInfo then
            local macroName = _G.GetMacroInfo(actionID)
            if type(macroName) == "string" and macroName ~= "" then
                return macroName
            end
        end
    end

    return button:GetName() or "Action"
end

function ActionBars:UpdateButtonBindingText(button)
    local hotKey = self:GetButtonHotKey(button)
    if not hotKey then
        return
    end

    hotKey:SetText(self:GetButtonBindingLabel(button))
end

function ActionBars:ShowBindOverlay(button)
    local overlay = self:GetKeybindOverlay()
    if not overlay or not button then
        return
    end

    overlay.button = button
    overlay:ClearAllPoints()
    overlay:SetAllPoints(button)
    overlay.label:SetText(self:GetButtonDisplayName(button))

    local bindings = self:GetButtonBindings(button)
    if #bindings == 0 then
        overlay.bindingText:SetText("Unbound")
    else
        local display = {}
        for _, binding in ipairs(bindings) do
            display[#display + 1] = GetBindingText and GetBindingText(binding, "KEY_", true) or binding
        end
        overlay.bindingText:SetText(table.concat(display, "\n"))
    end

    overlay:Show()
end

function ActionBars:HideBindOverlay()
    if self.bindOverlay then
        self.bindOverlay.button = nil
        self.bindOverlay:Hide()
    end
end

function ActionBars:ScheduleGlowSync(delaySeconds)
    local token = (self.glowSyncToken or 0) + 1
    self.glowSyncToken = token

    C_Timer.After(delaySeconds or 0.1, function()
        if ActionBars.glowSyncToken ~= token then
            return
        end

        local db = ActionBars:GetDB()
        if not db or db.enabled == false or not ActionBars:IsEnabled() then
            return
        end

        ActionBars:UpdateAllButtonGlows()
    end)
end

function ActionBars:ClearButtonGlow(button)
    if not button then
        return
    end

    self:HidePixelGlow(button)
    self:HideProcGlow(button)
    self:HideNativeOverlayGlow(button)
end

function ActionBars:ClearAllButtonGlows()
    for _, buttons in pairs(self.barButtons) do
        for _, button in ipairs(buttons) do
            self:ClearButtonGlow(button)
        end
    end
end

function ActionBars:RefreshGlowState()
    local token = (self.glowSyncToken or 0) + 1
    self.glowSyncToken = token

    local db = self:GetDB()
    if not db or db.enabled == false or not self:IsEnabled() then
        return
    end

    self:ClearAllButtonGlows()
    self:UpdateAllButtonGlows()

    C_Timer.After(0.05, function()
        if ActionBars.glowSyncToken ~= token then
            return
        end

        local refreshDB = ActionBars:GetDB()
        if not refreshDB or refreshDB.enabled == false or not ActionBars:IsEnabled() then
            return
        end

        ActionBars:ClearAllButtonGlows()
        ActionBars:UpdateAllButtonGlows()
    end)
end

function ActionBars:BindUpdate(button)
    if not self.keybindModeActive or InCombatLockdown() or not button then
        return
    end

    self:ShowBindOverlay(button)
end

function ActionBars:BindListener(key)
    local overlay = self.bindOverlay
    local button = overlay and overlay.button or nil
    local target = button and self:GetButtonBindingTarget(button) or nil
    if not button or not target then
        return
    end

    self.bindingsChanged = true

    if key == "ESCAPE" then
        for _, binding in ipairs(self:GetButtonBindings(button)) do
            SetBinding(binding)
        end

        T:Print(format("[TwichUI] Cleared bindings for %s.", self:GetButtonDisplayName(button)))
        self:BindUpdate(button)
        self:RefreshButtonStates()
        return
    end

    if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL" or key == "LALT" or key == "RALT"
        or key == "UNKNOWN" then
        return
    end

    if key == "MiddleButton" then
        key = "BUTTON3"
    elseif find(key, "Button%d") then
        key = upper(key)
    end

    local alt = IsAltKeyDown() and "ALT-" or ""
    local ctrl = IsControlKeyDown() and "CTRL-" or ""
    local shift = IsShiftKeyDown() and "SHIFT-" or ""
    local meta = IsMetaKeyDown and IsMetaKeyDown() and "META-" or ""
    local chord = alt .. ctrl .. shift .. meta .. key

    self:SetBindingForTarget(chord, target)
    T:Print(format("[TwichUI] %s bound to %s.", chord, self:GetButtonDisplayName(button)))
    self:BindUpdate(button)
    self:RefreshButtonStates()
end

function ActionBars:GetKeybindOverlay()
    if self.bindOverlay then
        return self.bindOverlay
    end

    local overlay = CreateFrame("Button", "TwichUIActionBarKeybindOverlay", UIParent, "BackdropTemplate")
    overlay:SetFrameStrata("DIALOG")
    overlay:SetFrameLevel(400)
    overlay:EnableMouse(true)
    overlay:EnableKeyboard(true)
    overlay:EnableMouseWheel(true)
    overlay:RegisterForClicks("AnyUp", "AnyDown")
    overlay:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    overlay:SetBackdropColor(0, 0, 0, 0.78)
    overlay:SetBackdropBorderColor(0.10, 0.72, 0.74, 0.95)
    overlay:Hide()

    overlay.label = overlay:CreateFontString(nil, "OVERLAY")
    overlay.label:SetPoint("TOP", overlay, "TOP", 0, -5)
    overlay.label:SetPoint("LEFT", overlay, "LEFT", 4, 0)
    overlay.label:SetPoint("RIGHT", overlay, "RIGHT", -4, 0)
    overlay.label:SetJustifyH("CENTER")
    overlay.label:SetJustifyV("TOP")
    overlay.label:SetFont(STANDARD_TEXT_FONT, 10, "")
    overlay.label:SetTextColor(1, 0.95, 0.85, 1)

    overlay.bindingText = overlay:CreateFontString(nil, "OVERLAY")
    overlay.bindingText:SetPoint("TOPLEFT", overlay.label, "BOTTOMLEFT", 0, -4)
    overlay.bindingText:SetPoint("BOTTOMRIGHT", overlay, "BOTTOMRIGHT", -4, 4)
    overlay.bindingText:SetJustifyH("CENTER")
    overlay.bindingText:SetJustifyV("MIDDLE")
    overlay.bindingText:SetFont(STANDARD_TEXT_FONT, 11, "OUTLINE")
    overlay.bindingText:SetTextColor(0.92, 0.94, 0.96, 1)

    overlay:SetScript("OnKeyUp", function(_, key)
        ActionBars:BindListener(key)
    end)
    overlay:SetScript("OnMouseUp", function(_, key)
        ActionBars:BindListener(key)
    end)
    overlay:SetScript("OnMouseDown", function()
    end)
    overlay:SetScript("OnMouseWheel", function(_, delta)
        ActionBars:BindListener(delta > 0 and "MOUSEWHEELUP" or "MOUSEWHEELDOWN")
    end)
    overlay:SetScript("OnHide", function(selfFrame)
        selfFrame.button = nil
    end)

    self.bindOverlay = overlay
    return overlay
end

function ActionBars:GetBindPopup()
    if self.bindPopup then
        return self.bindPopup
    end

    local popup = CreateFrame("Frame", "TwichUIActionBarBindPopup", UIParent, "BackdropTemplate")
    popup:SetFrameStrata("DIALOG")
    popup:SetFrameLevel(401)
    popup:SetMovable(true)
    popup:SetClampedToScreen(true)
    popup:EnableMouse(true)
    popup:RegisterForDrag("LeftButton")
    popup:SetScript("OnDragStart", popup.StartMoving)
    popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
    popup:SetSize(360, 142)
    popup:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
    popup:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
    })
    popup:SetBackdropColor(0.05, 0.06, 0.08, 0.97)
    popup:SetBackdropBorderColor(0.10, 0.72, 0.74, 0.95)
    popup:Hide()

    popup.title = popup:CreateFontString(nil, "OVERLAY")
    popup.title:SetPoint("TOPLEFT", popup, "TOPLEFT", 12, -10)
    popup.title:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -12, -10)
    popup.title:SetJustifyH("LEFT")
    popup.title:SetFont(STANDARD_TEXT_FONT, 12, "")
    popup.title:SetTextColor(1, 0.95, 0.85, 1)
    popup.title:SetText("Quick Bind Mode")

    popup.desc = popup:CreateFontString(nil, "OVERLAY")
    popup.desc:SetPoint("TOPLEFT", popup.title, "BOTTOMLEFT", 0, -10)
    popup.desc:SetPoint("TOPRIGHT", popup, "TOPRIGHT", -12, 0)
    popup.desc:SetJustifyH("LEFT")
    popup.desc:SetJustifyV("TOP")
    popup.desc:SetFont(STANDARD_TEXT_FONT, 10, "")
    popup.desc:SetTextColor(0.82, 0.84, 0.90, 1)
    popup.desc:SetText("Hover any action and press a key or mouse combo to bind it. Press Escape on an action to clear its bindings.")

    local function CreatePopupButton(text, point, relativeTo, relativePoint, xOffset)
        local button = CreateFrame("Button", nil, popup, "BackdropTemplate")
        button:SetSize(150, 24)
        button:SetPoint(point, relativeTo, relativePoint, xOffset, 12)
        button:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8X8",
            edgeFile = "Interface\\Buttons\\WHITE8X8",
            edgeSize = 1,
        })
        button:SetBackdropColor(0.09, 0.11, 0.15, 1)
        button:SetBackdropBorderColor(0.20, 0.22, 0.30, 1)
        button.text = button:CreateFontString(nil, "OVERLAY")
        button.text:SetAllPoints(button)
        button.text:SetFont(STANDARD_TEXT_FONT, 10, "")
        button.text:SetTextColor(0.92, 0.94, 0.96, 1)
        button.text:SetText(text)
        return button
    end

    popup.save = CreatePopupButton("Save", "BOTTOMRIGHT", popup, "BOTTOM", -8)
    popup.discard = CreatePopupButton("Discard", "BOTTOMLEFT", popup, "BOTTOM", 8)
    popup.save:SetScript("OnClick", function()
        ActionBars:DeactivateBindMode(true)
    end)
    popup.discard:SetScript("OnClick", function()
        ActionBars:DeactivateBindMode(false)
    end)

    self.bindPopup = popup
    return popup
end

function ActionBars:ActivateBindMode()
    if InCombatLockdown() then
        T:Print("[TwichUI] Cannot enable quick bind mode in combat.")
        return
    end

    self.keybindModeActive = true
    self.bindingsChanged = false
    self:GetBindPopup():Show()
    self:GetKeybindOverlay():Hide()
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnBindModeCombatLockdown")
end

function ActionBars:DeactivateBindMode(save)
    if save then
        SaveBindings(GetCurrentBindingSet())
        T:Print("[TwichUI] Action Bar bindings saved.")
    else
        LoadBindings(GetCurrentBindingSet())
        T:Print("[TwichUI] Action Bar binding changes discarded.")
    end

    self.keybindModeActive = false
    self.bindingsChanged = false
    self:HideBindOverlay()
    if self.bindPopup then
        self.bindPopup:Hide()
    end
    self:UnregisterEvent("PLAYER_REGEN_DISABLED")
    self:RefreshButtonStates()
end

function ActionBars:OnBindModeCombatLockdown()
    self:DeactivateBindMode(false)
end

function ActionBars:GetButtonSpellID(button)
    if not button then
        return nil
    end

    local directSpellID = button.spellID or button.spellId or (button.GetSpellId and button:GetSpellId()) or nil
    if directSpellID then
        return directSpellID
    end

    local action = tonumber(button.action or (button.GetAttribute and button:GetAttribute("action")) or nil)
    if not action or not GetActionInfo then
        return nil
    end

    local actionType, actionID = GetActionInfo(action)
    if actionType == "spell" then
        return actionID
    end

    return nil
end

function ActionBars:IsButtonGlowActive(button)
    local spellID = self:GetButtonSpellID(button)
    if not spellID then
        return false
    end

    return (IsSpellOverlayed and IsSpellOverlayed(spellID) == true) or self.activeAlertSpells[spellID] == true
end

function ActionBars:GetGlowStyle()
    local db = self:GetDB()
    local style = db and db.procGlowStyle or "pixel"
    if style == "pixel" or style == "proc" or style == "button" or style == "blizzard" or style == "none" then
        return style
    end

    return "pixel"
end

function ActionBars:GetGlowColor()
    local fallback = { 0.96, 0.76, 0.24 }
    local db = self:GetDB()
    if db and db.procGlowUseThemeColor ~= false then
        local theme = T:GetModule("Theme", true)
        return FetchThemeColor(theme, "accentColor", fallback)
    end

    return ResolveConfiguredColor(db and db.procGlowColor or nil, fallback)
end

function ActionBars:GetPixelGlowFrame(button)
    if not button then
        return nil
    end

    if button.__twichuiABPixelGlow then
        return button.__twichuiABPixelGlow
    end

    local glow = CreateFrame("Frame", nil, button)
    glow:SetFrameLevel(button:GetFrameLevel() + 8)
    glow:SetAlpha(0)
    glow:Hide()

    glow.top = glow:CreateTexture(nil, "OVERLAY")
    glow.bottom = glow:CreateTexture(nil, "OVERLAY")
    glow.left = glow:CreateTexture(nil, "OVERLAY")
    glow.right = glow:CreateTexture(nil, "OVERLAY")

    glow.anim = glow:CreateAnimationGroup()
    glow.anim:SetLooping("BOUNCE")
    local fadeOut = glow.anim:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetDuration(0.55)
    fadeOut:SetFromAlpha(PIXEL_GLOW_ALPHA)
    fadeOut:SetToAlpha(0.28)
    local fadeIn = glow.anim:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetDuration(0.55)
    fadeIn:SetFromAlpha(0.28)
    fadeIn:SetToAlpha(PIXEL_GLOW_ALPHA)

    button.__twichuiABPixelGlow = glow
    return glow
end

function ActionBars:GetProcGlowFrame(button)
    if not button then
        return nil
    end

    if button.__twichuiABProcGlow then
        return button.__twichuiABProcGlow
    end

    local glow = CreateFrame("Frame", nil, button)
    glow:SetFrameLevel(button:GetFrameLevel() + 7)
    glow:SetAlpha(0)
    glow:Hide()

    glow.outer = glow:CreateTexture(nil, "ARTWORK")
    glow.outer:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    glow.outer:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    glow.outer:SetBlendMode("ADD")

    glow.outerOver = glow:CreateTexture(nil, "ARTWORK")
    glow.outerOver:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    glow.outerOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
    glow.outerOver:SetBlendMode("ADD")

    glow.inner = glow:CreateTexture(nil, "OVERLAY")
    glow.inner:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    glow.inner:SetTexCoord(0.00781250, 0.50781250, 0.27734375, 0.52734375)
    glow.inner:SetBlendMode("ADD")

    glow.innerOver = glow:CreateTexture(nil, "OVERLAY")
    glow.innerOver:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    glow.innerOver:SetTexCoord(0.00781250, 0.50781250, 0.53515625, 0.78515625)
    glow.innerOver:SetBlendMode("ADD")

    glow.spark = glow:CreateTexture(nil, "OVERLAY")
    glow.spark:SetTexture([[Interface\SpellActivationOverlay\IconAlert]])
    glow.spark:SetTexCoord(0.00781250, 0.61718750, 0.00390625, 0.26953125)
    glow.spark:SetBlendMode("ADD")

    glow.anim = glow:CreateAnimationGroup()
    glow.anim:SetLooping("BOUNCE")
    local fadeOut = glow.anim:CreateAnimation("Alpha")
    fadeOut:SetOrder(1)
    fadeOut:SetDuration(0.75)
    fadeOut:SetFromAlpha(0.82)
    fadeOut:SetToAlpha(0.34)
    local fadeIn = glow.anim:CreateAnimation("Alpha")
    fadeIn:SetOrder(2)
    fadeIn:SetDuration(0.75)
    fadeIn:SetFromAlpha(0.34)
    fadeIn:SetToAlpha(0.82)

    glow.scaleAnim = glow:CreateAnimationGroup()
    glow.scaleAnim:SetLooping("BOUNCE")
    local scaleOut = glow.scaleAnim:CreateAnimation("Scale")
    scaleOut:SetOrder(1)
    scaleOut:SetDuration(0.75)
    scaleOut:SetScale(1.04, 1.04)
    local scaleIn = glow.scaleAnim:CreateAnimation("Scale")
    scaleIn:SetOrder(2)
    scaleIn:SetDuration(0.75)
    scaleIn:SetScale(1 / 1.04, 1 / 1.04)

    button.__twichuiABProcGlow = glow
    return glow
end

function ActionBars:UpdatePixelGlowLayout(button)
    local glow = self:GetPixelGlowFrame(button)
    local icon = self:GetButtonIcon(button)
    local target = icon or button
    local targetParent = target:GetParent() or button
    if not glow or not target then
        return
    end

    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", target, "TOPLEFT", -1, 1)
    glow:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 1, -1)

    local red, green, blue = self:GetGlowColor()

    glow.top:ClearAllPoints()
    glow.top:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)
    glow.top:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
    glow.top:SetHeight(1)
    glow.top:SetColorTexture(red, green, blue, 1)

    glow.bottom:ClearAllPoints()
    glow.bottom:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
    glow.bottom:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
    glow.bottom:SetHeight(1)
    glow.bottom:SetColorTexture(red, green, blue, 1)

    glow.left:ClearAllPoints()
    glow.left:SetPoint("TOPLEFT", glow, "TOPLEFT", 0, 0)
    glow.left:SetPoint("BOTTOMLEFT", glow, "BOTTOMLEFT", 0, 0)
    glow.left:SetWidth(1)
    glow.left:SetColorTexture(red, green, blue, 1)

    glow.right:ClearAllPoints()
    glow.right:SetPoint("TOPRIGHT", glow, "TOPRIGHT", 0, 0)
    glow.right:SetPoint("BOTTOMRIGHT", glow, "BOTTOMRIGHT", 0, 0)
    glow.right:SetWidth(1)
    glow.right:SetColorTexture(red, green, blue, 1)

    glow:SetParent(targetParent)
end

function ActionBars:UpdateProcGlowLayout(button)
    local glow = self:GetProcGlowFrame(button)
    local icon = self:GetButtonIcon(button)
    local target = icon or button
    local targetParent = target:GetParent() or button
    if not glow or not target then
        return
    end

    glow:ClearAllPoints()
    glow:SetPoint("TOPLEFT", target, "TOPLEFT", -7, 7)
    glow:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 7, -7)

    local red, green, blue = self:GetGlowColor()

    glow.outer:ClearAllPoints()
    glow.outer:SetPoint("CENTER", glow, "CENTER", 0, 0)
    glow.outer:SetAllPoints(glow)
    glow.outer:SetVertexColor(red, green, blue, 0.30)
    glow.outer:SetDesaturated(true)

    glow.outerOver:ClearAllPoints()
    glow.outerOver:SetPoint("TOPLEFT", glow.outer, "TOPLEFT")
    glow.outerOver:SetPoint("BOTTOMRIGHT", glow.outer, "BOTTOMRIGHT")
    glow.outerOver:SetVertexColor(red, green, blue, 0.16)
    glow.outerOver:SetDesaturated(true)

    glow.inner:ClearAllPoints()
    glow.inner:SetPoint("TOPLEFT", target, "TOPLEFT", -3, 3)
    glow.inner:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 3, -3)
    glow.inner:SetVertexColor(red, green, blue, 0.48)
    glow.inner:SetDesaturated(true)

    glow.innerOver:ClearAllPoints()
    glow.innerOver:SetPoint("TOPLEFT", glow.inner, "TOPLEFT")
    glow.innerOver:SetPoint("BOTTOMRIGHT", glow.inner, "BOTTOMRIGHT")
    glow.innerOver:SetVertexColor(red, green, blue, 0.20)
    glow.innerOver:SetDesaturated(true)

    glow.spark:ClearAllPoints()
    glow.spark:SetPoint("CENTER", target, "CENTER", 0, 0)
    glow.spark:SetSize(target:GetWidth() * 1.35, target:GetHeight() * 1.35)
    glow.spark:SetVertexColor(red, green, blue, 0.18)
    glow.spark:SetDesaturated(true)

    glow:SetParent(targetParent)
end

function ActionBars:ShowPixelGlow(button)
    local glow = self:GetPixelGlowFrame(button)
    if not glow then
        return
    end

    self:UpdatePixelGlowLayout(button)
    glow:SetAlpha(PIXEL_GLOW_ALPHA)
    glow:Show()
    if glow.anim and not glow.anim:IsPlaying() then
        glow.anim:Play()
    end
end

function ActionBars:HidePixelGlow(button)
    local glow = button and button.__twichuiABPixelGlow or nil
    if not glow then
        return
    end

    if glow.anim and glow.anim:IsPlaying() then
        glow.anim:Stop()
    end
    glow:SetAlpha(0)
    glow:Hide()
end

function ActionBars:ShowProcGlow(button)
    local glow = self:GetProcGlowFrame(button)
    if not glow then
        return
    end

    self:UpdateProcGlowLayout(button)
    glow:SetAlpha(0.82)
    glow:Show()
    if glow.anim and not glow.anim:IsPlaying() then
        glow.anim:Play()
    end
    if glow.scaleAnim and not glow.scaleAnim:IsPlaying() then
        glow.scaleAnim:Play()
    end
end

function ActionBars:HideProcGlow(button)
    local glow = button and button.__twichuiABProcGlow or nil
    if not glow then
        return
    end

    if glow.anim and glow.anim:IsPlaying() then
        glow.anim:Stop()
    end
    if glow.scaleAnim and glow.scaleAnim:IsPlaying() then
        glow.scaleAnim:Stop()
    end
    glow:SetAlpha(0)
    glow:Hide()
end

function ActionBars:TintOverlayGlow(button, red, green, blue)
    local overlay = button and (button.__LBGoverlay or button.overlay or button.SpellActivationAlert or nil) or nil
    if not overlay then
        return
    end

    for _, texture in ipairs({ overlay.spark, overlay.innerGlow, overlay.innerGlowOver, overlay.outerGlow, overlay.outerGlowOver, overlay.ants }) do
        if texture and texture.SetVertexColor then
            if texture.SetDesaturated then
                texture:SetDesaturated(1)
            end
            texture:SetVertexColor(red, green, blue, 1)
        end
    end
end

function ActionBars:ShowActionButtonGlow(button)
    if not button then
        return
    end

    if LBG and LBG.ShowOverlayGlow then
        LBG.ShowOverlayGlow(button)
        local red, green, blue = self:GetGlowColor()
        self:TintOverlayGlow(button, red, green, blue)
        return
    end

    if ActionButton_ShowOverlayGlow then
        pcall(ActionButton_ShowOverlayGlow, button)
    end
end

function ActionBars:HideNativeOverlayGlow(button)
    if not button then
        return
    end

    if ActionButton_HideOverlayGlow then
        pcall(ActionButton_HideOverlayGlow, button)
    end

    local buttonName = button.GetName and button:GetName() or nil
    local lbgOverlay = button.__LBGoverlay or nil
    if lbgOverlay and LBG and LBG.HideOverlayGlow then
        pcall(LBG.HideOverlayGlow, button)
        if lbgOverlay.animOut and lbgOverlay.animOut.IsPlaying and lbgOverlay.animOut:IsPlaying() and lbgOverlay.animOut.Finish then
            lbgOverlay.animOut:Finish()
        end
    end

    local overlay = button.overlay or button.SpellActivationAlert or
        (buttonName and _G[buttonName .. "SpellActivationAlert"]) or nil

    if overlay == lbgOverlay then
        overlay = nil
    end

    if overlay then
        if overlay.animIn and overlay.animIn.IsPlaying and overlay.animIn:IsPlaying() then
            overlay.animIn:Stop()
        end
        if overlay.animOut and overlay.animOut.IsPlaying and overlay.animOut:IsPlaying() then
            overlay.animOut:Stop()
        end
        if overlay.Hide then
            overlay:Hide()
        end
    end
end

function ActionBars:UpdateButtonGlow(button)
    if not button then
        return
    end

    local style = self:GetGlowStyle()
    local active = self:IsButtonGlowActive(button)

    self:ClearButtonGlow(button)

    if style == "pixel" then
        if active then
            self:ShowPixelGlow(button)
        end
    elseif style == "proc" then
        if active then
            self:ShowProcGlow(button)
        end
    elseif style == "button" then
        if active then
            self:ShowActionButtonGlow(button)
        end
    elseif style == "blizzard" then
        if ActionButton_ShowOverlayGlow and ActionButton_HideOverlayGlow then
            pcall(active and ActionButton_ShowOverlayGlow or ActionButton_HideOverlayGlow, button)
        end
    end
end

function ActionBars:UpdateAllButtonGlows()
    for _, buttons in pairs(self.barButtons) do
        for _, button in ipairs(buttons) do
            self:UpdateButtonGlow(button)
        end
    end
end

function ActionBars:SPELL_ACTIVATION_OVERLAY_GLOW_SHOW(_, spellID)
    if spellID then
        self.activeAlertSpells[spellID] = true
    end
    self:UpdateAllButtonGlows()
end

function ActionBars:SPELL_ACTIVATION_OVERLAY_GLOW_HIDE(_, spellID)
    if spellID then
        self.activeAlertSpells[spellID] = nil
    end
    self:UpdateAllButtonGlows()
end

function ActionBars:CreateCustomActionButton(definition, index)
    if not definition or not definition.key or not definition.actionPage or not self.blizzardHiddenRoot then
        return nil
    end

    local buttonName = string.format("TwichUIActionBar_%s_Button%d", definition.key, index)
    local button = _G[buttonName]
    local actionID = ((definition.actionPage - 1) * 12) + index

    if not button then
        button = CreateFrame("CheckButton", buttonName, self.blizzardHiddenRoot,
            "ActionButtonTemplate,SecureActionButtonTemplate")
    end

    button:SetParent(self.blizzardHiddenRoot)
    button:SetAttribute("type", "action")
    button:SetAttribute("action", actionID)
    button.action = actionID
    button:SetID(actionID)
    button:Hide()

    self:CaptureButtonState(button)
    return button
end

function ActionBars:CaptureButtonState(button)
    if not button or self.originalButtons[button] then
        return
    end

    local icon = self:GetButtonIcon(button)
    local left, right, top, bottom = 0, 1, 0, 1
    if icon and icon.GetTexCoord then
        left, right, top, bottom = icon:GetTexCoord()
    end

    self.originalButtons[button] = {
        parent = button:GetParent(),
        points = CapturePoints(button),
        width = button:GetWidth(),
        height = button:GetHeight(),
        scale = button:GetScale(),
        alpha = button:GetAlpha(),
        shown = button:IsShown(),
        frameStrata = button:GetFrameStrata(),
        frameLevel = button:GetFrameLevel(),
        iconTexCoords = { left, right, top, bottom },
        hotKey = CaptureFont(self:GetButtonHotKey(button)),
        count = CaptureFont(self:GetButtonCount(button)),
        name = CaptureFont(self:GetButtonMacroName(button)),
        cooldownPoints = CapturePoints(self:GetButtonCooldown(button)),
        spellCastAnim = CaptureSpellCastAnimState(button),
        artTextures = CaptureButtonArtTextures(button),
    }
end

function ActionBars:CaptureFrameState(frame)
    if not frame or self.originalFrames[frame] then
        return
    end

    local frameName = frame.GetName and frame:GetName() or nil
    local managedFramePositions = _G.UIPARENT_MANAGED_FRAME_POSITIONS

    self.originalFrames[frame] = {
        name = frameName,
        parent = frame.GetParent and frame:GetParent() or nil,
        points = CapturePoints(frame),
        alpha = frame.GetAlpha and frame:GetAlpha() or 1,
        shown = frame.IsShown and frame:IsShown() or true,
        ignoreInLayout = frame.ignoreInLayout,
        managedPosition = managedFramePositions and frameName and managedFramePositions[frameName] or nil,
    }
end

function ActionBars:CaptureRegionState(region)
    if not region or self.originalRegions[region] then
        return
    end

    self.originalRegions[region] = CaptureRegionState(region)
end

function ActionBars:RestoreOriginalLayout()
    for _, holder in pairs(self.holders) do
        if holder then
            pcall(UnregisterStateDriver, holder, "visibility")
            holder:SetAlpha(1)
            holder:Hide()
        end
    end

    for _, mover in pairs(self.movers) do
        if mover then
            mover:Hide()
        end
    end

    for button, state in pairs(self.originalButtons) do
        if button and state then
            if state.parent then
                button:SetParent(state.parent)
            end
            RestorePoints(button, state.points)

            if state.width and state.height then
                button:SetSize(state.width, state.height)
            end
            if state.scale then
                button:SetScale(state.scale)
            end
            if state.alpha then
                button:SetAlpha(state.alpha)
            end
            if state.frameStrata then
                button:SetFrameStrata(state.frameStrata)
            end
            if state.frameLevel then
                button:SetFrameLevel(state.frameLevel)
            end

            local icon = self:GetButtonIcon(button)
            if icon and state.iconTexCoords then
                icon:SetTexCoord(unpackValues(state.iconTexCoords))
            end

            RestoreFont(self:GetButtonHotKey(button), state.hotKey)
            RestoreFont(self:GetButtonCount(button), state.count)
            RestoreFont(self:GetButtonMacroName(button), state.name)
            RestoreButtonArtTextures(button, state.artTextures)
            RestoreSpellCastAnimState(button, state.spellCastAnim)
            ActionBars:HideButtonHoverEffect(button)
            ActionBars:HidePixelGlow(button)
            ActionBars:HideProcGlow(button)
            ActionBars:HideNativeOverlayGlow(button)

            if state.shown == true then
                button:Show()
            else
                button:Hide()
            end

            if button.__twichuiABChrome then
                button.__twichuiABChrome:Hide()
            end

            local cooldown = self:GetButtonCooldown(button)
            if cooldown then
                RestorePoints(cooldown, state.cooldownPoints)
                if cooldown.SetHideCountdownNumbers then
                    cooldown:SetHideCountdownNumbers(false)
                end
                if cooldown.SetDrawSwipe then
                    cooldown:SetDrawSwipe(true)
                end
                if cooldown.SetDrawEdge then
                    cooldown:SetDrawEdge(true)
                end
                if cooldown.SetDrawBling then
                    cooldown:SetDrawBling(false)
                end
            end
        end
    end

    for frame, state in pairs(self.originalFrames) do
        if frame and state then
            if state.parent then
                frame:SetParent(state.parent)
            end
            if frame.ignoreInLayout ~= nil then
                frame.ignoreInLayout = state.ignoreInLayout
            end
            if _G.UIPARENT_MANAGED_FRAME_POSITIONS and state.name then
                _G.UIPARENT_MANAGED_FRAME_POSITIONS[state.name] = state.managedPosition
            end
            RestorePoints(frame, state.points)
            frame:SetAlpha(state.alpha or 1)
            if state.shown == true then
                frame:Show()
            else
                frame:Hide()
            end

            LogDebugf(false, "restore frame=%s shown=%s parent=%s",
                SafeDebugString(frame.GetName and frame:GetName() or frame),
                tostring(state.shown == true),
                state.parent and state.parent.GetName and state.parent:GetName() or "nil")
        end
    end

    for region, state in pairs(self.originalRegions) do
        if region and state then
            RestoreRegionState(region, state)
        end
    end

    RefreshBlizzardLayout()
end

function ActionBars:GetButtonsForDefinition(definition)
    local buttons = {}
    if definition.actionPage then
        self.customButtons[definition.key] = self.customButtons[definition.key] or {}

        for index = 1, definition.maxButtons do
            local button = self.customButtons[definition.key][index] or self:CreateCustomActionButton(definition, index)
            if button then
                self.customButtons[definition.key][index] = button
                buttons[#buttons + 1] = button
            end
        end
    elseif definition.buttonName then
        local button = _G[definition.buttonName]
        if button then
            self:CaptureButtonState(button)
            buttons[#buttons + 1] = button
        end
    else
        for index = 1, definition.maxButtons do
            local button = _G[definition.prefix .. index]
            if button then
                self:CaptureButtonState(button)
                buttons[#buttons + 1] = button
            end
        end
    end

    self.barButtons[definition.key] = buttons
    return buttons
end

function ActionBars:GetButtonCountForDefinition(definition, buttons)
    local barSettings = self:GetBarSettings(definition.key) or {}
    local requestedCount = ClampNumber(barSettings.buttonCount, 1, #buttons, #buttons)

    if definition.key == "stance" then
        local count = type(GetNumShapeshiftForms) == "function" and GetNumShapeshiftForms() or 0
        if count and count > 0 then
            return min(count, requestedCount)
        end
        return requestedCount
    end

    return requestedCount
end

function ActionBars:GetResolvedTextColor(actionBarDB)
    local theme = T:GetModule("Theme", true)
    local fallback = theme and theme.Get and theme:Get("textColor") or { 0.92, 0.94, 0.96 }
    return ResolveConfiguredColor(actionBarDB and actionBarDB.textColor, fallback)
end

function ActionBars:ResolveFont(fontName)
    local theme = T:GetModule("Theme", true)
    local resolved = fontName

    if type(resolved) ~= "string" or resolved == "" or resolved == "__default" then
        resolved = theme and theme.Get and theme:Get("globalFont") or nil
    end

    if type(resolved) == "string" and resolved ~= "" and resolved ~= "__default" and LSM then
        return LSM:Fetch("font", resolved, true) or STANDARD_TEXT_FONT
    end

    return STANDARD_TEXT_FONT
end

function ActionBars:ApplyTextShadow(fontString, enabled)
    if not fontString then
        return
    end

    if fontString.SetShadowOffset then
        if enabled == true then
            fontString:SetShadowOffset(1, -1)
        else
            fontString:SetShadowOffset(0, 0)
        end
    end

    if fontString.SetShadowColor then
        if enabled == true then
            fontString:SetShadowColor(0, 0, 0, 0.9)
        else
            fontString:SetShadowColor(0, 0, 0, 0)
        end
    end
end

function ActionBars:GetButtonHoverFrame(button)
    if not button then
        return nil
    end

    if button.__twichuiABHoverEffect then
        return button.__twichuiABHoverEffect
    end

    local hover = CreateFrame("Frame", nil, button)
    hover:SetAlpha(0)
    hover:Hide()
    hover:EnableMouse(false)

    hover.ring = hover:CreateTexture(nil, "OVERLAY")
    hover.ring:SetTexture([[Interface\Buttons\CheckButtonHilight]])
    hover.ring:SetBlendMode("ADD")

    hover.glaze = hover:CreateTexture(nil, "OVERLAY")
    hover.glaze:SetTexture([[Interface\Buttons\UI-Listbox-Highlight2]])
    hover.glaze:SetBlendMode("ADD")

    hover.top = hover:CreateTexture(nil, "OVERLAY")
    hover.bottom = hover:CreateTexture(nil, "OVERLAY")
    hover.left = hover:CreateTexture(nil, "OVERLAY")
    hover.right = hover:CreateTexture(nil, "OVERLAY")

    hover.pulse = hover:CreateAnimationGroup()
    hover.pulse:SetLooping("BOUNCE")

    local glazeFadeOut = hover.pulse:CreateAnimation("Alpha")
    glazeFadeOut:SetTarget(hover.glaze)
    glazeFadeOut:SetOrder(1)
    glazeFadeOut:SetDuration(0.38)
    glazeFadeOut:SetFromAlpha(0.22)
    glazeFadeOut:SetToAlpha(0.08)

    local glazeFadeIn = hover.pulse:CreateAnimation("Alpha")
    glazeFadeIn:SetTarget(hover.glaze)
    glazeFadeIn:SetOrder(2)
    glazeFadeIn:SetDuration(0.52)
    glazeFadeIn:SetFromAlpha(0.08)
    glazeFadeIn:SetToAlpha(0.22)

    local ringFadeOut = hover.pulse:CreateAnimation("Alpha")
    ringFadeOut:SetTarget(hover.ring)
    ringFadeOut:SetOrder(1)
    ringFadeOut:SetDuration(0.38)
    ringFadeOut:SetFromAlpha(0.28)
    ringFadeOut:SetToAlpha(0.12)

    local ringFadeIn = hover.pulse:CreateAnimation("Alpha")
    ringFadeIn:SetTarget(hover.ring)
    ringFadeIn:SetOrder(2)
    ringFadeIn:SetDuration(0.52)
    ringFadeIn:SetFromAlpha(0.12)
    ringFadeIn:SetToAlpha(0.28)

    button.__twichuiABHoverEffect = hover
    return hover
end

function ActionBars:UpdateButtonHoverEffect(button, actionBarDB, barSettings)
    local hover = self:GetButtonHoverFrame(button)
    if not hover then
        return
    end

    local useMasque = actionBarDB and actionBarDB.useMasque == true and Masque ~= nil
    local theme = T:GetModule("Theme", true)
    local primaryR, primaryG, primaryB = FetchThemeColor(theme, "primaryColor", { 0.10, 0.72, 0.74 })
    local accentR, accentG, accentB = FetchThemeColor(theme, "accentColor", { 0.96, 0.76, 0.24 })
    local hoverR = (barSettings and barSettings.showAccent == false) and primaryR or accentR
    local hoverG = (barSettings and barSettings.showAccent == false) and primaryG or accentG
    local hoverB = (barSettings and barSettings.showAccent == false) and primaryB or accentB

    local icon = self:GetButtonIcon(button)
    local target = icon or button

    if hover.SetFrameLevel then
        hover:SetFrameLevel(button:GetFrameLevel() + 4)
    end

    hover:ClearAllPoints()
    hover:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
    hover:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)

    hover.ring:ClearAllPoints()
    hover.ring:SetPoint("TOPLEFT", hover, "TOPLEFT", -4, 4)
    hover.ring:SetPoint("BOTTOMRIGHT", hover, "BOTTOMRIGHT", 4, -4)
    hover.ring:SetVertexColor(hoverR, hoverG, hoverB, useMasque and 0.22 or 0.28)

    hover.glaze:ClearAllPoints()
    hover.glaze:SetPoint("TOPLEFT", target, "TOPLEFT", -2, 2)
    hover.glaze:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 2, -2)
    hover.glaze:SetVertexColor(hoverR, hoverG, hoverB, useMasque and 0.14 or 0.22)

    hover.top:ClearAllPoints()
    hover.top:SetPoint("TOPLEFT", hover, "TOPLEFT", 1, -1)
    hover.top:SetPoint("TOPRIGHT", hover, "TOPRIGHT", -1, -1)
    hover.top:SetHeight(1)
    hover.top:SetColorTexture(hoverR, hoverG, hoverB, useMasque and 0.32 or 0.55)

    hover.bottom:ClearAllPoints()
    hover.bottom:SetPoint("BOTTOMLEFT", hover, "BOTTOMLEFT", 1, 1)
    hover.bottom:SetPoint("BOTTOMRIGHT", hover, "BOTTOMRIGHT", -1, 1)
    hover.bottom:SetHeight(1)
    hover.bottom:SetColorTexture(hoverR, hoverG, hoverB, useMasque and 0.24 or 0.45)

    hover.left:ClearAllPoints()
    hover.left:SetPoint("TOPLEFT", hover, "TOPLEFT", 1, -1)
    hover.left:SetPoint("BOTTOMLEFT", hover, "BOTTOMLEFT", 1, 1)
    hover.left:SetWidth(1)
    hover.left:SetColorTexture(hoverR, hoverG, hoverB, useMasque and 0.28 or 0.50)

    hover.right:ClearAllPoints()
    hover.right:SetPoint("TOPRIGHT", hover, "TOPRIGHT", -1, -1)
    hover.right:SetPoint("BOTTOMRIGHT", hover, "BOTTOMRIGHT", -1, 1)
    hover.right:SetWidth(1)
    hover.right:SetColorTexture(hoverR, hoverG, hoverB, useMasque and 0.20 or 0.38)
end

function ActionBars:ShowButtonHoverEffect(button)
    local hover = self:GetButtonHoverFrame(button)
    if not hover then
        return
    end

    hover:SetAlpha(1)
    hover:Show()
    if hover.pulse and not hover.pulse:IsPlaying() then
        hover.pulse:Play()
    end
end

function ActionBars:HideButtonHoverEffect(button)
    local hover = button and button.__twichuiABHoverEffect or nil
    if not hover then
        return
    end

    if hover.pulse and hover.pulse:IsPlaying() then
        hover.pulse:Stop()
    end
    hover:SetAlpha(0)
    hover:Hide()
end

function ActionBars:ApplyHolderStyle(holder, barSettings)
    if not holder or not holder.SetBackdrop then
        return
    end

    local theme = T:GetModule("Theme", true)
    local primaryR, primaryG, primaryB = FetchThemeColor(theme, "primaryColor", { 0.10, 0.72, 0.74 })
    local bgR, bgG, bgB = FetchThemeColor(theme, "backgroundColor", { 0.05, 0.06, 0.08 })
    local accentR, accentG, accentB = FetchThemeColor(theme, "accentColor", { 0.96, 0.76, 0.24 })

    holder:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    holder:SetBackdropColor(bgR, bgG, bgB, barSettings.backdrop == false and 0 or 0.82)
    holder:SetBackdropBorderColor(primaryR, primaryG, primaryB,
        (barSettings.backdrop == false or barSettings.showBorder == false) and 0 or 0.45)

    if not holder.innerGlow then
        holder.innerGlow = holder:CreateTexture(nil, "ARTWORK")
        holder.innerGlow:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
        holder.innerGlow:SetPoint("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -1, 1)
    end
    local accentAlpha = (barSettings.backdrop == false or barSettings.showAccent == false) and 0 or 0.04
    holder.innerGlow:SetColorTexture(accentR, accentG, accentB, accentAlpha)

    if not holder.leftAccent then
        holder.leftAccent = holder:CreateTexture(nil, "BORDER")
        holder.leftAccent:SetPoint("TOPLEFT", holder, "TOPLEFT", 1, -1)
        holder.leftAccent:SetPoint("BOTTOMLEFT", holder, "BOTTOMLEFT", 1, 1)
        holder.leftAccent:SetWidth(3)
    end
    holder.leftAccent:SetColorTexture(accentR, accentG, accentB,
        (barSettings.backdrop == false or barSettings.showAccent == false) and 0 or 0.9)
end

function ActionBars:ApplyMoverStyle(mover)
    if not mover or not mover.SetBackdrop then
        return
    end

    local theme = T:GetModule("Theme", true)
    local primaryR, primaryG, primaryB = FetchThemeColor(theme, "primaryColor", { 0.10, 0.72, 0.74 })
    local bgR, bgG, bgB = FetchThemeColor(theme, "backgroundColor", { 0.05, 0.06, 0.08 })

    mover:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    mover:SetBackdropColor(bgR, bgG, bgB, 0.78)
    mover:SetBackdropBorderColor(primaryR, primaryG, primaryB, 0.9)
    mover.label:SetTextColor(1, 0.95, 0.85)
end

function ActionBars:ApplyButtonStyle(button, actionBarDB, barKey, barSettings)
    if not button then
        return
    end

    local useMasque = actionBarDB.useMasque == true and Masque ~= nil
    local theme = T:GetModule("Theme", true)
    local primaryR, primaryG, primaryB = FetchThemeColor(theme, "primaryColor", { 0.10, 0.72, 0.74 })
    local accentR, accentG, accentB = FetchThemeColor(theme, "accentColor", { 0.96, 0.76, 0.24 })
    local bgR, bgG, bgB = FetchThemeColor(theme, "backgroundColor", { 0.05, 0.06, 0.08 })

    local icon = self:GetButtonIcon(button)
    if icon then
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end

    local border = button.Border or _G[button:GetName() .. "Border"]
    if border and border.SetAlpha then
        border:SetAlpha(useMasque and 1 or 0)
    end

    SuppressButtonArtTextures(button)
    SuppressButtonAnimationEffects(button)
    SuppressSpellCastAnim(button)
    if useMasque ~= true then
        SuppressButtonBorder(button)
    end

    if not button.__twichuiABChrome then
        local chrome = CreateFrame("Frame", nil, button, "BackdropTemplate")
        chrome:SetPoint("TOPLEFT", button, "TOPLEFT", -1, 1)
        chrome:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, -1)
        chrome:EnableMouse(false)
        button.__twichuiABChrome = chrome

        chrome.innerGlow = chrome:CreateTexture(nil, "ARTWORK")
        chrome.innerGlow:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
        chrome.innerGlow:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -1, 1)

        chrome.leftAccent = chrome:CreateTexture(nil, "BORDER")
        chrome.leftAccent:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
        chrome.leftAccent:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 1, 1)
        chrome.leftAccent:SetWidth(2)
    end

    local chrome = button.__twichuiABChrome
    if chrome.SetFrameLevel then
        chrome:SetFrameLevel(max(0, button:GetFrameLevel() - 1))
    end

    chrome:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })
    chrome:SetBackdropColor(bgR, bgG, bgB, useMasque and 0 or 0.92)
    chrome:SetBackdropBorderColor(primaryR, primaryG, primaryB,
        (useMasque or (barSettings and barSettings.showBorder == false)) and 0 or 0.42)
    local accentEnabled = barSettings and barSettings.showAccent ~= false
    chrome.innerGlow:SetColorTexture(accentR, accentG, accentB, (useMasque or not accentEnabled) and 0 or 0.05)
    chrome.leftAccent:SetColorTexture(accentR, accentG, accentB, (useMasque or not accentEnabled) and 0 or 0.85)
    chrome:SetShown(useMasque ~= true)

    self:UpdateButtonHoverEffect(button, actionBarDB, barSettings)
    if button.IsMouseOver and button:IsMouseOver() then
        self:ShowButtonHoverEffect(button)
    else
        self:HideButtonHoverEffect(button)
    end

    if not button.__twichuiABHoverHooked then
        button:HookScript("OnEnter", function()
            ActionBars:SetBarHoverState(barKey, true)
            SuppressButtonBorder(button)
            ActionBars:ShowButtonHoverEffect(button)
            if ActionBars.keybindModeActive == true then
                ActionBars:BindUpdate(button)
            end
        end)
        button:HookScript("OnLeave", function()
            SuppressButtonBorder(button)
            ActionBars:HideButtonHoverEffect(button)
            ActionBars:ScheduleBarFade(barKey)
        end)
        button:HookScript("OnHide", function()
            SuppressButtonBorder(button)
            ActionBars:HideButtonHoverEffect(button)
        end)
        button.__twichuiABHoverHooked = true
    end

    self:ApplyTypography(button, actionBarDB)
    self:ApplyCooldownSettingsToButton(button, actionBarDB, barSettings)
    self:UpdateButtonGlow(button)
end

function ActionBars:ApplyTypography(button, actionBarDB)
    local fontPath = self:ResolveFont(actionBarDB.textFont)
    local fontFlags = actionBarDB.fontOutline ~= "NONE" and (actionBarDB.fontOutline or "") or ""
    local textR, textG, textB = self:GetResolvedTextColor(actionBarDB)
    local useShadow = actionBarDB.textShadow == true

    local hotKey = self:GetButtonHotKey(button)
    if hotKey then
        hotKey:SetFont(fontPath, ClampNumber(actionBarDB.hotkeyFontSize, 6, 24, 11), fontFlags)
        hotKey:SetTextColor(textR, textG, textB, 1)
        self:ApplyTextShadow(hotKey, useShadow)
        self:UpdateButtonBindingText(button)
        if actionBarDB.showHotkeys == true then
            hotKey:Show()
        else
            hotKey:Hide()
        end
    end

    local count = self:GetButtonCount(button)
    if count then
        count:SetFont(fontPath, ClampNumber(actionBarDB.countFontSize, 6, 24, 11), fontFlags)
        count:SetTextColor(textR, textG, textB, 1)
        self:ApplyTextShadow(count, useShadow)
        if actionBarDB.showCounts == true then
            count:Show()
        else
            count:Hide()
        end
    end

    local name = self:GetButtonMacroName(button)
    if name then
        name:SetFont(fontPath, ClampNumber(actionBarDB.macroFontSize, 6, 24, 9), fontFlags)
        name:SetJustifyH("CENTER")
        name:SetTextColor(textR, textG, textB, 1)
        self:ApplyTextShadow(name, useShadow)
        if actionBarDB.showMacroNames == true then
            name:Show()
        else
            name:Hide()
        end
    end
end

function ActionBars:ApplyCooldownSettingsToButton(button, actionBarDB, barSettings)
    local cooldown = self:GetButtonCooldown(button)
    if not cooldown then
        return
    end

    local showSwipe = actionBarDB.showCooldownSwipe == true and (not barSettings or barSettings.showCooldownSwipe ~= false)
    local icon = self:GetButtonIcon(button)

    if icon then
        cooldown:ClearAllPoints()
        cooldown:SetAllPoints(icon)
    end

    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(actionBarDB.showCooldownText ~= true)
    end
    if cooldown.SetDrawSwipe then
        cooldown:SetDrawSwipe(showSwipe)
    end
    if cooldown.SetDrawEdge then
        cooldown:SetDrawEdge(showSwipe)
    end
    if cooldown.SetDrawBling then
        cooldown:SetDrawBling(false)
    end
end

function ActionBars:ApplyCooldownSettings()
    local db = self:GetDB()
    if not db or db.enabled == false then
        return
    end

    for _, buttons in pairs(self.barButtons) do
        for _, button in ipairs(buttons) do
            local barKey = button:GetParent() and button:GetParent().barKey or nil
            self:ApplyCooldownSettingsToButton(button, db, barKey and self:GetBarSettings(barKey) or nil)
        end
    end
end

function ActionBars:RefreshButtonStates()
    local db = self:GetDB()
    if not db or db.enabled == false then
        return
    end

    for barKey, buttons in pairs(self.barButtons) do
        local settings = self:GetBarSettings(barKey)
        for _, button in ipairs(buttons) do
            self:ApplyCooldownSettingsToButton(button, db, settings)
            self:UpdateButtonGlow(button)
            if db.showGrid == true then
                if type(ActionButton_ShowGrid) == "function" then
                    pcall(ActionButton_ShowGrid, button)
                end
            elseif type(ActionButton_HideGrid) == "function" then
                pcall(ActionButton_HideGrid, button)
            end
        end
        local holder = self.holders[barKey]
        if holder and settings then
            holder:SetAlpha(self:GetTargetAlpha(settings, false))
        end
    end

    self:ScheduleGlowSync(0.05)
end

function ActionBars:GetTargetAlpha(barSettings, hovered)
    local db = self:GetDB()
    local alpha = ClampNumber(barSettings.alpha, 0.05, 1, 1)

    if db and db.lockBars == false then
        return alpha
    end

    if barSettings.mouseover == true then
        return hovered == true and alpha or 0
    end

    return alpha
end

function ActionBars:SetBarHoverState(barKey, hovered)
    local holder = self.holders[barKey]
    local settings = self:GetBarSettings(barKey)
    if not holder or not settings then
        return
    end

    holder:SetAlpha(self:GetTargetAlpha(settings, hovered == true))
end

function ActionBars:ScheduleBarFade(barKey)
    local token = (self.hoverTokens[barKey] or 0) + 1
    self.hoverTokens[barKey] = token

    C_Timer.After(MOUSEOVER_FADE_DELAY, function()
        if ActionBars.hoverTokens[barKey] ~= token then
            return
        end

        local holder = ActionBars.holders[barKey]
        local buttons = ActionBars.barButtons[barKey] or {}
        if not holder or holder:IsMouseOver() then
            return
        end

        for _, button in ipairs(buttons) do
            if button and button:IsMouseOver() then
                return
            end
        end

        ActionBars:SetBarHoverState(barKey, false)
    end)
end

function ActionBars:ApplyVisibility(holder, barSettings)
    pcall(UnregisterStateDriver, holder, "visibility")

    local db = self:GetDB()
    if db and db.lockBars == false then
        holder:Show()
        return
    end

    local visibility = tostring(barSettings.visibility or DEFAULT_VISIBILITY)
    local ok = pcall(RegisterStateDriver, holder, "visibility", visibility)
    if not ok then
        pcall(RegisterStateDriver, holder, "visibility", DEFAULT_VISIBILITY)
    end
end

function ActionBars:UpdateMovers()
    local db = self:GetDB()
    local showMovers = db and db.lockBars == false
    local inspector = self._moverInspector

    for _, mover in pairs(self.movers) do
        self:ApplyMoverStyle(mover)
        mover:SetShown(false)
    end

    if not showMovers then
        if inspector then
            inspector:Hide()
        end
        return
    end

    for _, definition in ipairs(BAR_DEFINITIONS) do
        local holder = self.holders[definition.key]
        local mover = self.movers[definition.key]
        local settings = self:GetBarSettings(definition.key)
        if holder and mover and settings and holder:IsShown() then
            mover:ClearAllPoints()
            mover:SetPoint(settings.point or "BOTTOM", UIParent, settings.relativePoint or settings.point or "BOTTOM",
                settings.x or 0, settings.y or 0)
            mover:SetScale(holder:GetScale())
            mover:SetSize(max(holder:GetWidth(), 24), max(holder:GetHeight(), 24))
            mover.label:SetText(definition.label)
            mover:Show()
        end
    end
end

function ActionBars:HideDefaultArt()
    for _, frameName in ipairs(BLIZZARD_FRAMES_TO_HIDE) do
        local frame = _G[frameName]
        if frame then
            self:CaptureFrameState(frame)
            for _, region in ipairs({ frame:GetRegions() }) do
                self:CaptureRegionState(region)
            end
            if _G.UIPARENT_MANAGED_FRAME_POSITIONS then
                _G.UIPARENT_MANAGED_FRAME_POSITIONS[frameName] = nil
            end
            if frame.ignoreInLayout ~= nil then
                frame.ignoreInLayout = true
            end
            local ok, err = pcall(function()
                SuppressFrameRegions(frame)
                frame:SetParent(self.blizzardHiddenRoot)
                frame:SetAlpha(0)
                frame:Hide()
            end)
            if ok then
                LogDebugf(false, "hide blizzard frame=%s shown=%s parent=%s",
                    frameName,
                    tostring(frame.IsShown and frame:IsShown() or false),
                    frame.GetParent and frame:GetParent() and frame:GetParent():GetName() or "nil")
            else
                LogDebugf(true, "hide blizzard frame failed frame=%s error=%s", frameName, SafeDebugString(err))
                if ErrorLog and ErrorLog.CaptureFailure then
                    ErrorLog:CaptureFailure("ActionBars.HideDefaultArt." .. frameName, err, 3)
                end
            end
        end
    end

    for _, objectName in ipairs(BLIZZARD_OBJECTS_TO_HIDE) do
        local object = _G[objectName]
        if object then
            local ok, err = pcall(function()
                if object.GetObjectType and object:GetObjectType() == "Frame" then
                    self:CaptureFrameState(object)
                    for _, region in ipairs({ object:GetRegions() }) do
                        self:CaptureRegionState(region)
                    end
                    SuppressFrameRegions(object)
                else
                    self:CaptureRegionState(object)
                    SuppressRegion(object)
                end

                if object.SetParent then
                    object:SetParent(self.blizzardHiddenRoot)
                end
                if object.SetAlpha then
                    object:SetAlpha(0)
                end
                if object.Hide then
                    object:Hide()
                end
            end)

            if ok then
                LogDebugf(false, "hide blizzard object=%s type=%s",
                    objectName,
                    SafeDebugString(object.GetObjectType and object:GetObjectType() or type(object)))
            else
                LogDebugf(true, "hide blizzard object failed object=%s error=%s", objectName, SafeDebugString(err))
            end
        end
    end
end

function ActionBars:LayoutBar(definition, barSettings, actionBarDB)
    local holder = self.holders[definition.key]
    if not holder then
        return
    end

    local buttons = self:GetButtonsForDefinition(definition)
    local availableCount = self:GetButtonCountForDefinition(definition, buttons)
    local enabled = barSettings.enabled == true and availableCount > 0

    holder:ClearAllPoints()
    holder:SetPoint(barSettings.point or "BOTTOM", UIParent, barSettings.relativePoint or barSettings.point or "BOTTOM",
        barSettings.x or 0, barSettings.y or 0)
    holder:SetScale(ClampNumber(barSettings.scale, 0.5, 2, 1))
    holder:SetFrameLevel(30)

    self:ApplyHolderStyle(holder, barSettings)

    if not enabled then
        pcall(UnregisterStateDriver, holder, "visibility")
        holder:SetAlpha(0)
        holder:SetShown(false)

        for _, button in ipairs(buttons) do
            button:Hide()
        end

        return
    end

    local buttonSize = ClampNumber(barSettings.buttonSize, 22, 64, definition.fallbackButtonSize)
    local buttonsPerRow = ClampNumber(barSettings.buttonsPerRow, 1, availableCount, definition.fallbackButtonsPerRow)
    local spacing = ClampNumber(actionBarDB.buttonSpacing, 0, 20, 4)
    local rows = ceil(availableCount / buttonsPerRow)
    local width = (buttonsPerRow * buttonSize) + ((buttonsPerRow - 1) * spacing) + (DEFAULT_HOLDER_PADDING * 2)
    local height = (rows * buttonSize) + ((rows - 1) * spacing) + (DEFAULT_HOLDER_PADDING * 2)

    holder:SetSize(width, height)

    for index, button in ipairs(buttons) do
        button:SetParent(holder)
        button:ClearAllPoints()
        button:SetSize(buttonSize, buttonSize)
        button:SetFrameStrata("MEDIUM")
        button:SetFrameLevel(holder:GetFrameLevel() + 4)

        if index <= availableCount then
            local row = floor((index - 1) / buttonsPerRow)
            local column = (index - 1) % buttonsPerRow
            button:SetPoint("TOPLEFT", holder, "TOPLEFT",
                DEFAULT_HOLDER_PADDING + (column * (buttonSize + spacing)),
                -DEFAULT_HOLDER_PADDING - (row * (buttonSize + spacing)))
            self:ApplyButtonStyle(button, actionBarDB, definition.key, barSettings)

            if actionBarDB.showGrid == true then
                if type(ActionButton_ShowGrid) == "function" then
                    pcall(ActionButton_ShowGrid, button)
                end
            elseif type(ActionButton_HideGrid) == "function" then
                pcall(ActionButton_HideGrid, button)
            end

            button:Show()
        else
            button:Hide()
        end
    end

    self:ApplyVisibility(holder, barSettings)
    holder:SetAlpha(self:GetTargetAlpha(barSettings, false))
    holder:Show()
end

function ActionBars:ApplyMasqueSettings(actionBarDB)
    if not Masque then
        self:ClearMasqueGroups()
        return
    end

    if actionBarDB.useMasque ~= true then
        self:ClearMasqueGroups()
        return
    end

    self.masqueButtons = self.masqueButtons or {}

    for _, definition in ipairs(BAR_DEFINITIONS) do
        local buttons = self.barButtons[definition.key] or {}
        if #buttons > 0 then
            local group = self.masqueGroups[definition.key]
            if not group then
                group = Masque:Group("TwichUI Reformed", definition.label)
                self.masqueGroups[definition.key] = group
            end

            self.masqueButtons[definition.key] = self.masqueButtons[definition.key] or {}

            for _, button in ipairs(buttons) do
                if not self.masqueButtons[definition.key][button] then
                    group:AddButton(button, {
                        Icon = self:GetButtonIcon(button),
                        Cooldown = self:GetButtonCooldown(button),
                        HotKey = self:GetButtonHotKey(button),
                        Count = self:GetButtonCount(button),
                        Name = self:GetButtonMacroName(button),
                        Border = button.Border or _G[button:GetName() .. "Border"],
                        Normal = _G[button:GetName() .. "NormalTexture"],
                        Highlight = button:GetHighlightTexture(),
                    })
                    self.masqueButtons[definition.key][button] = true
                end

                if button.__twichuiABChrome then
                    button.__twichuiABChrome:Hide()
                end

                ActionBars:HideButtonHoverEffect(button)

                SuppressButtonAnimationEffects(button)
                SuppressSpellCastAnim(button)
            end

            if group.ReSkin then
                group:ReSkin()
            end

            for _, button in ipairs(buttons) do
                SuppressButtonArtTextures(button)
                SuppressButtonAnimationEffects(button)
                SuppressSpellCastAnim(button)
            end
        end
    end
end

function ActionBars:ClearMasqueGroups()
    for key, group in pairs(self.masqueGroups) do
        if group and type(group.Delete) == "function" then
            group:Delete()
        end
        self.masqueGroups[key] = nil
    end
    self.masqueButtons = {}
end

function ActionBars:RefreshAll()
    local actionBarDB = self:GetDB()
    if not actionBarDB or actionBarDB.enabled == false then
        return
    end

    if InCombatLockdown() then
        self.pendingRefresh = true
        return
    end

    self:HideDefaultArt()

    for _, definition in ipairs(BAR_DEFINITIONS) do
        local barSettings = self:GetBarSettings(definition.key)
        if barSettings then
            self:LayoutBar(definition, barSettings, actionBarDB)
        end
    end

    self:ApplyMasqueSettings(actionBarDB)
    self:RefreshButtonStates()
    self:UpdateAllButtonGlows()
    self:ScheduleGlowSync(0.15)
    self:UpdateMovers()
end