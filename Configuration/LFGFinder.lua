--[[
    LFG Finder Configuration - Integrated into Mythic+ Tools
    Provides the configuration subsection for LFG Finder within Mythic+ Tools.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

-- This function is called by MythicPlusTools.lua to inject LFG Finder config
function ConfigurationModule:GetLFGFinderConfigSection()
    local W = self.Widgets
    local Options = self.Options.LFGFinder
    
    return {
        type = "group",
        name = "LFG Finder",
        order = 42,
        args = {
            desc = W.Description(1, 
                "Advanced group finder with intelligent filtering, sorting, and dual-mode browser for searching groups and reviewing applications."),
            
            enable = {
                type = "toggle",
                name = "Enable LFG Finder",
                desc = "Enable the LFG Finder module for advanced group browsing.",
                order = 1,
                width = 1.5,
                handler = Options,
                get = "GetEnabled",
                set = "SetEnabled",
            },
            
            browserOptions = W.IGroup(2, "Browser Settings", {
                autoOpen = {
                    type = "toggle",
                    name = "Auto-Open on LFG Panel",
                    desc = "Automatically open the LFG Finder when you open the Blizzard Group Finder.",
                    order = 1,
                    width = 1.8,
                    handler = Options,
                    get = "GetAutoOpen",
                    set = "SetAutoOpen",
                },
                muteApplicantPing = {
                    type = "toggle",
                    name = "Mute Applicant Sound",
                    desc = "Suppress the alert sound when someone applies to your group.",
                    order = 2,
                    width = 1.6,
                    handler = Options,
                    get = "GetMuteApplicantPing",
                    set = "SetMuteApplicantPing",
                },
            }),
            
            filters = W.IGroup(4, "Default Filters", {
                difficulty = {
                    type = "select",
                    name = "Default Difficulty",
                    desc = "Filter by group difficulty level.",
                    order = 1,
                    width = 1.6,
                    values = {
                        ANY = "Any",
                        MYTHIC_PLUS = "Mythic+",
                        RAID = "Raid",
                        PVP = "PvP",
                    },
                    handler = Options,
                    get = "GetSelectedDifficulty",
                    set = "SetSelectedDifficulty",
                },
                
                keyMin = {
                    type = "range",
                    name = "Min Keystone Level",
                    desc = "Minimum keystoke level to display by default.",
                    order = 2,
                    min = 2,
                    max = 20,
                    step = 1,
                    width = 1.4,
                    handler = Options,
                    get = "GetMinKeystone",
                    set = "SetMinKeystone",
                },
                
                keyMax = {
                    type = "range",
                    name = "Max Keystone Level",
                    desc = "Maximum keystone level to display by default.",
                    order = 3,
                    min = 2,
                    max = 20,
                    step = 1,
                    width = 1.4,
                    handler = Options,
                    get = "GetMaxKeystone",
                    set = "SetMaxKeystone",
                },
                
                minimumRating = {
                    type = "range",
                    name = "Minimum Group Rating",
                    desc = "Hide groups with lower average group ratings.",
                    order = 4,
                    min = 0,
                    max = 4000,
                    step = 100,
                    width = 1.6,
                    handler = Options,
                    get = "GetMinimumRating",
                    set = "SetMinimumRating",
                },
                
                needsTank = {
                    type = "toggle",
                    name = "Only Need Tank",
                    desc = "Hide groups that already have a tank.",
                    order = 5,
                    width = 1.5,
                    handler = Options,
                    get = "GetNeedsTank",
                    set = "SetNeedsTank",
                },
                
                needsHealer = {
                    type = "toggle",
                    name = "Only Need Healer",
                    desc = "Hide groups that already have a healer.",
                    order = 6,
                    width = 1.6,
                    handler = Options,
                    get = "GetNeedsHealer",
                    set = "SetNeedsHealer",
                },
                
                needsDPS = {
                    type = "toggle",
                    name = "Only Need DPS",
                    desc = "Hide groups that don't need additional DPS.",
                    order = 7,
                    width = 1.5,
                    handler = Options,
                    get = "GetNeedsDPS",
                    set = "SetNeedsDPS",
                },
                
                hideDeclined = {
                    type = "toggle",
                    name = "Hide Declined Applications",
                    desc = "Don't show groups that declined your application.",
                    order = 8,
                    width = 1.8,
                    handler = Options,
                    get = "GetHideDeclined",
                    set = "SetHideDeclined",
                },
            }),
            
            appearance = W.IGroup(20, "Appearance Overrides", {
                desc = W.Description(1, 
                    "The LFG Finder inherits from global Appearance settings. Override here for fine-tuning."),
                
                frameTrans = {
                    type = "range",
                    name = "Frame Transparency",
                    desc = "Opacity of the LFG Finder window.",
                    order = 1,
                    min = 0.3,
                    max = 1.0,
                    step = 0.05,
                    width = 1.6,
                    handler = Options,
                    get = "GetFrameTransparency",
                    set = "SetFrameTransparency",
                },
                
                fontSize = {
                    type = "range",
                    name = "Font Size",
                    desc = "Text size in the group browser.",
                    order = 2,
                    min = 8,
                    max = 16,
                    step = 1,
                    width = 1.4,
                    handler = Options,
                    get = "GetFontSize",
                    set = "SetFontSize",
                },
                
                rowHeight = {
                    type = "range",
                    name = "Row Height",
                    desc = "Height of each group row.",
                    order = 3,
                    min = 18,
                    max = 36,
                    step = 1,
                    width = 1.4,
                    handler = Options,
                    get = "GetRowHeight",
                    set = "SetRowHeight",
                },
            }),
        },
    }
end
