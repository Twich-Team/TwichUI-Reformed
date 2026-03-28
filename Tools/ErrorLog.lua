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
local geterrorhandler = _G.geterrorhandler
local math            = math
local pcall           = pcall
local seterrorhandler = _G.seterrorhandler
local table           = table
local time            = _G.time
local type            = type

local ADDON_NAME      = "TwichUI_Reformed"
local DEFAULT_MAX     = 100
local SHORT_MAX_LEN   = 220

---@class TwichUIErrorLog
---@field installed boolean
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
    return msg:find(ADDON_NAME, 1, true) ~= nil
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

-- ---------------------------------------------------------------------------
-- Public API
-- ---------------------------------------------------------------------------

--- Install the chained error handler.  Safe to call multiple times (no-op after first).
function ErrorLog:Install()
    if self.installed then return end

    local previous = geterrorhandler()

    seterrorhandler(function(msg)
        -- Ultra-defensive inner block so our handler can never cascade
        pcall(function()
            if IsOurError(msg) then
                local db = GetLogsDB()
                if db then
                    local entry = {
                        id      = time(),
                        dateStr = date("%Y-%m-%d %H:%M:%S"),
                        short   = MakeShort(msg),
                        detail  = msg,
                    }
                    table.insert(db.errors, 1, entry) -- newest first
                    local cap = db.maxErrors or DEFAULT_MAX
                    while #db.errors > cap do
                        table.remove(db.errors)
                    end
                    -- Reflect in viewer if open
                    local viewer = Tools.UI and Tools.UI.ErrorLogViewer
                    if viewer and viewer.frame and viewer.frame:IsShown() then
                        viewer:Refresh()
                    end
                end
            end
        end)

        -- Always chain to preserve ElvUI/Blizzard handling
        if type(previous) == "function" then
            previous(msg)
        end
    end)

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
    local db = GetLogsDB()
    if not db then return end
    local entry = {
        id      = time(),
        dateStr = date("%Y-%m-%d %H:%M:%S"),
        short   = MakeShort(msg),
        detail  = msg,
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
end
