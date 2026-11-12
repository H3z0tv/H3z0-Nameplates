local ADDON_NAME, ns = ...

local menu
local profileDialog
local effectsDialog
local combatGuard

-- Extra settings windows (Sizes, Friendly, Target & Threat). They are kept in
-- step when a value changes somewhere else: dragging in the preview, the main
-- sliders, reset or import.
local extraDialogs = {}
local function SyncExtraDialogs()
    for _, dialog in pairs(extraDialogs) do
        if dialog:IsShown() then dialog:Sync() end
    end
end
local function HideExtraDialogs()
    for _, dialog in pairs(extraDialogs) do
        if dialog:IsShown() then dialog:Hide() end
    end
end

-- Settings added after profile format 17. They are written on export, but a
-- profile string without them still imports and keeps the current value.
local NEW_PROFILE_KEYS = {
    "friendlyScale","friendlySizesEnabled","friendlyNpcNameOnly","friendlyNpcNameY","plateOffsetY","hpPercentOn","hpValueOn",
    "friendlyHealthWidth","friendlyHealthHeight","friendlyCastWidth","friendlyCastHeight",
    "friendlyNameFontSize","friendlyLevelFontSize","friendlyHealthPercentFontSize",
    "friendlyHealthValueFontSize","friendlyCastFontSize",
    "targetR","targetG","targetB","targetScale","nonTargetAlpha","threatMode",
}
-- Short fade-in when a window opens, so it does not pop in instantly.
local OPEN_FADE_SECONDS = 0.18
local function PlayOpenFade(frame)
    if not frame or not frame.CreateAnimationGroup then return end
    if not frame.h3z0OpenFade then
        local group = frame:CreateAnimationGroup()
        local alpha = group:CreateAnimation("Alpha")
        alpha:SetFromAlpha(0)
        alpha:SetToAlpha(1)
        alpha:SetDuration(OPEN_FADE_SECONDS)
        alpha:SetSmoothing("OUT")
        if group.SetToFinalAlpha then group:SetToFinalAlpha(true) end
        frame.h3z0OpenFade = group
    end
    pcall(frame.h3z0OpenFade.Stop, frame.h3z0OpenFade)
    pcall(frame.h3z0OpenFade.Play, frame.h3z0OpenFade)
end

local OPTIONAL_PROFILE_KEYS = {}
for _, key in ipairs(NEW_PROFILE_KEYS) do OPTIONAL_PROFILE_KEYS[key] = true end

local function Backdrop(frame, bg, border)
    frame:SetBackdrop({bgFile=ns.FLAT_TEXTURE, edgeFile=ns.FLAT_TEXTURE, edgeSize=1})
    frame:SetBackdropColor(bg,bg,bg+.008,.99)
    frame:SetBackdropBorderColor(border,border,border+.015,1)
end

local function Label(parent,text,template)
    local label=parent:CreateFontString(nil,"OVERLAY",template or "GameFontHighlight")
    label:SetText(text)
    return label
end

local function NumberString(value)
    value=tonumber(value) or 0
    return string.format("%.12g",value)
end

