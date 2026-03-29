---@diagnostic disable: undefined-field, undefined-global, inject-field
--[[
    TwichUI Aura Watcher Designer — Graphical Configuration UI

    A custom floating panel for assigning tracked auras to indicator slots.
    Opens via UnitFrames:AWOpenDesigner(frameKey) or the mini-button embedded
    in the UnitFrames options page.

    Layout (860 × 526):
      ┌────────────────────────────────────────────────────────────────┐
      │  Header: title · frame-type selector · close button           │
      ├──────────────────────┬─────────────────────────────────────────┤
      │  CATALOGUE  (240px)  │  INDICATOR SLOTS  +  DETAIL  (596px)   │
      │  ─ Your Spec icons   │  Six slot cards (3×2 grid) above       │
      │  ─ Generic filters   │  Detail panel expands below selected   │
      │  ─ Spell Groups      │  slot with anchor grid + type controls  │
      └──────────────────────┴─────────────────────────────────────────┘

    Interaction model:
      1. Click a Catalogue tile → it becomes "held" (gold border).
      2. Click an empty or filled indicator slot → assigns the held entry.
      3. Click a slot with nothing held → selects it for editing / deletion.
      4. The detail panel updates immediately for the active selection.
]]

local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type UnitFramesModule
local UnitFrames = T:GetModule("UnitFrames")
if not UnitFrames then return end

local CreateFrame   = _G.CreateFrame
local UIParent      = _G.UIParent
local GameTooltip   = _G.GameTooltip
local GetTime       = _G.GetTime
local math_floor    = math.floor
local tostring      = tostring
local ipairs        = ipairs
local pairs         = pairs
local type          = type
local wipe          = wipe

-- ============================================================
-- Visual constants  (match TwichUI wizard palette)
-- ============================================================
local W_TOTAL  = 860
local H_TOTAL  = 700
local HEADER_H = 40
local PAD      = 12

-- Colours
local C = {
    bg      = { 0.05, 0.06, 0.08 },
    panel   = { 0.08, 0.09, 0.12 },
    card    = { 0.10, 0.11, 0.15 },
    cardSel = { 0.09, 0.18, 0.20 },
    cardHeld= { 0.18, 0.15, 0.07 },
    border  = { 0.20, 0.22, 0.28 },
    teal    = { 0.10, 0.72, 0.74 },
    gold    = { 0.96, 0.76, 0.24 },
    green   = { 0.42, 0.89, 0.63 },
    red     = { 0.90, 0.30, 0.32 },
    text    = { 1.00, 0.95, 0.85 },
    muted   = { 0.50, 0.52, 0.58 },
    danger  = { 0.90, 0.30, 0.32 },
}

local SECTION_FONT_SIZE = 11
local LABEL_FONT_SIZE   = 12
local BODY_FONT_SIZE    = 13

-- Anchor point labels (for 3×3 grid)
local ANCHOR_KEYS  = { "TOPLEFT","TOP","TOPRIGHT","LEFT","CENTER","RIGHT","BOTTOMLEFT","BOTTOM","BOTTOMRIGHT" }
local ANCHOR_SHORT = {
    TOPLEFT="TL",TOP="TC",TOPRIGHT="TR",
    LEFT="ML",CENTER="CC",RIGHT="MR",
    BOTTOMLEFT="BL",BOTTOM="BC",BOTTOMRIGHT="BR",
}

-- Frame-key → human label mapping
local FRAME_LABELS = {
    player       = "Player",
    target       = "Target",
    focus        = "Focus",
    pet          = "Pet",
    mouseover    = "Mouseover",
    boss         = "Boss",
    partyMember  = "Party Member",
    raidMember   = "Raid Member",
    tankMember   = "Main Tank",
}
-- Ordered list for the dropdown
local FRAME_KEY_ORDER = {
    "player","target","focus","pet","mouseover","boss",
    "partyMember","raidMember","tankMember"
}

-- ============================================================
-- State
-- ============================================================
local designer = {}   -- namespace for public methods on UnitFrames:AW*

-- Persistent UI refs
local root          -- root Frame
local catalogScroll -- ScrollFrame for catalogue
local catalogChild  -- content child of catalogScroll
local slotCards     = {}   -- [1..6] = card Frame
local detailPanel          -- Frame that shows slot detail
local headerFrameLabel     -- FontString showing current frame type

-- Runtime state
local activeFrameKey= "partyMember"   -- which unit-frame type is being edited
local heldEntry     = nil             -- catalog/generic entry currently "picked up"
local selectedSlot  = 0               -- 1-6, currently selected indicator slot
local tilePool      = {}              -- reused catalog tile frames
local sectionLabels = {}              -- FontString section labels (tracked for cleanup)
local previewHost       = nil         -- mock frame for live preview
local previewSidePanel  = nil         -- right-side panel hosting the preview
local activeDragCatcher = nil         -- global drag-release catcher frame
local selectedLayer     = 1           -- 1=primary, 2+=extraLayers[n-1]

-- ============================================================
-- Live-update flush — pushes config changes to all active frames
-- ============================================================
local flushPending = false
local RefreshPreview  -- forward-declare

local function DeferredFlush()
    if not flushPending then
        flushPending = true
        C_Timer.After(0.1, function()
            flushPending = false
            UnitFrames:AWForceUpdate()
            if RefreshPreview then RefreshPreview() end
        end)
    end
end

-- ============================================================
-- Shared UI helpers
-- ============================================================

--- Format a numeric value for display: integers show as integers,
--- floats with the appropriate decimal places based on step size.
local function FormatSliderVal(v, step)
    if step and step < 1 then
        local places = math.ceil(math.abs(math.log(step) / math.log(10)))
        return string.format("%%.%df", places):format(v)
    end
    return tostring(math.floor(v + 0.5))
end

--- Attach a GameTooltip to a frame.  Fires on enter/leave.
--- Does NOT stomp an existing OnLeave script.
local function AddTooltip(frame, title, body)
    frame:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(title, 1, 1, 1)
        if body then GameTooltip:AddLine(body, 0.8, 0.8, 0.8, true) end
        GameTooltip:Show()
    end)
    local prevLeave = frame:GetScript("OnLeave")
    frame:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        if prevLeave then prevLeave(self) end
    end)
end

-- ============================================================
-- Font helper
-- ============================================================
local function Font(size, flags)
    local LSM  = T.Libs and T.Libs.LSM
    local path = (LSM and LSM.Fetch and LSM:Fetch("font", "Expressway"))
             or "Fonts\\ARIALN.TTF"
    return path, size or 12, flags or ""
end

--- Always use a unicode-capable font for glyph symbols (×  ✓  ✕  ⟳).
local function SymbolFont(size)
    return "Fonts\\ARIALN.TTF", size or 14, ""
end

local function NewText(parent, text, size, r, g, b)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    fs:SetFont(Font(size or BODY_FONT_SIZE))
    if r then fs:SetTextColor(r, g, b) else fs:SetTextColor(C.text[1], C.text[2], C.text[3]) end
    fs:SetText(text or "")
    return fs
end

local function Backdrop(frame, bg, bdr, aBg, aBdr)
    if not frame.SetBackdrop then return end
    frame:SetBackdrop({
        bgFile   = "Interface\\Buttons\\WHITE8x8",
        edgeFile = "Interface\\Buttons\\WHITE8x8",
        edgeSize = 1,
    })
    frame:SetBackdropColor(   bg[1],  bg[2],  bg[3],  aBg  or 1)
    frame:SetBackdropBorderColor(bdr[1], bdr[2], bdr[3], aBdr or 1)
end

local function SetBorder(frame, r, g, b, a)
    frame:SetBackdropBorderColor(r, g, b, a or 1)
end

-- ============================================================
-- DB helpers – thin wrappers so we don't repeat GetDB() calls
-- ============================================================
local function GetDB()
    return UnitFrames:GetDB()
end

local function GetIndicators(frameKey)
    return UnitFrames:AWGetIndicators(frameKey)
end

-- Ensure the indicators array is writable (initialise if needed).
local function EnsureIndicatorsWritable(frameKey)
    local db = GetDB()
    if frameKey == "partyMember" then
        db.auras        = db.auras or {}
        db.auras.scopes = db.auras.scopes or {}
        db.auras.scopes.party             = db.auras.scopes.party or {}
        db.auras.scopes.party.indicators  = db.auras.scopes.party.indicators or {}
        return db.auras.scopes.party.indicators
    elseif frameKey == "raidMember" then
        db.auras        = db.auras or {}
        db.auras.scopes = db.auras.scopes or {}
        db.auras.scopes.raid             = db.auras.scopes.raid or {}
        db.auras.scopes.raid.indicators  = db.auras.scopes.raid.indicators or {}
        return db.auras.scopes.raid.indicators
    elseif frameKey == "tankMember" then
        db.auras        = db.auras or {}
        db.auras.scopes = db.auras.scopes or {}
        db.auras.scopes.tank             = db.auras.scopes.tank or {}
        db.auras.scopes.tank.indicators  = db.auras.scopes.tank.indicators or {}
        return db.auras.scopes.tank.indicators
    else
        db.units          = db.units or {}
        db.units[frameKey] = db.units[frameKey] or {}
        db.units[frameKey].indicators = db.units[frameKey].indicators or {}
        return db.units[frameKey].indicators
    end
end

-- ============================================================
-- Layer helpers — support multiple visual layers per slot
-- ============================================================

--- Returns the config table for the currently-edited layer.
--- selectedLayer==1 → primary (the slot cfg itself)
--- selectedLayer>1  → extraLayers[n-1]
local function GetLayerCfg()
    local inds     = GetIndicators(activeFrameKey)
    local slotCfg  = inds[selectedSlot]
    if not slotCfg then return nil end
    if selectedLayer == 1 then return slotCfg end
    local extra = slotCfg.extraLayers
    return extra and extra[selectedLayer - 1] or nil
end

--- Returns the writable layer cfg, initialising extraLayers as needed.
local function EnsureLayerWritable()
    local i2 = EnsureIndicatorsWritable(activeFrameKey)
    if selectedLayer == 1 then return i2[selectedSlot] end
    i2[selectedSlot].extraLayers = i2[selectedSlot].extraLayers or {}
    if not i2[selectedSlot].extraLayers[selectedLayer - 1] then
        i2[selectedSlot].extraLayers[selectedLayer - 1] = { type = "border" }
    end
    return i2[selectedSlot].extraLayers[selectedLayer - 1]
end

--- Refresh the preview side panel to show all layers of the current slot.
RefreshPreview = function()
    if not previewHost then return end
    UnitFrames:AWPreviewClear(previewHost)
    local inds    = GetIndicators(activeFrameKey)
    local slotCfg = inds[selectedSlot]
    if not slotCfg then return end
    -- Primary layer at index 1
    UnitFrames:AWPreviewRender(previewHost, 1, slotCfg)
    -- Extra layers at their engine indices
    if slotCfg.extraLayers then
        for lj, extraCfg in ipairs(slotCfg.extraLayers) do
            UnitFrames:AWPreviewRender(previewHost, 6 * lj + 1, extraCfg)
        end
    end
end

-- ============================================================
-- Slot assignment helpers
-- ============================================================

--- Build a new indicator config table from a catalogue/generic entry.
local function EntryToIndicatorCfg(entry)
    if entry.source then
        -- Generic filter entry
        return {
            enabled       = true,
            type          = "icons",
            source        = entry.source,
            onlyMine      = false,
            anchor        = "TOPLEFT",
            relativeAnchor= "TOPLEFT",
            offsetX       = 0,
            offsetY       = 0,
            iconSize      = 18,
            spacing       = 2,
            maxCount      = 5,
            growDirection = "RIGHT",
        }
    else
        -- Catalog spell entry
        return {
            enabled        = true,
            type           = "icons",
            source         = "spell",
            spellIds       = entry.spellIds and { unpack(entry.spellIds) } or {},
            onlyMine       = true,
            anchor         = "TOPLEFT",
            relativeAnchor = "TOPLEFT",
            offsetX        = 0,
            offsetY        = 0,
            iconSize       = 18,
            spacing        = 2,
            maxCount       = 5,
            growDirection  = "RIGHT",
        }
    end
end

