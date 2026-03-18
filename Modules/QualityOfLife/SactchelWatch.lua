local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)


---@type QualityOfLife
local QOL = T:GetModule("QualityOfLife")

---@class SatchelWatchModule : AceModule
local SW = QOL:NewModule("SatchelWatch")

function SW:OnEnable()
end

function SW:OnDisable()
end
