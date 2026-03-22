-- Portal Authority Mythic+ dock preset data.

PortalAuthority = PortalAuthority or {}

PortalAuthority.MPlusDockPresets = {
    ["SEASON_01"] = {
        name = "Midnight Season 01",
        spellIDs = {
            1254400, -- Windrunner Spire
            159898,  -- Skyreach
            1254551, -- Seat of the Triumvirate
            1254555, -- Pit of Saron
            1254563, -- Nexus-Point Xenas
            1254559, -- Maisara Caverns
            1254572, -- Magister's Terrace
            393273,  -- Algeth'ar Academy
        },
    },
}

local function copySpellIDList(list)
    local copy = {}
    if type(list) ~= "table" then
        return copy
    end

    for _, spellID in ipairs(list) do
        local sid = math.floor(tonumber(spellID) or 0)
        if sid > 0 then
            copy[#copy + 1] = sid
        end
    end

    return copy
end

function PortalAuthority:GetMPlusDockPreset(presetKey)
    local key = tostring(presetKey or "SEASON_01")
    local presets = self.MPlusDockPresets
    return presets and presets[key] or nil
end

function PortalAuthority:GetMPlusDockPresetSpellIDs(presetKey)
    local preset = self:GetMPlusDockPreset(presetKey)
    return copySpellIDList(preset and preset.spellIDs or nil)
end

function PortalAuthority:GetDefaultMPlusDockPresetKey()
    return "SEASON_01"
end

function PortalAuthority:GetDefaultMPlusDockPresetSpellIDs()
    return self:GetMPlusDockPresetSpellIDs(self:GetDefaultMPlusDockPresetKey())
end

function PortalAuthority:GetMPlusDockPresetDungeons(presetKey)
    local key = tostring(presetKey or self:GetDefaultMPlusDockPresetKey())
    local dungeons = {}
    local spellMap = self.SpellMap or {}

    for _, spellID in ipairs(self:GetMPlusDockPresetSpellIDs(key)) do
        local info = spellMap[spellID] or {}
        dungeons[#dungeons + 1] = {
            spellID = spellID,
            dest = type(info.dest) == "string" and info.dest or "",
            short = type(info.short) == "string" and info.short or "",
            presetKey = key,
        }
    end

    return dungeons
end

function PortalAuthority:GetDefaultMPlusDockPresetDungeons()
    return self:GetMPlusDockPresetDungeons(self:GetDefaultMPlusDockPresetKey())
end