--- Human-readable summary for an indicator config.
local function IndicatorLabel(cfg)
    if not cfg then return "Empty" end
    local s = cfg.source or "?"
    if s == "spell" then
        -- Resolve first spell ID from spellIds array, or legacy spellId scalar.
        local spellIds = cfg.spellIds
        local sid = (type(spellIds) == "table" and spellIds[1]) or cfg.spellId
        if sid and sid > 0 then
            local name
            if _G.C_Spell and _G.C_Spell.GetSpellName then
                name = _G.C_Spell.GetSpellName(sid)
            elseif _G.GetSpellInfo then
                name = (_G.GetSpellInfo(sid))
            end
            if name then
                local extra = type(spellIds) == "table" and #spellIds > 1
                return name .. (extra and (" +" .. (#spellIds - 1)) or "")
            end
            return "Spell " .. tostring(sid)
        end
        return "Spell (unset)"
    elseif s == "group" then
        local db = GetDB()
        local grp = db.spellGroups and cfg.groupKey and db.spellGroups[cfg.groupKey]
        return (grp and grp.label) or ("Group " .. (cfg.groupKey or "?"))
    else
        local labels = {
            HELPFUL="Helpful",HARMFUL="Harmful",DISPELLABLE="Dispellable",
            DISPELLABLE_OR_BOSS="Dispel/Boss",ALL="All Auras",
        }
        return labels[s] or s
    end
end

--- Multi-line summary for the slot card — shows each spell name on its own line
--- with "X more" if there are too many to fit. Non-spell sources use IndicatorLabel.
local MAX_CARD_SPELL_LINES = 3
local function BuildSlotSummary(cfg)
    if not cfg then return "" end
    if cfg.source ~= "spell" then return IndicatorLabel(cfg) end
    local spellIds = cfg.spellIds or {}
    -- backward compat
    if #spellIds == 0 and cfg.spellId and cfg.spellId > 0 then
        spellIds = { cfg.spellId }
    end
    if #spellIds == 0 then return "Spell (unset)" end
    local lines = {}
    for i = 1, math.min(#spellIds, MAX_CARD_SPELL_LINES) do
        local sid  = spellIds[i]
        local name
        if _G.C_Spell and _G.C_Spell.GetSpellName then
            name = _G.C_Spell.GetSpellName(sid)
        elseif _G.GetSpellInfo then
            name = (_G.GetSpellInfo(sid))
        end
        lines[#lines + 1] = name or ("ID: " .. tostring(sid))
    end
    local overflow = #spellIds - MAX_CARD_SPELL_LINES
    if overflow > 0 then
        lines[#lines + 1] = "+" .. overflow .. " more"
    end
    return table.concat(lines, "\n")
end

--- Icon texture for an indicator config.
local function IndicatorIcon(cfg)
    if not cfg then return nil end
    if cfg.source == "spell" then
        local spellIds = cfg.spellIds
        local sid = (type(spellIds) == "table" and spellIds[1]) or cfg.spellId
        if sid and sid > 0 then
            if _G.C_Spell and _G.C_Spell.GetSpellTexture then
                return _G.C_Spell.GetSpellTexture(sid)
            elseif _G.GetSpellTexture then
                return _G.GetSpellTexture(sid)
            end
        end
    end
    -- Generic icon placeholders
    local icons = {
        HELPFUL=135987, HARMFUL=136116, DISPELLABLE=135939,
        DISPELLABLE_OR_BOSS=135939, ALL=134400,
        group=134400,
    }
    return icons[cfg.source or "ALL"]
end

-- ============================================================
-- Forward declarations
-- ============================================================
local RefreshCatalog
local RefreshSlots
local RefreshDetailPanel
local SelectSlot

-- ============================================================
-- Held-entry cursor indicator
-- A small floating tile that follows the mouse when an entry
-- is "held", giving the user clear drag-intent feedback.
-- ============================================================
local cursor
local function EnsureCursor()
    if cursor then return cursor end
    cursor = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    cursor:SetSize(38, 38)
    cursor:SetFrameStrata("TOOLTIP")
    cursor:SetFrameLevel(900)
    cursor:EnableMouse(false)
    Backdrop(cursor, C.card, C.gold, 1, 1)

    cursor.icon = cursor:CreateTexture(nil, "ARTWORK")
    cursor.icon:SetPoint("TOPLEFT",     cursor, "TOPLEFT",     2, -2)
    cursor.icon:SetPoint("BOTTOMRIGHT", cursor, "BOTTOMRIGHT", -2, 2)
    cursor.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    cursor:SetScript("OnUpdate", function(self)
        local mx, my = GetCursorPosition()
        local scale  = UIParent:GetEffectiveScale()
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT",
            (mx / scale) + 8, (my / scale) + 8)
    end)
    cursor:Hide()
    return cursor
end

local function ShowCursor(entry)
    local c = EnsureCursor()
    local icon = entry and (entry.icon or UnitFrames:AWGetEntryIcon(entry))
    c.icon:SetTexture(icon)
    c:Show()
end

local function HideCursor()
    EnsureCursor():Hide()
end

-- ============================================================
-- Held-entry management
-- ============================================================
local function SetHeld(entry)
    heldEntry = entry
    if entry then
        ShowCursor(entry)
    else
        HideCursor()
    end
    RefreshCatalog()
    RefreshSlots()
end

-- ============================================================
-- Catalogue rebuild
-- ============================================================
local function ReleaseTilePool()
    for _, t in ipairs(tilePool) do
        t:Hide()
        t:ClearAllPoints()
    end
    wipe(tilePool)
    for _, lbl in ipairs(sectionLabels) do
        lbl:Hide()
    end
    wipe(sectionLabels)
end

local TILE_SIZE  = 52
local TILE_PAD   = 6
local TILE_COLS  = 3

local function MakeTile(parent, entry, isFilter)
    local tile = CreateFrame("Button", nil, parent, "BackdropTemplate")
    tile:SetSize(TILE_SIZE, TILE_SIZE + 22)
    Backdrop(tile, C.card, C.border, 1, 1)
    tile:EnableMouse(true)

    -- Spell icon
    local tex = tile:CreateTexture(nil, "ARTWORK")
    tex:SetPoint("TOPLEFT",  tile, "TOPLEFT",  2, -2)
    tex:SetSize(TILE_SIZE - 4, TILE_SIZE - 4)
    tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    tile.iconTex = tex

    -- Label below icon (two-line, wrap allowed)
    local lbl = tile:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(Font(10))
    lbl:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    lbl:SetPoint("TOPLEFT",  tile, "TOPLEFT",  2, -(TILE_SIZE - 2))
    lbl:SetPoint("TOPRIGHT", tile, "TOPRIGHT", -2, -(TILE_SIZE - 2))
    lbl:SetJustifyH("CENTER")
    lbl:SetWordWrap(true)
    lbl:SetNonSpaceWrap(false)
    lbl:SetHeight(20)
    tile.lbl = lbl

    -- Colour accent bar along the left edge
    local accent = tile:CreateTexture(nil, "BACKGROUND")
    accent:SetWidth(2)
    accent:SetPoint("TOPLEFT",    tile, "TOPLEFT",    0, 0)
    accent:SetPoint("BOTTOMLEFT", tile, "BOTTOMLEFT", 0, 0)
    tile.accent = accent

    tile.entry    = entry
    tile.isFilter = isFilter

    -- Icon
    local iconTex
    if isFilter then
        iconTex = entry.icon
    else
        iconTex = UnitFrames:AWGetEntryIcon(entry)
    end
    tex:SetTexture(iconTex)

    -- Label text
    lbl:SetText(entry.display)

    -- Accent colour
    local ec = entry.color or { 0.5, 0.5, 0.5 }
    accent:SetColorTexture(ec[1], ec[2], ec[3], 0.85)

    -- Tooltip
    tile:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetText(entry.display, 1, 1, 1)
        if entry.spellIds and entry.spellIds[1] then
            GameTooltip:SetSpellByID(entry.spellIds[1])
        elseif entry.source then
            GameTooltip:AddLine("Generic filter: " .. entry.source, 0.7, 0.7, 0.7)
        end
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("Click or drag to a slot to assign.", 0.6, 0.6, 0.6, true)
        GameTooltip:Show()
        self:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
    end)
    tile:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        local isHeld = heldEntry == self.entry
        self:SetBackdropBorderColor(
            isHeld and C.gold[1]   or C.border[1],
            isHeld and C.gold[2]   or C.border[2],
            isHeld and C.gold[3]   or C.border[3], 1)
    end)

    -- True click-drag: OnMouseDown picks up the entry + installs a global
    -- OnMouseUp catcher. Releasing directly over a slot card assigns immediately.
    -- Releasing elsewhere keeps the entry "held" (click-a-slot-to-assign workflow).
    tile:SetScript("OnMouseDown", function(self, button)
        if button ~= "LeftButton" then return end
        if heldEntry == self.entry then
            -- Toggle off on second press
            SetHeld(nil)
            if activeDragCatcher then
                activeDragCatcher:Hide()
                activeDragCatcher:SetParent(nil)
                activeDragCatcher = nil
            end
            return
        end
        SetHeld(self.entry)
        -- Clean up any stale catcher
        if activeDragCatcher then
            activeDragCatcher:Hide()
            activeDragCatcher:SetParent(nil)
        end
        activeDragCatcher = CreateFrame("Frame", nil, UIParent)
        activeDragCatcher:SetAllPoints(UIParent)
        activeDragCatcher:SetFrameStrata("TOOLTIP")
        activeDragCatcher:SetFrameLevel(840)
        activeDragCatcher:EnableMouse(true)
        activeDragCatcher:SetScript("OnMouseUp", function(_, btn)
            if btn ~= "LeftButton" then return end
            local catcher = activeDragCatcher
            activeDragCatcher = nil
            if catcher then catcher:Hide(); catcher:SetParent(nil) end
            -- Check which slot card the cursor is over
            local held  = heldEntry
            if not held then return end
            for si = 1, 6 do
                local card = slotCards[si]
                if card and card:IsVisible() and card:IsMouseOver() then
                    local inds    = EnsureIndicatorsWritable(activeFrameKey)
                    local existing = inds[si]
                    if existing and existing.source == "spell"
                        and held.spellIds and not held.source then
                        existing.spellIds = existing.spellIds or {}
                        if existing.spellId and existing.spellId > 0 then
                            local ok = false
                            for _, v in ipairs(existing.spellIds) do
                                if v == existing.spellId then ok = true; break end
                            end
                            if not ok then
                                table.insert(existing.spellIds, existing.spellId)
                            end
                            existing.spellId = nil
                        end
                        for _, sid in ipairs(held.spellIds) do
                            local ok = false
                            for _, v in ipairs(existing.spellIds) do
                                if v == sid then ok = true; break end
                            end
                            if not ok then
                                table.insert(existing.spellIds, sid)
                            end
                        end
                        SetHeld(nil)
                        SelectSlot(si)
                    else
                        inds[si] = EntryToIndicatorCfg(held)
                        SetHeld(nil)
                        SelectSlot(si)
                    end
                    return
                end
            end
            -- Not over a slot → keep held for click-to-assign
        end)
        activeDragCatcher:Show()
    end)

    tile:Hide()
    tilePool[#tilePool + 1] = tile
    return tile
end

RefreshCatalog = function()
    if not catalogChild then return end

    ReleaseTilePool()

    -- Recompute tile size to fill the available catalogue width dynamically
    local innerW = catalogChild:GetWidth()
    if innerW > 0 then
        TILE_SIZE = math_floor((innerW - PAD * 2 - TILE_PAD * (TILE_COLS - 1)) / TILE_COLS)
        TILE_SIZE = math.max(40, TILE_SIZE)   -- never smaller than 40px
    end

    local _, specKey = UnitFrames:AWGetPlayerCatalog()
    local specName  = (specKey and UnitFrames:AWGetSpecName(specKey)) or "Unknown Spec"
    local specCat   = UnitFrames:AWGetSpecCatalog(specKey or "")
    local generic   = UnitFrames:AWGetGenericEntries()

    -- Collect all tiles to lay out
    local tiles = {}

    -- Section: spec auras
    local function AddSection(label, entries, isFilter)
        tiles[#tiles + 1] = { isLabel = true, text = label }
        for _, entry in ipairs(entries) do
            tiles[#tiles + 1] = { entry = entry, isFilter = isFilter }
        end
    end

    AddSection(specName, specCat, false)
    AddSection("Generic Filters", generic, true)

    -- Spell Groups section
    local db       = GetDB()
    local sgEntries = {}
    if db.spellGroups then
        for key, grp in pairs(db.spellGroups) do
            if type(grp) == "table" and grp.spellIds and grp.spellIds ~= "" then
                sgEntries[#sgEntries + 1] = {
                    key     = key,
                    display = grp.label or ("Group " .. (key:sub(2) or "?")),
                    source  = "group",
                    groupKey= key,
                    icon    = 134400,
                    color   = { 0.62, 0.47, 0.85 },
                }
            end
        end
    end
    if #sgEntries > 0 then
        AddSection("Spell Groups", sgEntries, true)
    end

    -- Layout tiles into the child
    local x, y    = 0, -PAD
    local maxW    = (TILE_SIZE + TILE_PAD) * TILE_COLS - TILE_PAD
    local totalH  = PAD

    for _, item in ipairs(tiles) do
        if item.isLabel then
            -- section header label
            x = 0
            local lbl = catalogChild:CreateFontString(nil, "OVERLAY")
            lbl:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
            lbl:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
            lbl:SetText(item.text)
            lbl:SetPoint("TOPLEFT", catalogChild, "TOPLEFT", PAD, y)
            lbl:SetWidth(maxW)
            lbl:Show()
            sectionLabels[#sectionLabels + 1] = lbl
            y = y - 16
            totalH = totalH + 16
        else
            local tile = MakeTile(catalogChild, item.entry, item.isFilter)
            tile:ClearAllPoints()
            tile:SetPoint("TOPLEFT", catalogChild, "TOPLEFT", PAD + x, y)

            local isHeld = heldEntry == item.entry
            tile:SetBackdropBorderColor(
                isHeld and C.gold[1] or C.border[1],
                isHeld and C.gold[2] or C.border[2],
                isHeld and C.gold[3] or C.border[3], 1)
            if isHeld then
                tile:SetBackdropColor(C.cardHeld[1], C.cardHeld[2], C.cardHeld[3], 1)
            else
                tile:SetBackdropColor(C.card[1], C.card[2], C.card[3], 1)
            end

            tile:Show()

            x = x + TILE_SIZE + TILE_PAD
            if x + TILE_SIZE > maxW + TILE_PAD then
                x = 0
                y = y - (TILE_SIZE + 22 + TILE_PAD)
                totalH = totalH + TILE_SIZE + 22 + TILE_PAD
            end
        end
    end
    -- final row
    if x > 0 then
        y = y - (TILE_SIZE + 22 + TILE_PAD)
        totalH = totalH + TILE_SIZE + 22 + TILE_PAD
    end

    catalogChild:SetHeight(math.max(1, -y + PAD))
end

-- ============================================================
-- Slot cards rebuild
-- ============================================================
local SLOT_W  = 170
local SLOT_H  = 100
local SLOT_PAD= 8
local SLOT_COLS = 3

local function BuildSlotCard(parent, slotIdx)
    local card = CreateFrame("Button", nil, parent, "BackdropTemplate")
    card:SetSize(SLOT_W, SLOT_H)
    Backdrop(card, C.card, C.border, 1, 1)
    card:EnableMouse(true)

    -- Index badge (top-left corner)
    local badge = card:CreateFontString(nil, "OVERLAY")
    badge:SetFont(Font(9, "OUTLINE"))
    badge:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    badge:SetText(tostring(slotIdx))
    badge:SetPoint("TOPLEFT", card, "TOPLEFT", 5, -4)
    card.badge = badge

    -- Icon container (center-left) — 2×2 grid shows up to 4 spell icons
    local iconFrame = CreateFrame("Frame", nil, card, "BackdropTemplate")
    iconFrame:SetSize(46, 46)
    iconFrame:SetPoint("LEFT", card, "LEFT", 8, 0)
    Backdrop(iconFrame, C.panel, C.border, 1, 1)
    card.iconFrame = iconFrame

    card.iconSlots = {}
    for gridIdx = 1, 4 do
        local gc = (gridIdx - 1) % 2
        local gr = math_floor((gridIdx - 1) / 2)
        local sf = CreateFrame("Frame", nil, iconFrame)
        sf:SetSize(20, 20)
        sf:SetPoint("TOPLEFT", iconFrame, "TOPLEFT", 3 + gc * 22, -3 - gr * 22)
        local st = sf:CreateTexture(nil, "ARTWORK")
        st:SetPoint("TOPLEFT",     sf, "TOPLEFT",     1, -1)
        st:SetPoint("BOTTOMRIGHT", sf, "BOTTOMRIGHT", -1,  1)
        st:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        sf.tex = st
        card.iconSlots[gridIdx] = sf
        sf:Hide()
    end
    -- back-compat for any residual direct access
    card.iconTex = card.iconSlots[1] and card.iconSlots[1].tex

    -- Source label
    local lblMain = card:CreateFontString(nil, "OVERLAY")
    lblMain:SetFont(Font(LABEL_FONT_SIZE))
    lblMain:SetTextColor(C.text[1], C.text[2], C.text[3])
    lblMain:SetPoint("TOPLEFT",  card, "TOPLEFT",  60, -22)
    lblMain:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -22)
    lblMain:SetJustifyH("LEFT")
    lblMain:SetWordWrap(true)
    card.lblMain = lblMain

    -- User-defined slot label (shown in gold above the spell summary)
    local lblSlotName = card:CreateFontString(nil, "OVERLAY")
    lblSlotName:SetFont(Font(9, "OUTLINE"))
    lblSlotName:SetTextColor(C.gold[1], C.gold[2], C.gold[3])
    lblSlotName:SetPoint("TOPLEFT",  card, "TOPLEFT",  60, -8)
    lblSlotName:SetPoint("TOPRIGHT", card, "TOPRIGHT", -8, -8)
    lblSlotName:SetJustifyH("LEFT")
    lblSlotName:Hide()
    card.lblSlotName = lblSlotName

    -- Type badge pill
    local typeBadge = card:CreateFontString(nil, "OVERLAY")
    typeBadge:SetFont(Font(8, "OUTLINE"))
    typeBadge:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    typeBadge:SetPoint("BOTTOMLEFT", card, "BOTTOMLEFT", 60, 10)
    card.typeBadge = typeBadge

    -- "Empty" placeholder text
    local emptyText = card:CreateFontString(nil, "OVERLAY")
    emptyText:SetFont(Font(SECTION_FONT_SIZE))
    emptyText:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    emptyText:SetAllPoints(card)
    emptyText:SetJustifyH("CENTER")
    emptyText:SetJustifyV("MIDDLE")
    emptyText:SetText("+  Add Indicator")
    card.emptyText = emptyText

    -- Delete button (top-right × )
    local del = CreateFrame("Button", nil, card)
    del:SetSize(16, 16)
    del:SetPoint("TOPRIGHT", card, "TOPRIGHT", -3, -3)
    del:SetNormalFontObject(_G.GameFontNormalSmall)

    local delTex = del:CreateFontString(nil, "OVERLAY")
    delTex:SetFont(SymbolFont(12))
    delTex:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    delTex:SetAllPoints(del)
    delTex:SetJustifyH("CENTER")
    delTex:SetText("×")
    del:SetScript("OnEnter", function() delTex:SetTextColor(C.danger[1], C.danger[2], C.danger[3]) end)
    del:SetScript("OnLeave", function() delTex:SetTextColor(C.muted[1],  C.muted[2],  C.muted[3])  end)
    del:SetScript("OnClick", function()
        local inds = EnsureIndicatorsWritable(activeFrameKey)
        inds[slotIdx] = nil
        if selectedSlot == slotIdx then selectedSlot = 0 end
        RefreshSlots()
        RefreshDetailPanel()
    end)
    card.delBtn = del

    -- Anchor badge (shows current anchor point abbreviation)
    local anchorBadge = card:CreateFontString(nil, "OVERLAY")
    anchorBadge:SetFont(Font(8, "OUTLINE"))
    anchorBadge:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
    anchorBadge:SetPoint("BOTTOMRIGHT", card, "BOTTOMRIGHT", -8, 8)
    card.anchorBadge = anchorBadge

    card:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        if heldEntry then
            GameTooltip:SetText("Slot " .. slotIdx, C.gold[1], C.gold[2], C.gold[3])
            GameTooltip:AddLine("Release here to assign the held indicator.", 0.8, 0.8, 0.8, true)
            self:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 1)
        else
            GameTooltip:SetText("Slot " .. slotIdx, 1, 1, 1)
            GameTooltip:AddLine("Click to select and configure this indicator slot.", 0.8, 0.8, 0.8, true)
            GameTooltip:AddLine("Drag an entry from the catalogue to assign it.", 0.7, 0.7, 0.7, true)
            self:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.8)
        end
        GameTooltip:Show()
    end)
    card:SetScript("OnLeave", function(self)
        GameTooltip:Hide()
        local isSel = (selectedSlot == slotIdx)
        self:SetBackdropBorderColor(
            isSel and C.teal[1] or C.border[1],
            isSel and C.teal[2] or C.border[2],
            isSel and C.teal[3] or C.border[3], isSel and 1 or 0.7)
    end)
    card:SetScript("OnClick", function(self)
        if heldEntry then
            local inds = EnsureIndicatorsWritable(activeFrameKey)
            local existing = inds[slotIdx]

            -- If the slot already tracks spells AND the dropped entry is also a
            -- spell catalog entry, APPEND its IDs instead of replacing the slot.
            local held = heldEntry  -- capture before SetHeld clears it
            if existing and existing.source == "spell"
                and held.spellIds and not held.source then
                -- Merge: add any spell IDs not already present
                existing.spellIds = existing.spellIds or {}
                -- migrate old scalar if needed
                if existing.spellId and existing.spellId > 0 then
                    local found = false
                    for _, v in ipairs(existing.spellIds) do
                        if v == existing.spellId then found = true; break end
                    end
                    if not found then
                        table.insert(existing.spellIds, existing.spellId)
                    end
                    existing.spellId = nil
                end
                for _, sid in ipairs(held.spellIds) do
                    local found = false
                    for _, v in ipairs(existing.spellIds) do
                        if v == sid then found = true; break end
                    end
                    if not found then
                        table.insert(existing.spellIds, sid)
                    end
                end
                SetHeld(nil)
                SelectSlot(slotIdx)
            else
                -- Different type or empty slot — replace entirely
                inds[slotIdx] = EntryToIndicatorCfg(held)
                SetHeld(nil)
                SelectSlot(slotIdx)
            end
        else
            SelectSlot(slotIdx)
        end
    end)

    slotCards[slotIdx] = card
    return card
end

RefreshSlots = function()
    local inds = GetIndicators(activeFrameKey)
    for i = 1, 6 do
        local card = slotCards[i]
        if not card then break end
        local cfg = inds[i]
        local isSel = (selectedSlot == i)
        local hasCfg = cfg ~= nil

        -- Border colour
        if heldEntry then
            card:SetBackdropBorderColor(C.gold[1], C.gold[2], C.gold[3], 0.6)
        elseif isSel then
            card:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
        else
            card:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 0.7)
        end

        -- Background
        if isSel then
            card:SetBackdropColor(C.cardSel[1], C.cardSel[2], C.cardSel[3], 1)
        else
            card:SetBackdropColor(C.card[1], C.card[2], C.card[3], 1)
        end

        if hasCfg then
            card.emptyText:Hide()
            card.delBtn:Show()
            card.iconFrame:Show()

            -- Populate icon grid from spell ID list (up to 4)
            local spellIds = (cfg.source == "spell") and
                (cfg.spellIds or (cfg.spellId and {cfg.spellId}) or {}) or {}
            local iconCount = math.max(1, #spellIds)
            for gi = 1, 4 do
                local sf = card.iconSlots[gi]
                if sf then
                    if gi <= iconCount then
                        local tex
                        if spellIds[gi] then
                            local sid = spellIds[gi]
                            if _G.C_Spell and _G.C_Spell.GetSpellTexture then
                                tex = _G.C_Spell.GetSpellTexture(sid)
                            elseif _G.GetSpellTexture then
                                tex = _G.GetSpellTexture(sid)
                            end
                        else
                            tex = IndicatorIcon(cfg)
                        end
                        sf.tex:SetTexture(tex)
                        sf:Show()
                    else
                        sf:Hide()
                    end
                end
            end

            card.lblMain:SetText(BuildSlotSummary(cfg))
            local typeLabels = {
                icons   = "Icon Cluster",
                border  = "Border Highlight",
                overlay = "Color Overlay",
            }
            card.typeBadge:SetText(typeLabels[cfg.type or "icons"] or cfg.type or "")
            card.anchorBadge:SetText(ANCHOR_SHORT[cfg.anchor or "TOPLEFT"] or "?")
            -- Slot name label
            if cfg.slotName and cfg.slotName ~= "" then
                card.lblSlotName:SetText(cfg.slotName)
                card.lblSlotName:Show()
                card.lblMain:SetPoint("TOPLEFT",  card, "TOPLEFT",  60, -20)
            else
                card.lblSlotName:Hide()
                card.lblMain:SetPoint("TOPLEFT",  card, "TOPLEFT",  60, -22)
            end
        else
            card.emptyText:Show()
            card.delBtn:Hide()
            card.iconFrame:Hide()
            card.lblMain:SetText("")
            card.lblSlotName:Hide()
            card.lblMain:SetPoint("TOPLEFT", card, "TOPLEFT", 60, -22)
            card.typeBadge:SetText("")
            card.anchorBadge:SetText("")
        end
    end
end

SelectSlot = function(idx)
    if selectedSlot == idx then
        selectedSlot = 0
    else
        selectedSlot = idx
    end
    selectedLayer = 1
    RefreshSlots()
    RefreshDetailPanel()
end

-- ============================================================
-- Detail panel
-- ============================================================

local detailWidgets = {}   -- child frames recycled on refresh

local function ClearDetail()
    for _, w in ipairs(detailWidgets) do
        if w and w.Hide then w:Hide() end
    end
    wipe(detailWidgets)
end

local function PushDetail(w)
    detailWidgets[#detailWidgets + 1] = w
    return w
end

-- Thin factory helpers used exclusively inside BuildDetail
local function DetailLabel(parent, text, x, y)
    local fs = PushDetail(parent:CreateFontString(nil, "OVERLAY"))
    fs:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
    fs:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    fs:SetText(text)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    return fs
end

local function DetailDropdown(parent, items, current, x, y, w, onChange)
    -- Items: { key, label } array
    local btn = PushDetail(CreateFrame("Button", nil, parent, "BackdropTemplate"))
    btn:SetSize(w or 120, 20)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    Backdrop(btn, C.panel, C.border, 1, 1)
    btn:EnableMouse(true)

    local lbl = btn:CreateFontString(nil, "OVERLAY")
    lbl:SetFont(Font(LABEL_FONT_SIZE))
    lbl:SetTextColor(C.text[1], C.text[2], C.text[3])
    lbl:SetAllPoints(btn)
    lbl:SetJustifyH("CENTER")
    btn.lbl = lbl

    -- Set initial label
    for _, item in ipairs(items) do
        if item.key == current then lbl:SetText(item.label); break end
    end
    if lbl:GetText() == "" then lbl:SetText(current or "?") end

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    btn:SetScript("OnClick", function(self)
        -- Build a small popup menu
        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetFrameLevel(800)
        Backdrop(menu, C.panel, C.border, 1, 1)
        local itemH  = 18
        menu:SetSize(w or 120, #items * itemH + 4)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)

        for idx2, item in ipairs(items) do
            local row = CreateFrame("Button", nil, menu, "BackdropTemplate")
            row:SetSize((w or 120) - 2, itemH)
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 1, -(idx2 - 1) * itemH - 2)
            Backdrop(row, { 0, 0, 0 }, { 0, 0, 0 }, 0, 0)
            local rowLbl = row:CreateFontString(nil, "OVERLAY")
            rowLbl:SetFont(Font(LABEL_FONT_SIZE))
            rowLbl:SetTextColor(C.text[1], C.text[2], C.text[3])
            rowLbl:SetAllPoints(row)
            rowLbl:SetJustifyH("CENTER")
            rowLbl:SetText(item.label)
            row:SetScript("OnEnter", function()
                row:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.25)
            end)
            row:SetScript("OnLeave", function()
                row:SetBackdropColor(0, 0, 0, 0)
            end)
            row:SetScript("OnClick", function()
                lbl:SetText(item.label)
                menu:Hide()
                menu:SetParent(nil)
                if onChange then onChange(item.key) end
            end)
        end

        -- auto-close on click outside
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("TOOLTIP")
        catcher:SetFrameLevel(799)
        catcher:SetScript("OnClick", function()
            menu:Hide()
            catcher:Hide()
            catcher:SetParent(nil)
        end)
        catcher:Show()

        menu:SetScript("OnHide", function()
            catcher:Hide()
            catcher:SetParent(nil)
        end)
        menu:Show()
    end)

    return btn
end

local function DetailCheckbox(parent, label, current, x, y, onChange)
    local btn = PushDetail(CreateFrame("Frame", nil, parent, "BackdropTemplate"))
    btn:SetSize(16, 16)
    btn:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    Backdrop(btn, C.panel, C.border, 1, 1)
    btn:EnableMouse(true)

    local checked = (current == true or current == 1)

    -- Teal square indicator (matches TwichUI design language)
    local tick = btn:CreateTexture(nil, "OVERLAY")
    tick:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 1)
    tick:SetPoint("CENTER", btn, "CENTER", 0, 0)
    tick:SetSize(8, 8)
    tick:SetShown(checked)
    btn._checked = checked
    btn.tick = tick

    local lfs = PushDetail(parent:CreateFontString(nil, "OVERLAY"))
    lfs:SetFont(Font(LABEL_FONT_SIZE))
    lfs:SetTextColor(C.text[1], C.text[2], C.text[3])
    lfs:SetText(label)
    lfs:SetPoint("LEFT", btn, "RIGHT", 5, 0)

    btn:SetScript("OnMouseUp", function(self, button)
        if button ~= "LeftButton" then return end
        self._checked = not self._checked
        tick:SetShown(self._checked)
        if onChange then onChange(self._checked) end
        DeferredFlush()
    end)
    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)

    return btn
end

local function DetailSlider(parent, label, value, minV, maxV, step, x, y, w, onChange)
    local W = w or 120
    local STEP = step or 1

    if label and label ~= "" then
        local lfs = PushDetail(parent:CreateFontString(nil, "OVERLAY"))
        lfs:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
        lfs:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        lfs:SetText(label)
        lfs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    end

    -- Slider bar (leaves 34px on the right for the EditBox)
    local s = PushDetail(CreateFrame("Slider", nil, parent, "BackdropTemplate"))
    s:SetSize(W - 34, 14)
    s:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 16)
    s:SetMinMaxValues(minV, maxV)
    s:SetValueStep(STEP)
    s:SetValue(value)
    s:SetObeyStepOnDrag(true)
    Backdrop(s, C.panel, C.border, 1, 1)

    local thumb = s:CreateTexture(nil, "ARTWORK")
    thumb:SetSize(6, 12)
    thumb:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 1)
    s:SetThumbTexture(thumb)

    -- Numeric EditBox (right of slider, always editable)
    local eb = PushDetail(CreateFrame("EditBox", nil, parent, "BackdropTemplate"))
    eb:SetSize(30, 14)
    eb:SetPoint("TOPLEFT", parent, "TOPLEFT", x + W - 30, y - 16)
    Backdrop(eb, C.panel, C.border, 1, 1)
    eb:SetFont(Font(10))
    eb:SetAutoFocus(false)
    eb:SetNumeric(false)          -- allow floats via GetText
    eb:SetMaxLetters(8)
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(2, 2, 0, 0)
    eb:SetText(FormatSliderVal(value, STEP))

    local function CommitEdit()
        local v = tonumber(eb:GetText())
        if v then
            v = math.max(minV, math.min(maxV, v))
            -- Snap to step
            if STEP >= 0.001 then
                v = math.floor(v / STEP + 0.5) * STEP
            end
            s:SetValue(v)
        end
        eb:SetText(FormatSliderVal(s:GetValue(), STEP))
        eb:ClearFocus()
    end
    eb:SetScript("OnEnterPressed", function() CommitEdit() end)
    eb:SetScript("OnEscapePressed", function(self2)
        self2:SetText(FormatSliderVal(s:GetValue(), STEP))
        self2:ClearFocus()
    end)
    eb:SetScript("OnEditFocusGained", function(self2)
        self2:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
        self2:HighlightText()
    end)
    eb:SetScript("OnEditFocusLost", function(self2)
        self2:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    AddTooltip(eb, "Manual Entry", "Click to type a value, then press Enter to apply.")

    s:SetScript("OnValueChanged", function(self2, v)
        eb:SetText(FormatSliderVal(v, STEP))
        if onChange then onChange(v) end
        DeferredFlush()
    end)

    return s
end

-- 3×3 anchor point grid
local function DetailAnchorGrid(parent, current, x, y, onChange)
    local gridW       = 90
    local gridH       = 58
    local cellW       = gridW / 3
    local cellH       = gridH / 3
    local container   = PushDetail(CreateFrame("Frame", nil, parent, "BackdropTemplate"))
    container:SetSize(gridW, gridH)
    container:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    Backdrop(container, C.panel, C.border, 1, 1)

    local row, col = 0, 0
    for _, key in ipairs(ANCHOR_KEYS) do
        local btn = CreateFrame("Button", nil, container, "BackdropTemplate")
        btn:SetSize(cellW - 2, cellH - 2)
        btn:SetPoint("TOPLEFT", container, "TOPLEFT",
            col * cellW + 1, -row * cellH - 1)

        local isCurrent = current == key
        Backdrop(btn,
            isCurrent and C.teal   or C.card,
            isCurrent and C.teal   or C.border,
            isCurrent and 0.4 or 1, 1)

        local fs = btn:CreateFontString(nil, "OVERLAY")
        fs:SetFont(Font(8))
        fs:SetTextColor(
            isCurrent and 1 or C.muted[1],
            isCurrent and 1 or C.muted[2],
            isCurrent and 1 or C.muted[3])
        fs:SetAllPoints(btn)
        fs:SetJustifyH("CENTER")
        fs:SetJustifyV("MIDDLE")
        fs:SetText(ANCHOR_SHORT[key] or "?")

        btn:SetScript("OnEnter", function(self2)
            if not isCurrent then
                self2:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.7)
            end
        end)
        btn:SetScript("OnLeave", function(self2)
            if not isCurrent then
                self2:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            end
        end)
        btn:SetScript("OnClick", function()
            if onChange then onChange(key) end
        end)

        col = col + 1
        if col >= 3 then col = 0; row = row + 1 end
    end

    return container
