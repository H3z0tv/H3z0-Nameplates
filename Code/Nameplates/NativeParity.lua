local _, ns = ...

-- Layout settings for one plate. Friendly plates can have their own sizes.
local function RecordDB(record)
    if ns.GetNameplateRecordDB then return ns.GetNameplateRecordDB(record) end
    return ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
end

-- Mirrors Blizzard-resolved nameplate state into H3z0 presentation.
-- Native regions remain available where required for Blizzard indicators.
local function Alpha(region, value)
    if region and region.SetAlpha then pcall(region.SetAlpha, region, value) end
end

local function SafeShown(region)
    if not region or type(region.IsShown) ~= "function" then return nil end
    local ok, shown = pcall(region.IsShown, region)
    if not ok then return nil end
    if issecretvalue and issecretvalue(shown) then return nil end
    return shown and true or false
end

-- IsShown() only reflects the region's own Show/Hide flag. Nameplate visibility
-- is often inherited from a Blizzard parent, so presentation gating must use the
-- effective visibility chain when mirroring whether H3z0 should render at all.
local function SafeVisible(region)
    if not region or type(region.IsVisible) ~= "function" then return nil end
    local ok, visible = pcall(region.IsVisible, region)
    if not ok then return nil end
    if issecretvalue and issecretvalue(visible) then return nil end
    return visible and true or false
end

local function HideChrome(owner, keys)
    if not owner then return end
    for _, key in ipairs(keys) do Alpha(owner[key], 0) end
end

function ns.SkinNativeHealth(record)
    local health = record and record.nativeHealth
    if not health then return end
    Alpha(health, 1)
    HideChrome(health, {"bgTexture", "BgTexture", "Background", "selectedBorder",
        "deselectedOverlay",
        "LeftText", "RightText", "Text", "TextString"})
    if health.GetStatusBarTexture then Alpha(health:GetStatusBarTexture(), 0) end

    -- Blizzard remains the calculator/state owner, but when the Midnight
    -- prediction calculator is available H3z0 draws the visible heal/absorb
    -- layers itself. Keep the native regions alive and updating at alpha 0 so
    -- no stock shield/glow art can leak through the custom healthbar.
    if record and record.healthEffectsSupported then
        HideChrome(health, {
            "myHealPrediction", "otherHealPrediction",
            "totalAbsorb", "totalAbsorbOverlay",
            "overAbsorbGlow", "overHealAbsorbGlow",
            "myHealAbsorb", "myHealAbsorbLeftShadow", "myHealAbsorbRightShadow",
        })
    end

    -- Threat progressive flare is intentionally NOT hidden here. Blizzard owns
    -- and renders that effect; only the one-shot aggro flash is H3z0-skinned.
end

function ns.SkinNativeCast(record)
    local cast = record and record.nativeCast
    if not cast then return end
    HideChrome(cast, {"Background", "background", "Bg", "Border", "border",
        "TextBorder", "textBorder", "DropShadow", "Icon", "icon", "IconTexture", "iconTexture",
        "BorderShield", "borderShield", "Shield", "Text", "text", "Spark",
        "Flash", "BarBorder"})
    if cast.GetStatusBarTexture then Alpha(cast:GetStatusBarTexture(), 0) end
    -- Do not touch cast/container alpha; Blizzard uses it for native fades.
end

local function Place(region, point, relative, relativePoint, x, y)
    if not region or not relative then return end
    pcall(region.ClearAllPoints, region)
    pcall(region.SetPoint, region, point, relative, relativePoint, x or 0, y or 0)
end

local function ApplyShownState(region, shown)
    if not region then return false end
    if region.SetAlphaFromBoolean then
        local ok = pcall(region.SetAlphaFromBoolean, region, shown, 1, 0)
        if ok then return true end
    end
    if not (issecretvalue and issecretvalue(shown)) then
        return pcall(region.SetAlpha, region, shown == true and 1 or 0)
    end
    return false
end

