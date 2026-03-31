---@diagnostic disable: undefined-field, undefined-global
--[[
    TwichUI Error Log
    Installs a chained global error handler that captures any unhandled Lua errors
    originating from TwichUI_Reformed and persists them to the global SavedVariables
    database for later review via the Error Log viewer.

    Install is deferred until after the DB is available (called from Core.lua).
]]
local TwichRx         = _G.TwichRx
---@type TwichUI
local T               = unpack(TwichRx)

---@type Tools
local Tools           = T.Tools

local date            = _G.date
local debugstack      = _G.debugstack
local geterrorhandler = _G.geterrorhandler
local math            = math
local pcall           = pcall
local seterrorhandler = _G.seterrorhandler
local table           = table
local time            = _G.time
local tostring        = tostring
local type            = type

local ADDON_NAME      = "TwichUI_Reformed"
local DEFAULT_MAX     = 100
local SHORT_MAX_LEN   = 220

---@class TwichUIErrorLog
---@field installed boolean
---@field _handler function|nil
---@field _previousHandler function|nil
---@field Capture fun(self:TwichUIErrorLog, detail:any, context:string|nil, stack:string|nil)
---@field CaptureFailure fun(self:TwichUIErrorLog, context:string|nil, detail:any, stackLevel:number|nil)
---@field _InjectTestError fun(self:TwichUIErrorLog, msg:string)
local ErrorLog        = (Tools.ErrorLog or {}) --[[@as TwichUIErrorLog]]
Tools.ErrorLog        = ErrorLog
ErrorLog.installed    = ErrorLog.installed or false

-- ---------------------------------------------------------------------------
-- Private helpers
-- ---------------------------------------------------------------------------

local function GetLogsDB()
    local db = T.db and T.db.global
    if not db then return nil end
    if not db.errorLog then
        db.errorLog = { errors = {}, maxErrors = DEFAULT_MAX }
    end
    return db.errorLog
end

--- Returns true if `msg` originates from our addon.
local function IsOurError(msg)
    if type(msg) ~= "string" then return false end

    local lowered = msg:lower()
    return lowered:find(ADDON_NAME:lower(), 1, true) ~= nil
        or lowered:find("twichrx", 1, true) ~= nil
end

--- Extracts a short one-line summary from the full error string.
local function MakeShort(msg)
    local first = msg:match("^([^\n]+)") or msg
    -- Strip the addon path prefix for display brevity
    first = first:gsub("Interface\\AddOns\\" .. ADDON_NAME .. "\\", "")
    if #first > SHORT_MAX_LEN then
        first = first:sub(1, SHORT_MAX_LEN) .. "…"
    end
    return first
end

local function BuildDetail(detail, context, stack)
    local resolvedDetail = tostring(detail or "Unknown error")
    local prefix = (type(context) == "string" and context ~= "") and ("[" .. context .. "] ") or ""
    local full = prefix .. resolvedDetail

    if type(stack) == "string" and stack ~= "" and not full:find("stack traceback", 1, true) then
        full = full .. "\nstack traceback:\n" .. stack
    end

    return full
end

local function AppendEntry(detail)
    local db = GetLogsDB()
    if not db then
        return false
    end

    local now = time()
    if db._lastDetail == detail and db._lastCapturedAt == now then
        return false
    end

    db._lastDetail = detail
    db._lastCapturedAt = now

    local entry = {
        id = now,
        dateStr = date("%Y-%m-%d %H:%M:%S"),
        short = MakeShort(detail),
        detail = detail,
    }

    table.insert(db.errors, 1, entry)
    local cap = db.maxErrors or DEFAULT_MAX
    while #db.errors > cap do
        table.remove(db.errors)
    end

    local viewer = Tools.UI and Tools.UI.ErrorLogViewer
    if viewer and viewer.frame and viewer.frame:IsShown() then
        viewer:Refresh()
    end

    return true
end

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

function ErrorLog:Capture(detail, context, stack)
    local fullDetail = BuildDetail(detail, context, stack)
    local inserted = AppendEntry(fullDetail)
    if inserted and T.Print then
        T:Print("[TwichUI] Captured a new error. Open /tui errors to review details.")
    end
end

function ErrorLog:CaptureFailure(context, detail, stackLevel)
    local stack = nil
    if type(debugstack) == "function" then
        stack = debugstack((tonumber(stackLevel) or 3), 20, 20)
    end

    self:Capture(detail, context, stack)
end

--- Install the chained error handler.  Safe to call multiple times (no-op after first).
function ErrorLog:Install()
    local current = geterrorhandler()
    if self._handler and current == self._handler then
        self.installed = true
        return
    end

    local previous = current
    if previous == self._handler then
        previous = self._previousHandler
    end

    self._previousHandler = previous
    self._handler = function(msg)
        pcall(function()
            if IsOurError(msg) then
                self:Capture(msg)
            end
        end)

        if type(self._previousHandler) == "function" then
            self._previousHandler(msg)
        end
    end

    seterrorhandler(self._handler)

    self.installed = true
end

--- Return all captured errors (newest first).
---@return table[]
function ErrorLog:GetAll()
    local db = GetLogsDB()
    return (db and db.errors) or {}
end

--- Return the count of captured errors.
---@return number
function ErrorLog:GetCount()
    local db = GetLogsDB()
    return db and #db.errors or 0
end

--- Clear all captured errors.
function ErrorLog:Clear()
    local db = GetLogsDB()
    if db then
        db.errors = {}
    end
    local viewer = Tools.UI and Tools.UI.ErrorLogViewer
    if viewer and viewer.frame and viewer.frame:IsShown() then
        viewer:Refresh()
    end
end

--- Get the current max-errors cap.
---@return number
function ErrorLog:GetMaxErrors()
    local db = GetLogsDB()
    return (db and db.maxErrors) or DEFAULT_MAX
end

--- Set the max-errors cap, trimming the log if necessary.
---@param value number
function ErrorLog:SetMaxErrors(value)
    local db = GetLogsDB()
    if not db then return end
    local cap = math.max(10, math.min(500, math.floor(value or DEFAULT_MAX)))
    db.maxErrors = cap
    while #db.errors > cap do
        table.remove(db.errors)
    end
end

--- FOR TESTING ONLY: directly inject a fake error entry.
---@param msg string
function ErrorLog:_InjectTestError(msg)
    self:Capture(msg)
end
