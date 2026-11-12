local ADDON_NAME, ns = ...

-- H3z0Nameplates custom nameplate renderer.
-- Forever/Blizzard owns unit tokens, health/cast state and protected logic.
-- Native state/effect regions are retained above the custom visual bars.

local records = setmetatable({}, { __mode = "k" })
local byUnit = {}
local byUnitFrame = setmetatable({}, { __mode = "k" })
local eventFrame = CreateFrame("Frame")

local WHITE = ns.FLAT_TEXTURE or "Interface\\Buttons\\WHITE8X8"
local HEALTH_MASK = "Interface\\AddOns\\H3z0Nameplates\\Media\\NameplateHealthMask.tga"
local CAST_MASK = "Interface\\AddOns\\H3z0Nameplates\\Media\\NameplateCastMask.tga"
local CAST_ICON_MASK = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraMask.tga"
local CAST_ICON_BORDER = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorder.tga"
local CAST_ICON_SHADOW = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraShadow.tga"
local CAST_ICON_EXTRA_GAP = 2
local BAR_SOURCE_WIDTH, BAR_SOURCE_HEIGHT = 854, 98
local BORDER_STYLES = {
    -- Three-slice assets keep the rounded end caps intact while the middle stretches.
    normal = { path = "Interface\\AddOns\\H3z0Nameplates\\Media\\NameplateBorderNormal.tga", width = 926, height = 170 },
    highlight = { path = "Interface\\AddOns\\H3z0Nameplates\\Media\\NameplateBorderHighlight.tga", width = 980, height = 224 },
    aggro = { path = "Interface\\AddOns\\H3z0Nameplates\\Media\\NameplateBorderAggro.tga", width = 980, height = 224 },
}


-- Default presentation values.
local defaults = {
    layoutVersion = 2,
    enabled = true,
    -- User-facing presentation switch only. Blizzard still owns which plates exist.
    -- 1 = skin friendly + enemy, 0 = leave every friendly unit completely native.
    skinFriendlyEnabled = 0,
    -- Extra size multiplier for friendly plates, applied on top of globalScale.
    friendlyScale = 1,
    -- Optional separate bar and text sizes for friendly plates.
    friendlySizesEnabled = 0,
    -- 1 = friendly NPC plates show only the name (no bars, level or icons).
    friendlyNpcNameOnly = 0,
    -- Height of the name on text-only friendly NPC plates (0 = bar centre).
    friendlyNpcNameY = 0,
    -- Raises or lowers every nameplate (enemy and friendly).
    plateOffsetY = 0,
    -- 1 = always show health % / health value on the plate, even when the
    -- game's own nameplate health text setting is off.
    hpPercentOn = 0,
    hpValueOn = 0,
    -- Nameplate text font: "Default" or any LibSharedMedia font name.
    font = "Default",
    friendlyHealthWidth = 190,
    friendlyHealthHeight = 23,
    friendlyCastWidth = 190,
    friendlyCastHeight = 20,
    friendlyNameFontSize = 13,
    friendlyLevelFontSize = 13,
    friendlyHealthPercentFontSize = 11,
    friendlyHealthValueFontSize = 11,
    friendlyCastFontSize = 11,
    -- Target presentation. White keeps the stock highlight glow.
    targetR = 1, targetG = 1, targetB = 1,
    targetScale = 1,
    nonTargetAlpha = 1,
    -- Threat border: 0 off, 1 solo with a pet, 2 whenever the player holds
    -- aggro, 3 tank (the player does NOT hold aggro on a unit in combat).
    threatMode = 1,
    globalScale = 0.85,
    healthTexture = "H3z0 Flat",
    castTexture = "H3z0 Flat",
    comboTexture = "H3z0 Flat",
    comboEnabled = 1,
    incomingHealTexture = "Match Health",
    absorbTexture = "Match Health",
    damageEchoTexture = "Match Health",
    incomingHealsEnabled = 1,
    absorbsEnabled = 1,
    damageEchoEnabled = 1,
    damageEchoDuration = 0.5,
    damageEchoOpacity = 0.85,
    healthWidth = 190,
    healthHeight = 23,
    healthX = 0,
    healthY = 0,
    healthR = 145/255,
    healthG = 0,
    healthB = 0,
    healthBgR = 0,
    healthBgG = 0,
    healthBgB = 0,
    nameFontSize = 13,
    nameX = -0.83334447816,
    nameY = 20.8333258517,
    levelFontSize = 13,
    levelX = 84.2082824754,
    levelY = 20.2083115326,

    -- Native/parity indicators. These values affect presentation only:
    -- Blizzard/C_QuestLog remains the state owner.
    questX = 126.458297144,
    questY = 26.6667127982,
    questScale = 0.775297466433,
    classificationX = -84.000009127,
    classificationY = 22.2916488862,
    classificationScale = 1,
    raidTargetX = -0.124987962655,
    raidTargetY = 48.1249462394,
    raidTargetScale = 1.7797617746,
    -- Rogue / Druid Cat Form Combo Points on the selected target nameplate.
    comboX = 0,
    comboY = -29,
    comboScale = 1,

    healthPercentEnabled = 1,
    healthPercentFontSize = 11,
    healthPercentX = -73.2082804264,
    healthPercentY = 0.416624555363,
    healthValueEnabled = 1,
    healthValueFontSize = 11,
    healthValueX = 70.0834114868,
    healthValueY = 0.416636476293,
    nameOutline = true,
    castWidth = 190,
    castHeight = 20,
    castX = -0.416731843727,
    castY = 45.9583436167,
    helpfulR = 0.23, helpfulG = 0.85, helpfulB = 0.37,
    harmfulR = 0.95, harmfulG = 0.22, harmfulB = 0.20,
    shieldR = 0.639215707779,
    shieldG = 0.600000023842,
    shieldB = 0.600000023842,
    interruptedR = 0.95,
    interruptedG = 0.12,
    interruptedB = 0.10,
    castBgR = 0,
    castBgG = 0,
    castBgB = 0,
    castFontSize = 11,
    castOutline = true,
    iconEnabled = true,
    iconSize = 26.6666666667,
    iconGap = 3,
    shieldEnabled = true,
    shieldSize = 30.7692307692,
    shieldGap = 3,
}

local INTERRUPTED_HOLD_SECONDS = 0.75

local numericRanges = {
    globalScale={0.5,2.0}, friendlyScale={0.5,2.0}, friendlySizesEnabled={0,1}, friendlyNpcNameOnly={0,1}, friendlyNpcNameY={-60,80}, plateOffsetY={-40,80}, hpPercentOn={0,1}, hpValueOn={0,1},
    friendlyHealthWidth={70,360}, friendlyHealthHeight={8,48},
    friendlyCastWidth={70,360}, friendlyCastHeight={6,40},
    friendlyNameFontSize={7,30}, friendlyLevelFontSize={7,30},
    friendlyHealthPercentFontSize={7,30}, friendlyHealthValueFontSize={7,30},
    friendlyCastFontSize={7,26},
    targetScale={1.0,1.6}, nonTargetAlpha={0.2,1.0}, threatMode={0,3},
    incomingHealsEnabled={0,1}, absorbsEnabled={0,1}, damageEchoEnabled={0,1},
    damageEchoDuration={0.1,1.0}, damageEchoOpacity={0.2,1.0},
    healthWidth={70,360}, healthHeight={8,48}, healthX={-250,250}, healthY={-150,150},
    nameFontSize={7,30}, nameX={-250,250}, nameY={-150,150},
    levelFontSize={7,30}, levelX={-250,250}, levelY={-150,150},
    questX={-400,400}, questY={-250,250}, questScale={0.35,3.0},
    classificationX={-400,400}, classificationY={-250,250}, classificationScale={0.35,3.0},
    raidTargetX={-400,400}, raidTargetY={-250,250}, raidTargetScale={0.35,3.0},
    comboX={-400,400}, comboY={-250,250}, comboScale={0.35,3.0},
    healthPercentEnabled={0,1}, healthPercentFontSize={7,30}, healthPercentX={-250,250}, healthPercentY={-150,150},
    healthValueEnabled={0,1}, healthValueFontSize={7,30}, healthValueX={-250,250}, healthValueY={-150,150},
    castWidth={70,360}, castHeight={6,40}, castX={-250,250}, castY={-150,150},
    castFontSize={7,26}, iconSize={8,80}, iconGap={0,24}, shieldSize={8,80}, shieldGap={0,24},
}

local colorKeys = {
    "healthR","healthG","healthB","healthBgR","healthBgG","healthBgB",
    "helpfulR","helpfulG","helpfulB","harmfulR","harmfulG","harmfulB","shieldR","shieldG","shieldB",
    "interruptedR","interruptedG","interruptedB","castBgR","castBgG","castBgB",
    "targetR","targetG","targetB",
}

local function Clamp(value, low, high)
    value = tonumber(value)
    if not value then return low end
    if value < low then return low end
    if value > high then return high end
    return value
end

local function ApplyReferenceDefaults(db)
    for key, value in pairs(defaults) do
        if key ~= "layoutVersion" then db[key] = value end
    end
    db.layoutVersion = defaults.layoutVersion
end

local function Normalize(db)
    -- 0.13.0 used provisional capsule defaults and may have stored those
    -- values simply by opening/sliding the page. Migrate once to the actual
    -- Initialize missing options while preserving saved layouts.
    if tonumber(db.layoutVersion or 0) < defaults.layoutVersion then
        ApplyReferenceDefaults(db)
    end
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end
    for key, range in pairs(numericRanges) do
        db[key] = Clamp(db[key], range[1], range[2])
    end
    for _, key in ipairs(colorKeys) do db[key] = Clamp(db[key], 0, 1) end
    db.enabled = true
    db.skinFriendlyEnabled = tonumber(db.skinFriendlyEnabled) == 0 and 0 or 1
    db.nameOutline = db.nameOutline ~= false
    db.castOutline = db.castOutline ~= false
    db.iconEnabled = true
    db.shieldEnabled = true
    db.incomingHealsEnabled = db.incomingHealsEnabled == 0 and 0 or 1
    db.absorbsEnabled = db.absorbsEnabled == 0 and 0 or 1
    db.damageEchoEnabled = db.damageEchoEnabled == 0 and 0 or 1
    db.friendlySizesEnabled = db.friendlySizesEnabled == 1 and 1 or 0
    db.friendlyNpcNameOnly = db.friendlyNpcNameOnly == 1 and 1 or 0
    db.threatMode = math.floor(db.threatMode + 0.5)
    return db
end

local function GetDB()
    H3z0NameplatesDB = type(H3z0NameplatesDB) == "table" and H3z0NameplatesDB or {}
    H3z0NameplatesDB.designer = type(H3z0NameplatesDB.designer) == "table" and H3z0NameplatesDB.designer or {}
    return Normalize(H3z0NameplatesDB.designer)
end

function ns.GetNameplateDesignerDB() return GetDB() end

-- Fast presentation gate shared by the designer/parity/aura modules.
-- Blizzard remains the source of truth for friend/enemy classification.
-- Enemy players are not friends, so they continue through the full H3z0 path.
local function FriendlySkinEnabledFast()
    -- Hot-path read only. Do NOT call GetDB()/Normalize here: this helper is used
    -- by native Blizzard callbacks and can run very frequently around nameplates.
    local root = H3z0NameplatesDB
    local designer = type(root) == "table" and root.designer or nil
    return not (type(designer) == "table" and tonumber(designer.skinFriendlyEnabled) == 0)
end

function ns.ShouldSkinNameplateUnit(unit, unitFrame)
    if FriendlySkinEnabledFast() then return true end

    -- Prefer Blizzard's already-resolved nameplate state. Enemy players resolve
    -- as not-friend and therefore continue through the full H3z0 path.
    local isFriend = unitFrame and unitFrame.isFriend
    if isFriend ~= nil and not (issecretvalue and issecretvalue(isFriend))
        and type(isFriend) == "boolean" then
        return not isFriend
    end

    -- Compatibility fallback for builds/styles where isFriend is unavailable.
    if unit and UnitCanAttack then
        local ok, canAttack = pcall(UnitCanAttack, "player", unit)
        if ok and not (issecretvalue and issecretvalue(canAttack))
            and type(canAttack) == "boolean" then
            return canAttack
        end
    end

    -- Enemy-only mode must never accidentally skin an unresolved friendly plate.
    return false
end

-- Hot-path settings read (no Normalize). Missing keys are handled by callers.
local function FastDesignerDB()
    local root = H3z0NameplatesDB
    local designer = type(root) == "table" and root.designer or nil
    return type(designer) == "table" and designer or defaults
end

-- Friendly plates can carry their own size on top of Global Scale. Blizzard
-- stays the source of truth for friend/enemy; an unresolved unit counts as
-- not friendly so it simply keeps the normal size.
local function IsFriendlyRecord(record)
    local unitFrame = record and record.unitFrame
    local isFriend = unitFrame and unitFrame.isFriend
    if isFriend ~= nil and not (issecretvalue and issecretvalue(isFriend))
        and type(isFriend) == "boolean" then
        return isFriend
    end
    local unit = record and record.unit
    if unit and UnitCanAttack then
        local ok, canAttack = pcall(UnitCanAttack, "player", unit)
        if ok and not (issecretvalue and issecretvalue(canAttack))
            and type(canAttack) == "boolean" then
            return not canAttack
        end
    end
    return false
end

-- A friendly NPC is a friendly unit that is positively known not to be a
-- player. An unresolved (secret) answer counts as "not an NPC", so a player
-- plate is never turned into text only by this option.
local function IsNpcRecord(record)
    local unitFrame = record and record.unitFrame
    local isPlayer = unitFrame and unitFrame.isPlayer
    if isPlayer ~= nil and not (issecretvalue and issecretvalue(isPlayer))
        and type(isPlayer) == "boolean" then
        return isPlayer == false
    end
    local unit = record and record.unit
    if unit and UnitIsPlayer then
        local ok, value = pcall(UnitIsPlayer, unit)
        if ok and not (issecretvalue and issecretvalue(value))
            and type(value) == "boolean" then
            return value == false
        end
    end
    return false
