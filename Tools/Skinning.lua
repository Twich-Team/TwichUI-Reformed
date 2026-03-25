---@diagnostic disable: undefined-field, undefined-global, inject-field
local T = unpack(TwichRx)

---@type Tools
local Tools = T.Tools

---@class UISkins
---@field GetElvUISkins fun():any|nil
---@field SkinCloseButton fun(btn:Button|nil)
---@field SkinScrollBar fun(scrollFrameOrSlider:any)
---@field SkinEditBox fun(editBox:EditBox|nil)
---@field SkinButton fun(btn:Button|nil)
---@field SkinTwichButton fun(btn:Button|nil, color:number[]|nil)
local UI = Tools.UI or {}
Tools.UI = UI

local _G = _G
local CreateFrame = _G.CreateFrame
local unpackValues = table.unpack or unpack

---@param texture any
local function HideTexture(texture)
    if not texture then
        return
    end

    if texture.SetAlpha then
        texture:SetAlpha(0)
    end

    if texture.Hide then
        texture:Hide()
    end
end

---@return any|nil skins
function UI.GetElvUISkins()
    local E = _G.ElvUI and _G.ElvUI[1]
    if not E or not E.GetModule then
        return nil
    end

    local ok, skins = pcall(E.GetModule, E, "Skins", true)
    if ok then
        return skins
    end
    return nil
end

---@param scrollFrameOrSlider any
---@return any|nil
local function ResolveScrollBar(scrollFrameOrSlider)
    if not scrollFrameOrSlider then
        return nil
    end

    -- Direct slider
    if type(scrollFrameOrSlider.GetObjectType) == "function" then
        local ok, objType = pcall(scrollFrameOrSlider.GetObjectType, scrollFrameOrSlider)
        if ok and objType == "Slider" then
            return scrollFrameOrSlider
        end
    end

    -- Standard ScrollFrame templates
    local sb = scrollFrameOrSlider.ScrollBar
    if sb then
        return sb
    end

    -- Fallback: named template scrollbar ("<ScrollFrameName>ScrollBar")
    if type(scrollFrameOrSlider.GetName) == "function" then
        local name = scrollFrameOrSlider:GetName()
        if name then
            return _G[name .. "ScrollBar"]
        end
    end

    return nil
end

---@param btn Button|nil
function UI.SkinCloseButton(btn)
    local skins = UI.GetElvUISkins()
    if skins and skins.HandleCloseButton and btn then
        pcall(skins.HandleCloseButton, skins, btn)
    end
end

---@param scrollFrameOrSlider any
function UI.SkinScrollBar(scrollFrameOrSlider)
    local skins = UI.GetElvUISkins()
    if not skins or not skins.HandleScrollBar then
        return
    end

    local sb = ResolveScrollBar(scrollFrameOrSlider)
    if sb then
        pcall(skins.HandleScrollBar, skins, sb)
    end
end

---@param editBox EditBox|nil
function UI.SkinEditBox(editBox)
    local skins = UI.GetElvUISkins()
    if skins and skins.HandleEditBox and editBox then
        pcall(skins.HandleEditBox, skins, editBox)
    end
end

---@param btn Button|nil
function UI.SkinButton(btn)
    local skins = UI.GetElvUISkins()
    if skins and skins.HandleButton and btn then
        pcall(skins.HandleButton, skins, btn)
    end
end

