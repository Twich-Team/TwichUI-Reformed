--[[
    TwichUI Profiler
    Provides performance profiling for addon functions and modules.
    Tracks execution time, call counts, memory usage, and generates reports.
]]

local function GetT()
    if not _G.TwichRx then return nil end
    return unpack(_G.TwichRx)
end

---@type TwichUI
local T

---@class Profiler
---@field isActive boolean
---@field profiles table<string, ProfileData>
---@field startTime number
---@field memorySnapshot table<string, number>
local Profiler = {}

---@class ProfileData
---@field name string
---@field callCount integer
---@field totalTime number
---@field minTime number
---@field maxTime number
---@field averageTime number
---@field memoryBefore number
---@field memoryAfter number
---@field lastCallTime number

---@class ProfilingScope
---@field name string
---@field startTime number
---@field startMemory number

local activeScopeStack = {}
local profileData = {}
local isProfilingActive = false
local profilingStartTime = 0
local hookedFunctions = {} -- Track hooked functions for cleanup

---Start a named profiling scope
---@param name string
---@return ProfilingScope|nil
local function BeginScope(name)
    if not isProfilingActive then
        return nil
    end

    local scope = {
        name = name,
        startTime = debugprofilestop(),
        startMemory = collectgarbage("count")
    }

    table.insert(activeScopeStack, scope)
    return scope
end

