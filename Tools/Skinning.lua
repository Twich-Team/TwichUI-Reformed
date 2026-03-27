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

    -- Per-button animation state (closed over per SkinTwichButton call).
    local HOVER_SPEED   = 8     -- 0→1 in ~125ms
    local hoverProgress = 0.0
    local isPressed     = false

    local function lerp(a, b, t) return a + (b - a) * t end

    local function applyVisual(selfBtn)
        local enabled = selfBtn.IsEnabled == nil or selfBtn:IsEnabled()
        local h  = hoverProgress
        local fs = selfBtn.GetFontString and selfBtn:GetFontString() or nil

        if not enabled then
            chrome:SetBackdropColor(r * 0.14, g * 0.14, b * 0.14, 0.70)
            chrome:SetBackdropBorderColor(r, g, b, 0.08)
            chrome.LeftAccent:SetColorTexture(r, g, b, 0.28)
            chrome.InnerGlow:SetColorTexture(r, g, b, 0.02)
            if fs then
                if fs.SetDrawLayer then fs:SetDrawLayer("OVERLAY", 7) end
                fs:SetTextColor(0.58, 0.6, 0.66)
            end
            return
        end

        if isPressed then
            chrome:SetBackdropColor(r * 0.3, g * 0.3, b * 0.3, 1.0)
            chrome:SetBackdropBorderColor(r, g, b, 0.50)
            chrome.LeftAccent:SetColorTexture(r, g, b, 1.0)
            chrome.InnerGlow:SetColorTexture(r, g, b, 0.10)
        else
            chrome:SetBackdropColor(
                r * lerp(0.16, 0.22, h),
                g * lerp(0.16, 0.22, h),
                b * lerp(0.16, 0.22, h),
                lerp(0.95, 1.0, h))
            chrome:SetBackdropBorderColor(r, g, b, lerp(0.16, 0.36, h))
            chrome.LeftAccent:SetColorTexture(r, g, b, lerp(0.92, 1.0, h))
            chrome.InnerGlow:SetColorTexture(r, g, b, lerp(0.04, 0.10, h))
        end

        if fs then
            if fs.SetDrawLayer then fs:SetDrawLayer("OVERLAY", 7) end
            fs:SetTextColor(1, 0.95, 0.84)
        end
    end

    -- Drive hoverProgress toward `target` each frame, stop when reached.
    local function animateTo(selfBtn, target)
        selfBtn:SetScript("OnUpdate", function(self, elapsed)
            local step = HOVER_SPEED * elapsed
            if hoverProgress < target then
                hoverProgress = math.min(hoverProgress + step, target)
            else
                hoverProgress = math.max(hoverProgress - step, target)
            end
            applyVisual(self)
            if hoverProgress == target then
                self:SetScript("OnUpdate", nil)
            end
        end)
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
            isPressed = false
            animateTo(self, 1.0)
        end)
        btn:HookScript("OnLeave", function(self)
            isPressed = false
            animateTo(self, 0.0)
        end)
        btn:HookScript("OnMouseDown", function(self)
            isPressed = true
            self:SetScript("OnUpdate", nil)
            applyVisual(self)
        end)
        btn:HookScript("OnMouseUp", function(self)
            isPressed = false
            local over = self.IsMouseOver and self:IsMouseOver() or false
            animateTo(self, over and 1.0 or 0.0)
        end)
        btn:HookScript("OnEnable", function(self)
            isPressed = false
            hoverProgress = 0.0
            self:SetScript("OnUpdate", nil)
            applyVisual(self)
        end)
        btn:HookScript("OnDisable", function(self)
            isPressed = false
            hoverProgress = 0.0
            self:SetScript("OnUpdate", nil)
            applyVisual(self)
        end)
        btn.__twichuiButtonSkinned = true
    end

    isPressed = false
    hoverProgress = 0.0
    applyVisual(btn)
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
