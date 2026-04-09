--[[
    AutoLoot module — TwichUI Quality of Life

    Design:
    - When the module is ENABLED, autoLootDefault CVar is set to 1 and all
      loot sessions are handled by our fast ticker (~30 Hz, one slot per tick).
    - On DISABLE the original CVar value is restored.
    - Holding the AUTOLOOTTOGGLE modifier key (default: Shift) while clicking
      a corpse suppresses auto-loot for that session — normal loot frame opens.
    - The loot frame is hidden by re-parenting to a hidden sink frame.
      It only becomes visible for: bag full, BoP confirm, modifier-suppressed.
    - TSM Destroy workaround: if TSMDestroyBtn is visible when loot closes,
      /tsm destroy is re-issued via a deferred ticker.

    When the module is DISABLED every event and the loot-frame hook are fully
    removed — zero residual CPU cost.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class AutoLootModule : AceModule, AceEvent-3.0
local AL = QOL:NewModule("AutoLoot", "AceEvent-3.0")
AL:SetEnabledState(false)

-- ---------------------------------------------------------------------------
-- Localized globals
-- ---------------------------------------------------------------------------
local C_Timer        = _G.C_Timer
local C_Container    = _G.C_Container
local C_CVar         = _G.C_CVar
local C_Item         = _G.C_Item
local C_PartyInfo    = _G.C_PartyInfo
local GetCVar        = _G.GetCVar
local GetCVarBool    = _G.GetCVarBool
local GetLootThreshold   = _G.GetLootThreshold
local GetLootSlotInfo    = _G.GetLootSlotInfo
local GetLootSlotLink    = _G.GetLootSlotLink
local GetLootSlotType    = _G.GetLootSlotType
local GetNumLootItems    = _G.GetNumLootItems
local IsFishingLoot      = _G.IsFishingLoot
local IsInGroup          = _G.IsInGroup
local IsModifiedClick    = _G.IsModifiedClick
local LootSlot           = _G.LootSlot
local PlaySound          = _G.PlaySound
local SOUNDKIT           = _G.SOUNDKIT
local SlashCmdList       = _G.SlashCmdList
local BACKPACK_CONTAINER = _G.BACKPACK_CONTAINER
local NUM_BAG_SLOTS      = _G.NUM_BAG_SLOTS
local NUM_TOTAL_EQUIPPED_BAG_SLOTS = _G.NUM_TOTAL_EQUIPPED_BAG_SLOTS
local ERR_INV_FULL       = _G.ERR_INV_FULL
local ERR_ITEM_MAX_COUNT = _G.ERR_ITEM_MAX_COUNT
local ERR_LOOT_ROLL_PENDING = _G.ERR_LOOT_ROLL_PENDING
local Enum               = _G.Enum
local LootFrame          = _G.LootFrame
local UIParent           = _G.UIParent
local math               = math

local LOOT_THRESHOLD_NONE    = 10     -- always auto-loot solo normal loot
local LOOT_TICKER_INTERVAL   = 0.033  -- ~30 Hz, one slot per tick
local SOUND_INV_FULL_DEFAULT = 44321

-- ---------------------------------------------------------------------------
-- Per-session state (wiped at LOOT_CLOSED via ResetState)
-- ---------------------------------------------------------------------------
local state = {
    isLooting            = false,
    isHidden             = true,    -- true = loot frame is suppressed
    isAnyItemLocked      = false,
    lootFailure          = false,
    lastNumLoot          = nil,
    suppressedByModifier = false,   -- player held the toggle key
    inventorySoundPlayed = false,
    lootTicker           = nil,
}

-- CVar value before we took ownership (restored on Disable).
local savedAutoLootCVar = nil

-- Hidden anchor; LootFrame is reparented here while we loot silently.
local sinkFrame = nil

-- Whether the hooksecurefunc for EditMode has been installed.
local editModeHooked = false

-- ---------------------------------------------------------------------------
-- Settings accessor
-- ---------------------------------------------------------------------------
local function GetSettings()
    local opts = T:GetModule("Configuration") and T:GetModule("Configuration").Options.AutoLoot
    if not opts then return { fishingSound = true, inventorySound = false, soundID = SOUND_INV_FULL_DEFAULT } end
    return {
        fishingSound   = opts:GetFishingSoundEnabled(),
        inventorySound = opts:GetInventorySoundEnabled(),
        soundID        = opts:GetInventorySoundID(),
    }
end

-- ---------------------------------------------------------------------------
-- Bag / threshold helpers
-- ---------------------------------------------------------------------------

local function GetLootThresholdForSituation()
    if C_PartyInfo and C_PartyInfo.GetLootMethod then
        local method = C_PartyInfo.GetLootMethod()
        if IsInGroup() and (
            method == Enum.LootMethod.Group or
            method == Enum.LootMethod.NeedBeforeGreed or
            method == Enum.LootMethod.MasterLooter) then
            return GetLootThreshold()
        end
    end
    return LOOT_THRESHOLD_NONE
end

---@param link string
---@param qty number
---@return boolean
local function ItemFitsInBags(link, qty)
    if not link then return true end
    local stackCount, _, _, _, _, _, _, _, _, isCraftingReagent = select(8, C_Item.GetItemInfo(link))
    local itemFamily = C_Item.GetItemFamily(link)

    local carried = C_Item.GetItemCount and C_Item.GetItemCount(link) or 0
    if carried > 0 and stackCount and stackCount > 1 then
        if ((stackCount - carried) % stackCount) >= (qty or 1) then
            return true
        end
    end

    local bagMax = NUM_TOTAL_EQUIPPED_BAG_SLOTS or NUM_BAG_SLOTS or 4
    for bag = BACKPACK_CONTAINER, bagMax do
        local freeSlots, bagFamily = C_Container.GetContainerNumFreeSlots(bag)
        if freeSlots and freeSlots > 0 then
            if bag == 5 then
                if isCraftingReagent then return true else return false end
            end
            if not bagFamily or bagFamily == 0 or
               (itemFamily and _G.bit and _G.bit.band(itemFamily, bagFamily) > 0) then
                return true
            end
        end
    end
    return false
end

-- ---------------------------------------------------------------------------
-- Core loot machinery
-- ---------------------------------------------------------------------------

---@param slot number
---@return boolean processed
local function LootOneSlot(slot)
    local SLOT_NONE = Enum.LootSlotType and Enum.LootSlotType.None or 0
    local SLOT_ITEM = Enum.LootSlotType and Enum.LootSlotType.Item or 1
    local slotType  = GetLootSlotType(slot)
    if slotType == SLOT_NONE then return true end

    local link                              = GetLootSlotLink(slot)
    local qty, _, quality, locked, isQuest  = select(3, GetLootSlotInfo(slot))
    local threshold                         = GetLootThresholdForSituation()

    if locked or (quality and quality >= threshold) then
        state.isAnyItemLocked = true
        return false
    end

    if slotType ~= SLOT_ITEM or isQuest or ItemFitsInBags(link, qty or 1) then
        LootSlot(slot)
        return true
    end
    return false  -- no bag space
end

local function CancelLootTicker()
    if state.lootTicker then
        state.lootTicker:Cancel()
        state.lootTicker = nil
    end
end

local function ShowLootFrame()
    state.isHidden = false
    if not LootFrame then return end
    if LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(UIParent)
        LootFrame:SetFrameStrata("HIGH")
        if GetCVarBool("lootUnderMouse") then
            local x, y  = _G.GetCursorPosition()
            local scale = LootFrame:GetEffectiveScale()
            LootFrame:ClearAllPoints()
            LootFrame:SetPoint("TOPLEFT", nil, "BOTTOMLEFT",
                x / scale - 30,
                math.max((y / scale) + 50, 350))
            LootFrame:Raise()
        end
    end
end

local function HideLootFrameToSink()
    if sinkFrame and LootFrame and LootFrame:IsEventRegistered("LOOT_OPENED") then
        LootFrame:SetParent(sinkFrame)
    end
end

local function StartLootTicker(numItems)
    CancelLootTicker()
    local current = numItems
    state.lootTicker = C_Timer.NewTicker(LOOT_TICKER_INTERVAL, function()
        if current >= 1 then
            if not LootOneSlot(current) then
                state.lootFailure = true
            end
            current = current - 1
        else
            if state.lootFailure then
                ShowLootFrame()
            end
            CancelLootTicker()
        end
    end, numItems + 1)
end

local function ResetState()
    CancelLootTicker()
    HideLootFrameToSink()
    state.isLooting            = false
    state.isHidden             = true
    state.isAnyItemLocked      = false
    state.lootFailure          = false
    state.lastNumLoot          = nil
    state.suppressedByModifier = false
    state.inventorySoundPlayed = false
end

-- ---------------------------------------------------------------------------
-- Event handlers
-- ---------------------------------------------------------------------------

--- Both LOOT_OPENED (primary in retail, carries the autoLoot flag) and
--- LOOT_READY use this handler.
function AL:LOOT_READY(event, autoLoot)
    state.isLooting = true

    local numItems = GetNumLootItems()
    if numItems == 0 or state.lastNumLoot == numItems then return end
    state.lastNumLoot = numItems

    -- If the player held the AUTOLOOTTOGGLE key (Shift by default) they want
    -- to manually inspect this loot — honour that and show the frame.
    if IsModifiedClick and IsModifiedClick("AUTOLOOTTOGGLE") then
        state.suppressedByModifier = true
        ShowLootFrame()
        return
    end

    local settings = GetSettings()
    if IsFishingLoot() and settings.fishingSound and SOUNDKIT then
        PlaySound(SOUNDKIT.FISHING_REEL_IN, "Master")
    end

    -- We own autoLootDefault (set in OnEnable), so always use the fast ticker.
    StartLootTicker(numItems)
end

AL.LOOT_OPENED = AL.LOOT_READY

function AL:LOOT_CLOSED()
    -- TSM Destroy workaround.
    local tsmBtn = _G.TSMDestroyBtn
    if tsmBtn and tsmBtn.IsVisible and tsmBtn:IsVisible() then
        C_Timer.NewTicker(0, function()
            if SlashCmdList and SlashCmdList.TSM then
                SlashCmdList.TSM("destroy")
            end
        end, 2)
    end
    ResetState()
end

function AL:UI_ERROR_MESSAGE(event, _, message)
    if message == ERR_INV_FULL or message == ERR_ITEM_MAX_COUNT then
        if state.isLooting then
            if state.isHidden then ShowLootFrame() end
            local settings = GetSettings()
            if settings.inventorySound and not state.inventorySoundPlayed and not state.isAnyItemLocked then
                state.inventorySoundPlayed = true
                PlaySound(settings.soundID or SOUND_INV_FULL_DEFAULT, "Master")
            end
        end
    elseif message == ERR_LOOT_ROLL_PENDING then
        if state.isLooting and state.isHidden then
            ShowLootFrame()
        end
    end
end

-- ---------------------------------------------------------------------------
-- LootFrame sink hook
-- ---------------------------------------------------------------------------
local function EnsureSinkHook()
    if not LootFrame then return end
    if not LootFrame:IsEventRegistered("LOOT_OPENED") then return end

    HideLootFrameToSink()

    if not editModeHooked and LootFrame.UpdateShownState then
        editModeHooked = true
        _G.hooksecurefunc(LootFrame, "UpdateShownState", function(self)
            if self.isInEditMode then
                self:SetParent(UIParent)
            elseif state.isHidden and sinkFrame then
                self:SetParent(sinkFrame)
            end
        end)
    end
end

-- ---------------------------------------------------------------------------
-- CVar management
-- ---------------------------------------------------------------------------
local function TakeAutoLootOwnership()
    if C_CVar then
        savedAutoLootCVar = GetCVar and GetCVar("autoLootDefault") or "0"
        C_CVar.SetCVar("autoLootDefault", "1")
    end
end

local function ReleaseAutoLootOwnership()
    if C_CVar and savedAutoLootCVar then
        C_CVar.SetCVar("autoLootDefault", savedAutoLootCVar)
        savedAutoLootCVar = nil
    end
end

-- ---------------------------------------------------------------------------
-- AceModule lifecycle
-- ---------------------------------------------------------------------------

function AL:OnEnable()
    if not sinkFrame then
        sinkFrame = _G.CreateFrame("Frame", "TwichUI_AutoLootSink", UIParent)
        sinkFrame:SetToplevel(true)
        sinkFrame:Hide()
    end

    -- Set the CVar so LOOT_OPENED/LOOT_READY always fire with auto-loot intent.
    TakeAutoLootOwnership()

    self:RegisterEvent("LOOT_READY",       "LOOT_READY")
    self:RegisterEvent("LOOT_OPENED",      "LOOT_READY")
    self:RegisterEvent("LOOT_CLOSED",      "LOOT_CLOSED")
    self:RegisterEvent("UI_ERROR_MESSAGE", "UI_ERROR_MESSAGE")

    C_Timer.After(0.5, EnsureSinkHook)
end

function AL:OnDisable()
    CancelLootTicker()
    ResetState()

    if LootFrame then LootFrame:SetParent(UIParent) end
    editModeHooked = false

    ReleaseAutoLootOwnership()
    self:UnregisterAllEvents()
end
