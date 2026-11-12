local _, ns = ...

-- H3z0Nameplates owns its visible Buff / Debuff / CC containers.
-- Do not hook, restyle, measure, or refresh Blizzard's pooled aura frames.
-- Calling their RefreshAuras from addon code taints native priority tables.
-- The custom AuraContainers live under H3z0's presentation branch (the outer
-- nameplate), never under Blizzard's protected UnitFrame. This keeps placement
-- and visibility mutable when a new/recycled nameplate appears during combat.
-- Blizzard still owns aura data through CustomAuraContainerTemplate. H3z0 only
-- supplies the presentation branch and fixed internal rules that mirror the
-- native nameplate lists; there are no H3z0 aura-source/filter choices.

local setsByUnitFrame = setmetatable({}, { __mode = "k" })
-- Aura containers are parented to H3z0's persistent outer-nameplate record, not
-- to Blizzard's pooled UnitFrame. Keep a second weak map so a record can retain
-- and reuse its presentation even if Blizzard gives the plate a different UnitFrame.
local setsByRecord = setmetatable({}, { __mode = "k" })
local boundByUnit = {}
local eventFrame = CreateFrame("Frame")

local BASE_AURA = 32
local AURA_GAP = 4
-- Nameplate visual caps: 2 buffs, 12 debuffs and 2 crowd-control icons.
local MAX_AURA = 2
local MAX_DEBUFF = 12
local BASE_CC = 35
local CC_GAP = 2
local MAX_CC = 2
local DURATION_FONT_SCALE = 2

ns.NAMEPLATE_AURA_ICON_SIZE = BASE_AURA
ns.NAMEPLATE_AURA_ICON_GAP = AURA_GAP
ns.NAMEPLATE_CC_ICON_SIZE = BASE_CC
ns.NAMEPLATE_CC_ICON_GAP = CC_GAP
ns.NAMEPLATE_AURA_DURATION_FONT_SCALE = DURATION_FONT_SCALE

local function StyleDurationFontString(fontString, scale)
    if not fontString or not fontString.GetFont or not fontString.SetFont then return end
    local font, fontSize = fontString:GetFont()
    fontSize = tonumber(fontSize)
    if font and fontSize then
        -- WoW renders OUTLINE in black; the text itself uses H3z0 gold.
        fontString:SetFont(font, fontSize * (tonumber(scale) or 1), "OUTLINE")
    end
    fontString:SetTextColor(1, 0.82, 0, 1)
end

local function IsNameplateToken(unit)
    return type(unit) == "string" and unit:match("^nameplate%d+$") ~= nil
end

