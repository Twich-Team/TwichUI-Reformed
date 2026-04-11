---@diagnostic disable: undefined-field, need-check-nil
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class MapTweaksModule : AceModule, AceEvent-3.0
local MT = QOL:NewModule("MapTweaks", "AceEvent-3.0")
MT:SetEnabledState(false)

local C_CVar = _G.C_CVar
local C_Map = _G.C_Map
local C_MapExplorationInfo = _G.C_MapExplorationInfo
local C_Timer = _G.C_Timer
local UIParent = _G.UIParent
local WorldMapFrame = _G["WorldMapFrame"]
local TexturePool_HideAndClearAnchors = _G["TexturePool_HideAndClearAnchors"]
local ceil = math.ceil
local mod = math.fmod
local ipairs = ipairs
local pairs = pairs
local strsplit = strsplit
local tinsert = table.insert
local wipe = wipe

local originalMapFade = nil
local hooksInstalled = false
local battlefieldLoaded = false

local function GetOptions()
    local configurationModule = T:GetModule("Configuration")
    return (configurationModule.Options --[[@as any]]).MapTweaks
end

local function IsFeatureEnabled(path)
    local options = GetOptions()
    return options:GetEnabled() and options:GetValue(path, false) == true
end

local function ResetTexturePoolColor(pool, texture)
    texture:SetVertexColor(1, 1, 1, 1)
    texture:SetAlpha(1)
    return TexturePool_HideAndClearAnchors(pool, texture)
end

local function ClearInjectedTextures(pin)
    if not pin or not pin.TwichUIRevealTextures then
        return
    end

    for index = 1, #pin.TwichUIRevealTextures do
        local texture = pin.TwichUIRevealTextures[index]
        if texture then
            texture:SetVertexColor(1, 1, 1, 1)
            texture:SetAlpha(1)
            texture:Hide()
        end
    end

    wipe(pin.TwichUIRevealTextures)
end

local function AcquireRevealTextures(pin)
    if not pin.TwichUIRevealTextures then
        pin.TwichUIRevealTextures = {}
    end
    return pin.TwichUIRevealTextures
end

local function GetMapFramePinMapID(pin)
    if pin and pin:GetMap() and pin:GetMap().mapID then
        return pin:GetMap().mapID
    end
    return WorldMapFrame and WorldMapFrame.mapID or nil
end

