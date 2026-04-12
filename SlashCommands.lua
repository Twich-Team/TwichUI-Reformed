--[[
    Contains slash command logic for the addon.
]]
---@type TwichUI
local TwichRx = _G.TwichRx
local T = unpack(TwichRx)

local function GetUnitFramesModule()
    return T:GetModule("UnitFrames", true)
end

local function OpenConfigurationPanel(input)
    local command = type(input) == "string" and input:match("^%s*(.-)%s*$") or ""
    local primaryCommand, remainder = command:match("^(%S+)%s*(.-)%s*$")
    primaryCommand = primaryCommand or ""
    remainder = remainder or ""

    if primaryCommand == "chores" then
        ---@type DataTextModule
        local datatextModule = T:GetModule("Datatexts")
        ---@type ChoresDataText|nil
        ---@diagnostic disable-next-line: undefined-field
        local choresDataText = datatextModule and datatextModule.GetModule and
            datatextModule:GetModule("ChoresDataText", true)
        if choresDataText and choresDataText.ShowTrackerFrame then
            choresDataText:ShowTrackerFrame()
            return
        end

        T:Print("[TwichUI] Chores tracker is unavailable")
        return
    end

    if primaryCommand == "debug" then
        local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
        if not console or type(console.Show) ~= "function" then
            T:Print("[TwichUI] Debug console is unavailable")
            return
        end

        if remainder ~= "" and not console:ResolveSourceKey(remainder) then
            local available = console:ListSourceTitles()
            if #available > 0 then
                T:Print("[TwichUI] Unknown debug source. Available sources: " .. table.concat(available, ", "))
            else
                T:Print("[TwichUI] No debug sources are registered")
            end
            return
        end

        console:Show(remainder ~= "" and remainder or nil)
        return
    end

    if primaryCommand == "wizard" then
        ---@type SetupWizardModule
        local SetupWizardModule = T:GetModule("SetupWizard", true)
        if not SetupWizardModule then
            T:Print("[TwichUI] Setup wizard is unavailable")
            return
        end

        local subCmd, subArgs = remainder:match("^(%S+)%s*(.-)%s*$")
        subCmd = subCmd or ""

        if subCmd == "capture" then
            -- /tui wizard capture [layoutId] [layoutName]
            local layoutId, layoutName = subArgs:match("^(%S+)%s*(.-)%s*$")
            SetupWizardModule:CaptureLayoutFrames(layoutId, layoutName)
            return
        end

        if subCmd == "reset" then
            SetupWizardModule:Reset()
            T:Print("[TwichUI] Setup wizard reset — it will appear on next login.")
            return
        end

        -- Default: show wizard
        SetupWizardModule:Show()
        return
    end

    if primaryCommand == "errors" then
        if remainder == "test" then
            local el = T.Tools and (T.Tools --[[@as any]]).ErrorLog --[[@as TwichUIErrorLog|nil]]
            if not el then
                T:Print("[TwichUI] Error log is unavailable")
                return
            end
            local fakeStack =
                "Interface\\AddOns\\TwichUI_Reformed\\Modules\\ChatEnhancements\\ChatRenderer.lua:1183: attempt to index a nil value (field 'settings')\n" ..
                "stack traceback:\n" ..
                "\tInterface\\AddOns\\TwichUI_Reformed\\Modules\\ChatEnhancements\\ChatRenderer.lua:1183: in method 'RefreshRow'\n" ..
                "\tInterface\\AddOns\\TwichUI_Reformed\\Modules\\ChatEnhancements\\ChatRenderer.lua:842: in method 'LayoutRenderer'\n" ..
                "\tInterface\\AddOns\\TwichUI_Reformed\\Core.lua:95: in function <TwichUI_Reformed\\Core.lua:74>"
            el:_InjectTestError(fakeStack)
            T:Print("[TwichUI] Test error injected into log.")
            return
        end
        local viewer = T.Tools and T.Tools.UI and T.Tools.UI.ErrorLogViewer
        if not viewer then
            T:Print("[TwichUI] Error log viewer is unavailable")
            return
        end
        viewer:Toggle()
        return
    end

    if primaryCommand == "artwork" then
        local unitFrames = GetUnitFramesModule()
        if not unitFrames then
            T:Print("[TwichUI] Unit frames are unavailable")
            return
        end

        if remainder == "print" then
            if type(unitFrames.PrintPlayerClassArtworkOffsets) == "function" then
                unitFrames:PrintPlayerClassArtworkOffsets()
                return
            end

            T:Print("[TwichUI] Player class artwork tooling is unavailable")
            return
        end

        if type(unitFrames.TogglePlayerClassArtworkAlignmentMode) == "function" then
            unitFrames:TogglePlayerClassArtworkAlignmentMode()
            return
        end

        T:Print("[TwichUI] Player class artwork tooling is unavailable")
        return
    end

    if primaryCommand == "ufdebug" then
        local unitFrames = GetUnitFramesModule()
        if not unitFrames then
            T:Print("[TwichUI] Unit frames are unavailable")
            return
        end

        local subCmd, subArgs = remainder:match("^(%S+)%s*(.-)%s*$")
        subCmd = (subCmd or "status"):lower()
        subArgs = subArgs or ""

        if subCmd == "on" or subCmd == "enable" or subCmd == "start" then
            if unitFrames.SetUFDiagnosticsEnabled then
                unitFrames:SetUFDiagnosticsEnabled(true)
                T:Print("[TwichUI] UnitFrames diagnostics enabled.")
            end
        elseif subCmd == "off" or subCmd == "disable" or subCmd == "stop" then
            if unitFrames.SetUFDiagnosticsEnabled then
                unitFrames:SetUFDiagnosticsEnabled(false)
                T:Print("[TwichUI] UnitFrames diagnostics disabled.")
            end
        elseif subCmd == "once" or subCmd == "snapshot" then
            if unitFrames.UFDiagMaybeReport then
                unitFrames:UFDiagMaybeReport("manual", true)
                T:Print("[TwichUI] UnitFrames diagnostics snapshot emitted to debugger.")
            end
        elseif subCmd == "interval" then
            local seconds = tonumber(subArgs)
            if not seconds then
                T:Print("[TwichUI] Usage: /tui ufdebug interval <seconds>")
                return
            end
            if unitFrames.SetUFDiagnosticsInterval then
                unitFrames:SetUFDiagnosticsInterval(seconds)
            end
            if unitFrames.UFDiagGetStatusLine then
                T:Print("[TwichUI] " .. unitFrames:UFDiagGetStatusLine())
            end
        elseif subCmd == "delta" or subCmd == "threshold" then
            local kb = tonumber(subArgs)
            if not kb then
                T:Print("[TwichUI] Usage: /tui ufdebug delta <kb>")
                return
            end
            if unitFrames.SetUFDiagnosticsMemoryDelta then
                unitFrames:SetUFDiagnosticsMemoryDelta(kb)
            end
            if unitFrames.UFDiagGetStatusLine then
                T:Print("[TwichUI] " .. unitFrames:UFDiagGetStatusLine())
            end
        elseif subCmd == "verbose" then
            local mode = tostring(subArgs or ""):lower()
            local enabled = (mode == "1" or mode == "true" or mode == "on" or mode == "yes")
            if mode ~= "0" and mode ~= "false" and mode ~= "off" and mode ~= "no" and not enabled then
                T:Print("[TwichUI] Usage: /tui ufdebug verbose <on|off>")
                return
            end
            if unitFrames.SetUFDiagnosticsVerbose then
                unitFrames:SetUFDiagnosticsVerbose(enabled)
            end
            if unitFrames.UFDiagGetStatusLine then
                T:Print("[TwichUI] " .. unitFrames:UFDiagGetStatusLine())
            end
        else
            if unitFrames.UFDiagGetStatusLine then
                T:Print("[TwichUI] " .. unitFrames:UFDiagGetStatusLine())
            else
                T:Print("[TwichUI] UnitFrames diagnostics are unavailable.")
            end
            T:Print("[TwichUI] /tui ufdebug on|off|once|status|interval <sec>|delta <kb>|verbose <on|off>")
        end

        local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
        if console and type(console.Show) == "function" then
            console:Show("unitframes")
        end
        return
    end

    if primaryCommand == "profile" then
        local profiler = T.Tools and T.Tools.UI and T.Tools.UI.Profiler
        if not profiler then
            T:Print("[TwichUI] Profiler is unavailable")
            return
        end

        local subCmd, subArgs = remainder:match("^(%S+)%s*(.-)%s*$")
        subCmd = (subCmd and subCmd:lower()) or "status"
        subArgs = subArgs or ""

        if subCmd == "start" then
            profiler:StartProfiling()
            return
        end

        if subCmd == "stop" then
            profiler:StopProfiling()
            return
        end

        if subCmd == "report" then
            local profilerUI = T.Tools and T.Tools.UI and T.Tools.UI.ProfilerUI
            if profilerUI and type(profilerUI.Show) == "function" then
                profilerUI:Show()
            else
                T:Print(profiler:GenerateReport())
            end
            return
        end

        if subCmd == "window" or subCmd == "ui" then
            local profilerUI = T.Tools and T.Tools.UI and T.Tools.UI.ProfilerUI
            if profilerUI and type(profilerUI.Show) == "function" then
                profilerUI:Show()
            else
                T:Print("[TwichUI] Profiler UI is unavailable")
            end
            return
        end

        if subCmd == "export" then
            local exportData = profiler:ExportData()
            T:Print(exportData)
            T:Print("\n|cff69b86fProfiler data exported above. Copy and save to a file for analysis.|r")
            return
        end

        if subCmd == "memory" then
            local mode = tostring(subArgs or ""):lower()
            if mode == "" or mode == "status" then
                local enabled = profiler.IsMemoryProfilingEnabled and profiler.IsMemoryProfilingEnabled() == true
                local interval = profiler.GetMemorySampleInterval and profiler:GetMemorySampleInterval() or 5
                local summary = profiler.GetMemorySummary and profiler:GetMemorySummary() or nil
                T:Print(string.format("[TwichUI] Profiler memory metrics: %s",
                    enabled and "|cff69b86fENABLED|r" or "|cffff9a6cDISABLED|r"))
                T:Print(string.format("[TwichUI] Memory growth watcher interval: %ss", tostring(interval)))
                if summary and (summary.sampleCount or 0) > 0 then
                    T:Print(string.format(
                        "[TwichUI] AddOn memory: %.2f MB -> %.2f MB (%+.2f MB), peak %.2f MB, largest spike %+.2f MB.",
                        (summary.baselineAddonKB or 0) / 1024,
                        (summary.currentAddonKB or 0) / 1024,
                        (summary.growthKB or 0) / 1024,
                        (summary.peakAddonKB or 0) / 1024,
                        (summary.largestSpikeKB or 0) / 1024
                    ))
                end
                T:Print("Usage: /tui profile memory on|off|toggle|status|summary|snapshot|interval <seconds>")
                return
            end

            if mode == "summary" then
                local summary = profiler.GetMemorySummary and profiler:GetMemorySummary() or nil
                if not summary or (summary.sampleCount or 0) == 0 then
                    T:Print(
                        "[TwichUI] No memory growth samples collected yet. Start profiling and let it run through the scenario first.")
                    return
                end

                T:Print(string.format(
                    "[TwichUI] Memory growth summary: start %.2f MB | current %.2f MB | peak %.2f MB | growth %+.2f MB | spike %+.2f MB | samples %d @ %ss",
                    (summary.baselineAddonKB or 0) / 1024,
                    (summary.currentAddonKB or 0) / 1024,
                    (summary.peakAddonKB or 0) / 1024,
                    (summary.growthKB or 0) / 1024,
                    (summary.largestSpikeKB or 0) / 1024,
                    summary.sampleCount or 0,
                    tostring(summary.sampleInterval or 5)
                ))
                return
            end

            if mode == "snapshot" then
                local snapshot = profiler.CaptureMemorySnapshot and profiler:CaptureMemorySnapshot("manual") or nil
                if snapshot then
                    T:Print(string.format(
                        "[TwichUI] Memory snapshot: AddOn %.2f MB | Lua %.2f MB | Session delta %+.2f MB | Last delta %+.2f MB",
                        (snapshot.addonKB or 0) / 1024,
                        (snapshot.luaKB or 0) / 1024,
                        (snapshot.deltaFromStartKB or 0) / 1024,
                        (snapshot.deltaFromPreviousKB or 0) / 1024
                    ))
                end
                return
            end

            local intervalValue = mode:match("^interval%s+(%d+)$")
            if not intervalValue then
                intervalValue = remainder:match("^memory%s+interval%s+(%d+)$")
            end
            if intervalValue then
                if profiler.SetMemorySampleInterval then
                    profiler:SetMemorySampleInterval(tonumber(intervalValue))
                end
                return
            end

            if mode == "toggle" then
                local enabled = profiler.IsMemoryProfilingEnabled and profiler.IsMemoryProfilingEnabled() == true
                if profiler.SetMemoryProfilingEnabled then
                    profiler.SetMemoryProfilingEnabled(not enabled)
                end
                return
            end

            if mode == "on" or mode == "enable" then
                if profiler.SetMemoryProfilingEnabled then
                    profiler.SetMemoryProfilingEnabled(true)
                end
                return
            end

            if mode == "off" or mode == "disable" then
                if profiler.SetMemoryProfilingEnabled then
                    profiler.SetMemoryProfilingEnabled(false)
                end
                return
            end

            T:Print("[TwichUI] Usage: /tui profile memory on|off|toggle|status|summary|snapshot|interval <seconds>")
            return
        end

        if subCmd == "clear" then
            profiler:ClearProfiles()
            return
        end

        if subCmd == "status" then
            if profiler:IsActive() then
                T:Print("|cff69b86fProfiler is currently ACTIVE|r - Use '/tui profile stop' to stop profiling")
            else
                T:Print("|cffff9a6cProfiler is currently INACTIVE|r - Use '/tui profile start' to begin profiling")
            end
            if profiler.IsMemoryProfilingEnabled then
                local enabled = profiler.IsMemoryProfilingEnabled() == true
                T:Print(string.format("  memory  - %s", enabled and "enabled" or "disabled"))
            end
            T:Print("Available commands:")
            T:Print("  start   - Begin profiling")
            T:Print("  stop    - End profiling")
            T:Print("  report  - Open visual results window")
            T:Print("  window  - Same as report")
            T:Print("  export  - Copy raw data to chat")
            T:Print("  memory  - Memory metrics and growth watcher controls")
            T:Print("  clear   - Clear all profiling data")
            T:Print("  status  - Show this help")
            return
        end

        T:Print("[TwichUI] Unknown profile subcommand.")
        T:Print("Use '/tui profile status' for available commands.")
        return
    end

    if primaryCommand == "movers" then
        local moversModule = T:GetModule("Movers", true)
        if not moversModule then
            T:Print("[TwichUI] Mover system is unavailable")
            return
        end
        if remainder == "on" then
            moversModule:Activate()
        elseif remainder == "off" then
            moversModule:Deactivate()
        else
            moversModule:Toggle()
        end
        return
    end

    if primaryCommand == "npdebug" then
        local mod = T:GetModule("Nameplates", true)
        if not mod then
            T:Print("[TwichUI] Nameplates module not loaded.")
            return
        end

        local subCmd, subArgs = remainder:match("^(%S+)%s*(.-)%s*$")
        subCmd = (subCmd or ""):lower()
        subArgs = subArgs or ""

        if subCmd == "export" then
            local presetId, rawName = subArgs:match("^(%S+)%s*(.-)%s*$")
            local presetName = rawName and rawName:match('^"(.*)"$') or rawName
            if type(mod.ExportCurrentNameplatePreset) ~= "function" then
                T:Print("[TwichUI] Nameplates preset export is unavailable.")
                return
            end
            mod:ExportCurrentNameplatePreset(presetId, presetName)
            return
        end

        -- DB status
        local db = mod.GetDB and mod:GetDB()
        if db then
            T:Print(string.format("[NP] healthFormat: %s  healthFontSize: %s  healthFont: %s",
                tostring(db.healthFormat), tostring(db.healthFontSize), tostring(db.healthFont)))
            T:Print(string.format("[NP] healthTextAnchor: %s  showAbsorb: %s",
                tostring(db.healthTextAnchor), tostring(db.showAbsorb)))
        else
            T:Print("[NP] Could not read DB.")
        end

        -- Module enable state
        T:Print(string.format("[NP] Module IsEnabled: %s", tostring(mod:IsEnabled())))

        -- Plate count
        local total, visible = 0, 0
        if mod._plates then
            for _, frame in pairs(mod._plates) do
                total = total + 1
                if frame and frame:IsShown() then visible = visible + 1 end
            end
        end
        T:Print(string.format("[NP] Tracked plates: %d  Visible: %d", total, visible))

        -- First visible plate frame dump
        if mod._plates then
            for unit, frame in pairs(mod._plates) do
                if frame and frame:IsShown() then
                    T:Print(string.format("[NP] Sample plate unit: %s", tostring(unit)))
                    local ht = frame.healthText
                    if ht then
                        local font, size, flags = ht:GetFont()
                        T:Print(string.format("  healthText: IsShown=%s  Text='%s'  Points=%d  Font=%s sz=%s",
                            tostring(ht:IsShown()), tostring(ht:GetText() or ""),
                            ht:GetNumPoints(), tostring(font), tostring(size)))
                    else
                        T:Print("  healthText: NOT CREATED on this frame")
                    end
                    local hb = frame.healthBar
                    if hb then
                        T:Print(string.format("  healthBar: w=%.0f h=%.0f IsShown=%s",
                            hb:GetWidth(), hb:GetHeight(), tostring(hb:IsShown())))
                    end
                    local ab = frame.absorbBar
                    if ab then
                        T:Print(string.format("  absorbBar: IsShown=%s", tostring(ab:IsShown())))
                    end
                    break
                end
            end
        end
        return
    end

    ---@type ConfigurationModule
    local ConfigurationModule = T:GetModule("Configuration")
    ConfigurationModule:ToggleOptionsUI()
