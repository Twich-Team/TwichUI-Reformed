---@class _G
---@field PlaySound fun(soundKitID:any, ...:any):any
---@field PlaySoundFile fun(soundPath:any, ...:any):any
local _G = _G
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

local debugstack = _G.debugstack
local stringFind = string.find
local stringFormat = string.format
local stringGmatch = string.gmatch
local stringGsub = string.gsub
local stringLower = string.lower
local tostring = tostring
local type = type
local tonumber = tonumber

local DEBUG_SOURCE_KEY = "sounds"
local MEDIA_SOUND_ROOT = "interface\\addons\\twichui_reformed\\media\\sounds\\"

---@class TwichUISoundTrace
---@field installed boolean|nil
---@field sourceRegistered boolean|nil
---@field _logging boolean|nil
---@field _originalPlaySound function|nil
---@field _originalPlaySoundFile function|nil
local SoundTrace = Tools.SoundTrace or {}
Tools.SoundTrace = SoundTrace

local function SafeString(value)
    if value == nil then
        return "nil"
    end

    local ok, result = pcall(tostring, value)
    if not ok or result == nil then
        return "<unprintable>"
    end

    result = stringGsub(result, "[\r\n\t]+", " ")
    result = stringGsub(result, "%s%s+", " ")
    return result
end

local function GetDebuggerDB()
    local db = T.db and T.db.global
    if not db then
        return nil
    end

    db.debugger = db.debugger or {}
    if db.debugger.soundTraceEnabled == nil then
        db.debugger.soundTraceEnabled = false
    end

    return db.debugger
end

local function NormalizeCallerLine(line)
    if type(line) ~= "string" or line == "" then
        return "unknown"
    end

    line = stringGsub(line, "^%s+", "")

    local markerStart, markerEnd = stringFind(line, "Interface\\AddOns\\", 1, true)
    if markerEnd then
        return line:sub(markerEnd + 1)
    end

    markerStart, markerEnd = stringFind(line, "Interface/AddOns/", 1, true)
    if markerEnd then
        return line:sub(markerEnd + 1)
    end

    local markerStart, markerEnd = stringFind(line, "TwichUI_Reformed\\", 1, true)
    if markerEnd then
        return line:sub(markerEnd + 1)
    end

    markerStart, markerEnd = stringFind(line, "TwichUI_Reformed/", 1, true)
    if markerEnd then
        return line:sub(markerEnd + 1)
    end

    return line
end

local function NormalizeSoundValue(soundValue)
    if type(soundValue) ~= "string" or soundValue == "" then
        return nil
    end

    local normalized = stringLower(soundValue)
    normalized = stringGsub(normalized, "/", "\\")
    return normalized
end

local function IsTrackedSoundValue(soundValue)
    local normalized = NormalizeSoundValue(soundValue)
    if not normalized then
        return false
    end

    return stringFind(normalized, MEDIA_SOUND_ROOT, 1, true) ~= nil
end

local function ExtractCaller(stack)
    if type(stack) ~= "string" or stack == "" then
        return nil
    end

    local fallbackCaller = nil
    for line in stringGmatch(stack, "[^\n]+") do
        local normalized = NormalizeCallerLine(line)
        local isTracerFrame = stringFind(line, "Tools\\SoundTrace.lua", 1, true)
            or stringFind(line, "Tools/SoundTrace.lua", 1, true)
        if not isTracerFrame and normalized ~= "unknown" and normalized ~= "" then
            local isAddonFrame = stringFind(line, "Interface\\AddOns\\", 1, true)
                or stringFind(line, "Interface/AddOns/", 1, true)
            if isAddonFrame and not fallbackCaller then
                fallbackCaller = normalized
            end
        end

        if stringFind(line, "TwichUI_Reformed", 1, true)
            and not isTracerFrame then
            return normalized, "twichui"
        end
    end

    if fallbackCaller then
        return fallbackCaller, "external"
    end

    return nil, nil
end

function SoundTrace:GetEnabled()
    local db = GetDebuggerDB()
    return db and db.soundTraceEnabled == true or false
end

function SoundTrace:SetEnabled(value)
    local db = GetDebuggerDB()
    if not db then
        return
    end

    db.soundTraceEnabled = value == true
    self:EnsureDebugSource()
end

function SoundTrace:BuildDebugReport()
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil
    local lines = console and console.GetLines and console:GetLines(DEBUG_SOURCE_KEY) or {}

    return table.concat({
        "TwichUI Sound Trace",
        "",
        stringFormat("Enabled: %s", self:GetEnabled() and "Yes" or "No"),
        stringFormat("Buffered entries: %d", #lines),
        "",
        "This source logs TwichUI-owned sound calls and any playback of TwichUI media sound files, even if another addon triggered them.",
    }, "\n")
end

function SoundTrace:EnsureDebugSource()
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil
    if not console or type(console.RegisterSource) ~= "function" then
        return false
    end

    console:RegisterSource(DEBUG_SOURCE_KEY, {
        title = "Sound Trace",
        order = 26,
        aliases = { "sound", "sounds", "audio" },
        maxLines = 250,
        isEnabled = function()
            return SoundTrace:GetEnabled()
        end,
        buildReport = function()
            return SoundTrace:BuildDebugReport()
        end,
    })

    self.sourceRegistered = true
    return true
end

function SoundTrace:LogTrace(apiName, soundValue, channel, stackLevel)
    if self._logging or not self:GetEnabled() then
        return
    end

    if type(debugstack) ~= "function" then
        return
    end

    local stack = debugstack(tonumber(stackLevel) or 3, 8, 8)
    if type(stack) ~= "string" then
        return
    end

    local trackedMediaSound = apiName == "PlaySoundFile" and IsTrackedSoundValue(soundValue)
    local hasTwichUIFrame = stringFind(stack, "TwichUI_Reformed", 1, true) ~= nil
    if not hasTwichUIFrame and not trackedMediaSound then
        return
    end

    local caller, callerKind = ExtractCaller(stack)
    if not caller then
        return
    end

    self:EnsureDebugSource()

    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole or nil
    if not console or type(console.Log) ~= "function" then
        return
    end

    self._logging = true
    local ok = pcall(
        console.Log,
        console,
        DEBUG_SOURCE_KEY,
        stringFormat(
            "%s sound=%s channel=%s caller=%s source=%s",
            SafeString(apiName),
            SafeString(soundValue),
            SafeString(channel or "default"),
            SafeString(caller),
            trackedMediaSound and (callerKind == "external" and "external-twichui-media" or "twichui-media") or "twichui"
        ),
        false
    )
    self._logging = false

    if not ok then
        self._logging = false
    end
end

function SoundTrace:Install()
    if self.installed then
        self:EnsureDebugSource()
        return
    end

    self._originalPlaySound = self._originalPlaySound or _G.PlaySound
    self._originalPlaySoundFile = self._originalPlaySoundFile or _G.PlaySoundFile

    if type(self._originalPlaySound) == "function" then
        _G.PlaySound = function(soundKitID, ...)
            SoundTrace:LogTrace("PlaySound", soundKitID, select(1, ...), 3)
            return SoundTrace._originalPlaySound(soundKitID, ...)
        end
    end

    if type(self._originalPlaySoundFile) == "function" then
        _G.PlaySoundFile = function(soundPath, ...)
            SoundTrace:LogTrace("PlaySoundFile", soundPath, select(1, ...), 3)
            return SoundTrace._originalPlaySoundFile(soundPath, ...)
        end
    end

    self.installed = true
    self:EnsureDebugSource()
end

SoundTrace:Install()