---End a profiling scope and record metrics
---@param scope ProfilingScope
local function EndScope(scope)
    if not scope or not isProfilingActive then
        return
    end

    local endTime = debugprofilestop()
    local endMemory = collectgarbage("count")
    local elapsed = endTime - scope.startTime
    local memoryDelta = endMemory - scope.startMemory

    local profile = profileData[scope.name]
    if not profile then
        profile = {
            name = scope.name,
            callCount = 0,
            totalTime = 0,
            minTime = math.huge,
            maxTime = 0,
            averageTime = 0,
            memoryBefore = scope.startMemory,
            memoryAfter = endMemory,
            lastCallTime = elapsed,
        }
        profileData[scope.name] = profile
    end

    profile.callCount = profile.callCount + 1
    profile.totalTime = profile.totalTime + elapsed
    profile.minTime = math.min(profile.minTime, elapsed)
    profile.maxTime = math.max(profile.maxTime, elapsed)
    profile.averageTime = profile.totalTime / profile.callCount
    profile.lastCallTime = elapsed
    profile.memoryAfter = endMemory

    -- Pop from stack
    if activeScopeStack[#activeScopeStack] == scope then
        table.remove(activeScopeStack)
    end
end

---Wrap a function with profiling
---@param functionName string
---@param func function
---@return function wrappedFunc
local function ProfileFunction(functionName, func)
    return function(...)
        if not isProfilingActive then
            return func(...)
        end

        local scope = BeginScope(functionName)
        local success, result = pcall(func, ...)
        EndScope(scope)

        if not success then
            error(result)
        end

        return result
    end
end

---Register a module or namespace for automatic profiling
---@param name string
---@param tbl table
---@param functionNames? table<string>
local function RegisterModuleForProfiling(name, tbl, functionNames)
    if not tbl then return end

    functionNames = functionNames or {}

    -- If functionNames is empty, profile all functions in the table
    if #functionNames == 0 then
        for funcName, func in pairs(tbl) do
            if type(func) == "function" and not funcName:match("^_") then
                table.insert(functionNames, funcName)
            end
        end
    end

    for _, funcName in ipairs(functionNames) do
        local originalFunc = tbl[funcName]
        if type(originalFunc) == "function" then
            local profileName = name .. ":" .. funcName

            -- Create a wrapper that properly preserves the self context for methods
            local wrappedFunc = function(self, ...)
                if not isProfilingActive then
                    return originalFunc(self, ...)
                end

                local scope = BeginScope(profileName)
                local success, result = pcall(originalFunc, self, ...)
                EndScope(scope)

                if not success then
                    error(result)
                end

                return result
            end

            -- Store original and wrapper
            hookedFunctions[profileName] = {
                original = originalFunc,
                wrapped = wrappedFunc,
                object = tbl,
                method =
                    funcName
            }
            tbl[funcName] = wrappedFunc
        end
    end
end

---Start profiling session
local function StartProfiling()
    T = T or GetT()
    if not T or not T.Print then
        print("|cffff9a6c[TwichUI] Profiler error|r: T not initialized. Please reload UI after login.")
        return
    end

    if isProfilingActive then
        T:Print("[TwichUI] Profiling is already active.")
        return
    end

    profileData = {}
    activeScopeStack = {}
    hookedFunctions = {}
    isProfilingActive = true
    profilingStartTime = debugprofilestop()

    -- Use T that we already verified is available
    if not T.GetModule then
        T:Print("[TwichUI] Profiler error: T.GetModule not available. Profiling disabled.")
        isProfilingActive = false
        return
    end

    -- Methods that are safe to auto-wrap (no problematic state dependencies)
    -- These are primarily oUF frame methods that get called on every update
    local SAFE_METHODS_TO_PROFILE = {
        -- oUF element updates
        "Update",
        "UpdateAllElements",
        "PostUpdate",
        "ForceUpdate",
        -- Unit frame specific apply methods (called on settings change)
        "ApplyColors",
        "ApplyFrameColors",
        "ApplyFontObject",
        "ApplyTextTags",
        "ApplyFrameFonts",
        "ApplyTextPositions",
        "ApplyAuraSettings",
        "ApplyClassBarSettings",
        "ApplyStatusBarTexture",
        "ApplyHealPredictionSettings",
        "ApplyRoleIconSettings",
        "ApplyStateIndicatorSettings",
        "ApplyReadyCheckIndicatorSettings",
        "ApplyInfoBarSettings",
        "ApplyCustomFrameSettings",
        -- Aura updates
        "UpdateAuraRemainingText",
        "UpdateRoleIcon",
        "UpdateStateIndicator",
        "UpdateReadyCheckIndicator",
        "UpdatePowerBarForRole",
        "RefreshAuraBarsForFrame",
        -- Refresh methods
        "Refresh",
        "RefreshStateIndicatorFrames",
        "RefreshReadyCheckIndicatorFrames",
    }

    -- Auto-register key modules for profiling
    local modulesToProfile = {
        "Datatexts",
        "UnitFrames",
        "ActionBars",
        "ChatEnhancements",
        "Chores",
    }

    local registeredCount = 0
    local wrappedCount = 0
    local failedModules = {}

    for _, moduleName in ipairs(modulesToProfile) do
        local ok, module = pcall(function()
            return T:GetModule(moduleName, true)
        end)

        if ok and module then
            registeredCount = registeredCount + 1

            -- Selectively wrap only safe methods that exist on this module
            for _, methodName in ipairs(SAFE_METHODS_TO_PROFILE) do
                if type(module[methodName]) == "function" then
                    RegisterModuleForProfiling(moduleName, module, { methodName })
                    wrappedCount = wrappedCount + 1
                end
            end
        else
            table.insert(failedModules, moduleName)
        end
    end

    if wrappedCount == 0 then
        T:Print(string.format("[TwichUI] Profiling initialized with %d modules, but no safe methods found to wrap.",
            registeredCount))
        T:Print("[TwichUI] Try '/tui profile report' to view any manually-scoped data.")
    else
        T:Print(string.format("[TwichUI] Profiling started. %d modules loaded, %d methods wrapped.", registeredCount,
            wrappedCount))
    end
end

---Stop profiling session
local function StopProfiling()
    T = T or GetT()
    if not T or not T.Print then
        print("|cffff9a6c[TwichUI] Profiler error|r: T not initialized.")
        return
    end

    if not isProfilingActive then
        T:Print("[TwichUI] Profiling is not active.")
        return
    end

    isProfilingActive = false
    local duration = debugprofilestop() - profilingStartTime

    -- Restore original functions
    for _, hookInfo in pairs(hookedFunctions) do
        hookInfo.object[hookInfo.method] = hookInfo.original
    end
    hookedFunctions = {}

    T:Print(string.format(
        "[TwichUI] Profiling stopped after %.2f ms. Use '/tui profile report' or '/tui profile export' to view results.",
        duration))
end

---Generate a formatted profiling report
---@return string report
local function GenerateReport()
    if not next(profileData) then
        return "No profiling data collected."
    end

    local lines = {
        "",
        "╔════════════════════════════════════════════════════════════════════════════════╗",
        "║                         TWICHUI PROFILING REPORT                               ║",
        "╚════════════════════════════════════════════════════════════════════════════════╝",
        "",
        string.format("%-40s | %8s | %10s | %10s | %10s",
            "Function Name", "Calls", "Total (ms)", "Avg (ms)", "Max (ms)"),
        string.rep("─", 95),
    }

    -- Sort by total time (descending)
    local sorted = {}
    for _, profile in pairs(profileData) do
        table.insert(sorted, profile)
    end
    table.sort(sorted, function(a, b) return a.totalTime > b.totalTime end)

    for _, profile in ipairs(sorted) do
        table.insert(lines, string.format("%-40s | %8d | %10.3f | %10.3f | %10.3f",
            profile.name:sub(1, 40),
            profile.callCount,
            profile.totalTime,
            profile.averageTime,
            profile.maxTime))
    end

    table.insert(lines, "")
    return table.concat(lines, "\n")
end

---Export profiling data as a formatted table
---@return string exportData
local function ExportData()
    if not next(profileData) then
        return "No profiling data to export."
    end

    local lines = {
        "-- TwichUI Profiling Data Export",
        "-- Generated: " .. date("%Y-%m-%d %H:%M:%S"),
        "-- This data can be used to identify performance bottlenecks",
        "",
        "local profilingData = {",
    }

    for name, profile in pairs(profileData) do
        table.insert(lines, string.format(
            '    ["%s"] = { calls = %d, total = %.3f, avg = %.3f, min = %.3f, max = %.3f, last = %.3f },',
            name,
            profile.callCount,
            profile.totalTime,
            profile.averageTime,
            profile.minTime,
            profile.maxTime,
            profile.lastCallTime
        ))
    end

    table.insert(lines, "}")
    table.insert(lines, "")
    table.insert(lines, "-- Top 10 most expensive functions:")

    local sorted = {}
    for _, profile in pairs(profileData) do
        table.insert(sorted, profile)
    end
    table.sort(sorted, function(a, b) return a.totalTime > b.totalTime end)

    for i, profile in ipairs(sorted) do
        if i > 10 then break end
        table.insert(lines, string.format("-- %d. %s: %.3f ms total (%d calls)",
            i,
            profile.name,
            profile.totalTime,
            profile.callCount))
    end

    return table.concat(lines, "\n")
end

---Get profiling data as a table (for Debug Console integration)
---@return table data
local function GetProfileData()
    local sorted = {}
    for _, profile in pairs(profileData) do
        table.insert(sorted, profile)
    end
    table.sort(sorted, function(a, b) return a.totalTime > b.totalTime end)

    return {
        isActive = isProfilingActive,
        totalProfiles = #sorted,
        profiles = sorted,
        timestamp = date("%Y-%m-%d %H:%M:%S"),
    }
end

---Clear all profiling data
local function ClearProfiles()
    profileData = {}
    activeScopeStack = {}
    T = T or GetT()
    if T and T.Print then
        T:Print("[TwichUI] Profiling data cleared.")
    end
end

-- Export the Profiler
---@class TwichUIProfiler
local TwichUIProfiler = {
    BeginScope = BeginScope,
    EndScope = EndScope,
    ProfileFunction = ProfileFunction,
    StartProfiling = StartProfiling,
    StopProfiling = StopProfiling,
    GenerateReport = GenerateReport,
    ExportData = ExportData,
    GetProfileData = GetProfileData,
    ClearProfiles = ClearProfiles,
    RegisterModuleForProfiling = RegisterModuleForProfiling,
    IsActive = function() return isProfilingActive end,
}

-- Lazy initialization of T and attachment
local function InitializeProfiler()
    T = T or GetT()
    if not T or not T.Tools then return end

    T.Tools = T.Tools or {}
    T.Tools.UI = T.Tools.UI or {}
    T.Tools.UI.Profiler = TwichUIProfiler
end

InitializeProfiler()

-- Register with Debug Console (also lazy)
local function RegisterDebugSource()
    T = T or GetT()
    if not T or not T.Tools then return end

    local DebugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if not DebugConsole or not DebugConsole.RegisterSource then
        return
    end

    DebugConsole:RegisterSource("profiler", {
        title = "Profiler",
        order = 15,
        aliases = { "profile", "perf", "performance" },
        buildReport = function()
            return GenerateReport()
        end,
    })
end

-- Schedule registration after DebugConsole is loaded
local function ScheduleDebugRegistration()
    T = T or GetT()
    if not T then
        return
    end

    if type(T.RegisterEvent) == "function" then
        T:RegisterEvent("PLAYER_LOGIN", RegisterDebugSource)
    end
    RegisterDebugSource()
end

ScheduleDebugRegistration()

_G.TwichUIProfiler = TwichUIProfiler
