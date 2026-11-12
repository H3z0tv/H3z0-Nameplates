local _, ns = ...

-- Forever Combo Points belong to the selected target. H3z0 draws them
-- with StatusBars and does not inspect protected values in combat.
local MASK = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraMask.tga"
local BORDER = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorder.tga"
local BORDER_RED = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorderRed.tga"
local SHADOW = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraShadow.tga"
local FLAT = ns.FLAT_TEXTURE or "Interface\\Buttons\\WHITE8X8"
local POINT_SIZE = 18
local POINT_GAP = 4
local CAT_CLAW_TEXTURE = "Interface\\AddOns\\H3z0Nameplates\\Media\\FeralClawSlash.tga"
local ROGUE_DAGGER_TEXTURE = "Interface\\AddOns\\H3z0Nameplates\\Media\\RogueDaggerSlash.tga"
local MAX_VISUAL_POINTS = 10
local POWER_TYPE = (Enum and Enum.PowerType and Enum.PowerType.ComboPoints) or 4

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function IsComboClass()
    if not UnitClass then return false end
    local okClass, _, class = pcall(UnitClass, "player")
    if not okClass or Secret(class) then return false end
    if class == "ROGUE" then return true, false end
    if class ~= "DRUID" then return false end
    -- Druid visibility depends on the *active form*, never specialization:
    -- Cat Form on any spec is eligible; Bear, Moonkin, Travel and humanoid
    -- must not show the resource. GetShapeshiftFormID is stable across specs
    -- (unlike GetShapeshiftForm's form-bar index).
    if not GetShapeshiftFormID then return false end
    local okForm, formID = pcall(GetShapeshiftFormID)
    if not okForm or Secret(formID) then return false end
    local cat = formID == (CAT_FORM or 1)
    return cat, cat
end

local function MakePoint(group, index)
    local cell = CreateFrame("Frame", nil, group)
    cell:SetSize(POINT_SIZE, POINT_SIZE)
    cell:EnableMouse(false)

    local shadow = cell:CreateTexture(nil, "BACKGROUND", nil, -7)
    shadow:SetPoint("TOPLEFT", cell, "TOPLEFT", -4, 4)
    shadow:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", 4, -4)
    shadow:SetTexture(SHADOW)
    shadow:SetAlpha(0.82)

    local inactive = cell:CreateTexture(nil, "ARTWORK", nil, 0)
    inactive:SetAllPoints(cell)
    inactive:SetTexture(MASK)
    inactive:SetVertexColor(0.12, 0.10, 0.08, 0.85)

    -- Each point has its own numeric range: [0,1], [1,2], ... . Blizzard
    -- clamps the secret total to that range internally and fills the circle
    -- only when that point is earned. No secret-dependent branching in Lua.
    local active = CreateFrame("StatusBar", nil, cell)
    active:SetAllPoints(cell)
    active:SetStatusBarTexture(FLAT)
    active:SetMinMaxValues(index - 1, index)
    active:SetValue(0)
    active:SetStatusBarColor(1, 0.74, 0.21, 1)
    active:SetFrameLevel(cell:GetFrameLevel() + 1)

    -- The red fill activates at the configured maximum. Secret counts go
    -- straight to SetValue without comparisons in addon code.
    local fullRed = CreateFrame("StatusBar", nil, cell)
    fullRed:SetAllPoints(cell)
    fullRed:SetStatusBarTexture(FLAT)
    fullRed:SetMinMaxValues(4, 5)
    fullRed:SetValue(0)
    fullRed:SetStatusBarColor(0.96, 0.22, 0.29, 1)
    fullRed:SetFrameLevel(active:GetFrameLevel() + 1)

    -- Both normal and full-red fills reuse the same circular mask, including
    -- after a user changes their shared-media statusbar texture.
    local mask = cell:CreateMaskTexture(nil, "ARTWORK")
    mask:SetAllPoints(cell)
    mask:SetTexture(MASK)
    cell.comboMask = mask
    cell.normalBar = active
    cell.redBar = fullRed

    local rimLayer = CreateFrame("Frame", nil, cell)
    rimLayer:SetAllPoints(cell)
    rimLayer:SetFrameLevel(fullRed:GetFrameLevel() + 1)
    rimLayer:EnableMouse(false)
    local rim = rimLayer:CreateTexture(nil, "OVERLAY")
    rim:SetAllPoints(rimLayer)
    rim:SetTexture(BORDER)
    rim:SetVertexColor(1, 0.88, 0.57, 1)

    -- The border follows the same max-only native StatusBar threshold.
    local redRim = CreateFrame("StatusBar", nil, cell)
    redRim:SetAllPoints(cell)
    redRim:SetFrameLevel(rimLayer:GetFrameLevel() + 1)
    redRim:SetStatusBarTexture(BORDER_RED)
    redRim:SetMinMaxValues(4, 5)
    redRim:SetValue(0)
    redRim:SetStatusBarColor(1, 1, 1, 1)

    local clawFrame = CreateFrame("Frame", nil, cell)
    clawFrame:SetAllPoints(cell)
    clawFrame:SetFrameLevel(redRim:GetFrameLevel() + 1)
    clawFrame:EnableMouse(false)
    local slash = clawFrame:CreateTexture(nil, "OVERLAY")
    slash:SetSize(28, 34)
    slash:SetPoint("CENTER", clawFrame, "CENTER", 0, 0)
    local slashLoaded = pcall(slash.SetTexture, slash, CAT_CLAW_TEXTURE)
    slash:Hide()
    if slashLoaded then
        local animGroup = clawFrame:CreateAnimationGroup()
        animGroup:SetLooping("NONE")
        local flip = animGroup:CreateAnimation("FlipBook")
        flip:SetTarget(slash)
        flip:SetDuration(0.60)
        flip:SetFlipBookRows(4)
        flip:SetFlipBookColumns(4)
        flip:SetFlipBookFrames(16)
        animGroup:SetScript("OnFinished", function()
            slash:Hide()
        end)
        cell.clawSlash = slash
        cell.clawAnimation = animGroup
    end

    local rogueFrame = CreateFrame("Frame", nil, cell)
    rogueFrame:SetAllPoints(cell)
    rogueFrame:SetFrameLevel(clawFrame:GetFrameLevel())
    rogueFrame:EnableMouse(false)
    local rogueSlash = rogueFrame:CreateTexture(nil, "OVERLAY")
    rogueSlash:SetSize(40, 40)
    rogueSlash:SetPoint("CENTER", rogueFrame, "CENTER")
    local rogueOK = pcall(rogueSlash.SetTexture, rogueSlash, ROGUE_DAGGER_TEXTURE)
    rogueSlash:Hide()
    if rogueOK then
        local animGroup = rogueFrame:CreateAnimationGroup()
        animGroup:SetLooping("NONE")
        local flip = animGroup:CreateAnimation("FlipBook")
        flip:SetTarget(rogueSlash)
        flip:SetDuration(0.30)
        flip:SetFlipBookRows(4)
        flip:SetFlipBookColumns(4)
        flip:SetFlipBookFrames(16)
        animGroup:SetScript("OnFinished", function()
            rogueSlash:Hide()
        end)
        cell.rogueSlash = rogueSlash
        cell.rogueAnimation = animGroup
    end

    cell.pointBar = active
    cell.fullRed = fullRed
    cell.redRim = redRim
    cell.maskedNormalTexture = nil
    cell.maskedRedTexture = nil
    return cell
end

-- Share the existing HEALTH/CAST LibSharedMedia and Blizzard texture menu.
-- Keep icon masking intact if SetStatusBarTexture changes the texture object.
function ns.ApplyNameplateComboTexture(group, name)
    if not group then return end
    name = type(name) == "string" and name or "H3z0 Flat"
    if group.appliedComboTexture == name then return end
    group.appliedComboTexture = name
    for _, cell in ipairs(group.points or {}) do
        for _, entry in ipairs({
            {bar = cell.normalBar, key = "maskedNormalTexture", r = 1, g = 0.74, b = 0.21},
            {bar = cell.redBar, key = "maskedRedTexture", r = 0.96, g = 0.22, b = 0.29},
        }) do
            local bar = entry.bar
            if ns.ApplyStatusbarMedia then
                ns.ApplyStatusbarMedia(bar, name)
            else
                bar:SetStatusBarTexture(FLAT)
            end
            bar:SetStatusBarColor(entry.r, entry.g, entry.b, 1)
            local fill = bar:GetStatusBarTexture()
            if fill and fill ~= cell[entry.key] then
                fill:AddMaskTexture(cell.comboMask)
                cell[entry.key] = fill
            end
        end
    end
end

-- The same construction/layout method serves live nameplates and the 2x
-- Nameplate Designer preview, so the edited position and scale match live.
function ns.CreateNameplateComboPoints(parent)
    if not parent then return nil end
    local group = CreateFrame("Frame", nil, parent)
    group:SetSize(5 * POINT_SIZE + 4 * POINT_GAP, POINT_SIZE)
    group:EnableMouse(false)
    group.points = {}
    group.visiblePoints = 0
    for i = 1, MAX_VISUAL_POINTS do
        group.points[i] = MakePoint(group, i)
    end
    ns.SetNameplateComboMax(group, 5)
    ns.ApplyNameplateComboTexture(group, "H3z0 Flat")
    return group
end

function ns.SetNameplateComboMax(group, maxPoints)
    if not group or Secret(maxPoints) or type(maxPoints) ~= "number" then return end
    maxPoints = math.max(1, math.min(MAX_VISUAL_POINTS, math.floor(maxPoints)))
    if group.visiblePoints == maxPoints then return end
    group.visiblePoints = maxPoints
    local width = maxPoints * POINT_SIZE + (maxPoints - 1) * POINT_GAP
    group:SetSize(width, POINT_SIZE)
    local origin = -width / 2
    for i, cell in ipairs(group.points) do
        cell:ClearAllPoints()
        cell:SetPoint("LEFT", group, "CENTER", origin + (i - 1) * (POINT_SIZE + POINT_GAP), 0)
        cell:SetShown(i <= maxPoints)
        -- Talents that raise the maximum use the actual cap; max-only red
        -- colour does not appear prematurely at five of six points.
        cell.fullRed:SetMinMaxValues(maxPoints - 1, maxPoints)
        cell.redRim:SetMinMaxValues(maxPoints - 1, maxPoints)
    end
end

function ns.LayoutNameplateComboPoints(group, healthShell, db)
    if not group or not healthShell or not db then return end
    group:ClearAllPoints()
    group:SetPoint("CENTER", healthShell, "CENTER", db.comboX or 0, db.comboY or -29)
    group:SetScale(db.comboScale or 1)
    ns.ApplyNameplateComboTexture(group, db.comboTexture)
end

-- The native Feral and Rogue slash effects animate only newly filled points.
-- Unlike a full-row glow, each class-specific effect plays once on its own
-- circle. Both limits are ordinary, non-secret Lua numbers at the call site.
local function PlayNewComboPoints(group, previous, current, isDruidCat)
    if not group or previous == nil or current <= previous then return end
    for index = previous + 1, math.min(current, group.visiblePoints) do
        local cell = group.points[index]
        if cell then
            local slash = isDruidCat and cell.clawSlash or cell.rogueSlash
            local animation = isDruidCat and cell.clawAnimation or cell.rogueAnimation
            if slash and animation then
                animation:Stop()
                slash:Show()
                animation:Play()
            end
        end
    end
end

function ns.SetNameplateComboPointValue(group, count)
    if not group then return end
    if not Secret(count) and type(count) ~= "number" then count = 0 end
    for _, cell in ipairs(group.points) do
        -- Forward raw protected values to the Blizzard-supported widget sink.
        pcall(cell.pointBar.SetValue, cell.pointBar, count)
        pcall(cell.fullRed.SetValue, cell.fullRed, count)
        pcall(cell.redRim.SetValue, cell.redRim, count)
    end
end

-- Forever stores the count on the target. UnitPower('player') can
-- describe a different resource state and must not be used here.
local function CurrentComboValue()
    if not GetComboPoints then return nil end
    local ok, value = pcall(GetComboPoints, 'player', 'target')
    if ok then return value end
    return nil
end

local function CurrentMaxPoints()
    if not UnitPowerMax then return nil end
    local ok, value = pcall(UnitPowerMax, "player", POWER_TYPE)
    if ok and not Secret(value) and type(value) == "number" and value > 0 then
        return value
    end
    local cap = MAX_COMBO_POINTS
    if not Secret(cap) and type(cap) == 'number' and cap > 0 then return cap end
    return 5
end

-- Host is a non-protected H3z0 overlay under the outer nameplate, not under
-- Blizzard's UnitFrame. The selected plate is chosen by frame identity;
-- target GUIDs and secret UnitIsUnit results are never inspected in Lua.
local previousComboValue
local previousComboClass

-- Switching targets must not replay a gain animation from the old target.
function ns.ResetNameplateComboTargetHistory()
    previousComboValue = nil
    previousComboClass = nil
end

function ns.UpdateNameplateComboPoints(records)
    if type(records) ~= "table" then return end
    local db = ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB()
    if db and tonumber(db.comboEnabled) == 0 then
        for _, record in pairs(records) do
            local group = record and record.comboPoints
            if group then
                group:SetAlpha(0)
                for _, cell in ipairs(group.points or {}) do
                    if cell.rogueAnimation then cell.rogueAnimation:Stop() end
                    if cell.clawAnimation then cell.clawAnimation:Stop() end
                    if cell.rogueSlash then cell.rogueSlash:Hide() end
                    if cell.clawSlash then cell.clawSlash:Hide() end
                end
            end
        end
        previousComboValue = nil
        previousComboClass = nil
        return
    end
    local classAllowed, isDruidCat = IsComboClass()
    local maxPoints
    -- The maximum can change with Rogue talents/spec even while combat is
    -- active. A public maximum is safe to apply to these H3z0-owned widgets;
    -- a protected maximum is ignored until the next public refresh.
    if classAllowed then
        maxPoints = CurrentMaxPoints()
    end
    local count = 0
    if classAllowed then count = CurrentComboValue() end
    local protected = Secret(count)
    local countPublic = not protected and type(count) == 'number'
    -- A missing target count cannot be displayed. Secret counts can still
    -- be forwarded to native StatusBars without being inspected by Lua.
    local hasPoints = protected or (countPublic and count > 0)
    -- Never replay effects on a target swap or on an initial unknown state.
    -- Only a readable increase on the current target triggers animation.
    local comboClass = classAllowed and (isDruidCat and "DRUID_CAT" or "ROGUE") or nil
    local playNewPoints = countPublic and comboClass ~= nil
        and previousComboClass == comboClass
        and previousComboValue ~= nil and count > previousComboValue
    local previous = previousComboValue
    local targetPlate
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, 'target')
        if ok and not Secret(plate) then targetPlate = plate end
    end

    for _, record in pairs(records) do
        local group = record and record.comboPoints
        if group then
            local active = classAllowed and hasPoints
                and record.h3z0SkinActive and record.unit ~= nil
            if not active then
                group:SetAlpha(0)
            else
                if maxPoints then ns.SetNameplateComboMax(group, maxPoints) end
                ns.SetNameplateComboPointValue(group, count)
                -- Compare the returned Blizzard nameplate frame, not
                -- UnitIsUnit's potentially protected identity result.
                local isTarget = targetPlate ~= nil and record.plate == targetPlate
                group:SetAlpha(isTarget and 1 or 0)
                if isTarget and playNewPoints then
                    PlayNewComboPoints(group, previous, count, isDruidCat)
                end
            end
        end
    end
    -- One shared count is reset on every target change to avoid replaying
    -- a gain animation when the new target already has Combo Points.
    -- If combat hides the count, discard our old sample: we must not play
    -- a delayed gain animation when the value becomes readable again.
    if countPublic then
        previousComboValue = classAllowed and count or nil
    else
        previousComboValue = nil
    end
    previousComboClass = comboClass
end
