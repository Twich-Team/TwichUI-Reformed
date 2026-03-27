local TwichRx = _G["TwichRx"]
---@type TwichUI
local T = unpack(TwichRx)

---@type Tools
local TM = T.Tools

---@class TexturesTool
---@field Styles table<string, string>
local Textures = TM.Textures or {}
TM.Textures = Textures

local DEFAULT_TEXTURE = "Interface\\GLUES\\CHARACTERCREATE\\UI-CHARACTERCREATE-CLASSES"
local FALLBACK_TEXTURE = "Interface\\FriendsFrame\\InformationIcon"

local TEXTURE_STYLES = {
    DEFAULT = "default",
    FABLED = "fabled",
    PIXEL = "pixel",
}

local TEXTURE_PATHS = {
    [TEXTURE_STYLES.FABLED] = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\fabled.tga",
    [TEXTURE_STYLES.PIXEL] = "Interface\\AddOns\\TwichUI_Reformed\\Media\\Textures\\fabledpixelsv2.tga",
}

Textures.Styles = TEXTURE_STYLES

local textureHelper = {
    WARRIOR = {
        texString = '0:128:0:128',
        texStringLarge = '0:500:0:500',
        texCoords = { 0, 0, 0, 0.125, 0.125, 0, 0.125, 0.125 },
    },
    MAGE = {
        texString = '128:256:0:128',
        texStringLarge = '500:1000:0:500',
        texCoords = { 0.125, 0, 0.125, 0.125, 0.25, 0, 0.25, 0.125 },
    },
    ROGUE = {
        texString = '256:384:0:128',
        texStringLarge = '1000:1500:0:500',
        texCoords = { 0.25, 0, 0.25, 0.125, 0.375, 0, 0.375, 0.125 },
    },
    DRUID = {
        texString = '384:512:0:128',
        texStringLarge = '1500:2000:0:500',
        texCoords = { 0.375, 0, 0.375, 0.125, 0.5, 0, 0.5, 0.125 },
    },
    EVOKER = {
        texString = '512:640:0:128',
        texStringLarge = '2000:2500:0:500',
        texCoords = { 0.5, 0, 0.5, 0.125, 0.625, 0, 0.625, 0.125 },
    },
    HUNTER = {
        texString = '0:128:128:256',
        texStringLarge = '0:500:500:1000',
        texCoords = { 0, 0.125, 0, 0.25, 0.125, 0.125, 0.125, 0.25 },
    },
    SHAMAN = {
        texString = '128:256:128:256',
        texStringLarge = '500:1000:500:1000',
        texCoords = { 0.125, 0.125, 0.125, 0.25, 0.25, 0.125, 0.25, 0.25 },
    },
    PRIEST = {
        texString = '256:384:128:256',
        texStringLarge = '1000:1500:500:1000',
        texCoords = { 0.25, 0.125, 0.25, 0.25, 0.375, 0.125, 0.375, 0.25 },
    },
    WARLOCK = {
        texString = '384:512:128:256',
        texStringLarge = '1500:2000:500:1000',
        texCoords = { 0.375, 0.125, 0.375, 0.25, 0.5, 0.125, 0.5, 0.25 },
    },
    PALADIN = {
        texString = '0:128:256:384',
        texStringLarge = '0:500:1000:1500',
        texCoords = { 0, 0.25, 0, 0.375, 0.125, 0.25, 0.125, 0.375 },
    },
    DEATHKNIGHT = {
        texString = '128:256:256:384',
        texStringLarge = '500:1000:1000:1500',
        texCoords = { 0.125, 0.25, 0.125, 0.375, 0.25, 0.25, 0.25, 0.375 },
    },
    MONK = {
        texString = '256:384:256:384',
        texStringLarge = '1000:1500:1000:1500',
        texCoords = { 0.25, 0.25, 0.25, 0.375, 0.375, 0.25, 0.375, 0.375 },
    },
    DEMONHUNTER = {
        texString = '384:512:256:384',
        texStringLarge = '1500:2000:1000:1500',
        texCoords = { 0.375, 0.25, 0.375, 0.375, 0.5, 0.25, 0.5, 0.375 },
    },
}

local ATLAS_W, ATLAS_H = 1024, 1024

local function NormalizeStyle(style)
    if type(style) ~= "string" then
        return TEXTURE_STYLES.DEFAULT
    end

    style = style:lower()

    if style == TEXTURE_STYLES.FABLED or style == "fabled.tga" then
        return TEXTURE_STYLES.FABLED
    end

    if style == TEXTURE_STYLES.PIXEL or style == "pixels" or style == "fabledpixelsv2" or style == "fabledpixelsv2.tga" then
        return TEXTURE_STYLES.PIXEL
    end

    return TEXTURE_STYLES.DEFAULT
end

function Textures:GetClassTextureData(classFile, style)
    if not classFile then
        return nil
    end

    style = NormalizeStyle(style)
    if style == TEXTURE_STYLES.DEFAULT then
        local coords = CLASS_ICON_TCOORDS and CLASS_ICON_TCOORDS[classFile]
        if not coords then
            return nil
        end

        return {
            texture = DEFAULT_TEXTURE,
            coords = { coords[1], coords[2], coords[3], coords[4] },
            atlasWidth = 256,
            atlasHeight = 256,
            style = style,
        }
    end

    local info = textureHelper[classFile]
    if not info or not info.texCoords then
        return nil
    end

    return {
        texture = TEXTURE_PATHS[style],
        coords = { info.texCoords[1], info.texCoords[5], info.texCoords[2], info.texCoords[8] },
        atlasWidth = ATLAS_W,
        atlasHeight = ATLAS_H,
        style = style,
    }
end

function Textures:ApplyClassTexture(texture, classFile, style)
    if not texture then
        return false
    end

    local textureData = self:GetClassTextureData(classFile, style)
    if not textureData then
        texture:SetTexture(FALLBACK_TEXTURE)
        texture:SetTexCoord(0, 1, 0, 1)
        return false
    end

    texture:SetTexture(textureData.texture)
    texture:SetTexCoord(unpack(textureData.coords))
    return true
end

function Textures:GetClassTextureString(classFile, size, style)
    if not classFile then return nil end
    size = size or 16

    local textureData = self:GetClassTextureData(classFile, style)
    if not textureData then
        return ("|T%s:%d:%d|t"):format(FALLBACK_TEXTURE, size, size)
    end

    local left = textureData.coords[1] * textureData.atlasWidth
    local right = textureData.coords[2] * textureData.atlasWidth
    local top = textureData.coords[3] * textureData.atlasHeight
    local bottom = textureData.coords[4] * textureData.atlasHeight

    return ("|T%s:%d:%d:0:0:%d:%d:%d:%d:%d:%d|t"):format(
        textureData.texture,
        size, size,
        textureData.atlasWidth, textureData.atlasHeight,
        left, right, top, bottom
    )
end

function Textures:GetPlayerClassTextureString(size, style)
    local _, classFile = UnitClass("player")
    return self:GetClassTextureString(classFile, size, style)
end
