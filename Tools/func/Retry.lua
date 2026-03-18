local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)

---@class RetryModule : AceModule,AceTimer-3.0
local RetryModule = T:NewModule("Retry", "AceTimer-3.0")
RetryModule:SetEnabledState(true)

T.Tools.Functions.Retry = RetryModule

-- func      : function to call
-- condition : function(result) -> true when we should stop retrying
-- interval  : seconds between attempts
-- maxTries  : hard cap so it cannot loop forever
-- onDone    : callback(success, result) when finished
function RetryModule:Retry(func, condition, interval, maxTries, onDone)
    interval       = interval or 0.1
    maxTries       = maxTries or 50

    local attempts = 0
    local timerHandle

    local function tick()
        attempts = attempts + 1
        local result = func()

        if condition(result) or attempts >= maxTries then
            if timerHandle then
                self:CancelTimer(timerHandle)
            end
            if onDone then
                local success = condition(result)
                onDone(success, result)
            end
        end
    end

    timerHandle = self:ScheduleRepeatingTimer(tick, interval)
    return timerHandle
end

function RetryModule:OnDisable()
    -- cancel all timers on disable for safety
    self:CancelAllTimers()
end