end

function ns.GetNameplateRecordScale(record, db)
    db = db or GetDB()
    local scale = tonumber(db.globalScale) or 1
    if record and record.h3z0Friendly then
        scale = scale * (tonumber(db.friendlyScale) or 1)
    end
    return scale
end

-- Separate friendly sizes. Friendly plates read the layout through this
-- read-only view: bar and text sizes come from the friendly* settings, and
-- anything positioned against the health bar keeps its distance to the bar
-- edge, so level, health text and icons follow a narrower or flatter bar.
local FRIENDLY_SIZE_KEYS = {
    healthWidth = "friendlyHealthWidth", healthHeight = "friendlyHealthHeight",
    castWidth = "friendlyCastWidth", castHeight = "friendlyCastHeight",
    nameFontSize = "friendlyNameFontSize", levelFontSize = "friendlyLevelFontSize",
    healthPercentFontSize = "friendlyHealthPercentFontSize",
    healthValueFontSize = "friendlyHealthValueFontSize",
    castFontSize = "friendlyCastFontSize",
}
local FRIENDLY_X_KEYS = {
    nameX = true, levelX = true, healthPercentX = true, healthValueX = true,
    questX = true, classificationX = true, raidTargetX = true, comboX = true,
}
local FRIENDLY_Y_KEYS = {
    nameY = true, levelY = true, healthPercentY = true, healthValueY = true,
    questY = true, classificationY = true, raidTargetY = true, comboY = true,
}

local function FollowBarEdge(offset, baseSize, newSize)
    offset, baseSize, newSize = tonumber(offset), tonumber(baseSize), tonumber(newSize)
    if not offset or not baseSize or not newSize or baseSize <= 0 then return offset end
    local distance = math.abs(offset)
    -- Centred elements stay centred.
    if distance < baseSize * 0.15 then return offset end
    local moved = distance + (newSize - baseSize) / 2
    if moved < 0 then moved = 0 end
    if offset < 0 then return -moved end
    return moved
end

local friendlySource
local friendlyView = setmetatable({}, {
    __index = function(_, key)
        local db = friendlySource
        if not db then return nil end
        local sizeKey = FRIENDLY_SIZE_KEYS[key]
        if sizeKey then
            local value = db[sizeKey]
            if value ~= nil then return value end
            return db[key]
        end
        if FRIENDLY_X_KEYS[key] then
            return FollowBarEdge(db[key], db.healthWidth, db.friendlyHealthWidth)
        end
        if FRIENDLY_Y_KEYS[key] then
            return FollowBarEdge(db[key], db.healthHeight, db.friendlyHealthHeight)
        end
        if key == "shieldSize" then
            local base, friendly = tonumber(db.castHeight), tonumber(db.friendlyCastHeight)
            local size = tonumber(db.shieldSize)
            if base and friendly and size and base > 0 then return size * friendly / base end
            return db.shieldSize
        end
        return db[key]
    end,
    -- The view is read-only; settings are only ever written to the real table.
    __newindex = function() end,
})

function ns.GetNameplateRecordDB(record, db)
    db = db or GetDB()
    if record and record.h3z0Friendly and tonumber(db.friendlySizesEnabled) == 1 then
        friendlySource = db
        return friendlyView
    end
    return db
end
function ns.ResetNameplateDesignerDB()
    H3z0NameplatesDB = type(H3z0NameplatesDB) == "table" and H3z0NameplatesDB or {}
    H3z0NameplatesDB.designer = {}
    local db = GetDB()
    if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner() end
    return db
end

local function IsSecret(value)
    return issecretvalue and issecretvalue(value)
end

local function HasValue(value)
    if IsSecret(value) then return true end
    return value ~= nil
end

local function Usable(object)
    if not object then return false end
    if object.IsForbidden then
        local ok, forbidden = pcall(object.IsForbidden, object)
        if not ok or forbidden then return false end
    end
    return true
end

local function GetNativeHealth(unitFrame)
    local container = unitFrame and unitFrame.HealthBarsContainer
    return container and container.healthBar or nil
end

local function GetNativeCast(unitFrame)
    if not unitFrame then return nil end
    local hc = unitFrame.HealthBarsContainer
    local cc = unitFrame.CastBarsContainer or unitFrame.CastBarContainer
    return unitFrame.castBar or unitFrame.CastBar or unitFrame.CastingBarFrame or unitFrame.SpellCastBar
        or (cc and (cc.castBar or cc.CastBar))
        or (hc and (hc.castBar or hc.CastBar))
end

local function SetNativeCastContainersAlpha(unitFrame, alpha)
    if not unitFrame then return end
    local seen = {}
    local function Apply(frame)
        if frame and not seen[frame] and frame.SetAlpha then
            seen[frame] = true
            pcall(frame.SetAlpha, frame, alpha)
        end
    end
    Apply(unitFrame.CastBarsContainer)
    Apply(unitFrame.CastBarContainer)
    local hc = unitFrame.HealthBarsContainer
    if hc then
        Apply(hc.CastBarsContainer)
        Apply(hc.CastBarContainer)
    end
end

local function ApplyHealthColor(record)
    if not record or not Usable(record.health) then return end

    -- Reaction colour is not a H3z0Nameplates option. Blizzard/Forever owns
    -- the exact hostile/neutral/friendly/class-colour rules for the native
    -- nameplate. Mirror the resolved native StatusBar colour 1:1 so hostile
    -- mobs stay red, neutral mobs stay yellow, friendly units keep Blizzard's
    -- normal colour, and any future Blizzard rule changes carry through.
    if Usable(record.nativeHealth) and record.nativeHealth.GetStatusBarColor then
        local ok, r, g, b = pcall(record.nativeHealth.GetStatusBarColor, record.nativeHealth)
        if ok then
            -- Values are forwarded directly; never compare or do arithmetic on
            -- them because Forever can mark UI values secret.
            pcall(record.health.SetStatusBarColor, record.health, r, g, b)
            return
        end
    end

    -- Only a defensive fallback for a malformed/unavailable native bar.
    local db = GetDB()
    pcall(record.health.SetStatusBarColor, record.health, db.healthR, db.healthG, db.healthB, 1)
end

local function HookNativeHealthColor(record)
    local native = record and record.nativeHealth
    if not Usable(native) or record.hookedHealthColor == native then return end
    record.hookedHealthColor = native
    if hooksecurefunc and type(native.SetStatusBarColor) == "function" then
        pcall(hooksecurefunc, native, "SetStatusBarColor", function(_, r, g, b)
            -- UnitFrames are pooled independently from the outer nameplate. An old
            -- secure hook can therefore outlive this record's current UnitFrame;
            -- ignore it once Blizzard has rebound the record to another native bar.
            if record.unit and record.nativeHealth == native
                and ns.ShouldSkinNameplateUnit(record.unit, record.unitFrame) then
                -- Mirror Blizzard's resolved colour directly. No reaction API
                -- calls and no user toggle: native behaviour is authoritative.
                pcall(record.health.SetStatusBarColor, record.health, r, g, b)
            end
        end)
    end
end

local function SetFont(fontString, size, outlined)
    if not Usable(fontString) then return end
    local font
    if fontString.GetFont then
        local ok, current = pcall(fontString.GetFont, fontString)
        if ok then font = current end
    end
    font = font or STANDARD_TEXT_FONT
    local chosen = GetDB().font
    if type(chosen) == "string" and chosen ~= "Default" and ns.GetFontPath then
        font = ns.GetFontPath(chosen) or font
    end
    if fontString.SetFont then pcall(fontString.SetFont, fontString, font, size, outlined and "OUTLINE" or "") end
    if fontString.SetTextColor then pcall(fontString.SetTextColor, fontString, 1,1,1,1) end
    if fontString.SetShadowOffset then pcall(fontString.SetShadowOffset, fontString, 0,0) end
end

local function AttachMask(texture, parent, maskPath)
    if not Usable(texture) or not Usable(parent) then return nil end
    if parent.CreateMaskTexture and texture.AddMaskTexture then
        local mask = parent:CreateMaskTexture()
        local ok = pcall(mask.SetTexture, mask, maskPath, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not ok then pcall(mask.SetTexture, mask, maskPath) end
        mask:SetAllPoints(parent)
        local attached = pcall(texture.AddMaskTexture, texture, mask)
        if attached then return mask end
    end
    return nil
end

local function CreateBorderSkin(shell)
    local frame = CreateFrame("Frame", nil, shell)
    frame:SetPoint("CENTER", shell, "CENTER", 0, 0)
    frame:SetFrameLevel(shell:GetFrameLevel() + 1)
    frame.left = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    frame.middle = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    frame.right = frame:CreateTexture(nil, "BACKGROUND", nil, 0)
    return frame
end

local function SetBorderTexture(texture, path, u1, u2)
    if not texture then return end
    pcall(texture.SetTexture, texture, path)
    pcall(texture.SetTexCoord, texture, u1, u2, 0, 1)
    pcall(texture.SetVertexColor, texture, 1, 1, 1, 1)
    pcall(texture.SetAlpha, texture, 1)
end

local function LayoutBorderSkin(frame, shell, state)
    if not frame or not shell then return end
    local spec = BORDER_STYLES[state] or BORDER_STYLES.normal
    local shellW, shellH = shell:GetWidth() or 1, shell:GetHeight() or 1
    if shellW <= 0 or shellH <= 0 then frame:Hide(); return end

    -- Border assets are authored around an 854x98 inner bar.
    -- Scale the authored OUTER padding from that exact inner opening and do
    -- not add any synthetic extra size. This makes the live health/cast bar
    -- meet the border's inner edge exactly on left/right/top/bottom while all
    -- authored border/glow padding remains outside the bar.
    local scale = shellH / BAR_SOURCE_HEIGHT
    local outerW = shellW + (spec.width - BAR_SOURCE_WIDTH) * scale
    local outerH = shellH + (spec.height - BAR_SOURCE_HEIGHT) * scale
    local capSource = spec.height * 0.5
    local capOut = outerH * 0.5
    local middleOut = math.max(1, outerW - (capOut * 2))
    local uL = capSource / spec.width
    local uR = (spec.width - capSource) / spec.width

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", shell, "CENTER", 0, 0)
    frame:SetSize(outerW, outerH)

    SetBorderTexture(frame.left, spec.path, 0, uL)
    SetBorderTexture(frame.middle, spec.path, uL, uR)
    SetBorderTexture(frame.right, spec.path, uR, 1)

    frame.left:ClearAllPoints()
    frame.left:SetPoint("TOPLEFT", frame, "TOPLEFT", 0, 0)
    frame.left:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 0, 0)
    frame.left:SetWidth(capOut)

    frame.middle:ClearAllPoints()
    frame.middle:SetPoint("TOPLEFT", frame.left, "TOPRIGHT", 0, 0)
    frame.middle:SetPoint("BOTTOMLEFT", frame.left, "BOTTOMRIGHT", 0, 0)
    frame.middle:SetWidth(middleOut)

    frame.right:ClearAllPoints()
    frame.right:SetPoint("TOPLEFT", frame.middle, "TOPRIGHT", 0, 0)
    frame.right:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 0, 0)

    frame.state = state
    frame:Show()
end


local function CreateMaskedBar(root, maskPath)
    local shell = CreateFrame("Frame", nil, root)
    local borderSkin = CreateBorderSkin(shell)

    local bar = CreateFrame("StatusBar", nil, shell)
    bar:SetFrameLevel(shell:GetFrameLevel() + 2)
    bar:SetAllPoints(shell)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0,1)
    bar:SetValue(1)

    local bg = bar:CreateTexture(nil, "BACKGROUND", nil, -6)
    bg:SetAllPoints(bar)
    bg:SetColorTexture(1,1,1,1)

    local fill = bar:GetStatusBarTexture()
    local fillMask = AttachMask(fill, bar, maskPath)
    local bgMask = nil
    if not fillMask then bar:SetStatusBarTexture(maskPath) end

    -- Background should reach fully to the inside of the custom border. Keep
    -- it as a plain black rect (with alpha set later) instead of masking it,
    -- so no inset gap from the native/nameplate mask shows through.

    -- Keep the old two-return border slots aliased for compatibility with the
    -- current record/preview layout. They both point to the same 9-slice skin.
    return shell, borderSkin, borderSkin, bar, bg, fillMask, bgMask
end

local function CreateH3z0PredictionBar(parent, r, g, b, alpha)
    local bar = CreateFrame("StatusBar", nil, parent)
    bar:SetFrameLevel(parent:GetFrameLevel() + 1)
    bar:SetStatusBarTexture(WHITE)
    bar:SetMinMaxValues(0, 1)
    bar:SetValue(0)
    bar:SetStatusBarColor(r, g, b, 1)
    bar:SetAlpha(alpha or 1)
    return bar
end

