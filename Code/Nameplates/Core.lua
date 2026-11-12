local ADDON_NAME, ns = ...

-- Blizzard owns nameplate state/data; H3z0 owns the movable presentation.
-- Aura data stays in Blizzard's native nameplate AuraContainer frames. H3z0
-- only adds skin, saved position and scale to that already-resolved output.

ns.STOCK_HEALTH_WIDTH = 110
ns.STOCK_HEALTH_HEIGHT = 10
ns.STOCK_CAST_HEIGHT = 10

-- Canonical layout captured from the user's finalized 0.11.47 profile.
-- Icon + shield are no longer user-editable; they stay rigidly attached to
-- the cast bar and scale/move with it as one composite element.
local BASE_CAST_SCALE = 1.01010104907

local defaults = {
    castX = 0.833225268868,
    castY = 26.1666327976,
    castScale = BASE_CAST_SCALE,
    buffX = -142.217852125,
    buffY = -0.0323179589125,
    buffScale = 0.69,
    debuffX = 142.883903698,
    debuffY = -0.0198954589952,
    debuffScale = 0.69,
    ccX = -17.2216243707,
    ccY = 56.091698481,
    ccScale = 1.57306456669,
}

-- Buff/debuff positions are captured from Blizzard's live layout the first
-- time a usable nameplate is seen. This preserves the stock layout until the
-- user deliberately moves them in H3z0Nameplates Edit Mode.
local allowed = {
    castX=true, castY=true, castScale=true,
    ccX=true, ccY=true, ccScale=true,
    buffX=true, buffY=true, buffScale=true,
    debuffX=true, debuffY=true, debuffScale=true,
}

local function Normalize(db)
    for key in pairs(db) do
        if not allowed[key] then db[key] = nil end
    end
    for key, value in pairs(defaults) do
        if db[key] == nil then db[key] = value end
    end
    if db.buffScale ~= nil then db.buffScale = tonumber(db.buffScale) or 1 end
    if db.debuffScale ~= nil then db.debuffScale = tonumber(db.debuffScale) or 1 end
    return db
end

function ns.GetDB()
    H3z0NameplatesDB = type(H3z0NameplatesDB) == "table" and H3z0NameplatesDB or {}
    H3z0NameplatesDB.layout = type(H3z0NameplatesDB.layout) == "table" and H3z0NameplatesDB.layout or {}
    return Normalize(H3z0NameplatesDB.layout)
end

local function PublicNumber(value)
    if issecretvalue and issecretvalue(value) then return nil end
    return tonumber(value)
end

local function CVarNumber(name)
    local value
    if C_CVar and C_CVar.GetCVar then
        local ok, result = pcall(C_CVar.GetCVar, name)
        if ok then value = result end
    elseif GetCVar then
        local ok, result = pcall(GetCVar, name)
        if ok then value = result end
    end
    return PublicNumber(value)
end

function ns.GetNameplateBitfieldSetting(cvarName, enumValue, fallback)
    if cvarName and enumValue ~= nil and CVarCallbackRegistry
        and type(CVarCallbackRegistry.GetCVarBitfieldIndex) == "function" then
        local ok, value = pcall(CVarCallbackRegistry.GetCVarBitfieldIndex,
            CVarCallbackRegistry, cvarName, enumValue)
        if ok and not (issecretvalue and issecretvalue(value)) and type(value) == "boolean" then
            return value
        end
    end
    return fallback == true
end

function ns.GetNameplateCVarNumber(cvarName, fallback)
    local value = cvarName and CVarNumber(cvarName) or nil
    if value == nil then return tonumber(fallback) or 0 end
    return value
end

-- Capture Blizzard's aura scale and padding during migration so existing
-- layouts do not jump; later option changes are applied as a relative delta.
local function GetParityBaseline()
    H3z0NameplatesDB = type(H3z0NameplatesDB) == "table" and H3z0NameplatesDB or {}
    H3z0NameplatesDB.blizzardParityBaseline = type(H3z0NameplatesDB.blizzardParityBaseline) == "table"
        and H3z0NameplatesDB.blizzardParityBaseline or {}
    return H3z0NameplatesDB.blizzardParityBaseline
end

function ns.GetNameplateAuraScaleFactor()
    local constants = NamePlateConstants or {}
    local current = ns.GetNameplateCVarNumber(constants.AURA_SCALE_CVAR or "nameplateAuraScale", 1)
    if current <= 0 then current = 1 end
    local baseline = GetParityBaseline()
    local original = tonumber(baseline.auraScale)
    if not original or original <= 0 then
        original = current
        baseline.auraScale = current
    end
    return current / original
end

function ns.GetNameplateDebuffPaddingOffset()
    local constants = NamePlateConstants or {}
    local current = ns.GetNameplateCVarNumber(constants.DEBUFF_PADDING_CVAR or "nameplateDebuffPadding", 0)
    local baseline = GetParityBaseline()
    local original = tonumber(baseline.debuffPadding)
    if original == nil then
        original = current
        baseline.debuffPadding = current
    end
    return current - original
end

-- Blizzard NamePlateAuraItemTemplate is authored at AURA_ITEM_HEIGHT (25 on
-- current Forever/Mainline) and then each child receives the dedicated
-- nameplate aura scale. Expose the exact same source metrics to the layout
-- preview so it does not invent its own icon size.
-- Saved positions were authored at Blizzard nameplate Size 3, whose canonical
-- health width is NAMEPLATE_WIDTH. Other Size values change frame dimensions
-- without consistently changing effective scale, so offsets need this factor.
function ns.GetNameplateLayoutFactor(healthFrame)
    local db = ns.GetDB and ns.GetDB() or nil
    if db and tonumber(db.designEnabled or 1) ~= 0 then return 1 end
    local constants = NamePlateConstants or {}
    local baseWidth = tonumber(constants.NAMEPLATE_WIDTH) or ns.STOCK_HEALTH_WIDTH
    local width
    if healthFrame and healthFrame.GetWidth then
        local ok,value=pcall(healthFrame.GetWidth,healthFrame)
        width=ok and PublicNumber(value) or nil
    end
    width=width or baseWidth
    if not width or width<=20 or not baseWidth or baseWidth<=20 then return 1 end
    return width/baseWidth
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addon)
    if addon ~= ADDON_NAME then return end
    H3z0NameplatesDB = type(H3z0NameplatesDB) == "table" and H3z0NameplatesDB or {}
    H3z0NameplatesDB.layout = type(H3z0NameplatesDB.layout) == "table" and H3z0NameplatesDB.layout or {}
    Normalize(H3z0NameplatesDB.layout)
    -- Lock the migration baseline before the player can change the Blizzard
    -- sliders, so their first adjustment is reflected immediately.
    ns.GetNameplateAuraScaleFactor()
    ns.GetNameplateDebuffPaddingOffset()
end)