end

RefreshDetailPanel = function()
    if not detailPanel then return end
    ClearDetail()

    local inds     = GetIndicators(activeFrameKey)
    local slotCfg  = inds[selectedSlot]  -- full slot cfg (owns source/spells/extraLayers)
    local cfg      = GetLayerCfg()       -- current layer's visual settings

    if selectedSlot == 0 or not slotCfg then
        detailPanel:SetHeight(80)
        local hint = PushDetail(detailPanel:CreateFontString(nil, "OVERLAY"))
        hint:SetFont(Font(LABEL_FONT_SIZE))
        hint:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        hint:SetText("Click an indicator slot above to edit its settings,\nor assign a spell from the catalogue first.")
        hint:SetWidth(detailPanel:GetWidth() - PAD * 2)
        hint:SetJustifyH("CENTER")
        hint:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", PAD, -PAD)
        return
    end

    -- Clamp selectedLayer in case layers were removed externally
    local extraCount  = slotCfg.extraLayers and #slotCfg.extraLayers or 0
    if selectedLayer > 1 + extraCount then selectedLayer = 1 end
    cfg = GetLayerCfg()   -- re-fetch after clamp

    -- Title
    local layerSuffix = selectedLayer > 1 and ("  ·  Layer " .. selectedLayer) or ""
    local titleFS = PushDetail(detailPanel:CreateFontString(nil, "OVERLAY"))
    titleFS:SetFont(Font(LABEL_FONT_SIZE, "OUTLINE"))
    titleFS:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
    titleFS:SetText("Slot " .. selectedSlot .. layerSuffix .. " — " .. IndicatorLabel(slotCfg))
    titleFS:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", PAD, -PAD)
    titleFS:SetWidth(detailPanel:GetWidth() - PAD * 4)

    -- Slot label name input (only on primary layer, visible in slot card header)
    local nameExtraH = 0
    if selectedLayer == 1 then
        nameExtraH = 26
        local nameLbl = PushDetail(detailPanel:CreateFontString(nil, "OVERLAY"))
        nameLbl:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
        nameLbl:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        nameLbl:SetText("LABEL")
        nameLbl:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", PAD, -PAD - 22)

        local nameBox = PushDetail(CreateFrame("EditBox", nil, detailPanel, "BackdropTemplate"))
        nameBox:SetSize(210, 20)
        nameBox:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", PAD + 46, -PAD - 20)
        Backdrop(nameBox, C.card, C.border, 1, 1)
        nameBox:SetFont(Font(LABEL_FONT_SIZE))
        nameBox:SetAutoFocus(false)
        nameBox:SetMaxLetters(40)
        nameBox:SetTextInsets(4, 4, 0, 0)
        nameBox:SetText(slotCfg.slotName or "")
        nameBox:SetScript("OnEditFocusGained", function(self2)
            self2:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
            self2:HighlightText()
        end)
        nameBox:SetScript("OnEditFocusLost", function(self2)
            self2:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            local text = self2:GetText():match("^%s*(.-)%s*$")
            EnsureIndicatorsWritable(activeFrameKey)[selectedSlot].slotName = (text ~= "") and text or nil
            RefreshSlots()
        end)
        nameBox:SetScript("OnEnterPressed", function(self2) self2:ClearFocus() end)
        nameBox:SetScript("OnEscapePressed", function(self2)
            self2:SetText(slotCfg.slotName or "")
            self2:ClearFocus()
        end)
    end

    -- ── Layer tabs ──────────────────────────────────────────────────────────
    local LAYER_TAB_H  = 22
    local LAYER_TAB_W  = 110
    local tabRowY      = -PAD - 20 - 6 - nameExtraH   -- just below title / label
    local tabX         = PAD
    local typeLabels   = { icons = "Icon Cluster", border = "Border", overlay = "Overlay" }

    local function LayerTabLabel(layerIdx)
        local lcfg
        if layerIdx == 1 then lcfg = slotCfg
        elseif slotCfg.extraLayers then lcfg = slotCfg.extraLayers[layerIdx - 1] end
        local t = lcfg and (typeLabels[lcfg.type or "icons"] or "Layer") or "Layer"
        return "L" .. layerIdx .. "  " .. t
    end

    local totalLayers = 1 + extraCount
    for li = 1, totalLayers do
        local isActive = (li == selectedLayer)
        local tab = PushDetail(CreateFrame("Button", nil, detailPanel, "BackdropTemplate"))
        tab:SetSize(LAYER_TAB_W, LAYER_TAB_H)
        tab:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", tabX + (li - 1) * (LAYER_TAB_W + 4), tabRowY)
        Backdrop(tab,
            isActive and { C.teal[1]*0.2, C.teal[2]*0.2, C.teal[3]*0.2 } or C.card,
            isActive and C.teal or C.border, 1, 1)
        local tabLbl = tab:CreateFontString(nil, "OVERLAY")
        tabLbl:SetFont(Font(9))
        tabLbl:SetAllPoints(tab)
        tabLbl:SetJustifyH("CENTER")
        tabLbl:SetJustifyV("MIDDLE")
        tabLbl:SetTextColor(
            isActive and C.teal[1] or C.muted[1],
            isActive and C.teal[2] or C.muted[2],
            isActive and C.teal[3] or C.muted[3])
        tabLbl:SetText(LayerTabLabel(li))
        local capLi = li
        tab:SetScript("OnClick", function()
            selectedLayer = capLi
            RefreshDetailPanel()
        end)
        tab:SetScript("OnEnter", function(self2)
            if not isActive then
                self2:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 0.7)
            end
        end)
        tab:SetScript("OnLeave", function(self2)
            if not isActive then
                self2:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
            end
        end)
    end

    -- "+ Add Layer" button
    local addLayerX = tabX + totalLayers * (LAYER_TAB_W + 4)
    local addLayerBtn = PushDetail(CreateFrame("Button", nil, detailPanel, "BackdropTemplate"))
    addLayerBtn:SetSize(80, LAYER_TAB_H)
    addLayerBtn:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", addLayerX, tabRowY)
    Backdrop(addLayerBtn, C.panel, C.border, 1, 1)
    local addLayerLbl = addLayerBtn:CreateFontString(nil, "OVERLAY")
    addLayerLbl:SetFont(Font(9))
    addLayerLbl:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
    addLayerLbl:SetAllPoints(addLayerBtn)
    addLayerLbl:SetJustifyH("CENTER")
    addLayerLbl:SetJustifyV("MIDDLE")
    addLayerLbl:SetText("+ Layer")
    AddTooltip(addLayerBtn, "Add Layer", "Add an additional indicator layer to this slot.\nEach layer tracks the same aura but shows a different visual type.")
    addLayerBtn:SetScript("OnEnter", function(self2)
        self2:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
    end)
    addLayerBtn:SetScript("OnLeave", function(self2)
        self2:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    addLayerBtn:SetScript("OnClick", function()
        local i2 = EnsureIndicatorsWritable(activeFrameKey)
        i2[selectedSlot].extraLayers = i2[selectedSlot].extraLayers or {}
        table.insert(i2[selectedSlot].extraLayers, {
            type   = "border",
            anchor = slotCfg.anchor or "TOPLEFT",
            borderAnim = "solid",
        })
        selectedLayer = 1 + #i2[selectedSlot].extraLayers
        RefreshDetailPanel()
    end)

    -- "Remove Layer" button (only for non-primary layers)
    if selectedLayer > 1 then
        local remX = addLayerX + 84
        local remBtn = PushDetail(CreateFrame("Button", nil, detailPanel, "BackdropTemplate"))
        remBtn:SetSize(80, LAYER_TAB_H)
        remBtn:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", remX, tabRowY)
        Backdrop(remBtn, C.panel, C.border, 1, 1)
        local remLbl = remBtn:CreateFontString(nil, "OVERLAY")
        remLbl:SetFont(Font(9))
        remLbl:SetTextColor(C.danger[1], C.danger[2], C.danger[3])
        remLbl:SetAllPoints(remBtn)
        remLbl:SetJustifyH("CENTER")
        remLbl:SetJustifyV("MIDDLE")
        remLbl:SetText("Remove")
        remBtn:SetScript("OnEnter", function(self2)
            self2:SetBackdropBorderColor(C.danger[1], C.danger[2], C.danger[3], 1)
        end)
        remBtn:SetScript("OnLeave", function(self2)
            self2:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end)
        remBtn:SetScript("OnClick", function()
            local i2 = EnsureIndicatorsWritable(activeFrameKey)
            table.remove(i2[selectedSlot].extraLayers, selectedLayer - 1)
            selectedLayer = selectedLayer - 1
            if selectedLayer < 1 then selectedLayer = 1 end
            RefreshDetailPanel()
        end)
    end

    -- ── Two-column settings layout ────────────────────────────────────────────
    -- col1 (left):  type + type-specific settings
    -- col2 (right): positioning (anchor / offsets) + chase dot options
    local col1X  = PAD
    local col2X  = PAD + 302
    local row    = -PAD - 20 - LAYER_TAB_H - 10 - nameExtraH   -- below layer tabs row
    local c2y    = row                              -- col2 top (same baseline as col1)

    -- Section banner: dark background + teal left accent + muted label
    local SEP_W  = col2X - col1X - PAD
    local BAND_H = 16
    local function SectionHeader(label, y)
        -- Dark background band
        local bg = PushDetail(detailPanel:CreateTexture(nil, "BACKGROUND"))
        bg:SetColorTexture(C.bg[1]*1.1, C.bg[2]*1.1, C.bg[3]*1.1, 0.95)
        bg:SetSize(SEP_W, BAND_H)
        bg:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X, y)
        -- Teal left accent bar
        local accent = PushDetail(detailPanel:CreateTexture(nil, "BORDER"))
        accent:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 0.9)
        accent:SetSize(2, BAND_H)
        accent:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X, y)
        -- Label
        local fs = PushDetail(detailPanel:CreateFontString(nil, "OVERLAY"))
        fs:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
        fs:SetTextColor(C.muted[1] * 1.4, C.muted[2] * 1.4, C.muted[3] * 1.4)
        fs:SetText(label)
        fs:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X + 7, y - 1)
    end

    -- Draws a bordered group box around a section.  Call OpenGroup before the
    -- SectionHeader and CloseGroup after the last row advance for that section.
    -- Textures live on detailPanel's draw layers (BACKGROUND/BORDER) so they
    -- always render behind any child Frame objects placed inside the group.
    local function OpenGroup(label, y)
        local BOX_W = SEP_W + 8   -- 4 px padding on each side
        local TOP_Y = y + 4        -- 4 px above the SectionHeader band
        local grp   = { _topY = y }
        local br, bg2, bb = C.border[1], C.border[2], C.border[3]
        -- Fill
        local fill = PushDetail(detailPanel:CreateTexture(nil, "BACKGROUND"))
        fill:SetColorTexture(C.panel[1], C.panel[2], C.panel[3], 0.25)
        fill:SetWidth(BOX_W)
        fill:SetHeight(1)   -- actual height set by CloseGroup
        fill:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X - 4, TOP_Y)
        grp.fill = fill
        -- Top border line
        local topL = PushDetail(detailPanel:CreateTexture(nil, "BORDER"))
        topL:SetColorTexture(br, bg2, bb, 0.55)
        topL:SetSize(BOX_W, 1)
        topL:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X - 4, TOP_Y)
        -- Left border line
        local leftL = PushDetail(detailPanel:CreateTexture(nil, "BORDER"))
        leftL:SetColorTexture(br, bg2, bb, 0.55)
        leftL:SetSize(1, 1)
        leftL:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X - 4, TOP_Y)
        grp.leftL = leftL
        -- Right border line
        local rightL = PushDetail(detailPanel:CreateTexture(nil, "BORDER"))
        rightL:SetColorTexture(br, bg2, bb, 0.55)
        rightL:SetSize(1, 1)
        rightL:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X - 4 + BOX_W - 1, TOP_Y)
        grp.rightL = rightL
        -- Bottom border line (repositioned by CloseGroup)
        local botL = PushDetail(detailPanel:CreateTexture(nil, "BORDER"))
        botL:SetColorTexture(br, bg2, bb, 0.55)
        botL:SetSize(BOX_W, 1)
        botL:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X - 4, TOP_Y)
        grp.botL = botL
        SectionHeader(label, y)
        return grp
    end

    local function CloseGroup(grp, endRow)
        local TOP_Y = grp._topY + 4
        local BOT_Y = endRow - 4
        local h     = TOP_Y - BOT_Y   -- positive: TOP_Y is less negative than BOT_Y
        if h < 2 then h = 2 end
        grp.fill:SetHeight(h)
        grp.leftL:SetHeight(h)
        grp.rightL:SetHeight(h)
        grp.botL:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X - 4, BOT_Y)
    end

    -- ── Helpers ─────────────────────────────────────────────
    -- Shared preset swatch table (used for border colour, overlay colour, chase colour)
    local SWATCH_PRESETS = {
        { 1.00, 0.50, 0.00 },  -- orange
        { 0.10, 0.72, 0.74 },  -- teal
        { 0.96, 0.76, 0.24 },  -- gold
        { 0.42, 0.89, 0.63 },  -- green
        { 0.90, 0.30, 0.32 },  -- red
        { 1.00, 1.00, 1.00 },  -- white
        { 0.50, 0.25, 1.00 },  -- purple
        { 0.25, 0.50, 1.00 },  -- blue
    }

    --- Render a row of colour swatches + a "..." custom-colour button.
    --- onChange(r,g,b,a) is called when a colour is committed.
    local function DetailColorRow(px, py, currentColor, onChange)
        local swX = px
        for _, sw in ipairs(SWATCH_PRESETS) do
            local swBtn = PushDetail(CreateFrame("Button", nil, detailPanel, "BackdropTemplate"))
            swBtn:SetSize(18, 18)
            swBtn:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", swX, py)
            Backdrop(swBtn, { sw[1]*0.25, sw[2]*0.25, sw[3]*0.25 }, { sw[1], sw[2], sw[3] }, 1, 1)
            local cc = currentColor
            local isSel = cc
                and math.abs((cc[1] or 0) - sw[1]) < 0.02
                and math.abs((cc[2] or 0) - sw[2]) < 0.02
                and math.abs((cc[3] or 0) - sw[3]) < 0.02
            if isSel then swBtn:SetBackdropBorderColor(1, 1, 1, 1) end
            local capSw = sw
            swBtn:SetScript("OnEnter", function(s2) s2:SetBackdropBorderColor(1,1,1,1) end)
            swBtn:SetScript("OnLeave", function(s2)
                local cur = currentColor
                local sel = cur
                    and math.abs((cur[1] or 0) - capSw[1]) < 0.02
                    and math.abs((cur[2] or 0) - capSw[2]) < 0.02
                    and math.abs((cur[3] or 0) - capSw[3]) < 0.02
                s2:SetBackdropBorderColor(
                    sel and 1 or capSw[1], sel and 1 or capSw[2], sel and 1 or capSw[3], 1)
            end)
            swBtn:SetScript("OnClick", function()
                if onChange then onChange(capSw[1], capSw[2], capSw[3], 1) end
            end)
            swX = swX + 22
        end

        -- "..." custom colour button
        local custBtn = PushDetail(CreateFrame("Button", nil, detailPanel, "BackdropTemplate"))
        custBtn:SetSize(24, 18)
        custBtn:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", swX, py)
        Backdrop(custBtn, C.panel, C.border, 1, 1)
        local custLbl = custBtn:CreateFontString(nil, "OVERLAY")
        custLbl:SetFont(Font(9))
        custLbl:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
        custLbl:SetAllPoints(custBtn)
        custLbl:SetJustifyH("CENTER")
        custLbl:SetText("...")
        custBtn:SetScript("OnEnter", function(s2)
            GameTooltip:SetOwner(s2, "ANCHOR_RIGHT")
            GameTooltip:SetText("Custom Color", 1, 1, 1)
            GameTooltip:AddLine("Opens the color picker to choose any color.", 0.8, 0.8, 0.8, true)
            GameTooltip:Show()
            s2:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
        end)
        custBtn:SetScript("OnLeave", function(s2)
            GameTooltip:Hide()
            s2:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end)
        custBtn:SetScript("OnClick", function(s2)
            local cur   = currentColor or { 1, 1, 1, 1 }
            local prevR, prevG, prevB = cur[1], cur[2], cur[3]
            local cpf   = _G.ColorPickerFrame
            if not cpf then return end

            local info = {
                r = prevR, g = prevG, b = prevB,
                hasOpacity = false,
                func = function()
                    local r, g, b = cpf:GetColorRGB()
                    if onChange then onChange(r, g, b, 1) end
                end,
                cancelFunc = function(prev)
                    if onChange then onChange(prev.r, prev.g, prev.b, 1) end
                end,
            }

            if cpf.SetupColorPickerAndShow then
                cpf:SetupColorPickerAndShow(info)
            elseif _G.OpenColorPicker then
                _G.OpenColorPicker(info)
            end
        end)
    end

    -- ── COL 2: Positioning (always visible, fixed position) ──────────────────
    local c2Sec = PushDetail(detailPanel:CreateFontString(nil, "OVERLAY"))
    c2Sec:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
    c2Sec:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    c2Sec:SetText("POSITIONING")
    c2Sec:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col2X, c2y)
    AddTooltip(c2Sec, "Positioning", "Set where this indicator appears on the unit frame.")

    DetailLabel(detailPanel, "Anchor Point", col2X, c2y - 18)
    AddTooltip(
        DetailAnchorGrid(detailPanel, cfg.anchor or "TOPLEFT", col2X, c2y - 34, function(key)
            local layer = EnsureLayerWritable()
            layer.anchor         = key
            layer.relativeAnchor = key
            RefreshSlots()
            RefreshDetailPanel()
        end),
        "Anchor Point", "Click a cell to set where on the frame this indicator is anchored.")

    DetailSlider(detailPanel, "Offset X", cfg.offsetX or 0, -80, 80, 1,
        col2X, c2y - 96, 136, function(v)
            EnsureLayerWritable().offsetX = v
            DeferredFlush()
    end)
    DetailSlider(detailPanel, "Offset Y", cfg.offsetY or 0, -80, 80, 1,
        col2X, c2y - 130, 136, function(v)
            EnsureLayerWritable().offsetY = v
            DeferredFlush()
    end)

    -- ── COL 1: Type + Only Mine ───────────────────────────────────────────────
    local typeItems = {
        { key = "icons",   label = "Icon Cluster"    },
        { key = "border",  label = "Border Highlight" },
        { key = "overlay", label = "Color Overlay"    },
    }
    DetailLabel(detailPanel, "Indicator Type", col1X, row)
    local typeDD = DetailDropdown(detailPanel, typeItems, cfg.type or "icons", col1X, row - 14, 148, function(k)
        EnsureLayerWritable().type = k
        RefreshDetailPanel()
    end)
    AddTooltip(typeDD, "Indicator Type",
        "Icon Cluster: shows aura icons.\nBorder Highlight: glows the frame border.\nColor Overlay: tints the entire frame.")

    -- Only Mine only makes sense on the primary layer (shares aura condition with slot)
    if selectedLayer == 1 then
        local cbOnlyMine = DetailCheckbox(detailPanel, "Only Mine", slotCfg.onlyMine, col1X + 168, row - 14, function(v)
            local i2 = EnsureIndicatorsWritable(activeFrameKey)
            i2[selectedSlot].onlyMine = v
            DeferredFlush()
        end)
        AddTooltip(cbOnlyMine, "Only Mine", "When enabled, only show auras that YOU applied to this unit.")
    end

    row = row - 46

    -- ── COL 1: Type-specific settings ────────────────────────────────────────
    if (cfg.type or "icons") == "icons" then

        -- ── APPEARANCE ────────────────────────────────────────────────────────
        local grp_app = OpenGroup("APPEARANCE", row)
        row = row - BAND_H - 6

        DetailSlider(detailPanel, "Icon Size", cfg.iconSize or 18, 8, 40, 1,
            col1X, row, 130, function(v)
                EnsureLayerWritable().iconSize = v
                DeferredFlush()
        end)
        DetailSlider(detailPanel, "Max Count", cfg.maxCount or 5, 1, 12, 1,
            col1X + 148, row, 120, function(v)
                EnsureLayerWritable().maxCount = v
                DeferredFlush()
        end)
        row = row - 40

        local growItems = {
            { key="RIGHT", label="Right →" }, { key="LEFT",  label="Left ←"  },
            { key="UP",    label="Up ↑"    }, { key="DOWN",  label="Down ↓"  },
        }
        DetailLabel(detailPanel, "Grow Direction", col1X, row)
        local dirDD = DetailDropdown(detailPanel, growItems, cfg.growDirection or "RIGHT", col1X, row - 14, 128, function(k)
            EnsureLayerWritable().growDirection = k
            DeferredFlush()
        end)
        AddTooltip(dirDD, "Grow Direction", "Direction icons expand when multiple auras are active.")
        DetailSlider(detailPanel, "Gap", cfg.spacing or 2, 0, 12, 1,
            col1X + 148, row, 100, function(v)
                EnsureLayerWritable().spacing = v
                DeferredFlush()
        end)
        row = row - 40
        CloseGroup(grp_app, row)

        -- ── DURATION ──────────────────────────────────────────────────────────
        row = row - 8
        local grp_dur = OpenGroup("DURATION", row)
        row = row - BAND_H - 6

        local cbDur = DetailCheckbox(detailPanel, "Show Duration", cfg.showDuration ~= false, col1X, row - 6, function(v)
            EnsureLayerWritable().showDuration = v
            DeferredFlush()
        end)
        AddTooltip(cbDur, "Show Duration", "Display time remaining on each aura icon.")
        DetailSlider(detailPanel, "Font Size", cfg.durationFontSize or 7, 5, 14, 1,
            col1X + 140, row, 108, function(v)
                EnsureLayerWritable().durationFontSize = v
                DeferredFlush()
        end)
        row = row - 36

        DetailLabel(detailPanel, "Position", col1X, row)
        AddTooltip(
            DetailAnchorGrid(detailPanel, cfg.durAnchor or "TOPLEFT", col1X, row - 16, function(key)
                EnsureLayerWritable().durAnchor = key
                RefreshDetailPanel()
        end), "Duration Position", "Where the timer text sits on each icon.")
        row = row - 82
        CloseGroup(grp_dur, row)

        -- ── STACKS ────────────────────────────────────────────────────────────
        row = row - 8
        local grp_stk = OpenGroup("STACKS", row)
        row = row - BAND_H - 6

        local cbCount = DetailCheckbox(detailPanel, "Show Stacks", cfg.showCount ~= false, col1X, row - 6, function(v)
            EnsureLayerWritable().showCount = v
            DeferredFlush()
        end)
        AddTooltip(cbCount, "Show Stacks", "Display the aura stack count on each icon.")
        DetailSlider(detailPanel, "Font Size", cfg.countFontSize or 9, 5, 16, 1,
            col1X + 140, row, 108, function(v)
                EnsureLayerWritable().countFontSize = v
                DeferredFlush()
        end)
        row = row - 36

        DetailLabel(detailPanel, "Position", col1X, row)
        AddTooltip(
            DetailAnchorGrid(detailPanel, cfg.countAnchor or "BOTTOMRIGHT", col1X, row - 16, function(key)
                EnsureLayerWritable().countAnchor = key
                RefreshDetailPanel()
        end), "Stack Position", "Where the stack count sits on each icon.")
        row = row - 82
        CloseGroup(grp_stk, row)

    elseif (cfg.type or "icons") == "border" then
        -- Border Width
        DetailSlider(detailPanel, "Border Width", cfg.borderWidth or 2, 1, 8, 1,
            col1X, row, 130, function(v)
                EnsureLayerWritable().borderWidth = v
                DeferredFlush()
        end)
        row = row - 40

        -- Animation
        local animItems = {
            { key = "solid", label = "Solid" },
            { key = "pulse", label = "Pulse" },
            { key = "chase", label = "Chase" },
        }
        DetailLabel(detailPanel, "Animation", col1X, row)
        local animDD = DetailDropdown(detailPanel, animItems, cfg.borderAnim or "solid", col1X, row - 14, 120, function(k)
            EnsureLayerWritable().borderAnim = k
            RefreshDetailPanel()
        end)
        AddTooltip(animDD, "Animation",
            "Solid: static color.\nPulse: fades in and out.\nChase: tiny dots orbit the border.")

        -- Pulse speed (only when pulse selected)
        if (cfg.borderAnim or "solid") == "pulse" then
            DetailSlider(detailPanel, "Speed", cfg.borderAnimSpeed or 1.0, 0.25, 4.0, 0.25,
                col1X + 140, row, 108, function(v)
                    EnsureLayerWritable().borderAnimSpeed = v
                    DeferredFlush()
            end)
        end
        row = row - 40

        -- Border Color
        DetailLabel(detailPanel, "Border Color", col1X, row)
        DetailColorRow(col1X, row - 16, cfg.borderColor, function(r, g, b, a)
            EnsureLayerWritable().borderColor = { r, g, b, a or 1 }
            DeferredFlush()
            RefreshDetailPanel()
        end)
        row = row - 44

        -- Chase dot settings in col2 (below offset sliders)
        if (cfg.borderAnim or "solid") == "chase" then
            local chY = c2y - 170
            local c2Sec2 = PushDetail(detailPanel:CreateFontString(nil, "OVERLAY"))
            c2Sec2:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
            c2Sec2:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
            c2Sec2:SetText("CHASE DOTS")
            c2Sec2:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col2X, chY)

            DetailSlider(detailPanel, "Dot Count", cfg.chaseCount or 4, 1, 12, 1,
                col2X, chY - 18, 136, function(v)
                    EnsureLayerWritable().chaseCount = v
                    DeferredFlush()
            end)
            DetailSlider(detailPanel, "Dot Length", cfg.chasePixelW or 6, 1, 24, 1,
                col2X, chY - 52, 136, function(v)
                    EnsureLayerWritable().chasePixelW = v
                    DeferredFlush()
            end)
            DetailSlider(detailPanel, "Dot Thickness", cfg.chasePixelH or 2, 1, 12, 1,
                col2X, chY - 86, 136, function(v)
                    EnsureLayerWritable().chasePixelH = v
                    DeferredFlush()
            end)
            DetailLabel(detailPanel, "Dot Color", col2X, chY - 120)
            DetailColorRow(col2X, chY - 134, cfg.chaseColor, function(r, g, b, a)
                EnsureLayerWritable().chaseColor = { r, g, b, a or 1 }
                DeferredFlush()
            end)
        end

    elseif (cfg.type or "icons") == "overlay" then
        -- Overlay Color
        DetailLabel(detailPanel, "Overlay Color", col1X, row)
        DetailColorRow(col1X, row - 16, cfg.overlayColor, function(r, g, b, a)
            EnsureLayerWritable().overlayColor = { r, g, b, a or 1 }
            DeferredFlush()
            RefreshDetailPanel()
        end)
        row = row - 44

        -- Overlay Opacity
        DetailSlider(detailPanel, "Overlay Opacity", cfg.overlayAlpha or 0.35, 0.0, 0.8, 0.05,
            col1X, row, 200, function(v)
                EnsureLayerWritable().overlayAlpha = v
                DeferredFlush()
        end)
        row = row - 40
    end

    -- Spell list — only shown on the primary layer (layer 1) since spells are slot-wide
    if selectedLayer == 1 and slotCfg.source == "spell" then
        row = row - 8
        local grp_spells = OpenGroup("TRACKED SPELLS", row)
        row = row - BAND_H - 6

        local spellIds = slotCfg.spellIds or {}
        -- backward compat: surface legacy spellId scalar
        if #spellIds == 0 and slotCfg.spellId and slotCfg.spellId > 0 then
            spellIds = { slotCfg.spellId }
        end

        for _, sid in ipairs(spellIds) do
            -- Spell icon
            local sIcon = PushDetail(CreateFrame("Frame", nil, detailPanel))
            sIcon:SetSize(16, 16)
            sIcon:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X, row + 1)
            local sTex = sIcon:CreateTexture(nil, "ARTWORK")
            sTex:SetAllPoints(sIcon)
            sTex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
            if _G.C_Spell and _G.C_Spell.GetSpellTexture then
                sTex:SetTexture(_G.C_Spell.GetSpellTexture(sid))
            elseif _G.GetSpellTexture then
                sTex:SetTexture(_G.GetSpellTexture(sid))
            end

            -- Spell name
            local sName
            if _G.C_Spell and _G.C_Spell.GetSpellName then
                sName = _G.C_Spell.GetSpellName(sid)
            elseif _G.GetSpellInfo then
                sName = (_G.GetSpellInfo(sid))
            end
            local sLbl = PushDetail(detailPanel:CreateFontString(nil, "OVERLAY"))
            sLbl:SetFont(Font(LABEL_FONT_SIZE))
            sLbl:SetTextColor(C.text[1], C.text[2], C.text[3])
            sLbl:SetText(sName or ("ID: " .. tostring(sid)))
            sLbl:SetPoint("LEFT", sIcon, "RIGHT", 4, 0)
            sLbl:SetWidth(180)

            -- Remove button ×
            local rBtn = PushDetail(CreateFrame("Button", nil, detailPanel))
            rBtn:SetSize(14, 14)
            rBtn:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X + 210, row + 2)
            local rTex = rBtn:CreateFontString(nil, "OVERLAY")
            rTex:SetFont(SymbolFont(11))
            rTex:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
            rTex:SetAllPoints(rBtn)
            rTex:SetJustifyH("CENTER")
            rTex:SetText("×")
            local capSid = sid
            rBtn:SetScript("OnEnter", function() rTex:SetTextColor(C.danger[1], C.danger[2], C.danger[3]) end)
            rBtn:SetScript("OnLeave", function() rTex:SetTextColor(C.muted[1],  C.muted[2],  C.muted[3])  end)
            rBtn:SetScript("OnClick", function()
                local i2 = EnsureIndicatorsWritable(activeFrameKey)
                local ids = i2[selectedSlot].spellIds or {}
                for j = #ids, 1, -1 do
                    if ids[j] == capSid then table.remove(ids, j); break end
                end
                if i2[selectedSlot].spellId == capSid then
                    i2[selectedSlot].spellId = nil
                end
                RefreshSlots(); RefreshDetailPanel()
            end)
            row = row - 20
        end

        -- Add spell by ID input
        row = row - 4
        DetailLabel(detailPanel, "Add Spell ID:", col1X, row)
        row = row - 14
        local addBox = PushDetail(CreateFrame("EditBox", nil, detailPanel, "BackdropTemplate"))
        addBox:SetSize(100, 20)
        addBox:SetPoint("TOPLEFT", detailPanel, "TOPLEFT", col1X, row)
        addBox:SetFontObject(_G.GameFontNormal)
        addBox:SetAutoFocus(false)
        addBox:SetNumeric(true)
        addBox:SetMaxLetters(10)
        Backdrop(addBox, C.panel, C.border, 1, 1)
        addBox:SetTextInsets(4, 4, 0, 0)

        local addBtn = PushDetail(CreateFrame("Button", nil, detailPanel, "BackdropTemplate"))
        addBtn:SetSize(36, 20)
        addBtn:SetPoint("LEFT", addBox, "RIGHT", 4, 0)
        Backdrop(addBtn, C.card, C.border, 1, 1)
        local addLbl = addBtn:CreateFontString(nil, "OVERLAY")
        addLbl:SetFont(Font(LABEL_FONT_SIZE))
        addLbl:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
        addLbl:SetAllPoints(addBtn)
        addLbl:SetJustifyH("CENTER")
        addLbl:SetText("Add")

        local function DoAddSpell()
            local sid = tonumber(addBox:GetText())
            if sid and sid > 0 then
                local i2 = EnsureIndicatorsWritable(activeFrameKey)
                i2[selectedSlot].spellIds = i2[selectedSlot].spellIds or {}
                for _, existing in ipairs(i2[selectedSlot].spellIds) do
                    if existing == sid then
                        addBox:SetText(""); addBox:ClearFocus(); return
                    end
                end
                table.insert(i2[selectedSlot].spellIds, sid)
                addBox:SetText("")
                addBox:ClearFocus()
                RefreshSlots(); RefreshDetailPanel()
            end
        end
        addBox:SetScript("OnEnterPressed", function() DoAddSpell() end)
        addBtn:SetScript("OnEnter", function(self2)
            self2:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
        end)
        addBtn:SetScript("OnLeave", function(self2)
            self2:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
        end)
        addBtn:SetScript("OnClick", function() DoAddSpell() end)
        row = row - 28
        CloseGroup(grp_spells, row)
    end

    -- Resize scroll child to fit all content
    detailPanel:SetHeight(math.max(1, -row + PAD))

    -- Refresh preview to show current slot's layers
    RefreshPreview()

    DeferredFlush()