local function CreateHealthEffectPresentation(shell, health)
    local layer = CreateFrame("Frame", nil, shell)
    layer:SetAllPoints(shell)
    layer:SetFrameLevel(health:GetFrameLevel() + 1)
    if layer.SetClipsChildren then pcall(layer.SetClipsChildren, layer, true) end

    -- Separate bars keep Blizzard's values independent: player heals, other
    -- heals, damage absorbs and heal absorbs can all be forwarded as secret
    -- values without Lua arithmetic.
    local myHeal = CreateH3z0PredictionBar(layer, 0.20, 1.00, 0.38, 0.62)
    local otherHeal = CreateH3z0PredictionBar(layer, 0.12, 0.72, 0.28, 0.46)
    local absorb = CreateH3z0PredictionBar(layer, 0.28, 0.72, 1.00, 0.62)
    local healAbsorb = CreateH3z0PredictionBar(layer, 1.00, 0.20, 0.18, 0.62)
    if healAbsorb.SetReverseFill then pcall(healAbsorb.SetReverseFill, healAbsorb, true) end

    -- One mask shared by every effect clips all bars to the exact H3z0
    -- healthbar silhouette instead of creating stock rectangular ends.
    local mask
    if layer.CreateMaskTexture then
        mask = layer:CreateMaskTexture()
        local ok = pcall(mask.SetTexture, mask, HEALTH_MASK, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        if not ok then pcall(mask.SetTexture, mask, HEALTH_MASK) end
        mask:SetAllPoints(layer)
        for _, bar in ipairs({myHeal, otherHeal, absorb, healAbsorb}) do
            local fill = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
            if fill and fill.AddMaskTexture then
                pcall(fill.AddMaskTexture, fill, mask)
                bar._h3z0MaskedFill = fill
            end
        end
    end

    -- Clean 2px edge indicators replace Blizzard's stock overshield/glow art.
    -- Keep them above the prediction bars but below text.
    local indicatorLayer = CreateFrame("Frame", nil, shell)
    indicatorLayer:SetAllPoints(shell)
    indicatorLayer:SetFrameLevel(health:GetFrameLevel() + 3)

    local overHeal = indicatorLayer:CreateTexture(nil, "OVERLAY", nil, 6)
    overHeal:SetColorTexture(0.20, 1.00, 0.38, 0.95)
    overHeal:SetWidth(2)
    overHeal:SetAlpha(0)

    local overAbsorb = indicatorLayer:CreateTexture(nil, "OVERLAY", nil, 6)
    overAbsorb:SetColorTexture(0.28, 0.72, 1.00, 0.95)
    overAbsorb:SetWidth(2)
    overAbsorb:SetAlpha(0)

    local overHealAbsorb = indicatorLayer:CreateTexture(nil, "OVERLAY", nil, 6)
    overHealAbsorb:SetColorTexture(1.00, 0.20, 0.18, 0.95)
    overHealAbsorb:SetWidth(2)
    overHealAbsorb:SetAlpha(0)

    -- Blizzard still decides exactly when the aggro flash happens. This is only
    -- the H3z0 visual that is played from Blizzard's native LoseAggroAnim.
    local flashLayer = CreateFrame("Frame", nil, shell)
    flashLayer:SetAllPoints(shell)
    flashLayer:SetFrameLevel(health:GetFrameLevel() + 4)
    local threatFlash = flashLayer:CreateTexture(nil, "OVERLAY", nil, 7)
    threatFlash:SetAllPoints(flashLayer)
    threatFlash:SetColorTexture(1.00, 0.78, 0.08, 0.58)
    if threatFlash.SetBlendMode then threatFlash:SetBlendMode("ADD") end
    AttachMask(threatFlash, flashLayer, HEALTH_MASK)
    threatFlash:SetAlpha(0)

    local threatFlashAnim = threatFlash:CreateAnimationGroup()
    local flashOut1 = threatFlashAnim:CreateAnimation("Alpha")
    flashOut1:SetDuration(0.25)
    flashOut1:SetFromAlpha(1)
    flashOut1:SetToAlpha(0)
    flashOut1:SetOrder(1)
    local flashOut2 = threatFlashAnim:CreateAnimation("Alpha")
    flashOut2:SetDuration(0.25)
    flashOut2:SetFromAlpha(1)
    flashOut2:SetToAlpha(0)
    flashOut2:SetOrder(2)
    if threatFlashAnim.SetToFinalAlpha then pcall(threatFlashAnim.SetToFinalAlpha, threatFlashAnim, true) end

    return {
        layer=layer,
        mask=mask,
        indicatorLayer=indicatorLayer,
        flashLayer=flashLayer,
        myHeal=myHeal,
        otherHeal=otherHeal,
        absorb=absorb,
        healAbsorb=healAbsorb,
        overHeal=overHeal,
        overAbsorb=overAbsorb,
        overHealAbsorb=overHealAbsorb,
        threatFlash=threatFlash,
        threatFlashAnim=threatFlashAnim,
    }
end

-- Additive cast-progress spark. It is anchored directly to the right edge of
-- our own StatusBar fill texture, so Blizzard/StatusBar drives its position.
-- No cast-value arithmetic is done in Lua (Forever secret-number safe).
local function ApplyEffectTexture(bar, name, mask)
    if not bar then return end
    local oldFill = bar:GetStatusBarTexture()
    if ns.ApplyStatusbarMedia then ns.ApplyStatusbarMedia(bar, name)
    else bar:SetStatusBarTexture(WHITE) end
    local fill = bar:GetStatusBarTexture()
    if oldFill ~= fill and oldFill and mask and oldFill.RemoveMaskTexture then
        pcall(oldFill.RemoveMaskTexture, oldFill, mask)
    end
    if fill and mask and fill.AddMaskTexture and bar._h3z0MaskedFill ~= fill then
        pcall(fill.AddMaskTexture, fill, mask)
        bar._h3z0MaskedFill = fill
    end
end

local function ApplyHealthEffectAppearance(record, db)
    local fx = record and record.healthEffects
    if not fx then return end
    local healName = db.incomingHealTexture == "Match Health" and db.healthTexture or db.incomingHealTexture
    local absorbName = db.absorbTexture == "Match Health" and db.healthTexture or db.absorbTexture
    local echoName = db.damageEchoTexture == "Match Health" and db.healthTexture or db.damageEchoTexture
    for _, bar in ipairs({fx.myHeal, fx.otherHeal}) do
        ApplyEffectTexture(bar, healName, fx.mask)
    end
    for _, bar in ipairs({fx.absorb, fx.healAbsorb}) do
        ApplyEffectTexture(bar, absorbName, fx.mask)
    end
    fx.myHeal:SetAlpha(db.incomingHealsEnabled ~= 0 and 0.62 or 0)
    fx.otherHeal:SetAlpha(db.incomingHealsEnabled ~= 0 and 0.46 or 0)
    fx.absorb:SetAlpha(db.absorbsEnabled ~= 0 and 0.62 or 0)
    fx.healAbsorb:SetAlpha(db.absorbsEnabled ~= 0 and 0.62 or 0)
    if record.damageEcho then
        ApplyEffectTexture(record.damageEcho, echoName, record.damageEchoMask)
        record.damageEcho:SetStatusBarColor(0.94, 0.20, 0.22, 1)
        record.damageEcho:SetAlpha(db.damageEchoEnabled ~= 0 and db.damageEchoOpacity or 0)
        local fill = record.damageEcho:GetStatusBarTexture()
        if fill and fill.SetDrawLayer then pcall(fill.SetDrawLayer, fill, "ARTWORK", -1) end
    end
end

local interpolation = Enum and Enum.StatusBarInterpolation
local ECHO_IMMEDIATE = interpolation and interpolation.Immediate or 0
local ECHO_SMOOTH = interpolation and interpolation.ExponentialEaseOut

local function ClearDamageEcho(record)
    if not record then return end
    record.echoGeneration = (record.echoGeneration or 0) + 1
    record.echoReady = false
    if record.damageEcho then
        pcall(record.damageEcho.SetMinMaxValues, record.damageEcho, 0, 1)
        pcall(record.damageEcho.SetValue, record.damageEcho, 0, ECHO_IMMEDIATE)
    end
end

local function UpdateDamageEcho(record, health, maximum, sourceEvent)
    local echo = record and record.damageEcho
    if not echo or not record.unit then return end
    local db = GetDB()
    if db.damageEchoEnabled == 0 or not ECHO_SMOOTH then
        ClearDamageEcho(record)
        return
    end
    pcall(echo.SetMinMaxValues, echo, 0, maximum)
    if not record.echoReady or sourceEvent == "UNIT_MAXHEALTH" then
        record.echoGeneration = (record.echoGeneration or 0) + 1
        record.echoReady = true
        pcall(echo.SetValue, echo, health, ECHO_IMMEDIATE)
        return
    end
    if sourceEvent ~= "UNIT_HEALTH" then return end
    record.echoGeneration = (record.echoGeneration or 0) + 1
    local generation, unit = record.echoGeneration, record.unit
    local function CanUpdate()
        return record.echoGeneration == generation and record.unit == unit and record.h3z0SkinActive
    end
    if not C_Timer or not C_Timer.After then
        pcall(echo.SetValue, echo, health, ECHO_SMOOTH)
        return
    end
    C_Timer.After(0.06, function()
        if CanUpdate() then pcall(echo.SetValue, echo, health, ECHO_SMOOTH) end
    end)
    C_Timer.After(db.damageEchoDuration, function()
        if CanUpdate() then pcall(echo.SetValue, echo, health, ECHO_IMMEDIATE) end
    end)
end

local function CreateCastProgressSpark(shell, bar)
    if not shell or not bar or not bar.GetStatusBarTexture then return nil end
    local fill = bar:GetStatusBarTexture()
    if not fill then return nil end

    local spark = shell:CreateTexture(nil, "OVERLAY", nil, 7)
    spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
    if spark.SetBlendMode then spark:SetBlendMode("ADD") end
    if spark.SetVertexColor then spark:SetVertexColor(1, 1, 1, 0.95) end
    spark:ClearAllPoints()
    spark:SetPoint("CENTER", fill, "RIGHT", 0, 0)
    spark:Hide()
    return spark
end

local function LayoutCastProgressSpark(spark, barHeight)
    if not spark then return end
    local h = tonumber(barHeight) or defaults.castHeight
    spark:SetSize(math.max(8, h * 0.85), math.max(24, h * 2.75))
end

local function ConfigureMaskedBar(shell, borderSkin, _, bar, bg, width, height, r,g,b, br,bgC,bb)
    shell:SetSize(width, height)

    -- The fill remains exactly width x height. The authored border asset is a
    -- separate frame behind it and expands only OUTSIDE the bar. There is no
    -- border-thickness option: the PNG itself defines the look.
    bar:ClearAllPoints()
    bar:SetAllPoints(shell)
    LayoutBorderSkin(borderSkin, shell, "normal")

    bg:SetVertexColor(0,0,0,0.6)
    bar:SetStatusBarColor(r,g,b,1)
end

-- Shared H3z0Nameplates castbar visual -----------------------------------------
--
-- Shared castbar renderer. Blizzard remains the state and timing source.
local function CreateStyledCastIconFrame(parent)
    local frame = CreateFrame("Frame", nil, parent)

    local shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
    shadow:SetTexture(CAST_ICON_SHADOW)
    shadow:SetVertexColor(1, 1, 1, .82)
    frame.H3z0CastShadow = shadow

    local icon = frame:CreateTexture(nil, "ARTWORK", nil, 0)
    icon:SetAllPoints(frame)
    icon:SetTexCoord(.08,.92,.08,.92)
    local mask = AttachMask(icon, frame, CAST_ICON_MASK)
    if not mask and icon.SetMask then pcall(icon.SetMask, icon, CAST_ICON_MASK) end

    local border = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    border:SetAllPoints(frame)
    border:SetTexture(CAST_ICON_BORDER)
    if border.SetVertexColor then border:SetVertexColor(1,1,1,1) end

    return frame, icon, border, mask
end

local function LayoutStyledCastIconBorder(frame, border, iconSize)
    if not frame or not border then return end
    local size = tonumber(iconSize) or 0
    if size <= 0 then return end

    border:ClearAllPoints()
    border:SetAllPoints(frame)
    local shadow = frame.H3z0CastShadow
    if shadow then
        shadow:ClearAllPoints()
        shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -4, 4)
        shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", 4, -4)
    end
end

local function SetAlpha(region, value)
    if Usable(region) and region.SetAlpha then pcall(region.SetAlpha, region, value) end
end

local function HideNativeHighlightArt(record)
    -- Selection/deselection and the one-shot aggro flash are H3z0-skinned.
    -- The native progressive aggro flare is deliberately untouched: Blizzard
    -- continues to own and draw that effect.
    local health = record and record.nativeHealth
    SetAlpha(health and health.selectedBorder, 0)
    SetAlpha(health and health.deselectedOverlay, 0)

    local unitFrame = record and record.unitFrame
    local nativeFlash = unitFrame and unitFrame.aggroFlash
    if Usable(nativeFlash) and nativeFlash.SetVertexColor then
        -- LoseAggroAnim may animate region alpha after this point, so zero the
        -- texture's vertex alpha instead of fighting Blizzard's animation.
        pcall(nativeFlash.SetVertexColor, nativeFlash, 1, 1, 0, 0)
    end
end

local function ApplyResolvedBooleanAlpha(region, value)
    if not Usable(region) then return end
    if region.SetAlphaFromBoolean then
        local ok = pcall(region.SetAlphaFromBoolean, region, value, 1, 0)
        if ok then return end
    end
    if not IsSecret(value) then SetAlpha(region, value == true and 1 or 0) end
end

