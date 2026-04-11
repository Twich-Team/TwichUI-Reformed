--[[
    TwichUI Profiler
    Provides performance profiling for addon functions and modules.
    Tracks execution time, call counts, memory usage, and generates reports.
]]

local function GetT()
    if not _G.TwichRx then return nil end
    return unpack(_G.TwichRx)
end

local C_AddOns = _G.C_AddOns
local CreateFrame = _G.CreateFrame
local GetAddOnMemoryUsage = _G.GetAddOnMemoryUsage

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
local includeMemoryMetrics = false
local unpackCompat = _G.unpack
local UpdateAddOnMemoryUsage = _G.UpdateAddOnMemoryUsage

local ADDON_NAME = "TwichUI_Reformed"
local DEFAULT_MEMORY_SAMPLE_INTERVAL = 5
local MAX_MEMORY_SAMPLES = 360

local EXCLUDED_METHODS = {
    OnInitialize = true,
    OnEnable = true,
    OnDisable = true,
    Enable = true,
    Disable = true,
    NewModule = true,
    GetModule = true,
    IterateModules = true,
    IterateEmbeds = true,
    RegisterEvent = true,
    UnregisterEvent = true,
    RegisterMessage = true,
    UnregisterMessage = true,
    Hook = true,
    RawHook = true,
    SecureHook = true,
    HookScript = true,
    Unhook = true,
    UnhookAll = true,
    ScheduleTimer = true,
    ScheduleRepeatingTimer = true,
    CancelTimer = true,
    CancelAllTimers = true,
    Print = true,
}

local memorySamples = {}
local memorySummary = {
    baselineAddonKB = 0,
    currentAddonKB = 0,
    peakAddonKB = 0,
    growthKB = 0,
    largestSpikeKB = 0,
    lastDeltaKB = 0,
    baselineLuaKB = 0,
    currentLuaKB = 0,
    peakLuaKB = 0,
    peakTimeMs = 0,
    sampleCount = 0,
}
local memoryWatchFrame
local memorySampleElapsed = 0
local memorySampleInterval = DEFAULT_MEMORY_SAMPLE_INTERVAL
local addOnMemoryIndex

local function GetProfilerDB()
    T = T or GetT()
    if not T or not T.db or not T.db.profile then
        return nil
    end

    T.db.profile.profiler = T.db.profile.profiler or {}
    local db = T.db.profile.profiler
    if db.includeMemoryMetrics == nil then
        db.includeMemoryMetrics = false
    end
    if type(db.memorySampleInterval) ~= "number" or db.memorySampleInterval < 1 then
        db.memorySampleInterval = DEFAULT_MEMORY_SAMPLE_INTERVAL
    end

    return db
end

local function ResolveAddOnMemoryIndex()
    if addOnMemoryIndex then
        return addOnMemoryIndex
    end

    if not (C_AddOns and C_AddOns.GetNumAddOns and C_AddOns.GetAddOnInfo) then
        return nil
    end

    local count = C_AddOns.GetNumAddOns()
    for index = 1, count do
        local name = C_AddOns.GetAddOnInfo(index)
        if name == ADDON_NAME then
            addOnMemoryIndex = index
            return index
        end
    end

    return nil
end

local function GetCurrentMemoryUsage()
    local addonKB = nil
    if type(UpdateAddOnMemoryUsage) == "function" then
        UpdateAddOnMemoryUsage()
    end

    if type(GetAddOnMemoryUsage) == "function" then
        local byName = GetAddOnMemoryUsage(ADDON_NAME)
        if type(byName) == "number" then
            addonKB = byName
        end

        if addonKB == nil then
            local index = ResolveAddOnMemoryIndex()
            if index then
                addonKB = GetAddOnMemoryUsage(index)
            end
        end
    end

    return {
        addonKB = tonumber(addonKB) or 0,
        luaKB = tonumber(collectgarbage("count")) or 0,
    }
end

