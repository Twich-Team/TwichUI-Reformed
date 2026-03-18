--[[
        Gossip hotkeys module.

        Responsibilities:
        - Apply hotkeys to NPC gossip for fast and easy interactions.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class GossipHotkeys : AceModule, AceEvent-3.0
---@field hotkeyFrame Frame the frame used to capture hotkey input
---@field activeButtons Button[]|nil list of clickable gossip buttons ordered as shown
---@field overrideButtons Button[]|nil internal buttons used for override bindings
local GH = QOL:NewModule("GossipHotkeys", "AceEvent-3.0")
GH:SetEnabledState(false)

--- Flag indicating we attempted to clear bindings during combat and
--- should retry once combat ends.
---@type boolean
GH.pendingClear = false

local CreateFrame = CreateFrame
local SelectOption = C_GossipInfo.SelectOption -- kept for potential future use
local GetOptions = C_GossipInfo.GetOptions     -- kept for potential future use

--- Returns true if the key is a number row key (1-9).
---@param key string
---@return boolean
---@param key string
---@return boolean
local function IsNumericKey(key)
	return key == "1" or key == "2" or key == "3"
		or key == "4" or key == "5" or key == "6"
		or key == "7" or key == "8" or key == "9"
end

--- Converts a numeric key string into a 1-based index.
---@param key string
---@return integer|nil
local function KeyToIndex(key)
	return tonumber(key)
end

--- Prepend the assigned hotkey (1-9) to each gossip option's
--- button text in the default GossipFrame, so players can see which
--- key will activate which option.
---@return nil
function GH:ApplyHotkeyLabels()
	if not self.activeButtons or #self.activeButtons == 0 then
		return
	end

	local maxHotkey = 9

	local function applyToButton(button, buttonIndex)
		if not button or not button:IsShown() then
			return
		end

		-- Different gossip button templates expose text in different ways.
		local text
		if button.GetText then
			text = button:GetText()
		elseif button.GreetingText and button.GreetingText.GetText then
			text = button.GreetingText:GetText()
		elseif button.GetFontString and button:GetFontString() then
			text = button:GetFontString():GetText()
		end

		if not text or text == "" then
			return
		end

		local optionIndex = buttonIndex

		if not optionIndex then
			return
		end

		-- Strip any existing numeric prefix like "[1] " before re-applying.
		text = text:gsub("^%[%d%]%s*", "")

		local newText
		if optionIndex <= maxHotkey then
			newText = ("[%d] %s"):format(optionIndex, text)
		else
			newText = text
		end

		if button.SetText then
			button:SetText(newText)
		elseif button.GreetingText and button.GreetingText.SetText then
			button.GreetingText:SetText(newText)
		elseif button.GetFontString and button:GetFontString() and button:GetFontString().SetText then
			button:GetFontString():SetText(newText)
		end
	end

	for index, button in ipairs(self.activeButtons) do
		applyToButton(button, index)
	end
end

function GH:OnEnable()
	self:RegisterEvent("GOSSIP_SHOW")
	self:RegisterEvent("GOSSIP_CLOSED")
	self:RegisterEvent("PLAYER_INTERACTION_MANAGER_FRAME_HIDE")

	if not self.hotkeyFrame then
		self.hotkeyFrame = CreateFrame("Frame", "TwichUI_GossipHotkeysFrame", UIParent)
		self.hotkeyFrame:EnableKeyboard(false)
		self.hotkeyFrame:SetPropagateKeyboardInput(true)
	end

	-- Create hidden buttons once, used for temporary override bindings
	-- for keys 1-9 while gossip is open.
	if not self.overrideButtons then
		self.overrideButtons = {}
		for i = 1, 9 do
			local name = ("TwichUI_GossipHotkey_%d"):format(i)
			local btn = CreateFrame("Button", name, UIParent, "SecureActionButtonTemplate")
			btn:SetScript("OnClick", function()
				GH:OnHotkeyPressed(i)
			end)
			self.overrideButtons[i] = btn
		end
	end
end

function GH:OnDisable()
	self:UnregisterHotkeys()
end

--- Handles a numeric hotkey press by clicking the corresponding
--- active gossip button, if any.
---@param index integer
function GH:OnHotkeyPressed(index)
	if not self.activeButtons or index < 1 or index > #self.activeButtons then
		return
	end

	local button = self.activeButtons[index]
	if button and button:IsShown() and button:IsMouseClickEnabled() then
		button:Click()
	end
end

function GH:GOSSIP_SHOW()
	self.activeButtons = {}

	-- Collect clickable gossip buttons in visual order.
	if GossipFrame then
		-- Newer ScrollBox-based greeting panel.
		if GossipFrame.GreetingPanel and GossipFrame.GreetingPanel.ScrollBox and GossipFrame.GreetingPanel.ScrollBox.ForEachFrame then
			GossipFrame.GreetingPanel.ScrollBox:ForEachFrame(function(button)
				if button and button:IsShown() and button:IsMouseClickEnabled() and button:GetScript("OnClick") then
					table.insert(self.activeButtons, button)
				end
			end)
			-- Older style buttons table (fallback).
		elseif GossipFrame.buttons then
			for _, button in ipairs(GossipFrame.buttons) do
				if button and button:IsShown() and button:IsMouseClickEnabled() and button:GetScript("OnClick") then
					table.insert(self.activeButtons, button)
				end
			end
		end
	end

	if self.activeButtons and #self.activeButtons > 0 then
		self:ApplyHotkeyLabels()

		-- Override numeric keys 1-9 while gossip is open so they trigger
		-- gossip options instead of their normal bindings (e.g., Blink).
		if self.overrideButtons and self.hotkeyFrame and ClearOverrideBindings and SetOverrideBindingClick then
			-- Do not attempt to change override bindings while in combat; this is
			-- a protected action and will cause a blocked action / chat error.
			if InCombatLockdown and InCombatLockdown() then
				return
			end

			ClearOverrideBindings(self.hotkeyFrame)
			local maxIndex = math.min(9, #self.activeButtons)
			for i = 1, maxIndex do
				local overrideBtn = self.overrideButtons[i]
				if overrideBtn then
					SetOverrideBindingClick(self.hotkeyFrame, true, tostring(i), overrideBtn:GetName(), "LeftButton")
				end
			end
		end
	else
		-- No active options; ensure any temporary overrides are cleared.
		if self.hotkeyFrame and ClearOverrideBindings then
			ClearOverrideBindings(self.hotkeyFrame)
		end
	end
end

function GH:GOSSIP_CLOSED()
	self:UnregisterHotkeys()
end

function GH:PLAYER_INTERACTION_MANAGER_FRAME_HIDE()
	self:UnregisterHotkeys()
end

function GH:UnregisterHotkeys()
	self.activeButtons = nil
	if self.hotkeyFrame then
		self.hotkeyFrame:EnableKeyboard(false)
		self.hotkeyFrame:SetPropagateKeyboardInput(true)
		if ClearOverrideBindings then
			-- ClearOverrideBindings is protected in combat. If we are in
			-- combat lockdown, defer the clear until combat ends so we
			-- avoid blocked-action / chat-locked errors and still restore
			-- the player's normal keybinds as soon as possible.
			if InCombatLockdown and InCombatLockdown() then
				GH.pendingClear = true
				if GH.RegisterEvent then
					GH:RegisterEvent("PLAYER_REGEN_ENABLED")
				end
			else
				ClearOverrideBindings(self.hotkeyFrame)
				GH.pendingClear = false
				if GH.UnregisterEvent then
					GH:UnregisterEvent("PLAYER_REGEN_ENABLED")
				end
			end
		end
	end
end

--- Fired when the player leaves combat. Used to safely clear any
--- gossip override bindings that we could not clear while in combat.
function GH:PLAYER_REGEN_ENABLED()
	if self.pendingClear and self.hotkeyFrame and ClearOverrideBindings then
		if not InCombatLockdown or not InCombatLockdown() then
			ClearOverrideBindings(self.hotkeyFrame)
		end
	end
	self.pendingClear = false
	if self.UnregisterEvent then
		self:UnregisterEvent("PLAYER_REGEN_ENABLED")
	end
end