local function LayoutHealthEffects(record, db)
    local fx = record and record.healthEffects
    if not fx or not Usable(record.health) or not Usable(record.healthShell) then return end
    local fill = record.health.GetStatusBarTexture and record.health:GetStatusBarTexture()
    if not Usable(fill) then return end

    local width, height = db.healthWidth, db.healthHeight
    for _, bar in ipairs({fx.myHeal, fx.otherHeal, fx.absorb, fx.healAbsorb}) do
        bar:ClearAllPoints()
        bar:SetSize(width, height)
    end

    -- Every forward segment starts exactly where the previous StatusBar fill
    -- ends. StatusBar itself converts secret amounts to pixel width.
    fx.myHeal:SetPoint("LEFT", fill, "RIGHT", 0, 0)
    local myFill = fx.myHeal:GetStatusBarTexture()
    fx.otherHeal:SetPoint("LEFT", myFill, "RIGHT", 0, 0)
    local otherFill = fx.otherHeal:GetStatusBarTexture()
    fx.absorb:SetPoint("LEFT", otherFill, "RIGHT", 0, 0)

    -- Heal absorbs consume existing health from the current-health edge inward.
    fx.healAbsorb:SetPoint("RIGHT", fill, "RIGHT", 0, 0)

    fx.overHeal:ClearAllPoints()
    fx.overHeal:SetPoint("TOPRIGHT", record.healthShell, "TOPRIGHT", -1, -1)
    fx.overHeal:SetPoint("BOTTOMRIGHT", record.healthShell, "BOTTOMRIGHT", -1, 1)

    fx.overAbsorb:ClearAllPoints()
    fx.overAbsorb:SetPoint("TOPRIGHT", record.healthShell, "TOPRIGHT", -4, -1)
    fx.overAbsorb:SetPoint("BOTTOMRIGHT", record.healthShell, "BOTTOMRIGHT", -4, 1)

    fx.overHealAbsorb:ClearAllPoints()
    fx.overHealAbsorb:SetPoint("TOPLEFT", record.healthShell, "TOPLEFT", 1, -1)
    fx.overHealAbsorb:SetPoint("BOTTOMLEFT", record.healthShell, "BOTTOMLEFT", 1, 1)
end

local function ClearHealthEffects(record)
    local fx = record and record.healthEffects
    if not fx then return end
    for _, bar in ipairs({fx.myHeal, fx.otherHeal, fx.absorb, fx.healAbsorb}) do
        pcall(bar.SetMinMaxValues, bar, 0, 1)
        pcall(bar.SetValue, bar, 0)
    end
    SetAlpha(fx.overHeal, 0)
    SetAlpha(fx.overAbsorb, 0)
    SetAlpha(fx.overHealAbsorb, 0)
end

local function UpdateHealthEffects(record)
    if not record or not record.unit or not record.healthEffectsSupported then
        ClearHealthEffects(record)
        return
    end

    -- Blizzard may refresh native prediction textures on the same prediction
    -- events. Re-assert only their visual alpha before drawing H3z0's mirror;
    -- the native frames remain alive as Blizzard-owned state.
    if ns.SkinNativeHealth then ns.SkinNativeHealth(record) end
    local calc = record.healthPredictionCalculator
    if not calc or type(UnitGetDetailedHealPrediction) ~= "function" then
        ClearHealthEffects(record)
        return
    end

    local ok = pcall(UnitGetDetailedHealPrediction, record.unit, "player", calc)
    if not ok then
        ClearHealthEffects(record)
        return
    end

    local okMax, maxHealth = pcall(calc.GetMaximumHealth, calc)
    if not okMax then
        ClearHealthEffects(record)
        return
    end

    local fx = record.healthEffects
    local db = GetDB()
    for _, bar in ipairs({fx.myHeal, fx.otherHeal, fx.absorb, fx.healAbsorb}) do
        pcall(bar.SetMinMaxValues, bar, 0, maxHealth)
    end

    if type(calc.GetIncomingHeals) == "function" then
        local okHeal, _, playerHeal, otherHeal, healClamped = pcall(calc.GetIncomingHeals, calc)
        if okHeal then
            if db.incomingHealsEnabled ~= 0 then
                pcall(fx.myHeal.SetValue, fx.myHeal, playerHeal)
                pcall(fx.otherHeal.SetValue, fx.otherHeal, otherHeal)
                ApplyResolvedBooleanAlpha(fx.overHeal, healClamped)
            else
                pcall(fx.myHeal.SetValue, fx.myHeal, 0)
                pcall(fx.otherHeal.SetValue, fx.otherHeal, 0)
                SetAlpha(fx.overHeal, 0)
            end
        end
    end

    if type(calc.GetDamageAbsorbs) == "function" then
        local okAbsorb, absorbAmount, absorbClamped = pcall(calc.GetDamageAbsorbs, calc)
        if okAbsorb then
            if db.absorbsEnabled ~= 0 then
                pcall(fx.absorb.SetValue, fx.absorb, absorbAmount)
                ApplyResolvedBooleanAlpha(fx.overAbsorb, absorbClamped)
            else
                pcall(fx.absorb.SetValue, fx.absorb, 0)
                SetAlpha(fx.overAbsorb, 0)
            end
        end
    end

    if type(calc.GetHealAbsorbs) == "function" then
        local okHealAbsorb, healAbsorbAmount, healAbsorbClamped = pcall(calc.GetHealAbsorbs, calc)
        if okHealAbsorb then
            if db.absorbsEnabled ~= 0 then
                pcall(fx.healAbsorb.SetValue, fx.healAbsorb, healAbsorbAmount)
                ApplyResolvedBooleanAlpha(fx.overHealAbsorb, healAbsorbClamped)
            else
                pcall(fx.healAbsorb.SetValue, fx.healAbsorb, 0)
                SetAlpha(fx.overHealAbsorb, 0)
            end
        end
    end
end

local function PlayH3z0ThreatFlash(record)
    local fx = record and record.healthEffects
    local anim = fx and fx.threatFlashAnim
    if not anim then return end
    if anim.Restart then
        pcall(anim.Restart, anim)
    else
        pcall(anim.Stop, anim)
        pcall(anim.Play, anim)
    end
end

local function HookNativeThreatFlash(record)
    local unitFrame = record and record.unitFrame
    local nativeAnim = unitFrame and unitFrame.LoseAggroAnim
    if not nativeAnim or record.hookedThreatFlashAnim == nativeAnim then return end
    record.hookedThreatFlashAnim = nativeAnim

    local function Active()
        if record.unit and record.h3z0SkinActive and record.unitFrame == unitFrame then
            HideNativeHighlightArt(record)
            PlayH3z0ThreatFlash(record)
        end
    end

    if hooksecurefunc then
        if type(nativeAnim.Play) == "function" then pcall(hooksecurefunc, nativeAnim, "Play", Active) end
        if type(nativeAnim.Restart) == "function" then pcall(hooksecurefunc, nativeAnim, "Restart", Active) end
    end
end

local function UpdateBorderState(record)
    if not record or not Usable(record.healthGlow) then return end
    -- Base border is only normal/target. A separate red aggro overlay sits on
    -- top and is driven directly by Blizzard's secret-safe threat boolean.
    local state = (record.isTarget or record.isFocus) and "highlight" or "normal"
    LayoutBorderSkin(record.healthGlow, record.healthShell, state)
    -- Selection/focus belongs to the unit, so show it only on health. The
    -- castbar has separate important/cast-at-player/interrupt state styling.
    LayoutBorderSkin(record.castGlow, record.castShell, "normal")
    if record.isTarget then
        -- Optional custom colour for the target glow. White is the stock look.
        local settings = FastDesignerDB()
        local r, g, b = tonumber(settings.targetR) or 1, tonumber(settings.targetG) or 1, tonumber(settings.targetB) or 1
        if r < 1 or g < 1 or b < 1 then
            record.healthGlow.left:SetVertexColor(r, g, b)
            record.healthGlow.middle:SetVertexColor(r, g, b)
            record.healthGlow.right:SetVertexColor(r, g, b)
        end
    end
    if record.isFocus and not record.isTarget then
        local color = NAMEPLATE_BORDER_FOCUS_TARGET_COLOR
        local r, g, b = .55, .75, 1
        if color then r, g, b = color.r, color.g, color.b end
        record.healthGlow.left:SetVertexColor(r, g, b)
        record.healthGlow.middle:SetVertexColor(r, g, b)
        record.healthGlow.right:SetVertexColor(r, g, b)
    end
    record.borderState = state
end

local function ApplyThreatBooleanToOverlay(overlay, threatBool, inverted)
    if not overlay then return end

    -- Forever can return a secret boolean from UnitDetailedThreatSituation in
    -- combat. Pass that value directly to the secure widget helper instead of
    -- branching on it in Lua. This is the same secret-safe pattern used by
    -- Blizzard UI code for boolean-driven visual state.
    if overlay.SetAlphaFromBoolean then
        pcall(overlay.SetAlphaFromBoolean, overlay, threatBool, inverted and 0 or 1, inverted and 1 or 0)
        return
    end

    -- Fallback is only used when the value is ordinary/non-secret.
    if not IsSecret(threatBool) then
        local shown = threatBool == true
        if inverted then shown = not shown end
        overlay:SetAlpha(shown and 1 or 0)
    end
end

local function HideThreatOverlay(record)
    ApplyThreatBooleanToOverlay(record.healthAggro, false)
    ApplyThreatBooleanToOverlay(record.castAggro, false)
end

-- Tank mode only: the border pieces are additionally gated by "this unit is
-- in combat", so idle units never light up. The value goes straight into the
-- widget, like the threat boolean, and is never inspected when protected.
local function SetThreatCombatGate(record, enabled)
    if not enabled and not record.threatCombatGated then return end
    record.threatCombatGated = enabled or nil
    local gate = true
    if enabled and UnitAffectingCombat then
        local ok, inCombat = pcall(UnitAffectingCombat, record.unit)
        if ok then gate = inCombat end
    end
    for index = 1, 2 do
        local overlay = index == 1 and record.healthAggro or record.castAggro
        if overlay then
            for piece = 1, 3 do
                local texture = piece == 1 and overlay.left or piece == 2 and overlay.middle or overlay.right
                if texture then
                    if texture.SetAlphaFromBoolean then
                        pcall(texture.SetAlphaFromBoolean, texture, gate, 1, 0)
                    elseif not IsSecret(gate) and texture.SetAlpha then
                        pcall(texture.SetAlpha, texture, gate == true and 1 or 0)
                    end
                end
            end
        end
    end
end

local function UpdateSelectedThreatMode(record, mode)
    local ok, isTanking, status = pcall(UnitDetailedThreatSituation, "player", record.unit)
    if not ok then
        HideThreatOverlay(record)
        return
    end
    -- A readable "no threat status" means the player is not on this unit's
    -- threat table at all, so there is nothing to show in either mode.
    if not IsSecret(status) and status == nil then
        HideThreatOverlay(record)
        return
    end
    if not IsSecret(isTanking) then
        isTanking = (isTanking == true)
    end
    local tankMode = mode == 3
    SetThreatCombatGate(record, tankMode)
    ApplyThreatBooleanToOverlay(record.healthAggro, isTanking, tankMode)
    ApplyThreatBooleanToOverlay(record.castAggro, isTanking, tankMode)
end

local function UpdateAggroOverlay(record)
    if not record or not record.unit then return end

    local mode = tonumber(FastDesignerDB().threatMode) or 1
    if mode == 0 then
        HideThreatOverlay(record)
        return
    end
    if mode >= 2 then
        UpdateSelectedThreatMode(record, mode)
        return
    end
    -- Mode 1 below is the original solo-with-pet behaviour, unchanged.
    SetThreatCombatGate(record, false)

    -- The supplemental solo/pet border is a progressive threat highlight. It
    -- must obey that exact Blizzard bit instead of appearing when only Flash or
    -- Health Bar Color was selected.
    local uf = record.unitFrame
    if not uf or uf.displayAggroHighlight ~= true then
        ApplyThreatBooleanToOverlay(record.healthAggro, false)
        ApplyThreatBooleanToOverlay(record.castAggro, false)
        return
    end

    -- Parity rule: Blizzard always retains ownership of its native progressive
    -- threat, health-colour and aggro-flash systems. H3z0 adds its old red
    -- border only while solo, where Blizzard's party-oriented progressive
    -- threat display does not provide the same player-vs-pet feedback.
    if IsInGroup and IsInGroup() then
        ApplyThreatBooleanToOverlay(record.healthAggro, false)
        ApplyThreatBooleanToOverlay(record.castAggro, false)
        return
    end

    -- The extra H3z0 border exists specifically to cover the solo player-vs-pet
    -- threat case that Blizzard's party-oriented progressive threat display does
    -- not expose in the same way. If there is no active pet unit, keep the H3z0
    -- overlay fully disabled and leave Blizzard's native threat presentation alone.
    -- Using the generic "pet" unit token keeps this parity-safe for Hunter,
    -- Warlock, and any other class/build that exposes a real controllable pet.
    if not (UnitExists and UnitExists("pet")) then
        ApplyThreatBooleanToOverlay(record.healthAggro, false)
        ApplyThreatBooleanToOverlay(record.castAggro, false)
        return
    end

    -- This reproduces the useful pre-parity H3z0 behaviour for solo pet play:
    -- if the player becomes the tanking unit for this nameplate, the H3z0 red
    -- border appears. If the pet still owns aggro, it remains hidden. Do not
    -- inspect a secret return value; feed it straight into SetAlphaFromBoolean.
    local ok, isTanking = pcall(UnitDetailedThreatSituation, "player", record.unit)
    if not ok then
        ApplyThreatBooleanToOverlay(record.healthAggro, false)
        ApplyThreatBooleanToOverlay(record.castAggro, false)
        return
    end

    if not IsSecret(isTanking) then
        isTanking = (isTanking == true)
    end

    ApplyThreatBooleanToOverlay(record.healthAggro, isTanking)
    ApplyThreatBooleanToOverlay(record.castAggro, isTanking)
end

local function SyncAggroState(record)
    if not record then return end
    HideNativeHighlightArt(record)
    UpdateBorderState(record)
    UpdateAggroOverlay(record)
end

local function QueueAggroSync(record)
    if not record or not record.h3z0SkinActive then return end
    SyncAggroState(record)
    if C_Timer and C_Timer.After then
        C_Timer.After(0, function()
            if record.unit and record.plate then SyncAggroState(record) end
        end)
    end
end

local currentHasTarget = false