local function EncodeSection(name,db,keys)
    local values={}
    for _,key in ipairs(keys) do values[#values+1]=key.."="..NumberString(db and db[key]) end
    return name..":"..table.concat(values,";")
end

local function EscapeText(value)
    return (tostring(value or ""):gsub("([^%w%._%-])",function(char)
        return string.format("%%%02X",string.byte(char))
    end))
end

local function UnescapeText(value)
    return (tostring(value or ""):gsub("%%(%x%x)",function(hex)
        return string.char(tonumber(hex,16))
    end))
end

local function EncodeTextSection(name,db,keys)
    local values={}
    for _,key in ipairs(keys) do values[#values+1]=key.."="..EscapeText(db and db[key]) end
    return name..":"..table.concat(values,";")
end

local function ParseTextSection(text,allowed)
    local out={}
    for pair in string.gmatch(text or "","[^;]+") do
        local key,value=pair:match("^([%a%d_]+)=(.*)$")
        if not key or not allowed[key] then return nil,"Unknown or malformed media setting: "..tostring(pair) end
        out[key]=UnescapeText(value)
    end
    for key in pairs(allowed) do if out[key]==nil then return nil,"Missing media setting: "..key end end
    return out
end

local function AllowedKeyMap(keys)
    local map={}
    for _,key in ipairs(keys) do map[key]=true end
    return map
end

local function ParseSection(text,allowed)
    local out={}
    for pair in string.gmatch(text or "","[^;]+") do
        local key,value=pair:match("^([%a%d_]+)=([%+%-%.%deE]+)$")
        if not key or not allowed[key] then return nil,"Unknown or malformed setting: "..tostring(pair) end
        local number=tonumber(value)
        if not number or number~=number or number==math.huge or number==-math.huge then return nil,"Invalid value for "..key end
        out[key]=number
    end
    for key in pairs(allowed) do
        if out[key]==nil and not OPTIONAL_PROFILE_KEYS[key] then return nil,"Missing setting: "..key end
    end
    return out
end

local NAMEPLATE_LAYOUT_PREFIX_V14 = "H3Z0NAMEPLATES:NPLAYOUT:14"
local NAMEPLATE_LAYOUT_PREFIX_V15 = "H3Z0NAMEPLATES:NPLAYOUT:15"
local NAMEPLATE_LAYOUT_PREFIX_V16 = "H3Z0NAMEPLATES:NPLAYOUT:16"
local NAMEPLATE_LAYOUT_PREFIX = "H3Z0NAMEPLATES:NPLAYOUT:17"
local NAMEPLATE_LAYOUT_PREFIX_V13 = "H3Z0NAMEPLATES:NPLAYOUT:13"
local NAMEPLATE_LAYOUT_PREFIX_V12 = "H3Z0NAMEPLATES:NPLAYOUT:12"
local NAMEPLATE_LAYOUT_PREFIX_V11 = "H3Z0NAMEPLATES:NPLAYOUT:11"
local NAMEPLATE_LAYOUT_PREFIX_V10 = "H3Z0NAMEPLATES:NPLAYOUT:10"
local NAMEPLATE_LAYOUT_PREFIX_V9 = "H3Z0NAMEPLATES:NPLAYOUT:9"
local NAMEPLATE_LAYOUT_PREFIX_V8 = "H3Z0NAMEPLATES:NPLAYOUT:8"
local NAMEPLATE_LAYOUT_PREFIX_V7 = "H3Z0NAMEPLATES:NPLAYOUT:7"
local NAMEPLATE_LAYOUT_PREFIX_V6 = "H3Z0NAMEPLATES:NPLAYOUT:6"
local NAMEPLATE_LAYOUT_PREFIX_V5 = "H3Z0NAMEPLATES:NPLAYOUT:5"
local NAMEPLATE_LAYOUT_PREFIX_V4 = "H3Z0NAMEPLATES:NPLAYOUT:4"
local NAMEPLATE_LAYOUT_PREFIX_V3 = "H3Z0NAMEPLATES:NPLAYOUT:3"
local NAMEPLATE_LAYOUT_PREFIX_V2 = "H3Z0NAMEPLATES:NPLAYOUT:2"
local NAMEPLATE_LAYOUT_PREFIX_V1 = "H3Z0NAMEPLATES:NPLAYOUT:1"
local LEGACY_LAYOUT_PREFIX = "H3Z0UI:NPLAYOUT:1"
local DESIGNER_LAYOUT_KEYS_V1 = {
    "healthX","healthY","healthWidth","healthHeight","nameFontSize",
    "castX","castY","castWidth","castHeight","castFontSize",
    "iconSize","iconGap","shieldSize","shieldGap",
}
local DESIGNER_LAYOUT_KEYS_V6 = {
    "healthX","healthY","healthWidth","healthHeight",
    "nameX","nameY","nameFontSize",
    "levelX","levelY","levelFontSize",
    "healthPercentEnabled","healthPercentX","healthPercentY","healthPercentFontSize",
    "healthValueEnabled","healthValueX","healthValueY","healthValueFontSize",
    "castX","castY","castWidth","castHeight","castFontSize",
    "iconSize","iconGap","shieldSize","shieldGap",
}
local DESIGNER_LAYOUT_KEYS = {
    "healthX","healthY","healthWidth","healthHeight",
    "nameX","nameY","nameFontSize",
    "levelX","levelY","levelFontSize",
    "healthPercentX","healthPercentY","healthPercentFontSize",
    "healthValueX","healthValueY","healthValueFontSize",
    "castX","castY","castWidth","castHeight","castFontSize",
    "iconSize","iconGap","shieldSize","shieldGap",
}
local DESIGNER_INDICATOR_KEYS_V7 = {
    "questX","questY","questScale",
    "classificationX","classificationY","classificationScale",
}
local DESIGNER_INDICATOR_KEYS = {}
for _,key in ipairs(DESIGNER_INDICATOR_KEYS_V7) do DESIGNER_INDICATOR_KEYS[#DESIGNER_INDICATOR_KEYS+1]=key end
for _,key in ipairs({"raidTargetX","raidTargetY","raidTargetScale"}) do DESIGNER_INDICATOR_KEYS[#DESIGNER_INDICATOR_KEYS+1]=key end
local DESIGNER_COLOR_KEYS = {
    "helpfulR","helpfulG","helpfulB","harmfulR","harmfulG","harmfulB",
    "shieldR","shieldG","shieldB",
    "interruptedR","interruptedG","interruptedB",
}
local DESIGNER_PROFILE_KEYS_V3 = {}
for _,key in ipairs(DESIGNER_LAYOUT_KEYS_V6) do DESIGNER_PROFILE_KEYS_V3[#DESIGNER_PROFILE_KEYS_V3+1]=key end
for _,key in ipairs(DESIGNER_COLOR_KEYS) do DESIGNER_PROFILE_KEYS_V3[#DESIGNER_PROFILE_KEYS_V3+1]=key end
local DESIGNER_PROFILE_KEYS_V4 = {}
for _,key in ipairs(DESIGNER_PROFILE_KEYS_V3) do DESIGNER_PROFILE_KEYS_V4[#DESIGNER_PROFILE_KEYS_V4+1]=key end
for _,key in ipairs(DESIGNER_INDICATOR_KEYS) do DESIGNER_PROFILE_KEYS_V4[#DESIGNER_PROFILE_KEYS_V4+1]=key end
local DESIGNER_SETTINGS_KEYS_V5 = {
    "friendlyPlayerMode",
    "enemyNameplatesEnabled","friendlyNpcNameplatesEnabled","alwaysShowNameplates",
    "offscreenNameplates","stackingNameplates","friendlyPlayerClassColor",
}
local DESIGNER_PROFILE_KEYS = {}
for _,key in ipairs(DESIGNER_LAYOUT_KEYS) do DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1]=key end
for _,key in ipairs(DESIGNER_COLOR_KEYS) do DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1]=key end
for _,key in ipairs(DESIGNER_INDICATOR_KEYS) do DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1]=key end
local DESIGNER_PROFILE_KEYS_V9 = {}
for _,key in ipairs(DESIGNER_PROFILE_KEYS) do DESIGNER_PROFILE_KEYS_V9[#DESIGNER_PROFILE_KEYS_V9+1]=key end
DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1]="globalScale"
local DESIGNER_PROFILE_KEYS_V10 = {}
for _,key in ipairs(DESIGNER_PROFILE_KEYS) do DESIGNER_PROFILE_KEYS_V10[#DESIGNER_PROFILE_KEYS_V10+1]=key end
DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1]="skinFriendlyEnabled"
-- Preserve the v12 schema for legacy profile imports.
-- Movable Combo Points settings were introduced in v13.
local DESIGNER_PROFILE_KEYS_V12 = {}
for _,key in ipairs(DESIGNER_PROFILE_KEYS) do
    DESIGNER_PROFILE_KEYS_V12[#DESIGNER_PROFILE_KEYS_V12+1] = key
end
for _,key in ipairs({"comboX","comboY","comboScale"}) do
    DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1] = key
end
-- v13 media imports have two entries; v14 adds the Combo Points texture.
local DESIGNER_PROFILE_KEYS_V15 = {}
for _,key in ipairs(DESIGNER_PROFILE_KEYS) do DESIGNER_PROFILE_KEYS_V15[#DESIGNER_PROFILE_KEYS_V15+1]=key end
DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1]="comboEnabled"
local MEDIA_PROFILE_KEYS_V13 = {"healthTexture","castTexture"}
local MEDIA_PROFILE_KEYS_V16 = {"healthTexture","castTexture","comboTexture"}
local MEDIA_PROFILE_KEYS = {"healthTexture","castTexture","comboTexture","incomingHealTexture","absorbTexture","damageEchoTexture"}
local DESIGNER_PROFILE_KEYS_V16 = {}
for _, key in ipairs(DESIGNER_PROFILE_KEYS) do
    DESIGNER_PROFILE_KEYS_V16[#DESIGNER_PROFILE_KEYS_V16+1] = key
end
for _, key in ipairs({"incomingHealsEnabled", "absorbsEnabled", "damageEchoEnabled", "damageEchoDuration", "damageEchoOpacity"}) do
    DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1] = key
end
for _, key in ipairs(NEW_PROFILE_KEYS) do
    DESIGNER_PROFILE_KEYS[#DESIGNER_PROFILE_KEYS+1] = key
end
local DESIGNER_PROFILE_KEYS_V7 = {}
for _,key in ipairs(DESIGNER_LAYOUT_KEYS) do DESIGNER_PROFILE_KEYS_V7[#DESIGNER_PROFILE_KEYS_V7+1]=key end
for _,key in ipairs(DESIGNER_COLOR_KEYS) do DESIGNER_PROFILE_KEYS_V7[#DESIGNER_PROFILE_KEYS_V7+1]=key end
for _,key in ipairs(DESIGNER_INDICATOR_KEYS_V7) do DESIGNER_PROFILE_KEYS_V7[#DESIGNER_PROFILE_KEYS_V7+1]=key end
local DESIGNER_PROFILE_KEYS_V5 = {}
for _,key in ipairs(DESIGNER_PROFILE_KEYS_V4) do DESIGNER_PROFILE_KEYS_V5[#DESIGNER_PROFILE_KEYS_V5+1]=key end
for _,key in ipairs(DESIGNER_SETTINGS_KEYS_V5) do DESIGNER_PROFILE_KEYS_V5[#DESIGNER_PROFILE_KEYS_V5+1]=key end
local AURA_LAYOUT_KEYS_V8 = {
    "buffX","buffY","buffScale",
    "debuffX","debuffY","debuffScale",
    "ccX","ccY","ccScale",
}
-- v12 deliberately stores geometry only. Aura selection is completely native
-- Blizzard state and has no H3z0 source/filter option.
local AURA_LAYOUT_KEYS = {}
for _,key in ipairs(AURA_LAYOUT_KEYS_V8) do AURA_LAYOUT_KEYS[#AURA_LAYOUT_KEYS+1]=key end
local AURA_LAYOUT_KEYS_V11 = {}
for _,key in ipairs(AURA_LAYOUT_KEYS_V8) do AURA_LAYOUT_KEYS_V11[#AURA_LAYOUT_KEYS_V11+1]=key end
AURA_LAYOUT_KEYS_V11[#AURA_LAYOUT_KEYS_V11+1]="debuffSourceMode"
local DESIGNER_PROFILE_ALLOWED=AllowedKeyMap(DESIGNER_PROFILE_KEYS)
local DESIGNER_PROFILE_ALLOWED_V16=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V16)
local DESIGNER_PROFILE_ALLOWED_V15=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V15)
local DESIGNER_PROFILE_ALLOWED_V14=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V16)
for _, legacyKey in ipairs({"castR","castG","castB"}) do DESIGNER_PROFILE_ALLOWED_V14[legacyKey]=true end
local DESIGNER_PROFILE_ALLOWED_V12=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V12)
local DESIGNER_PROFILE_ALLOWED_V10=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V10)
local DESIGNER_PROFILE_ALLOWED_V9=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V9)
local DESIGNER_PROFILE_ALLOWED_V7=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V7)
local DESIGNER_PROFILE_ALLOWED_V5=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V5)
local DESIGNER_PROFILE_ALLOWED_V4=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V4)
local DESIGNER_PROFILE_ALLOWED_V3=AllowedKeyMap(DESIGNER_PROFILE_KEYS_V3)
local DESIGNER_LAYOUT_ALLOWED_V6=AllowedKeyMap(DESIGNER_LAYOUT_KEYS_V6)
local DESIGNER_LAYOUT_ALLOWED_V1=AllowedKeyMap(DESIGNER_LAYOUT_KEYS_V1)
local AURA_LAYOUT_ALLOWED=AllowedKeyMap(AURA_LAYOUT_KEYS)
local AURA_LAYOUT_ALLOWED_V11=AllowedKeyMap(AURA_LAYOUT_KEYS_V11)
local AURA_LAYOUT_ALLOWED_V8=AllowedKeyMap(AURA_LAYOUT_KEYS_V8)
local MEDIA_PROFILE_ALLOWED=AllowedKeyMap(MEDIA_PROFILE_KEYS)
local MEDIA_PROFILE_ALLOWED_V16=AllowedKeyMap(MEDIA_PROFILE_KEYS_V16)
local MEDIA_PROFILE_ALLOWED_V13=AllowedKeyMap(MEDIA_PROFILE_KEYS_V13)

local function ExportNameplateLayout()
    local designer=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or {}
    local aura=ns.GetDB and ns.GetDB() or {}
    return table.concat({
        NAMEPLATE_LAYOUT_PREFIX,
        EncodeSection("D",designer,DESIGNER_PROFILE_KEYS),
        EncodeSection("A",aura,AURA_LAYOUT_KEYS),
        EncodeTextSection("M",designer,MEDIA_PROFILE_KEYS),
    },"|")
end

local function ImportNameplateLayout(value)
    value=(value or ""):gsub("%s+","")
    local prefix,designerText,auraText,mediaText=value:match("^([^|]+)|D:([^|]+)|A:([^|]+)|M:(.+)$")
    if not prefix then prefix,designerText,auraText=value:match("^([^|]+)|D:([^|]+)|A:(.+)$") end
    if prefix~=NAMEPLATE_LAYOUT_PREFIX and prefix~=NAMEPLATE_LAYOUT_PREFIX_V16 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V15 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V14 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V13 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V12 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V11 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V10 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V9 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V8 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V7 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V6 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V5 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V4 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V3 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V2 and prefix~=NAMEPLATE_LAYOUT_PREFIX_V1 and prefix~=LEGACY_LAYOUT_PREFIX then
        return false,"Not an H3z0 Nameplates layout string."
    end
    local designerAllowed
    if prefix==NAMEPLATE_LAYOUT_PREFIX then
        designerAllowed=DESIGNER_PROFILE_ALLOWED
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V16 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V16
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V15 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V15
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V14 or prefix==NAMEPLATE_LAYOUT_PREFIX_V13 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V14
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V12 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V12
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V11 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V12
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V10 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V10
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V9 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V9
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V8 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V9
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V7 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V7
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V6 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V4
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V5 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V5
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V4 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V4
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V3 then
        designerAllowed=DESIGNER_PROFILE_ALLOWED_V3
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V2 then
        designerAllowed=DESIGNER_LAYOUT_ALLOWED_V6
    else
        designerAllowed=DESIGNER_LAYOUT_ALLOWED_V1
    end
    local designer,err=ParseSection(designerText,designerAllowed)
    if not designer then return false,err end
    local auraAllowed
    if prefix==NAMEPLATE_LAYOUT_PREFIX or prefix==NAMEPLATE_LAYOUT_PREFIX_V16 or prefix==NAMEPLATE_LAYOUT_PREFIX_V15 or prefix==NAMEPLATE_LAYOUT_PREFIX_V14 or prefix==NAMEPLATE_LAYOUT_PREFIX_V13 or prefix==NAMEPLATE_LAYOUT_PREFIX_V12 then
        auraAllowed=AURA_LAYOUT_ALLOWED
    elseif prefix==NAMEPLATE_LAYOUT_PREFIX_V11 or prefix==NAMEPLATE_LAYOUT_PREFIX_V10 or prefix==NAMEPLATE_LAYOUT_PREFIX_V9 then
        auraAllowed=AURA_LAYOUT_ALLOWED_V11
    else
        auraAllowed=AURA_LAYOUT_ALLOWED_V8
    end
    local aura; aura,err=ParseSection(auraText,auraAllowed)
    if not aura then return false,err end
    local media
    if prefix==NAMEPLATE_LAYOUT_PREFIX or prefix==NAMEPLATE_LAYOUT_PREFIX_V16 or prefix==NAMEPLATE_LAYOUT_PREFIX_V15 or prefix==NAMEPLATE_LAYOUT_PREFIX_V14 or prefix==NAMEPLATE_LAYOUT_PREFIX_V13 or prefix==NAMEPLATE_LAYOUT_PREFIX_V12 or prefix==NAMEPLATE_LAYOUT_PREFIX_V11 or prefix==NAMEPLATE_LAYOUT_PREFIX_V10 then
        local mediaAllowed = prefix==NAMEPLATE_LAYOUT_PREFIX and MEDIA_PROFILE_ALLOWED
            or (prefix==NAMEPLATE_LAYOUT_PREFIX_V16 or prefix==NAMEPLATE_LAYOUT_PREFIX_V15 or prefix==NAMEPLATE_LAYOUT_PREFIX_V14) and MEDIA_PROFILE_ALLOWED_V16
            or MEDIA_PROFILE_ALLOWED_V13
        media,err=ParseTextSection(mediaText,mediaAllowed)
        if not media then return false,err end
    end
    local designerDB=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
    local auraDB=ns.GetDB and ns.GetDB() or nil
    if type(designerDB)~="table" or type(auraDB)~="table" then return false,"Nameplate layout is unavailable." end
    -- Older profiles carried duplicate Blizzard CVars and H3z0-owned health
    -- visibility toggles. Accept them, but import only settings H3z0 owns in v7.
    for key,val in pairs(designer) do
        if DESIGNER_PROFILE_ALLOWED[key] then designerDB[key]=val end
    end
    if designer.comboEnabled == nil then designerDB.comboEnabled = 1 end
    if media then for key,val in pairs(media) do designerDB[key]=val end end
    for key,val in pairs(aura) do
        if AURA_LAYOUT_ALLOWED[key] then auraDB[key]=val end
    end
    auraDB.debuffSourceMode=nil
    if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner() end
    if ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
    if ns.RefreshNameplateDesignerPreview then ns.RefreshNameplateDesignerPreview() end
    SyncExtraDialogs()
    return true
end

local function ShowProfileDialog(mode)
    if not profileDialog then
        profileDialog=CreateFrame("Frame","H3z0NameplatesLayoutDialog",UIParent,"BackdropTemplate")
        profileDialog:SetSize(600,220)
        profileDialog:SetPoint("CENTER")
        profileDialog:SetFrameStrata("FULLSCREEN_DIALOG")
        profileDialog:SetFrameLevel(500)
        profileDialog:SetClampedToScreen(true)
        profileDialog:SetToplevel(true)
        Backdrop(profileDialog,.025,.18)

        profileDialog.title=Label(profileDialog,"Nameplate Layout","GameFontNormalLarge")
        profileDialog.title:SetPoint("TOPLEFT",18,-16)
        profileDialog.title:SetTextColor(1,.49,.16)

        profileDialog.help=Label(profileDialog,"","GameFontHighlightSmall")
        profileDialog.help:SetPoint("TOPLEFT",18,-44)
        profileDialog.help:SetTextColor(.72,.76,.82)

        local scroll=CreateFrame("ScrollFrame",nil,profileDialog,"InputScrollFrameTemplate")
        scroll:SetPoint("TOPLEFT",18,-70)
        scroll:SetPoint("BOTTOMRIGHT",-18,52)
        profileDialog.editBox=scroll.EditBox
        profileDialog.editBox:SetFontObject("ChatFontNormal")
        profileDialog.editBox:SetAutoFocus(false)
        profileDialog.editBox:SetMaxLetters(16000)

        profileDialog.status=Label(profileDialog,"","GameFontHighlightSmall")
        profileDialog.status:SetPoint("BOTTOMLEFT",18,18)

        profileDialog.action=CreateFrame("Button",nil,profileDialog,"BackdropTemplate")
        profileDialog.action:SetSize(110,30)
        profileDialog.action:SetPoint("BOTTOMRIGHT",-54,12)
        Backdrop(profileDialog.action,.075,.24)
        profileDialog.action:SetBackdropBorderColor(1,.24,.09,1)
        profileDialog.actionText=Label(profileDialog.action,"","GameFontNormal")
        profileDialog.actionText:SetPoint("CENTER")
        profileDialog.actionText:SetTextColor(1,.82,.60)

        local close=CreateFrame("Button",nil,profileDialog,"UIPanelCloseButton")
        close:SetPoint("TOPRIGHT",-3,-3)
        profileDialog:Hide()
        table.insert(UISpecialFrames,profileDialog:GetName())
    end

    local box=profileDialog.editBox
    profileDialog.status:SetText("")
    profileDialog.status:SetTextColor(.75,.78,.82)
    profileDialog.action:SetScript("OnClick",nil)

    if mode=="export" then
        profileDialog.title:SetText("Export H3z0 Nameplates Profile")
        profileDialog.help:SetText("Ctrl+C to copy this layout string.")
        profileDialog.actionText:SetText("SELECT ALL")
        box:SetText(ExportNameplateLayout())
        box:SetCursorPosition(0)
        box:HighlightText()
        box:SetFocus()
        profileDialog.action:SetScript("OnClick",function()
            box:SetFocus()
            box:HighlightText()
        end)
    else
        profileDialog.title:SetText("Import H3z0 Nameplates Profile")
    profileDialog.help:SetText("Paste a profile string, then select IMPORT.")
        profileDialog.actionText:SetText("IMPORT")
        box:SetText("")
        box:SetFocus()
        profileDialog.action:SetScript("OnClick",function()
            local ok,err=ImportNameplateLayout(box:GetText())
            if ok then
                profileDialog.status:SetText("Nameplate layout imported successfully.")
                profileDialog.status:SetTextColor(.35,1,.45)
            else
                profileDialog.status:SetText(err or "Import failed.")
                profileDialog.status:SetTextColor(1,.30,.25)
            end
        end)
    end

    profileDialog:Show()
    profileDialog:Raise()
end

local function OpenDesignerColorPicker(keys, swatch)
    -- H3z0Nameplates menu itself uses FULLSCREEN_DIALOG. Force Blizzard's
    -- shared ColorPickerFrame above it, otherwise the picker opens invisibly
    -- behind the designer window.
    if ColorPickerFrame then
        if ColorPickerFrame.SetFrameStrata then pcall(ColorPickerFrame.SetFrameStrata, ColorPickerFrame, "TOOLTIP") end
        if ColorPickerFrame.SetFrameLevel then pcall(ColorPickerFrame.SetFrameLevel, ColorPickerFrame, 1000) end
    end

    local db=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB()
    if not db then return end
    local r,g,b=db[keys[1]] or 1,db[keys[2]] or 1,db[keys[3]] or 1
    local function Apply(nr,ng,nb)
        local current=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB()
        if not current then return end
        current[keys[1]],current[keys[2]],current[keys[3]]=nr,ng,nb
        swatch:SetColorTexture(nr,ng,nb,1)
        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner() end
    end
    if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({
            r=r,g=g,b=b,
            swatchFunc=function()
                local nr,ng,nb=ColorPickerFrame:GetColorRGB()
                Apply(nr,ng,nb)
            end,
            cancelFunc=function(previous)
                if previous then Apply(previous.r or r,previous.g or g,previous.b or b) else Apply(r,g,b) end
            end,
        })
        if ColorPickerFrame.Raise then pcall(ColorPickerFrame.Raise, ColorPickerFrame) end
    else
        ColorPickerFrame:SetColorRGB(r,g,b)
        ColorPickerFrame.func=function()
            local nr,ng,nb=ColorPickerFrame:GetColorRGB()
            Apply(nr,ng,nb)
        end
        ColorPickerFrame.cancelFunc=function() Apply(r,g,b) end
        ColorPickerFrame:Show()
        if ColorPickerFrame.Raise then pcall(ColorPickerFrame.Raise, ColorPickerFrame) end
    end
end

local function MakeColorButton(parent,labelText,keys,x,y)
    local frame=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    frame:SetSize(220,30)
    frame:SetPoint("TOPLEFT",x,y)
    Backdrop(frame,.05,.18)

    local swatchButton=CreateFrame("Button",nil,frame,"BackdropTemplate")
    swatchButton:SetSize(22,22)
    swatchButton:SetPoint("LEFT",4,0)
    Backdrop(swatchButton,.03,.65)
    local swatch=swatchButton:CreateTexture(nil,"ARTWORK")
    swatch:SetPoint("TOPLEFT",2,-2)
    swatch:SetPoint("BOTTOMRIGHT",-2,2)

    local textLabel=Label(frame,labelText,"GameFontHighlightSmall")
    textLabel:SetPoint("LEFT",swatchButton,"RIGHT",7,0)

    local function Sync()
        local db=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or {}
        swatch:SetColorTexture(db[keys[1]] or 1,db[keys[2]] or 1,db[keys[3]] or 1,1)
    end
    swatchButton:SetScript("OnClick",function() OpenDesignerColorPicker(keys,swatch) end)
    frame.Sync=Sync
    Sync()
    return frame
end

local designerPreview
-- The layout editor is intentionally magnified 2x for precise dragging. All
-- saved coordinates and drag deltas are converted back to live layout units.
local DESIGNER_PREVIEW_ZOOM = 2.0
local HEALTH_MASK = "Interface\\AddOns\\H3z0Nameplates\\Media\\NameplateHealthMask.tga"
local CAST_MASK = "Interface\\AddOns\\H3z0Nameplates\\Media\\NameplateCastMask.tga"
local PREVIEW_BORDER_NORMAL = "Interface\\AddOns\\H3z0Nameplates\\Media\\NameplateBorderNormal.tga"
local PREVIEW_BAR_SOURCE_WIDTH, PREVIEW_BAR_SOURCE_HEIGHT = 854, 98
local PREVIEW_BORDER_SPEC = { width=926, height=170 }
local DESIGNER_WHITE = ns.FLAT_TEXTURE or "Interface\\Buttons\\WHITE8X8"
local MENU_BACKGROUND = "Interface\\AddOns\\H3z0Nameplates\\Media\\MenuBackground.tga"
local AURA_LAYOUT_DEFAULTS = {
    buffX=-142.217852125, buffY=-0.0323179589125, buffScale=0.69,
    debuffX=142.883903698, debuffY=-0.0198954589952, debuffScale=0.69,
    ccX=-17.2216243707, ccY=56.091698481, ccScale=1.57306456669,
}
local function GetAuraLayoutDB()
    local db = ns.GetDB and ns.GetDB() or nil
    if type(db) ~= "table" then
        H3z0NameplatesDB = type(H3z0NameplatesDB) == "table" and H3z0NameplatesDB or {}
        H3z0NameplatesDB.layout = type(H3z0NameplatesDB.layout) == "table" and H3z0NameplatesDB.layout or {}
        db = H3z0NameplatesDB.layout
    end
    for key,value in pairs(AURA_LAYOUT_DEFAULTS) do
        if db[key] == nil then db[key] = value end
    end
    -- Pre-v12 profiles carried this H3z0 selection setting. Blizzard now owns
    -- the complete aura selection, so discard it on first use.
    db.debuffSourceMode=nil
    return db
end


local function AttachPreviewMask(texture,parent,path)
    if parent.CreateMaskTexture and texture.AddMaskTexture then
        local mask=parent:CreateMaskTexture()
        local ok=pcall(mask.SetTexture,mask,path,"CLAMPTOBLACKADDITIVE","CLAMPTOBLACKADDITIVE")
        if not ok then pcall(mask.SetTexture,mask,path) end
        mask:SetAllPoints(parent)
        if pcall(texture.AddMaskTexture,texture,mask) then return mask end
    end
end

local function CreatePreviewBorderSkin(shell)
    local frame=CreateFrame("Frame",nil,shell)
    frame:SetPoint("CENTER",shell,"CENTER",0,0)
    frame:SetFrameLevel(shell:GetFrameLevel()+1)
    frame.left=frame:CreateTexture(nil,"BACKGROUND",nil,0)
    frame.middle=frame:CreateTexture(nil,"BACKGROUND",nil,0)
    frame.right=frame:CreateTexture(nil,"BACKGROUND",nil,0)
    return frame
end

local function PreviewSetPiece(tex,path,u1,u2)
    tex:SetTexture(path); tex:SetTexCoord(u1,u2,0,1); tex:SetVertexColor(1,1,1,1); tex:SetAlpha(1)
end

local function PreviewLayoutBorder(frame,shell)
    local s=PREVIEW_BORDER_SPEC
    local shellW,shellH=shell:GetWidth() or 1,shell:GetHeight() or 1
    local scale=shellH/PREVIEW_BAR_SOURCE_HEIGHT
    local outerW=shellW+(s.width-PREVIEW_BAR_SOURCE_WIDTH)*scale
    local outerH=s.height*scale
    local capSrc=s.height*.5
    local capOut=outerH*.5
    local midOut=math.max(1,outerW-capOut*2)
    local uL,uR=capSrc/s.width,(s.width-capSrc)/s.width
    frame:ClearAllPoints(); frame:SetPoint("CENTER",shell,"CENTER",0,0); frame:SetSize(outerW,outerH)
    PreviewSetPiece(frame.left,PREVIEW_BORDER_NORMAL,0,uL)
    PreviewSetPiece(frame.middle,PREVIEW_BORDER_NORMAL,uL,uR)
    PreviewSetPiece(frame.right,PREVIEW_BORDER_NORMAL,uR,1)
    frame.left:ClearAllPoints(); frame.left:SetPoint("TOPLEFT",frame,"TOPLEFT",0,0); frame.left:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",0,0); frame.left:SetWidth(capOut)
    frame.middle:ClearAllPoints(); frame.middle:SetPoint("TOPLEFT",frame.left,"TOPRIGHT",0,0); frame.middle:SetPoint("BOTTOMLEFT",frame.left,"BOTTOMRIGHT",0,0); frame.middle:SetWidth(midOut)
    frame.right:ClearAllPoints(); frame.right:SetPoint("TOPLEFT",frame.middle,"TOPRIGHT",0,0); frame.right:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",0,0)
    frame:Show()
end


local function PreviewBar(parent,path)
    local shell=CreateFrame("Frame",nil,parent)
    local border=CreatePreviewBorderSkin(shell)
    local bar=CreateFrame("StatusBar",nil,shell)
    bar:SetFrameLevel(shell:GetFrameLevel()+2)
    bar:SetAllPoints(shell)
    bar:SetStatusBarTexture(DESIGNER_WHITE)
    bar:SetMinMaxValues(0,1); bar:SetValue(1)
    local bg=bar:CreateTexture(nil,"BACKGROUND")
    bg:SetAllPoints(); bg:SetColorTexture(1,1,1,1)
    local fill=bar:GetStatusBarTexture()
    if not AttachPreviewMask(fill,bar,path) then bar:SetStatusBarTexture(path) end
    if not AttachPreviewMask(bg,bar,path) then bg:SetTexture(path) end
    return shell,border,border,bar,bg
end

local function CreateDesignerAuraIcon(parent, texture, label, size)
    local frame=CreateFrame("Frame",nil,parent)
    frame:SetSize(size or 25,size or 25)
    local icon=frame:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(frame)
    icon:SetTexture(texture or 135846)
    icon:SetTexCoord(.08,.92,.08,.92)
    if ns.AddCastIconSkin then ns.AddCastIconSkin(frame,icon,4,.82) end
    if label then
        local text=frame:CreateFontString(nil,"OVERLAY","GameFontHighlightSmall")
        local font,fontSize=text:GetFont()
        if font and fontSize then
            text:SetFont(font,fontSize*(tonumber(ns.NAMEPLATE_AURA_DURATION_FONT_SCALE) or 2),"OUTLINE")
        end
        text:SetPoint("CENTER")
        text:SetText(label)
        text:SetTextColor(1,.82,0,1)
    end
    return frame
end

local function CreateDesignerAuraGroup(parent, kind)
    local group=CreateFrame("Frame",nil,parent)
    local textures
    if kind=="buff" then
        textures={135824,135932}
    elseif kind=="debuff" then
        textures={135818,136096,136197}
    else
        textures={136071}
    end
    -- Use the exact same source metrics as the live H3z0 secure containers.
    local iconSize
    local gap
    if kind=="cc" then
        iconSize = tonumber(ns.NAMEPLATE_CC_ICON_SIZE) or 35
        gap = tonumber(ns.NAMEPLATE_CC_ICON_GAP) or 2
    else
        iconSize = tonumber(ns.NAMEPLATE_AURA_ICON_SIZE) or 32
        gap = tonumber(ns.NAMEPLATE_AURA_ICON_GAP) or 4
    end
    group.icons={}
    for i,texture in ipairs(textures) do
        -- Show a real timer sample at the same relative size as live auras.
        local label=(i==1 and (kind=="cc" and "1.8" or "9")) or nil
        local icon=CreateDesignerAuraIcon(group,texture,label,iconSize)
        group.icons[i]=icon
    end
    local count=#group.icons
    group:SetSize(count*iconSize + math.max(0,count-1)*gap,iconSize)
    -- Buffs mirror the live container: RIGHT origin + grow LEFT.
    -- Debuffs/CC use LEFT origin + grow RIGHT.
    for i,icon in ipairs(group.icons) do
        icon:ClearAllPoints()
        if kind == "buff" then
            icon:SetPoint("RIGHT",group,"RIGHT",-(i-1)*(iconSize+gap),0)
        else
            icon:SetPoint("LEFT",group,"LEFT",(i-1)*(iconSize+gap),0)
        end
    end
    group.H3z0AuraKind=kind
    -- Preview-only marker. The layout editor must never inherit the live
    -- designer global scale when its aura groups are rebuilt after reopening
    -- the menu; only the per-group buff/debuff/CC scale belongs here.
    group.H3z0PreviewContainer=true
    return group
end

local function LayoutDesignerAuraGroup(group, kind)
    if not group or type(group.icons) ~= "table" then return end
    local iconSize, gap
    if kind == "cc" then
        iconSize = tonumber(ns.NAMEPLATE_CC_ICON_SIZE) or 35
        gap = tonumber(ns.NAMEPLATE_CC_ICON_GAP) or 2
    else
        iconSize = tonumber(ns.NAMEPLATE_AURA_ICON_SIZE) or 32
        gap = tonumber(ns.NAMEPLATE_AURA_ICON_GAP) or 4
    end
    local count = #group.icons
    group:SetSize(math.max(iconSize, count * iconSize + math.max(0, count - 1) * gap), iconSize)
    for i, icon in ipairs(group.icons) do
        icon:SetScale(1)
        icon:SetSize(iconSize, iconSize)
        icon:ClearAllPoints()
        if kind == "buff" then
            icon:SetPoint("RIGHT", group, "RIGHT", -(i - 1) * (iconSize + gap), 0)
        else
            icon:SetPoint("LEFT", group, "LEFT", (i - 1) * (iconSize + gap), 0)
        end
    end
end

local function ClampDesignerValue(v, lo, hi)
    v=tonumber(v) or lo
    if v<lo then return lo end
    if v>hi then return hi end
    return v
end

local function DesignerLiveDelta(v)
    return (tonumber(v) or 0) / DESIGNER_PREVIEW_ZOOM
end

local function MakeDesignerMover(holder, shell, kind)
    local mover=CreateFrame("Frame",nil,holder,"BackdropTemplate")
    local moverTarget=shell.H3z0MoverTarget or shell
    mover:SetAllPoints(moverTarget)
    local holderLevel = holder.GetFrameLevel and holder:GetFrameLevel() or 0
    local shellLevel = shell.GetFrameLevel and shell:GetFrameLevel() or holderLevel
    mover:SetFrameLevel(math.max(holderLevel, shellLevel) + 50)
    mover:EnableMouse(true)
    mover:SetBackdrop({edgeFile=DESIGNER_WHITE,edgeSize=1})
    mover:SetBackdropBorderColor(0,0,0,0)

    local isAura = kind=="buff" or kind=="debuff" or kind=="cc"
    local xKey = kind=="buff" and "buffX" or kind=="debuff" and "debuffX" or kind=="cc" and "ccX" or nil
    local yKey = kind=="buff" and "buffY" or kind=="debuff" and "debuffY" or kind=="cc" and "ccY" or nil
    local scaleKey = kind=="buff" and "buffScale" or kind=="debuff" and "debuffScale" or kind=="cc" and "ccScale" or nil

    local function CurrentDB()
        if isAura then return GetAuraLayoutDB() end
        return ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
    end

    local function Cursor()
        local x,y=GetCursorPosition()
        local scale=holder:GetEffectiveScale() or 1
        if scale<=0 then scale=1 end
        return x/scale,y/scale
    end

    local function ApplyLive()
        if isAura then
            if ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
        else
            if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner() end
            -- Aura coordinates are relative to the visible custom healthbar.
            -- Moving HEALTH therefore refreshes the live aura containers too.
            if kind=="health" and ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
        end
    end

    local function Stop(self)
        self.dragMode=nil
        self:SetScript("OnUpdate",nil)
        self:SetBackdropBorderColor(.20,.70,1,.75)
        ApplyLive()
        SyncExtraDialogs()
    end

    mover:SetScript("OnEnter",function(self)
        if not self.dragMode then self:SetBackdropBorderColor(.20,.70,1,.75) end
    end)
    mover:SetScript("OnLeave",function(self)
        if not self.dragMode then self:SetBackdropBorderColor(0,0,0,0) end
    end)

    mover:SetScript("OnMouseDown",function(self,button)
        local db=CurrentDB()
        if not db then return end
        local cx,cy=Cursor()
        self.startX,self.startY=cx,cy
        if button=="LeftButton" then
            self.dragMode="move"
            if isAura then
                self.baseX,self.baseY=tonumber(db[xKey]) or 0,tonumber(db[yKey]) or 0
            elseif kind=="health" then
                self.baseX,self.baseY=db.healthX,db.healthY
            else
                self.baseX,self.baseY=db.castX,db.castY
            end
        elseif button=="RightButton" then
            self.dragMode="scale"
            if isAura then
                self.baseScale=tonumber(db[scaleKey]) or 1
            elseif kind=="health" then
                self.baseW,self.baseH=db.healthWidth,db.healthHeight
            else
                self.baseW,self.baseH=db.castWidth,db.castHeight
                self.baseFont=db.castFontSize
                self.baseIcon=db.iconSize
                self.baseIconGap=db.iconGap
                self.baseShield=db.shieldSize
                self.baseShieldGap=db.shieldGap
            end
        else
            return
        end
        self:SetBackdropBorderColor(1,.55,.15,1)
        self:SetScript("OnUpdate",function(frame)
            if frame.dragMode=="move" and not IsMouseButtonDown("LeftButton") then Stop(frame); return end
            if frame.dragMode=="scale" and not IsMouseButtonDown("RightButton") then Stop(frame); return end
            local x,y=Cursor()
            local dx,dy=DesignerLiveDelta(x-frame.startX),DesignerLiveDelta(y-frame.startY)
            local current=CurrentDB()
            if not current then Stop(frame); return end
            if frame.dragMode=="move" then
                if isAura then
                    -- Aura groups may intentionally sit well outside the healthbar.
                    -- Keep a generous editor range so Buffs can be pulled far left
                    -- and Debuffs far right without hitting an artificial wall.
                    current[xKey]=ClampDesignerValue(frame.baseX+dx,-800,800)
                    current[yKey]=ClampDesignerValue(frame.baseY+dy,-400,400)
                elseif kind=="health" then
                    current.healthX=ClampDesignerValue(frame.baseX+dx,-250,250)
                    current.healthY=ClampDesignerValue(frame.baseY+dy,-150,150)
                else
                    current.castX=ClampDesignerValue(frame.baseX+dx,-250,250)
                    current.castY=ClampDesignerValue(frame.baseY+dy,-150,150)
                end
            else
                local factor=ClampDesignerValue(1+(dx/140),.35,3.0)
                if isAura then
                    current[scaleKey]=ClampDesignerValue(frame.baseScale*factor,.35,3.0)
                elseif kind=="health" then
                    current.healthWidth=ClampDesignerValue(frame.baseW*factor,70,360)
                    current.healthHeight=ClampDesignerValue(frame.baseH*factor,8,48)
                else
                    current.castWidth=ClampDesignerValue(frame.baseW*factor,70,360)
                    current.castHeight=ClampDesignerValue(frame.baseH*factor,6,40)
                    current.castFontSize=ClampDesignerValue(frame.baseFont*factor,7,26)
                    current.iconSize=ClampDesignerValue(frame.baseIcon*factor,8,80)
                    current.iconGap=ClampDesignerValue(frame.baseIconGap*factor,0,24)
                    current.shieldSize=ClampDesignerValue(frame.baseShield*factor,8,80)
                    current.shieldGap=ClampDesignerValue(frame.baseShieldGap*factor,0,24)
                end
            end
            if ns.RefreshNameplateDesignerPreview then ns.RefreshNameplateDesignerPreview() end
        end)
    end)
    mover:SetScript("OnMouseUp",function(self) Stop(self) end)
    return mover
end

local TEXT_MOVER_KEYS = {
    name={x="nameX",y="nameY",font="nameFontSize"},
    level={x="levelX",y="levelY",font="levelFontSize"},
    percent={x="healthPercentX",y="healthPercentY",font="healthPercentFontSize"},
    value={x="healthValueX",y="healthValueY",font="healthValueFontSize"},
}

local function MakeDesignerTextMover(holder, fontString, kind, width)
    local keys=TEXT_MOVER_KEYS[kind]
    if not keys then return nil end
    local mover=CreateFrame("Frame",nil,holder,"BackdropTemplate")
    mover:SetSize(width or 60,28)
    mover:SetPoint("CENTER",fontString,"CENTER",0,0)
    local holderLevel=holder.GetFrameLevel and holder:GetFrameLevel() or 0
    mover:SetFrameLevel(holderLevel+180)
    mover:EnableMouse(true)
    mover:SetBackdrop({edgeFile=DESIGNER_WHITE,edgeSize=1})
    mover:SetBackdropBorderColor(0,0,0,0)

    local function Cursor()
        local x,y=GetCursorPosition()
        local scale=holder:GetEffectiveScale() or 1
        if scale<=0 then scale=1 end
        return x/scale,y/scale
    end
    local function Stop(self)
        self.dragMode=nil
        self:SetScript("OnUpdate",nil)
        self:SetBackdropBorderColor(.20,.70,1,.75)
        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner() end
        SyncExtraDialogs()
    end
    mover:SetScript("OnEnter",function(self) if not self.dragMode then self:SetBackdropBorderColor(.20,.70,1,.75) end end)
    mover:SetScript("OnLeave",function(self) if not self.dragMode then self:SetBackdropBorderColor(0,0,0,0) end end)
    mover:SetScript("OnMouseDown",function(self,button)
        local db=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
        if not db then return end
        local cx,cy=Cursor(); self.startX,self.startY=cx,cy
        if button=="LeftButton" then
            self.dragMode="move"
            self.baseX=tonumber(db[keys.x]) or 0
            self.baseY=tonumber(db[keys.y]) or 0
        elseif button=="RightButton" then
            self.dragMode="scale"
            self.baseFont=tonumber(db[keys.font]) or 13
        else return end
        self:SetBackdropBorderColor(1,.55,.15,1)
        self:SetScript("OnUpdate",function(frame)
            if frame.dragMode=="move" and not IsMouseButtonDown("LeftButton") then Stop(frame); return end
            if frame.dragMode=="scale" and not IsMouseButtonDown("RightButton") then Stop(frame); return end
            local x,y=Cursor(); local dx,dy=DesignerLiveDelta(x-frame.startX),DesignerLiveDelta(y-frame.startY)
            local current=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
            if not current then Stop(frame); return end
            if frame.dragMode=="move" then
                current[keys.x]=ClampDesignerValue(frame.baseX+dx,-250,250)
                current[keys.y]=ClampDesignerValue(frame.baseY+dy,-150,150)
            else
                local factor=ClampDesignerValue(1+(dx/140),.35,3.0)
                current[keys.font]=ClampDesignerValue(frame.baseFont*factor,7,30)
            end
            if ns.RefreshNameplateDesignerPreview then ns.RefreshNameplateDesignerPreview() end
        end)
    end)
    mover:SetScript("OnMouseUp",function(self) Stop(self) end)
    return mover
end


local INDICATOR_MOVER_KEYS = {
    quest={x="questX",y="questY",scale="questScale"},
    classification={x="classificationX",y="classificationY",scale="classificationScale"},
    raidTarget={x="raidTargetX",y="raidTargetY",scale="raidTargetScale"},
    combo={x="comboX",y="comboY",scale="comboScale"},
}

local function MakeDesignerIndicatorMover(holder, target, kind, width, height)
    local keys=INDICATOR_MOVER_KEYS[kind]
    if not keys then return nil end
    local mover=CreateFrame("Frame",nil,holder,"BackdropTemplate")
    mover:SetSize(width or 36,height or 30)
    mover:SetPoint("CENTER",target,"CENTER",0,0)
    local holderLevel=holder.GetFrameLevel and holder:GetFrameLevel() or 0
    mover:SetFrameLevel(holderLevel+185)
    mover:EnableMouse(true)
    mover:SetBackdrop({edgeFile=DESIGNER_WHITE,edgeSize=1})
    mover:SetBackdropBorderColor(0,0,0,0)

    local function Cursor()
        local x,y=GetCursorPosition()
        local scale=holder:GetEffectiveScale() or 1
        if scale<=0 then scale=1 end
        return x/scale,y/scale
    end
    local function Stop(self)
        self.dragMode=nil
        self:SetScript("OnUpdate",nil)
        self:SetBackdropBorderColor(.20,.70,1,.75)
        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner() end
        SyncExtraDialogs()
    end
    mover:SetScript("OnEnter",function(self) if not self.dragMode then self:SetBackdropBorderColor(.20,.70,1,.75) end end)
    mover:SetScript("OnLeave",function(self) if not self.dragMode then self:SetBackdropBorderColor(0,0,0,0) end end)
    mover:SetScript("OnMouseDown",function(self,button)
        local db=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
        if not db then return end
        local cx,cy=Cursor(); self.startX,self.startY=cx,cy
        if button=="LeftButton" then
            self.dragMode="move"
            self.baseX=tonumber(db[keys.x]) or 0
            self.baseY=tonumber(db[keys.y]) or 0
        elseif button=="RightButton" then
            self.dragMode="scale"
            self.baseScale=tonumber(db[keys.scale]) or 1
        else return end
        self:SetBackdropBorderColor(1,.55,.15,1)
        self:SetScript("OnUpdate",function(frame)
            if frame.dragMode=="move" and not IsMouseButtonDown("LeftButton") then Stop(frame); return end
            if frame.dragMode=="scale" and not IsMouseButtonDown("RightButton") then Stop(frame); return end
            local x,y=Cursor(); local dx,dy=DesignerLiveDelta(x-frame.startX),DesignerLiveDelta(y-frame.startY)
            local current=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB() or nil
            if not current then Stop(frame); return end
            if frame.dragMode=="move" then
                current[keys.x]=ClampDesignerValue(frame.baseX+dx,-400,400)
                current[keys.y]=ClampDesignerValue(frame.baseY+dy,-250,250)
            else
                local factor=ClampDesignerValue(1+(dx/140),.35,3.0)
                current[keys.scale]=ClampDesignerValue(frame.baseScale*factor,.35,3.0)
            end
            if ns.RefreshNameplateDesignerPreview then ns.RefreshNameplateDesignerPreview() end
        end)
    end)
    mover:SetScript("OnMouseUp",function(self) Stop(self) end)
    return mover
end

local function BuildDesignerPreview(parent)
    local holder=CreateFrame("Frame",nil,parent,"BackdropTemplate")
    holder:SetPoint("TOPLEFT",84,-134)
    holder:SetPoint("TOPRIGHT",-85,-134)
    holder:SetHeight(410)
    holder:SetBackdrop({})

    -- Everything visible in the preview lives under one scene frame. Scaling
    -- this scene by the real live nameplate effective scale makes one local
    -- layout unit equal one local live nameplate unit.
    local scene=CreateFrame("Frame",nil,holder)
    scene:SetSize(1,1)
    scene:SetFrameLevel(holder:GetFrameLevel()+5)
    local layoutAnchor=CreateFrame("Frame",nil,scene)
    layoutAnchor:SetSize(1,1)
    layoutAnchor:SetPoint("CENTER",scene,"CENTER",0,0)

    local healthShell,healthGlow,healthOuter,health,healthBG=PreviewBar(scene,HEALTH_MASK)
    health:SetValue(.82)
    local nameLayer=CreateFrame("Frame",nil,healthShell)
    nameLayer:SetAllPoints(healthShell); nameLayer:SetFrameLevel(health:GetFrameLevel()+5)
    local name=nameLayer:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    name:SetPoint("CENTER"); name:SetText("Bloodtalon Taillasher")
    local levelText=nameLayer:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    levelText:SetPoint("CENTER"); levelText:SetText("90")
    local healthPercentText=nameLayer:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    healthPercentText:SetPoint("CENTER"); healthPercentText:SetText("82%")
    local healthValueText=nameLayer:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    healthValueText:SetPoint("CENTER"); healthValueText:SetText("1000k")

    -- Quest objective indicator. Use Blizzard's normal quest "!" atlas.
    -- C_QuestLog still owns whether a live unit is related to an active quest;
    -- H3z0 only presents that state and lets the designer move/scale the icon.
    local questFrame=CreateFrame("Frame",nil,scene)
    questFrame:SetSize(22,22)
    local questIcon=questFrame:CreateTexture(nil,"ARTWORK")
    questIcon:SetAllPoints(questFrame)
    local questAtlasApplied=false
    if questIcon.SetAtlas then
        questAtlasApplied=pcall(questIcon.SetAtlas,questIcon,"QuestNormal",false)
    end
    if not questAtlasApplied then
        questIcon:SetTexture("Interface\\GossipFrame\\AvailableQuestIcon")
    end

    -- Exact live Forever fallback footprint: one 20x20 Blizzard classification
    -- atlas with atlas-size disabled. Do not preview two native-size atlases;
    -- that made the saved scale look much larger here than it was in game.
    local classificationGroup=CreateFrame("Frame",nil,scene)
    classificationGroup:SetSize(20,20)
    local eliteIcon=classificationGroup:CreateTexture(nil,"ARTWORK")
    eliteIcon:SetAllPoints(classificationGroup)
    if eliteIcon.SetAtlas then
        local ok=pcall(eliteIcon.SetAtlas,eliteIcon,"nameplates-icon-elite-gold",false)
        if not ok then eliteIcon:SetTexture(132177) end
    end

    -- Raid target preview: Blizzard's blue Square marker (raid target index 6).
    -- Live visibility/icon choice remains entirely owned by UpdateRaidTarget.
    local raidTargetFrame=CreateFrame("Frame",nil,scene)
    raidTargetFrame:SetSize(22,22)
    raidTargetFrame:SetFrameLevel(scene:GetFrameLevel()+180)
    local raidTargetIcon=raidTargetFrame:CreateTexture(nil,"ARTWORK")
    raidTargetIcon:SetAllPoints(raidTargetFrame)
    raidTargetIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    -- Use Blizzard's own 4x4 sprite-sheet resolver. Square is raid target 6.
    -- The old hand-authored TexCoord sampled an empty/wrong section and left
    -- only the designer mover visible.
    if type(SetRaidTargetIconTexture)=="function" then
        SetRaidTargetIconTexture(raidTargetIcon,6)
    elseif raidTargetIcon.SetSpriteSheetCell then
        raidTargetIcon:SetSpriteSheetCell(6,4,4)
    else
        raidTargetIcon:SetTexCoord(.25,.5,.25,.5)
    end

    local castShell,castGlow,castOuter,cast,castBG=PreviewBar(scene,CAST_MASK)
    cast:SetValue(.62)
    local castTextLayer=CreateFrame("Frame",nil,castShell)
    castTextLayer:SetAllPoints(castShell); castTextLayer:SetFrameLevel(cast:GetFrameLevel()+5)
    local castName=castTextLayer:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    castName:SetPoint("CENTER"); castName:SetText("Frostbolt")

    local iconFrame=CreateFrame("Frame",nil,scene)
    local icon=iconFrame:CreateTexture(nil,"ARTWORK")
    icon:SetAllPoints(iconFrame)
    icon:SetTexture(135846); icon:SetTexCoord(.08,.92,.08,.92)
    if ns.AddCastIconSkin then ns.AddCastIconSkin(iconFrame,icon,4,.82) end
    local shield=scene:CreateTexture(nil,"OVERLAY")
    if shield.SetAtlas then
        local ok=pcall(shield.SetAtlas,shield,"nameplates-InterruptShield",true)
        if not ok then shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield") end
    else
        shield:SetTexture("Interface\\CastingBar\\UI-CastingBar-Small-Shield")
    end

    local comboGroup = ns.CreateNameplateComboPoints and ns.CreateNameplateComboPoints(scene)
    if comboGroup then
        ns.SetNameplateComboMax(comboGroup, 5)
        ns.SetNameplateComboPointValue(comboGroup, 5)
        comboGroup:SetFrameLevel(health:GetFrameLevel()+8)
    end

    local buffGroup=CreateDesignerAuraGroup(scene,"buff")
    local debuffGroup=CreateDesignerAuraGroup(scene,"debuff")
    local ccGroup=CreateDesignerAuraGroup(scene,"cc")

    local healthMover=MakeDesignerMover(scene,healthShell,"health")
    local castMover=MakeDesignerMover(scene,castShell,"cast")
    local buffMover=MakeDesignerMover(scene,buffGroup,"buff")
    local debuffMover=MakeDesignerMover(scene,debuffGroup,"debuff")
    local ccMover=MakeDesignerMover(scene,ccGroup,"cc")
    local nameMover=MakeDesignerTextMover(scene,name,"name",130)
    local levelMover=MakeDesignerTextMover(scene,levelText,"level",44)
    local percentMover=MakeDesignerTextMover(scene,healthPercentText,"percent",52)
    local valueMover=MakeDesignerTextMover(scene,healthValueText,"value",62)
    local questMover=MakeDesignerIndicatorMover(scene,questFrame,"quest",30,30)
    local classificationMover=MakeDesignerIndicatorMover(scene,classificationGroup,"classification",30,30)
    local raidTargetMover=MakeDesignerIndicatorMover(scene,raidTargetFrame,"raidTarget",30,30)
    local comboMover=comboGroup and MakeDesignerIndicatorMover(scene,comboGroup,"combo",140,30)
    if comboMover then
        comboMover:SetScript("OnEnter",function(self)
            if not self.dragMode then self:SetBackdropBorderColor(.20,.70,1,.75) end
            if GameTooltip then
                GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
                GameTooltip:SetText("Combo Points")
                GameTooltip:AddLine("Left-drag: Move   Right-drag: Scale",1,1,1)
                GameTooltip:Show()
            end
        end)
        comboMover:HookScript("OnLeave",function() if GameTooltip then GameTooltip:Hide() end end)
    end

    designerPreview={holder=holder,scene=scene,layoutAnchor=layoutAnchor,healthShell=healthShell,healthGlow=healthGlow,healthOuter=healthOuter,health=health,healthBG=healthBG,nameLayer=nameLayer,name=name,levelText=levelText,healthPercentText=healthPercentText,healthValueText=healthValueText,
        questFrame=questFrame,questIcon=questIcon,classificationGroup=classificationGroup,eliteIcon=eliteIcon,raidTargetFrame=raidTargetFrame,raidTargetIcon=raidTargetIcon,
        comboGroup=comboGroup,comboMover=comboMover,
        castShell=castShell,castGlow=castGlow,castOuter=castOuter,cast=cast,castBG=castBG,castTextLayer=castTextLayer,castName=castName,iconFrame=iconFrame,icon=icon,shield=shield,
        buffGroup=buffGroup,debuffGroup=debuffGroup,ccGroup=ccGroup,
        healthMover=healthMover,castMover=castMover,buffMover=buffMover,debuffMover=debuffMover,ccMover=ccMover,
        nameMover=nameMover,levelMover=levelMover,percentMover=percentMover,valueMover=valueMover,questMover=questMover,classificationMover=classificationMover,raidTargetMover=raidTargetMover}
    return holder
end

function ns.RefreshNameplateDesignerPreview()
    if not designerPreview then return end
    local p=designerPreview
    local db=ns.GetNameplateDesignerDB and ns.GetNameplateDesignerDB()
    if not db then return end
    local function Layout(shell,borderSkin,outer,bar,bg,w,h,r,g,b,br,bgc,bb)
        shell:SetSize(w,h)
        bar:ClearAllPoints(); bar:SetAllPoints(shell)
        PreviewLayoutBorder(borderSkin,shell)
        bg:SetVertexColor(br,bgc,bb,1); bar:SetStatusBarColor(r,g,b,1)
    end

    -- Shift the complete preview scene down inside the gray layout canvas.
    -- This is preview-only and does not alter any saved/live coordinates.
    local previewBaseY=-55
    -- The layout editor is a fixed working canvas. Live globalScale must never
    -- resize, offset or otherwise influence the editor, including after the
    -- menu is closed/reopened. Only DESIGNER_PREVIEW_ZOOM applies here.
    p.scene:ClearAllPoints(); p.scene:SetPoint("CENTER",p.holder,"CENTER",0,previewBaseY); p.scene:SetScale(DESIGNER_PREVIEW_ZOOM)

    -- Rebuild the sample footprints from the same base dimensions used live.
    LayoutDesignerAuraGroup(p.buffGroup,"buff")
    LayoutDesignerAuraGroup(p.debuffGroup,"debuff")
    LayoutDesignerAuraGroup(p.ccGroup,"cc")

    p.healthShell:ClearAllPoints(); p.healthShell:SetPoint("CENTER",p.layoutAnchor,"CENTER",db.healthX,db.healthY)
    Layout(p.healthShell,p.healthGlow,p.healthOuter,p.health,p.healthBG,db.healthWidth,db.healthHeight,
        1,0,0,db.healthBgR,db.healthBgG,db.healthBgB)
    if ns.ApplyStatusbarMedia then ns.ApplyStatusbarMedia(p.health,db.healthTexture)
    else p.health:SetStatusBarTexture(DESIGNER_WHITE) end
    local font=select(1,p.name:GetFont()) or STANDARD_TEXT_FONT
    p.name:ClearAllPoints(); p.name:SetPoint("CENTER",p.healthShell,"CENTER",db.nameX,db.nameY)
    p.name:SetFont(font,db.nameFontSize,db.nameOutline and "OUTLINE" or "")
    p.name:SetTextColor(1,1,1,1); p.name:SetShadowOffset(0,0)

    p.levelText:ClearAllPoints(); p.levelText:SetPoint("CENTER",p.healthShell,"CENTER",db.levelX,db.levelY)
    p.levelText:SetFont(font,db.levelFontSize,"OUTLINE"); p.levelText:SetTextColor(1,.82,0,1); p.levelText:SetShadowColor(0,0,0,1); p.levelText:SetShadowOffset(1,-1)

    p.questFrame:ClearAllPoints(); p.questFrame:SetPoint("CENTER",p.healthShell,"CENTER",db.questX,db.questY)
    p.questFrame:SetScale(db.questScale)
    p.classificationGroup:ClearAllPoints(); p.classificationGroup:SetPoint("CENTER",p.healthShell,"CENTER",db.classificationX,db.classificationY)
    p.classificationGroup:SetScale(db.classificationScale)
    p.raidTargetFrame:ClearAllPoints(); p.raidTargetFrame:SetPoint("CENTER",p.healthShell,"CENTER",db.raidTargetX,db.raidTargetY)
    p.raidTargetFrame:SetScale(db.raidTargetScale)
    if p.comboGroup and ns.LayoutNameplateComboPoints then
        ns.LayoutNameplateComboPoints(p.comboGroup,p.healthShell,db)
        if p.comboMover then
            p.comboMover:SetSize(p.comboGroup:GetWidth() * db.comboScale + 14,
                24 * db.comboScale + 6)
        end
    end

    p.healthPercentText:ClearAllPoints(); p.healthPercentText:SetPoint("CENTER",p.healthShell,"CENTER",db.healthPercentX,db.healthPercentY)
    p.healthPercentText:SetFont(font,db.healthPercentFontSize,"OUTLINE"); p.healthPercentText:SetTextColor(1,1,1,1); p.healthPercentText:SetShadowOffset(0,0)
    local constants=NamePlateConstants or {}
    local infoEnums=Enum and Enum.NamePlateInfoDisplay or nil
    local showHealthPercent,showHealthValue=true,true
    if ns.GetNameplateBitfieldSetting and infoEnums then
        showHealthPercent=ns.GetNameplateBitfieldSetting(
            constants.INFO_DISPLAY_CVAR or "nameplateInfoDisplay",
            infoEnums.CurrentHealthPercent,true)
        showHealthValue=ns.GetNameplateBitfieldSetting(
            constants.INFO_DISPLAY_CVAR or "nameplateInfoDisplay",
            infoEnums.CurrentHealthValue,true)
    end
    -- The Modules switches force the texts on, same as on the real plates.
    if tonumber(db.hpPercentOn)==1 then showHealthPercent=true end
    if tonumber(db.hpValueOn)==1 then showHealthValue=true end
    p.healthPercentText:SetAlpha(showHealthPercent and 1 or 0)
    if p.percentMover then p.percentMover:SetShown(showHealthPercent) end

    p.healthValueText:ClearAllPoints(); p.healthValueText:SetPoint("CENTER",p.healthShell,"CENTER",db.healthValueX,db.healthValueY)
    p.healthValueText:SetFont(font,db.healthValueFontSize,"OUTLINE"); p.healthValueText:SetTextColor(1,1,1,1); p.healthValueText:SetShadowOffset(0,0)
    p.healthValueText:SetAlpha(showHealthValue and 1 or 0)
    if p.valueMover then p.valueMover:SetShown(showHealthValue) end

    p.castShell:ClearAllPoints(); p.castShell:SetPoint("CENTER",p.layoutAnchor,"CENTER",db.castX,db.castY)
    Layout(p.castShell,p.castGlow,p.castOuter,p.cast,p.castBG,db.castWidth,db.castHeight,
        db.harmfulR,db.harmfulG,db.harmfulB,db.castBgR,db.castBgG,db.castBgB)
    if ns.ApplyStatusbarMedia then ns.ApplyStatusbarMedia(p.cast,db.castTexture)
    else p.cast:SetStatusBarTexture(DESIGNER_WHITE) end
    font=select(1,p.castName:GetFont()) or STANDARD_TEXT_FONT
    p.castName:SetFont(font,db.castFontSize,db.castOutline and "OUTLINE" or "")
    p.castName:SetTextColor(1,1,1,1); p.castName:SetShadowOffset(0,0)
    local castEnums=Enum and Enum.NamePlateCastBarDisplay or nil
    local showSpellName,showSpellIcon=true,true
    if ns.GetNameplateBitfieldSetting and castEnums then
        showSpellName=ns.GetNameplateBitfieldSetting(
            constants.CAST_BAR_DISPLAY_CVAR or "nameplateCastBarDisplay",
            castEnums.SpellName,true)
        showSpellIcon=ns.GetNameplateBitfieldSetting(
            constants.CAST_BAR_DISPLAY_CVAR or "nameplateCastBarDisplay",
            castEnums.SpellIcon,true)
    end
    p.castName:SetShown(showSpellName)

    local castIconSize = db.castHeight
    p.iconFrame:SetSize(castIconSize,castIconSize)
    p.iconFrame:ClearAllPoints(); p.iconFrame:SetPoint("RIGHT",p.castShell,"LEFT",-db.iconGap,0)
    p.iconFrame:SetShown(db.iconEnabled and showSpellIcon)
    p.shield:SetSize(db.shieldSize,db.shieldSize)
    p.shield:ClearAllPoints(); p.shield:SetPoint("LEFT",p.castShell,"RIGHT",db.shieldGap,0)
    p.shield:SetShown(db.shieldEnabled)

    local auraDB=GetAuraLayoutDB()
    -- One geometry function for BOTH preview and live. Coordinates are relative
    -- to the visible custom healthbar center. Buffs use a RIGHT origin and grow
    -- left; Debuffs/CC use a LEFT origin and grow right. Aura count cannot move
    -- the saved origin in either direction.
    if ns.PlaceNameplateAuraContainer then
        ns.PlaceNameplateAuraContainer(p.buffGroup,p.layoutAnchor,"buff",auraDB)
        ns.PlaceNameplateAuraContainer(p.debuffGroup,p.layoutAnchor,"debuff",auraDB)
        ns.PlaceNameplateAuraContainer(p.ccGroup,p.layoutAnchor,"cc",auraDB)
    end
end

local function OpenBlizzardNameplateOptions()
    -- Use Blizzard's own registered category. H3z0 does not mirror, cache or
    -- write any of these settings; the button is only a navigation shortcut.
    if C_AddOns and type(C_AddOns.LoadAddOn)=="function" then
        pcall(C_AddOns.LoadAddOn,"Blizzard_SettingsDefinitions_Frame")
    elseif type(LoadAddOn)=="function" then
        pcall(LoadAddOn,"Blizzard_SettingsDefinitions_Frame")
    end

    if Settings and type(Settings.OpenToCategory)=="function" then
        local categoryID=Settings.NAMEPLATE_OPTIONS_CATEGORY_ID
        if not categoryID and type(Settings.GetCategory)=="function" and NAMEPLATE_OPTIONS_LABEL then
            local ok,category=pcall(Settings.GetCategory,NAMEPLATE_OPTIONS_LABEL)
            if ok and category and type(category.GetID)=="function" then
                local okID,resolvedID=pcall(category.GetID,category)
                if okID then categoryID=resolvedID end
            end
        end
        if categoryID then
            Settings.OpenToCategory(categoryID)
            return true
        end
    end
    return false
end

local function OpenEffectsDialog()
    if not effectsDialog then
        local frame = CreateFrame("Frame", "H3z0NameplatesEffectsDialog", UIParent, "BackdropTemplate")
        frame:SetSize(755, 350)
        frame:SetPoint("CENTER")
        frame:SetFrameStrata("DIALOG")
        frame:SetFrameLevel(100)
        frame:SetClampedToScreen(true)
        frame:SetToplevel(true)
        Backdrop(frame, .035, .24)
        table.insert(UISpecialFrames, frame:GetName())

        local title = Label(frame, "Health Effects & Textures", "GameFontNormalLarge")
        title:SetPoint("TOPLEFT", 24, -22)
        title:SetTextColor(1, .7, .4)
        local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -4, -4)
        frame.controls = {}

        local columns = {
            {title="Incoming Heals", enabled="incomingHealsEnabled", media="incomingHealTexture", x=25},
            {title="Absorbs", enabled="absorbsEnabled", media="absorbTexture", x=275},
            {title="Damage Echo", enabled="damageEchoEnabled", media="damageEchoTexture", x=525},
        }
        local function Refresh()
            if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
        end
        for _, info in ipairs(columns) do
            local header = Label(frame, info.title, "GameFontNormal")
            header:SetPoint("TOPLEFT", info.x, -73)
            local toggle = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
            toggle:SetPoint("TOPLEFT", info.x, -100)
            toggle:SetSize(24, 24)
            local toggleLabel = Label(frame, "Enabled", "GameFontHighlightSmall")
            toggleLabel:SetPoint("LEFT", toggle, "RIGHT", 3, 0)
            toggle:SetScript("OnClick", function(self)
                ns.GetNameplateDesignerDB()[info.enabled] = self:GetChecked() and 1 or 0
                Refresh()
            end)
            local mediaLabel = Label(frame, "Texture", "GameFontHighlightSmall")
            mediaLabel:SetPoint("TOPLEFT", info.x, -139)
            local button = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
            button:SetSize(212, 30)
            button:SetPoint("TOPLEFT", info.x, -161)
            button:SetSelectionTranslator(function(selection)
                return tostring(selection.text or "Match Health")
            end)
            function button:Sync()
                local names = {"Match Health"}
                for _, name in ipairs(ns.GetStatusbarMediaNames and ns.GetStatusbarMediaNames() or {"H3z0 Flat"}) do
                    names[#names+1] = name
                end
                self:SetupMenu(function(_, rootDescription)
                    rootDescription:SetTag("MENU_H3Z0_NAMEPLATES_EFFECT_"..info.media)
                    for _, name in ipairs(names) do
                        local option = name
                        rootDescription:CreateRadio(option,
                            function() return ns.GetNameplateDesignerDB()[info.media] == option end,
                            function()
                                ns.GetNameplateDesignerDB()[info.media] = option
                                Refresh()
                            end)
                    end
                end)
            end
            frame.controls[#frame.controls+1] = {toggle=toggle, button=button, enabled=info.enabled}
        end

        local durationLabel = Label(frame, "Echo Duration: 0.50 s", "GameFontNormalSmall")
        durationLabel:SetPoint("TOPLEFT", 28, -247)
        local duration = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
        duration:SetSize(302, 16)
        duration:SetPoint("TOPLEFT", 28, -283)
        duration:SetMinMaxValues(0.1, 1)
        duration:SetValueStep(.05)
        if duration.SetObeyStepOnDrag then duration:SetObeyStepOnDrag(true) end
        duration:SetScript("OnValueChanged", function(self, value)
            if self.syncing then return end
            value = math.floor(value * 20 + .5) / 20
            ns.GetNameplateDesignerDB().damageEchoDuration = value
            durationLabel:SetText(string.format("Echo Duration: %.2f s", value))
        end)
        local opacityLabel = Label(frame, "Echo Opacity: 85%", "GameFontNormalSmall")
        opacityLabel:SetPoint("TOPLEFT", 390, -247)
        local opacity = CreateFrame("Slider", nil, frame, "OptionsSliderTemplate")
        opacity:SetSize(300, 16)
        opacity:SetPoint("TOPLEFT", 390, -283)
        opacity:SetMinMaxValues(.2, 1)
        opacity:SetValueStep(.05)
        if opacity.SetObeyStepOnDrag then opacity:SetObeyStepOnDrag(true) end
        opacity:SetScript("OnValueChanged", function(self, value)
            if self.syncing then return end
            value = math.floor(value * 20 + .5) / 20
            ns.GetNameplateDesignerDB().damageEchoOpacity = value
            opacityLabel:SetText(string.format("Echo Opacity: %d%%", math.floor(value * 100 + .5)))
            Refresh()
        end)
        function frame:Sync()
            local db = ns.GetNameplateDesignerDB()
            for _, control in ipairs(self.controls) do
                control.toggle:SetChecked(db[control.enabled] ~= 0)
                control.button:Sync()
            end
            duration.syncing = true
            duration:SetValue(db.damageEchoDuration or .5)
            duration.syncing = false
            durationLabel:SetText(string.format("Echo Duration: %.2f s", db.damageEchoDuration or .5))
            opacity.syncing = true
            opacity:SetValue(db.damageEchoOpacity or .85)
            opacity.syncing = false
            opacityLabel:SetText(string.format("Echo Opacity: %d%%", math.floor((db.damageEchoOpacity or .85)*100+.5)))
        end
        effectsDialog = frame
        frame:Hide()
    end
    effectsDialog:Sync()
    effectsDialog:Show()
    effectsDialog:Raise()
end

-- ---------------------------------------------------------------------------
-- Extra settings windows: Sizes, Friendly, Target & Threat.
-- Every control edits the same saved settings the layout preview uses, with
-- the same limits, so nothing has to be sized by right-dragging.
-- ---------------------------------------------------------------------------
local function MakeSettingsDialog(key, frameName, titleText, width, height)
    local frame = CreateFrame("Frame", frameName, UIParent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetPoint("CENTER")
    frame:SetFrameStrata("DIALOG")
    frame:SetFrameLevel(100)
    frame:SetClampedToScreen(true)
    frame:SetToplevel(true)
    -- Movable, so it can sit beside the layout preview while sliding.
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:RegisterForDrag("LeftButton")
    frame:SetScript("OnDragStart", function(self) self:StartMoving() end)
    frame:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)
    Backdrop(frame, .035, .24)
    table.insert(UISpecialFrames, frame:GetName())

    local title = Label(frame, titleText, "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 24, -22)
    title:SetTextColor(1, .7, .4)
    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -4, -4)

    frame.controls = {}
    function frame:Sync()
        for _, control in ipairs(self.controls) do control:Sync() end
        if self.AfterSync then self:AfterSync() end
    end
    frame:SetScript("OnShow", function(self) self:Sync(); PlayOpenFade(self) end)
    frame:Hide()
    extraDialogs[key] = frame
    return frame
end

local function MakeSettingHeader(frame, text, x, y)
    local header = Label(frame, text, "GameFontNormal")
    header:SetPoint("TOPLEFT", x, y)
    return header
end

local function MakeSettingHint(frame, text, x, y, width)
    local hint = Label(frame, text, "GameFontDisableSmall")
    hint:SetPoint("TOPLEFT", x, y)
    hint:SetWidth(width)
    hint:SetJustifyH("LEFT")
    return hint
end

-- info: label, key, min, max, step, and optionally
--   percent    show and store as a 0-1 factor, displayed as a percentage
--   aura       value lives in the aura layout settings
--   castHeight keep the spell icon and shield proportional to the bar height
--   liveOnly   not shown in the layout preview, so only live plates refresh
local function MakeSettingSlider(frame, info, x, y, width)
    local text = Label(frame, info.label, "GameFontNormalSmall")
    text:SetPoint("TOPLEFT", x, y)
    local slider = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    slider:SetSize(width, 14)
    slider:SetPoint("TOPLEFT", x, y - 20)
    slider:SetOrientation("HORIZONTAL")
    slider:SetMinMaxValues(info.min, info.max)
    slider:SetValueStep(info.step)
    if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
    Backdrop(slider, .065, .22)
    local thumb = slider:CreateTexture(nil, "OVERLAY")
    thumb:SetColorTexture(1, .32, .08, 1)
    thumb:SetSize(10, 20)
    slider:SetThumbTexture(thumb)
    slider.text = text

    local function Describe(value)
        if info.percent then
            return string.format("%s: %d%%", info.label, math.floor(value * 100 + .5))
        end
        return string.format("%s: %d", info.label, math.floor(value + .5))
    end
    local function Read()
        local db = info.aura and GetAuraLayoutDB() or ns.GetNameplateDesignerDB()
        return ClampDesignerValue(db[info.key], info.min, info.max)
    end
    local function Write(value)
        if info.aura then
            GetAuraLayoutDB()[info.key] = value
            if ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
            if ns.RefreshNameplateDesignerPreview then ns.RefreshNameplateDesignerPreview() end
            return
        end
        local db = ns.GetNameplateDesignerDB()
        if info.castHeight then
            -- Same rule as the main Cast Height slider: the spell icon and
            -- shield stay square and follow the bar height.
            local oldHeight = tonumber(db.castHeight) or 13
            if oldHeight <= 0 then oldHeight = 13 end
            local factor = value / oldHeight
            db.iconSize = ClampDesignerValue((tonumber(db.iconSize) or 17) * factor, 8, 80)
            db.shieldSize = ClampDesignerValue((tonumber(db.shieldSize) or 20) * factor, 8, 80)
        end
        db[info.key] = value
        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(info.liveOnly and true or false) end
        if info.castHeight and menu and menu.page and menu.page.SyncCastHeight then
            menu.page:SyncCastHeight()
        end
    end

    slider:SetScript("OnValueChanged", function(self, value)
        if self.syncing then return end
        value = tonumber(value) or info.min
        value = math.floor(value / info.step + .5) * info.step
        value = ClampDesignerValue(value, info.min, info.max)
        text:SetText(Describe(value))
        Write(value)
    end)
    function slider:Sync()
        local value = Read()
        self.syncing = true
        self:SetValue(value)
        self.syncing = false
        text:SetText(Describe(value))
    end
    function slider:SetActive(active)
        self:EnableMouse(active and true or false)
        self:SetAlpha(active and 1 or .35)
        text:SetAlpha(active and 1 or .35)
    end
    frame.controls[#frame.controls + 1] = slider
    return slider
end

local function MakeSettingCheck(frame, labelText, x, y, getter, setter)
    local check = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    check:SetPoint("TOPLEFT", x - 4, y)
    check:SetSize(24, 24)
    local text = Label(frame, labelText, "GameFontHighlightSmall")
    text:SetPoint("LEFT", check, "RIGHT", 3, 0)
    check.text = text
    check:SetScript("OnClick", function(self)
        setter(self:GetChecked() and true or false)
        frame:Sync()
    end)
    function check:Sync()
        self:SetChecked(getter() and true or false)
    end
    function check:SetActive(active)
        if self.SetEnabled then self:SetEnabled(active and true or false) end
        text:SetAlpha(active and 1 or .35)
    end
    frame.controls[#frame.controls + 1] = check
    return check
end

local function ToggleSettingsDialog(key, build)
    local dialog = extraDialogs[key] or build()
    if dialog:IsShown() then
        dialog:Hide()
        return
    end
    dialog:Sync()
    dialog:Show()
    dialog:Raise()
end

-- Sizes --------------------------------------------------------------------
local SIZE_SLIDERS = {
    {col=1,row=1,label="Health Width",key="healthWidth",min=70,max=360,step=1},
    {col=1,row=2,label="Health Height",key="healthHeight",min=8,max=48,step=1},
    {col=1,row=3,label="Cast Width",key="castWidth",min=70,max=360,step=1},
    {col=1,row=4,label="Cast Height",key="castHeight",min=6,max=40,step=1,castHeight=true},
    {col=1,row=5,label="Buff Icons",key="buffScale",min=.35,max=3,step=.01,percent=true,aura=true},
    {col=1,row=6,label="Debuff Icons",key="debuffScale",min=.35,max=3,step=.01,percent=true,aura=true},
    {col=1,row=7,label="Crowd Control Icons",key="ccScale",min=.35,max=3,step=.01,percent=true,aura=true},
    {col=2,row=1,label="Name Text",key="nameFontSize",min=7,max=30,step=1},
    {col=2,row=2,label="Level Text",key="levelFontSize",min=7,max=30,step=1},
    {col=2,row=3,label="Health % Text",key="healthPercentFontSize",min=7,max=30,step=1},
    {col=2,row=4,label="Health Value Text",key="healthValueFontSize",min=7,max=30,step=1},
    {col=2,row=5,label="Cast Text",key="castFontSize",min=7,max=26,step=1},
    {col=2,row=6,label="Combo Points",key="comboScale",min=.35,max=3,step=.01,percent=true},
    {col=2,row=7,label="Raid Marker",key="raidTargetScale",min=.35,max=3,step=.01,percent=true},
    {col=2,row=8,label="Quest Icon",key="questScale",min=.35,max=3,step=.01,percent=true},
    {col=2,row=9,label="Elite / Rare Icon",key="classificationScale",min=.35,max=3,step=.01,percent=true},
}

local function BuildSizesDialog()
    local frame = MakeSettingsDialog("sizes", "H3z0NameplatesSizesDialog", "Sizes", 760, 650)
    local columnX = {28, 400}
    MakeSettingHeader(frame, "Bars & Auras", columnX[1], -56)
    MakeSettingHeader(frame, "Text & Icons", columnX[2], -56)
    for _, info in ipairs(SIZE_SLIDERS) do
        MakeSettingSlider(frame, info, columnX[info.col], -86 - (info.row - 1) * 50, 330)
    end
    MakeSettingSlider(frame,
        {label="Nameplate Height",key="plateOffsetY",min=-40,max=80,step=1,liveOnly=true},
        columnX[1], -446, 330)
    MakeSettingHeader(frame, "Font", columnX[1], -496)
    local fontDropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    fontDropdown:SetSize(330, 30)
    fontDropdown:SetPoint("TOPLEFT", columnX[1], -520)
    fontDropdown:SetSelectionTranslator(function(selection)
        return tostring(selection.text or "Default")
    end)
    function fontDropdown:Sync()
        local names = ns.GetFontNames and ns.GetFontNames() or {"Default"}
        self:SetupMenu(function(_, rootDescription)
            rootDescription:SetTag("MENU_H3Z0_NAMEPLATES_FONT")
            if rootDescription.SetScrollMode then rootDescription:SetScrollMode(300) end
            for _, name in ipairs(names) do
                local fontName = name
                rootDescription:CreateRadio(fontName,
                    function() return (ns.GetNameplateDesignerDB().font or "Default") == fontName end,
                    function()
                        ns.GetNameplateDesignerDB().font = fontName
                        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
                    end)
            end
        end)
    end
    frame.controls[#frame.controls + 1] = fontDropdown
    MakeSettingHint(frame,
        "These are the sizes for enemy plates. Friendly plates use them too unless separate friendly sizes are turned on under FRIENDLY.",
        columnX[1], -566, 330)
    return frame
end

-- Friendly -----------------------------------------------------------------
local FRIENDLY_SIZE_SLIDERS = {
    {label="Friendly Health Width",key="friendlyHealthWidth",base="healthWidth",min=70,max=360,step=1,liveOnly=true},
    {label="Friendly Health Height",key="friendlyHealthHeight",base="healthHeight",min=8,max=48,step=1,liveOnly=true},
    {label="Friendly Cast Width",key="friendlyCastWidth",base="castWidth",min=70,max=360,step=1,liveOnly=true},
    {label="Friendly Cast Height",key="friendlyCastHeight",base="castHeight",min=6,max=40,step=1,liveOnly=true},
    {label="Friendly Name Text",key="friendlyNameFontSize",base="nameFontSize",min=7,max=30,step=1,liveOnly=true},
    {label="Friendly Level Text",key="friendlyLevelFontSize",base="levelFontSize",min=7,max=30,step=1,liveOnly=true},
    {label="Friendly Health % Text",key="friendlyHealthPercentFontSize",base="healthPercentFontSize",min=7,max=30,step=1,liveOnly=true},
    {label="Friendly Health Value Text",key="friendlyHealthValueFontSize",base="healthValueFontSize",min=7,max=30,step=1,liveOnly=true},
    {label="Friendly Cast Text",key="friendlyCastFontSize",base="castFontSize",min=7,max=26,step=1,liveOnly=true},
}

local function RefreshFriendlyPlates()
    -- Apply the visual/runtime state immediately in either direction.
    if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
    if ns.RebindAuraContainers then ns.RebindAuraContainers() end
    if ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
end

local function BuildFriendlyDialog()
    local frame = MakeSettingsDialog("friendly", "H3z0NameplatesFriendlyDialog", "Friendly Nameplates", 760, 560)
    local leftX, rightX = 28, 400

    MakeSettingHeader(frame, "Friendly Plates", leftX, -56)
    MakeSettingCheck(frame, "Use the H3z0 style on friendly nameplates", leftX, -78,
        function() return tonumber(ns.GetNameplateDesignerDB().skinFriendlyEnabled) ~= 0 end,
        function(enabled)
            ns.GetNameplateDesignerDB().skinFriendlyEnabled = enabled and 1 or 0
            RefreshFriendlyPlates()
            if menu and menu.page and menu.page.friendlySkinDropdown then
                menu.page.friendlySkinDropdown:Sync()
            end
        end)
    local npcCheck = MakeSettingCheck(frame, "Show friendly NPC nameplates", leftX, -108,
        function() return ns.GetGameNameplateSetting and ns.GetGameNameplateSetting("friendlyNpcs") end,
        function(enabled)
            if ns.SetGameNameplateSetting then ns.SetGameNameplateSetting("friendlyNpcs", enabled) end
        end)
    local nameOnlyCheck = MakeSettingCheck(frame, "Name only for friendly players", leftX, -138,
        function() return ns.GetGameNameplateSetting and ns.GetGameNameplateSetting("friendlyNameOnly") end,
        function(enabled)
            if ns.SetGameNameplateSetting then ns.SetGameNameplateSetting("friendlyNameOnly", enabled) end
        end)
    MakeSettingCheck(frame, "Friendly NPCs: name only (text only)", leftX, -168,
        function() return tonumber(ns.GetNameplateDesignerDB().friendlyNpcNameOnly) == 1 end,
        function(enabled)
            ns.GetNameplateDesignerDB().friendlyNpcNameOnly = enabled and 1 or 0
            RefreshFriendlyPlates()
        end)
    MakeSettingSlider(frame,
        {label="Friendly Size",key="friendlyScale",min=.5,max=2,step=.05,percent=true,liveOnly=true},
        leftX, -216, 330)
    MakeSettingSlider(frame,
        {label="Friendly NPC Name Height",key="friendlyNpcNameY",min=-60,max=80,step=1,liveOnly=true},
        leftX, -266, 330)
    MakeSettingHint(frame,
        "Friendly Size and the separate sizes apply while the H3z0 style is on for friendly plates.\n\nFriendly NPCs: name only hides the bars, level and icons on friendly NPC plates and keeps just the name.\n\nFriendly NPC plates and name-only for players are game settings. H3z0 Nameplates keeps them the way they are set here, and changes them outside combat only. Friendly NPC plates start switched off.\n\nInside dungeons and raids the game does not let addons restyle friendly plates.",
        leftX, -330, 330)

    MakeSettingHeader(frame, "Friendly Bar & Text Sizes", rightX, -56)
    local sizeSliders = {}
    MakeSettingCheck(frame, "Use separate sizes for friendly plates", rightX, -78,
        function() return tonumber(ns.GetNameplateDesignerDB().friendlySizesEnabled) == 1 end,
        function(enabled)
            local db = ns.GetNameplateDesignerDB()
            if enabled and db.friendlySizesSeeded ~= 1 then
                -- First use: start from the current enemy sizes, not defaults.
                for _, info in ipairs(FRIENDLY_SIZE_SLIDERS) do
                    db[info.key] = ClampDesignerValue(db[info.base], info.min, info.max)
                end
                db.friendlySizesSeeded = 1
            end
            db.friendlySizesEnabled = enabled and 1 or 0
            RefreshFriendlyPlates()
        end)
    for index, info in ipairs(FRIENDLY_SIZE_SLIDERS) do
        sizeSliders[index] = MakeSettingSlider(frame, info, rightX, -122 - (index - 1) * 46, 330)
    end

    function frame:AfterSync()
        local separate = tonumber(ns.GetNameplateDesignerDB().friendlySizesEnabled) == 1
        for _, slider in ipairs(sizeSliders) do slider:SetActive(separate) end
        npcCheck:SetActive(ns.IsGameNameplateSettingAvailable and ns.IsGameNameplateSettingAvailable("friendlyNpcs") or false)
        nameOnlyCheck:SetActive(ns.IsGameNameplateSettingAvailable and ns.IsGameNameplateSettingAvailable("friendlyNameOnly") or false)
    end
    return frame
end

-- Target & Threat ----------------------------------------------------------
local THREAT_MODES = {
    {value=0, text="Off"},
    {value=1, text="Solo with a pet: I have aggro"},
    {value=2, text="Always: I have aggro"},
    {value=3, text="Tank: I do NOT have aggro"},
}

local BuildTargetDialog
local BuildModulesDialog

BuildTargetDialog = function()
    local frame = MakeSettingsDialog("target", "H3z0NameplatesTargetDialog", "Target & Threat", 420, 470)
    local x = 28

    MakeSettingHeader(frame, "Target", x, -56)
    local color = MakeColorButton(frame, "Target glow colour", {"targetR","targetG","targetB"}, x, -80)
    frame.controls[#frame.controls + 1] = color
    MakeSettingSlider(frame,
        {label="Target Size",key="targetScale",min=1,max=1.6,step=.05,percent=true,liveOnly=true},
        x, -130, 330)
    MakeSettingSlider(frame,
        {label="Other Plates While I Have A Target",key="nonTargetAlpha",min=.2,max=1,step=.05,percent=true,liveOnly=true},
        x, -180, 330)
    MakeSettingHint(frame,
        "White keeps the standard target glow. 100% leaves size and the other plates unchanged.",
        x, -226, 360)

    MakeSettingHeader(frame, "Threat Border", x, -272)
    local threat = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
    threat:SetSize(330, 30)
    threat:SetPoint("TOPLEFT", x, -296)
    threat:SetSelectionTranslator(function(selection)
        return tostring(selection.text or "")
    end)
    function threat:Sync()
        self:SetupMenu(function(_, rootDescription)
            rootDescription:SetTag("MENU_H3Z0_NAMEPLATES_THREAT")
            for _, option in ipairs(THREAT_MODES) do
                local value = option.value
                rootDescription:CreateRadio(option.text,
                    function() return (tonumber(ns.GetNameplateDesignerDB().threatMode) or 1) == value end,
                    function()
                        ns.GetNameplateDesignerDB().threatMode = value
                        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
                    end)
            end
        end)
    end
    frame.controls[#frame.controls + 1] = threat
    MakeSettingHint(frame,
        "Shows the red border on a unit. The game only tells addons whether a unit is attacking you, not threat numbers, so there are no warning stages. The game's own threat colours and flash keep working as set under BLIZZARD NAMEPLATES.",
        x, -340, 360)
    return frame
end

-- Modules ------------------------------------------------------------------
local MODULE_SWITCHES = {
    {text="Health % text", key="hpPercentOn"},
    {text="Health value (HP) text", key="hpValueOn"},
    {text="Combo points", key="comboEnabled"},
    {text="Incoming heals", key="incomingHealsEnabled"},
    {text="Absorbs", key="absorbsEnabled"},
    {text="Damage echo", key="damageEchoEnabled"},
}

BuildModulesDialog = function()
    local frame = MakeSettingsDialog("modules", "H3z0NameplatesModulesDialog", "Modules", 420, 370)
    local x = 28
    MakeSettingHeader(frame, "Turn On / Off", x, -56)
    for index, info in ipairs(MODULE_SWITCHES) do
        local key = info.key
        frame.controls[#frame.controls + 1] = MakeSettingCheck(frame, info.text, x, -80 - (index - 1) * 30,
            function() return tonumber(ns.GetNameplateDesignerDB()[key]) == 1 end,
            function(enabled)
                ns.GetNameplateDesignerDB()[key] = enabled and 1 or 0
                if key == "comboEnabled" and menu and menu.page and menu.page.comboToggle then
                    menu.page.comboToggle:SetChecked(enabled)
                end
                if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
                if ns.RefreshNameplateDesignerPreview then ns.RefreshNameplateDesignerPreview() end
            end)
    end
    MakeSettingHint(frame,
        "Health % and health value show on every plate that has a health bar when switched on. When they are off, the game's own nameplate health text setting decides.",
        x, -270, 360)
    return frame
end

local function BuildNameplateDesignerPage(parent)
    local page=CreateFrame("Frame",nil,parent)
    page:SetAllPoints()

    -- Outer menu artwork/border stays unchanged. Only the inner layout preview
    -- was shortened vertically so the controls below have a cleaner footprint.
    local holder=BuildDesignerPreview(page)

    -- Three wide colour controls, matching the compact menu concept.
    local controlsTop=-585
    page.colorButtons={
        MakeColorButton(page,"Helpful / Healing",{"helpfulR","helpfulG","helpfulB"},95,controlsTop),
        MakeColorButton(page,"Harmful / Damage",{"harmfulR","harmfulG","harmfulB"},340,controlsTop),
        MakeColorButton(page,"Shielded cast",{"shieldR","shieldG","shieldB"},585,controlsTop),
        MakeColorButton(page,"Interrupted",{"interruptedR","interruptedG","interruptedB"},95,controlsTop-36),
    }

    local extraButtons={
        {text="SIZES",x=340,width=100,open=function() ToggleSettingsDialog("sizes",BuildSizesDialog) end},
        {text="FRIENDLY",x=445,width=105,open=function() ToggleSettingsDialog("friendly",BuildFriendlyDialog) end},
        {text="MODULES",x=555,width=105,open=function() ToggleSettingsDialog("modules",BuildModulesDialog) end},
        {text="TARGET & THREAT",x=665,width=140,open=function() ToggleSettingsDialog("target",BuildTargetDialog) end},
    }
    for _,info in ipairs(extraButtons) do
        local button=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
        button:SetSize(info.width,30)
        button:SetPoint("TOPLEFT",info.x,controlsTop-36)
        button:SetText(info.text)
        button:SetScript("OnClick",info.open)
    end

    local scaleLabel=Label(page,"GLOBAL SCALE: 100%","GameFontNormal")
    scaleLabel:SetPoint("TOPLEFT",120,-672)
    scaleLabel:SetTextColor(1,.75,.45)
    local globalScale=CreateFrame("Slider",nil,page,"BackdropTemplate")
    globalScale:SetSize(300,16)
    globalScale:SetPoint("TOPLEFT",120,-695)
    globalScale:SetOrientation("HORIZONTAL")
    globalScale:SetMinMaxValues(.5,2)
    globalScale:SetValueStep(.05)
    if globalScale.SetObeyStepOnDrag then globalScale:SetObeyStepOnDrag(true) end
    Backdrop(globalScale,.065,.22)
    local thumb=globalScale:CreateTexture(nil,"OVERLAY")
    thumb:SetColorTexture(1,.32,.08,1)
    thumb:SetSize(10,22)
    globalScale:SetThumbTexture(thumb)
    page.globalScaleSlider=globalScale
    page.globalScaleLabel=scaleLabel
    globalScale:SetScript("OnValueChanged",function(self,value)
        if self.syncing then return end
        value=math.floor((tonumber(value) or 1)*20+.5)/20
        local db=ns.GetNameplateDesignerDB()
        db.globalScale=value
        scaleLabel:SetText(string.format("GLOBAL SCALE: %d%%",math.floor(value*100+.5)))
        -- Global scale is live-only; the layout canvas stays fixed.
        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
        if ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
    end)

    -- Cast-height changes only bar height. Icon/shield stay square and scale
    -- proportionally with the height.
    local castHeightLabel=Label(page,"CAST HEIGHT: 13","GameFontNormal")
    castHeightLabel:SetPoint("TOPLEFT",480,-672)
    castHeightLabel:SetTextColor(1,.75,.45)
    local castHeight=CreateFrame("Slider",nil,page,"BackdropTemplate")
    castHeight:SetSize(300,16)
    castHeight:SetPoint("TOPLEFT",480,-695)
    castHeight:SetOrientation("HORIZONTAL")
    castHeight:SetMinMaxValues(6,40)
    castHeight:SetValueStep(1)
    if castHeight.SetObeyStepOnDrag then castHeight:SetObeyStepOnDrag(true) end
    Backdrop(castHeight,.065,.22)
    local castHeightThumb=castHeight:CreateTexture(nil,"OVERLAY")
    castHeightThumb:SetColorTexture(1,.32,.08,1)
    castHeightThumb:SetSize(10,22)
    castHeight:SetThumbTexture(castHeightThumb)
    page.castHeightSlider=castHeight
    page.castHeightLabel=castHeightLabel
    castHeight:SetScript("OnValueChanged",function(self,value)
        if self.syncing then return end
        value=math.floor((tonumber(value) or 13)+.5)
        local db=ns.GetNameplateDesignerDB()
        local oldHeight=tonumber(db.castHeight) or 13
        if oldHeight<=0 then oldHeight=13 end
        local factor=value/oldHeight
        db.castHeight=value
        db.iconSize=ClampDesignerValue((tonumber(db.iconSize) or 17)*factor,8,80)
        db.shieldSize=ClampDesignerValue((tonumber(db.shieldSize) or 20)*factor,8,80)
        castHeightLabel:SetText(string.format("CAST HEIGHT: %d",value))
        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner() end
        SyncExtraDialogs()
    end)
    function page:SyncCastHeight()
        local current=ns.GetNameplateDesignerDB().castHeight or 13
        castHeight.syncing=true
        castHeight:SetValue(current)
        castHeight.syncing=false
        castHeightLabel:SetText(string.format("CAST HEIGHT: %d",math.floor(current+.5)))
    end

    -- Three configurable controls plus a read-only native-aura status.
    local dropdownY=-735
    local dropdownW=190
    local dropdownX={55,260,465,670}

    local function MakeMediaDropdown(key,title,x,y,allowMatchHealth)
        local button=CreateFrame("DropdownButton",nil,page,"WowStyle1DropdownTemplate")
        button:SetSize(dropdownW,30)
        button:SetPoint("TOPLEFT",x,y or dropdownY)
        button.mediaKey=key
        button.mediaTitle=title
        button:SetSelectionTranslator(function(selection)
            return title..": "..tostring(selection.text or (allowMatchHealth and "Match Health" or "H3z0 Flat"))
        end)
        function button:Sync()
            local names={}
            if allowMatchHealth then names[#names+1]="Match Health" end
            for _,name in ipairs(ns.GetStatusbarMediaNames and ns.GetStatusbarMediaNames() or {"H3z0 Flat"}) do
                if not (allowMatchHealth and name=="Match Health") then names[#names+1]=name end
            end
            self:SetupMenu(function(_,rootDescription)
                rootDescription:SetTag("MENU_H3Z0_NAMEPLATES_"..string.upper(key))
                for _,name in ipairs(names) do
                    local mediaName=name
                    rootDescription:CreateRadio(mediaName,
                        function() return ns.GetNameplateDesignerDB()[key]==mediaName end,
                        function()
                            ns.GetNameplateDesignerDB()[key]=mediaName
                            if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
                            if effectsDialog and effectsDialog:IsShown() then effectsDialog:Sync() end
                        end)
                end
            end)
        end
        return button
    end

    local effectsButton=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
    effectsButton:SetSize(85,26)
    effectsButton:SetPoint("TOPLEFT",dropdownX[4]+105,dropdownY-44)
    effectsButton:SetText("EFFECTS")
    effectsButton:SetScript("OnClick",OpenEffectsDialog)
    page.effectsButton=effectsButton

    local friendlyDropdown=CreateFrame("DropdownButton",nil,page,"WowStyle1DropdownTemplate")
    friendlyDropdown:SetSize(dropdownW,30)
    friendlyDropdown:SetPoint("TOPLEFT",dropdownX[4],dropdownY)
    friendlyDropdown:SetSelectionTranslator(function(selection)
        return "FRIENDLY: "..tostring(selection.text or "OFF")
    end)

    local function SetFriendlySkinEnabled(enabled)
        local db=ns.GetNameplateDesignerDB()
        local currentlyOn=tonumber(db.skinFriendlyEnabled)~=0
        enabled=enabled and true or false
        if currentlyOn==enabled then return end
        db.skinFriendlyEnabled=enabled and 1 or 0

        -- Apply the visual/runtime state immediately in either direction.
        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
        if ns.RebindAuraContainers then ns.RebindAuraContainers() end
        if ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
        page:Sync()
    end

    function friendlyDropdown:Sync()
        self:SetupMenu(function(_,rootDescription)
            rootDescription:SetTag("MENU_H3Z0_NAMEPLATES_FRIENDLY")
            rootDescription:CreateRadio("ON",
                function() return tonumber(ns.GetNameplateDesignerDB().skinFriendlyEnabled)~=0 end,
                function() SetFriendlySkinEnabled(true) end)
            rootDescription:CreateRadio("OFF",
                function() return tonumber(ns.GetNameplateDesignerDB().skinFriendlyEnabled)==0 end,
                function() SetFriendlySkinEnabled(false) end)
        end)
    end
    page.friendlySkinDropdown=friendlyDropdown

    page.healthTextureButton=MakeMediaDropdown("healthTexture","HEALTH",dropdownX[1])
    page.castTextureButton=MakeMediaDropdown("castTexture","CAST",dropdownX[2])
    page.comboTextureButton=MakeMediaDropdown("comboTexture","COMBO",dropdownX[3])
    page.incomingHealTextureButton=MakeMediaDropdown("incomingHealTexture","HEALS",dropdownX[1],dropdownY-44,true)
    page.absorbTextureButton=MakeMediaDropdown("absorbTexture","ABSORBS",dropdownX[2],dropdownY-44,true)
    page.damageEchoTextureButton=MakeMediaDropdown("damageEchoTexture","ECHO",dropdownX[3],dropdownY-44,true)

    local comboToggle=CreateFrame("CheckButton",nil,page,"UICheckButtonTemplate")
    comboToggle:SetPoint("TOPLEFT",dropdownX[4],dropdownY-44)
    comboToggle:SetSize(24,24)
    local comboText=Label(page,"Enable Combo Points","GameFontHighlightSmall")
    comboText:SetPoint("LEFT",comboToggle,"RIGHT",3,0)
    comboToggle:SetScript("OnClick",function(self)
        local db=ns.GetNameplateDesignerDB()
        db.comboEnabled=self:GetChecked() and 1 or 0
        if ns.RefreshNameplateDesigner then ns.RefreshNameplateDesigner(true) end
        if ns.RefreshNameplateDesignerPreview then ns.RefreshNameplateDesignerPreview() end
    end)
    page.comboToggle=comboToggle

    -- Bottom utility row remains the familiar H3z0 red-button layout.
    local buttonY=-829
    local blizzardOptions=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
    blizzardOptions:SetSize(180,30)
    blizzardOptions:SetPoint("TOPLEFT",65,buttonY)
    blizzardOptions:SetText("BLIZZARD NAMEPLATES")
    blizzardOptions:SetScript("OnClick",function()
        if menu then menu:Hide() end
        OpenBlizzardNameplateOptions()
    end)

    local exportLayout=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
    exportLayout:SetSize(180,30)
    exportLayout:SetPoint("TOPLEFT",260,buttonY)
    exportLayout:SetText("EXPORT PROFILE")
    exportLayout:SetScript("OnClick",function() ShowProfileDialog("export") end)

    local importLayout=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
    importLayout:SetSize(180,30)
    importLayout:SetPoint("TOPLEFT",455,buttonY)
    importLayout:SetText("IMPORT PROFILE")
    importLayout:SetScript("OnClick",function() ShowProfileDialog("import") end)

    local reset=CreateFrame("Button",nil,page,"UIPanelButtonTemplate")
    reset:SetSize(180,30)
    reset:SetPoint("TOPLEFT",650,buttonY)
    reset:SetText("RESET PROFILE")

    function page:Sync()
        for _,button in ipairs(self.colorButtons) do button:Sync() end
        local designerDB=ns.GetNameplateDesignerDB()
        self.globalScaleSlider.syncing=true
        self.globalScaleSlider:SetValue(designerDB.globalScale or 1)
        self.globalScaleSlider.syncing=false
        self.globalScaleLabel:SetText(string.format("GLOBAL SCALE: %d%%",math.floor((designerDB.globalScale or 1)*100+.5)))
        self.castHeightSlider.syncing=true
        self.castHeightSlider:SetValue(designerDB.castHeight or 13)
        self.castHeightSlider.syncing=false
        self.castHeightLabel:SetText(string.format("CAST HEIGHT: %d",math.floor((designerDB.castHeight or 13)+.5)))
        self.healthTextureButton:Sync()
        self.castTextureButton:Sync()
        self.comboTextureButton:Sync()
        self.incomingHealTextureButton:Sync()
        self.absorbTextureButton:Sync()
        self.damageEchoTextureButton:Sync()
        self.comboToggle:SetChecked(tonumber(designerDB.comboEnabled)~=0)
        self.friendlySkinDropdown:Sync()
        ns.RefreshNameplateDesignerPreview()
        SyncExtraDialogs()
    end

    reset:SetScript("OnClick",function()
        ns.ResetNameplateDesignerDB()
        local auraDB=GetAuraLayoutDB()
        for key,value in pairs(AURA_LAYOUT_DEFAULTS) do auraDB[key]=value end
        if ns.RefreshNameplates then ns.RefreshNameplates() end
        if ns.RefreshAuraContainers then ns.RefreshAuraContainers() end
        page:Sync()
    end)
    page:SetScript("OnShow",function(self) self:Sync() end)
    page:Sync()
    return page
end

local function BuildMenu()
    if menu then return end
    menu=CreateFrame("Frame","H3z0NameplatesMainMenu",UIParent)
    -- Match the aspect ratio of the 1249x1297 menu artwork.
    menu:SetSize(900,935)
    local w,h=UIParent:GetWidth() or 900,UIParent:GetHeight() or 935
    menu:SetScale(math.min(1,w/940,h/975))
    menu:SetPoint("CENTER")
    -- Keep the addon panel below Blizzard's DIALOG/FULLSCREEN_DIALOG menu
    -- strata. Native dropdown menus must always render above the artwork.
    menu:SetFrameStrata("HIGH")
    menu:SetFrameLevel(20)
    menu:SetToplevel(true)
    menu:SetClampedToScreen(true)
    menu:SetMovable(true)
    menu:EnableMouse(true)
    menu:RegisterForDrag("LeftButton")
    menu:SetScript("OnDragStart",function(self) if not InCombatLockdown() then self:StartMoving() end end)
    menu:SetScript("OnDragStop",function(self) self:StopMovingOrSizing() end)
    table.insert(UISpecialFrames,menu:GetName())

    local background=menu:CreateTexture(nil,"BACKGROUND",nil,-8)
    background:SetAllPoints(menu)
    background:SetTexture(MENU_BACKGROUND)
    menu.background=background

    local close=CreateFrame("Button",nil,menu,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-28,-28)
    close:SetScript("OnClick",function() menu:Hide() end)

    local page=BuildNameplateDesignerPage(menu)
    menu.page=page

    -- Editing is disabled in combat because the preview applies changes to the
    -- live Blizzard-owned nameplate presentation.
    menu:SetScript("OnShow",function(self)
        PlayOpenFade(self)
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN then
            PlaySound(SOUNDKIT.IG_MAINMENU_OPEN)
        end
    end)
    menu:SetScript("OnHide",function(self)
        if effectsDialog and effectsDialog:IsShown() then effectsDialog:Hide() end
        HideExtraDialogs()
        if PlaySound and SOUNDKIT and SOUNDKIT.IG_MAINMENU_CLOSE then
            PlaySound(SOUNDKIT.IG_MAINMENU_CLOSE)
        end
    end)
    menu:Hide()

    combatGuard=combatGuard or CreateFrame("Frame")
    combatGuard:RegisterEvent("PLAYER_REGEN_DISABLED")
    combatGuard:SetScript("OnEvent",function()
        if menu and menu:IsShown() then menu:Hide() end
        if profileDialog and profileDialog:IsShown() then profileDialog:Hide() end
        if effectsDialog and effectsDialog:IsShown() then effectsDialog:Hide() end
        HideExtraDialogs()
    end)
end

function ns.OpenMainMenu()
    if InCombatLockdown and InCombatLockdown() then
        print("H3z0 Nameplates: the options menu cannot be opened during combat.")
        return
    end
    BuildMenu(); menu:Show(); menu:Raise()
end

SLASH_H3Z0NAMEPLATES1="/hnp"
SLASH_H3Z0NAMEPLATES2="/h3z0np"
SLASH_H3Z0NAMEPLATES3="/h3z0nameplates"
SlashCmdList.H3Z0NAMEPLATES=function() ns.OpenMainMenu() end
