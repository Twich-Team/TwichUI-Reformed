--[[
    Options for the ChatEnhancement module.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

--- @class MediaConfigurationOptions
local Options = ConfigurationModule.Options.Media or {}
ConfigurationModule.Options.Media = Options


---@return table mediaDB the profile-level media configuration database.
function Options:GetMediaDB()
    if not ConfigurationModule:GetProfileDB().media then
        ConfigurationModule:GetProfileDB().media = {}
    end
    return ConfigurationModule:GetProfileDB().media
end

---@return boolean isEnabled true if fonts are enabled, false otherwise.
function Options:GetFontEnabled(info)
    return self:GetMediaDB().fontsEnabled or true
end

---@param value boolean isEnabled true to enable fonts, false to disable.
function Options:SetFontEnabled(info, value)
    self:GetMediaDB().fontsEnabled = value

    if value == true then
        ---@type MediaModule
        local MediaModule = T:GetModule("Media")
        MediaModule:AddFonts()
    else
        ConfigurationModule:PromptToReloadUI()
    end
end

---@return boolean isEnabled true if sounds are enabled, false otherwise.
function Options:GetSoundEnabled(info)
    return self:GetMediaDB().soundsEnabled or true
end

---@param value boolean isEnabled true to enable sounds, false to disable.
function Options:SetSoundEnabled(info, value)
    self:GetMediaDB().soundsEnabled = value

    if value == true then
        ---@type MediaModule
        local MediaModule = T:GetModule("Media")
        MediaModule:AddSounds()
    else
        ConfigurationModule:PromptToReloadUI()
    end
end

---@return boolean isEnabled true if textures are enabled, false otherwise.
function Options:GetTextureEnabled(info)
    return self:GetMediaDB().texturesEnabled or true
end

---@param value boolean isEnabled true to enable textures, false to disable.
function Options:SetTextureEnabled(info, value)
    self:GetMediaDB().texturesEnabled = value

    if value == true then
        ---@type MediaModule
        local MediaModule = T:GetModule("Media")
        MediaModule:AddTextures()
    else
        ConfigurationModule:PromptToReloadUI()
    end
end
