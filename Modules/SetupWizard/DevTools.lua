---@diagnostic disable: undefined-field, inject-field
--[[
    TwichUI Setup Wizard — Developer Layout Capture Tool

    Usage (in-game):
        /tui wizard capture
        /tui wizard capture <layoutId>
        /tui wizard capture <layoutId> <layoutName>

    Example:
        /tui wizard capture standard_wide "Standard Wide"

    Workflow:
      1. Arrange your UI exactly as you want the layout to appear.
      2. Call  /tui wizard capture <id> "<Name>"
      3. Open  /tui debug wizard  to view and copy the generated Lua snippet.
      4. Paste the table entry into AVAILABLE_LAYOUTS in Layouts.lua.
      5. Increment WIZARD_VERSION in SetupWizardModule.lua so existing users
         see the new layout in the picker.

    Registering frames:
      Any module can expose a frame for capture by calling:
          SetupWizardModule:RegisterLayoutFrame("MyFrameKey", myFrame)
      The key becomes the table key in the captured output.
]]
local TwichRx           = _G.TwichRx
---@type TwichUI
local T                 = unpack(TwichRx)

---@type SetupWizardModule
local SetupWizardModule = T:GetModule("SetupWizard")

local GetScreenWidth    = _G.GetScreenWidth
local GetScreenHeight   = _G.GetScreenHeight
local CopyTable         = _G.CopyTable
local date              = _G.date

local function SanitizeCapturedConfigSection(sectionKey, sectionValue)
    if type(sectionValue) ~= "table" then
        return sectionValue
    end

    local sanitized = type(CopyTable) == "function" and CopyTable(sectionValue) or sectionValue
    if sectionKey == "chatEnhancement" then
        sanitized.persistedChatHistory = nil
    end

    return sanitized
end

-- ─── Capture ────────────────────────────────────────────────────────────────

