
local AceGUI = LibStub("AceGUI-3.0")
local Type, Version = "GatherNotificationWidget", 1
local function Constructor()
	local frame = AceGUI:Create("SimpleGroup")
	local icon = AceGUI:Create("Icon")
	local label = AceGUI:Create("Label")
	frame:AddChild(icon)
	frame:AddChild(label)
	frame.type = Type
	-- Provide a safe SetItemData method via callback
	frame:SetCallback("OnSetItemData", function(widget, event, itemLink, count, value)
		local texture = select(5, C_Item.GetItemInfoInstant(itemLink))
		if icon.SetImage then icon:SetImage(texture) end
		if label.SetText then label:SetText(string.format("%s x%d (%s)", itemLink, count, value)) end
	end)
	return frame
end
AceGUI:RegisterWidgetType(Type, Constructor, Version)
