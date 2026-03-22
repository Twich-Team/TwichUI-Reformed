--[[
    Contains slash command logic for the addon.
]]
---@type TwichUI
local TwichRx = _G.TwichRx
local T = unpack(TwichRx)

local function OpenConfigurationPanel(input)
    local command = type(input) == "string" and input:match("^%s*(.-)%s*$") or ""

    if command == "chores" then
        ---@type DataTextModule
        local datatextModule = T:GetModule("Datatexts")
        ---@type ChoresDataText|nil
        ---@diagnostic disable-next-line: undefined-field
        local choresDataText = datatextModule and datatextModule.GetModule and
        datatextModule:GetModule("ChoresDataText", true)
        if choresDataText and choresDataText.ShowTrackerFrame then
            choresDataText:ShowTrackerFrame()
            return
        end

        T:Print("[TwichUI] Chores tracker is unavailable")
        return
    end

    ---@type ConfigurationModule
    local ConfigurationModule = T:GetModule("Configuration")
    ConfigurationModule:ToggleOptionsUI()
end

T:RegisterChatCommand("tui", OpenConfigurationPanel)

local function StartRaidFrameGlowTest()
    local module = T:GetModule("RaidFrames", true)
    if not module or not module.IsEnabled or not module:IsEnabled() then
        T:Print("[TwichUI] RaidFrames module is not enabled")
        return
    end

    module:StartTest(8)
end

T:RegisterChatCommand("tuirftest", StartRaidFrameGlowTest)

local function DebugRaidFrameUnit(input)
    local module = T:GetModule("RaidFrames", true)
    if not module or type(module.DebugUnit) ~= "function" then
        T:Print("[TwichUI] RaidFrames debug is unavailable")
        return
    end

    module:DebugUnit(type(input) == "string" and input ~= "" and input or "player")
end

T:RegisterChatCommand("tuirfdebug", DebugRaidFrameUnit)

local function FindTexture(input)
    local f = (GetMouseFoci and GetMouseFoci()[1]) or GetMouseFocus()
    if not f then
        T:Print("[TwichUI] /findtexture: No frame under mouse")
        return
    end

    local filter = nil
    if type(input) == "string" and input ~= "" then
        filter = input:lower()
    end

    T:Print("[TwichUI] Frame:", f:GetName() or "<unnamed>")

    -- iterate all regions from GetRegions()
    local index = 1
    local found = false
    while true do
        local r = select(index, f:GetRegions())
        if not r then break end

        if r.IsObjectType and r:IsObjectType("Texture") then
            local tex = r:GetTexture()
            local atlas = r.GetAtlas and r:GetAtlas()
            if tex or atlas then
                local a, b, c, d, e, f2, g, h = r:GetTexCoord()

                local texStr = tex and tostring(tex) or ""
                local atlasStr = atlas and tostring(atlas) or ""

                if not filter or texStr:lower():find(filter, 1, true) or atlasStr:lower():find(filter, 1, true) then
                    found = true

                    if tex then
                        -- fileID or path sample
                        local numericId = tonumber(texStr)
                        if numericId then
                            T:Print(string.format("[%d] fileID=%s texCoords=%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
                                index, texStr, a or 0, b or 0, c or 0, d or 0, e or 0, f2 or 0, g or 0, h or 0))
                            T:Print(string.format("    sample: \"|T%s:16:16|t\"", texStr))
                        else
                            T:Print(string.format(
                                "[%d] texture=\"%s\" texCoords=%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
                                index, texStr, a or 0, b or 0, c or 0, d or 0, e or 0, f2 or 0, g or 0, h or 0))
                            T:Print(string.format("    sample: \"|T%s:16:16|t\"", texStr))
                        end
                    end

                    if atlas then
                        T:Print(string.format("[%d] atlas=\"%s\" texCoords=%.3f %.3f %.3f %.3f %.3f %.3f %.3f %.3f",
                            index, atlasStr, a or 0, b or 0, c or 0, d or 0, e or 0, f2 or 0, g or 0, h or 0))
                        T:Print(string.format("    sample: \"|A:%s:16:16|a\"", atlasStr))
                    end
                end
            end
        end

        index = index + 1
    end

    if not found then
        if filter then
            print("[TwichUI] /findtexture: No textures/atlases matched filter '", filter, "'")
        else
            print("[TwichUI] /findtexture: No textures or atlases on this frame")
        end
    end
end

T:RegisterChatCommand("findtexture", FindTexture)

local function ShowMPTDebugPanel()
    local mpt = _G.TwichUIMythicPlusToolsRuntime
    if not mpt or type(mpt.ShowDebugFrame) ~= "function" then
        T:Print("[TwichUI] Mythic+ Tools debug is unavailable")
        return
    end
    mpt:ShowDebugFrame()
end

T:RegisterChatCommand("tuimptdebug", ShowMPTDebugPanel)
