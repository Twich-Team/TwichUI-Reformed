--[[
    Premade widgets for use throughout the configuration.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@type ConfigurationModule
local ConfigurationModule = T:GetModule("Configuration")

---@class ConfigurationWidgets
local Widgets = ConfigurationModule.Widgets or {}
ConfigurationModule.Widgets = Widgets

--- Creates a header widget with the primary color.
--- @param order number The order of the widget.
--- @param text string The text to display in the header.
function Widgets.TitleWidget(order, text)
    return {
        type = 'description',
        fontSize = 'large',
        order = order,
        name = Tools.Text.Color(Tools.Colors.PRIMARY, text or ""),
    }
end

--- @alias ConfigurationSection { type: string, name: string, order: number, childGroups: string, args: table }

--- @return ConfigurationSection section
function Widgets.NewConfigurationSection(order, name)
    return {
        type = "group",
        name = name or "Section",
        order = order,
        childGroups = "tab",
        args = {},
    }
end

function Widgets.Description(order, text)
    return {
        type = "description",
        order = order,
        name = text or "",
    }
end

function Widgets.IGroup(order, name, args)
    return {
        type = "group",
        name = name or "Group",
        order = order,
        inline = true,
        args = args or {},
    }
end

function Widgets.Spacer(order)
    return {
        type = "description",
        name = " ",
        order = order,
    }
end
