---@diagnostic disable: undefined-field
--[[
    Gathering Datatext
    ==================
    Shows: HUD status, session gold/hour.
    Left-click    → Toggle Farm HUD
    Shift-click   → Pause / Resume session
    Ctrl-click    → Reset session
    Right-click   → Menu (open tracker, toggle HUD, session controls)
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DataTextModule = T:GetModule("Datatexts")

local IsControlKeyDown = _G.IsControlKeyDown
local IsShiftKeyDown   = _G.IsShiftKeyDown
local floor            = math.floor
local format           = string.format
local min              = math.min

local GOLD_COLOR   = "|cffffd24a"
local SILVER_COLOR = "|cffd7e0ea"
local COPPER_COLOR = "|cffd08a43"

---@class GatheringDataText : AceModule
local GDT = DataTextModule:NewModule("GatheringDataText")

local DATATEXT_NAME = "TwichUI: Gathering"

local function GetGatheringModule()
    ---@type QualityOfLifeGatheringModule
    local qol = T:GetModule("QualityOfLife")
    return qol and qol:GetModule("Gathering", true) or nil
end

local function GetOptions()
    return T:GetModule("Configuration").Options.Gathering
end

-- ============================================================
-- Formatting helpers
-- ============================================================
local function FormatCopper(copper)
    if not copper or copper <= 0 then return "0g" end
    local g = floor(copper / 10000)
    local s = floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return format("%dg %ds", g, s)
    elseif s > 0 then
        return format("%ds %dc", s, c)
    else
        return format("%dc", c)
    end
end

local function FormatCopperColored(copper)
    if not copper or copper <= 0 then return "|cffaaaaaa0g|r" end
    local g = floor(copper / 10000)
    local s = floor((copper % 10000) / 100)
    local c = copper % 100
    if g > 0 then
        return format("%s%dg|r %s%ds|r", GOLD_COLOR, g, SILVER_COLOR, s)
    elseif s > 0 then
        return format("%s%ds|r %s%dc|r", SILVER_COLOR, s, COPPER_COLOR, c)
    else
        return format("%s%dc|r", COPPER_COLOR, c)
    end
end

local function GetSortedItems(session)
    local items = {}
    for _, entry in pairs(session.items or {}) do
        table.insert(items, entry)
    end
    table.sort(items, function(left, right)
        return (left.totalValue or 0) > (right.totalValue or 0)
    end)
    return items
end

-- ============================================================
-- Panel update
-- ============================================================
local function OnUpdate(panel, elapsed)
    local opts = GetOptions()
    -- Show HUD status regardless of module enabled state; only hide if datatext itself disabled.
    if opts and not opts:GetDatatextEnabled() then
        panel.text:SetText("|cffaaaaaa[Gathering]|r")
        return
    end

    local mod   = GetGatheringModule()
    local parts = {}

    -- HUD status indicator (avoid Unicode symbols — not all WoW fonts render them)
    if mod and mod.hud and mod.hud.active then
        table.insert(parts, "|cff20bf4f[HUD]|r")
    else
        table.insert(parts, "|cff666666[HUD]|r")
    end

    if mod and mod.session then
        local sess = mod.session

        if sess.startTime and not sess.active then
            table.insert(parts, "|cffd4a017Paused|r")
        end

        if sess.startTime then
            local gphStr = (sess.goldPerHour and sess.goldPerHour > 0)
                and (FormatCopperColored(sess.goldPerHour) .. "/hr")
                or "|cffaaaaaa0g/hr|r"
            table.insert(parts, gphStr)

            local totalStr = FormatCopperColored(sess.totalValue or 0)
            table.insert(parts, "|cffd4a017Total:|r " .. totalStr)
        end
    end

    if #parts == 0 then
        panel.text:SetText("[Gathering]")
    else
        panel.text:SetText(table.concat(parts, "  "))
    end
end

-- ============================================================
-- Click handler
-- ============================================================
local function OnClick(panel, button)
    local mod  = GetGatheringModule()
    if not mod then return end

    if button == "RightButton" then
        -- Right click → menu
        local menuList = {
            {
                text    = "Gathering",
                isTitle = true,
                notCheckable = true,
            },
            {
                text    = mod.hud and mod.hud.active and "Disable Farm HUD" or "Enable Farm HUD",
                notCheckable = true,
                func    = function() mod:ToggleHUD() end,
            },
            { text = " ", notCheckable = true, disabled = true },
            {
                text    = "Session",
                isTitle = true,
                notCheckable = true,
            },
        }

        local sess = mod.session
        if not sess.startTime then
            table.insert(menuList, {
                text = "Start Session",
                notCheckable = true,
                func = function() mod:StartSession() end,
            })
        elseif sess.active then
            table.insert(menuList, {
                text = "Pause Session",
                notCheckable = true,
                func = function() mod:PauseSession() end,
            })
        else
            table.insert(menuList, {
                text = "Resume Session",
                notCheckable = true,
                func = function() mod:StartSession() end,
            })
        end

        table.insert(menuList, {
            text = "Reset Session",
            notCheckable = true,
            func = function() mod:ResetSession() end,
        })

        table.insert(menuList, { text = " ", notCheckable = true, disabled = true })

        table.insert(menuList, {
            text = "Open Gathered Items",
            notCheckable = true,
            func = function() mod:ToggleTrackerFrame() end,
        })

        DataTextModule:ShowMenu(panel, menuList)
        return
    end

    if button == "LeftButton" then
        if IsControlKeyDown() then
            mod:ResetSession()
        elseif IsShiftKeyDown() then
            if mod.session.active then
                mod:PauseSession()
            else
                mod:StartSession()
            end
        else
            mod:ToggleHUD()
        end
    end
end

-- ============================================================
-- Tooltip
-- ============================================================
local function OnEnter(panel)
    local mod = GetGatheringModule()

    local gt = DataTextModule:GetElvUITooltip()
    if not gt then return end

    gt:SetOwner(panel, "ANCHOR_NONE")
    gt:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 0, 4)
    gt:ClearLines()
    gt:AddLine("|cff19c9c7TwichUI|r |cffd7e0eaGathering|r")
    gt:AddLine("|cff7f8c9bFarm session overview and quick controls|r")
    gt:AddLine(" ")

    if not mod then
        gt:AddLine("|cffff4444Module not loaded.|r")
        gt:Show()
        return
    end

    local sess = mod.session
    gt:AddLine("|cff19c9c7Status|r")
    gt:AddDoubleLine("HUD", mod.hud and mod.hud.active and "|cff20bf4fActive|r" or "|cff7f8c9bInactive|r", 0.9,0.93,0.97, 1,1,1)

    local status
    if not sess.startTime then
        status = "|cff7f8c9bNot started|r"
    elseif not sess.active then
        status = "|cffd4a017Paused|r"
    else
        status = "|cff20bf4fActive|r"
    end
    gt:AddDoubleLine("Session", status, 0.9,0.93,0.97, 1,1,1)

    if sess.startTime then
        local secs    = mod:GetActiveSessionSeconds()
        local mins    = floor(secs / 60)
        local secRem  = secs % 60
        gt:AddDoubleLine("Duration", format("%dm %02ds", mins, secRem), 0.9,0.93,0.97, 0.86,0.9,0.96)
        gt:AddDoubleLine("Total Value", FormatCopperColored(sess.totalValue), 0.9,0.93,0.97, 1,1,1)
        if sess.goldPerHour > 0 then
            gt:AddDoubleLine("Gold / Hour", FormatCopperColored(sess.goldPerHour), 0.9,0.93,0.97, 1,1,1)
        end

        gt:AddLine(" ")
        gt:AddLine("|cff19c9c7Top Finds|r")
        local sortedItems = GetSortedItems(sess)
        if #sortedItems == 0 then
            gt:AddLine("|cff7f8c9bNo gathered items in this session yet.|r")
        else
            for index = 1, min(4, #sortedItems) do
                local entry = sortedItems[index]
                gt:AddDoubleLine(
                    format("%s |cff9aa5b1x%d|r", entry.itemLink or (entry.name or "Unknown"), entry.qty or 0),
                    FormatCopperColored(entry.totalValue or 0),
                    0.82,0.87,0.94,
                    1,1,1
                )
            end
        end
    end

    gt:AddLine(" ")
    gt:AddLine("|cff19c9c7Controls|r")
    gt:AddLine("|cff7f8c9bLeft-click: Toggle HUD|r")
    gt:AddLine("|cff7f8c9bShift-click: Pause or resume session|r")
    gt:AddLine("|cff7f8c9bCtrl-click: Reset session|r")
    gt:AddLine("|cff7f8c9bRight-click: Open actions menu|r")
    gt:Show()
end

local function OnLeave(panel)
    local gt = DataTextModule:GetElvUITooltip()
    if gt then gt:Hide() end
end

-- ============================================================
-- Register
-- ============================================================
DataTextModule:Inform({
    name          = DATATEXT_NAME,
    prettyName    = "Gathering",
    onUpdateFunc  = OnUpdate,
    onClickFunc   = OnClick,
    onEnterFunc   = OnEnter,
    onLeaveFunc   = OnLeave,
    module        = GDT,
})