local function IsSupportedUnit(unit)
    -- Do not ask UnitIsUnit(nameplate#, "player") here. That comparison may be
    -- secret in combat. Personal-nameplate exclusion is done by comparing the
    -- actual nameplate frame object against C_NamePlate.GetNamePlateForUnit("player").
    return IsNameplateToken(unit)
end

local function IsPersonalPlayerPlate(plate)
    if not plate or not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then return false end
    local ok, playerPlate = pcall(C_NamePlate.GetNamePlateForUnit, "player")
    return ok and playerPlate ~= nil and playerPlate == plate
end

local function IsUsableFrame(frame)
    if not frame then return false end
    if frame.IsForbidden then
        local ok, forbidden = pcall(frame.IsForbidden, frame)
        if not ok or forbidden then return false end
    end
    return true
end

local function GetHealthBar(unitFrame)
    local container = unitFrame and unitFrame.HealthBarsContainer
    return container and container.healthBar or nil
end

local function LoadAuraContainerAPI()
    if C_AddOns and C_AddOns.LoadAddOn then
        pcall(C_AddOns.LoadAddOn, "Blizzard_AuraContainer")
    elseif UIParentLoadAddOn then
        pcall(UIParentLoadAddOn, "Blizzard_AuraContainer")
    end
    return AuraUtil and AuraUtil.CreateFilterString and AuraUtil.AuraFilters and true or false
end

local function FlowDir(key)
    local flow = AnchorUtil and AnchorUtil.FlowDirection
    return flow and flow[key] or nil
end

local function SetContainerFlow(container, kind, iconSize, gap, maxCount)
    if not container then return end

    -- Buffs are mirrored: their stable origin is the RIGHT edge and new icons
    -- grow LEFT. Debuffs/CC keep LEFT origin and grow RIGHT. Preview uses the
    -- same origin rule, so saved X/Y means the same visible point live.
    local anchorPoint = kind == "buff" and "RIGHT" or "LEFT"
    if container.SetFlowLayoutAnchorPoint then
        pcall(container.SetFlowLayoutAnchorPoint, container, anchorPoint)
    elseif container.SetAuraLayoutAnchorPoint then
        pcall(container.SetAuraLayoutAnchorPoint, container, anchorPoint)
    end

    local horizontal = kind == "buff" and FlowDir("Left") or FlowDir("Right")
    local up = FlowDir("Up")
    if horizontal and up then
        if container.SetFlowLayoutGrowthDirection then
            pcall(container.SetFlowLayoutGrowthDirection, container, horizontal, up)
        elseif container.SetAuraLayoutGrowthDirection then
            pcall(container.SetAuraLayoutGrowthDirection, container, horizontal, up)
        end
    end
    if container.SetFlowLayoutMaximumLineSize then
        pcall(container.SetFlowLayoutMaximumLineSize, container, maxCount * iconSize + (maxCount - 1) * gap)
    end
end

local function InitializeAuraVisuals(button, preview, iconSize, warningGlow, showTenths)
    button:SetSize(iconSize, iconSize)

    local icon = button:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(button)
    icon:SetTexCoord(.08,.92,.08,.92)
    if not preview and button.SetIcon then button:SetIcon(icon) end
    button.H3z0Icon = icon
    if ns.AddCastIconSkin then
        -- Match the nameplate castbar spell icon exactly: same mask, border,
        -- shadow padding and shadow opacity. This is presentation-only; aura
        -- state/filtering remains Blizzard-owned through the custom container API.
        ns.AddCastIconSkin(button, icon, 4, .82)
    elseif ns.AddRoundedIconSkin then
        ns.AddRoundedIconSkin(button, icon, 4, .82)
    end

    -- Parity-safe dispel status presentation. Do not read auraData or aura
    -- instance IDs in H3z0 Lua. CustomAuraButton owns the aura assignment and
    -- applies this overlay from Blizzard's protected aura state. The normal
    -- H3z0 border remains underneath as the neutral black fallback.
    --
    -- Harmful aura with a Blizzard dispel type -> blue border.
    -- Harmful aura without a dispel type       -> red border.
    -- Helpful/neutral aura                     -> normal black H3z0 border.
    if not preview and button.AddDispelTypeTexture and Enum
        and Enum.CustomAuraButtonDispelTypeTextureStyle
        and Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset then
        -- Keep the normal black H3z0 border one sublevel below the status
        -- overlay, without changing the castbar icon skin globally.
        if button.H3z0CastBorder and button.H3z0CastBorder.SetDrawLayer then
            pcall(button.H3z0CastBorder.SetDrawLayer, button.H3z0CastBorder, "OVERLAY", 6)
        end
        local dispelBorder = button:CreateTexture(nil, "OVERLAY", nil, 7)
        dispelBorder:SetAllPoints(icon)
        dispelBorder:Hide()
        button.H3z0DispelBorder = dispelBorder

        -- These are pre-colored assets. AuraBorder.tga is intentionally almost
        -- black and therefore cannot be vertex-tinted into a visible red/blue.
        -- Keep it as the neutral base, and let Blizzard's protected dispel state
        -- select one of the dedicated status borders above it.
        local redEntry = {
            asset = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorderRed.tga",
            useAtlasSize = false,
        }
        local blueEntry = {
            asset = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorderBlue.tga",
            useAtlasSize = false,
        }
        local white = CreateColor and CreateColor(1, 1, 1) or nil

        if white then
            local options = {
                showAlways = false,
                showWhenHarmful = true,
                showWhenHelpful = false,
                showWithoutDispelType = true,
                style = Enum.CustomAuraButtonDispelTypeTextureStyle.CustomAsset,
                customDispelAssetMap = {
                    None = redEntry,
                    Magic = blueEntry,
                    Curse = blueEntry,
                    Disease = blueEntry,
                    Poison = blueEntry,
                },
                customDispelColorMap = {
                    None = white,
                    Magic = white,
                    Curse = white,
                    Disease = white,
                    Poison = white,
                },
            }
            local ok = pcall(button.AddDispelTypeTexture, button, dispelBorder, options)
            if not ok then
                dispelBorder:Hide()
            end
        end
    end

    local cooldown = CreateFrame("Cooldown", nil, button, "CooldownFrameTemplate")
    cooldown:SetAllPoints(icon)
    if cooldown.SetDrawBling then cooldown:SetDrawBling(false) end
    if cooldown.SetDrawEdge then cooldown:SetDrawEdge(false) end
    if cooldown.SetDrawSwipe then cooldown:SetDrawSwipe(true) end
    if cooldown.SetReverse then cooldown:SetReverse(true) end
    if cooldown.SetSwipeColor then cooldown:SetSwipeColor(0,0,0,.72) end
    -- Hide long aura-duration numbers above 60 seconds (original H3z0 behavior).
    -- A normal Cooldown cannot express a protected maximum-duration rule, so
    -- use CustomAuraButton's secure duration binding for the text and keep the
    -- Cooldown for the swipe only. No duration value is exposed to addon Lua.
    local durationTextBound = false
    if not preview and button.SetDurationText and C_StringUtil
        and type(C_StringUtil.CreateNumericRuleFormatter) == "function" then
        local okFormatter, formatter = pcall(C_StringUtil.CreateNumericRuleFormatter)
        if okFormatter and formatter and formatter.SetBreakpoints then
            local rounding = Enum and Enum.NumericRuleFormatRounding
                and Enum.NumericRuleFormatRounding.Nearest or nil
            local function Rule(threshold, step, format)
                local rule = { threshold = threshold, step = step, format = format }
                if rounding ~= nil then rule.rounding = rounding end
                return rule
            end
            local rules
            if showTenths then
                rules = {
                    Rule(0, 0.1, "%.1f"),
                    Rule(3, 1, "%.0f"),
                    Rule(61, 1, ""),
                }
            else
                rules = {
                    Rule(0, 1, "%.0f"),
                    Rule(61, 1, ""),
                }
            end
            local okRules = pcall(formatter.SetBreakpoints, formatter, rules)
            if okRules then
                local durationText = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
                -- Keep the timer proportional to the icon: the font is doubled
                -- before the whole aura button inherits its live layout scale.
                StyleDurationFontString(durationText, DURATION_FONT_SCALE)
                durationText:SetPoint("CENTER", button, "CENTER", 0, 0)
                durationText:SetJustifyH("CENTER")
                durationText:SetJustifyV("MIDDLE")
                local okBind = pcall(button.SetDurationText, button, durationText, {
                    textFormatter = formatter,
                })
                if okBind then
                    button.H3z0DurationText = durationText
                    durationTextBound = true
                else
                    durationText:Hide()
                end
            end
        end
    end
    if cooldown.SetHideCountdownNumbers then
        cooldown:SetHideCountdownNumbers(durationTextBound)
    end
    if not durationTextBound and showTenths and cooldown.SetCountdownMillisecondsThreshold then
        pcall(cooldown.SetCountdownMillisecondsThreshold, cooldown, 3)
    end
    if not preview and button.SetDurationCooldown then button:SetDurationCooldown(cooldown) end
    button.H3z0Cooldown = cooldown

    local count = button:CreateFontString(nil, "OVERLAY", "NumberFontNormalSmall")
    count:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 1, 0)
    if not preview and button.SetApplicationCount then button:SetApplicationCount(count, {}) end
    button.H3z0Count = count

    if warningGlow then
        local glow = button:CreateTexture(nil, "BACKGROUND", nil, 3)
        glow:SetPoint("TOPLEFT", button, "TOPLEFT", -2, 2)
        glow:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", 2, -2)
        glow:SetColorTexture(1,.08,.08,.26)
        button.H3z0Glow = glow
    end

    -- Keep Blizzard's secure aura tooltip available in and out of combat.
    if button.SetHideTooltipInCombat then button:SetHideTooltipInCombat(false) end
    if button.SetTooltipAnchorPoint then
        pcall(button.SetTooltipAnchorPoint, button, "ANCHOR_RIGHT", 0, 0)
    end
    if button.SetMouseClickEnabled then pcall(button.SetMouseClickEnabled, button, false) end
