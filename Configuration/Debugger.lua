--[[
    Debug Console configuration section.
    Provides a button to open the TwichUI Debug Console and lists registered sources.
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

local function OpenDebugSource(sourceKey)
    local console = GetDebugConsole()
    if console and console.Show then
        console:Show(sourceKey)
    else
        T:Print("[TwichUI] Debug Console is not available.")
    end
end

local function BuildDebugConsoleConfiguration()
    local W = ConfigurationModule.Widgets

    local section = W.NewConfigurationSection(96, "Debug Console")
    section.args = {
        title    = W.TitleWidget(0, "Debug Console"),
        desc     = W.Description(5,
            "The TwichUI Debug Console collects diagnostic logs from internal modules. " ..
            "Open it to inspect live state, copy reports for bug reports, or clear logs."),
        actions  = W.IGroup(10, "Actions", {
            open = {
                type  = "execute",
                order = 0,
                name  = "Open Debug Console",
                desc  = "Open the TwichUI Debug Console window.",
                func  = function()
                    OpenDebugSource()
                end,
            },
            openActionBars = {
                type  = "execute",
                order = 2,
                name  = "Open Action Bars Logs",
                desc  = "Open the Debug Console focused on the Action Bars source.",
                func  = function()
                    OpenDebugSource("actionbars")
                end,
            },
            openUnitFrames = {
                type  = "execute",
                order = 3,
                name  = "Open Unit Frames Logs",
                desc  = "Open the Debug Console focused on the Unit Frames source.",
                func  = function()
                    OpenDebugSource("unitframes")
                end,
            },
            clearAll = {
                type        = "execute",
                order       = 5,
                name        = "Clear All Logs",
                desc        = "Clear all buffered debug logs across every source.",
                confirm     = true,
                confirmText = "Clear all debug logs? This cannot be undone.",
                func        = function()
                    local console = GetDebugConsole()
                    if console and console.ClearLogs then
                        console:ClearLogs()
                    end
                    ConfigurationModule:Refresh()
                end,
            },
        }),
        profiler = W.IGroup(15, "Profiler", {
            memoryEnabled = {
                type = "toggle",
                order = 0,
                name = "Enable Memory Metrics",
                desc =
                "Track per-call memory deltas (KB) during profiling sessions. This is separate from the session memory growth watcher.",
                get = function()
                    local profiler = GetProfiler()
                    return profiler and profiler.IsMemoryProfilingEnabled and profiler.IsMemoryProfilingEnabled() or
                        false
                end,
                set = function(_, value)
                    local profiler = GetProfiler()
                    if profiler and profiler.SetMemoryProfilingEnabled then
                        profiler.SetMemoryProfilingEnabled(value == true)
                    end
                end,
            },
            memorySampleInterval = {
                type = "range",
                order = 5,
                name = "Memory Sample Interval",
                desc =
                "How often the profiler snapshots total TwichUI memory while profiling. Lower gives better leak visibility with slightly more overhead.",
                min = 1,
                max = 60,
                step = 1,
                get = function()
                    local profiler = GetProfiler()
                    return profiler and profiler.GetMemorySampleInterval and profiler:GetMemorySampleInterval() or 5
                end,
                set = function(_, value)
                    local profiler = GetProfiler()
                    if profiler and profiler.SetMemorySampleInterval then
                        profiler:SetMemorySampleInterval(value)
                    end
                end,
            },
            start = {
                type = "execute",
                order = 10,
                name = "Start Profiling",
                desc = "Start profiling now.",
                func = function()
                    local profiler = GetProfiler()
                    if profiler and profiler.StartProfiling then
                        profiler:StartProfiling()
                    end
                end,
            },
            stop = {
                type = "execute",
                order = 11,
                name = "Stop Profiling",
                desc = "Stop profiling and keep captured data for report/export.",
                func = function()
                    local profiler = GetProfiler()
                    if profiler and profiler.StopProfiling then
                        profiler:StopProfiling()
                    end
                end,
            },
            clear = {
                type = "execute",
                order = 12,
                name = "Clear Profiling Data",
                desc = "Clear all collected profile samples.",
                confirm = true,
                confirmText = "Clear profiling data?",
                func = function()
                    local profiler = GetProfiler()
                    if profiler and profiler.ClearProfiles then
                        profiler:ClearProfiles()
                    end
                end,
            },
            status = {
                type = "description",
                order = 20,
                name = function()
                    local profiler = GetProfiler()
                    if not profiler then
                        return "|cffff9a6cProfiler unavailable.|r"
                    end
                    local active = profiler.IsActive and profiler:IsActive() == true
                    local memory = profiler.IsMemoryProfilingEnabled and profiler.IsMemoryProfilingEnabled() == true
                    local profileData = profiler.GetProfileData and profiler:GetProfileData() or nil
                    local count = profileData and profileData.totalProfiles or 0
                    local summary = profileData and profileData.memorySummary or nil
                    local growth = summary and summary.growthKB or 0
                    local samples = summary and summary.sampleCount or 0
                    local interval = profiler.GetMemorySampleInterval and profiler:GetMemorySampleInterval() or 5
                    return string.format(
                        "Status: %s | Call Memory: %s | Profiles: %d | Growth: %+0.2f MB | Samples: %d @ %ss",
                        active and "|cff69b86fACTIVE|r" or "|cffff9a6cINACTIVE|r",
                        memory and "|cff69b86fON|r" or "|cffff9a6cOFF|r",
                        count,
                        (growth or 0) / 1024,
                        samples,
                        tostring(interval))
                end,
            },
        }),
        sources  = W.IGroup(20, "Registered Sources", {
            list = {
                type  = "description",
                order = 0,
                name  = function()
                    local console = GetDebugConsole()
                    if not console then
                        return "|cffff9a6cDebug Console not loaded.|r"
                    end
                    local keys = console:GetSortedSourceKeys()
                    if not keys or #keys == 0 then
                        return "|cff69b86fNo debug sources registered yet.|r"
                    end
                    local out = {}
                    for _, k in ipairs(keys) do
                        local src = console.sources[k]
                        local title = src and src.title or k
                        table.insert(out, string.format("• %s  |cff888888(%s)|r", title, k))
                    end
                    return table.concat(out, "\n")
                end,
            },
        }),
    }

    return section
end

ConfigurationModule:RegisterConfigurationFunction("Debugger", BuildDebugConsoleConfiguration)
