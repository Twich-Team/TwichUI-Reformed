--[[
    Error Log configuration section.
    Shows error count, max-size setting, and buttons to open the viewer or clear the log.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)
local LibStub = _G.LibStub

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

local DEFAULT_SOUND = "TwichUI Alert 1"

local function GetSoundValues()
    local lsm = (T.Libs and T.Libs.LSM) or (LibStub and LibStub("LibSharedMedia-3.0", true))
    return lsm and lsm:HashTable("sound") or {}
end

local function GetErrorLog()
    ---@type TwichUIErrorLog|nil
    return T.Tools and (T.Tools --[[@as any]]).ErrorLog
end

local function GetViewer()
    return T.Tools and T.Tools.UI and (T.Tools.UI --[[@as any]]).ErrorLogViewer
end

local function BuildErrorLogConfiguration()
    local W = ConfigurationModule.Widgets

    local section = W.NewConfigurationSection(95, "Error Log")
    section.childGroups = nil
    section.args = {
        title         = W.TitleWidget(0, "Error Log"),
        desc          = W.Description(5,
            "TwichUI captures unhandled Lua errors from its own code and keeps a rolling log. " ..
            "Use the viewer to inspect them and copy details for bug reports."),
        status        = W.IGroup(10, "Status", {
            count = {
                type  = "description",
                order = 0,
                name  = function()
                    local el = GetErrorLog()
                    local n  = el and el:GetCount() or 0
                    if n == 0 then
                        return "|cff69b86fNo errors captured.|r"
                    else
                        return string.format("|cffff9a6c%d error%s captured.|r", n, n == 1 and "" or "s")
                    end
                end,
            },
        }),
        notifications = W.IGroup(15, "Notifications", {
            suppressChatOutput = {
                type = "toggle",
                order = 10,
                name = "Hide Chat Output",
                desc = "Do not print a chat message when TwichUI captures a new error.",
                get = function()
                    local el = GetErrorLog()
                    return el and el:GetSuppressChatOutput() or false
                end,
                set = function(_, value)
                    local el = GetErrorLog()
                    if el then el:SetSuppressChatOutput(value) end
                end,
            },
            playAlertSound = {
                type = "toggle",
                order = 20,
                name = "Play Alert Sound",
                desc = "Play a sound whenever TwichUI captures a new error.",
                get = function()
                    local el = GetErrorLog()
                    return el and el:GetPlayAlertSound() or false
                end,
                set = function(_, value)
                    local el = GetErrorLog()
                    if el then el:SetPlayAlertSound(value) end
                end,
            },
            alertSound = {
                type = "select",
                dialogControl = "LSM30_Sound",
                order = 25,
                width = 2,
                name = "Alert Sound",
                desc = "Sound to play when a new TwichUI error is captured.",
                values = GetSoundValues,
                disabled = function()
                    local el = GetErrorLog()
                    return not (el and el:GetPlayAlertSound())
                end,
                get = function()
                    local el = GetErrorLog()
                    return el and el:GetAlertSound() or DEFAULT_SOUND
                end,
                set = function(_, value)
                    local el = GetErrorLog()
                    if el then el:SetAlertSound(value) end
                end,
            },
        }),
        actions       = W.IGroup(20, "Actions", {
            open = {
                type  = "execute",
                order = 0,
                name  = "Open Error Viewer",
                desc  = "Open the error log viewer window.",
                func  = function()
                    local v = GetViewer()
                    if v then v:Show() end
                end,
            },
            clear = {
                type        = "execute",
                order       = 5,
                name        = "Clear All Errors",
                desc        = "Permanently delete all captured errors.",
                confirm     = true,
                confirmText = "Clear the entire error log? This cannot be undone.",
                func        = function()
                    local el = GetErrorLog()
                    if el then el:Clear() end
                    ConfigurationModule:Refresh()
                end,
            },
        }),
        settings      = W.IGroup(30, "Settings", {
            maxErrors = {
                type  = "range",
                order = 0,
                name  = "Max Stored Errors",
                desc  = "Maximum number of errors to keep. Oldest entries are trimmed when the cap is reached.",
                min   = 10,
                max   = 500,
                step  = 10,
                get   = function()
                    local el = GetErrorLog()
                    return el and el:GetMaxErrors() or 100
                end,
                set   = function(_, value)
                    local el = GetErrorLog()
                    if el then el:SetMaxErrors(value) end
                end,
            },
        }),
    }
    return section
end

ConfigurationModule:RegisterConfigurationFunction("Error Log", BuildErrorLogConfiguration)