local function DrawRevealOverlays(pin)
    ClearInjectedTextures(pin)

    if not IsFeatureEnabled({ "reveal", "enabled" }) then
        return
    end

    local mapID = GetMapFramePinMapID(pin)
    if not mapID then
        return
    end

    local artID = C_Map.GetMapArtID(mapID)
    local revealDB = T.MapRevealData and T.MapRevealData[artID]
    if not artID or type(revealDB) ~= "table" then
        return
    end

    local explored = {}
    local exploredTextures = C_MapExplorationInfo.GetExploredMapTextures(mapID)
    if exploredTextures then
        for _, textureInfo in ipairs(exploredTextures) do
            explored[(textureInfo.textureWidth or 0) .. ":" .. (textureInfo.textureHeight or 0) .. ":" .. (textureInfo.offsetX or 0) .. ":" .. (textureInfo.offsetY or 0)] = true
        end
    end

    pin.layerIndex = pin:GetMap():GetCanvasContainer():GetCurrentLayerIndex()
    local layers = C_Map.GetMapArtLayers(mapID)
    local layerInfo = layers and layers[pin.layerIndex]
    if not layerInfo then
        return
    end

    local mapInfo = C_Map.GetMapInfo(mapID)
    local mapType = mapInfo and mapInfo.mapType or 0
    local tileWidth = layerInfo.tileWidth
    local tileHeight = layerInfo.tileHeight
    local tintEnabled = IsFeatureEnabled({ "tint", "enabled" })
    local tintR = GetOptions():GetValue({ "tint", "r" }, 0.6)
    local tintG = GetOptions():GetValue({ "tint", "g" }, 0.6)
    local tintB = GetOptions():GetValue({ "tint", "b" }, 1)
    local tintA = GetOptions():GetValue({ "tint", "a" }, 1)
    local textures = AcquireRevealTextures(pin)

    for key, files in pairs(revealDB) do
        if not explored[key] then
            local widthText, heightText, offsetXText, offsetYText = strsplit(":", key)
            local width = tonumber(widthText) or 0
            local height = tonumber(heightText) or 0
            local offsetX = tonumber(offsetXText) or 0
            local offsetY = tonumber(offsetYText) or 0

            local fileIDs = { strsplit(",", files) }
            local texturesWide = ceil(width / tileWidth)
            local texturesTall = ceil(height / tileHeight)
            local fileIndex = 1

            for row = 1, texturesTall do
                local pixelHeight = row < texturesTall and tileHeight or mod(height, tileHeight)
                if pixelHeight == 0 then
                    pixelHeight = tileHeight
                end

                local fileHeight = 16
                while fileHeight < pixelHeight do
                    fileHeight = fileHeight * 2
                end

                for column = 1, texturesWide do
                    local pixelWidth = column < texturesWide and tileWidth or mod(width, tileWidth)
                    if pixelWidth == 0 then
                        pixelWidth = tileWidth
                    end

                    local fileWidth = 16
                    while fileWidth < pixelWidth do
                        fileWidth = fileWidth * 2
                    end

                    local texture = pin.overlayTexturePool:Acquire()
                    texture:SetSize(pixelWidth, pixelHeight)
                    texture:SetTexCoord(0, pixelWidth / fileWidth, 0, pixelHeight / fileHeight)
                    texture:SetPoint("TOPLEFT", offsetX + (tileWidth * (column - 1)),
                        -(offsetY + (tileHeight * (row - 1))))
                    texture:SetTexture(tonumber(fileIDs[fileIndex] or fileIDs[#fileIDs]), nil, nil, "TRILINEAR")
                    texture:SetDrawLayer("ARTWORK", -1)
                    if tintEnabled and mapType == 3 then
                        texture:SetVertexColor(tintR, tintG, tintB, tintA)
                    else
                        texture:SetVertexColor(1, 1, 1, 1)
                    end
                    texture:Show()
                    if pin.textureLoadGroup then
                        pin.textureLoadGroup:AddTexture(texture)
                    end
                    tinsert(textures, texture)
                    fileIndex = fileIndex + 1
                end
            end
        end
    end
end

local function HookMapExplorationPins(mapFrame)
    if not mapFrame or not mapFrame.EnumeratePinsByTemplate then
        return
    end

    for pin in mapFrame:EnumeratePinsByTemplate("MapExplorationPinTemplate") do
        if not pin.TwichUIRevealHooked then
            hooksecurefunc(pin, "RefreshOverlays", DrawRevealOverlays)
            if pin.overlayTexturePool then
                pin.overlayTexturePool.resetterFunc = ResetTexturePoolColor
            end
            pin.TwichUIRevealHooked = true
        end
        DrawRevealOverlays(pin)
    end
end

local function EnsureBattlefieldMapLoaded()
    if battlefieldLoaded then
        return
    end

    battlefieldLoaded = true
    if not _G["BattlefieldMapFrame"] and _G.C_AddOns and type(_G.C_AddOns.LoadAddOn) == "function" then
        _G.C_AddOns.LoadAddOn("Blizzard_BattlefieldMap")
    elseif not _G["BattlefieldMapFrame"] and type(_G["LoadAddOn"]) == "function" then
        _G["LoadAddOn"]("Blizzard_BattlefieldMap")
    end
end

function MT:ApplyMapPosition(skipRefresh)
    if not WorldMapFrame then
        return
    end

    local unlockEnabled = IsFeatureEnabled({ "unlock", "enabled" })
    local db = T:GetModule("Configuration"):GetProfileDB().mapTweaks
    local target = WorldMapFrame:IsMaximized() and db.position.maximized or db.position.normal

    WorldMapFrame:ClearAllPoints()
    if unlockEnabled then
        WorldMapFrame:SetPoint(target.point, UIParent, target.relativePoint, target.x, target.y)
    else
        WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -94)
    end

    if not skipRefresh then
        HookMapExplorationPins(WorldMapFrame)
        if _G["BattlefieldMapFrame"] then
            HookMapExplorationPins(_G["BattlefieldMapFrame"])
        end
    end
end

function MT:RefreshSettings()
    if not self:IsEnabled() then
        return
    end

    if originalMapFade == nil then
        originalMapFade = C_CVar.GetCVar and C_CVar.GetCVar("mapFade") or _G.GetCVar("mapFade")
    end

    if IsFeatureEnabled({ "fade", "enabled" }) then
        _G.SetCVar("mapFade", "0")
    elseif originalMapFade ~= nil then
        _G.SetCVar("mapFade", tostring(originalMapFade))
    end

    if WorldMapFrame then
        WorldMapFrame:SetMovable(IsFeatureEnabled({ "unlock", "enabled" }))
        WorldMapFrame:SetClampedToScreen(true)
    end

    self:ApplyMapPosition()
end

function MT:PLAYER_ENTERING_WORLD()
    self:RefreshSettings()
end

local function SaveMapPosition()
    if not IsFeatureEnabled({ "unlock", "enabled" }) or not WorldMapFrame then
        return
    end

    local db = T:GetModule("Configuration"):GetProfileDB().mapTweaks
    local point, _, relativePoint, x, y = WorldMapFrame:GetPoint()
    local target = WorldMapFrame:IsMaximized() and db.position.maximized or db.position.normal
    target.point = point or target.point
    target.relativePoint = relativePoint or target.relativePoint
    target.x = x or target.x
    target.y = y or target.y
end

local function InstallHooks()
    if hooksInstalled or not WorldMapFrame then
        return
    end
    hooksInstalled = true

    C_Timer.After(0.1, function()
        if not WorldMapFrame then
            return
        end

        WorldMapFrame:SetAttribute("UIPanelLayout-area", nil)
        WorldMapFrame:SetAttribute("UIPanelLayout-enabled", false)
        WorldMapFrame:SetAttribute("UIPanelLayout-allowOtherPanels", true)
    end)

    WorldMapFrame:RegisterForDrag("LeftButton")
    WorldMapFrame:SetScript("OnDragStart", function(frame)
        if IsFeatureEnabled({ "unlock", "enabled" }) and GetOptions():GetValue({ "unlock", "movement" }, true) then
            frame:StartMoving()
        end
    end)

    WorldMapFrame:SetScript("OnDragStop", function(frame)
        frame:StopMovingOrSizing()
        SaveMapPosition()
        MT:ApplyMapPosition(true)
    end)

    hooksecurefunc(WorldMapFrame, "SynchronizeDisplayState", function()
        MT:ApplyMapPosition(true)
    end)

    hooksecurefunc(WorldMapFrame, "OnFrameSizeChanged", function()
        MT:ApplyMapPosition(true)
    end)

    hooksecurefunc(_G.C_ChatInfo, "PerformEmote", function(emote)
        if emote == "READ" and WorldMapFrame and WorldMapFrame:IsShown() and IsFeatureEnabled({ "emote", "enabled" }) then
            _G.C_ChatInfo.CancelEmote()
        end
    end)
end

function MT:OnEnable()
    InstallHooks()
    EnsureBattlefieldMapLoaded()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RefreshSettings()
end

function MT:OnDisable()
    self:UnregisterAllEvents()
    if originalMapFade ~= nil then
        _G.SetCVar("mapFade", tostring(originalMapFade))
    end
    if WorldMapFrame then
        WorldMapFrame:StopMovingOrSizing()
        WorldMapFrame:SetMovable(false)
        WorldMapFrame:ClearAllPoints()
        WorldMapFrame:SetPoint("TOPLEFT", UIParent, "TOPLEFT", 16, -94)
    end
    HookMapExplorationPins(WorldMapFrame)
    if _G["BattlefieldMapFrame"] then
        HookMapExplorationPins(_G["BattlefieldMapFrame"])
    end
end
