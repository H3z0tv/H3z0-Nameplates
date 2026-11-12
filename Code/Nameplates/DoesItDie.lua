local _, ns = ...
local api = UsefulPlatesAndTooltips_DoTAPI
if not api or (api.API_VERSION or 0) < 1 then return end

local texture = "Interface\\Buttons\\WHITE8X8"

local function CreateIndicators(healthBar)
    local marker = CreateFrame("StatusBar", nil, healthBar)
    marker:SetAllPoints(healthBar)
    marker:SetFrameLevel(healthBar:GetFrameLevel() + 1)
    marker:SetStatusBarTexture(texture)
    marker:SetStatusBarColor(1, .74, .19, .45)

    local window = CreateFrame("Frame", nil, healthBar)
    window:SetSize(16, 16)
    window:SetPoint("LEFT", healthBar, "RIGHT", 3, 0)
    window:SetClipsChildren(true)
    local bar = CreateFrame("StatusBar", nil, window)
    bar:SetSize(10000, 16)
    bar:SetPoint("RIGHT", window)
    bar:SetStatusBarTexture(texture)
    bar:GetStatusBarTexture():SetAlpha(0)
    local skull = bar:CreateTexture(nil, "OVERLAY")
    skull:SetSize(16, 16)
    skull:SetPoint("RIGHT", bar:GetStatusBarTexture(), "RIGHT")
    skull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
    return {marker = marker, window = window, bar = bar}
end

function ns.UpdateDoesItDie(record, health, maxHealth)
    local indicators = record.doesItDie
    local damage = api.GetRemainingDamage(record.unit)
    if type(damage) ~= "number" or damage <= 0 then
        if indicators then
            indicators.marker:Hide()
            indicators.window:Hide()
        end
        return
    end
    if not indicators then
        indicators = CreateIndicators(record.health)
        record.doesItDie = indicators
    end
    indicators.marker:SetMinMaxValues(0, maxHealth)
    indicators.marker:SetValue(damage)
    indicators.bar:SetMinMaxValues(0, health)
    indicators.bar:SetValue(damage)
    indicators.marker:Show()
    indicators.window:Show()
end

function ns.RegisterDoesItDieCallback(refresh)
    api.RegisterCallback("H3z0Nameplates", function(event, unit)
        if event == "DOTS_CHANGED" then refresh(unit) end
    end)
end
