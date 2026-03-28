--[[
    Configuration for adding supplemental media.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class MediaConfigurationOptions
local Options = ConfigurationModule.Options.Media

--- Builds the "Media" configuration menu.
local function BuildMediaConfiguration()
    local optionsTab = ConfigurationModule.Widgets.NewConfigurationSection(30, "Media")
    optionsTab.args = {
        title = ConfigurationModule.Widgets.TitleWidget(0, "Media"),
        description = {
            type = "description",
            name = "Add additional media such as fonts, sounds and textures to further customize your interface.",
            order = 1,
        },
        fontHeader = {
            type = "header",
            name = "Fonts",
            order = 10,
        },
        fontDescription = {
            type = "description",
            name = "Adds several fonts to the font selectors in most addons.",
            order = 10.5,
        },

        fontToggle = {
            type = "toggle",
            name = "Add Fonts",
            desc = "Adds additional fonts to the font selectors.",
            order = 11,
            handler = Options,
            get = "GetFontEnabled",
            set = "SetFontEnabled",
        },
        soundHeader = {
            type = "header",
            name = "Sounds",
            order = 20,
        },
        soundDescription = {
            type = "description",
            name = "Adds several sounds to the sound selectors in most addons.",
            order = 20.5,
        },
        soundToggle = {
            type = "toggle",
            name = "Add Sounds",
            desc = "Adds additional sounds to the sound selectors.",
            order = 21,
            handler = Options,
            get = "GetSoundEnabled",
            set = "SetSoundEnabled",
        },
        textureHeader = {
            type = "header",
            name = "Textures",
            order = 30,
        },
        textureDescription = {
            type = "description",
            name = "Adds several textures to the texture selectors in most addons.",
            order = 30.5,
        },
        textureToggle = {
            type = "toggle",
            name = "Add Textures",
            desc = "Adds additional textures to the texture selectors.",
            order = 31,
            handler = Options,
            get = "GetTextureEnabled",
            set = "SetTextureEnabled",
        },

    }

    return optionsTab
end
