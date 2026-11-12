local _, ns = ...

local FALLBACK = ns.FLAT_TEXTURE or "Interface\\Buttons\\WHITE8X8"
local LSM = LibStub and LibStub("LibSharedMedia-3.0", true) or nil

-- Curated Blizzard assets that are useful as bar fills. Atlas entries cannot
-- be registered as normal LibSharedMedia file paths, so they are merged into
-- the same dropdown and applied directly to the StatusBar texture object.
local BLIZZARD_MEDIA = {
    ["Blizzard Original Cast"] = { atlas = "ui-castingbar-filling-standard" },
    ["Blizzard Channel"] = { atlas = "ui-castingbar-filling-channel" },
    ["Blizzard Uninterruptible"] = { atlas = "ui-castingbar-uninterruptable" },
    ["Blizzard Interrupted"] = { atlas = "ui-castingbar-interrupted" },
    ["Blizzard Modern Nameplate"] = { atlas = "UI-HUD-CoolDownManager-Bar" },
    ["Blizzard Classic Health"] = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill" },
    ["Blizzard Raid Bar"] = { file = "Interface\\RaidFrame\\Raid-Bar-Hp-Fill" },
    ["Blizzard"] = { file = "Interface\\TargetingFrame\\UI-StatusBar" },
    ["Blizzard Character Skills Bar"] = { file = "Interface\\PaperDollInfoFrame\\UI-Character-Skills-Bar" },
    ["Blizzard Classic Fill"] = { file = "Interface\\TargetingFrame\\UI-TargetingFrame-BarFill" },
}

local H3Z0_MEDIA_ORDER = {
    {"H3z0 Diagonal Stripes", "H3z0Diagonal.tga"},
    {"H3z0 Checker", "H3z0Checker.tga"},
    {"H3z0 Soft Diagonal", "H3z0SoftDiagonal.tga"},
    {"H3z0 Honeycomb", "H3z0Honeycomb.tga"},
    {"H3z0 Weave", "H3z0Weave.tga"},
    {"H3z0 Grid", "H3z0Grid.tga"},
    {"H3z0 Triangles", "H3z0Triangles.tga"},
    {"H3z0 Gradient", "H3z0Gradient.tga"},
    {"H3z0 Four-Way Gradient", "H3z0FourWayGradient.tga"},
    {"H3z0 Soft Bevel", "H3z0SoftBevel.tga"},
    {"H3z0 Soft Bevel - Hard Edge", "H3z0SoftBevelHardEdgeV2.tga"},
}
local H3Z0_MEDIA = {}
for _, entry in ipairs(H3Z0_MEDIA_ORDER) do
    H3Z0_MEDIA[entry[1]] = "Interface\\AddOns\\H3z0Nameplates\\Media\\BarTextures\\" .. entry[2]
end
local H3Z0_CAST_NAME = "H3z0Cast Original"
local H3Z0_CAST_FILE = "Interface\\AddOns\\H3z0Nameplates\\Media\\H3z0CastChannel.tga"

local BLIZZARD_MEDIA_ORDER = {
    "Blizzard Original Cast",
    "Blizzard Channel",
    "Blizzard Uninterruptible",
    "Blizzard Interrupted",
    "Blizzard Modern Nameplate",
    "Blizzard Classic Health",
    "Blizzard Raid Bar",
    "Blizzard",
    "Blizzard Character Skills Bar",
    "Blizzard Classic Fill",
    "H3z0Cast Original",
    "H3z0 Flat",
}

if LSM then
    LSM:Register("statusbar", "H3z0 Flat", FALLBACK)
    LSM:Register("statusbar", H3Z0_CAST_NAME, H3Z0_CAST_FILE)
    for _, entry in ipairs(H3Z0_MEDIA_ORDER) do
        LSM:Register("statusbar", entry[1], H3Z0_MEDIA[entry[1]])
    end
end

function ns.GetStatusbarMedia(name)
    local builtin = type(name) == "string" and BLIZZARD_MEDIA[name] or nil
    if builtin and builtin.file then return builtin.file end
    if name == H3Z0_CAST_NAME then return H3Z0_CAST_FILE end
    if type(name) == "string" and H3Z0_MEDIA[name] then return H3Z0_MEDIA[name] end
    if LSM and type(name) == "string" then
        local texture = LSM:Fetch("statusbar", name, true)
        if texture then return texture end
    end
    return FALLBACK
end

function ns.ApplyStatusbarMedia(statusbar, name)
    if not statusbar or not statusbar.SetStatusBarTexture then return end
    local builtin = type(name) == "string" and BLIZZARD_MEDIA[name] or nil
    if builtin and builtin.atlas then
        statusbar:SetStatusBarTexture(FALLBACK)
        local texture = statusbar:GetStatusBarTexture()
        if texture and texture.SetAtlas then
            local ok = pcall(texture.SetAtlas, texture, builtin.atlas, false)
            if ok then return end
        end
    end
    statusbar:SetStatusBarTexture(ns.GetStatusbarMedia(name))
end

function ns.GetStatusbarMediaNames()
    local result, seen = {}, {}
    for _, name in ipairs(BLIZZARD_MEDIA_ORDER) do
        result[#result + 1], seen[name] = name, true
    end
    for _, entry in ipairs(H3Z0_MEDIA_ORDER) do
        local name = entry[1]
        if not seen[name] then result[#result + 1], seen[name] = name, true end
    end
    local names = LSM and LSM:List("statusbar") or nil
    if type(names) == "table" then
        for _, name in ipairs(names) do
            if not seen[name] then result[#result + 1], seen[name] = name, true end
        end
    end
    return result
end

-- Fonts: any font registered in LibSharedMedia (including the fonts H3z0 UI
-- registers) can be used for nameplate text. "Default" keeps the game font.
ns.DEFAULT_FONT_NAME = "Default"

function ns.GetFontPath(name)
    if not LSM or type(name) ~= "string" or name == ns.DEFAULT_FONT_NAME then return nil end
    return LSM:Fetch("font", name, true)
end

function ns.GetFontNames()
    local result = {ns.DEFAULT_FONT_NAME}
    local names = LSM and LSM:List("font") or nil
    if type(names) ~= "table" then return result end
    local rest = {}
    for _, name in ipairs(names) do
        if type(name) == "string" and name:lower():find("h3z0", 1, true) then
            result[#result + 1] = name
        else
            rest[#rest + 1] = name
        end
    end
    for _, name in ipairs(rest) do result[#result + 1] = name end
    return result
end
