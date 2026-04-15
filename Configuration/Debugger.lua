--[[
    Debug / diagnostics configuration section.
    Provides debug console controls, profiler controls, nameplate diagnostics,
    and a list of registered debug sources.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local function GetDebugConsole()
    return T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
end

local function GetProfiler()
    return T.Tools and T.Tools.UI and T.Tools.UI.Profiler
end

local function GetTooltipModule()
    return T:GetModule("Tooltip", true) --[[@as any]]
end

local function OpenDebugSource(sourceKey)
    local console = GetDebugConsole()
    if console and type(console.Show) == "function" then
        console:Show(sourceKey)
    else
        T:Print("[TwichUI] Debug Console is not available.")
    end
end

local function BuildDebugConsoleConfiguration()
    local W = ConfigurationModule.Widgets

    local actionsGroup = W.IGroup(10, "Actions", {
        open = {
            type  = "execute",
            order = 1,
            name  = "Open Debug Console",
            desc  = "Open the TwichUI Debug Console window.",
            func  = function() OpenDebugSource() end,
        },
        openActionBars = {
            type  = "execute",
            order = 2,
            name  = "Action Bars Logs",
            func  = function() OpenDebugSource("actionbars") end,
        },
        openUnitFrames = {
            type  = "execute",
            order = 3,
            name  = "Unit Frames Logs",
            func  = function() OpenDebugSource("unitframes") end,
        },
        openNameplates = {
            type  = "execute",
            order = 4,
            name  = "Nameplates Logs",
            func  = function() OpenDebugSource("nameplates") end,
        },
        openTooltips = {
            type  = "execute",
            order = 5,
            name  = "Tooltip Logs",
            func  = function() OpenDebugSource("tooltip") end,
        },
        clearAll = {
            type        = "execute",
            order       = 6,
            name        = "Clear All Logs",
            confirm     = true,
            confirmText = "Clear all debug logs?",
            func        = function()
                local console = GetDebugConsole()
                if console and type(console.ClearLogs) == "function" then
                    console:ClearLogs()
                end
            end,
        },
    })

    local tooltipDiagGroup = W.IGroup(17, "Tooltip Diagnostics", {
        tooltipStatus = {
            type  = "description",
            order = 1,
            name  = function()
                local module = GetTooltipModule()
                if not module then
                    return "|cffff9a6cTooltip module not loaded.|r"
                end

                if module.GetDebugSummaryLine then
                    return module:GetDebugSummaryLine()
                end

                return "|cff69b86fTooltip module loaded.|r"
            end,
        },
        tooltipPreview = {
            type  = "execute",
            order = 2,
            name  = "Preview Tooltip",
            func  = function()
                local module = GetTooltipModule()
                if module and module.ShowPreview then
                    module:ShowPreview()
                end
            end,
        },
        tooltipSnapshot = {
            type  = "execute",
            order = 3,
            name  = "Capture Tooltip Snapshot",
            desc  = "Emit a paste-friendly tooltip snapshot into the debugger.",
            func  = function()
                local module = GetTooltipModule()
                if module and module.CaptureDebugSnapshot then
                    module:CaptureDebugSnapshot(true)
                end
            end,
        },
        tooltipLogs = {
            type  = "execute",
            order = 4,
            name  = "Open Tooltip Logs",
            func  = function() OpenDebugSource("tooltip") end,
        },
    })

    local profilerGroup = W.IGroup(15, "Profiler", {
        memoryEnabled = {
            type  = "toggle",
            order = 1,
            name  = "Enable Memory Metrics",
            desc  = "Track per-call memory deltas (KB) during profiling sessions.",
            get   = function()
                local p = GetProfiler()
                return p and p.IsMemoryProfilingEnabled and p.IsMemoryProfilingEnabled() or false
            end,
            set   = function(_, v)
                local p = GetProfiler()
                if p and p.SetMemoryProfilingEnabled then p.SetMemoryProfilingEnabled(v == true) end
            end,
        },
        memorySampleInterval = {
            type  = "range",
            order = 2,
            name  = "Memory Sample Interval",
            desc  = "How often (seconds) the profiler snapshots TwichUI memory.",
            min   = 1,
            max   = 60,
            step  = 1,
            get   = function()
                local p = GetProfiler()
                return p and p.GetMemorySampleInterval and p:GetMemorySampleInterval() or 5
            end,
            set   = function(_, v)
                local p = GetProfiler()
                if p and p.SetMemorySampleInterval then p:SetMemorySampleInterval(v) end
            end,
        },
        startProfiling = {
            type  = "execute",
            order = 10,
            name  = "Start Profiling",
            func  = function()
                local p = GetProfiler()
                if p and p.StartProfiling then p:StartProfiling() end
            end,
        },
        stopProfiling = {
            type  = "execute",
            order = 11,
            name  = "Stop Profiling",
            func  = function()
                local p = GetProfiler()
                if p and p.StopProfiling then p:StopProfiling() end
            end,
        },
        clearProfiling = {
            type        = "execute",
            order       = 12,
            name        = "Clear Profiling Data",
            confirm     = true,
            confirmText = "Clear all profiling data?",
            func        = function()
                local p = GetProfiler()
                if p and p.ClearProfiles then p:ClearProfiles() end
            end,
        },
        status = {
            type  = "description",
            order = 20,
            name  = function()
                local p = GetProfiler()
                if not p then return "|cffff9a6cProfiler unavailable.|r" end
                local active   = p.IsActive and p:IsActive() == true
                local memory   = p.IsMemoryProfilingEnabled and p.IsMemoryProfilingEnabled() == true
                local pd       = p.GetProfileData and p:GetProfileData()
                local count    = (pd and pd.totalProfiles) or 0
                local summary  = pd and pd.memorySummary
                local growth   = (summary and summary.growthKB) or 0
                local samples  = (summary and summary.sampleCount) or 0
                local interval = p.GetMemorySampleInterval and p:GetMemorySampleInterval() or 5
                return string.format(
                    "Status: %s  |  Memory: %s  |  Profiles: %d  |  Growth: %+.2f MB  |  Samples: %d @ %ss",
                    active and "|cff69b86fACTIVE|r" or "|cffff9a6cINACTIVE|r",
                    memory and "|cff69b86fON|r" or "|cffff9a6cOFF|r",
                    count, (growth or 0) / 1024, samples, tostring(interval)
                )
            end,
        },
    })

    local npDiagGroup = W.IGroup(18, "Nameplate Diagnostics", {
        npDesc = {
            type  = "description",
            order = 1,
            name  = "Inspect live nameplate frame state. Also available via: /tui npdebug",
        },
        npDbStatus = {
            type  = "description",
            order = 2,
            name  = function()
                local mod = T:GetModule("Nameplates")
                if not mod then return "|cffff9a6cNameplates module not loaded.|r" end
                local db = mod.GetDB and mod:GetDB()
                if not db then return "|cffff9a6cDB unavailable.|r" end
                return string.format(
                    "healthFormat: |cff69b86f%s|r   healthFontSize: |cff69b86f%s|r\n"
                    .. "healthTextAnchor: |cff69b86f%s|r   showAbsorb: |cff69b86f%s|r",
                    tostring(db.healthFormat or "nil"),
                    tostring(db.healthFontSize or "nil"),
                    tostring(db.healthTextAnchor or "nil"),
                    tostring(db.showAbsorb)
                )
            end,
        },
        npDump = {
            type  = "execute",
            order = 5,
            name  = "Dump First Active Plate",
            desc  = "Print state of the first visible nameplate frame to chat.",
            func  = function()
                local mod = T:GetModule("Nameplates")
                if not mod or not mod._plates then
                    T:Print("[NP] Module unavailable."); return
                end
                local found = false
                for unit, frame in pairs(mod._plates) do
                    if frame and frame:IsShown() then
                        found = true
                        T:Print("[NP] Unit: " .. tostring(unit))
                        local ht = frame.healthText
                        if ht then
                            local font, size, flags = ht:GetFont()
                            T:Print(string.format(
                                "  healthText: IsShown=%s Text=%q Points=%d Font=%s sz=%s flags=%s",
                                tostring(ht:IsShown()), tostring(ht:GetText() or ""),
                                ht:GetNumPoints(), tostring(font), tostring(size), tostring(flags)
                            ))
                        else
                            T:Print("  healthText: NOT CREATED")
                        end
                        local hb = frame.healthBar
                        if hb then
                            T:Print(string.format("  healthBar: w=%.0f h=%.0f IsShown=%s",
                                hb:GetWidth(), hb:GetHeight(), tostring(hb:IsShown())))
                        end
                        break
                    end
                end
                if not found then T:Print("[NP] No visible plates found.") end
            end,
        },
        npCount = {
            type  = "execute",
            order = 6,
            name  = "Count Plates",
            func  = function()
                local mod = T:GetModule("Nameplates")
                if not mod or not mod._plates then
                    T:Print("[NP] Module unavailable."); return
                end
                local total, visible = 0, 0
                for _, frame in pairs(mod._plates) do
                    total = total + 1
                    if frame and frame:IsShown() then visible = visible + 1 end
                end
                T:Print(string.format("[NP] Tracked: %d  Visible: %d", total, visible))
            end,
        },
        npRefresh = {
            type  = "execute",
            order = 7,
            name  = "Force Refresh All Plates",
            func  = function()
                local mod = T:GetModule("Nameplates")
                if mod and mod.RefreshAllPlates then
                    mod:RefreshAllPlates()
                    T:Print("[NP] RefreshAllPlates called.")
                else
                    T:Print("[NP] RefreshAllPlates not available.")
                end
            end,
        },
    })

    local sourcesGroup = W.IGroup(20, "Registered Sources", {
        list = {
            type  = "description",
            order = 1,
            name  = function()
                local console = GetDebugConsole()
                if not console then return "|cffff9a6cDebug Console not loaded.|r" end
                local keys = console:GetSortedSourceKeys()
                if not keys or #keys == 0 then return "|cff69b86fNo sources registered yet.|r" end
                local lines = {}
                for _, k in ipairs(keys) do
                    local src = console.sources and console.sources[k]
                    local title = (src and src.title) or k
                    lines[#lines + 1] = "  " .. title .. "  |cff888888(" .. k .. ")|r"
                end
                return table.concat(lines, "\n")
            end,
        },
    })

    local section = W.NewConfigurationSection(96, "Debug")
    section.args = {
        title      = W.TitleWidget(0, "Debug"),
        desc       = W.Description(5, "Debug console, profiler controls, and live diagnostics."),
        actions    = actionsGroup,
        tooltips   = tooltipDiagGroup,
        profiler   = profilerGroup,
        nameplates = npDiagGroup,
        sources    = sourcesGroup,
    }

    return section
end

ConfigurationModule:RegisterConfigurationFunction("Debugger", BuildDebugConsoleConfiguration)
