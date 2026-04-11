---@diagnostic disable: inject-field, undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")
local ConfigurationOptions = ConfigurationModule.Options --[[@as any]]

---@class MapTweaksConfigurationOptions
local Options = ConfigurationOptions.MapTweaks or {}
ConfigurationOptions.MapTweaks = Options

local function GetDB()
    local profile = ConfigurationModule:GetProfileDB()
    profile.mapTweaks = profile.mapTweaks or {}
    local db = profile.mapTweaks

    db.position = db.position or {
        normal = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 16, y = -94 },
        maximized = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 },
    }
    db.tint = db.tint or { enabled = false, r = 0.6, g = 0.6, b = 1, a = 1 }
    db.unlock = db.unlock or { enabled = false, movement = true }
    db.fade = db.fade or { enabled = false }
    db.emote = db.emote or { enabled = false }
    db.reveal = db.reveal or { enabled = false }

    return db
end

local function GetModule()
    return T:GetModule("QualityOfLife"):GetModule("MapTweaks")
end

local function ResolvePath(path, create)
    local node = GetDB()
    for index = 1, #path - 1 do
        local key = path[index]
        if type(node[key]) ~= "table" then
            if not create then
                return nil, path[#path]
            end
            node[key] = {}
        end
        node = node[key]
    end
    return node, path[#path]
end

function Options:GetEnabled()
    return GetDB().enabled == true
end

function Options:SetEnabled(info, value)
    local db = GetDB()
    db.enabled = value == true
    local module = GetModule()
    if db.enabled then
        module:Enable()
    else
        module:Disable()
    end
end

function Options:GetValue(path, defaultValue)
    local node, key = ResolvePath(path, false)
    if not node then
        return defaultValue
    end
    local value = node[key]
    if value == nil then
        return defaultValue
    end
    return value
end

function Options:SetValue(path, value)
    local node, key = ResolvePath(path, true)
    node[key] = value
    local module = GetModule()
    if module and module.RefreshSettings then
        module:RefreshSettings()
    end
end

function Options:ResetMapPosition()
    local db = GetDB()
    db.position.normal = { point = "TOPLEFT", relativePoint = "TOPLEFT", x = 16, y = -94 }
    db.position.maximized = { point = "CENTER", relativePoint = "CENTER", x = 0, y = 0 }
    local module = GetModule()
    if module and module.ApplyMapPosition then
        module:ApplyMapPosition(true)
    end
end