---@param btn Button|nil
---@param color number[]|nil
function UI.SkinTwichButton(btn, color)
    if not btn then
        return
    end

    local r, g, b = unpackValues(color or { 0.98, 0.76, 0.24 })
    ---@type any
    local chrome = btn

    if not chrome.SetBackdrop then
        if not btn.__twichuiChrome then
            btn.__twichuiChrome = CreateFrame("Frame", nil, btn, "BackdropTemplate")
            btn.__twichuiChrome:SetAllPoints(btn)
            btn.__twichuiChrome:EnableMouse(false)
        end

        if btn.GetFrameLevel and btn.__twichuiChrome.SetFrameLevel then
            btn.__twichuiChrome:SetFrameLevel(math.max(0, btn:GetFrameLevel() - 1))
        end

        chrome = btn.__twichuiChrome
    end

    chrome:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Buttons\\WHITE8X8",
        edgeSize = 1,
        insets = { left = 1, right = 1, top = 1, bottom = 1 },
    })

    if not chrome.LeftAccent then
        chrome.LeftAccent = chrome:CreateTexture(nil, "BORDER")
        chrome.LeftAccent:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
        chrome.LeftAccent:SetPoint("BOTTOMLEFT", chrome, "BOTTOMLEFT", 1, 1)
        chrome.LeftAccent:SetWidth(3)
    end

    if not chrome.InnerGlow then
        chrome.InnerGlow = chrome:CreateTexture(nil, "ARTWORK")
        chrome.InnerGlow:SetPoint("TOPLEFT", chrome, "TOPLEFT", 1, -1)
        chrome.InnerGlow:SetPoint("BOTTOMRIGHT", chrome, "BOTTOMRIGHT", -1, 1)
    end

    local function updateVisual(self, hovered, pressed)
        local enabled = self.IsEnabled == nil or self:IsEnabled()
        local baseAlpha = enabled and 0.98 or 0.72
        local borderAlpha = enabled and 0.16 or 0.08
        local accentAlpha = enabled and 0.92 or 0.3

        if hovered then
            borderAlpha = enabled and 0.36 or borderAlpha
            accentAlpha = enabled and 1 or accentAlpha
        end

        if pressed then
            baseAlpha = enabled and 1 or baseAlpha
            borderAlpha = enabled and 0.5 or borderAlpha
        end

        chrome:SetBackdropColor(r * (pressed and 0.3 or hovered and 0.22 or 0.16),
            g * (pressed and 0.3 or hovered and 0.22 or 0.16),
            b * (pressed and 0.3 or hovered and 0.22 or 0.16),
            baseAlpha)
        chrome:SetBackdropBorderColor(r, g, b, borderAlpha)
        chrome.LeftAccent:SetColorTexture(r, g, b, accentAlpha)
        chrome.InnerGlow:SetColorTexture(r, g, b, hovered and 0.08 or 0.04)

        local fontString = self.GetFontString and self:GetFontString() or nil
        if fontString then
            if fontString.SetDrawLayer then
                fontString:SetDrawLayer("OVERLAY", 7)
            end
            if enabled then
                fontString:SetTextColor(1, 0.95, 0.84)
            else
                fontString:SetTextColor(0.58, 0.6, 0.66)
            end
        end
    end

    local regions = { btn:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType and region:GetObjectType() == "Texture" then
            HideTexture(region)
        end
    end

    HideTexture(btn.GetNormalTexture and btn:GetNormalTexture() or nil)
    HideTexture(btn.GetPushedTexture and btn:GetPushedTexture() or nil)
    HideTexture(btn.GetHighlightTexture and btn:GetHighlightTexture() or nil)
    HideTexture(btn.GetDisabledTexture and btn:GetDisabledTexture() or nil)

    if not btn.__twichuiButtonSkinned then
        btn:HookScript("OnEnter", function(self)
            updateVisual(self, true, false)
        end)
        btn:HookScript("OnLeave", function(self)
            updateVisual(self, false, false)
        end)
        btn:HookScript("OnMouseDown", function(self)
            updateVisual(self, self.IsMouseOver and self:IsMouseOver() or false, true)
        end)
        btn:HookScript("OnMouseUp", function(self)
            updateVisual(self, self.IsMouseOver and self:IsMouseOver() or false, false)
        end)
        btn:HookScript("OnEnable", function(self)
            updateVisual(self, self.IsMouseOver and self:IsMouseOver() or false, false)
        end)
        btn:HookScript("OnDisable", function(self)
            updateVisual(self, false, false)
        end)
        btn.__twichuiButtonSkinned = true
    end

    updateVisual(btn, btn.IsMouseOver and btn:IsMouseOver() or false, false)
end

---@param frame Frame|nil
---@param width number|nil
function UI.SkinDropDown(frame, width)
    local skins = UI.GetElvUISkins()
    if skins and skins.HandleDropDownBox and frame then
        pcall(skins.HandleDropDownBox, skins, frame, width)
    end
end

---@param frame Frame
function UI.GetBorderColor(frame)
    ---@diagnostic disable-next-line: undefined-field
    local E = _G.ElvUI and _G.ElvUI[1]
    if E and E.media and E.media.bordercolor then
        local r, g, b = unpack(E.media.bordercolor)
        return r or 1, g or 1, b or 1, 1
    end
    return 1, 1, 1, 1
end

return UI