end

function ns.InitializeNameplateAuraVisuals(button, preview)
    InitializeAuraVisuals(button, preview, BASE_AURA, false, false)
end

function ns.InitializeNameplateCCVisuals(button, preview)
    InitializeAuraVisuals(button, preview, BASE_CC, true, true)
end

local function initAura(button) ns.InitializeNameplateAuraVisuals(button, false) end
local function initCC(button) ns.InitializeNameplateCCVisuals(button, false) end

local function AddFixedAuraStatusBorder(button, asset)
    if not button or not button.H3z0Icon or not asset then return end
    if button.H3z0CastBorder and button.H3z0CastBorder.SetDrawLayer then
        pcall(button.H3z0CastBorder.SetDrawLayer, button.H3z0CastBorder, "OVERLAY", 6)
    end
    -- WoW texture sublevels are restricted to -8..7.
    local border = button:CreateTexture(nil, "OVERLAY", nil, 7)
    border:SetAllPoints(button.H3z0Icon)
    border:SetTexture(asset)
    button.H3z0HelpfulStatusBorder = border
end

-- The secure group itself proves the state, so these initializers can style
-- enemy buffs without reading protected aura data in addon Lua.
local function initEnemyImportantBuff(button)
    ns.InitializeNameplateAuraVisuals(button, false)
    AddFixedAuraStatusBorder(button, "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorderRed.tga")
end

local function initEnemyStealableBuff(button)
    ns.InitializeNameplateAuraVisuals(button, false)
    AddFixedAuraStatusBorder(button, "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorderBlue.tga")
end

local function AddGroup(container, key, filterString, iconSize, gap, maxCount, initializer, layoutIndex, candidateFilters, sortMethod)
    local options = {
        maxFrameCount = maxCount,
        initializeFrame = initializer,
        candidateFilters = candidateFilters or {},
        layout = {
            elementSpacing = gap,
            lineSpacing = gap,
            elementWidth = iconSize,
            elementHeight = iconSize,
            layoutIndex = layoutIndex or 1,
        },
    }
    if AuraContainerSortMethod then
        options.sortMethod = sortMethod or AuraContainerSortMethod.Default
    end
    if AuraContainerSortDirection then options.sortDirection = AuraContainerSortDirection.Normal end
    local ok = pcall(container.AddAuraGroup, container, key, filterString, options)
    return ok
end

local function CreateContainer(parent, kind, iconSize, gap, maxCount)
    -- A fixed clipping anchor keeps the visible row at the H3z0 capacity even
    -- when parity requires multiple secure filter groups (enemy Important OR
    -- Stealable buffs). The CustomAuraContainer may internally wrap overflow,
    -- but only the first H3z0 row is rendered, preserving the existing style.
    local anchor = CreateFrame("Frame", nil, parent or UIParent)
    anchor:SetSize(maxCount * iconSize + math.max(0, maxCount - 1) * gap, iconSize + 4)
    anchor.H3z0CanClip = false
    if anchor.SetClipsChildren then
        local ok = pcall(anchor.SetClipsChildren, anchor, true)
        anchor.H3z0CanClip = ok and true or false
    end
    anchor:Hide()

    local ok, container = pcall(CreateFrame, "AuraContainer", nil, anchor, "CustomAuraContainerTemplate")
    if not ok or not container then
        anchor:Hide()
        return nil
    end
    container:SetEnabled(false)
    container:Hide()
    container.H3z0Kind = kind
    container.H3z0Anchor = anchor
    container.H3z0PresentationOwned = true
    anchor.H3z0PresentationOwned = true
    if kind == "buff" then
        container:SetPoint("RIGHT", anchor, "RIGHT", 0, 0)
    else
        container:SetPoint("LEFT", anchor, "LEFT", 0, 0)
    end
    if container.SetFlattensRenderLayers then pcall(container.SetFlattensRenderLayers, container, true) end
    SetContainerFlow(container, kind, iconSize, gap, maxCount)
    return container