--- Captures the current positions of all registered layout frames and emits a
--- ready-to-paste Lua snippet to the DebugConsole (source key: "wizard") and chat.
---
---@param layoutId   string|nil  Identifier for the new layout (default: "my_layout")
---@param layoutName string|nil  Human-readable name (default: "My Layout")
function SetupWizardModule:CaptureLayoutFrames(layoutId, layoutName)
    local sw     = GetScreenWidth()
    local sh     = GetScreenHeight()
    local frames = self.layoutFrames
    layoutId     = layoutId or "my_layout"
    layoutName   = layoutName or "My Layout"

    if not next(frames) then
        T:Print("|cff19c9c7[TwichUI Wizard]|r No layout frames are currently registered.")
        T:Print("Modules register frames via  SetupWizardModule:RegisterLayoutFrame(key, frame)")
        return
    end

    -- ── Build output lines ─────────────────────────────────────────────────
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    -- capturedFrameValues is passed to settings capturers so they can reference
    -- absolute pixel positions for frame-dependent settings (e.g. chat position).
    -- Values are absolute screen pixels: x = left edge, y = bottom edge.
    ---@type table<string, {x:number, y:number, w:number, h:number}>
    local capturedFrameValues = {}

    add(string.format("-- Captured: %s  |  %dx%d  |  layout id: %s", date("%Y-%m-%d"), sw, sh, layoutId))
    add("{")
    add(string.format('    id          = "%s",', layoutId))
    add(string.format('    name        = "%s",', layoutName))
    add('    description = "Add a description here.",')
    add('    role        = "any",   -- "any" | "dps" | "healer" | "tank"')
    add(string.format('    referenceResolution = { w = %d, h = %d },', sw, sh))
    add('    frames = {')

    -- Sort keys for deterministic output
    local sortedKeys = {}
    for k in pairs(frames) do sortedKeys[#sortedKeys + 1] = k end
    table.sort(sortedKeys)

    for _, key in ipairs(sortedKeys) do
        local entry = frames[key]
        -- Support both old bare-frame and new {frame=, persist=} styles.
        local frame = (type(entry) == "table" and entry.frame) or entry
        if frame and frame.GetLeft and frame.GetBottom and frame.GetWidth and frame.GetHeight then
            -- Use GetLeft/GetBottom (absolute screen coords) so the stored values are
            -- always BOTTOMLEFT-relative and resolution-independent.  This is anchor-agnostic
            -- and consistent with how modules like ChatStyling store their own positions.
            local left   = frame:GetLeft() or 0
            local bottom = frame:GetBottom() or 0
            local fw     = frame:GetWidth() or 0
            local fh     = frame:GetHeight() or 0

            -- ChatFrame1 captures should anchor to the visible chrome shell, not the raw
            -- chat frame, so layout positioning lines up with surrounding elements.
            if key == "ChatFrame1" then
                local chrome = frame.TwichUIChrome
                if chrome and chrome.GetLeft and chrome.GetBottom and chrome.GetWidth and chrome.GetHeight then
                    left = chrome:GetLeft() or left
                    bottom = chrome:GetBottom() or bottom
                    fw = chrome:GetWidth() or fw
                    fh = chrome:GetHeight() or fh
                end
            end

            -- Clamp NaN
            left                     = (left == left) and left or 0
            bottom                   = (bottom == bottom) and bottom or 0
            fw                       = (fw == fw) and fw or 0
            fh                       = (fh == fh) and fh or 0

            capturedFrameValues[key] = { x = left, y = bottom, w = fw, h = fh }

            local extra              = ""
            if key == "ChatFrame1" then
                extra = ', scaleMode = "height"'
            end
            add(string.format(
                "        %-32s = { x = %9.5f, y = %9.5f, w = %9.5f, h = %9.5f%s },",
                key,
                left / sw, bottom / sh, fw / sw, fh / sh, extra
            ))
        else
            add(string.format("        -- %-30s  (frame unavailable at capture time)", key))
        end
    end

    add('    },')

    -- ── Full DB snapshot ──────────────────────────────────────────────────
    -- Serialize the entire profile configuration (minus "setupWizard") so the
    -- generated apply() function can restore every setting automatically via
    -- SetupWizardModule:RestoreConfigSnapshot().

    -- ── Serializer helpers ────────────────────────────────────────────────
    local function FormatNumber(v)
        if v ~= v then return "0" end -- NaN
        if v == math.huge then return "1e308" end
        if v == -math.huge then return "-1e308" end
        if math.floor(v) == v and math.abs(v) <= 2147483647 then
            return string.format("%d", v)
        end
        return string.format("%.6g", v)
    end

    -- Returns true + length if `t` is a clean numeric array of numbers only.
    local function IsCompactNumberArray(t)
        local n = 0
        for k in pairs(t) do
            if type(k) ~= "number" or k ~= math.floor(k) or k < 1 then return false end
            n = n + 1
        end
        if n == 0 or n > 8 then return false end
        for i = 1, n do
            if t[i] == nil or type(t[i]) ~= "number" then return false end
        end
        return true, n
    end

    local function SerializeValue(v, indent, seen)
        local vt = type(v)
        if vt == "boolean" then
            return tostring(v)
        elseif vt == "number" then
            return FormatNumber(v)
        elseif vt == "string" then
            return string.format("%q", v)
        elseif vt == "table" then
            seen = seen or {}
            if seen[v] then return "{}" end
            seen[v] = true

            -- Short all-number arrays (colours, vectors) – emit on one line.
            local ok, n = IsCompactNumberArray(v)
            if ok then
                local parts = {}
                for i = 1, n do parts[i] = FormatNumber(v[i]) end
                seen[v] = nil
                return "{ " .. table.concat(parts, ", ") .. " }"
            end

            -- General table: sort keys, recurse.
            local keys = {}
            for k in pairs(v) do
                local kt, vvt = type(k), type(v[k])
                if (kt == "string" or kt == "number")
                    and vvt ~= "function" and vvt ~= "userdata" and vvt ~= "thread" then
                    keys[#keys + 1] = k
                end
            end
            if #keys == 0 then
                seen[v] = nil; return "{}"
            end

            table.sort(keys, function(a, b)
                if type(a) == type(b) then return tostring(a) < tostring(b) end
                return type(a) < type(b)
            end)

            local nextIndent = indent .. "    "
            local parts = {}
            for _, k in ipairs(keys) do
                local sv = SerializeValue(v[k], nextIndent, seen)
                if sv then
                    local kStr
                    if type(k) == "string" and k:match("^[%a_][%w_]*$") then
                        kStr = k
                    elseif type(k) == "string" then
                        kStr = string.format("[%q]", k)
                    else
                        kStr = string.format("[%d]", k)
                    end
                    parts[#parts + 1] = nextIndent .. kStr .. " = " .. sv
                end
            end

            seen[v] = nil
            if #parts == 0 then return "{}" end
            return "{\n" .. table.concat(parts, ",\n") .. "\n" .. indent .. "}"
        end
        return nil -- function / userdata / thread / nil → skip
    end

    -- ── Snapshot profile.configuration (excluding setupWizard) ───────────
    local CM          = T:GetModule("Configuration")
    local config      = CM and CM:GetProfileDB() or {}

    local sectionKeys = {}
    for k in pairs(config) do
        if k ~= "setupWizard" then sectionKeys[#sectionKeys + 1] = k end
    end
    table.sort(sectionKeys)

    add('    apply = function()')
    add('        local T = unpack(_G.TwichRx)')

    local hasSnapshot = false
    for _, k in ipairs(sectionKeys) do
        local sv = SerializeValue(SanitizeCapturedConfigSection(k, config[k]), "            ", {})
        if sv and sv ~= "{}" then
            if not hasSnapshot then
                add('        T:GetModule("SetupWizard"):RestoreConfigSnapshot({')
                hasSnapshot = true
            end
            add(string.format("            %s = %s,", k, sv))
        end
    end

    if hasSnapshot then
        add('        })')
    else
        add('        -- Configuration DB was empty at capture time; no settings to restore.')
    end

    add('    end,')
    add('},')
    add('-- Paste the block above into AVAILABLE_LAYOUTS in Layouts.lua')

    local output = table.concat(lines, "\n")

    -- ── Emit to DebugConsole ───────────────────────────────────────────────
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
    if console and type(console.Log) == "function" then
        console:Log("wizard", output)
        T:Print("|cff19c9c7[TwichUI Wizard]|r Layout captured (" ..
            #sortedKeys .. " frames). View with |cff19c9c7/tui debug wizard|r")
    else
        -- Fallback: print to chat in chunks (WoW's print has a ~255-char limit)
        T:Print("|cff19c9c7[TwichUI Wizard]|r Layout capture output:")
        for _, line in ipairs(lines) do
            T:Print(line)
        end
    end
end
