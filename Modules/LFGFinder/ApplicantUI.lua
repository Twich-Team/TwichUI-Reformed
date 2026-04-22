--[[
    LFG Finder Applicant UI - Applicant mode frame for reviewing applications
]]
local TwichRx = _G.TwichRx
---@type TwichUI
local T = unpack(TwichRx)
local LFG = T:GetModule("LFGFinder")

local CreateFrame = _G.CreateFrame
local format = _G.format
local ipairs = _G.ipairs

function LFG:RefreshApplicantUIImpl()
    -- Similar to RefreshBrowserUIImpl but for applicants
    if not self.mainFrame then return end
    
    local filteredResults = {}
    for _, result in ipairs(self.searchResults) do
        table.insert(filteredResults, result)
    end
    
    -- Render rows with applicant data
    for i, row in ipairs(self.rowPool) do
        if filteredResults[i] then
            local result = filteredResults[i]
            row.result = result
            
            -- Populate columns with applicant info
            -- These would be applicant class, name, role, ilevel, rating, dungeon experience
            row.dungeon:SetText(result.class or "Unknown")
            row.leader:SetText(result.name or "Unknown")
            row.composition:SetText(result.role or "")
            row.rating:SetText(format("%d", result.rating or 0))
            row.age:SetText(self:FormatAge(result.applicationTime or 0))
            
            row.applyBtn:SetText("Invite")
            row.applyBtn:Enable()
            row.applyBtn:SetScript("OnClick", function()
                LFG:InviteApplicant(result)
            end)
            
            row.frame:Show()
        else
            row.frame:Hide()
        end
    end
    
    if self.footerText then
        self.footerText:SetFormattedText("Applicants: %d", #filteredResults)
    end
end

function LFG:InviteApplicant(result)
    if not result or not result.id then return end
    C_LFGList.UpdateApplicantStatus(result.id, true) -- true = invite
end

function LFG:DeclineApplicant(result)
    if not result or not result.id then return end
    C_LFGList.UpdateApplicantStatus(result.id, false) -- false = decline
end