end

T:RegisterChatCommand("tui", OpenConfigurationPanel)

local function FindTexture(input)
    local f = (GetMouseFoci and GetMouseFoci()[1]) or GetMouseFocus()
    if not f then
        T:Print("[TwichUI] /findtexture: No frame under mouse")
        return
    end

    local filter = nil
    if type(input) == "string" and input ~= "" then
        filter = input:lower()
    end

    T:Print("[TwichUI] Frame:", f:GetName() or "<unnamed>")

    -- iterate all regions from GetRegions()
    local index = 1
    local found = false
    while true do
        local r = select(index, f:GetRegions())
        if not r then break end

        if r.IsObjectType and r:IsObjectType("Texture") then
            local tex = r:GetTexture()
            local atlas = r.GetAtlas and r:GetAtlas()
            if tex or atlas then
                local a, b, c, d, e, f2, g, h = r:GetTexCoord()

                local texStr = tex and tostring(tex) or ""
                local atlasStr = atlas and tostring(atlas) or ""

                if not filter or texStr:lower():find(filter, 1, true) or atlasStr:lower():find(filter, 1, true) then
                    found = true

                    if tex then
                        -- fileID or path sample
                        local numericId = tonumber(texStr)
                        if numericId then
                            T:Print(string.format("[%d] fileID=%s texCoords=%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
                                index, texStr, a or 0, b or 0, c or 0, d or 0, e or 0, f2 or 0, g or 0, h or 0))
                            T:Print(string.format("    sample: \"|T%s:16:16|t\"", texStr))
                        else
                            T:Print(string.format(
                                "[%d] texture=\"%s\" texCoords=%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
                                index, texStr, a or 0, b or 0, c or 0, d or 0, e or 0, f2 or 0, g or 0, h or 0))
                            T:Print(string.format("    sample: \"|T%s:16:16|t\"", texStr))
                        end
                    end

                    if atlas then
                        T:Print(string.format("[%d] atlas=\"%s\" texCoords=%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
                            index, atlasStr, a or 0, b or 0, c or 0, d or 0, e or 0, f2 or 0, g or 0, h or 0))
                        T:Print(string.format("    sample: \"|A:%s:16:16|a\"", atlasStr))
                    end
                end
            end
        end

        index = index + 1
    end

    if not found then
        if filter then
            print("[TwichUI] /findtexture: No textures/atlases matched filter '", filter, "'")
        else
            print("[TwichUI] /findtexture: No textures or atlases on this frame")
        end
    end
end

T:RegisterChatCommand("findtexture", FindTexture)