-- Target size and non-target fading only touch the H3z0-owned root frame, so
-- they are safe to change in combat and never move Blizzard's own regions.
-- Smooth size/fade when the target changes. Only the H3z0 root frame is
-- touched, so this is safe in combat.
-- Nameplate height: the whole H3z0 presentation moves up or down around the
-- native plate. The offset is divided by the plate scale so it stays in
-- screen units while a plate is scaled.
local function PlaceRoot(record, scale)
    local root, unitFrame = record and record.root, record and record.unitFrame
    if not root or not unitFrame then return end
    scale = tonumber(scale) or 1
    if scale <= 0 then scale = 1 end
    local y = (tonumber(GetDB().plateOffsetY) or 0) / scale
    pcall(root.ClearAllPoints, root)
    pcall(root.SetPoint, root, "CENTER", unitFrame, "CENTER", 0, y)
end
ns.PlaceNameplateRoot = PlaceRoot

local TARGET_GLIDE_SPEED = 16
local targetGlide = {}
local targetGlideFrame = CreateFrame("Frame")
targetGlideFrame:Hide()
targetGlideFrame:SetScript("OnUpdate", function(self, elapsed)
    local blend = math.min(1, (elapsed or 0) * TARGET_GLIDE_SPEED)
    local active = false
    for record in pairs(targetGlide) do
        local root = record.root
        local scaleTo, alphaTo = record.h3zScaleTo, record.h3zAlphaTo
        if not root or not scaleTo or not alphaTo then
            targetGlide[record] = nil
        else
            local scale = record.h3zScale + (scaleTo - record.h3zScale) * blend
            local alpha = record.h3zAlpha + (alphaTo - record.h3zAlpha) * blend
            if math.abs(scaleTo - scale) < 0.005 and math.abs(alphaTo - alpha) < 0.01 then
                scale, alpha = scaleTo, alphaTo
                targetGlide[record] = nil
            else
                active = true
            end
            record.h3zScale, record.h3zAlpha = scale, alpha
            pcall(root.SetScale, root, scale)
            PlaceRoot(record, scale)
            pcall(root.SetAlpha, root, alpha)
        end
    end
    if not active then self:Hide() end
end)

local function ApplyTargetPresentation(record, db, snap)
    if not record or not record.root then return end
    db = db or FastDesignerDB()
    local scale = ns.GetNameplateRecordScale(record, db)
    local alpha = 1
    if record.isTarget then
        scale = scale * Clamp(db.targetScale or 1, 1, 1.6)
    elseif currentHasTarget then
        alpha = Clamp(db.nonTargetAlpha or 1, 0.2, 1)
    end
    record.h3zScaleTo, record.h3zAlphaTo = scale, alpha
    -- A freshly set up plate snaps to its state; a target change glides.
    if snap or not record.h3zScale then
        record.h3zScale, record.h3zAlpha = scale, alpha
        targetGlide[record] = nil
        pcall(record.root.SetScale, record.root, scale)
        PlaceRoot(record, scale)
        pcall(record.root.SetAlpha, record.root, alpha)
    else
        targetGlide[record] = true
        targetGlideFrame:Show()
    end
end

local function RefreshTargetHighlights()
    local targetPlate, focusPlate
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "target")
        if ok then targetPlate = plate end
        ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, "focus")
        if ok then focusPlate = plate end
    end
    local hasTarget = targetPlate ~= nil
    if UnitExists then
        local okExists, exists = pcall(UnitExists, "target")
        if okExists and not IsSecret(exists) then hasTarget = exists == true end
    end
    currentHasTarget = hasTarget
    local settings = FastDesignerDB()
    for _, record in pairs(byUnit) do
        if record then
            record.isTarget = targetPlate ~= nil and record.plate == targetPlate
            record.isFocus = focusPlate ~= nil and record.plate == focusPlate
            if record.h3z0SkinActive then
                HideNativeHighlightArt(record)
                UpdateBorderState(record)
                ApplyTargetPresentation(record, settings)
            end
        end
    end
end

local function HideNativeHealth(record)
    ns.SkinNativeHealth(record)
end

local function HideNativeCast(record)
    record.nativeCast = GetNativeCast(record.unitFrame) or record.nativeCast
    ns.SkinNativeCast(record)
end

local function RestoreNative(record)
    local health = record.nativeHealth
    local unitFrame = record.unitFrame
    if Usable(health) then
        SetAlpha(health, 1)
        for _, region in ipairs({
            health.bgTexture, health.BgTexture, health.Background,
            health.selectedBorder, health.deselectedOverlay,
            health.myHealPrediction, health.otherHealPrediction,
            health.totalAbsorb, health.totalAbsorbOverlay,
            health.overAbsorbGlow, health.overHealAbsorbGlow,
            health.myHealAbsorb, health.myHealAbsorbLeftShadow, health.myHealAbsorbRightShadow,
            health.LeftText, health.RightText, health.Text, health.TextString,
        }) do
            SetAlpha(region, 1)
        end
        local fill = health.barTexture or health.BarTexture
        if not Usable(fill) and health.GetStatusBarTexture then
            local ok, result = pcall(health.GetStatusBarTexture, health)
            if ok then fill = result end
        end
        SetAlpha(fill, 1)
        local name = (unitFrame and (unitFrame.name or unitFrame.Name)) or health.unitNameFontString
        SetAlpha(name, 1)
        SetAlpha(unitFrame and unitFrame.LevelFrame, 1)
        SetAlpha(unitFrame and unitFrame.PlayerLevelDiffFrame, 1)
    end
    local nativeAggroFlash = unitFrame and unitFrame.aggroFlash
    if Usable(nativeAggroFlash) and nativeAggroFlash.SetVertexColor then
        pcall(nativeAggroFlash.SetVertexColor, nativeAggroFlash, 1, 1, 0, 1)
    end
    SetNativeCastContainersAlpha(record.unitFrame, 1)
    local cast = record.nativeCast or GetNativeCast(record.unitFrame)
    if Usable(cast) then
        SetAlpha(cast, 1)
        for _, region in ipairs({
            cast.Background, cast.background, cast.Bg, cast.Border, cast.border,
            cast.TextBorder, cast.textBorder, cast.DropShadow,
            cast.Icon, cast.icon, cast.IconTexture, cast.iconTexture,
            cast.BorderShield, cast.borderShield, cast.Shield, cast.shield,
            cast.Text, cast.text,
        }) do SetAlpha(region, 1) end
        local fill
        if cast.GetStatusBarTexture then
            local ok, result = pcall(cast.GetStatusBarTexture, cast)
            if ok then fill = result end
        end
        SetAlpha(fill, 1)
    end
    if ns.RestoreNativeParityPresentation then ns.RestoreNativeParityPresentation(record) end
end

local function CreateRecord(unit, plate)
    if not Usable(plate) or not Usable(plate.UnitFrame) then return nil end
    local nativeHealth = GetNativeHealth(plate.UnitFrame)
    if not Usable(nativeHealth) then return nil end

    -- Native-anchor isolation: the H3z0 tree is a sibling presentation branch
    -- under the outer nameplate, never a child of HealthBarsContainer/CastBarsContainer.
    -- Blizzard may freely rebuild its internal native anchor family on CVar changes
    -- without any native frame inheriting a dependency on a H3z0 frame.
    local root = CreateFrame("Frame", nil, plate)
    root:SetSize(1,1)
    root:SetPoint("CENTER", plate.UnitFrame, "CENTER", 0, 0)
    local okLevel, baseLevel = pcall(plate.UnitFrame.GetFrameLevel, plate.UnitFrame)
    if okLevel and type(baseLevel) == "number" then root:SetFrameLevel(baseLevel + 20) end

    local healthShell, healthGlow, healthOuter, health, healthBG, healthMask = CreateMaskedBar(root, HEALTH_MASK)
    local healthAggro = CreateBorderSkin(healthShell)
    healthAggro:SetFrameLevel(healthGlow:GetFrameLevel() + 1)
    LayoutBorderSkin(healthAggro, healthShell, "aggro")
    healthAggro:SetAlpha(0)
    local healthEffects = CreateHealthEffectPresentation(healthShell, health)
    local damageEcho = CreateFrame("StatusBar", nil, healthShell)
    damageEcho:SetFrameLevel(health:GetFrameLevel())
    damageEcho:SetAllPoints(healthShell)
    damageEcho:SetStatusBarTexture(WHITE)
    damageEcho:SetMinMaxValues(0, 1)
    damageEcho:SetValue(0)
    damageEcho:SetStatusBarColor(.94, .20, .22, 1)
    local damageEchoMask = AttachMask(damageEcho:GetStatusBarTexture(), damageEcho, HEALTH_MASK)
    local echoFill = damageEcho:GetStatusBarTexture()
    if echoFill and echoFill.SetDrawLayer then pcall(echoFill.SetDrawLayer, echoFill, "ARTWORK", -1) end
    local healthEffectsSupported = type(CreateUnitHealPredictionCalculator) == "function"
        and type(UnitGetDetailedHealPrediction) == "function"
    local healthPredictionCalculator
    if healthEffectsSupported then
        local ok, calculator = pcall(CreateUnitHealPredictionCalculator)
        if ok and calculator then
            healthPredictionCalculator = calculator
            -- Match Blizzard's long-standing nameplate overflow allowance while
            -- still letting the calculator return the clamp boolean directly.
            if calculator.SetIncomingHealOverflowPercent then
                pcall(calculator.SetIncomingHealOverflowPercent, calculator, 1.05)
            end
        else
            healthEffectsSupported = false
        end
    end
    local nameLayer = CreateFrame("Frame", nil, root)
    nameLayer:SetAllPoints(healthShell)
    nameLayer:SetFrameLevel(health:GetFrameLevel() + 5)

    -- Keep Blizzard's FontString as the untouched native state/hit-test owner.
    -- A separate H3z0 FontString receives its resolved values through direct
    -- secret-safe widget data flow and can therefore use the designer position.
    local nativeName = plate.UnitFrame.name or plate.UnitFrame.Name or nativeHealth.unitNameFontString
    local name = nameLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    name:SetPoint("CENTER", healthShell, "CENTER", 0, 0)
    name:SetJustifyH("CENTER")
    name:SetJustifyV("MIDDLE")
    name:SetWordWrap(false)

    -- H3z0Nameplates-owned text elements. Each one has its own position and
    -- font size so the layout designer can move/scale them independently.
    local levelText = nameLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    levelText:SetPoint("CENTER", healthShell, "CENTER", 84, 0)
    levelText:SetJustifyH("CENTER")
    levelText:SetJustifyV("MIDDLE")
    levelText:SetWordWrap(false)

    local healthPercentText = nameLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    healthPercentText:SetPoint("CENTER", healthShell, "CENTER", -58, 0)
    healthPercentText:SetJustifyH("CENTER")
    healthPercentText:SetJustifyV("MIDDLE")
    healthPercentText:SetWordWrap(false)

    local healthValueText = nameLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    healthValueText:SetPoint("CENTER", healthShell, "CENTER", 58, 0)
    healthValueText:SetJustifyH("CENTER")
    healthValueText:SetJustifyV("MIDDLE")
    healthValueText:SetWordWrap(false)

    local comboPoints = ns.CreateNameplateComboPoints and ns.CreateNameplateComboPoints(root)
    if comboPoints then
        comboPoints:SetFrameLevel(health:GetFrameLevel() + 8)
        comboPoints:SetAlpha(0)
    end

    local castShell, castGlow, castOuter, cast, castBG, castMask = CreateMaskedBar(root, CAST_MASK)
    -- Keep the border above the regular fill and all three cast-colour bars.
    -- The colour bars remain StatusBars to accept protected timer values.
    castGlow:SetFrameLevel(cast:GetFrameLevel() + 4)
    local castAggro = CreateBorderSkin(castShell)
    castAggro:SetFrameLevel(cast:GetFrameLevel() + 7)
    LayoutBorderSkin(castAggro, castShell, "aggro")
    castAggro:SetAlpha(0)
    -- Blizzard remains the owner of the "casting at me" state. This separate
    -- H3z0 border only mirrors that resolved native state in our 3-slice style.
    local castTargetGlow = CreateBorderSkin(castShell)
    castTargetGlow:SetFrameLevel(cast:GetFrameLevel() + 8)
    LayoutBorderSkin(castTargetGlow, castShell, "aggro")
    castTargetGlow:SetAlpha(0)
    cast:SetValue(0)
    -- Three independent progress layers allow Blizzard's secret spell predicates
    -- and uninterruptible boolean to control opacity through widget sinks.
    local castColorLayers = {}
    for index, color in ipairs({{0.23, 0.85, 0.37}, {0.95, 0.22, 0.20}, {0.64, 0.60, 0.60}}) do
        local layer = CreateFrame("StatusBar", nil, castShell)
        layer:SetAllPoints(cast)
        layer:SetFrameLevel(cast:GetFrameLevel() + index)
        layer:SetStatusBarTexture(WHITE)
        layer:SetStatusBarColor(color[1], color[2], color[3], 1)
        layer:SetMinMaxValues(0, 1)
        layer:SetValue(0)
        local mask = layer:CreateMaskTexture(nil, "ARTWORK")
        mask:SetAllPoints(layer)
        mask:SetTexture(CAST_MASK)
        local art = layer:GetStatusBarTexture()
        if art then art:AddMaskTexture(mask) end
        layer:SetAlpha(0)
        castColorLayers[index] = layer
    end
    local castSpark = CreateCastProgressSpark(castShell, cast)
    castShell:Hide()
    local castTextLayer = CreateFrame("Frame", nil, castShell)
    castTextLayer:SetAllPoints(castShell)
    castTextLayer:SetFrameLevel(cast:GetFrameLevel() + 6)
    local castName = castTextLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    castName:SetPoint("LEFT", castTextLayer, "LEFT", 4, 0)
    castName:SetPoint("RIGHT", castTextLayer, "RIGHT", -4, 0)
    castName:SetPoint("TOP", castTextLayer, "TOP", 0, 0)
    castName:SetPoint("BOTTOM", castTextLayer, "BOTTOM", 0, 0)
    castName:SetJustifyH("CENTER")
    castName:SetJustifyV("MIDDLE")
    castName:SetWordWrap(false)

    -- Dedicated H3z0 target label. Blizzard's resolved native label remains
    -- the secure state/text/colour source, but no longer dictates placement.
    local castTargetName = castTextLayer:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    castTargetName:SetPoint("LEFT", castTextLayer, "CENTER", 8, 0)
    castTargetName:SetPoint("RIGHT", castTextLayer, "RIGHT", -5, 0)
    castTargetName:SetJustifyH("RIGHT")
    castTargetName:SetJustifyV("MIDDLE")
    castTargetName:SetWordWrap(false)
    castTargetName:Hide()

    local iconFrame, icon, iconBorder, iconMask = CreateStyledCastIconFrame(root)
    iconFrame:Hide()

    local shield = root:CreateTexture(nil, "OVERLAY")
    if shield.SetAtlas then
        local ok = pcall(shield.SetAtlas, shield, "nameplates-InterruptShield", true)
        if not ok then shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield") end
    else
        shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
    end
    shield:SetAlpha(0)

    local record = {
        unit=unit, plate=plate, unitFrame=plate.UnitFrame, nativeHealth=nativeHealth,
        nativeCast=GetNativeCast(plate.UnitFrame), nativeName=nativeName, root=root,
        healthShell=healthShell, healthGlow=healthGlow, healthAggro=healthAggro, healthOuter=healthOuter, health=health, healthBG=healthBG, healthMask=healthMask,
        healthEffects=healthEffects, healthEffectsSupported=healthEffectsSupported, healthPredictionCalculator=healthPredictionCalculator,
        damageEcho=damageEcho, damageEchoMask=damageEchoMask,
        nameLayer=nameLayer, name=name, levelText=levelText, healthPercentText=healthPercentText, healthValueText=healthValueText, comboPoints=comboPoints,
        castColorLayers=castColorLayers, castShell=castShell, castGlow=castGlow, castAggro=castAggro, castTargetGlow=castTargetGlow, castOuter=castOuter, cast=cast, castBG=castBG, castMask=castMask, castSpark=castSpark, castTextLayer=castTextLayer, castName=castName, castTargetName=castTargetName,
        iconFrame=iconFrame, icon=icon, iconBorder=iconBorder, iconMask=iconMask, shield=shield,
        castSerial=0,
    }
    records[plate] = record
    byUnit[unit] = record
    byUnitFrame[plate.UnitFrame] = record

    ns.AttachNativeParity(record)

    HookNativeHealthColor(record)
    HookNativeThreatFlash(record)
    HideNativeHighlightArt(record)
    return record
