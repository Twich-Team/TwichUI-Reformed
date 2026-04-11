--[[
    Provides various utilities used throughout the addon
]]

local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)

---@class Tools
---@field Text TextTools
---@field Colors ColorTools
---@field Textures TexturesTool
---@field UI UISkins
---@field Quest QuestTools
---@field Game GameTool
---@field ErrorLog TwichUIErrorLog
---@field ReportErr fun(context:string, err:any)

---@class UISkins
---@field Profiler TwichUIProfiler
---@field ProfilerUI TwichUIProfilerUI
---@field DebugConsole any
---@field ErrorLogPopup any
---@field ErrorLogViewer any
local Tools = T.Tools or {}
T.Tools = Tools

---@class ToolFunctions
---@field Retry RetryModule
local functions = Tools.Functions or {}
Tools.Functions = functions

-- ---------------------------------------------------------------------------
-- ReportErr: central pcall error reporter
-- Routes caught errors to ErrorLog, EXCEPT for expected Midnight taint errors
-- which are not actionable bugs.  Use this in every `if not ok` branch where
-- the error originates from OUR code (not a third-party/Blizzard API call we
-- expect to fail).
--
-- Usage:
--   local ok, err = pcall(myFunc, arg1, arg2)
--   if not ok then T.Tools.ReportErr("MyModule:MyFunc", err) end
-- ---------------------------------------------------------------------------
local TAINT_PATTERNS = {
    "secret",     -- "attempt to compare field 'x' (a secret ...)"
    "tainted by", -- "... tainted by 'TwichUI_Reformed'"
    "attempt to perform boolean test on local.*secret",
    "invalid value %(secret%)",
}

---Report a pcall-caught error to the TwichUI error log.
---Taint errors (expected in Midnight due to protected API values) are
---silently dropped so they do not flood the error log.
---@param context string  Short description, e.g. "Nameplates:UpdateAuras"
---@param err any         The error value returned by pcall
function Tools.ReportErr(context, err)
    local msg = tostring(err or "unknown error")
    -- Check for known taint/secret patterns — these are Midnight engine-level
    -- restrictions, not bugs in our code.
    for _, pattern in ipairs(TAINT_PATTERNS) do
        if msg:find(pattern) then return end
    end
    local errorLog = Tools.ErrorLog
    if errorLog and type(errorLog.CaptureFailure) == "function" then
        errorLog:CaptureFailure(context, msg, 4)
    end
end
