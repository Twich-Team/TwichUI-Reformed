--[[
    Module that adds various enhancements to the chat interface.
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class ChatEnhancementModule : AceModule
local ChatEnhancementModule = T:NewModule("ChatEnhancements")
ChatEnhancementModule:SetEnabledState(true)
-- turn off submodules by default
ChatEnhancementModule:SetDefaultModuleState(false)
