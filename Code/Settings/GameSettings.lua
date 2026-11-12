local ADDON_NAME, ns = ...

-- Two friendly options are real game settings rather than H3z0 layout values:
-- whether friendly NPCs get nameplates at all, and Blizzard's own name-only
-- mode for friendly players. H3z0 Nameplates stores the choice and keeps the
-- game setting in step with it, outside combat only.
local SETTINGS = {
    -- Off unless the player turns it on.
    friendlyNpcs = { cvar = "nameplateShowFriendlyNPCs", default = 0 },
    -- Left exactly as the game has it until the player picks a value here.
    friendlyNameOnly = { cvar = "nameplateShowOnlyNameForFriendlyPlayerUnits" },
}

local function Store()
    H3z0NameplatesDB = type(H3z0NameplatesDB) == "table" and H3z0NameplatesDB or {}
    H3z0NameplatesDB.game = type(H3z0NameplatesDB.game) == "table" and H3z0NameplatesDB.game or {}
    return H3z0NameplatesDB.game
end

local function ReadCVar(name)
    if not (C_CVar and C_CVar.GetCVar) then return nil end
    local ok, value = pcall(C_CVar.GetCVar, name)
    if not ok or value == nil then return nil end
    if issecretvalue and issecretvalue(value) then return nil end
    return tostring(value)
end

-- A setting the running client does not have is reported as unavailable, so
-- the options window can grey it out instead of pretending it works.
function ns.IsGameNameplateSettingAvailable(key)
    local info = SETTINGS[key]
    return info ~= nil and ReadCVar(info.cvar) ~= nil
end

function ns.GetGameNameplateSetting(key)
    local info = SETTINGS[key]
    if not info then return false end
    local stored = Store()[key]
    if stored ~= nil then return tonumber(stored) == 1 end
    if info.default ~= nil then return info.default == 1 end
    return ReadCVar(info.cvar) == "1"
end

local pending = false

local function Apply()
    if InCombatLockdown and InCombatLockdown() then
        pending = true
        return
    end
    pending = false
    if not (C_CVar and C_CVar.SetCVar) then return end
    local store = Store()
    for key, info in pairs(SETTINGS) do
        local wanted = store[key]
        if wanted == nil then wanted = info.default end
        if wanted ~= nil then
            local text = tonumber(wanted) == 1 and "1" or "0"
            local current = ReadCVar(info.cvar)
            if current ~= nil and current ~= text then
                pcall(C_CVar.SetCVar, info.cvar, text)
            end
        end
    end
end

function ns.SetGameNameplateSetting(key, enabled)
    if not SETTINGS[key] then return end
    Store()[key] = enabled and 1 or 0
    Apply()
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
events:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_LOGIN" or pending then Apply() end
end)