local function PublicValue(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return value
end

-- Copy only resolved rendering properties from a Blizzard texture. This does not
-- inspect unit data; it lets Blizzard choose the atlas/sprite and H3z0 reuse the
-- exact same built-in art on its own presentation frame.
local function CopyTextureVisual(source, target)
    if not source or not target then return false end
    local copied = false

    if source.GetAtlas and target.SetAtlas then
        local ok, atlas = pcall(source.GetAtlas, source)
        atlas = ok and PublicValue(atlas) or nil
        if type(atlas) == "string" and atlas ~= "" then
            copied = pcall(target.SetAtlas, target, atlas, false) and true or copied
        end
    end
    if not copied and source.GetTexture and target.SetTexture then
        local ok, texture = pcall(source.GetTexture, source)
        texture = ok and PublicValue(texture) or nil
        if texture ~= nil then copied = pcall(target.SetTexture, target, texture) and true or copied end
    end

    if source.GetTexCoord and target.SetTexCoord then
        local ok, l, r, t, b = pcall(source.GetTexCoord, source)
        if ok and PublicValue(l) ~= nil and PublicValue(r) ~= nil
            and PublicValue(t) ~= nil and PublicValue(b) ~= nil then
            pcall(target.SetTexCoord, target, l, r, t, b)
        end
    end
    if source.GetVertexColor and target.SetVertexColor then
        local ok, r, g, b, a = pcall(source.GetVertexColor, source)
        if ok and PublicValue(r) ~= nil and PublicValue(g) ~= nil and PublicValue(b) ~= nil then
            pcall(target.SetVertexColor, target, r, g, b, PublicValue(a) or 1)
        end
    end
    if source.IsDesaturated and target.SetDesaturated then
        local ok, value = pcall(source.IsDesaturated, source)
        value = ok and PublicValue(value) or nil
        if value ~= nil then pcall(target.SetDesaturated, target, value and true or false) end
    end
    return copied
end

function ns.SyncCastTargetIndicator(record)
    local cast = record and record.nativeCast
    local native = cast and cast.CastTargetIndicator
    local h3z0 = record and record.castTargetGlow
    if not native or not h3z0 then return end

    -- Keep Blizzard's native shown state intact, but hide its atlas and mirror
    -- that protected boolean directly into the H3z0 3-slice warning border.
    local ok, shown = pcall(native.IsShown, native)
    if ok and ApplyShownState(h3z0, shown) then
        Alpha(native, 0)
    else
        pcall(h3z0.SetAlpha, h3z0, 0)
        Alpha(native, 1)
    end
end

local function Font(region, size)
    if not region then return end
    local ok, font = pcall(region.GetFont, region)
    pcall(region.SetFont, region, (ok and font) or STANDARD_TEXT_FONT, size, "OUTLINE")
    if region.SetShadowOffset then pcall(region.SetShadowOffset, region, 0, 0) end
end

function ns.SyncNativeName(record)
    if not record or not record.unit or not record.name then return end

    local source = record.nativeName
        or (record.unitFrame and (record.unitFrame.name or record.unitFrame.Name))
        or (record.nativeHealth and record.nativeHealth.unitNameFontString)

    if source then
        -- Forward only into widget setters. Do not compare, concatenate, measure
        -- or wrap the resolved name in pcall: the value can be secret in Forever.
        -- If SetText cannot accept it, execution stops before native alpha is
        -- hidden, leaving Blizzard's original name visible as a safe fallback.
        record.nativeName = source
        Alpha(source, 1)
        local db = ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
        if db and not db.enabled then return end
        record.name:SetText(source:GetText())
        if source.GetVertexColor and record.name.SetVertexColor then
            record.name:SetVertexColor(source:GetVertexColor())
        end
        record.name:SetShown(source:IsShown())
        -- Keep Blizzard's region shown for its visibility and hit-test logic;
        -- suppress only duplicate rendering after the copy succeeded.
        Alpha(source, 0)
        return
    end

    -- Defensive fallback for an unexpected build with no native name FontString.
    local ok, text = pcall(UnitName, record.unit)
    if ok and not (issecretvalue and issecretvalue(text)) and text~=nil and text~="" then
        pcall(record.name.SetText, record.name, text)
        pcall(record.name.Show, record.name)
    else
        pcall(record.name.Hide, record.name)
    end
end

local function SafeBoolean(value)
    if value == nil then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    return value and true or false
end

local function NativeHealthTextAllowed(record)
    local health = record and record.nativeHealth
    if not health then return false end

    -- Use Blizzard's own read-only visibility predicate when available. It only
    -- evaluates already-resolved simplified/target/name shown state; it does not
    -- read health numbers or force any protected refresh. This keeps H3z0's
    -- optional Health % / value fields aligned with native nameplate rules.
    if type(health.ShouldTextBeShown) == "function" then
        local ok, shown = pcall(health.ShouldTextBeShown, health)
        if ok then
            shown = SafeBoolean(shown)
            if shown ~= nil then return shown end
        end
    end

    -- Conservative fallback for an unexpected Forever build.
    local simplified = SafeBoolean(health.isSimplified)
    local target = SafeBoolean(health.isTarget)
    if simplified == true and target ~= true then return false end

    local nativeName = record.nativeName
        or (record.unitFrame and (record.unitFrame.name or record.unitFrame.Name))
        or health.unitNameFontString
    local nameShown = SafeShown(nativeName)
    if nameShown == false then return false end
    return nameShown ~= nil
end

-- Text-only presentation for friendly NPCs: everything except the name is
-- hidden. Called after every visibility sync, so Blizzard showing its health
-- or cast state cannot bring the bars back.
function ns.ApplyNpcNameOnly(record)
    if not record or not record.h3z0NpcNameOnly then return end
    local parts = {
        record.healthShell, record.castShell, record.castName, record.iconFrame,
        record.castSpark, record.levelText, record.levelSkull,
        record.healthPercentText, record.healthValueText,
    }
    for _, part in pairs(parts) do
        if part and part.Hide then pcall(part.Hide, part) end
    end
    if record.shield and record.shield.SetAlpha then pcall(record.shield.SetAlpha, record.shield, 0) end
end

function ns.SyncNativeVisibility(record)
    if not record or not record.unit then return end

    -- The H3z0 presentation branch is a sibling of Blizzard's UnitFrame, so it
    -- does not automatically inherit UnitFrame Hide/Show. Mirror Blizzard's
    -- EFFECTIVE visibility here; this is what prevents hidden critter/minor or
    -- CVar-suppressed plates from resurfacing through H3z0.
    local unitFrameVisible = SafeVisible(record.unitFrame)
    if unitFrameVisible ~= nil and record.root then
        local db = ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
        local enabled = not db or db.enabled ~= false
        pcall(record.root.SetShown, record.root, enabled and unitFrameVisible or false)
        if not unitFrameVisible then return end
    end

    local healthShown = SafeVisible(record.nativeHealth)
    if healthShown ~= nil then
        pcall(record.healthShell.SetShown, record.healthShell, healthShown)
        local textAllowed = healthShown and NativeHealthTextAllowed(record)
        local showPercentage = record.nativeHealth and record.nativeHealth.showPercentage == true
        local showNumeric = record.nativeHealth and record.nativeHealth.showNumeric == true
        -- H3z0 "Modules" switches can force the texts on while a health bar is
        -- visible; otherwise the game's own nameplate text settings decide.
        local moduleDB = ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
        local forcePercent = healthShown and moduleDB and tonumber(moduleDB.hpPercentOn) == 1
        local forceValue = healthShown and moduleDB and tonumber(moduleDB.hpValueOn) == 1
        if record.healthPercentText then
            pcall(record.healthPercentText.SetShown, record.healthPercentText,
                (forcePercent or (textAllowed and showPercentage)) and true or false)
        end
        if record.healthValueText then
            pcall(record.healthValueText.SetShown, record.healthValueText,
                (forceValue or (textAllowed and showNumeric)) and true or false)
        end
    end

    -- Name is the native Blizzard FontString, so its own Show/Hide state remains
    -- Blizzard-owned (including simplified/name-only/widgets-only rules). The
    -- root gate above supplies the inherited parent visibility that IsShown lacks.
    ns.SyncNativeName(record)
    ns.SyncNativeLevel(record)

    local cast = record.nativeCast
    if cast and not record.interruptedHold then
        local shown = SafeVisible(cast)
        if shown ~= nil then
            pcall(record.castShell.SetShown, record.castShell, shown)
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
            pcall(record.castName.SetShown, record.castName, shown and showSpellName)
            pcall(record.iconFrame.SetShown, record.iconFrame, shown and showSpellIcon)
            -- Shield visibility is additionally driven by interruptibility in
            -- the H3z0 cast code; don't force it visible here.
            if not shown then pcall(record.shield.SetAlpha, record.shield, 0) end
        end
    end

    ns.ApplyNpcNameOnly(record)
end

function ns.SkinNativeLevel(record)
    if not record or not record.unitFrame then return end
    -- Preserve these as Blizzard state owners. Alpha hides only their duplicate
    -- visuals; Show/Hide remains intact so H3z0 can mirror the native state.
    Alpha(record.unitFrame.LevelFrame, 0)
    Alpha(record.unitFrame.PlayerLevelDiffFrame, 0)
end

local function NativeLevelShown(record)
    local uf = record and record.unitFrame
    if not uf then return false end
    return SafeShown(uf.PlayerLevelDiffFrame) == true or SafeShown(uf.LevelFrame) == true
end

local function NativeLevelSkullShown(record)
    local uf = record and record.unitFrame
    if not uf then return false end
    local playerDiff = uf.PlayerLevelDiffFrame
    local levelFrame = uf.LevelFrame
    if playerDiff and SafeShown(playerDiff.highLevelTexture or playerDiff.HighLevelTexture) == true then
        return true
    end
    if levelFrame and SafeShown(levelFrame.highLevelTexture or levelFrame.HighLevelTexture) == true then
        return true
    end
    return false
end

function ns.SyncNativeLevel(record)
    if not record or not record.unit or not record.levelText then return end
    ns.SkinNativeLevel(record)

    if not record.levelSkull then
        record.levelSkull = record.nameLayer:CreateTexture(nil, "OVERLAY")
        record.levelSkull:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-Skull")
        record.levelSkull:SetPoint("CENTER", record.levelText, "CENTER")
    end

    local db = RecordDB(record)
    pcall(record.levelSkull.SetSize, record.levelSkull, db.levelFontSize + 3, db.levelFontSize + 3)
    if record.h3z0NpcNameOnly then
        pcall(record.levelText.Hide, record.levelText)
        pcall(record.levelSkull.Hide, record.levelSkull)
        return
    end

    -- Mirror the actual Blizzard level display state. Alpha-hiding the native
    -- frames does not alter IsShown(), so Blizzard still decides when level or
    -- skull information belongs on this nameplate.
    local nativeShown = NativeLevelShown(record)
    if not nativeShown then
        pcall(record.levelText.Hide, record.levelText)
        pcall(record.levelSkull.Hide, record.levelSkull)
        return
    end

    if NativeLevelSkullShown(record) then
        pcall(record.levelText.Hide, record.levelText)
        pcall(record.levelSkull.Show, record.levelSkull)
        return
    end

    pcall(record.levelSkull.Hide, record.levelSkull)
    pcall(record.levelText.Show, record.levelText)

    local uf = record.unitFrame

    -- Parity-first level presentation: copy Blizzard's already-resolved level
    -- text/color instead of independently deciding difficulty whenever possible.
    -- PlayerLevelDiffFrame embeds Blizzard's exact difficulty color in the text
    -- (gray/yellow/orange/red etc.), while classic LevelFrame applies its resolved
    -- difficulty color as a vertex color. H3z0 only supplies position/font/outline.
    local playerDiff = uf and uf.PlayerLevelDiffFrame
    local playerDiffText = playerDiff and playerDiff.playerLevelDiffText
    if SafeShown(playerDiff) == true and playerDiffText and playerDiffText.GetText then
        local okText, resolvedText = pcall(playerDiffText.GetText, playerDiffText)
        if okText then
            pcall(record.levelText.SetTextColor, record.levelText, 1, 1, 1, 1)
            pcall(record.levelText.SetText, record.levelText, resolvedText)
            return
        end
    end

    local levelFrame = uf and uf.LevelFrame
    local nativeLevelText = levelFrame and (levelFrame.LevelText or levelFrame.levelText)
    if SafeShown(levelFrame) == true and nativeLevelText and nativeLevelText.GetText then
        local okText, resolvedText = pcall(nativeLevelText.GetText, nativeLevelText)
        if okText then
            pcall(record.levelText.SetText, record.levelText, resolvedText)

            -- CompactUnitFrame_UpdateLevel colors LevelText with SetVertexColor.
            -- Mirror that resolved color directly so Blizzard remains the state
            -- owner and H3z0 does not drift from future difficulty-rule changes.
            if nativeLevelText.GetVertexColor and record.levelText.SetVertexColor then
                local okColor, r, g, b, a = pcall(nativeLevelText.GetVertexColor, nativeLevelText)
                if okColor then
                    pcall(record.levelText.SetVertexColor, record.levelText, r, g, b, a or 1)
                    return
                end
            end
            return
        end
    end

    -- Compatibility fallback only for builds/styles where Blizzard's resolved
    -- FontString is unavailable. Use the same public Blizzard difficulty rule.
    local okLevel, level = pcall(UnitLevel, record.unit)
    if not okLevel then
        pcall(record.levelText.Hide, record.levelText)
        return
    end

    if issecretvalue and issecretvalue(level) then
        -- Passing the secret directly to the FontString is allowed; do not branch
        -- or perform arithmetic on it. Keep the neutral base color in this rare
        -- fallback path rather than inspecting a secret value.
        pcall(record.levelText.SetTextColor, record.levelText, 1, 1, 1, 1)
        pcall(record.levelText.SetText, record.levelText, level)
    elseif not level or level <= 0 then
        pcall(record.levelText.Hide, record.levelText)
        pcall(record.levelSkull.Show, record.levelSkull)
        return
    else
        pcall(record.levelText.SetText, record.levelText, level)
        local okAttack, canAttack = pcall(UnitCanAttack, "player", record.unit)
        local publicCanAttack
        if okAttack and not (issecretvalue and issecretvalue(canAttack)) then
            publicCanAttack = canAttack == true
        end
        if publicCanAttack == true and type(GetRelativeDifficultyColor) == "function" then
            local okPlayerLevel, playerLevel = pcall(UnitLevel, "player")
            if okPlayerLevel and (not issecretvalue or not issecretvalue(playerLevel)) then
                local okColor, color = pcall(GetRelativeDifficultyColor, playerLevel, level)
                if okColor and color then
                    pcall(record.levelText.SetTextColor, record.levelText, color.r, color.g, color.b, 1)
                end
            end
        elseif publicCanAttack == false and UNIT_LEVEL_NON_ATTACKABLE then
            pcall(record.levelText.SetTextColor, record.levelText, UNIT_LEVEL_NON_ATTACKABLE.r, UNIT_LEVEL_NON_ATTACKABLE.g, UNIT_LEVEL_NON_ATTACKABLE.b, 1)
        end
    end
end

-- H3z0-owned mirrors for native indicators that used to be moved directly.
-- Their state/icon selection is still entirely Blizzard-owned; only geometry and
-- rendering live on the custom presentation branch.
local RAID_TARGET_TEXTURE = "Interface\\TargetingFrame\\UI-RaidTargetingIcons"

local function EnsureRaidTargetPresentation(record)
    if not record or record.raidTargetFrame or not record.root then return end
    local frame = CreateFrame("Frame", nil, record.root)
    frame:SetSize(22, 22)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture(RAID_TARGET_TEXTURE)
    frame:Show()
    frame:SetAlpha(0)
    record.raidTargetFrame = frame
    record.raidTargetIcon = icon
end

local function LayoutRaidTargetPresentation(record)
    EnsureRaidTargetPresentation(record)
    local frame = record and record.raidTargetFrame
    if not frame or not record.healthShell then return end
    local db = RecordDB(record)
    if not db then return end
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", record.healthShell, "CENTER", db.raidTargetX or -112, db.raidTargetY or 0)
    frame:SetScale(db.raidTargetScale or 1)
    if frame.SetFrameLevel and record.nameLayer then
        pcall(frame.SetFrameLevel, frame, record.nameLayer:GetFrameLevel() + 3)
    end
end

local function ApplyRaidTargetIndex(icon, index)
    if not icon or type(index) == "nil" then return false end

    -- Forever can return a secret raid-target index in instances. Do not inspect,
    -- compare or convert that value. Blizzard's SetRaidTargetIconTexture is the
    -- approved sink: it accepts the resolved index and applies the correct cell.
    pcall(icon.SetTexture, icon, RAID_TARGET_TEXTURE)
    if type(SetRaidTargetIconTexture) == "function" then
        local ok = pcall(SetRaidTargetIconTexture, icon, index)
        if ok then return true end
    end

    -- Compatibility fallback for builds without the Blizzard sink. This branch
    -- is public-value only; secret values deliberately fall through to native.
    if issecretvalue and issecretvalue(index) then return false end
    if type(index) ~= "number" or index < 1 or index > 8 then return false end
    local cell = index - 1
    local left = (cell % 4) * 0.25
    local top = math.floor(cell / 4) * 0.25
    pcall(icon.SetTexCoord, icon, left, left + 0.25, top, top + 0.25)
    return true
end

local function SyncRaidTargetPresentation(record)
    LayoutRaidTargetPresentation(record)
    local native = record and record.unitFrame and record.unitFrame.RaidTargetFrame
    local frame = record and record.raidTargetFrame
    local icon = record and record.raidTargetIcon
    if not frame or not icon then return end

    -- Raid marker state comes straight from Blizzard. In instances the index may
    -- be secret, so only test its Lua type for nil/non-nil and pass the value
    -- untouched into Blizzard's texture sink. H3z0 owns only presentation.
    if record.unit and type(GetRaidTargetIndex) == "function" then
        local ok, index = pcall(GetRaidTargetIndex, record.unit)
        if ok then
            if type(index) == "nil" then
                pcall(frame.SetAlpha, frame, 0)
                if native then Alpha(native, 0) end
                return
            elseif ApplyRaidTargetIndex(icon, index) then
                pcall(frame.SetAlpha, frame, 1)
                if native then Alpha(native, 0) end
                return
            end
        end
    end

    -- Retain the native marker when its state cannot be forwarded.
    -- forwarded. Keep Blizzard's own marker visible rather than losing parity.
    pcall(frame.SetAlpha, frame, 0)
    if native then Alpha(native, 1) end
end

local function EnsureClassificationPresentation(record)
    if not record or record.classificationMirror or not record.root then return end
    local frame = CreateFrame("Frame", nil, record.root)
    frame:SetSize(20, 20)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(frame)
    frame:Show()
    frame:SetAlpha(0)
    record.classificationMirror = frame
    record.classificationMirrorIcon = icon
end

local function LayoutClassificationPresentation(record)
    EnsureClassificationPresentation(record)
    local frame = record and record.classificationMirror
    if not frame or not record.healthShell then return end
    local db = RecordDB(record)
    frame:ClearAllPoints()
    frame:SetPoint("CENTER", record.healthShell, "CENTER",
        db and db.classificationX or 111, db and db.classificationY or 0)
    frame:SetScale(db and db.classificationScale or 1)
    if frame.SetFrameLevel and record.nameLayer then
        pcall(frame.SetFrameLevel, frame, record.nameLayer:GetFrameLevel() + 2)
    end
end

local function SyncClassificationPresentation(record)
    LayoutClassificationPresentation(record)
    local native = record and record.unitFrame and record.unitFrame.ClassificationFrame
    local source = native and (native.classificationIndicator or native.ClassificationIndicator)
    local frame = record and record.classificationMirror
    local icon = record and record.classificationMirrorIcon
    if not native or not frame or not icon then return end

    if source and CopyTextureVisual(source, icon) then
        local ok, shown = pcall(native.IsShown, native)
        if ok and ApplyShownState(frame, shown) then
            Alpha(native, 0)
            return
        end
    end
    pcall(frame.SetAlpha, frame, 0)
    Alpha(native, 1)
end

local function EnsureSoftTargetPresentation(record)
    if not record or record.softTargetFrame or not record.root then return end
    local frame = CreateFrame("Frame", nil, record.root)
    frame:SetSize(24, 24)
    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture(RAID_TARGET_TEXTURE)
    frame:Show()
    frame:SetAlpha(0)
    record.softTargetFrame = frame
    record.softTargetIcon = icon
end

local function LayoutSoftTargetPresentation(record)
    EnsureSoftTargetPresentation(record)
    local frame = record and record.softTargetFrame
    if not frame or not record.healthShell then return end
    frame:ClearAllPoints()
    frame:SetPoint("BOTTOMLEFT", record.healthShell, "TOPRIGHT", 32, 4)
    if frame.SetFrameLevel and record.nameLayer then
        pcall(frame.SetFrameLevel, frame, record.nameLayer:GetFrameLevel() + 3)
    end
end

local function SyncSoftTargetPresentation(record)
    LayoutSoftTargetPresentation(record)
    local native = record and record.unitFrame and record.unitFrame.SoftTargetFrame
    local source = native and native.Icon
    local frame = record and record.softTargetFrame
    local icon = record and record.softTargetIcon
    if not native or not source or not frame or not icon then return end
    if CopyTextureVisual(source, icon) then
        local ok, shown = pcall(native.IsShown, native)
        if ok and ApplyShownState(frame, shown) then
            Alpha(native, 0)
            return
        end
    end
    pcall(frame.SetAlpha, frame, 0)
    Alpha(native, 1)
end


local function EnsureImportantCastPresentation(record)
    if not record or record.importantCastMirrorFrame or not record.castShell then return end
    local frame = CreateFrame("Frame", nil, record.castShell)
    frame:SetPoint("TOPLEFT", record.castShell, "TOPLEFT", -5, 3)
    frame:SetPoint("BOTTOMRIGHT", record.castShell, "BOTTOMRIGHT", 5, -3)
    frame:Show()
    frame:SetAlpha(0)

    local icon = frame:CreateTexture(nil, "OVERLAY", nil, 5)
    icon:SetAllPoints(frame)
    if icon.SetAtlas then pcall(icon.SetAtlas, icon, "ui-hud-nameplates-importantcast", false) end

    -- Blizzard's native XML pulses ImportantCastIndicator 0->1->0 over two
    -- seconds in a repeating animation. Create the same pulse on H3z0's copy;
    -- SyncImportantCastPresentation starts/stops it from Blizzard's resolved state.
    if icon.CreateAnimationGroup then
        local anim = icon:CreateAnimationGroup()
        if anim then
            local fadeIn = anim:CreateAnimation("Alpha")
            fadeIn:SetFromAlpha(0)
            fadeIn:SetToAlpha(1)
            fadeIn:SetDuration(1)
            fadeIn:SetOrder(1)
            local fadeOut = anim:CreateAnimation("Alpha")
            fadeOut:SetFromAlpha(1)
            fadeOut:SetToAlpha(0)
            fadeOut:SetDuration(1)
            fadeOut:SetOrder(2)
            anim:SetLooping("REPEAT")
            record.importantCastMirrorAnim = anim
        end
    end

    record.importantCastMirrorFrame = frame
    record.importantCastMirror = icon
end

local function LayoutImportantCastPresentation(record)
    EnsureImportantCastPresentation(record)
    local frame = record and record.importantCastMirrorFrame
    if not frame or not record.castShell then return end
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", record.castShell, "TOPLEFT", -5, 3)
    frame:SetPoint("BOTTOMRIGHT", record.castShell, "BOTTOMRIGHT", 5, -3)
end

local function SyncImportantCastPresentation(record)
    LayoutImportantCastPresentation(record)
    local nativeCast = record and record.nativeCast
    local native = nativeCast and nativeCast.ImportantCastIndicator
    local frame = record and record.importantCastMirrorFrame
    local mirror = record and record.importantCastMirror
    if not native or not frame or not mirror then return end

    if CopyTextureVisual(native, mirror) then
        local nativeAnim = nativeCast and nativeCast.ImportantCastFlashAnim
        local mirrorAnim = record.importantCastMirrorAnim
        if nativeAnim and mirrorAnim and nativeAnim.IsPlaying then
            local okPlaying, playing = pcall(nativeAnim.IsPlaying, nativeAnim)
            if okPlaying and not (issecretvalue and issecretvalue(playing)) then
                local mirrorPlaying = false
                if mirrorAnim.IsPlaying then
                    local okMirror, value = pcall(mirrorAnim.IsPlaying, mirrorAnim)
                    mirrorPlaying = okMirror and value and true or false
                end
                if playing and not mirrorPlaying then
                    if mirrorAnim.Restart then pcall(mirrorAnim.Restart, mirrorAnim)
                    else pcall(mirrorAnim.Play, mirrorAnim) end
                elseif not playing and mirrorPlaying then
                    pcall(mirrorAnim.Stop, mirrorAnim)
                    pcall(mirror.SetAlpha, mirror, 1)
                end
            end
        end
        local ok, shown = pcall(native.IsShown, native)
        if ok and ApplyShownState(frame, shown) then
            -- Keep Blizzard's state object alive but suppress duplicate rendering.
            Alpha(native, 0)
            return
        end
    end
    pcall(frame.SetAlpha, frame, 0)
    Alpha(native, 1)
end

function ns.RestoreNativeParityPresentation(record)
    if not record then return end
    local uf = record.unitFrame
    Alpha(uf and uf.RaidTargetFrame, 1)
    Alpha(uf and uf.ClassificationFrame, 1)
    Alpha(uf and uf.SoftTargetFrame, 1)
    local cast = record.nativeCast
    Alpha(cast and cast.ImportantCastIndicator, 1)
    Alpha(cast and cast.CastTargetIndicator, 1)
    Alpha(cast and cast.CastTargetNameText, 1)

    local function HideH3z0(region)
        if region and region.SetAlpha then pcall(region.SetAlpha, region, 0) end
    end
    HideH3z0(record.raidTargetFrame)
    HideH3z0(record.classificationMirror)
    HideH3z0(record.softTargetFrame)
    HideH3z0(record.importantCastMirrorFrame)
    HideH3z0(record.classificationFallback)
    HideH3z0(record.questFrame)
    if record.importantCastMirrorAnim then pcall(record.importantCastMirrorAnim.Stop, record.importantCastMirrorAnim) end
end

local QUEST_ICON_ATLAS = "QuestNormal"
local QUEST_ICON_FALLBACK = "Interface\\GossipFrame\\AvailableQuestIcon"
local trackedRecords = setmetatable({}, { __mode = "k" })

local function EnsureQuestIndicator(record)
    if not record or record.questFrame then return end
    local parent = record.root or record.nameLayer
    if not parent then return end

    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(22, 22)
    frame:SetFrameLevel((record.nameLayer and record.nameLayer:GetFrameLevel() or parent:GetFrameLevel()) + 4)

    local icon = frame:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(frame)
    local atlasApplied = false
    if icon.SetAtlas then
        atlasApplied = pcall(icon.SetAtlas, icon, QUEST_ICON_ATLAS, false)
    end
    if not atlasApplied then
        icon:SetTexture(QUEST_ICON_FALLBACK)
    end

    frame:Hide()
    record.questFrame = frame
    record.questIcon = icon
end

local function LayoutQuestIndicator(record)
    if not record then return end
    EnsureQuestIndicator(record)
    local frame = record.questFrame
    if not frame or not record.healthShell then return end
    local db = RecordDB(record)
    if not db then return end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", record.healthShell, "CENTER", db.questX or 110, db.questY or 25)
    -- Quest fallback is parented to record.root and inherits globalScale.
    frame:SetScale(db.questScale or 1)
end

function ns.SyncQuestIndicator(record)
    if not record then return end
    EnsureQuestIndicator(record)
    LayoutQuestIndicator(record)
    local frame = record.questFrame
    if not frame then return end

    -- Quest relation is owned by Blizzard. This is the same public semantic
    -- exposed by the unit tooltip as QuestObjective lines, without parsing
    -- tooltip text. Never infer quest membership from NPC names or GUIDs.
    local healthShown = SafeShown(record.nativeHealth)
    if healthShown == false or not record.unit then
        pcall(frame.Hide, frame)
        return
    end

    if not C_QuestLog or type(C_QuestLog.UnitIsRelatedToActiveQuest) ~= "function" then
        pcall(frame.Hide, frame)
        return
    end

    local ok, related = pcall(C_QuestLog.UnitIsRelatedToActiveQuest, record.unit)
    if not ok then
        pcall(frame.Hide, frame)
        return
    end

    if issecretvalue and issecretvalue(related) then
        -- Frame:SetShown is not a documented secret-safe sink. Keep the last
        -- resolved public state and wait for the next quest refresh instead of
        -- leaking a restricted boolean into addon-owned visibility state.
        return
    end
    pcall(frame.SetShown, frame, related and true or false)
end

local PVE_CLASSIFICATION_ATLAS = {
    elite = "nameplates-icon-elite-gold",
    worldboss = "nameplates-icon-elite-gold",
    rare = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star",
    rareelite = "nameplates-icon-elite-silver",
}

local function EnsureClassificationFallback(record)
    if not record or record.classificationFallback then return end
    local parent = record.root or record.nameLayer
    if not parent then return end
    local frame = CreateFrame("Frame", nil, parent)
    frame:SetSize(20, 20)
    local icon = frame:CreateTexture(nil, "OVERLAY")
    icon:SetAllPoints(frame)
    frame:Hide()
    record.classificationFallback = frame
    record.classificationFallbackIcon = icon
end

local function SyncClassificationFallback(record)
    EnsureClassificationFallback(record)
    local fallback = record and record.classificationFallback
    local icon = record and record.classificationFallbackIcon
    local native = record and record.unitFrame and record.unitFrame.ClassificationFrame
    if not fallback or not icon or not native or not record.unit then return end

    -- Mainline and any future Forever build that enables native PvE
    -- classification keep full ownership. This fallback only fills the explicit
    -- Camelot/Forever showClassificationIndicator=false gap.
    if native.showPvEClassificationIndicator ~= false then
        fallback:Hide()
        return
    end
    -- PvP/other native classification output still wins even when Forever disables
    -- only the PvE indicator. The H3z0 mirror above carries that native visual.
    if SafeShown(native) == true then
        fallback:Hide()
        return
    end

    local constants = NamePlateConstants or {}
    local infoEnums = Enum and Enum.NamePlateInfoDisplay or nil
    local showRarity = true
    if ns.GetNameplateBitfieldSetting and infoEnums then
        showRarity = ns.GetNameplateBitfieldSetting(
            constants.INFO_DISPLAY_CVAR or "nameplateInfoDisplay",
            infoEnums.RarityIcon, true)
    end
    if not showRarity or native.showOnlyName == true or native.widgetsOnly == true then
        fallback:Hide()
        return
    end

    local raidTargetIndex = native.raidTargetIndex
    if (issecretvalue and issecretvalue(raidTargetIndex)) or raidTargetIndex ~= nil then
        fallback:Hide()
        return
    end

    local ok, classification = pcall(UnitClassification, record.unit)
    if not ok or (issecretvalue and issecretvalue(classification)) then
        fallback:Hide()
        return
    end
    local atlas = PVE_CLASSIFICATION_ATLAS[classification]
    if not atlas then
        fallback:Hide()
        return
    end

    local atlasOK = icon.SetAtlas and pcall(icon.SetAtlas, icon, atlas, false)
    if not atlasOK then
        fallback:Hide()
        return
    end
    fallback:Show()
end

local function LayoutClassification(record)
    local uf = record and record.unitFrame
    local native = uf and uf.ClassificationFrame
    if not native then return end

    -- Do not move/scale Blizzard's ClassificationFrame. Mirror its already-resolved
    -- texture/state onto H3z0's own 20x20 presentation at the saved layout point.
    SyncClassificationPresentation(record)

    EnsureClassificationFallback(record)
    local fallback = record.classificationFallback
    local db = RecordDB(record)
    if fallback and record.healthShell then
        Place(fallback, "CENTER", record.healthShell, "CENTER",
            db and db.classificationX or 111, db and db.classificationY or 0)
        if fallback.SetScale then pcall(fallback.SetScale, fallback, db and db.classificationScale or 1) end
        if fallback.SetFrameLevel and record.nameLayer then
            pcall(fallback.SetFrameLevel, fallback, record.nameLayer:GetFrameLevel() + 2)
        end
    end
    SyncClassificationFallback(record)
end

function ns.LayoutNativeName(record)
    local name=record and record.nativeName
    if not name then return end
    -- Native anchors remain untouched. Rendering is owned by the movable H3z0
    -- FontString after SyncNativeName has transferred the resolved state.
    Alpha(name,0)
end

function ns.LayoutNativeParity(record)
    if not record or not record.unit or record.parityLayoutBusy then return end

    -- H3z0-owned presentation remains live in combat. These operations touch only
    -- our frames; Blizzard is still the state/icon source.
    LayoutClassification(record)
    LayoutQuestIndicator(record)
    ns.SyncQuestIndicator(record)
    SyncRaidTargetPresentation(record)
    SyncSoftTargetPresentation(record)
    SyncImportantCastPresentation(record)
    ns.SyncCastTargetIndicator(record)

    -- Only native geometry/state-carrier alignment is deferred. This keeps the
    -- combat guard narrow instead of freezing every H3z0 visual on new plates.
    if InCombatLockdown and InCombatLockdown() then
        record.parityLayoutPending = true
        ns.SyncNativeName(record)
        ns.SyncNativeLevel(record)
        return
    end
    record.parityLayoutPending = nil
    record.parityLayoutBusy = true
    local ok, err = pcall(function()
        local uf, health, cast = record.unitFrame, record.nativeHealth, record.nativeCast
        if not uf or not health then return end
        local db = RecordDB(record)
        local healthContainer = uf.HealthBarsContainer or health:GetParent()
        local castContainer = uf.CastBarsContainer or uf.CastBarContainer

        -- Move only Blizzard's top-level containers. The native healthbar, castbar
        -- and name keep the exact internal anchors created by ApplyFrameOptions.
        -- This is required because SetHitTestPoints references native name+health.
        if healthContainer then
            pcall(healthContainer.ClearAllPoints,healthContainer)
            pcall(healthContainer.SetPoint,healthContainer,"CENTER",uf,"CENTER",db.healthX,db.healthY)
            pcall(healthContainer.SetSize,healthContainer,db.healthWidth,db.healthHeight)
            -- Native prediction, absorb, deselection and threat layers live in
            -- this container. Scale it around the same centre as record.root so
            -- no stock-sized shadow remains behind a globally scaled H3z0 bar.
            if healthContainer.SetScale then
                pcall(healthContainer.SetScale,healthContainer,
                    ns.GetNameplateRecordScale and ns.GetNameplateRecordScale(record,db) or db.globalScale or 1)
            end
        end
        ns.SkinNativeHealth(record)

        ns.LayoutNativeName(record)

        -- Threat regions already inherit Blizzard anchors from the native
        -- HealthBarsContainer. Do not rewrite their protected anchor family.

        ns.SkinNativeLevel(record)
        -- Classification / quest / raid-target / soft-target presentation is owned
        -- by H3z0 frames above. Their Blizzard originals are state sources only.
        -- Behind-camera and widget regions already follow Blizzard's castbar
        -- anchors, so moving the cast container moves them safely as well.

        if cast and castContainer then
            pcall(castContainer.ClearAllPoints,castContainer)
            pcall(castContainer.SetPoint,castContainer,"CENTER",uf,"CENTER",db.castX,db.castY)
            pcall(castContainer.SetSize,castContainer,db.castWidth,db.castHeight)
            -- Important-cast, cast-target, widget and behind-camera output must
            -- use the same live-only global scale as the custom castbar.
            if castContainer.SetScale then
                pcall(castContainer.SetScale,castContainer,
                    ns.GetNameplateRecordScale and ns.GetNameplateRecordScale(record,db) or db.globalScale or 1)
            end
            SyncImportantCastPresentation(record)
            -- CastTargetIndicator and CastTargetNameText stay at Blizzard geometry;
            -- H3z0 mirrors their resolved state/text into its own castbar visuals.
            ns.SyncCastTargetIndicator(record)
            ns.SkinNativeCast(record)
        end

        ns.SyncNativeName(record)
        ns.SyncNativeLevel(record)
    end)
    record.parityLayoutBusy = nil
    if not ok then error(err) end
end

function ns.LayoutNativeCastText(record)
    local native = record and record.nativeCast
    local target = native and native.CastTargetNameText
    if not record or not record.castName or not record.castTargetName then return end

    -- Forever restores the stock target label above the bar after every target
    -- update. Mirror Blizzard's resolved widget data into a H3z0 FontString
    -- inside our castbar, using the same secret-safe widget-to-widget flow as
    -- unit names. Blizzard remains the state and visibility owner.
    if target then
        local db=RecordDB(record)
        Font(record.castTargetName,db and db.castFontSize or 11)
        Alpha(target,1)
        record.castTargetName:SetText(target:GetText())
        if target.GetVertexColor and record.castTargetName.SetVertexColor then
            -- Preserve Blizzard's resolved class/reaction/name colour rules.
            record.castTargetName:SetVertexColor(target:GetVertexColor())
        end
        record.castTargetName:SetShown(target:IsShown())
        Alpha(target,0)
    else
        record.castTargetName:Hide()
    end

    local shown = target and SafeShown(target)
    local text
    if target and target.GetText then
        local ok, value = pcall(target.GetText, target)
        if ok then text = value end
    end

    -- Never concatenate or measure secret target names. Reserve a fixed area if
    -- Blizzard says its target label is shown.
    local hasTarget = shown == true
    if shown == nil and target then hasTarget = true end
    if shown == true and not (issecretvalue and issecretvalue(text)) and (text == nil or text == "") then
        hasTarget = false
    end

    record.castName:ClearAllPoints()
    record.castName:SetPoint("LEFT", record.castTextLayer, "LEFT", 4, 0)
    record.castName:SetPoint("RIGHT", record.castTextLayer, hasTarget and "CENTER" or "RIGHT", -4, 0)
    record.castName:SetJustifyH(hasTarget and "LEFT" or "CENTER")
    record.castTargetName:ClearAllPoints()
    record.castTargetName:SetPoint("LEFT",record.castTextLayer,"CENTER",8,0)
    record.castTargetName:SetPoint("RIGHT",record.castTextLayer,"RIGHT",-5,0)
    record.castTargetName:SetJustifyH("RIGHT")
end

function ns.AttachNativeParity(record)
    if not record or not record.unitFrame then return end
    -- The outer nameplate and its UnitFrame are pooled independently. Attach once
    -- per current UnitFrame, and make old hooks inert if Blizzard later rebinds
    -- this H3z0 presentation record to a different native UnitFrame.
    if record.parityAttachedUnitFrame == record.unitFrame then return end
    record.parityAttachedUnitFrame = record.unitFrame
    local attachedUnitFrame = record.unitFrame
    trackedRecords[record] = true
    EnsureQuestIndicator(record)
    LayoutQuestIndicator(record)
    ns.SyncQuestIndicator(record)
    EnsureRaidTargetPresentation(record)
    EnsureClassificationPresentation(record)
    EnsureSoftTargetPresentation(record)
    EnsureImportantCastPresentation(record)
    SyncRaidTargetPresentation(record)
    SyncClassificationPresentation(record)
    SyncSoftTargetPresentation(record)
    SyncImportantCastPresentation(record)
    ns.SyncCastTargetIndicator(record)

    local function Active(callback)
        return function()
            if record.unit and record.unitFrame == attachedUnitFrame
                and (not ns.ShouldSkinNameplateUnit
                    or ns.ShouldSkinNameplateUnit(record.unit, attachedUnitFrame)) then
                callback(record)
            end
        end
    end

    local function Hook(owner, method, callback)
        if owner and type(owner[method]) == "function" and hooksecurefunc then
            pcall(hooksecurefunc, owner, method, Active(callback))
        end
    end

    local function SyncResolvedState(r)
        ns.SyncNativeVisibility(r)
        ns.LayoutNativeParity(r)
        ns.SyncQuestIndicator(r)
        if ns.SyncNameplateAuraState then ns.SyncNameplateAuraState(r.unitFrame) end
    end

    Hook(record.unitFrame, "UpdateAnchors", ns.LayoutNativeParity)
    Hook(record.unitFrame, "UpdateWidgetsOnlyMode", SyncResolvedState)
    Hook(record.unitFrame, "UpdateShowOnlyName", SyncResolvedState)
    Hook(record.unitFrame, "UpdateIsSimplified", SyncResolvedState)
    Hook(record.unitFrame, "UpdateIsPlayer", SyncResolvedState)
    Hook(record.unitFrame, "UpdateIsFriend", SyncResolvedState)
    Hook(record.unitFrame, "UpdateIsTarget", SyncResolvedState)
    Hook(record.unitFrame, "Show", ns.SyncNativeVisibility)
    Hook(record.unitFrame, "Hide", ns.SyncNativeVisibility)
    Hook(record.unitFrame, "SetShown", ns.SyncNativeVisibility)
    Hook(record.unitFrame, "UpdateRaidTarget", function(r)
        SyncRaidTargetPresentation(r)
        LayoutClassification(r)
    end)

    Hook(record.nativeHealth, "UpdateShownState", ns.SyncNativeVisibility)
    Hook(record.nativeHealth, "UpdateTextDisplay", ns.SyncNativeVisibility)
    Hook(record.nativeHealth, "Show", ns.SyncNativeVisibility)
    Hook(record.nativeHealth, "Hide", ns.SyncNativeVisibility)
    Hook(record.nativeHealth, "SetShown", ns.SyncNativeVisibility)

    local nativeName = record.nativeName or (record.unitFrame and (record.unitFrame.name or record.unitFrame.Name))
    Hook(nativeName, "SetText", ns.SyncNativeName)
    Hook(nativeName, "SetVertexColor", ns.SyncNativeName)
    Hook(nativeName, "SetTextColor", ns.SyncNativeName)
    Hook(nativeName, "Show", ns.SyncNativeName)
    Hook(nativeName, "Hide", ns.SyncNativeName)

    local classification = record.unitFrame and record.unitFrame.ClassificationFrame
    Hook(classification, "UpdateShownState", function(r)
        LayoutClassification(r)
    end)
    Hook(classification, "UpdateClassificationIndicator", function(r)
        -- Re-apply H3z0's mirror/fallback after Blizzard resolves classification.
        LayoutClassification(r)
    end)
    local classificationIcon = classification and (classification.classificationIndicator or classification.ClassificationIndicator)
    Hook(classificationIcon, "SetAtlas", SyncClassificationPresentation)
    Hook(classificationIcon, "SetTexture", SyncClassificationPresentation)
    Hook(classificationIcon, "SetTexCoord", SyncClassificationPresentation)
    Hook(classificationIcon, "SetSpriteSheetCell", SyncClassificationPresentation)
    Hook(classificationIcon, "Show", SyncClassificationPresentation)
    Hook(classificationIcon, "Hide", SyncClassificationPresentation)

    local raidTarget = record.unitFrame and record.unitFrame.RaidTargetFrame
    local raidIcon = raidTarget and raidTarget.RaidTargetIcon
    Hook(raidTarget, "Show", SyncRaidTargetPresentation)
    Hook(raidTarget, "Hide", SyncRaidTargetPresentation)
    Hook(raidTarget, "SetShown", SyncRaidTargetPresentation)
    Hook(raidIcon, "SetAtlas", SyncRaidTargetPresentation)
    Hook(raidIcon, "SetTexture", SyncRaidTargetPresentation)
    Hook(raidIcon, "SetTexCoord", SyncRaidTargetPresentation)
    Hook(raidIcon, "SetSpriteSheetCell", SyncRaidTargetPresentation)

    local softTarget = record.unitFrame and record.unitFrame.SoftTargetFrame
    local softIcon = softTarget and softTarget.Icon
    Hook(softTarget, "Show", SyncSoftTargetPresentation)
    Hook(softTarget, "Hide", SyncSoftTargetPresentation)
    Hook(softTarget, "SetShown", SyncSoftTargetPresentation)
    Hook(softIcon, "SetAtlas", SyncSoftTargetPresentation)
    Hook(softIcon, "SetTexture", SyncSoftTargetPresentation)
    Hook(softIcon, "SetTexCoord", SyncSoftTargetPresentation)
    Hook(softIcon, "SetSpriteSheetCell", SyncSoftTargetPresentation)

    Hook(record.nativeCast, "ApplyStyleAndAnchoring", function(r)
        ns.SkinNativeCast(r)
        SyncImportantCastPresentation(r)
    end)
    Hook(record.nativeCast, "ApplyAlpha", function(r)
        ns.SkinNativeCast(r)
        SyncImportantCastPresentation(r)
    end)
    local importantCast = record.nativeCast and record.nativeCast.ImportantCastIndicator
    Hook(importantCast, "Show", SyncImportantCastPresentation)
    Hook(importantCast, "Hide", SyncImportantCastPresentation)
    Hook(importantCast, "SetShown", SyncImportantCastPresentation)
    Hook(importantCast, "SetAtlas", SyncImportantCastPresentation)
    Hook(importantCast, "SetTexture", SyncImportantCastPresentation)
    local importantCastAnim = record.nativeCast and record.nativeCast.ImportantCastFlashAnim
    Hook(importantCastAnim, "Play", function(r)
        local anim = r.importantCastMirrorAnim
        if anim then
            if anim.Restart then pcall(anim.Restart, anim) else pcall(anim.Play, anim) end
        end
        SyncImportantCastPresentation(r)
    end)
    Hook(importantCastAnim, "Restart", function(r)
        local anim = r.importantCastMirrorAnim
        if anim and anim.Restart then pcall(anim.Restart, anim) end
        SyncImportantCastPresentation(r)
    end)
    Hook(importantCastAnim, "Stop", function(r)
        local anim = r.importantCastMirrorAnim
        if anim then pcall(anim.Stop, anim) end
        if r.importantCastMirror then pcall(r.importantCastMirror.SetAlpha, r.importantCastMirror, 1) end
        SyncImportantCastPresentation(r)
    end)
    Hook(record.nativeCast, "SetNameTextShown", function(r)
        if r.refreshCast then r.refreshCast(r) end
    end)
    Hook(record.nativeCast, "SetIconShown", function(r)
        if r.refreshCast then r.refreshCast(r) end
    end)
    Hook(record.nativeCast, "UpdateShownState", function(r)
        if r.refreshCast then r.refreshCast(r) end
    end)
    Hook(record.nativeCast, "SetTargetNameText", ns.LayoutNativeCastText)
    Hook(record.nativeCast, "SetTargetNameTextShown", ns.LayoutNativeCastText)
    local castTargetIndicator = record.nativeCast and record.nativeCast.CastTargetIndicator
    Hook(castTargetIndicator, "Show", ns.SyncCastTargetIndicator)
    Hook(castTargetIndicator, "Hide", ns.SyncCastTargetIndicator)
    Hook(castTargetIndicator, "SetShown", ns.SyncCastTargetIndicator)
end

-- Quest objective parity -----------------------------------------------------
-- Refresh only our own quest icon when Blizzard's quest state changes. The
-- unit relation itself is queried from C_QuestLog; no tooltip text scanning,
-- quest-log objective matching, or protected native nameplate mutation occurs.
local questEvents = CreateFrame("Frame")
for _, eventName in ipairs({
    "QUEST_LOG_UPDATE",
    "QUEST_WATCH_UPDATE",
    "QUEST_LOG_CRITERIA_UPDATE",
    "QUEST_ACCEPTED",
    "QUEST_REMOVED",
    "QUEST_TURNED_IN",
    "QUEST_POI_UPDATE",
    "TASK_PROGRESS_UPDATE",
}) do
    pcall(questEvents.RegisterEvent, questEvents, eventName)
end
questEvents:SetScript("OnEvent", function()
    for record in pairs(trackedRecords) do
        if record and record.unit and record.h3z0SkinActive then ns.SyncQuestIndicator(record) end
    end
end)

-- Raid target markers can change without a plate being rebound. Refresh every
-- active H3z0 marker directly from Blizzard's raid-target state.
local raidTargetEvents = CreateFrame("Frame")
pcall(raidTargetEvents.RegisterEvent, raidTargetEvents, "RAID_TARGET_UPDATE")
raidTargetEvents:SetScript("OnEvent", function()
    for record in pairs(trackedRecords) do
        if record and record.unit and record.h3z0SkinActive then
            SyncRaidTargetPresentation(record)
            LayoutClassification(record)
        end
    end
end)
