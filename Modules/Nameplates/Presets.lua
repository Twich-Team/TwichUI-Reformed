---@diagnostic disable: inject-field
--[[
    Nameplates preset registry and import/export helpers.

    Workflow:
      1. Configure nameplates in-game the way you want.
      2. Run: /tui npdebug export <presetId> <Preset Name>
      3. Copy the emitted Lua snippet from the debug console.
      4. Paste that snippet into NAMEPLATE_PRESETS below.

    The dropdown in Nameplates > Presets populates automatically from
    NAMEPLATE_PRESETS. Applying a preset replaces only profile.configuration.nameplates.
]]

local TwichRx = _G.TwichRx
local T = unpack(TwichRx)

---@type NameplatesModule
local Nameplates = T:GetModule("Nameplates")

local loadstring = _G.loadstring

local PRESET_EXPORT_PREFIX = "TNP1:"

Nameplates.NAMEPLATE_PRESETS = Nameplates.NAMEPLATE_PRESETS or {
    {
        id = "standard",
        name = "Standard",
        export =
        [=[TNP1:{aggroColorDps={0.843137,0.262745,0.352941,1},auraFilter="HARMFUL",auraOnlyMine=true,auraSize=33,auraTimerFontSize=18,castBarTexture="TwichUI Bright",castBgColor={0.05,0.06,0.08,0.92},castColor={0.96,0.76,0.24,1},castFontOutline="NONE",castFontShadow=true,castFontSize=10,clampTargetNameplateToScreen=false,colorBoss={0.611765,0.313726,0.843137,1},colorByCaster=true,colorHostile={0.458824,0.533333,0.741176,1},colorMiniboss={0.611765,0.313726,0.843137,1},colorNpcCaster={0.396078,0.709804,0.741176,1},colorRare={0.454902,0.843137,0.819608,1},enabled=true,friendly={castHeight=6,enabled=true,healthColorMode="class",healthFontShadow=true,healthFormat="none",healthTextAnchor="CENTER",height=15,nameAnchorPoint="BOTTOMLEFT",nameColorClass=false,nameFontOutline="NONE",nameFontSize=16,nameJustify="CENTER",nameOffsetY=8,showAuras=false,showCastBar=false,showLevel=false,showPowerBar=false,width=125},healthBgColor={0.14902,0.168627,0.227451,0.92},healthBgTexture="TwichUI AngledLines",healthColorMode="reaction",healthFontOutline="NONE",healthFontShadow=true,healthFontSize=12,healthFormat="percent",healthTextAnchor="RIGHT",height=26,nameAnchorPoint="HEALTH_LEFT",nameColorClass=false,nameFont="Exo2 SemiBold",nameFontOutline="NONE",nameFontShadow=true,nameFontSize=13,nameFormat="full",nameOffsetX=0,nameOffsetY=0,nameWidth=135,powerBarGap=0,raidMarkerOffsetY=8,showAbsorb=true,showAuras=true,showCastBar=true,showEliteIcon=false,showLevel=false,showName=true,showPowerBar=true,showRaidMarker=true,showTargetArrows=true,showTargetGlow=true,showThreat=false,stackNameplates=true,stackingHeightScale=1.2,targetArrowSize=26,targetArrowStyle="Arrow9",targetGlowColor={0.937255,0.937255,0.937255,0.898438},targetGlowOutset=3,targetGrowHeight=1.2,targetGrowWidth=1.2,width=180}]=],
    },
}

local function CloneValue(value, seen)
    if type(value) ~= "table" then
        return value
    end

    seen = seen or {}
    if seen[value] then
        return seen[value]
    end

    local copy = {}
    seen[value] = copy
    for key, entry in pairs(value) do
        if type(entry) ~= "function" and type(entry) ~= "userdata" and type(entry) ~= "thread" then
            copy[CloneValue(key, seen)] = CloneValue(entry, seen)
        end
    end
    return copy
end

local function FormatNumber(value)
    if value ~= value then return "0" end
    if value == math.huge then return "1e308" end
    if value == -math.huge then return "-1e308" end
    if math.floor(value) == value and math.abs(value) <= 2147483647 then
        return string.format("%d", value)
    end
    return string.format("%.6g", value)
end

local function IsCompactNumberArray(tbl)
    local count = 0
    for key in pairs(tbl) do
        if type(key) ~= "number" or key ~= math.floor(key) or key < 1 then
            return false
        end
        count = count + 1
    end
    if count == 0 or count > 8 then
        return false
    end
    for index = 1, count do
        if tbl[index] == nil or type(tbl[index]) ~= "number" then
            return false
        end
    end
    return true, count
end