end

local function BuildAuraSet(unitFrame, presentationParent)
    if not LoadAuraContainerAPI() then return nil end
    local AF = AuraUtil.AuraFilters
    local FS = AuraUtil.CreateFilterString
    if not AF or not FS then return nil end

    local parent = presentationParent or UIParent
    local buffs = CreateContainer(parent, "buff", BASE_AURA, AURA_GAP, MAX_AURA)
    local debuffs = CreateContainer(parent, "debuff", BASE_AURA, AURA_GAP, MAX_DEBUFF)
    local cc = CreateContainer(parent, "cc", BASE_CC, CC_GAP, MAX_CC)
    if not buffs or not debuffs or not cc then return nil end

    local function MakeFilter(...)
        local parts = {}
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            if value then parts[#parts + 1] = value end
        end
        return FS(unpack(parts))
    end

    local helpful = MakeFilter(AF.Helpful, AF.IncludeNameplateOnly)
    local helpfulMine = MakeFilter(AF.Helpful, AF.Player or "PLAYER", AF.IncludeNameplateOnly)
    local importantSort = AuraContainerSortMethod and AuraContainerSortMethod.ImportantOnly or nil

    -- Mirror Blizzard's native BuffListFrame: friendly nameplates display only
    -- local-player auras, while enemy plates use the important/stealable union
    -- below. This is fixed Blizzard behaviour, not a H3z0 setting.
    local hasFriendlyBuffs = AddGroup(buffs, "FriendlyBuffs", helpfulMine,
        BASE_AURA, AURA_GAP, MAX_AURA, initAura, 1,
        { isFromPlayerOrPlayerPet = true }, importantSort) and true or false

    -- Blizzard enemy buffs are Important OR Stealable. Use two DISJOINT secure
    -- groups so H3z0 can share the friendly layout without enumerating aura
    -- data: stealable always wins the blue style, while important non-stealable
    -- buffs use red. Blizzard still owns eligibility, sorting and cooldown state.
    -- Treat the two native groups independently. Forever can expose the
    -- Stealable rule even when its Important token is absent; requiring both
    -- made the valid Stealable group disappear as well.
    local hasEnemyImportantBuffs = false
    local hasEnemyStealableBuffs = false
    if AF.Important then
        local important = MakeFilter(AF.Helpful, AF.IncludeNameplateOnly, AF.Important)
        hasEnemyImportantBuffs = AddGroup(buffs, "EnemyImportantBuffs", important,
            BASE_AURA, AURA_GAP, MAX_AURA, initEnemyImportantBuff, 1,
            { isStealable = false }, importantSort) and true or false
    end
    hasEnemyStealableBuffs = AddGroup(buffs, "EnemyStealableBuffs", helpful,
        BASE_AURA, AURA_GAP, MAX_AURA, initEnemyStealableBuff, 2,
        { isStealable = true }, importantSort) and true or false

    -- Mirror Blizzard's enemy-debuff rule: show harmful auras applied by the
    -- player or their pet, including Blizzard's nameplate-only auras. Crowd
    -- control remains in the separate CC container so an aura is never drawn
    -- twice.
    local hasDebuffParity = false
    if AF.CrowdControl then
        local harmfulMineNoCC = MakeFilter(AF.Harmful, AF.Player or "PLAYER",
            AF.IncludeNameplateOnly, "!" .. AF.CrowdControl)
        local all = AddGroup(debuffs, "DebuffsAll", harmfulMineNoCC,
            BASE_AURA, AURA_GAP, MAX_DEBUFF, initAura, 1,
            { isFromPlayerOrPlayerPet = true }, nil)
        hasDebuffParity = all and true or false
    end

    -- Blizzard's native NPC CC candidate rule is
    -- (CROWD_CONTROL OR nameplateShowAll). Express that as two DISJOINT secure
    -- groups so an aura can never be duplicated:
    --   1) every Blizzard-classified CC aura
    --   2) non-CC auras explicitly flagged nameplateShowAll
    -- Blizzard still owns filtering, aura data, cooldowns and per-group sort;
    -- H3z0 owns only the movable/scalable visual container.
    local hasCrowdControlParity = false
    if AF.CrowdControl then
        local harmfulCC = MakeFilter(AF.Harmful, AF.IncludeNameplateOnly, AF.CrowdControl)
        local harmfulShowAllOnly = MakeFilter(AF.Harmful, AF.IncludeNameplateOnly, "!" .. AF.CrowdControl)
        local crowdControl = AddGroup(cc, "CrowdControl", harmfulCC,
            BASE_CC, CC_GAP, MAX_CC, initCC, 1, {}, nil)
        local crowdControlShowAll = AddGroup(cc, "CrowdControlShowAll", harmfulShowAllOnly,
            BASE_CC, CC_GAP, MAX_CC, initCC, 2, { nameplateShowAll = true }, nil)
        hasCrowdControlParity = crowdControl and crowdControlShowAll and true or false
    end

    -- Player nameplates use Blizzard's LossOfControlFrame rather than the NPC CC
    -- list. Only replace that presentation if this build exposes a dedicated,
    -- secure LoC aura filter. Otherwise leave Blizzard's native LoC frame visible
    -- so parity wins over styling.
    local hasLossOfControl = false
    if AF.LossOfControl then
        local locFilter = MakeFilter(AF.Harmful, AF.LossOfControl)
        hasLossOfControl = AddGroup(cc, "LossOfControl", locFilter,
            BASE_CC, CC_GAP, 1, initCC, 1, {}, nil) and true or false
    end

    -- Do not inject a separate school-lockout category that Blizzard's native
    -- nameplate rules did not select.
    local groupControlSupported = type(buffs.SetAuraGroupEnabled) == "function"
        and type(debuffs.SetAuraGroupEnabled) == "function"
        and type(cc.SetAuraGroupEnabled) == "function"
        and type(buffs.HasAuraGroup) == "function"
        and type(debuffs.HasAuraGroup) == "function"
        and type(cc.HasAuraGroup) == "function"

    local set = {
        buffs = buffs,
        debuffs = debuffs,
        cc = cc,
        groupControlSupported = groupControlSupported,
        hasFriendlyBuffs = hasFriendlyBuffs,
        hasEnemyImportantBuffs = hasEnemyImportantBuffs,
        hasEnemyStealableBuffs = hasEnemyStealableBuffs,
        hasEnemyBuffs = hasEnemyImportantBuffs or hasEnemyStealableBuffs,
        hasDebuffParity = hasDebuffParity,
        hasCrowdControlParity = hasCrowdControlParity,
        hasLossOfControl = hasLossOfControl,
        presentationParent = parent,
    }
    return set