local function ResetMemoryTracking()
    memorySamples = {}
    memorySummary = {
        baselineAddonKB = 0,
        currentAddonKB = 0,
        peakAddonKB = 0,
        growthKB = 0,
        largestSpikeKB = 0,
        lastDeltaKB = 0,
        baselineLuaKB = 0,
        currentLuaKB = 0,
        peakLuaKB = 0,
        peakTimeMs = 0,
        peakLuaTimeMs = 0,
        sampleCount = 0,
        sampleInterval = memorySampleInterval,
        durationMs = 0,
        lastReason = nil,
    }
    memorySampleElapsed = 0
end

local function CaptureMemorySample(reason, nowMs)
    local usage = GetCurrentMemoryUsage()
    local currentTimeMs = nowMs or debugprofilestop()
    local elapsedMs = profilingStartTime > 0 and math.max(0, currentTimeMs - profilingStartTime) or 0
    local previous = memorySamples[#memorySamples]

    local sample = {
        reason = reason or "tick",
        timeMs = elapsedMs,
        addonKB = usage.addonKB,
        luaKB = usage.luaKB,
        deltaFromPreviousKB = previous and (usage.addonKB - previous.addonKB) or 0,
        deltaFromStartKB = 0,
    }

    if #memorySamples == 0 then
        memorySummary.baselineAddonKB = usage.addonKB
        memorySummary.baselineLuaKB = usage.luaKB
    end

    sample.deltaFromStartKB = usage.addonKB - (memorySummary.baselineAddonKB or usage.addonKB)

    table.insert(memorySamples, sample)
    while #memorySamples > MAX_MEMORY_SAMPLES do
        table.remove(memorySamples, 1)
    end

    memorySummary.currentAddonKB = usage.addonKB
    memorySummary.currentLuaKB = usage.luaKB
    memorySummary.growthKB = sample.deltaFromStartKB
    memorySummary.lastDeltaKB = sample.deltaFromPreviousKB
    memorySummary.sampleCount = #memorySamples
    memorySummary.sampleInterval = memorySampleInterval
    memorySummary.durationMs = elapsedMs
    memorySummary.lastReason = sample.reason

    if usage.addonKB >= (memorySummary.peakAddonKB or 0) then
        memorySummary.peakAddonKB = usage.addonKB
        memorySummary.peakTimeMs = elapsedMs
    end
    if usage.luaKB >= (memorySummary.peakLuaKB or 0) then
        memorySummary.peakLuaKB = usage.luaKB
        memorySummary.peakLuaTimeMs = elapsedMs
    end
    if sample.deltaFromPreviousKB > (memorySummary.largestSpikeKB or 0) then
        memorySummary.largestSpikeKB = sample.deltaFromPreviousKB
        memorySummary.largestSpikeTimeMs = elapsedMs
    end

    return sample
end

local function StopMemoryWatcher()
    if memoryWatchFrame then
        memoryWatchFrame:SetScript("OnUpdate", nil)
        memoryWatchFrame:Hide()
    end
    memorySampleElapsed = 0
end

local function StartMemoryWatcher()
    StopMemoryWatcher()

    if not isProfilingActive then
        return
    end

    if not memoryWatchFrame then
        memoryWatchFrame = CreateFrame("Frame")
    end

    memoryWatchFrame:Show()
    memoryWatchFrame:SetScript("OnUpdate", function(_, elapsed)
        memorySampleElapsed = memorySampleElapsed + elapsed
        if memorySampleElapsed < memorySampleInterval then
            return
        end

        memorySampleElapsed = 0
        CaptureMemorySample("tick")
    end)
end

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
        startMemory = includeMemoryMetrics and collectgarbage("count") or nil,
    }

    table.insert(activeScopeStack, scope)
    return scope
end

local function CaptureWrappedFailure(context, detail, stackLevel)
    T = T or GetT()
    local errorLog = T and T.Tools and T.Tools.ErrorLog
    if errorLog and type(errorLog.CaptureFailure) == "function" then
        errorLog:CaptureFailure(context, detail, stackLevel or 4)
    end