end

-- ============================================================
-- Root frame construction
-- ============================================================

local function BuildDesigner()
    if root then return end

    root = CreateFrame("Frame", "TwichAuraWatcherDesigner", UIParent, "BackdropTemplate")
    root:SetSize(W_TOTAL, H_TOTAL)
    root:SetPoint("CENTER", UIParent, "CENTER")
    root:SetFrameStrata("FULLSCREEN")
    root:SetFrameLevel(50)
    root:SetMovable(true)
    root:EnableMouse(true)
    root:RegisterForDrag("LeftButton")
    root:SetScript("OnDragStart", function(self) self:StartMoving() end)
    root:SetScript("OnDragStop",  function(self) self:StopMovingOrSizing() end)
    root:SetClampedToScreen(true)
    Backdrop(root, C.bg, C.border, 1, 1)

    -- Accent stripe along top
    local stripe = root:CreateTexture(nil, "ARTWORK")
    stripe:SetHeight(2)
    stripe:SetPoint("TOPLEFT",  root, "TOPLEFT",  1, -1)
    stripe:SetPoint("TOPRIGHT", root, "TOPRIGHT", -1, -1)
    stripe:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 1)

    -- ── Header ─────────────────────────────────────────────
    local header = CreateFrame("Frame", nil, root, "BackdropTemplate")
    header:SetHeight(HEADER_H)
    header:SetPoint("TOPLEFT",  root, "TOPLEFT",  0, 0)
    header:SetPoint("TOPRIGHT", root, "TOPRIGHT", 0, 0)
    Backdrop(header, C.panel, C.border, 1, 1)

    local title = header:CreateFontString(nil, "OVERLAY")
    title:SetFont(Font(14, "OUTLINE"))
    title:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
    title:SetText("Aura Watcher Designer")
    title:SetPoint("LEFT", header, "LEFT", PAD, 0)

    -- Frame-type dropdown (replaces cycle glyph + separate label)
    local frameDDBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    frameDDBtn:SetSize(148, 24)
    frameDDBtn:SetPoint("RIGHT", header, "RIGHT", -54, 0)
    Backdrop(frameDDBtn, C.card, C.border, 1, 1)

    headerFrameLabel = frameDDBtn:CreateFontString(nil, "OVERLAY")
    headerFrameLabel:SetFont(Font(LABEL_FONT_SIZE))
    headerFrameLabel:SetTextColor(C.text[1], C.text[2], C.text[3])
    headerFrameLabel:SetPoint("LEFT",  frameDDBtn, "LEFT",  6, 0)
    headerFrameLabel:SetPoint("RIGHT", frameDDBtn, "RIGHT", -14, 0)

    local ddArrow = frameDDBtn:CreateFontString(nil, "OVERLAY")
    ddArrow:SetFont(Font(9))
    ddArrow:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    ddArrow:SetText("v")
    ddArrow:SetPoint("RIGHT", frameDDBtn, "RIGHT", -4, 0)

    frameDDBtn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(C.teal[1], C.teal[2], C.teal[3], 1)
    end)
    frameDDBtn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    frameDDBtn:SetScript("OnClick", function(self)
        local items = {}
        for _, k in ipairs(FRAME_KEY_ORDER) do
            items[#items + 1] = { key = k, label = FRAME_LABELS[k] or k }
        end
        local menu = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        menu:SetFrameStrata("TOOLTIP")
        menu:SetFrameLevel(900)
        Backdrop(menu, C.panel, C.border, 1, 1)
        local itemH = 22
        menu:SetSize(148, #items * itemH + 4)
        menu:SetPoint("TOPLEFT", self, "BOTTOMLEFT", 0, -2)
        for idx2, item in ipairs(items) do
            local row = CreateFrame("Button", nil, menu, "BackdropTemplate")
            row:SetSize(144, itemH)
            row:SetPoint("TOPLEFT", menu, "TOPLEFT", 2, -(idx2-1)*itemH - 2)
            Backdrop(row, { 0, 0, 0 }, { 0, 0, 0 }, 0, 0)
            local isActive = (item.key == activeFrameKey)
            local rLbl = row:CreateFontString(nil, "OVERLAY")
            rLbl:SetFont(Font(LABEL_FONT_SIZE))
            rLbl:SetTextColor(
                isActive and C.teal[1] or C.text[1],
                isActive and C.teal[2] or C.text[2],
                isActive and C.teal[3] or C.text[3])
            rLbl:SetPoint("LEFT", row, "LEFT", 8, 0)
            rLbl:SetText(item.label)
            row:SetScript("OnEnter", function()
                row:SetBackdropColor(C.teal[1], C.teal[2], C.teal[3], 0.15)
            end)
            row:SetScript("OnLeave", function()
                row:SetBackdropColor(0, 0, 0, 0)
            end)
            row:SetScript("OnClick", function()
                activeFrameKey = item.key
                headerFrameLabel:SetText(FRAME_LABELS[activeFrameKey] or activeFrameKey)
                menu:Hide()
                menu:SetParent(nil)
                selectedSlot = 0
                RefreshSlots()
                RefreshDetailPanel()
            end)
        end
        local catcher = CreateFrame("Button", nil, UIParent)
        catcher:SetAllPoints(UIParent)
        catcher:SetFrameStrata("TOOLTIP")
        catcher:SetFrameLevel(899)
        catcher:SetScript("OnClick", function()
            menu:Hide(); catcher:Hide(); catcher:SetParent(nil)
        end)
        catcher:Show()
        menu:SetScript("OnHide", function()
            catcher:Hide(); catcher:SetParent(nil)
        end)
        menu:Show()
    end)

    -- Close button — plain text, no glyph needed
    local closeBtn = CreateFrame("Button", nil, header, "BackdropTemplate")
    closeBtn:SetSize(44, 24)
    closeBtn:SetPoint("RIGHT", header, "RIGHT", -PAD, 0)
    Backdrop(closeBtn, C.card, C.border, 1, 1)
    local closeLbl = closeBtn:CreateFontString(nil, "OVERLAY")
    closeLbl:SetFont(Font(LABEL_FONT_SIZE))
    closeLbl:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    closeLbl:SetAllPoints(closeBtn)
    closeLbl:SetJustifyH("CENTER")
    closeLbl:SetJustifyV("MIDDLE")
    closeLbl:SetText("Close")
    closeBtn:SetScript("OnEnter", function(self)
        closeLbl:SetTextColor(C.danger[1], C.danger[2], C.danger[3])
        self:SetBackdropBorderColor(C.danger[1], C.danger[2], C.danger[3], 1)
    end)
    closeBtn:SetScript("OnLeave", function(self)
        closeLbl:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        self:SetBackdropBorderColor(C.border[1], C.border[2], C.border[3], 1)
    end)
    closeBtn:SetScript("OnClick", function()
        UnitFrames:AWCloseDesigner()
    end)

    -- Cancel held on click-outside of designer
    root:SetScript("OnMouseDown", function(self, button)
        if button == "RightButton" and heldEntry then
            SetHeld(nil)
        end
    end)

    -- ESC binding
    root:SetScript("OnKeyDown", function(self, key)
        if key == "ESCAPE" then
            if heldEntry then
                SetHeld(nil)
                self:SetPropagateKeyboardInput(false)
            else
                UnitFrames:AWCloseDesigner()
                self:SetPropagateKeyboardInput(false)
            end
        else
            self:SetPropagateKeyboardInput(true)
        end
    end)
    root:EnableKeyboard(true)

    -- ── Catalogue panel (left) ──────────────────────────────
    local CATALOG_W  = 230
    local CONTENT_Y  = -(HEADER_H + PAD)
    local CONTENT_H  = H_TOTAL - HEADER_H - PAD * 2

    local catPanel = CreateFrame("Frame", nil, root, "BackdropTemplate")
    catPanel:SetSize(CATALOG_W, CONTENT_H)
    catPanel:SetPoint("TOPLEFT", root, "TOPLEFT", PAD, CONTENT_Y)
    Backdrop(catPanel, C.panel, C.border, 1, 1)

    local catTitle = catPanel:CreateFontString(nil, "OVERLAY")
    catTitle:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
    catTitle:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    catTitle:SetText("SPELL CATALOGUE")
    catTitle:SetPoint("TOPLEFT", catPanel, "TOPLEFT", PAD, -8)

    catalogScroll = CreateFrame("ScrollFrame", nil, catPanel)
    catalogScroll:SetPoint("TOPLEFT",    catPanel, "TOPLEFT",    2, -22)
    catalogScroll:SetPoint("BOTTOMRIGHT",catPanel, "BOTTOMRIGHT",-4,  4)

    catalogChild  = CreateFrame("Frame", nil, catalogScroll)
    catalogChild:SetSize(CATALOG_W - 6, 1)
    catalogScroll:SetScrollChild(catalogChild)

    -- Scroll with mouse wheel
    catalogScroll:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local max     = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, current - delta * 20)))
    end)

    -- ── Right content area ─────────────────────────────────
    local RIGHT_W = W_TOTAL - CATALOG_W - PAD * 3
    local rightArea = CreateFrame("Frame", nil, root)
    rightArea:SetSize(RIGHT_W, CONTENT_H)
    rightArea:SetPoint("TOPLEFT", root, "TOPLEFT", CATALOG_W + PAD * 2, CONTENT_Y)

    -- ── Slot cards ─────────────────────────────────────────
    local slotArea = CreateFrame("Frame", nil, rightArea, "BackdropTemplate")
    local SLOT_AREA_H = (SLOT_H + SLOT_PAD) * 2 + PAD + 20
    slotArea:SetSize(RIGHT_W, SLOT_AREA_H)
    slotArea:SetPoint("TOPLEFT", rightArea, "TOPLEFT", 0, 0)
    Backdrop(slotArea, C.panel, C.border, 1, 1)

    local slotTitle = slotArea:CreateFontString(nil, "OVERLAY")
    slotTitle:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
    slotTitle:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    slotTitle:SetText("INDICATOR SLOTS")
    slotTitle:SetPoint("TOPLEFT", slotArea, "TOPLEFT", PAD, -8)

    -- Build 6 slot cards in a 3×2 grid
    for i = 1, 6 do
        local col  = ((i - 1) % SLOT_COLS)
        local row2 = math_floor((i - 1) / SLOT_COLS)
        local card = BuildSlotCard(slotArea, i)
        card:SetPoint("TOPLEFT", slotArea, "TOPLEFT",
            PAD + col * (SLOT_W + SLOT_PAD),
            -(22 + row2 * (SLOT_H + SLOT_PAD)))
    end

    -- ── Detail panel ───────────────────────────────────────
    local DETAIL_Y    = -(SLOT_AREA_H + PAD)
    local DETAIL_H    = CONTENT_H - SLOT_AREA_H - PAD * 2
    local detailOuter = CreateFrame("Frame", nil, rightArea, "BackdropTemplate")
    detailOuter:SetSize(RIGHT_W, math.max(DETAIL_H, 160))
    detailOuter:SetPoint("TOPLEFT", rightArea, "TOPLEFT", 0, DETAIL_Y)
    Backdrop(detailOuter, C.panel, C.border, 1, 1)

    local detailTitle = detailOuter:CreateFontString(nil, "OVERLAY")
    detailTitle:SetFont(Font(SECTION_FONT_SIZE, "OUTLINE"))
    detailTitle:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
    detailTitle:SetText("SLOT SETTINGS")
    detailTitle:SetPoint("TOPLEFT", detailOuter, "TOPLEFT", PAD, -8)

    -- Scrollable inner child for settings widgets
    local detailScroll = CreateFrame("ScrollFrame", nil, detailOuter)
    detailScroll:SetPoint("TOPLEFT",     detailOuter, "TOPLEFT",     2, -22)
    detailScroll:SetPoint("BOTTOMRIGHT", detailOuter, "BOTTOMRIGHT", -4,  4)
    detailScroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        local max = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(max, cur - delta * 20)))
    end)
    detailPanel = CreateFrame("Frame", nil, detailScroll)
    detailPanel:SetSize(RIGHT_W - 6, 80)
    detailScroll:SetScrollChild(detailPanel)

    -- ── Preview side panel (anchored to right exterior of root) ──────────────
    if not previewSidePanel then
        local SIDE_W = 200
        previewSidePanel = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
        previewSidePanel:SetWidth(SIDE_W)
        previewSidePanel:SetPoint("TOPLEFT",    root, "TOPRIGHT",    PAD, 0)
        previewSidePanel:SetPoint("BOTTOMLEFT", root, "BOTTOMRIGHT", PAD, 0)
        previewSidePanel:SetFrameStrata("FULLSCREEN")
        previewSidePanel:SetFrameLevel(root:GetFrameLevel() + 2)
        Backdrop(previewSidePanel, C.panel, C.border, 1, 1)

        -- Accent line along the left edge
        local sideAccent = previewSidePanel:CreateTexture(nil, "BORDER")
        sideAccent:SetWidth(2)
        sideAccent:SetPoint("TOPLEFT",    previewSidePanel, "TOPLEFT",    1, -1)
        sideAccent:SetPoint("BOTTOMLEFT", previewSidePanel, "BOTTOMLEFT", 1,  1)
        sideAccent:SetColorTexture(C.teal[1], C.teal[2], C.teal[3], 0.7)

        -- Section header
        local sideTitle = previewSidePanel:CreateFontString(nil, "OVERLAY")
        sideTitle:SetFont(Font(14, "OUTLINE"))
        sideTitle:SetTextColor(C.teal[1], C.teal[2], C.teal[3])
        sideTitle:SetText("LIVE PREVIEW")
        sideTitle:SetPoint("TOPLEFT", previewSidePanel, "TOPLEFT", PAD + 4, -PAD)

        -- Subtitle
        local sideSub = previewSidePanel:CreateFontString(nil, "OVERLAY")
        sideSub:SetFont(Font(10))
        sideSub:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        sideSub:SetText("Aura overlays update as\nyou adjust settings.")
        sideSub:SetJustifyH("LEFT")
        sideSub:SetWidth(SIDE_W - PAD * 2 - 4)
        sideSub:SetPoint("TOPLEFT", sideTitle, "BOTTOMLEFT", 0, -4)

        -- Mock unit frame (preview host)
        previewHost = CreateFrame("Frame", nil, previewSidePanel, "BackdropTemplate")
        previewHost:SetSize(SIDE_W - PAD * 2, 90)
        previewHost:SetPoint("TOPLEFT", sideSub, "BOTTOMLEFT", 0, -PAD)
        Backdrop(previewHost, { 0.05, 0.07, 0.10 }, C.border, 1, 1)

        local previewLabel = previewHost:CreateFontString(nil, "OVERLAY")
        previewLabel:SetFont(Font(7, "OUTLINE"))
        previewLabel:SetTextColor(C.muted[1], C.muted[2], C.muted[3])
        previewLabel:SetText("UNIT FRAME")
        previewLabel:SetPoint("TOPLEFT", previewHost, "TOPLEFT", 4, -4)

        -- Mock health bar
        local phHBg = previewHost:CreateTexture(nil, "BACKGROUND")
        phHBg:SetColorTexture(0.08, 0.09, 0.12, 1)
        phHBg:SetHeight(10)
        phHBg:SetPoint("BOTTOMLEFT",  previewHost, "BOTTOMLEFT",  3, 3)
        phHBg:SetPoint("BOTTOMRIGHT", previewHost, "BOTTOMRIGHT", -3, 3)

        local phHFg = previewHost:CreateTexture(nil, "ARTWORK")
        phHFg:SetColorTexture(0.10, 0.68, 0.25, 1)
        phHFg:SetHeight(10)
        phHFg:SetPoint("BOTTOMLEFT", previewHost, "BOTTOMLEFT", 3, 3)
        phHFg:SetWidth(100)

        -- Mock name bar
        local phNameBg = previewHost:CreateTexture(nil, "BACKGROUND")
        phNameBg:SetColorTexture(0.06, 0.07, 0.10, 1)
        phNameBg:SetHeight(16)
        phNameBg:SetPoint("TOPLEFT",  previewHost, "TOPLEFT",  3, -16)
        phNameBg:SetPoint("TOPRIGHT", previewHost, "TOPRIGHT", -3, -16)

        local phName = previewHost:CreateFontString(nil, "OVERLAY")
        phName:SetFont(Font(8))
        phName:SetTextColor(C.text[1], C.text[2], C.text[3])
        phName:SetText("Player Name")
        phName:SetPoint("LEFT", phNameBg, "LEFT", 4, 0)

        UnitFrames:AWAttach(previewHost)
        previewHost.unit = nil

        previewSidePanel:Hide()
    end

    root:Hide()
