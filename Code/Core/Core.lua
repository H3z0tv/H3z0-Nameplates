local ADDON_NAME, ns = ...

ns.FLAT_TEXTURE = "Interface\\Buttons\\WHITE8X8"

function ns.Safe(label, func, ...)
    local ok, result = pcall(func, ...)
    if not ok then
        print("H3z0 Nameplates: " .. tostring(label) .. " failed: " .. tostring(result))
    end
    return ok, result
end

local function AddIconSkin(frame, icon, options)
    if not frame or not icon or not frame.CreateTexture then return end
    options = type(options) == "table" and options or {}
    local key = options.key or "Custom"
    local maskPath = options.maskPath
    local borderPath = options.borderPath
    local borderScale = tonumber(options.borderScale) or 1
    local shadowPath = options.shadowPath
    local shadowPad = tonumber(options.shadowPad) or 4
    local shadowAlpha = tonumber(options.shadowAlpha) or .82

    if maskPath and frame.CreateMaskTexture and icon.AddMaskTexture and not frame["H3z0" .. key .. "Mask"] then
        local mask = frame:CreateMaskTexture(nil, "ARTWORK")
        mask:SetTexture(maskPath)
        mask:SetAllPoints(icon)
        icon:AddMaskTexture(mask)
        frame["H3z0" .. key .. "Mask"] = mask
    end

    local shadow = frame["H3z0" .. key .. "Shadow"]
    if shadowPath and not shadow then
        shadow = frame:CreateTexture(nil, "BACKGROUND", nil, -7)
        shadow:SetTexture(shadowPath)
        shadow:SetVertexColor(1, 1, 1, shadowAlpha)
        frame["H3z0" .. key .. "Shadow"] = shadow
    end

    local border = frame["H3z0" .. key .. "Border"]
    if borderPath and not border then
        border = frame:CreateTexture(nil, "OVERLAY", nil, 7)
        border:SetTexture(borderPath)
        frame["H3z0" .. key .. "Border"] = border
    end

    if shadow then
        shadow:ClearAllPoints()
        shadow:SetPoint("TOPLEFT", icon, "TOPLEFT", -shadowPad, shadowPad)
        shadow:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", shadowPad, -shadowPad)
    end
    if border then
        border:ClearAllPoints()
        if borderScale > 1 then
            local pad = 6
            border:SetPoint("TOPLEFT", icon, "TOPLEFT", -pad, pad)
            border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", pad, -pad)
        else
            border:SetAllPoints(icon)
        end
    end
end

function ns.AddRoundedIconSkin(frame, icon, shadowPad, shadowAlpha)
    AddIconSkin(frame, icon, {
        key = "Rounded",
        maskPath = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraMask.tga",
        borderPath = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorder.tga",
        borderScale = 1,
        shadowPath = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraShadow.tga",
        shadowPad = shadowPad,
        shadowAlpha = shadowAlpha,
    })
end

function ns.AddCastIconSkin(frame, icon, shadowPad, shadowAlpha)
    -- Match buffs/debuffs exactly: same mask, border and dark shadow.
    AddIconSkin(frame, icon, {
        key = "Cast",
        maskPath = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraMask.tga",
        borderPath = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraBorder.tga",
        borderScale = 1,
        shadowPath = "Interface\\AddOns\\H3z0Nameplates\\Media\\AuraShadow.tga",
        shadowPad = tonumber(shadowPad) or 4,
        shadowAlpha = tonumber(shadowAlpha) or .82,
    })
end

local events = CreateFrame("Frame")
events:RegisterEvent("ADDON_LOADED")
events:SetScript("OnEvent", function(_, _, addonName)
    if addonName ~= ADDON_NAME then return end
    H3z0NameplatesDB = type(H3z0NameplatesDB) == "table" and H3z0NameplatesDB or {}
    H3z0NameplatesDB.layout = type(H3z0NameplatesDB.layout) == "table" and H3z0NameplatesDB.layout or {}
    H3z0NameplatesDB.designer = type(H3z0NameplatesDB.designer) == "table" and H3z0NameplatesDB.designer or {}
end)