end

---End a profiling scope and record metrics
---@param scope ProfilingScope
local function EndScope(scope)
    if not scope or not isProfilingActive then
        return
    end

    local endTime = debugprofilestop()
    local endMemory = (includeMemoryMetrics and scope.startMemory ~= nil) and collectgarbage("count") or nil
    local elapsed = endTime - scope.startTime
    local memoryDelta = (endMemory and scope.startMemory) and (endMemory - scope.startMemory) or nil

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
            memoryCallCount = 0,
            memoryTotalDelta = 0,
            memoryAverageDelta = 0,
            memoryMinDelta = nil,
            memoryMaxDelta = nil,
            memoryLastDelta = nil,
        }
        profileData[scope.name] = profile
    end

    profile.callCount = profile.callCount + 1
    profile.totalTime = profile.totalTime + elapsed
    profile.minTime = math.min(profile.minTime, elapsed)
    profile.maxTime = math.max(profile.maxTime, elapsed)
    profile.averageTime = profile.totalTime / profile.callCount
    profile.lastCallTime = elapsed

    if memoryDelta ~= nil then
        profile.memoryCallCount = (profile.memoryCallCount or 0) + 1
        profile.memoryTotalDelta = (profile.memoryTotalDelta or 0) + memoryDelta
        profile.memoryAverageDelta = profile.memoryTotalDelta / profile.memoryCallCount
        profile.memoryMinDelta = (profile.memoryMinDelta == nil) and memoryDelta or
            math.min(profile.memoryMinDelta, memoryDelta)
        profile.memoryMaxDelta = (profile.memoryMaxDelta == nil) and memoryDelta or
            math.max(profile.memoryMaxDelta, memoryDelta)
        profile.memoryLastDelta = memoryDelta
        profile.memoryBefore = profile.memoryBefore or scope.startMemory
        profile.memoryAfter = endMemory
    end

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
        local results = { pcall(func, ...) }
        EndScope(scope)

        if not results[1] then
            CaptureWrappedFailure(functionName, results[2], 4)
            error(results[2], 0)
        end

        return unpackCompat(results, 2)
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
            if not hookedFunctions[profileName] then
                -- Create a wrapper that properly preserves the self context for methods
                local wrappedFunc = function(self, ...)
                    if not isProfilingActive then
                        return originalFunc(self, ...)
                    end

                    local scope = BeginScope(profileName)
                    local results = { pcall(originalFunc, self, ...) }
                    EndScope(scope)

                    if not results[1] then
                        CaptureWrappedFailure(profileName, results[2], 4)
                        error(results[2], 0)
                    end

                    return unpackCompat(results, 2)
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
end

local function ShouldProfileMethod(funcName, func)
    if type(func) ~= "function" then
        return false
    end
    if type(funcName) ~= "string" then
        return false
    end
    if funcName:match("^_") or funcName:match("^__") then
        return false
    end
    if EXCLUDED_METHODS[funcName] then
        return false
    end
    return true
end