end

-- ============================================================
-- Public API
-- ============================================================

--- Open the Aura Watcher Designer for a specific unit-frame key.
---@param frameKey string  e.g. "partyMember", "player", "raidMember"
function UnitFrames:AWOpenDesigner(frameKey)
    BuildDesigner()
    if not root then return end
    activeFrameKey = frameKey or "partyMember"
    heldEntry      = nil
    selectedSlot   = 0
    selectedLayer  = 1
    HideCursor()
    if headerFrameLabel then
        headerFrameLabel:SetText(FRAME_LABELS[activeFrameKey] or activeFrameKey)
    end
    root:Show()
    root:Raise()
    if previewSidePanel then
        previewSidePanel:Show()
        previewSidePanel:SetFrameLevel(root:GetFrameLevel() + 2)
    end
    RefreshCatalog()
    RefreshSlots()
    RefreshDetailPanel()
end

--- Close the designer.
function UnitFrames:AWCloseDesigner()
    if root then root:Hide() end
    if previewSidePanel then previewSidePanel:Hide() end
    HideCursor()
    SetHeld(nil)
end

--- Toggle open/closed.
function UnitFrames:AWToggleDesigner(frameKey)
    BuildDesigner()
    if root:IsShown() then
        UnitFrames:AWCloseDesigner()
    else
        UnitFrames:AWOpenDesigner(frameKey or activeFrameKey)
    end
end