end

local function DesignerHealthOffset()
    local db = ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
    if type(db) == "table" and db.enabled ~= false then
        return tonumber(db.healthX) or 0, tonumber(db.healthY) or 0
    end
    return 0, 0
end

local function PositionContainer(container, bar, kind, db)
    if not container or not IsUsableFrame(bar) or not db then return end

    local iconSize, gap, maxCount
    if kind == "cc" then iconSize, gap, maxCount = BASE_CC, CC_GAP, MAX_CC
    elseif kind == "debuff" then iconSize, gap, maxCount = BASE_AURA, AURA_GAP, MAX_DEBUFF
    else iconSize, gap, maxCount = BASE_AURA, AURA_GAP, MAX_AURA end
    SetContainerFlow(container, kind, iconSize, gap, maxCount)

    local prefix = kind == "buff" and "buff" or kind == "debuff" and "debuff" or "cc"
    local x = tonumber(db[prefix .. "X"]) or 0
    local y = tonumber(db[prefix .. "Y"]) or 0
    local scale = tonumber(db[prefix .. "Scale"]) or 1
    local blizzardAuraScale = ns.GetNameplateAuraScaleFactor and ns.GetNameplateAuraScaleFactor() or 1
    local designerDB = ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
    -- Live H3z0 aura containers inherit globalScale from record.root. The
    -- layout-preview is intentionally a fixed authoring canvas and must ignore
    -- live globalScale completely, including when the menu is rebuilt/reopened.
    -- Only legacy/non-H3z0 callers retain the explicit fallback multiplier.
    local ignoresGlobalScale = container.H3z0PresentationOwned or container.H3z0PreviewContainer
    local globalScale = ignoresGlobalScale and 1
        or (designerDB and tonumber(designerDB.globalScale) or 1)
    scale = scale * blizzardAuraScale * globalScale
    local hx, hy = DesignerHealthOffset()
    -- H3z0-owned live containers anchor directly to the custom health shell, so
    -- saved aura coordinates already use that shell's centre as their origin.
    -- Preview groups have no H3z0Kind and still need the health offset.
    if container.H3z0Kind then hx, hy = 0, 0 end
    local plateFactor = ns.GetNameplateLayoutFactor and ns.GetNameplateLayoutFactor(bar) or 1

    -- Canonical 1:1 origin: all aura coordinates are relative to the CENTER of
    -- the visible H3z0Nameplates health bar. Live containers now anchor directly
    -- to H3z0's health shell; preview uses the same coordinate math.
    local px = (hx + x) * plateFactor
    local debuffPadding = kind == "debuff" and ns.GetNameplateDebuffPaddingOffset
        and ns.GetNameplateDebuffPaddingOffset() or 0
    local py = (hy + y + debuffPadding) * plateFactor

    local anchor = container.H3z0Anchor or container
    if container.H3z0Anchor then
        pcall(container.SetScale, container, 1)
        pcall(anchor.SetScale, anchor, scale)
    else
        pcall(container.SetScale, container, scale)
    end
    local okClear = pcall(anchor.ClearAllPoints, anchor)
    if okClear then
        if kind == "buff" then
            pcall(anchor.SetPoint, anchor, "RIGHT", bar, "CENTER", px, py)
        else
            pcall(anchor.SetPoint, anchor, "LEFT", bar, "CENTER", px, py)
        end
    end
end

ns.PlaceNameplateAuraContainer = PositionContainer

local function GetNativeAurasFrame(unitFrame)
    return unitFrame and (unitFrame.AurasFrame or unitFrame.AuraFrame) or nil
end

local function SafeBoolean(value)
    if value == nil then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    return value and true or false
end