local function DiscoverModulesForProfiling()
    local discovered = {}
    if not T or type(T.IterateModules) ~= "function" then
        return discovered
    end

    local seen = {}
    local queue = {}

    local function enqueue(module, path)
        if not module or seen[module] then
            return
        end
        seen[module] = true
        table.insert(discovered, { name = path, object = module })
        table.insert(queue, { module = module, path = path })
    end

    local rootName = (T.GetName and T:GetName()) or "TwichUI"
    enqueue(T, rootName)

    for _, module in T:IterateModules() do
        local moduleName = module.moduleName or module.name or tostring(module)
        enqueue(module, rootName .. "." .. tostring(moduleName))
    end

    while #queue > 0 do
        local node = table.remove(queue, 1)
        local module = node.module
        if type(module.IterateModules) == "function" then
            for _, child in module:IterateModules() do
                local childName = child.moduleName or child.name or tostring(child)
                enqueue(child, node.path .. "." .. tostring(childName))
            end
        end
    end

    return discovered
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
    ResetMemoryTracking()
    isProfilingActive = true
    profilingStartTime = debugprofilestop()
    CaptureMemorySample("start", profilingStartTime)
    StartMemoryWatcher()

    -- Use T that we already verified is available
    if not T.GetModule then
        T:Print("[TwichUI] Profiler error: T.GetModule not available. Profiling disabled.")
        isProfilingActive = false
        return
    end

    local modulesToProfile = DiscoverModulesForProfiling()
    local registeredCount = #modulesToProfile
    local wrappedCount = 0
    local skippedMethods = 0

    for _, entry in ipairs(modulesToProfile) do
        local functionNames = {}
        for methodName, method in pairs(entry.object) do
            if ShouldProfileMethod(methodName, method) then
                table.insert(functionNames, methodName)
            else
                skippedMethods = skippedMethods + 1
            end
        end
        if #functionNames > 0 then
            RegisterModuleForProfiling(entry.name, entry.object, functionNames)
            wrappedCount = wrappedCount + #functionNames
        end
    end

    local uniqueWrappedCount = 0
    for _ in pairs(hookedFunctions) do
        uniqueWrappedCount = uniqueWrappedCount + 1
    end

    if uniqueWrappedCount == 0 then
        T:Print(string.format(
            "[TwichUI] Profiling initialized with %d modules, but no profile-safe methods found to wrap.",
            registeredCount))
        T:Print("[TwichUI] Try '/tui profile report' to view any manually-scoped data.")
    else
        T:Print(string.format("[TwichUI] Profiling started. %d modules discovered, %d methods wrapped.",
            registeredCount, uniqueWrappedCount))
        if skippedMethods > 0 then
            T:Print(string.format("[TwichUI] %d methods skipped (lifecycle/private/unsafe).", skippedMethods))
        end
    end

    if includeMemoryMetrics then
        T:Print("[TwichUI] Memory metrics: |cff69b86fENABLED|r")
    else
        T:Print("[TwichUI] Memory metrics: |cffff9a6cDISABLED|r")
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
    CaptureMemorySample("stop")
    StopMemoryWatcher()
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
        if (memorySummary.sampleCount or 0) == 0 then
            return "No profiling data collected."
        end
    end

    local lines = {
        "",
        "╔════════════════════════════════════════════════════════════════════════════════╗",
        "║                         TWICHUI PROFILING REPORT                               ║",
        "╚════════════════════════════════════════════════════════════════════════════════╝",
        "",
        includeMemoryMetrics
        and string.format("%-32s | %8s | %10s | %10s | %10s | %10s | %10s",
            "Function Name", "Calls", "Total (ms)", "Avg (ms)", "Max (ms)", "MemAvg(KB)", "MemMax(KB)")
        or string.format("%-40s | %8s | %10s | %10s | %10s",
            "Function Name", "Calls", "Total (ms)", "Avg (ms)", "Max (ms)"),
        includeMemoryMetrics and string.rep("─", 108) or string.rep("─", 95),
    }

    if (memorySummary.sampleCount or 0) > 0 then
        table.insert(lines, string.format(
            "Memory Growth: start %.2f MB | current %.2f MB | peak %.2f MB | growth %+0.2f MB | largest spike %+0.2f MB | samples %d @ %ss",
            (memorySummary.baselineAddonKB or 0) / 1024,
            (memorySummary.currentAddonKB or 0) / 1024,
            (memorySummary.peakAddonKB or 0) / 1024,
            (memorySummary.growthKB or 0) / 1024,
            (memorySummary.largestSpikeKB or 0) / 1024,
            memorySummary.sampleCount or 0,
            tostring(memorySummary.sampleInterval or DEFAULT_MEMORY_SAMPLE_INTERVAL)
        ))
        table.insert(lines, string.format(
            "Lua Heap: start %.2f MB | current %.2f MB | peak %.2f MB",
            (memorySummary.baselineLuaKB or 0) / 1024,
            (memorySummary.currentLuaKB or 0) / 1024,
            (memorySummary.peakLuaKB or 0) / 1024
        ))
        table.insert(lines, "")
    end

    -- Sort by total time (descending)
    local sorted = {}
    for _, profile in pairs(profileData) do
        table.insert(sorted, profile)
    end
    table.sort(sorted, function(a, b) return a.totalTime > b.totalTime end)

    for _, profile in ipairs(sorted) do
        if includeMemoryMetrics then
            table.insert(lines, string.format("%-32s | %8d | %10.3f | %10.3f | %10.3f | %10.3f | %10.3f",
                profile.name:sub(1, 32),
                profile.callCount,
                profile.totalTime,
                profile.averageTime,
                profile.maxTime,
                profile.memoryAverageDelta or 0,
                profile.memoryMaxDelta or 0))
        else
            table.insert(lines, string.format("%-40s | %8d | %10.3f | %10.3f | %10.3f",
                profile.name:sub(1, 40),
                profile.callCount,
                profile.totalTime,
                profile.averageTime,
                profile.maxTime))
        end
    end

    if includeMemoryMetrics then
        local memorySuspects = {}
        for _, profile in ipairs(sorted) do
            local memoryNet = ((profile.memoryAfter or 0) - (profile.memoryBefore or 0))
            if memoryNet > 0 then
                table.insert(memorySuspects, {
                    profile = profile,
                    memoryNet = memoryNet,
                })
            end
        end
        table.sort(memorySuspects, function(a, b)
            if a.memoryNet == b.memoryNet then
                return (a.profile.memoryMaxDelta or 0) > (b.profile.memoryMaxDelta or 0)
            end
            return a.memoryNet > b.memoryNet
        end)

        table.insert(lines, "")
        table.insert(lines, "Top Memory Growth Suspects (retained net KB):")
        if #memorySuspects == 0 then
            table.insert(lines, "  None recorded yet.")
        else
            for index = 1, math.min(10, #memorySuspects) do
                local entry = memorySuspects[index]
                local profile = entry.profile
                table.insert(lines, string.format(
                    "  %d. %-32s | net %+10.3f KB | max %+10.3f KB | avg %+10.3f KB | calls %d",
                    index,
                    profile.name:sub(1, 32),
                    entry.memoryNet,
                    profile.memoryMaxDelta or 0,
                    profile.memoryAverageDelta or 0,
                    profile.callCount or 0
                ))
            end
        end
    end

    table.insert(lines, "")
    return table.concat(lines, "\n")
end

local function AppendMemorySummaryExportLines(lines)
    if not lines or (memorySummary.sampleCount or 0) <= 0 then
        return
    end

    table.insert(lines, string.format(
        "-- Memory growth summary: start %.2f MB | current %.2f MB | peak %.2f MB | growth %+0.2f MB | spike %+0.2f MB | samples %d @ %ss",
        (memorySummary.baselineAddonKB or 0) / 1024,
        (memorySummary.currentAddonKB or 0) / 1024,
        (memorySummary.peakAddonKB or 0) / 1024,
        (memorySummary.growthKB or 0) / 1024,
        (memorySummary.largestSpikeKB or 0) / 1024,
        memorySummary.sampleCount or 0,
        tostring(memorySummary.sampleInterval or DEFAULT_MEMORY_SAMPLE_INTERVAL)
    ))
    table.insert(lines, string.format(
        "-- Lua heap summary: start %.2f MB | current %.2f MB | peak %.2f MB",
        (memorySummary.baselineLuaKB or 0) / 1024,
        (memorySummary.currentLuaKB or 0) / 1024,
        (memorySummary.peakLuaKB or 0) / 1024
    ))
    table.insert(lines, string.format(
        "-- Memory timing: peak at %.2fs | largest spike at %.2fs",
        (memorySummary.peakTimeMs or 0) / 1000,
        (memorySummary.largestSpikeTimeMs or 0) / 1000
    ))
end

local function AppendMemorySuspectExportLines(lines)
    if not lines or not includeMemoryMetrics then
        return
    end

    local memorySuspects = {}
    for _, profile in pairs(profileData) do
        local memoryNet = ((profile.memoryAfter or 0) - (profile.memoryBefore or 0))
        if memoryNet > 0 then
            table.insert(memorySuspects, {
                profile = profile,
                memoryNet = memoryNet,
            })
        end
    end

    table.sort(memorySuspects, function(a, b)
        if a.memoryNet == b.memoryNet then
            return (a.profile.memoryMaxDelta or 0) > (b.profile.memoryMaxDelta or 0)
        end
        return a.memoryNet > b.memoryNet
    end)

    table.insert(lines, "-- Top retained-memory suspects:")
    if #memorySuspects == 0 then
        table.insert(lines, "-- None recorded yet")
        return
    end

    for index = 1, math.min(10, #memorySuspects) do
        local entry = memorySuspects[index]
        local profile = entry.profile
        table.insert(lines, string.format(
            "-- %d. %s: net %+0.3f KB | max %+0.3f KB | avg %+0.3f KB | calls %d",
            index,
            profile.name,
            entry.memoryNet,
            profile.memoryMaxDelta or 0,
            profile.memoryAverageDelta or 0,
            profile.callCount or 0
        ))
    end
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
        "-- Memory profiling: " .. (includeMemoryMetrics and "enabled" or "disabled"),
        "-- Memory sample interval: " .. tostring(memorySampleInterval) .. "s",
    }

    AppendMemorySummaryExportLines(lines)
    table.insert(lines, "")
    table.insert(lines, "local profilingData = {")

    if (memorySummary.sampleCount or 0) > 0 then
        table.insert(lines, string.format(
            '    memorySummary = { baselineAddonKB = %.3f, currentAddonKB = %.3f, peakAddonKB = %.3f, growthKB = %.3f, largestSpikeKB = %.3f, baselineLuaKB = %.3f, currentLuaKB = %.3f, peakLuaKB = %.3f, sampleCount = %d, sampleInterval = %d },',
            memorySummary.baselineAddonKB or 0,
            memorySummary.currentAddonKB or 0,
            memorySummary.peakAddonKB or 0,
            memorySummary.growthKB or 0,
            memorySummary.largestSpikeKB or 0,
            memorySummary.baselineLuaKB or 0,
            memorySummary.currentLuaKB or 0,
            memorySummary.peakLuaKB or 0,
            memorySummary.sampleCount or 0,
            memorySummary.sampleInterval or DEFAULT_MEMORY_SAMPLE_INTERVAL
        ))
        table.insert(lines, "    memorySamples = {")
        local startIndex = math.max(1, #memorySamples - 59)
        for index = startIndex, #memorySamples do
            local sample = memorySamples[index]
            if sample then
                table.insert(lines, string.format(
                    '        { t = %.0f, addonKB = %.3f, luaKB = %.3f, deltaStartKB = %.3f, deltaPrevKB = %.3f, reason = "%s" },',
                    sample.timeMs or 0,
                    sample.addonKB or 0,
                    sample.luaKB or 0,
                    sample.deltaFromStartKB or 0,
                    sample.deltaFromPreviousKB or 0,
                    tostring(sample.reason or "tick")
                ))
            end
        end
        table.insert(lines, "    },")
    end

    for name, profile in pairs(profileData) do
        if includeMemoryMetrics then
            table.insert(lines, string.format(
                '    ["%s"] = { calls = %d, total = %.3f, avg = %.3f, min = %.3f, max = %.3f, last = %.3f, memTotal = %.3f, memAvg = %.3f, memMin = %.3f, memMax = %.3f, memLast = %.3f, memNet = %.3f },',
                name,
                profile.callCount,
                profile.totalTime,
                profile.averageTime,
                profile.minTime,
                profile.maxTime,
                profile.lastCallTime,
                profile.memoryTotalDelta or 0,
                profile.memoryAverageDelta or 0,
                profile.memoryMinDelta or 0,
                profile.memoryMaxDelta or 0,
                profile.memoryLastDelta or 0,
                ((profile.memoryAfter or 0) - (profile.memoryBefore or 0))
            ))
        else
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

    if includeMemoryMetrics then
        table.insert(lines, "")
        AppendMemorySuspectExportLines(lines)
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
        memoryProfilingEnabled = includeMemoryMetrics,
        memorySampleInterval = memorySampleInterval,
        totalProfiles = #sorted,
        profiles = sorted,
        memorySummary = memorySummary,
        memorySamples = memorySamples,
        timestamp = date("%Y-%m-%d %H:%M:%S"),
    }
end

local function SetMemoryProfilingEnabled(selfOrEnabled, maybeEnabled)
    local enabled = (maybeEnabled ~= nil) and maybeEnabled or selfOrEnabled
    includeMemoryMetrics = enabled == true
    local db = GetProfilerDB()
    if db then
        db.includeMemoryMetrics = includeMemoryMetrics
    end
    T = T or GetT()
    if T and T.Print then
        T:Print(string.format("[TwichUI] Profiler memory metrics %s.", includeMemoryMetrics and "enabled" or "disabled"))
        if isProfilingActive then
            T:Print(
                "[TwichUI] Note: setting applies to new scope samples immediately; restart profiling for a clean comparison run.")
        end
    end
end

local function IsMemoryProfilingEnabled()
    return includeMemoryMetrics == true
end

local function SetMemorySampleInterval(selfOrValue, maybeValue)
    local value = tonumber((maybeValue ~= nil) and maybeValue or selfOrValue) or DEFAULT_MEMORY_SAMPLE_INTERVAL
    value = math.max(1, math.min(60, math.floor(value + 0.5)))
    memorySampleInterval = value
    memorySummary.sampleInterval = value

    local db = GetProfilerDB()
    if db then
        db.memorySampleInterval = value
    end

    if isProfilingActive then
        StartMemoryWatcher()
    end

    T = T or GetT()
    if T and T.Print then
        T:Print(string.format("[TwichUI] Profiler memory sample interval set to %ds.", value))
    end
end

local function GetMemorySampleInterval()
    return memorySampleInterval
end

local function GetMemorySummary()
    return memorySummary
end

local function GetMemorySamples()
    return memorySamples
end

local function CaptureMemorySnapshot(label)
    if isProfilingActive then
        return CaptureMemorySample(label or "manual")
    end

    local usage = GetCurrentMemoryUsage()
    return {
        reason = label or "manual",
        timeMs = 0,
        addonKB = usage.addonKB,
        luaKB = usage.luaKB,
        deltaFromStartKB = 0,
        deltaFromPreviousKB = 0,
    }
end

---Clear all profiling data
local function ClearProfiles()
    profileData = {}
    activeScopeStack = {}
    ResetMemoryTracking()
    StopMemoryWatcher()
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
    SetMemoryProfilingEnabled = SetMemoryProfilingEnabled,
    IsMemoryProfilingEnabled = IsMemoryProfilingEnabled,
    SetMemorySampleInterval = SetMemorySampleInterval,
    GetMemorySampleInterval = GetMemorySampleInterval,
    GetMemorySummary = GetMemorySummary,
    GetMemorySamples = GetMemorySamples,
    CaptureMemorySnapshot = CaptureMemorySnapshot,
    GetCurrentMemoryUsage = GetCurrentMemoryUsage,
}

-- Lazy initialization of T and attachment
local function InitializeProfiler()
    T = T or GetT()
    if not T or not T.Tools then return end

    local db = GetProfilerDB()
    if db then
        includeMemoryMetrics = db.includeMemoryMetrics == true
        memorySampleInterval = math.max(1,
            math.min(60, math.floor((db.memorySampleInterval or DEFAULT_MEMORY_SAMPLE_INTERVAL) + 0.5)))
    end

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