end

local DeactivateRecord

local function ConfigureRecord(record)
    if not record then return end
    local db = GetDB()
    local shouldSkin = db.enabled and ns.ShouldSkinNameplateUnit(record.unit, record.unitFrame)
    record.h3z0SkinActive = shouldSkin and true or false
    if not shouldSkin then
        DeactivateRecord(record)
        return
    end
    record.root:Show()
    record.plate.H3z0NameplatesHealthBar = record.health
    -- Scale the complete H3z0 presentation branch around the native plate
    -- centre. Layout coordinates remain authored at 100% and never drift.
    record.h3z0Friendly = IsFriendlyRecord(record)
    record.h3z0NpcNameOnly = record.h3z0Friendly and tonumber(db.friendlyNpcNameOnly) == 1
        and IsNpcRecord(record) or false
    -- Friendly plates may read their own bar and text sizes from here on.
    db = ns.GetNameplateRecordDB(record, db)
    ApplyTargetPresentation(record, db, true)

    record.healthShell:ClearAllPoints()
    record.healthShell:SetPoint("CENTER", record.root, "CENTER", db.healthX, db.healthY)
    ConfigureMaskedBar(record.healthShell, record.healthGlow, record.healthOuter, record.health, record.healthBG,
        db.healthWidth, db.healthHeight,
        db.healthR,db.healthG,db.healthB, db.healthBgR,db.healthBgG,db.healthBgB)
    ApplyEffectTexture(record.health, db.healthTexture, record.healthMask)
    LayoutBorderSkin(record.healthAggro, record.healthShell, "aggro")
    LayoutHealthEffects(record, db)
    ApplyHealthEffectAppearance(record, db)
    if record.comboPoints and ns.LayoutNameplateComboPoints then
        ns.LayoutNameplateComboPoints(record.comboPoints, record.healthShell, db)
    end
    -- Healthbar background: fixed black at 90% opacity.
    if record.healthBG and record.healthBG.SetVertexColor then
        pcall(record.healthBG.SetVertexColor, record.healthBG, 0, 0, 0, 0.9)
    end
    HookNativeHealthColor(record)
    ApplyHealthColor(record)
    if record.nameLayer then record.nameLayer:SetFrameLevel(record.health:GetFrameLevel() + 5) end

    if record.nativeName and record.name == record.nativeName and ns.LayoutNativeName then
        ns.LayoutNativeName(record)
    else
        record.name:ClearAllPoints()
        if record.h3z0NpcNameOnly then
            record.name:SetPoint("CENTER", record.healthShell, "CENTER", db.nameX,
                tonumber(db.friendlyNpcNameY) or 0)
        else
            record.name:SetPoint("CENTER", record.healthShell, "CENTER", db.nameX, db.nameY)
        end
    end
    SetFont(record.name, db.nameFontSize, db.nameOutline)

    record.levelText:ClearAllPoints()
    record.levelText:SetPoint("CENTER", record.healthShell, "CENTER", db.levelX, db.levelY)
    SetFont(record.levelText, db.levelFontSize, true)
    -- Visual skin only: keep Blizzard-owned level/skull/classification state.
    -- Difficulty color is mirrored later from Blizzard; H3z0 keeps the dark
    -- outline/shadow and the movable/scalable level presentation.
    if record.levelText and record.levelText.SetTextColor then pcall(record.levelText.SetTextColor, record.levelText, 1, 1, 1, 1) end
    if record.levelText and record.levelText.SetShadowColor then pcall(record.levelText.SetShadowColor, record.levelText, 0, 0, 0, 1) end
    if record.levelText and record.levelText.SetShadowOffset then pcall(record.levelText.SetShadowOffset, record.levelText, 1, -1) end

    record.healthPercentText:ClearAllPoints()
    record.healthPercentText:SetPoint("CENTER", record.healthShell, "CENTER", db.healthPercentX, db.healthPercentY)
    SetFont(record.healthPercentText, db.healthPercentFontSize, true)
    record.healthPercentText:SetAlpha(1)

    record.healthValueText:ClearAllPoints()
    record.healthValueText:SetPoint("CENTER", record.healthShell, "CENTER", db.healthValueX, db.healthValueY)
    SetFont(record.healthValueText, db.healthValueFontSize, true)
    record.healthValueText:SetAlpha(1)

    record.castShell:ClearAllPoints()
    record.castShell:SetPoint("CENTER", record.root, "CENTER", db.castX, db.castY)
    ConfigureMaskedBar(record.castShell, record.castGlow, record.castOuter, record.cast, record.castBG,
        db.castWidth, db.castHeight,
        db.harmfulR,db.harmfulG,db.harmfulB, db.castBgR,db.castBgG,db.castBgB)
    ApplyEffectTexture(record.cast, db.castTexture, record.castMask)
    LayoutBorderSkin(record.castAggro, record.castShell, "aggro")
    LayoutBorderSkin(record.castTargetGlow, record.castShell, "aggro")
    -- Red castbar glow is reserved for the immediate danger state where the
    -- current cast is aimed at the player. Selection remains health-only.
    for _,texture in ipairs({record.castTargetGlow.left,record.castTargetGlow.middle,record.castTargetGlow.right}) do
        if texture.SetDesaturated then pcall(texture.SetDesaturated,texture,false) end
        if texture.SetVertexColor then pcall(texture.SetVertexColor,texture,1,1,1,1) end
        if texture.SetBlendMode then pcall(texture.SetBlendMode,texture,"BLEND") end
    end
    for index, layer in ipairs(record.castColorLayers or {}) do
        layer:SetFrameLevel(record.cast:GetFrameLevel() + index)
        local colors = index == 1 and {db.helpfulR,db.helpfulG,db.helpfulB}
            or index == 2 and {db.harmfulR,db.harmfulG,db.harmfulB}
            or {db.shieldR,db.shieldG,db.shieldB}
        layer:SetStatusBarColor(colors[1],colors[2],colors[3],1)
    end
    if record.castGlow then record.castGlow:SetFrameLevel(record.cast:GetFrameLevel() + 4) end
    if record.castAggro then record.castAggro:SetFrameLevel(record.cast:GetFrameLevel() + 7) end
    if record.castTargetGlow then record.castTargetGlow:SetFrameLevel(record.cast:GetFrameLevel() + 8) end
    if record.castTextLayer then record.castTextLayer:SetFrameLevel(record.cast:GetFrameLevel() + 6) end
    LayoutCastProgressSpark(record.castSpark, db.castHeight)
    SetFont(record.castName, db.castFontSize, db.castOutline)
    SetFont(record.castTargetName, db.castFontSize, db.castOutline)
    record.castTargetName:SetTextColor(.75,.95,1,1)

    local styledIconSize = db.castHeight
    record.iconFrame:SetSize(styledIconSize, styledIconSize)
    LayoutStyledCastIconBorder(record.iconFrame, record.iconBorder, styledIconSize)
    record.iconFrame:ClearAllPoints()
    record.iconFrame:SetPoint("RIGHT", record.castShell, "LEFT", -(db.iconGap + CAST_ICON_EXTRA_GAP), 0)
    if not db.iconEnabled then record.iconFrame:Hide() end

    record.shield:SetSize(db.shieldSize, db.shieldSize)
    record.shield:ClearAllPoints()
    record.shield:SetPoint("LEFT", record.castShell, "RIGHT", db.shieldGap, 0)
    if not db.shieldEnabled then record.shield:SetAlpha(0) end

    ns.LayoutNativeParity(record)
    ns.LayoutNativeCastText(record)
    ns.SyncNativeVisibility(record)
    SyncAggroState(record)
end

local function UpdateHealth(record, sourceEvent)
    if not record or not record.unit or not record.h3z0SkinActive then return end
    HideNativeHealth(record)
    local db = GetDB()
    if not db.enabled then return end

    local okMax, maxHealth = pcall(UnitHealthMax, record.unit)
    local okHealth, health = pcall(UnitHealth, record.unit)
    if okMax and okHealth then
        -- Secret values are passed directly into our own StatusBar APIs; no Lua
        -- comparison or arithmetic is performed on them.
        pcall(record.health.SetMinMaxValues, record.health, 0, maxHealth)
        pcall(record.health.SetValue, record.health, health)
        if ns.UpdateDoesItDie then pcall(ns.UpdateDoesItDie, record, health, maxHealth) end
        UpdateDamageEcho(record, health, maxHealth, sourceEvent)
    end
    ApplyHealthColor(record)
    UpdateHealthEffects(record)
    ns.SyncNativeName(record)
    ns.SyncNativeLevel(record)


    if UnitHealthPercent then
        local curve = CurveConstants and CurveConstants.ScaleTo100 or nil
        local okPercent, healthPercent = pcall(UnitHealthPercent, record.unit, true, curve)
        if okPercent and HasValue(healthPercent) then
            -- SetFormattedText can consume secret numeric values in Midnight/Forever.
            pcall(record.healthPercentText.SetFormattedText, record.healthPercentText, "%.0f%%", healthPercent)
        else
            pcall(record.healthPercentText.SetText, record.healthPercentText, "")
        end
    else
        pcall(record.healthPercentText.SetText, record.healthPercentText, "")
    end

    do
        local displayHealth = health
        if AbbreviateNumbers then
            local okAbbrev, abbreviated = pcall(AbbreviateNumbers, health)
            if okAbbrev and HasValue(abbreviated) then displayHealth = abbreviated end
        end
        if HasValue(displayHealth) then
            pcall(record.healthValueText.SetText, record.healthValueText, displayHealth)
        else
            pcall(record.healthValueText.SetText, record.healthValueText, "")
        end
    end
end

if ns.RegisterDoesItDieCallback then
    ns.RegisterDoesItDieCallback(function(unit)
        local record = byUnit[unit]
        if not record or not record.h3z0SkinActive or not GetDB().enabled then return end
        local okHealth, health = pcall(UnitHealth, unit)
        local okMax, maxHealth = pcall(UnitHealthMax, unit)
        if okHealth and okMax then ns.UpdateDoesItDie(record, health, maxHealth) end
    end)
end

local function ApplyCastBooleanVisual(record, notInterruptible)
    local db = GetDB()
    local fill = record.cast:GetStatusBarTexture()
    local trueColor = CreateColor and CreateColor(db.shieldR,db.shieldG,db.shieldB,1) or nil
    local falseColor = CreateColor and CreateColor(db.harmfulR,db.harmfulG,db.harmfulB,1) or nil

    if IsSecret(notInterruptible) then
        if fill and fill.SetVertexColorFromBoolean and trueColor and falseColor then
            pcall(fill.SetVertexColorFromBoolean, fill, notInterruptible, trueColor, falseColor)
        else
            record.cast:SetStatusBarColor(db.harmfulR,db.harmfulG,db.harmfulB,1)
        end
        if db.shieldEnabled and record.shield.SetAlphaFromBoolean then
            pcall(record.shield.SetAlphaFromBoolean, record.shield, notInterruptible, 1, 0)
        else
            record.shield:SetAlpha(0)
        end
    else
        if notInterruptible then
            record.cast:SetStatusBarColor(db.shieldR,db.shieldG,db.shieldB,1)
            record.shield:SetAlpha(db.shieldEnabled and 1 or 0)
        else
            record.cast:SetStatusBarColor(db.harmfulR,db.harmfulG,db.harmfulB,1)
            record.shield:SetAlpha(0)
        end
    end
