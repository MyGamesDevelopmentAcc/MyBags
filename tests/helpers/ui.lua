-- Small frame simulator for shared container presentation tests.
local UI = { frames = {} }
local Frame = {}
Frame.__index = Frame

function UI.CreateFrame(_, name, parent, template)
    local frame = setmetatable({
        name = name, parent = parent, template = template,
        shown = true, scripts = {}, hooks = {}, points = {}, level = 5,
        width = 100, height = 100, scale = 1, text = "",
    }, Frame)
    table.insert(UI.frames, frame)
    if template == "UIPanelIconDropdownButtonTemplate" then
        frame.Icon = UI.CreateFrame(nil, nil, frame)
    elseif template == "ChatConfigCheckButtonTemplate" then
        frame.Text = UI.CreateFrame(nil, nil, frame)
    elseif template == "SearchBoxTemplate" then
        frame.Instructions = UI.CreateFrame(nil, nil, frame)
    elseif template == "InputScrollFrameTemplate" then
        frame.EditBox = UI.CreateFrame(nil, nil, frame)
    end
    return frame
end

function Frame:GetParent() return self.parent end
function Frame:GetFrameLevel() return self.level end
function Frame:SetFrameLevel(level) self.level = level end
function Frame:SetScript(event, handler) self.scripts[event] = handler end
function Frame:GetScript(event) return self.scripts[event] end
function Frame:HookScript(event, handler)
    self.hooks[event] = self.hooks[event] or {}
    table.insert(self.hooks[event], handler)
end
function Frame:Fire(event, ...)
    if self.scripts[event] then self.scripts[event](self, ...) end
    for _, handler in ipairs(self.hooks[event] or {}) do handler(self, ...) end
end
function Frame:IsShown() return self.shown end
function Frame:Show()
    local wasShown = self.shown
    self.shown = true
    if not wasShown then self:Fire("OnShow") end
end
function Frame:Hide()
    local wasShown = self.shown
    self.shown = false
    if wasShown then self:Fire("OnHide") end
end
function Frame:SetShown(shown) if shown then self:Show() else self:Hide() end end
function Frame:SetSize(width, height) self.width, self.height = width, height end
function Frame:SetWidth(width) self.width = width end
function Frame:SetHeight(height) self.height = height end
function Frame:GetWidth() return self.width end
function Frame:GetHeight() return self.height end
function Frame:SetScale(scale) self.scale = scale end
function Frame:GetEffectiveScale() return self.scale end
function Frame:GetLeft() return self.left or 0 end
function Frame:GetRight() return self:GetLeft() + self.width end
function Frame:GetBottom() return self.bottom or 0 end
function Frame:GetTop() return self:GetBottom() + self.height end
function Frame:SetPoint(...) table.insert(self.points, { ... }) end
function Frame:ClearAllPoints() self.points = {} end
function Frame:SetText(text) self.text = text; self:Fire("OnTextChanged", false) end
function Frame:GetText() return self.text end
function Frame:SetChecked(checked) self.checked = checked end
function Frame:GetChecked() return self.checked end
function Frame:SetTexture(texture) self.texture = texture end
function Frame:SetAtlas(atlas) self.atlas = atlas end
function Frame:SetVertexColor(...) self.color = { ... } end
function Frame:SetBackdropColor(...) self.backdropColor = { ... } end
function Frame:SetBackdropBorderColor(...) self.borderColor = { ... } end
function Frame:SetBackdrop(backdrop) self.backdrop = backdrop end
function Frame:SetFontObject(font) self.font = font end
function Frame:EnableMouse(enabled) self.mouseEnabled = enabled end
function Frame:RegisterForDrag(...) self.dragButtons = { ... } end
function Frame:CreateTexture() return UI.CreateFrame(nil, nil, self) end
function Frame:CreateFontString() return UI.CreateFrame(nil, nil, self) end
function Frame:SetAllPoints() end
function Frame:SetWordWrap() end
function Frame:SetJustifyH() end
function Frame:SetJustifyV() end
function Frame:SetAlpha(alpha) self.alpha = alpha end
function Frame:SetBlendMode() end
function Frame:SetHitRectInsets() end
function Frame:SetMaxLetters(maxLetters) self.maxLetters = maxLetters end
function Frame:SetFrameStrata() end
function Frame:SetShadowColor() end
function Frame:SetShadowOffset() end
function Frame:SetTextColor(...) self.textColor = { ... } end
function Frame:SetMovable() end
function Frame:SetClampedToScreen() end
function Frame:SetAutoFocus() end
function Frame:SetNumeric() end
function Frame:SetScrollChild(child) self.scrollChild = child end
function Frame:Enable() self.enabled = true end
function Frame:Disable() self.enabled = false end
function Frame:ClearFocus() self:Fire("OnEditFocusLost") end

return UI
