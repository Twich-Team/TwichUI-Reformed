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
