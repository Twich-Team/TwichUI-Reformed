--[[
    Module that adds additional interface customization options to the game.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class MediaModule : AceModule
---@field Loader MediaLoader
local MediaModule = T:NewModule("Media")
MediaModule:SetEnabledState(true)

local LSM = LibStub("LibSharedMedia-3.0")

MediaModule.Fonts = {
    { name = "Roboto-Regular",  extension = "ttf" },
    { name = "Roboto-Italic",   extension = "ttf" },
    { name = "Roboto-Bold",     extension = "ttf" },
    { name = "Inter",           extension = "ttf" },
    { name = "Inter-Italic",    extension = "ttf" },
    { name = "Inter-Bold",      extension = "ttf" },
    { name = "Inter-ExtraBold", extension = "ttf" },
    { name = "Exo2-Bold",       extension = "ttf" },
    { name = "Exo2-BoldItalic", extension = "ttf" },
    { name = "Exo2-ExtraBold",  extension = "ttf" },
    { name = "Exo2-Italic",     extension = "ttf" },
    { name = "Exo2-Light",      extension = "ttf" },
    { name = "Exo2-Regular",    extension = "ttf" },
    { name = "Exo2-SemiBold",   extension = "ttf" },
    { name = "Exo2-Thin",       extension = "ttf" },
}

MediaModule.Sounds = {
    { name = "Game-Ping",                    extension = "mp3" },
    { name = "Game-Success",                 extension = "mp3" },
    { name = "Ping",                         extension = "mp3" },
    { name = "Notable-Loot",                 extension = "mp3" },
    { name = "Game-Error",                   extension = "mp3" },
    { name = "TwichUI-Chat-Ping",            extension = "mp3" },
    { name = "TwichUI-Green-Dude-Gets-Loot", extension = "mp3" },
    { name = "TwichUI-Menu-Click",           extension = "mp3" },
    { name = "TwichUI-Menu-Confirm",         extension = "mp3" },
    { name = "TwichUI-Notification-1",       extension = "mp3" },
    { name = "TwichUI-Notification-2",       extension = "mp3" },
    { name = "TwichUI-Notification-3",       extension = "mp3" },
    { name = "TwichUI-Notification-4",       extension = "mp3" },
    { name = "TwichUI-Notification-5",       extension = "mp3" },
    { name = "TwichUI-Notification-6",       extension = "mp3" },
    { name = "TwichUI-Notification-7",       extension = "mp3" },
    { name = "TwichUI-Notification-8",       extension = "mp3" },
    { name = "TwichUI-Notification-9",       extension = "mp3" },
    { name = "TwichUI-Notification-10",      extension = "mp3" },
    { name = "TwichUI-Notification-11",      extension = "mp3" },
    { name = "TwichUI-Notification-12",      extension = "mp3" },
    { name = "TwichUI-Notification-13",      extension = "mp3" },
    { name = "TwichUI-Alert-1",              extension = "mp3" },
    { name = "TwichUI-Alert-2",              extension = "mp3" },
    { name = "TwichUI-Alert-3",              extension = "mp3" },
    { name = "TwichUI-Alert-4",              extension = "mp3" },
    { name = "TwichUI-Prey",                 extension = "mp3" },
}

MediaModule.Textures = {
    { name = "TwichUI-Bright",      extension = "tga" },
    { name = "TwichUI-Shade",       extension = "tga" },
    { name = "TwichUI-Smooth",      extension = "tga" },
    { name = "TwichUI-AngledLines", extension = "tga" }
}

function MediaModule:OnInitialize()
    self:AddFonts()
    self:AddSounds()
    self:AddTextures()
end

function MediaModule:AddFonts()
    for _, font in pairs(self.Fonts) do
        self.Loader:RegisterMedia(LSM.MediaType.FONT, font.name, font.extension)
    end
end

function MediaModule:AddSounds()
    for _, sound in pairs(self.Sounds) do
        self.Loader:RegisterMedia(LSM.MediaType.SOUND, sound.name, sound.extension)
    end
end

function MediaModule:AddTextures()
    for _, texture in pairs(self.Textures) do
        self.Loader:RegisterMedia(LSM.MediaType.STATUSBAR, texture.name, texture.extension)
    end
end