local function SerializeValue(value, seen)
    local valueType = type(value)
    if valueType == "boolean" then
        return tostring(value)
    end
    if valueType == "number" then
        return FormatNumber(value)
    end
    if valueType == "string" then
        return string.format("%q", value)
    end
    if valueType ~= "table" then
        return "nil"
    end

    seen = seen or {}
    if seen[value] then
        return "{}"
    end
    seen[value] = true

    local compactArray, count = IsCompactNumberArray(value)
    if compactArray then
        local parts = {}
        for index = 1, count do
            parts[index] = FormatNumber(value[index])
        end
        seen[value] = nil
        return "{" .. table.concat(parts, ",") .. "}"
    end

    local keys = {}
    for key, entry in pairs(value) do
        local keyType = type(key)
        local entryType = type(entry)
        if (keyType == "string" or keyType == "number")
            and entryType ~= "function" and entryType ~= "userdata" and entryType ~= "thread" then
            keys[#keys + 1] = key
        end
    end

    table.sort(keys, function(left, right)
        if type(left) == type(right) then
            return tostring(left) < tostring(right)
        end
        return type(left) < type(right)
    end)

    local parts = {}
    for _, key in ipairs(keys) do
        local serializedKey
        if type(key) == "string" and key:match("^[%a_][%w_]*$") then
            serializedKey = key
        elseif type(key) == "string" then
            serializedKey = string.format("[%q]", key)
        else
            serializedKey = string.format("[%d]", key)
        end
        parts[#parts + 1] = serializedKey .. "=" .. SerializeValue(value[key], seen)
    end

    seen[value] = nil
    return "{" .. table.concat(parts, ",") .. "}"
end

local function GetConfigurationDB()
    local configuration = T:GetModule("Configuration", true)
    if not configuration or type(configuration.GetProfileDB) ~= "function" then
        return nil
    end
    return configuration:GetProfileDB()
end

local function NormalizePresetExportString(exportString)
    if type(exportString) ~= "string" then
        return nil, "Preset export is missing."
    end

    local trimmed = exportString:match("^%s*(.-)%s*$")
    if not trimmed or trimmed == "" then
        return nil, "Preset export is empty."
    end

    local payload = trimmed:match("^" .. PRESET_EXPORT_PREFIX:gsub("([^%w])", "%%%1") .. "(.+)$")
    if not payload then
        return nil, "Unsupported nameplates preset format."
    end

    return payload
end

function Nameplates:GetNameplatePresets()
    return self.NAMEPLATE_PRESETS or {}
end

function Nameplates:GetNameplatePreset(presetId)
    if type(presetId) ~= "string" or presetId == "" then
        return nil
    end

    for _, preset in ipairs(self:GetNameplatePresets()) do
        if preset.id == presetId then
            return preset
        end
    end
    return nil
end

function Nameplates:GetNameplatePresetValues()
    local values = {}
    for _, preset in ipairs(self:GetNameplatePresets()) do
        if type(preset.id) == "string" and preset.id ~= "" and type(preset.name) == "string" and preset.name ~= "" then
            values[preset.id] = preset.name
        end
    end
    return values
end

function Nameplates:DecodeNameplatePresetString(exportString)
    local payload, err = NormalizePresetExportString(exportString)
    if not payload then
        return nil, err
    end
    if type(loadstring) ~= "function" then
        return nil, "loadstring is unavailable on this client."
    end

    local chunk, loadErr = loadstring("return " .. payload)
    if not chunk then
        return nil, "Failed to parse nameplates preset: " .. tostring(loadErr)
    end

    local ok, decoded = pcall(chunk)
    if not ok or type(decoded) ~= "table" then
        return nil, "Parsed preset did not return a table."
    end

    if type(decoded.nameplates) == "table" then
        decoded = decoded.nameplates
    end

    if type(decoded) ~= "table" then
        return nil, "Preset payload does not contain nameplates settings."
    end

    return CloneValue(decoded)
end

function Nameplates:SetSelectedPresetId(presetId)
    local db = self:GetDB()
    db.selectedPresetId = presetId
end

function Nameplates:GetSelectedPresetId()
    local db = self:GetDB()
    return db.selectedPresetId
end

function Nameplates:ApplyNameplatePresetData(presetData, presetId)
    if type(presetData) ~= "table" then
        return false, "Preset data is invalid."
    end

    local config = GetConfigurationDB()
    if not config then
        return false, "Configuration database is unavailable."
    end

    local applied = CloneValue(presetData)
    applied.selectedPresetId = presetId or applied.selectedPresetId
    applied.appliedPresetId = presetId or applied.appliedPresetId or "__custom"
    config.nameplates = applied

    self:InvalidateCache()
    if self:IsEnabled() then
        self:Refresh()
    end
    return true
end

function Nameplates:ApplyNameplatePresetById(presetId)
    local preset = self:GetNameplatePreset(presetId)
    if not preset then
        return false, "Preset not found."
    end

    local presetData, err = self:DecodeNameplatePresetString(preset.export)
    if not presetData then
        return false, err
    end

    local ok, applyErr = self:ApplyNameplatePresetData(presetData, preset.id)
    if not ok then
        return false, applyErr
    end

    return true, preset
end

function Nameplates:BuildNameplatePresetExportString()
    local snapshot = CloneValue(self:GetDB())
    snapshot.selectedPresetId = nil
    snapshot.appliedPresetId = nil
    return PRESET_EXPORT_PREFIX .. SerializeValue(snapshot)
end

function Nameplates:BuildNameplatePresetLuaSnippet(presetId, presetName, description)
    local lines = {
        "{",
        string.format("    id = %q,", presetId or "my_preset"),
        string.format("    name = %q,", presetName or "My Preset"),
    }

    if type(description) == "string" and description ~= "" then
        lines[#lines + 1] = string.format("    description = %q,", description)
    end

    lines[#lines + 1] = string.format("    export = [=[%s]=],", self:BuildNameplatePresetExportString())
    lines[#lines + 1] = "},"
    return table.concat(lines, "\n")
end

function Nameplates:ExportCurrentNameplatePreset(presetId, presetName, description)
    local snippet = self:BuildNameplatePresetLuaSnippet(presetId, presetName, description)
    local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole

    if console and type(console.Log) == "function" then
        console:Log("nameplates", snippet)
        if type(console.Show) == "function" then
            console:Show("nameplates")
        end
    end

    T:Print("[TwichUI] Nameplates preset snippet copied to the debug console.")
    T:Print("[TwichUI] Paste the emitted block into Modules/Nameplates/Presets.lua.")
    return snippet
end