local function ResolvedAuraUnitType(unitFrame)
    local auras = GetNativeAurasFrame(unitFrame)
    local isFriend = auras and SafeBoolean(auras.isFriend) or nil
    local isPlayer = auras and SafeBoolean(auras.isPlayer) or nil
    if isFriend == nil and unitFrame then isFriend = SafeBoolean(unitFrame.isFriend) end
    if isPlayer == nil and unitFrame then isPlayer = SafeBoolean(unitFrame.isPlayer) end
    return isFriend, isPlayer
end

local function SetNativeAuraAlpha(frame, alpha)
    if frame and frame.SetAlpha then pcall(frame.SetAlpha, frame, alpha) end
end

local function RestoreNativeAuras(unitFrame)
    local auras = GetNativeAurasFrame(unitFrame)
    if not auras then return end
    SetNativeAuraAlpha(auras.BuffListFrame, 1)
    SetNativeAuraAlpha(auras.DebuffListFrame, 1)
    SetNativeAuraAlpha(auras.CrowdControlListFrame, 1)
    SetNativeAuraAlpha(auras.LossOfControlFrame, 1)
    unitFrame.H3z0NativeAuraVisualsOwned = nil
end

local function SetGroupEnabled(container, key, enabled)
    if not container or not key or type(container.HasAuraGroup) ~= "function"
        or type(container.SetAuraGroupEnabled) ~= "function" then
        return false
    end
    local okHas, has = pcall(container.HasAuraGroup, container, key)
    if not okHas or not has then return false end

    local desired = enabled and true or false
    container.H3z0GroupStates = container.H3z0GroupStates or {}
    if container.H3z0GroupStates[key] == desired then return true end
    local current
    if type(container.IsAuraGroupEnabled) == "function" then
        local okCurrent, value = pcall(container.IsAuraGroupEnabled, container, key)
        if okCurrent and not (issecretvalue and issecretvalue(value)) then current = value and true or false end
    end
    if current ~= desired then
        local okSet = pcall(container.SetAuraGroupEnabled, container, key, desired)
        if not okSet then return false end
    end
    if type(container.IsAuraGroupEnabled) == "function" then
        local okVerify, value = pcall(container.IsAuraGroupEnabled, container, key)
        if okVerify and not (issecretvalue and issecretvalue(value)) then
            local matches = (value and true or false) == desired
            if matches then container.H3z0GroupStates[key] = desired end
            return matches
        end
    end
    container.H3z0GroupStates[key] = desired
    return true
end

local function SetContainerState(container, unit, shown)
    if not container or shown == nil then return false end
    local desired = shown and true or false
    if container.H3z0ShownState == desired and container.H3z0Unit == unit then
        return desired
    end
    local anchor = container.H3z0Anchor
    if desired then
        -- Do not suppress Blizzard's native auras if a Retail access
        -- restriction prevents this custom group from becoming active.
        local okUnit = pcall(container.SetUnit, container, unit)
        local okEnabled = okUnit and pcall(container.SetEnabled, container, true)
        local okShow = okEnabled and pcall(container.Show, container)
        local okAnchor = not anchor or (okShow and pcall(anchor.Show, anchor))
        if not (okUnit and okEnabled and okShow and okAnchor) then
            pcall(container.SetEnabled, container, false)
            pcall(container.Hide, container)
            if anchor then pcall(anchor.Hide, anchor) end
            container.H3z0ShownState = false
            container.H3z0Unit = nil
            return false
        end
    else
        pcall(container.SetEnabled, container, false)
        pcall(container.Hide, container)
        if anchor then pcall(anchor.Hide, anchor) end
    end
    container.H3z0ShownState = desired
    container.H3z0Unit = unit
    return desired
end

local function ConfigureAuraGroups(set, unitFrame)
    if not set or not unitFrame or not set.groupControlSupported then
        return false, false, false, false, false
    end
    local isFriend, isPlayer = ResolvedAuraUnitType(unitFrame)
    if isFriend == nil or isPlayer == nil then
        return false, false, false, false, false
    end

    -- BUFFS: configure every group that was created, then fail only this category
    -- if one of its required secure toggles fails.
    local customBuff = (isFriend and set.hasFriendlyBuffs)
        or ((not isFriend) and set.hasEnemyBuffs) or false
    local buffOK = true
    if set.hasFriendlyBuffs then
        buffOK = SetGroupEnabled(set.buffs, "FriendlyBuffs", customBuff and isFriend) and buffOK
    end
    if set.hasEnemyImportantBuffs then
        buffOK = SetGroupEnabled(set.buffs, "EnemyImportantBuffs", customBuff and not isFriend) and buffOK
    end
    if set.hasEnemyStealableBuffs then
        buffOK = SetGroupEnabled(set.buffs, "EnemyStealableBuffs", customBuff and not isFriend) and buffOK
    end
    if not buffOK then customBuff = false end

    -- DEBUFFS: use Blizzard's player/pet rule. Non-player debuffs stay hidden
    -- unless Blizzard classifies them for the separate crowd-control list.
    local customDebuff = set.hasDebuffParity or false
    local debuffOK = true
    if set.hasDebuffParity then
        debuffOK = SetGroupEnabled(set.debuffs, "DebuffsAll",
            customDebuff) and debuffOK
    end
    if not debuffOK then customDebuff = false end

    -- NPC CC and player Loss-of-Control are separate Blizzard categories. The
    -- native CC list has no player-source restriction, so neither does H3z0.
    local customCC = not isPlayer and set.hasCrowdControlParity or false
    local ccOK = true
    if set.hasCrowdControlParity then
        ccOK = SetGroupEnabled(set.cc, "CrowdControl", customCC) and ccOK
        ccOK = SetGroupEnabled(set.cc, "CrowdControlShowAll", customCC) and ccOK
    end
    if not ccOK then customCC = false end

    local customLoC = isPlayer and set.hasLossOfControl or false
    local locOK = true
    if set.hasLossOfControl then
        locOK = SetGroupEnabled(set.cc, "LossOfControl", customLoC) and locOK
    end
    if not locOK then customLoC = false end

    return customBuff, customDebuff, customCC, customLoC
