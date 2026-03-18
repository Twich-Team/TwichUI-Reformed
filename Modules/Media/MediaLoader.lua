local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

local LSM = LibStub("LibSharedMedia-3.0")

---@type MediaModule
local MediaModule = T:GetModule("Media")

---@class MediaLoader
local MediaLoader = MediaModule.Loader or {}
MediaModule.Loader = MediaLoader

MediaLoader.MediaRoot = "Interface\\AddOns\\TwichUI_Redux\\Media"
MediaLoader.FontPath = "Fonts"
MediaLoader.TexturePath = "Textures"
MediaLoader.SoundPath = "Sounds"

function MediaLoader:RegisterMedia(type, fileName, fileExtension)
    if type == LSM.MediaType.FONT then
        local fullPath = string.format("%s\\%s\\%s.%s", MediaLoader.MediaRoot, MediaLoader.FontPath, fileName,
            fileExtension)
        local name = string.gsub(fileName, "-", " ")
        LSM:Register(LSM.MediaType.FONT, name, fullPath)
    end

    if type == LSM.MediaType.SOUND then
        local fullPath = string.format("%s\\%s\\%s.%s", MediaLoader.MediaRoot, MediaLoader.SoundPath, fileName,
            fileExtension)
        local name = string.gsub(fileName, "-", " ")
        LSM:Register(LSM.MediaType.SOUND, name, fullPath)
    end

    if type == LSM.MediaType.STATUSBAR then
        local fullPath = string.format("%s\\%s\\%s.%s", MediaLoader.MediaRoot, MediaLoader.TexturePath, fileName,
            fileExtension)
        local name = string.gsub(fileName, "-", " ")
        LSM:Register(LSM.MediaType.STATUSBAR, name, fullPath)
    end
end