end

local function SetPredicateAlpha(region, value)
    if not region then return end
    if value == nil then region:SetAlpha(0); return end
    if IsSecret(value) then
        if region.SetAlphaFromBoolean then
            local ok = pcall(region.SetAlphaFromBoolean, region, value, 1, 0)
            if ok then return end
        end
        region:SetAlpha(0)
    else
        region:SetAlpha(value and 1 or 0)
    end
end

local function UpdateNameplateCastColors(record, spellID, notInterruptible)
    local layers = record.castColorLayers
    if not layers then return end
    for _, layer in ipairs(layers) do layer:SetAlpha(0) end
    if HasValue(spellID) and C_Spell then
        if type(C_Spell.IsSpellHelpful) == "function" then
            local ok, result = pcall(C_Spell.IsSpellHelpful, spellID)
            if ok then SetPredicateAlpha(layers[1], result) end
        end
        if type(C_Spell.IsSpellHarmful) == "function" then
            local ok, result = pcall(C_Spell.IsSpellHarmful, spellID)
            if ok then SetPredicateAlpha(layers[2], result) end
        end
    end
    -- This layer is above both classifications, so an uninterruptible cast
    -- always uses its existing shield colour, even with secret predicates.
    SetPredicateAlpha(layers[3], notInterruptible)
end

local function UpdateCast(record)
    if not record or not record.unit or not record.h3z0SkinActive then return end
    HideNativeCast(record)
    -- Preserve real kick feedback through the immediate STOP/FAILED sequence.
    if record.interruptedHold then return end
    record.cast:SetScript("OnUpdate", nil)
    if record.h3z0NpcNameOnly then
        ns.ApplyNpcNameOnly(record)
        return
    end
    local db = GetDB()
    if not db.enabled then
        record.castShell:Hide(); record.iconFrame:Hide(); record.shield:SetAlpha(0)
        return
    end

    local okCast, name, text, texture, startMS, endMS, tradeSkill, castID, notInterruptible, castSpellID
    okCast, name, text, texture, startMS, endMS, tradeSkill, castID, notInterruptible, castSpellID = pcall(UnitCastingInfo, record.unit)
    if not okCast then name = nil end
    local channel = false
    local spellID = castSpellID
    if not HasValue(name) then
        local okChannel
        okChannel, name, text, texture, startMS, endMS, tradeSkill, notInterruptible, spellID = pcall(UnitChannelInfo, record.unit)
        if not okChannel then name = nil end
        channel = HasValue(name)
    end

    if not HasValue(name) then
        record.cast:SetScript("OnUpdate", nil)
        record.castShell:Hide()
        record.iconFrame:Hide()
        record.shield:SetAlpha(0)
        if record.castSpark then record.castSpark:Hide() end
        return
    end

    local constants = NamePlateConstants or {}
    local castDisplayCVar = constants.CAST_BAR_DISPLAY_CVAR or "nameplateCastBarDisplay"
    local castEnums = Enum and Enum.NamePlateCastBarDisplay or nil
    local showSpellName, showSpellIcon = true, true
    if ns.GetNameplateBitfieldSetting and castEnums then
        showSpellName = ns.GetNameplateBitfieldSetting(castDisplayCVar, castEnums.SpellName, true)
        showSpellIcon = ns.GetNameplateBitfieldSetting(castDisplayCVar, castEnums.SpellIcon, true)
    end

    record.castShell:Show()
    if record.castSpark then record.castSpark:Show() end
    record.castName:SetShown(showSpellName)
    if db.iconEnabled and showSpellIcon then record.iconFrame:Show() else record.iconFrame:Hide() end
    if HasValue(texture) then pcall(record.icon.SetTexture, record.icon, texture) end
    if HasValue(text) then pcall(record.castName.SetText, record.castName, text)
    else pcall(record.castName.SetText, record.castName, name) end

    local duration
    if channel and UnitChannelDuration then
        local ok, value = pcall(UnitChannelDuration, record.unit)
        if ok then duration = value end
    elseif UnitCastingDuration then
        local ok, value = pcall(UnitCastingDuration, record.unit)
        if ok then duration = value end
    end

    local layers = record.castColorLayers or {}
    if HasValue(duration) and record.cast.SetTimerDuration then
        local interpolation = Enum and Enum.StatusBarInterpolation and Enum.StatusBarInterpolation.Immediate or 0
        local direction
        if channel then
            direction = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.RemainingTime or 1
        else
            direction = Enum and Enum.StatusBarTimerDirection and Enum.StatusBarTimerDirection.ElapsedTime or 0
        end
        pcall(record.cast.SetTimerDuration, record.cast, duration, interpolation, direction)
        for _, layer in ipairs(layers) do
            if layer.SetTimerDuration then
                pcall(layer.SetTimerDuration, layer, duration, interpolation, direction)
            end
        end
    elseif HasValue(startMS) and HasValue(endMS) then
        pcall(record.cast.SetMinMaxValues, record.cast, startMS, endMS)
        for _, layer in ipairs(layers) do
            pcall(layer.SetMinMaxValues, layer, startMS, endMS)
        end
        record.cast:SetScript("OnUpdate", function(self)
            local now = GetTime() * 1000
            pcall(self.SetValue, self, now)
            for _, layer in ipairs(layers) do pcall(layer.SetValue, layer, now) end
        end)
    end

    local interruptFlag = notInterruptible
    if not HasValue(interruptFlag) then interruptFlag = false end
    ApplyCastBooleanVisual(record, interruptFlag)
    UpdateNameplateCastColors(record, spellID, interruptFlag)
    ns.LayoutNativeCastText(record)
    ns.SyncNativeVisibility(record)
end

local function ClearInterrupted(record)
    if not record then return end
    if record.interruptedHold then
        record.interruptedHold = nil
        record.castSerial = (record.castSerial or 0) + 1
    end
end

local function FlashInterrupted(record)
    if not record then return end
    if record.h3z0NpcNameOnly then return end
    local db = GetDB()
    record.castSerial = (record.castSerial or 0) + 1
    local serial = record.castSerial
    record.interruptedHold = serial

    record.cast:SetScript("OnUpdate", nil)
    pcall(record.cast.SetMinMaxValues, record.cast, 0, 1)
    pcall(record.cast.SetValue, record.cast, 1)
    record.cast:SetStatusBarColor(db.interruptedR,db.interruptedG,db.interruptedB,1)
    for _, layer in ipairs(record.castColorLayers or {}) do layer:SetAlpha(0) end
    pcall(record.castName.SetText, record.castName, "Interrupted")
    record.castShell:Show()
    local constants = NamePlateConstants or {}
    local castEnums = Enum and Enum.NamePlateCastBarDisplay or nil
    local showSpellName, showSpellIcon = true, true
    if ns.GetNameplateBitfieldSetting and castEnums then
        showSpellName = ns.GetNameplateBitfieldSetting(
            constants.CAST_BAR_DISPLAY_CVAR or "nameplateCastBarDisplay",
            castEnums.SpellName, true)
        showSpellIcon = ns.GetNameplateBitfieldSetting(
            constants.CAST_BAR_DISPLAY_CVAR or "nameplateCastBarDisplay",
            castEnums.SpellIcon, true)
    end
    record.castName:SetShown(showSpellName)
    if db.iconEnabled and showSpellIcon then record.iconFrame:Show() else record.iconFrame:Hide() end
    if record.castSpark then record.castSpark:Hide() end
    record.shield:SetAlpha(0)

    if C_Timer and C_Timer.After then
        C_Timer.After(INTERRUPTED_HOLD_SECONDS, function()
            if record.interruptedHold == serial then
                record.interruptedHold = nil
                UpdateCast(record)
            end
        end)
    end
end

DeactivateRecord = function(record)
    if not record then return end

    -- Restore Blizzard visuals first while the current native references are valid.
    record.h3z0SkinActive = false
    targetGlide[record] = nil
    record.h3zScale, record.h3zAlpha = nil, nil
    if record.plate then record.plate.H3z0NameplatesHealthBar = nil end
    RestoreNative(record)

    -- Stop all H3z0 per-record runtime work immediately.
    if record.cast then pcall(record.cast.SetScript, record.cast, "OnUpdate", nil) end
    if record.healthEffects and record.healthEffects.threatFlashAnim then
        pcall(record.healthEffects.threatFlashAnim.Stop, record.healthEffects.threatFlashAnim)
    end
    ClearHealthEffects(record)
    ClearDamageEcho(record)
    record.interruptedHold = nil
    record.interruptedUntil = nil

    if record.comboPoints then record.comboPoints:SetAlpha(0) end
    if record.root then pcall(record.root.Hide, record.root) end

    -- Removing these mappings is important: global Blizzard hooks/event callbacks
    -- then miss this friendly frame on the first table lookup and return.
    local oldUnit = record.unit
    if oldUnit and byUnit[oldUnit] == record then byUnit[oldUnit] = nil end
    if record.unitFrame and byUnitFrame[record.unitFrame] == record then
        byUnitFrame[record.unitFrame] = nil
    end

    -- NativeParity keeps a weak/permanent hook record, but all those callbacks
    -- already require record.unit. Nil makes previously installed secure hooks inert.
    record.unit = nil
end