end

local function OwnNativeAuraVisuals(unitFrame, buffActive, debuffActive, ccActive, locActive)
    -- Retail can reject an individual secure aura group. Only suppress its
    -- corresponding native list after the custom group has been activated;
    -- otherwise retain Blizzard's own live visual as a safe fallback.
    if not unitFrame then return end
    local auras = GetNativeAurasFrame(unitFrame)
    if not auras then return end
    SetNativeAuraAlpha(auras.BuffListFrame, buffActive and 0 or 1)
    SetNativeAuraAlpha(auras.DebuffListFrame, debuffActive and 0 or 1)
    SetNativeAuraAlpha(auras.CrowdControlListFrame, ccActive and 0 or 1)
    SetNativeAuraAlpha(auras.LossOfControlFrame, locActive and 0 or 1)
    unitFrame.H3z0NativeAuraVisualsOwned = (buffActive or debuffActive or ccActive or locActive) and true or nil
end

function ns.SyncNameplateAuraState(unitFrame)
    local set = unitFrame and setsByUnitFrame[unitFrame]
    if not set or not set.unit then return end
    if ns.ShouldSkinNameplateUnit and not ns.ShouldSkinNameplateUnit(set.unit, unitFrame) then
        for _, container in pairs({set.buffs, set.debuffs, set.cc}) do
            if container then
                pcall(container.SetEnabled, container, false)
                pcall(container.Hide, container)
                if container.H3z0Anchor then pcall(container.H3z0Anchor.Hide, container.H3z0Anchor) end
            end
        end
        RestoreNativeAuras(unitFrame)
        return
    end

    -- This function is called only when a plate is bound, reclassified or its
    -- layout changes. Aura changes themselves are handled internally by
    -- Blizzard's CustomAuraContainer.
    local customBuff, customDebuff, customCC, customLoC =
        ConfigureAuraGroups(set, unitFrame)
    local buffActive = SetContainerState(set.buffs, set.unit, customBuff)
    local debuffActive = SetContainerState(set.debuffs, set.unit, customDebuff)
    local ccContainerActive = SetContainerState(set.cc, set.unit, customCC or customLoC)
    OwnNativeAuraVisuals(unitFrame, buffActive, debuffActive,
        ccContainerActive and customCC, ccContainerActive and customLoC)
end

local UnbindUnit
local function BindUnit(unit, plate)
    if not IsSupportedUnit(unit) or IsPersonalPlayerPlate(plate) then
        if UnbindUnit then UnbindUnit(unit) end
        return
    end
    if not IsUsableFrame(plate) or not IsUsableFrame(plate.UnitFrame) then return end
    local unitFrame = plate.UnitFrame

    -- Enemy-only presentation mode: stop here for every friendly unit. We do
    -- not build/rebind/update H3z0 aura containers at all; Blizzard's original
    -- friendly aura presentation is restored and left alone.
    if ns.ShouldSkinNameplateUnit and not ns.ShouldSkinNameplateUnit(unit, unitFrame) then
        if UnbindUnit then UnbindUnit(unit) end
        RestoreNativeAuras(unitFrame)
        return
    end

    -- Ensure the H3z0 presentation branch exists before creating aura containers.
    -- Parenting under plate/root (not UnitFrame) prevents protected-parent combat
    -- inheritance while Blizzard's AuraContainer still owns the actual aura data.
    local record = ns.GetNameplateDesignerRecordForUnitFrame
        and ns.GetNameplateDesignerRecordForUnitFrame(unitFrame) or nil
    if not record and ns.EnsureNameplateDesignerRecord then
        record = ns.EnsureNameplateDesignerRecord(unit)
    end
    local presentationParent = record and record.root or plate
    local bar = record and record.healthShell or GetHealthBar(unitFrame)
    if not IsUsableFrame(presentationParent) or not IsUsableFrame(bar) then return end

    local set = record and setsByRecord[record] or setsByUnitFrame[unitFrame]
    if not set or set.presentationParent ~= presentationParent then
        set = BuildAuraSet(unitFrame, presentationParent)
        if record and set then setsByRecord[record] = set end
    end
    if not set then return end
    local db = ns.GetDB and ns.GetDB() or nil
    if not db then return end

    -- Rebind the persistent H3z0 aura presentation to Blizzard's current pooled
    -- UnitFrame. Old UnitFrame callbacks remain harmless because lookup is by the
    -- current mapping, while the visible containers stay with this outer plate.
    if set.unitFrame and set.unitFrame ~= unitFrame and setsByUnitFrame[set.unitFrame] == set then
        setsByUnitFrame[set.unitFrame] = nil
    end
    set.unitFrame = unitFrame
    setsByUnitFrame[unitFrame] = set
    set.unit, set.plate, set.record = unit, plate, record
    boundByUnit[unit] = unitFrame

    local baseLevel = record and record.nameLayer and record.nameLayer.GetFrameLevel
        and record.nameLayer:GetFrameLevel() or 60
    for kind, container in pairs({buff=set.buffs, debuff=set.debuffs, cc=set.cc}) do
        if container and container.SetFrameLevel then pcall(container.SetFrameLevel, container, baseLevel + 10) end
        if container and container.H3z0Anchor and container.H3z0Anchor.SetFrameLevel then
            pcall(container.H3z0Anchor.SetFrameLevel, container.H3z0Anchor, baseLevel + 10)
        end
        if container then PositionContainer(container, bar, kind, db) end
        if container and container.SetUnit then pcall(container.SetUnit, container, unit) end
    end

    ns.SyncNameplateAuraState(unitFrame)
