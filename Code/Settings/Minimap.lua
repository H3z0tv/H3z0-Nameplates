local addonName, ns = ...

local function PlaceButton(button, angle)
    local radians = math.rad(angle)
    local radius = Minimap:GetWidth() * .5 + 7
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER",
        math.cos(radians) * radius, math.sin(radians) * radius)
end

local function DragToCursor(button)
    local x, y = Minimap:GetCenter()
    local scale = Minimap:GetEffectiveScale()
    if not x or not y or not scale or scale <= 0 then return end
    local atan = math.atan2 or atan2
    if not atan then return end
    local cursorX, cursorY = GetCursorPosition()
    local angle = math.deg(atan(cursorY / scale - y, cursorX / scale - x)) % 360
    H3z0NameplatesDB.minimapAngle = angle
    PlaceButton(button, angle)
end

local function CreateMinimapButton()
    local button = CreateFrame("Button", "H3z0NameplatesMinimapButton", Minimap)
    button:SetSize(31, 31)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel(Minimap:GetFrameLevel() + 8)
    button:EnableMouse(true)
    button:RegisterForClicks("LeftButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

    local background = button:CreateTexture(nil, "BACKGROUND")
    background:SetSize(24, 24)
    background:SetPoint("CENTER")
    background:SetTexture("Interface\\Minimap\\UI-Minimap-Background")

    local label = button:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    label:SetFont(STANDARD_TEXT_FONT, 9, "OUTLINE")
    label:SetPoint("CENTER")
    label:SetTextColor(1, .76, .30)
    label:SetText("HNP")

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(50, 50)
    border:SetPoint("TOPLEFT", button, "TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    button:SetScript("OnEnter", function(self)
        if not GameTooltip then return end
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("H3z0 Nameplates", 1, .62, .16)
        GameTooltip:AddLine("Left-click: Settings", 1, 1, 1)
        GameTooltip:AddLine("Left-drag: Move", 1, 1, 1)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function()
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnClick", function()
        ns.OpenMainMenu()
    end)
    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", DragToCursor)
        if GameTooltip then GameTooltip:Hide() end
    end)
    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
        DragToCursor(self)
    end)

    PlaceButton(button, tonumber(H3z0NameplatesDB.minimapAngle) or 255)
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    if Minimap then CreateMinimapButton() end
end)