local function EnsureRecord(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return nil end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if not ok or not plate then return nil end
    local record = records[plate]
    -- TRUE friendly bypass: this check applies even if this pooled plate already
    -- had a H3z0 record earlier in the session. Existing friendly work is torn
    -- down immediately; new friendly plates never create H3z0 presentation.
    if not ns.ShouldSkinNameplateUnit(unit, plate.UnitFrame) then
        if record then DeactivateRecord(record) end
        return nil
    end
    if not record then record = CreateRecord(unit, plate) end
    if not record then return nil end
    if record.unit ~= unit then
        if record.unit then byUnit[record.unit] = nil end
        ClearDamageEcho(record)
    end
    record.unit = unit
    record.refreshCast = UpdateCast
    record.plate = plate

    -- Blizzard pools UnitFrame objects separately from the outer nameplate base.
    -- A persistent H3z0 presentation record therefore has to rebind its native
    -- state sources whenever this plate receives a different UnitFrame.
    local unitFrame = plate.UnitFrame
    local oldUnitFrame = record.unitFrame
    if oldUnitFrame ~= unitFrame then
        if oldUnitFrame and byUnitFrame[oldUnitFrame] == record then
            byUnitFrame[oldUnitFrame] = nil
        end
        record.unitFrame = unitFrame
        -- The outer plate and UnitFrame are pooled independently. Re-anchor our
        -- sibling presentation branch to the CURRENT Blizzard UnitFrame whenever
        -- the pool rebinds, otherwise a stale anchor can survive Friendly/Enemy
        -- visibility changes until /reload.
        if record.root and unitFrame then
            PlaceRoot(record, record.h3zScale)
            if record.root.SetFrameLevel and unitFrame.GetFrameLevel then
                local okLevel, baseLevel = pcall(unitFrame.GetFrameLevel, unitFrame)
                if okLevel and type(baseLevel) == "number" then
                    pcall(record.root.SetFrameLevel, record.root, baseLevel + 20)
                end
            end
        end
        record.nativeHealth = GetNativeHealth(unitFrame)
        record.nativeCast = GetNativeCast(unitFrame)
        record.nativeName = unitFrame and (unitFrame.name or unitFrame.Name)
            or (record.nativeHealth and record.nativeHealth.unitNameFontString)
        record.hookedHealthColor = nil
        record.hookedThreatFlashAnim = nil
        if ns.AttachNativeParity then ns.AttachNativeParity(record) end
    else
        record.nativeHealth = GetNativeHealth(unitFrame) or record.nativeHealth
        record.nativeCast = GetNativeCast(unitFrame) or record.nativeCast
        record.nativeName = (unitFrame and (unitFrame.name or unitFrame.Name))
            or (record.nativeHealth and record.nativeHealth.unitNameFontString)
            or record.nativeName
    end
    byUnitFrame[unitFrame] = record
    HookNativeHealthColor(record)
    HookNativeThreatFlash(record)
    byUnit[unit] = record
    ConfigureRecord(record)
    return record
end

-- Aura/parity modules need the H3z0-owned presentation branch rather than
-- parenting movable visuals to Blizzard's protected UnitFrame. Keep the
-- lookup read-only; EnsureNameplateDesignerRecord is only a sequencing helper
-- for NAME_PLATE_UNIT_ADDED when another module receives the event first.
function ns.GetNameplateDesignerRecordForUnitFrame(unitFrame)
    return unitFrame and byUnitFrame[unitFrame] or nil
end

function ns.EnsureNameplateDesignerRecord(unit)
    return EnsureRecord(unit)
end

function ns.RefreshNameplateDesigner(skipPreview)
    local db = GetDB()

    -- Snapshot first because ConfigureRecord/DeactivateRecord can remove friendly
    -- mappings while FRIENDLY SKIN is being switched OFF.
    local activeUnits = {}
    for unit, record in pairs(byUnit) do
        if record and record.unit == unit then activeUnits[#activeUnits + 1] = unit end
    end
    for _, unit in ipairs(activeUnits) do
        local record = byUnit[unit]
        if record then
            ConfigureRecord(record)
            if db.enabled and record.h3z0SkinActive then
                UpdateHealth(record)
                UpdateCast(record)
            end
        end
    end

    -- Switching the option back ON must immediately build H3z0 presentation for
    -- already-visible friendly plates; OFF mode simply early-outs in EnsureRecord.
    if C_NamePlate and C_NamePlate.GetNamePlates then
        local ok, plates = pcall(C_NamePlate.GetNamePlates)
        if ok and type(plates) == "table" then
            for _, plate in ipairs(plates) do
                local token = plate and plate.namePlateUnitToken
                if token and type(token) == "string" and not byUnit[token] then
                    local record = EnsureRecord(token)
                    if record and record.h3z0SkinActive then
                        UpdateHealth(record)
                        UpdateCast(record)
                    end
                end
            end
        end
    end

    RefreshTargetHighlights()
    if ns.UpdateNameplateComboPoints then ns.UpdateNameplateComboPoints(byUnit) end
    if not skipPreview and ns.RefreshNameplateDesignerPreview then
        ns.RefreshNameplateDesignerPreview()
    end
end

-- Re-sync immediately after Blizzard resolves nameplate health colours.
-- This is the authoritative path for hostile red / neutral yellow / friendly
-- colours and keeps H3z0Nameplates visually aligned with stock reaction logic.
if type(CompactUnitFrame_UpdateHealthColor) == "function" and hooksecurefunc then
    pcall(hooksecurefunc, "CompactUnitFrame_UpdateHealthColor", function(frame)
        local record = byUnitFrame[frame]
        if record and record.unit and GetDB().enabled and record.h3z0SkinActive then ApplyHealthColor(record) end
    end)
end

-- Blizzard updates names after events/CVars; mirror the final resolved output.
if type(CompactUnitFrame_UpdateName) == "function" and hooksecurefunc then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        local record = byUnitFrame[frame]
        if record and record.unit and record.h3z0SkinActive then
            ns.SyncNativeName(record)
            -- Health % / value follow Blizzard's final name/simplified visibility.
            ns.SyncNativeVisibility(record)
        end
    end)
end

-- Blizzard may show/update its own LevelFrame after our initial layout. Mirror
-- the final level state into H3z0's single LVL field and keep the native level
-- visuals alpha-hidden so they never create a duplicate indicator.
if type(CompactUnitFrame_UpdateLevel) == "function" and hooksecurefunc then
    hooksecurefunc("CompactUnitFrame_UpdateLevel", function(frame)
        local record = byUnitFrame[frame]
        if record and record.unit and record.h3z0SkinActive then
            ns.SkinNativeLevel(record)
            ns.SyncNativeLevel(record)
        end
    end)
end

-- PlayerLevelDiffFrame has its own Blizzard visibility/skull state and is the
-- authoritative level indicator on non-Classic nameplate styles. Mirror it only
-- after Blizzard has resolved that state; never call ShouldDisplay ourselves.
if type(CompactUnitFrame_UpdatePlayerLevelDiff) == "function" and hooksecurefunc then
    pcall(hooksecurefunc, "CompactUnitFrame_UpdatePlayerLevelDiff", function(frame)
        local record = byUnitFrame[frame]
        if record and record.unit and record.h3z0SkinActive then
            ns.SkinNativeLevel(record)
            ns.SyncNativeLevel(record)
        end
    end)
end

local castEvents = {
    UNIT_SPELLCAST_START=true, UNIT_SPELLCAST_STOP=true, UNIT_SPELLCAST_FAILED=true,
    UNIT_SPELLCAST_INTERRUPTED=true, UNIT_SPELLCAST_DELAYED=true,
    UNIT_SPELLCAST_CHANNEL_START=true, UNIT_SPELLCAST_CHANNEL_UPDATE=true,
    UNIT_SPELLCAST_CHANNEL_STOP=true, UNIT_SPELLCAST_INTERRUPTIBLE=true,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE=true,
}

pcall(eventFrame.RegisterEvent, eventFrame, "ADDON_LOADED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_ENTERING_WORLD")
pcall(eventFrame.RegisterEvent, eventFrame, "NAME_PLATE_UNIT_ADDED")
pcall(eventFrame.RegisterEvent, eventFrame, "NAME_PLATE_UNIT_REMOVED")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_HEALTH")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_MAXHEALTH")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_HEAL_PREDICTION")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_ABSORB_AMOUNT_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_HEAL_ABSORB_AMOUNT_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_NAME_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_LEVEL")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_FACTION")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_FLAGS")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_THREAT_SITUATION_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_THREAT_LIST_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_TARGET_CHANGED")
for _, event in ipairs({"PLAYER_COMBO_POINTS", "COMBO_TARGET_CHANGED"}) do
    pcall(eventFrame.RegisterEvent, eventFrame, event)
end
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_POWER_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_MAXPOWER")
pcall(eventFrame.RegisterEvent, eventFrame, "UPDATE_SHAPESHIFT_FORM")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_SPECIALIZATION_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "TRAIT_CONFIG_UPDATED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_TALENT_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "SPELLS_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_FOCUS_CHANGED")
pcall(eventFrame.RegisterEvent, eventFrame, "GROUP_ROSTER_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "UNIT_PET")
pcall(eventFrame.RegisterEvent, eventFrame, "CVAR_UPDATE")
pcall(eventFrame.RegisterEvent, eventFrame, "PLAYER_REGEN_ENABLED")
for event in pairs(castEvents) do pcall(eventFrame.RegisterEvent, eventFrame, event) end

-- Blizzard can apply a new Combo Point maximum after the initial spec/talent
-- notification. Reconcile existing nameplates once on the next frame and a
-- few times during the transition; no permanent OnUpdate/polling is required.
local comboRefreshGeneration = 0
local function RefreshComboAfterBuildChange()
    comboRefreshGeneration = comboRefreshGeneration + 1
    local generation = comboRefreshGeneration
    local function Refresh()
        if generation ~= comboRefreshGeneration then return end
        if ns.UpdateNameplateComboPoints then ns.UpdateNameplateComboPoints(byUnit) end
    end
    Refresh()
    if C_Timer and C_Timer.After then
        for _, delay in ipairs({0, 0.2, 0.7, 1.5}) do
            C_Timer.After(delay, Refresh)
        end
    end
end

eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "ADDON_LOADED" then
        if unit ~= ADDON_NAME then return end
        GetDB()
        return
    end
    if event == "PLAYER_ENTERING_WORLD" then
        if C_NamePlate and C_NamePlate.GetNamePlates then
            local ok, plates = pcall(C_NamePlate.GetNamePlates)
            if ok and type(plates) == "table" then
                for _, plate in ipairs(plates) do
                    local token = plate and plate.namePlateUnitToken
                    if token and type(token) == "string" then
                        local record = EnsureRecord(token)
                        if record then UpdateHealth(record); UpdateCast(record) end
                    end
                end
            end
        end
        if ns.UpdateNameplateComboPoints then ns.UpdateNameplateComboPoints(byUnit) end
        return
    end
    if event == "PLAYER_REGEN_ENABLED" then
        -- Complete native layout work that was postponed while the relevant
        -- Blizzard regions were combat-restricted.
        ns.RefreshNameplateDesigner(true)
        RefreshComboAfterBuildChange()
        return
    end
    if event == "CVAR_UPDATE" then
        -- Blizzard owns ALL nameplate visibility/category rules. Do not maintain
        -- a hand-picked list here: Friendly/Enemy/Minions/Minor/Pets/etc. must
        -- all resync H3z0 immediately when Blizzard changes a nameplate* CVar.
        local cvarName = type(unit) == "string" and unit or nil
        local isNameplateCVar = cvarName and cvarName:lower():find("nameplate", 1, true) == 1
        if isNameplateCVar then
            local function RefreshBlizzardOwnedSettings()
                -- EnsureRecord also repairs a pooled UnitFrame rebind before we
                -- mirror Blizzard's final resolved visibility/state.
                local activeUnits = {}
                for activeUnit, activeRecord in pairs(byUnit) do
                    if activeRecord and activeRecord.unit == activeUnit then
                        activeUnits[#activeUnits + 1] = activeUnit
                    end
                end
                for _, activeUnit in ipairs(activeUnits) do
                    local activeRecord = EnsureRecord(activeUnit) or byUnit[activeUnit]
                    if activeRecord and activeRecord.unit then
                        UpdateHealth(activeRecord)
                        UpdateCast(activeRecord)
                        QueueAggroSync(activeRecord)
                        ns.SyncNativeVisibility(activeRecord)
                    end
                end
                if ns.RebindAuraContainers then ns.RebindAuraContainers() end
                if ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
                if ns.RefreshNameplateDesignerPreview then ns.RefreshNameplateDesignerPreview() end
            end
            -- Blizzard's own CVar callbacks resolve first; read their final state
            -- on the next frame and then mirror it into H3z0 visuals.
            if C_Timer and C_Timer.After then C_Timer.After(0, RefreshBlizzardOwnedSettings)
            else RefreshBlizzardOwnedSettings() end
        end
        return
    end
    if event == "NAME_PLATE_UNIT_ADDED" then
        local record = EnsureRecord(unit)
        if record and record.h3z0SkinActive then UpdateHealth(record); UpdateCast(record); QueueAggroSync(record) end
        RefreshTargetHighlights()
        if ns.UpdateNameplateComboPoints then ns.UpdateNameplateComboPoints(byUnit) end
        -- Blizzard can finish pooled nameplate selection/deselection state after
        -- NAME_PLATE_UNIT_ADDED. Re-assert only our visual alpha choice next
        -- frame so a stale stock deselected overlay cannot flash underneath.
        if C_Timer and C_Timer.After then C_Timer.After(0, RefreshTargetHighlights) end
        return
    end
    if event == "PLAYER_TARGET_CHANGED" or event == "PLAYER_FOCUS_CHANGED" then
        if event == "PLAYER_TARGET_CHANGED" and ns.ResetNameplateComboTargetHistory then
            ns.ResetNameplateComboTargetHistory()
        end
        RefreshTargetHighlights()
        if ns.UpdateNameplateComboPoints then ns.UpdateNameplateComboPoints(byUnit) end
        -- Run once more after Blizzard's own target/focus visual refresh. This
        -- avoids event-order races where deselectedOverlay is shown again after
        -- H3z0 already hid it. No anchors or protected state are changed here.
        if C_Timer and C_Timer.After then C_Timer.After(0, RefreshTargetHighlights) end
        return
    end
    if event == "PLAYER_COMBO_POINTS" or event == "COMBO_TARGET_CHANGED" then
        if ns.UpdateNameplateComboPoints then ns.UpdateNameplateComboPoints(byUnit) end
        return
    end
    if event == "UNIT_POWER_UPDATE" or event == "UNIT_MAXPOWER" then
        if unit == "player" and ns.UpdateNameplateComboPoints then
            ns.UpdateNameplateComboPoints(byUnit)
        end
        return
    end
    if event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_SPECIALIZATION_CHANGED"
        or event == "TRAIT_CONFIG_UPDATED" or event == "PLAYER_TALENT_UPDATE"
        or event == "SPELLS_CHANGED" then
        RefreshComboAfterBuildChange()
        return
    end
    if event == "GROUP_ROSTER_UPDATE" then
        -- Immediately remove the solo-only H3z0 aggro overlay on joining a
        -- party/raid, or restore its state after returning to solo. Blizzard's
        -- native threat presentation remains untouched in both cases.
        for _, activeRecord in pairs(byUnit) do
            if activeRecord then QueueAggroSync(activeRecord) end
        end
        return
    end
    if event == "UNIT_PET" and unit == "player" then
        -- Pet summon/dismiss/replace must immediately enable or disable the
        -- solo H3z0 threat overlay without waiting for another threat event.
        for _, activeRecord in pairs(byUnit) do
            if activeRecord then QueueAggroSync(activeRecord) end
        end
        return
    end
    if event == "NAME_PLATE_UNIT_REMOVED" then
        local record = byUnit[unit]
        if record then
            byUnit[unit] = nil
            if record.unitFrame then byUnitFrame[record.unitFrame] = nil end
            record.cast:SetScript("OnUpdate", nil)
            if record.healthEffects and record.healthEffects.threatFlashAnim then
                pcall(record.healthEffects.threatFlashAnim.Stop, record.healthEffects.threatFlashAnim)
            end
            ClearHealthEffects(record)
            ClearDamageEcho(record)
            record.interruptedHold = nil
            record.interruptedUntil = nil
            record.unit = nil
            if record.plate then record.plate.H3z0NameplatesHealthBar = nil end
            record.root:Hide()
        end
        return
    end

    local record = byUnit[unit]
    if not record then return end
    if event == "UNIT_HEALTH" or event == "UNIT_MAXHEALTH" or event == "UNIT_NAME_UPDATE"
        or event == "UNIT_LEVEL" or event == "UNIT_FACTION" or event == "UNIT_FLAGS" then
        UpdateHealth(record, event)
        if event == "UNIT_FLAGS" and record.threatCombatGated then QueueAggroSync(record) end
    elseif event == "UNIT_HEAL_PREDICTION" or event == "UNIT_ABSORB_AMOUNT_CHANGED"
        or event == "UNIT_HEAL_ABSORB_AMOUNT_CHANGED" then
        UpdateHealthEffects(record)
    elseif event == "UNIT_THREAT_SITUATION_UPDATE" or event == "UNIT_THREAT_LIST_UPDATE" then
        QueueAggroSync(record)
        ApplyHealthColor(record)
    elseif event == "UNIT_SPELLCAST_INTERRUPTED" then
        FlashInterrupted(record)
    elseif castEvents[event] then
        if event == "UNIT_SPELLCAST_START" or event == "UNIT_SPELLCAST_CHANNEL_START" then
            ClearInterrupted(record)
        end
        record.castSerial = (record.castSerial or 0) + 1
        UpdateCast(record)
    end
end)
