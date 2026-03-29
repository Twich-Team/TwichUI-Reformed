--[[
    Contains slash command logic for the addon.
]]
---@type TwichUI
local TwichRx = _G.TwichRx
local T = unpack(TwichRx)

local function OpenConfigurationPanel(input)
    local command = type(input) == "string" and input:match("^%s*(.-)%s*$") or ""
    local primaryCommand, remainder = command:match("^(%S+)%s*(.-)%s*$")
    primaryCommand = primaryCommand or ""
    remainder = remainder or ""

    if primaryCommand == "chores" then
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

    if primaryCommand == "debug" then
        local console = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
        if not console or type(console.Show) ~= "function" then
            T:Print("[TwichUI] Debug console is unavailable")
            return
        end

        if remainder ~= "" and not console:ResolveSourceKey(remainder) then
            local available = console:ListSourceTitles()
            if #available > 0 then
                T:Print("[TwichUI] Unknown debug source. Available sources: " .. table.concat(available, ", "))
            else
                T:Print("[TwichUI] No debug sources are registered")
            end
            return
        end

        console:Show(remainder ~= "" and remainder or nil)
        return
    end

    if primaryCommand == "wizard" then
        ---@type SetupWizardModule
        local SetupWizardModule = T:GetModule("SetupWizard", true)
        if not SetupWizardModule then
            T:Print("[TwichUI] Setup wizard is unavailable")
            return
        end

        local subCmd, subArgs = remainder:match("^(%S+)%s*(.-)%s*$")
        subCmd = subCmd or ""

        if subCmd == "capture" then
            -- /tui wizard capture [layoutId] [layoutName]
            local layoutId, layoutName = subArgs:match("^(%S+)%s*(.-)%s*$")
            SetupWizardModule:CaptureLayoutFrames(layoutId, layoutName)
            return
        end

        if subCmd == "reset" then
            SetupWizardModule:Reset()
            T:Print("[TwichUI] Setup wizard reset — it will appear on next login.")
            return
        end

        -- Default: show wizard
        SetupWizardModule:Show()
        return
    end

    if primaryCommand == "errors" then
        if remainder == "test" then
            local el = T.Tools and (T.Tools --[[@as any]]).ErrorLog --[[@as TwichUIErrorLog|nil]]
            if not el then
                T:Print("[TwichUI] Error log is unavailable")
                return
            end
            local fakeStack =
                "Interface\\AddOns\\TwichUI_Reformed\\Modules\\ChatEnhancements\\ChatRenderer.lua:1183: attempt to index a nil value (field 'settings')\n" ..
                "stack traceback:\n" ..
                "\tInterface\\AddOns\\TwichUI_Reformed\\Modules\\ChatEnhancements\\ChatRenderer.lua:1183: in method 'RefreshRow'\n" ..
                "\tInterface\\AddOns\\TwichUI_Reformed\\Modules\\ChatEnhancements\\ChatRenderer.lua:842: in method 'LayoutRenderer'\n" ..
                "\tInterface\\AddOns\\TwichUI_Reformed\\Core.lua:95: in function <TwichUI_Reformed\\Core.lua:74>"
            el:_InjectTestError(fakeStack)
            T:Print("[TwichUI] Test error injected into log.")
            return
        end
        local viewer = T.Tools and T.Tools.UI and T.Tools.UI.ErrorLogViewer
        if not viewer then
            T:Print("[TwichUI] Error log viewer is unavailable")
            return
        end
        viewer:Toggle()
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
