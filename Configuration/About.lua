--[[
    Configuration for adding supplemental media.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class AboutConfigurationOptions
local Options = ConfigurationModule.Options.About

--- Builds the "About" configuration menu.
local function BuildAboutConfiguration()
    local W = ConfigurationModule.Widgets
    local optionsTab = W.NewConfigurationSection(100, "About")
    optionsTab.args = {
        title = W.TitleWidget(0, "About"),
        desc = W.Description(5,
            "TwichUI is a collection of small, quality-of-life improvements for ElvUI. It is designed to be lightweight and modular, allowing you to enable only the features you want."),
        disc = W.IGroup(10, "Disclaimer", {
            disclaimer = W.Description(0,
                "AddOn development takes a lot of time and effort. Please be patient with bugs and new features."),
        }),
        roadmap = W.IGroup(20, "Roadmap", {
            a = W.Description(0, "The following features are planned for future releases!"),
            space = W.Spacer(1),
            b = W.Description(5, "• Scan for Satchels from LFG and be notified when one is available."),
            c = W.Description(5, "• Weekly chore tracking (Zone Events, Quests, etc)."),
            d = W.Description(5,
                "• Mythic+ season progress: track progress to milestones, show rewards, current rating, etc."),
            e = W.Description(5, "• Dungeon teleports added to the Portals datatext."),
            f = W.Description(5,
                "• More ABUNDANCE! Shards of DunDun tracking, Abundant Harvest location tracking added to Gold Goblin datatext."),
            g = W.Description(5, "• Easy Fishing: Cast and Reel with a single keybind; mute other sounds while fishing."),
            h = W.Description(5, "• Calculator: Perform basic math operations with slash commands."),
            i = W.Description(5,
                "• Gearing Handbook: Configure recommended enchants, gems, etc. as an in-game reference instead of referring to your favorite web-based guide."),
        }),
    }

    return optionsTab
end

-- register the configuration menu with the configuration module for display when shown.
ConfigurationModule:RegisterConfigurationFunction("About", BuildAboutConfiguration)