end

UnbindUnit = function(unit)
    local unitFrame = boundByUnit[unit]
    if not unitFrame then return end
    boundByUnit[unit] = nil
    local set = setsByUnitFrame[unitFrame]
    if set then
        for _, container in pairs({set.buffs, set.debuffs, set.cc}) do
            if container then
                pcall(container.SetEnabled, container, false)
                pcall(container.Hide, container)
                if container.H3z0Anchor then pcall(container.H3z0Anchor.Hide, container.H3z0Anchor) end
            end
        end
        set.unit, set.plate = nil, nil
        if setsByUnitFrame[unitFrame] == set then setsByUnitFrame[unitFrame] = nil end
        if set.unitFrame == unitFrame then set.unitFrame = nil end
        for _, container in pairs({set.buffs, set.debuffs, set.cc}) do
            if container then
                container.H3z0ShownState = nil
                container.H3z0Unit = nil
            end
        end
    end
    -- Keep native alpha ownership as last resolved. The frame is pooled and hidden at
    -- this point; restoring stock auras here caused the one-frame/whole-combat
    -- fallback when the same nameplate was rebound before combat ended.
end

function ns.RefreshAuraContainers()
    local db = ns.GetDB and ns.GetDB() or nil
    if not db then return end
    for unit, unitFrame in pairs(boundByUnit) do
        local set = setsByUnitFrame[unitFrame]
        local record = set and set.record
        local bar = record and record.healthShell or GetHealthBar(unitFrame)
        if set and (not set.record or set.record.h3z0SkinActive)
            and IsUsableFrame(bar) and IsSupportedUnit(unit) and not IsPersonalPlayerPlate(set.plate) then
            if set.buffs then ns.Safe("buff container layout", PositionContainer, set.buffs, bar, "buff", db) end
            if set.debuffs then ns.Safe("debuff container layout", PositionContainer, set.debuffs, bar, "debuff", db) end
            if set.cc then ns.Safe("cc container layout", PositionContainer, set.cc, bar, "cc", db) end
            ns.Safe("aura parity state", ns.SyncNameplateAuraState, unitFrame)
        end
    end
end

function ns.RebindAuraContainers()
    if not C_NamePlate then return end
    local plates = C_NamePlate.GetNamePlates and C_NamePlate.GetNamePlates() or {}
    local seen = {}
    for _, plate in ipairs(plates) do
        local uf = plate.UnitFrame
        local unit = uf and uf.unit
        if unit and IsSupportedUnit(unit) and not IsPersonalPlayerPlate(plate) then
            local skinThis = not ns.ShouldSkinNameplateUnit or ns.ShouldSkinNameplateUnit(unit, uf)
            if skinThis then
                seen[unit] = true
                ns.Safe("bind aura containers", BindUnit, unit, plate)
            else
                UnbindUnit(unit)
                RestoreNativeAuras(uf)
            end
        elseif unit then
            UnbindUnit(unit)
        end
    end
    for unit in pairs(boundByUnit) do
        if not seen[unit] then UnbindUnit(unit) end
    end
end

eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
eventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("CVAR_UPDATE")
eventFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        LoadAuraContainerAPI()
        if C_Timer and C_Timer.After then C_Timer.After(.35, ns.RebindAuraContainers) end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if not IsNameplateToken(unit) or not C_NamePlate or type(C_NamePlate.GetNamePlateForUnit) ~= "function" then return end
        local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
        if ok then ns.Safe("bind aura containers", BindUnit, unit, plate) end
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        UnbindUnit(unit)
    elseif event == "PLAYER_REGEN_ENABLED" then
        ns.RebindAuraContainers()
        ns.RefreshAuraContainers()
    elseif event == "CVAR_UPDATE" then
        -- Candidate filtering, visibility, scale and padding are Blizzard-owned.
        -- Any nameplate* CVar may recycle/reclassify plates, so rebind H3z0's
        -- own containers after Blizzard resolves the setting instead of keeping
        -- a partial allow-list that can leave stale Friendly/Enemy/minor state.
        local cvarName = type(unit) == "string" and unit or nil
        local isNameplateCVar = cvarName and cvarName:lower():find("nameplate", 1, true) == 1
        if isNameplateCVar then
            local function RefreshBlizzardAuraState()
                ns.RebindAuraContainers()
                ns.RefreshAuraContainers()
            end
            if C_Timer and C_Timer.After then C_Timer.After(0, RefreshBlizzardAuraState)
            else RefreshBlizzardAuraState() end
        end
    end
end)
