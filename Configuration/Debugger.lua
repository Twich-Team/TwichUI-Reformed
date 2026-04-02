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

local function GetSoundTrace()
    return T.Tools and T.Tools.SoundTrace
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
        title   = W.TitleWidget(0, "Debug Console"),
        desc    = W.Description(5,
            "The TwichUI Debug Console collects diagnostic logs from internal modules. " ..
            "Open it to inspect live state, copy reports for bug reports, or clear logs."),
        actions = W.IGroup(10, "Actions", {
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
            openSounds = {
                type  = "execute",
                order = 3,
                name  = "Open Sound Trace",
                desc  = "Open the Debug Console focused on sound playback traces.",
                func  = function()
                    OpenDebugSource("sounds")
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
            clearSounds = {
                type        = "execute",
                order       = 6,
                name        = "Clear Sound Trace",
                desc        = "Clear only the sound trace entries.",
                confirm     = true,
                confirmText = "Clear the sound trace log?",
                func        = function()
                    local console = GetDebugConsole()
                    if console and console.ClearLogs then
                        console:ClearLogs("sounds")
                    end
                    ConfigurationModule:Refresh()
                end,
            },
        }),
        soundTrace = W.IGroup(15, "Sound Trace", {
            desc = W.Description(0,
                "Capture TwichUI-owned sound playback calls in the shared debug console. " ..
                "Leave this off during normal play unless you are tracking a stray sound."),
            enabled = {
                type  = "toggle",
                order = 5,
                name  = "Enable Sound Trace",
                desc  = "Log each TwichUI PlaySound and PlaySoundFile call with its caller path.",
                get   = function()
                    local soundTrace = GetSoundTrace()
                    return soundTrace and soundTrace.GetEnabled and soundTrace:GetEnabled() or false
                end,
                set   = function(_, value)
                    local soundTrace = GetSoundTrace()
                    if soundTrace and soundTrace.SetEnabled then
                        soundTrace:SetEnabled(value)
                    end
                    ConfigurationModule:Refresh()
                end,
            },
            status = {
                type  = "description",
                order = 10,
                name  = function()
                    local console = GetDebugConsole()
                    local lines = console and console.GetLines and console:GetLines("sounds") or {}
                    local soundTrace = GetSoundTrace()
                    local enabled = soundTrace and soundTrace.GetEnabled and soundTrace:GetEnabled() or false
                    if enabled then
                        return string.format("|cff69b86fSound trace enabled.|r %d entr%s buffered.", #lines, #lines == 1 and "y" or "ies")
                    end
                    return string.format("|cffff9a6cSound trace disabled.|r %d entr%s currently buffered.", #lines, #lines == 1 and "y" or "ies")
                end,
            },
        }),
        sources = W.IGroup(20, "Registered Sources", {
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
