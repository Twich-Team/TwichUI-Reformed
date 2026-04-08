--[[
    Development datatext providing quick access to debugger, error log, bug sack, and profiler functions.
]]
---@diagnostic disable: undefined-field
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type DataTextModule
local DatatextModule = T:GetModule("Datatexts")

local IsAddOnLoaded = _G.IsAddOnLoaded
local C_AddOns = _G.C_AddOns

---@class DevelopmentDataText : AceModule
local DevDT = DatatextModule:NewModule("DevelopmentDataText")

local function SetDevText(panel)
    if not (panel and panel.text) then
        return
    end

    panel.text:SetText("Dev")
    panel.text:SetTextColor(0.8, 0.8, 0.8)
end

function DevDT:OnEnter(panel)
    if not panel or not panel.text then
        return
    end

    panel.text:SetTextColor(0.5, 0.8, 1.0)

    local tooltip = DatatextModule:GetElvUITooltip()
    if not tooltip then return end

    tooltip:ClearLines()
    tooltip:AddLine("TwichUI Development Tools")
    tooltip:AddLine(" ")
    tooltip:AddLine(T.Tools.Text.Color(T.Tools.Colors.GRAY, "Left-click  — Open menu"))
    DatatextModule:ShowDatatextTooltip(tooltip)
end

function DevDT:OnLeave(panel)
    SetDevText(panel)
    DatatextModule:HideDatatextTooltip(DatatextModule:GetActiveDatatextTooltip())
end

function DevDT:OnClick(panel, button)
    if button ~= "LeftButton" then
        return
    end

    local menuList = {}

    -- Debugger
    do
        local debugConsole = T.Tools and T.Tools.UI and T.Tools.UI.DebugConsole
        if debugConsole and type(debugConsole.Show) == "function" then
            table.insert(menuList, {
                text = "Open Debugger",
                notCheckable = true,
                func = function()
                    debugConsole:Show()
                end,
            })
        end
    end

    -- Error Log Viewer
    do
        local errorLogViewer = T.Tools and T.Tools.UI and T.Tools.UI.ErrorLogViewer
        if errorLogViewer and type(errorLogViewer.Toggle) == "function" then
            table.insert(menuList, {
                text = "Open Error Log",
                notCheckable = true,
                func = function()
                    errorLogViewer:Toggle()
                end,
            })
        end
    end

    -- Bug Sack
    do
        local bugSackLoaded = C_AddOns.IsAddOnLoaded("BugSack")
        if bugSackLoaded then
            table.insert(menuList, {
                text = "Open BugSack",
                notCheckable = true,
                func = function()
                    if _G.BugSack and type(_G.BugSack.Open) == "function" then
                        _G.BugSack:Open()
                    elseif _G.SlashCmdList and _G.SlashCmdList.BugSack then
                        _G.SlashCmdList.BugSack("")
                    end
                end,
            })

            table.insert(menuList, {
                text = "Clear BugSack",
                notCheckable = true,
                func = function()
                    if _G.BugSack and type(_G.BugSack.Clear) == "function" then
                        _G.BugSack:Clear()
                    elseif _G.SlashCmdList and _G.SlashCmdList.BugSack then
                        _G.SlashCmdList.BugSack("clear")
                    end
                    T:Print("[TwichUI] BugSack cleared")
                end,
            })
        end
    end

    -- Profiler separator and options
    do
        local profiler = T.Tools and T.Tools.UI and T.Tools.UI.Profiler
        if profiler then
            if #menuList > 0 then
                table.insert(menuList, {
                    text = "",
                    notCheckable = true,
                    notClickable = true,
                })
            end

            local isActive = profiler:IsActive()

            table.insert(menuList, {
                text = isActive and "Stop Profiling" or "Start Profiling",
                notCheckable = true,
                func = function()
                    if isActive then
                        profiler:StopProfiling()
                    else
                        profiler:StartProfiling()
                    end
                end,
            })

            if isActive then
                table.insert(menuList, {
                    text = "View Profile Report",
                    notCheckable = true,
                    func = function()
                        local profilerUI = T.Tools and T.Tools.UI and T.Tools.UI.ProfilerUI
                        if profilerUI and type(profilerUI.Show) == "function" then
                            profilerUI:Show()
                        else
                            T:Print(profiler:GenerateReport())
                        end
                    end,
                })

                table.insert(menuList, {
                    text = "Export Profile Data",
                    notCheckable = true,
                    func = function()
                        local exportData = profiler:ExportData()
                        T:Print(exportData)
                        T:Print("\n|cff69b86fProfiler data exported above. Copy and save to a file for analysis.|r")
                    end,
                })

                table.insert(menuList, {
                    text = "Clear Profile Data",
                    notCheckable = true,
                    func = function()
                        profiler:ClearProfiles()
                        T:Print("[TwichUI] Profile data cleared")
                    end,
                })
            end
        end
    end

    if #menuList == 0 then
        T:Print("[TwichUI] No development tools available")
        return
    end

    DatatextModule:ShowMenu(panel, menuList)
end

function DevDT:OnInitialize()
    ---@class DatatextDefinition
    self.definition = {
        name = "TwichUI: Development",
        prettyName = "Development",
        events = {
            "PLAYER_ENTERING_WORLD",
        },
        onEventFunc = function(panel)
            SetDevText(panel)
        end,
        onClickFunc = DatatextModule:CreateBoundCallback(self, "OnClick"),
        onEnterFunc = DatatextModule:CreateBoundCallback(self, "OnEnter"),
        onLeaveFunc = DatatextModule:CreateBoundCallback(self, "OnLeave"),
        module = self,
    }

    DatatextModule:Inform(self.definition)
end
