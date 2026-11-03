-- Shield Aura Forever v1.1.0
-- Clean-room WoW Forever addon. No WeakAuras or nanShield code/assets are reused.
-- Designed around Forever's secret-value restrictions: raw absorb values are only
-- passed into Blizzard-native display APIs, never used in combat arithmetic.

local ADDON_NAME = ...
local ADDON_VERSION = "1.1.0"
local AURA_TEXTURE = "Interface\\AddOns\\ShieldAuraForever\\Media\\shield_aura.tga"
local AURA_TEXTURE_MIRRORED = "Interface\\AddOns\\ShieldAuraForever\\Media\\shield_aura_mirrored.tga"
local CURVE_NEUTRAL = "Interface\\AddOns\\ShieldAuraForever\\Media\\shield_aura_neutral.tga"
local CURVE_MIRRORED_NEUTRAL = "Interface\\AddOns\\ShieldAuraForever\\Media\\shield_aura_mirrored_neutral.tga"
local CURVE_SOLID = "Interface\\AddOns\\ShieldAuraForever\\Media\\shield_aura_solid_neutral.tga"
local CURVE_MIRRORED_SOLID = "Interface\\AddOns\\ShieldAuraForever\\Media\\shield_aura_mirrored_solid_neutral.tga"
local HORIZONTAL_SEGMENTS = "Interface\\AddOns\\ShieldAuraForever\\Media\\shield_horizontal_segments_neutral.tga"
local HORIZONTAL_SOLID = "Interface\\Buttons\\WHITE8X8"
local ICON_TEXTURE = "Interface\\AddOns\\ShieldAuraForever\\Media\\shieldaura_icon.tga"

-- Color choices remain class-labeled for accessibility. Gold preserves the exact
-- original segmented-curve artwork on upgraded installations.
local colorOptions = {
    { value = "auto", label = "Automatic - My Class" },
    { value = "gold", label = "Original - Gold" },
    { value = "WARRIOR", label = "Warrior - Brown" },
    { value = "PALADIN", label = "Paladin - Pink" },
    { value = "HUNTER", label = "Hunter - Green" },
    { value = "ROGUE", label = "Rogue - Yellow" },
    { value = "PRIEST", label = "Priest - White" },
    { value = "SHAMAN", label = "Shaman - Blue" },
    { value = "MAGE", label = "Mage - Light Blue" },
    { value = "WARLOCK", label = "Warlock - Purple" },
    { value = "DRUID", label = "Druid - Orange" },
}
local classColorFallback = {
    WARRIOR = {0.78, 0.61, 0.43}, PALADIN = {0.96, 0.55, 0.73},
    HUNTER = {0.67, 0.83, 0.45}, ROGUE = {1, 0.96, 0.41},
    PRIEST = {1, 1, 1}, SHAMAN = {0, 0.44, 0.87},
    MAGE = {0.25, 0.78, 0.92}, WARLOCK = {0.53, 0.53, 0.93},
    DRUID = {1, 0.49, 0.04},
}

local defaults = {
    x = 95,
    y = 20,
    scale = 1.0,
    locked = true,
    showText = true,
    textPosition = "bottom", -- "bottom" (default) or "top"
    reverseFill = false, -- false = drain from top first (preferred default)
    showMinimap = true,
    minimapAngle = 220,
    minimapRadius = 105, -- pixels from minimap center; aligned with the surrounding Forever minimap buttons
    animateLoss = true,
    mirrorCurve = false, -- false = bow right; true = mirrored for a left-side HUD
    layout = "curved", -- "curved" or "horizontal"; both use a single live status bar
    barStyle = "segmented", -- "segmented" or "solid"
    colorMode = "auto", -- new installs follow class; upgrades retain original gold
    horizontalX = 0, -- separate movable position, centered beneath the character
    horizontalY = -105,
    windowX = -420,
    windowY = 80,
    schemaVersion = 10,
}

local db
local runtimeMax
local testing = false
local lastAbsorb
local suppressAnimationUntil = 0
local optionsCategoryID
local optionsPanel
local controlWindow
local minimapButton

local optionControls = {}
local windowControls = {}

local function IsSecret(v)
    return issecretvalue and issecretvalue(v) or false
end

local function Print(msg)
    DEFAULT_CHAT_FRAME:AddMessage("|cffffd35aShield Aura Forever:|r " .. msg)
end

local function CopyDefaults()
    local hadOldSettings = type(ShieldAuraForeverDB) == "table" and next(ShieldAuraForeverDB) ~= nil
    ShieldAuraForeverDB = ShieldAuraForeverDB or {}

    -- One-time migration from v0.1. v0.1 used Frame:SetScale(), which could
    -- corrupt drag coordinates after changing scale. v0.2+ resizes geometry.
    if hadOldSettings and (ShieldAuraForeverDB.schemaVersion or 1) < 2 then
        ShieldAuraForeverDB.scale = 1.0
        ShieldAuraForeverDB.reverseFill = false
        ShieldAuraForeverDB.x = defaults.x
        ShieldAuraForeverDB.y = defaults.y
        ShieldAuraForeverDB.schemaVersion = 2
    end

    if (ShieldAuraForeverDB.schemaVersion or 1) < 3 then
        ShieldAuraForeverDB.schemaVersion = 3
    end

    -- v0.4 adds the movable control window and minimap button. Existing HUD
    -- position, scale, direction, text preference, and calibration are retained.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 4 then
        ShieldAuraForeverDB.schemaVersion = 4
    end

    -- v0.5 adds radial minimap-button positioning and shield-loss animation.
    -- Existing users receive the new slightly-farther-out default radius.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 5 then
        ShieldAuraForeverDB.minimapRadius = defaults.minimapRadius
        if ShieldAuraForeverDB.animateLoss == nil then
            ShieldAuraForeverDB.animateLoss = defaults.animateLoss
        end
        ShieldAuraForeverDB.schemaVersion = 5
    end

    -- v0.6 corrects the minimap default and adds curve mirroring. Only the
    -- exact old v0.5 default is migrated; user-adjusted radii are preserved.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 6 then
        if ShieldAuraForeverDB.minimapRadius == 88 then
            ShieldAuraForeverDB.minimapRadius = defaults.minimapRadius
        end
        if ShieldAuraForeverDB.mirrorCurve == nil then
            ShieldAuraForeverDB.mirrorCurve = defaults.mirrorCurve
        end
        ShieldAuraForeverDB.schemaVersion = 6
    end

    -- v0.7 expands the allowed minimap-button distance and changes the
    -- public/display name to Shield Aura Forever. Existing settings are kept.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 7 then
        ShieldAuraForeverDB.schemaVersion = 7
    end

    -- v0.8 stores calibration per character instead of globally so a Priest
    -- PW:S maximum cannot distort a Warlock Sacrifice (or another character's
    -- absorb). Existing v0.7 calibration is assigned to the current character.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 8 then
        ShieldAuraForeverDB.maxAbsorbs = ShieldAuraForeverDB.maxAbsorbs or {}
        local guid = UnitGUID and UnitGUID("player")
        if guid and ShieldAuraForeverDB.maxAbsorb ~= nil then
            ShieldAuraForeverDB.maxAbsorbs[guid] = ShieldAuraForeverDB.maxAbsorb
        end
        ShieldAuraForeverDB.maxAbsorb = nil
        ShieldAuraForeverDB.schemaVersion = 8
    end

    -- v0.9 added a configurable absorb-number position.
    -- Existing users keep the historical/default placement beneath the aura.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 9 then
        if ShieldAuraForeverDB.textPosition ~= "top" then
            ShieldAuraForeverDB.textPosition = defaults.textPosition
        end
        ShieldAuraForeverDB.schemaVersion = 9
    end

    -- v1.1 introduces visual-only layouts and colors. Existing users retain
    -- their exact original gold appearance and their curved HUD position.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 10 then
        if hadOldSettings and ShieldAuraForeverDB.colorMode == nil then
            ShieldAuraForeverDB.colorMode = "gold"
        end
        ShieldAuraForeverDB.schemaVersion = 10
    end

    ShieldAuraForeverDB.maxAbsorbs = ShieldAuraForeverDB.maxAbsorbs or {}

    for k, v in pairs(defaults) do
        if ShieldAuraForeverDB[k] == nil then
            ShieldAuraForeverDB[k] = v
        end
    end
    db = ShieldAuraForeverDB
end

local function CharacterKey()
    return (UnitGUID and UnitGUID("player")) or (UnitName and UnitName("player")) or "player"
end

local function GetSavedMaximum()
    if not db or type(db.maxAbsorbs) ~= "table" then return nil end
    return db.maxAbsorbs[CharacterKey()]
end

local function SaveMaximum(value)
    if not db or IsSecret(value) or type(value) ~= "number" or value <= 0 then return end
    db.maxAbsorbs = db.maxAbsorbs or {}
    db.maxAbsorbs[CharacterKey()] = value
end

-- -----------------------------------------------------------------------------
-- HUD
-- -----------------------------------------------------------------------------

local BASE_HUD_W = 64
local BASE_HUD_H = 158
local BASE_BAR_W = 34
local BASE_BAR_H = 132
local BASE_FONT_SIZE = 13
local HORIZONTAL_HUD_W = 184
local HORIZONTAL_HUD_H = 56
local HORIZONTAL_BAR_W = 160
local HORIZONTAL_BAR_H = 16

local function ResolveShieldColor()
    local mode = db and db.colorMode or "gold"
    if mode == "gold" then return 1, 0.90, 0.20, true end
    if mode == "auto" then
        local _, playerClass = UnitClass("player")
        mode = playerClass or "PRIEST"
    end
    local color = RAID_CLASS_COLORS and RAID_CLASS_COLORS[mode]
    if color then return color.r, color.g, color.b, false end
    local fallback = classColorFallback[mode] or classColorFallback.PRIEST
    return fallback[1], fallback[2], fallback[3], false
end

local function GetBarTexture()
    local curved = db.layout ~= "horizontal"
    local solid = db.barStyle == "solid"
    local mirrored = db.mirrorCurve == true
    if not curved then
        return solid and HORIZONTAL_SOLID or HORIZONTAL_SEGMENTS, false
    end
    if solid then
        return mirrored and CURVE_MIRRORED_SOLID or CURVE_SOLID, false
    end
    if db.colorMode == "gold" then
        return mirrored and AURA_TEXTURE_MIRRORED or AURA_TEXTURE, true
    end
    return mirrored and CURVE_MIRRORED_NEUTRAL or CURVE_NEUTRAL, false
end

local hud = CreateFrame("Frame", "ShieldAuraForeverHUD", UIParent, "BackdropTemplate")
hud:SetSize(BASE_HUD_W, BASE_HUD_H)
hud:SetPoint("CENTER", UIParent, "CENTER", defaults.x, defaults.y)
hud:SetMovable(true)
hud:SetClampedToScreen(true)
hud:RegisterForDrag("LeftButton")

local ghostBar = CreateFrame("StatusBar", nil, hud)
ghostBar:SetSize(BASE_BAR_W, BASE_BAR_H)
ghostBar:SetPoint("TOP", hud, "TOP", 0, -4)
ghostBar:SetOrientation("VERTICAL")
ghostBar:SetReverseFill(false)
ghostBar:SetMinMaxValues(0, 1)
ghostBar:SetValue(0)
ghostBar:SetStatusBarTexture(AURA_TEXTURE)
ghostBar:SetStatusBarColor(1, 0.82, 0.16, 0.72)
ghostBar:SetFrameLevel((hud:GetFrameLevel() or 0) + 1)
ghostBar:Hide()

local ghostAnim = ghostBar:CreateAnimationGroup()
local ghostFade = ghostAnim:CreateAnimation("Alpha")
ghostFade:SetFromAlpha(0.72)
ghostFade:SetToAlpha(0)
ghostFade:SetDuration(0.22)
ghostFade:SetOrder(1)
local ghostMove = ghostAnim:CreateAnimation("Translation")
ghostMove:SetOffset(0, 10)
ghostMove:SetDuration(0.22)
ghostMove:SetOrder(1)
if ghostMove.SetSmoothing then ghostMove:SetSmoothing("OUT") end
ghostAnim:SetScript("OnFinished", function()
    ghostBar:Hide()
    ghostBar:SetAlpha(1)
end)
ghostAnim:SetScript("OnStop", function()
    ghostBar:Hide()
    ghostBar:SetAlpha(1)
end)

local bar = CreateFrame("StatusBar", nil, hud)
bar:SetSize(BASE_BAR_W, BASE_BAR_H)
bar:SetPoint("TOP", hud, "TOP", 0, -4)
bar:SetOrientation("VERTICAL")
bar:SetReverseFill(false)
bar:SetMinMaxValues(0, 1)
bar:SetValue(0)
bar:SetStatusBarTexture(AURA_TEXTURE)
bar:SetStatusBarColor(1, 1, 1, 1)
bar:SetFrameLevel((hud:GetFrameLevel() or 0) + 2)

local valueText = hud:CreateFontString(nil, "OVERLAY")
valueText:SetFont(STANDARD_TEXT_FONT, BASE_FONT_SIZE, "OUTLINE")
valueText:SetPoint("TOP", bar, "BOTTOM", 0, 1)
valueText:SetTextColor(1.0, 0.90, 0.20, 1)
valueText:SetShadowOffset(1, -1)
valueText:SetText("")

local unlockBG = hud:CreateTexture(nil, "BACKGROUND")
unlockBG:SetAllPoints()
unlockBG:SetColorTexture(0.1, 0.1, 0.1, 0.45)
unlockBG:Hide()

local unlockLabel = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
unlockLabel:SetPoint("BOTTOM", hud, "TOP", 0, 3)
unlockLabel:SetText("Shield Aura Forever — drag to move")
unlockLabel:Hide()

-- Cosmetic-only renderer: never interprets or calculates protected absorb values.
local function ApplyLayout()
    if not db then return end

    local scale = db.scale or 1
    local horizontal = db.layout == "horizontal"
    local texture, originalGold = GetBarTexture()
    local r, g, b = ResolveShieldColor()

    if ghostAnim:IsPlaying() then ghostAnim:Stop() end
    ghostBar:Hide()
    ghostBar:SetStatusBarTexture(texture)
    bar:SetStatusBarTexture(texture)
    if originalGold then
        -- Original gold assets and tint remain unchanged for upgraded users.
        bar:SetStatusBarColor(1, 1, 1, 1)
        ghostBar:SetStatusBarColor(1, 0.82, 0.16, 0.72)
    else
        bar:SetStatusBarColor(r, g, b, 1)
        ghostBar:SetStatusBarColor(r, g, b, 0.72)
    end
    valueText:SetTextColor(r, g, b, 1)

    -- Resize geometry, not Frame:SetScale(), preserving accurate drag offsets.
    hud:SetScale(1)
    local hudW = horizontal and HORIZONTAL_HUD_W or BASE_HUD_W
    local hudH = horizontal and HORIZONTAL_HUD_H or BASE_HUD_H
    local barW = horizontal and HORIZONTAL_BAR_W or BASE_BAR_W
    local barH = horizontal and HORIZONTAL_BAR_H or BASE_BAR_H
    local barTop = horizontal and -9 or -4
    hud:SetSize(hudW * scale, hudH * scale)
    for _, status in ipairs({ ghostBar, bar }) do
        status:SetSize(barW * scale, barH * scale)
        status:ClearAllPoints()
        status:SetPoint("TOP", hud, "TOP", 0, barTop * scale)
        status:SetOrientation(horizontal and "HORIZONTAL" or "VERTICAL")
        status:SetReverseFill(db.reverseFill == true)
    end

    valueText:ClearAllPoints()
    if db.textPosition == "top" then
        valueText:SetPoint("BOTTOM", bar, "TOP", 0, 1 * scale)
    else
        valueText:SetPoint("TOP", bar, "BOTTOM", 0, 1 * scale)
    end
    valueText:SetFont(STANDARD_TEXT_FONT, math.max(8, BASE_FONT_SIZE * scale), "OUTLINE")

    hud:ClearAllPoints()
    if horizontal then
        hud:SetPoint("CENTER", UIParent, "CENTER", db.horizontalX or defaults.horizontalX, db.horizontalY or defaults.horizontalY)
    else
        hud:SetPoint("CENTER", UIParent, "CENTER", db.x or defaults.x, db.y or defaults.y)
    end

    if db.showText == false then valueText:Hide() else valueText:Show() end
    hud:EnableMouse(not db.locked)
    if db.locked then
        unlockBG:Hide()
        unlockLabel:Hide()
    else
        unlockBG:Show()
        unlockLabel:Show()
    end
end

local function SaveHUDPosition()
    local hx, hy = hud:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if hx and hy and ux and uy then
        if db.layout == "horizontal" then
            db.horizontalX = hx - ux
            db.horizontalY = hy - uy
        else
            db.x = hx - ux
            db.y = hy - uy
        end
    end
end

hud:SetScript("OnDragStart", function(self)
    if db and not db.locked then
        self:StartMoving()
    end
end)

hud:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    if db then
        SaveHUDPosition()
        ApplyLayout()
    end
end)

local function SetBarMaximum(maxValue)
    runtimeMax = maxValue
    ghostBar:SetMinMaxValues(0, maxValue)
    bar:SetMinMaxValues(0, maxValue)
end

local function StartLossAnimation(previousValue)
    if not db or db.layout == "horizontal" or db.animateLoss == false or previousValue == nil then return end
    if ghostAnim:IsPlaying() then ghostAnim:Stop() end
    if runtimeMax ~= nil then ghostBar:SetMinMaxValues(0, runtimeMax) end
    ghostBar:SetValue(previousValue)
    ghostBar:SetAlpha(0.72)
    -- Animation direction is intentionally linked to the fill direction so the
    -- consumed end always drifts away from the aura: up for top-first drain,
    -- down for bottom-first drain. There is no separate direction state that
    -- can become mismatched.
    local drift = (db.reverseFill == true) and -10 or 10
    ghostMove:SetOffset(0, drift * (db.scale or 1))
    ghostBar:Show()
    ghostAnim:Play()
end

local function UpdateAbsorb(animateChange)
    if testing then return end
    if not UnitGetTotalAbsorbs then return end

    local ok, absorb = pcall(UnitGetTotalAbsorbs, "player")
    if not ok or absorb == nil then return end

    if runtimeMax == nil then
        local savedMax = GetSavedMaximum()
        if savedMax ~= nil then
            runtimeMax = savedMax
            ghostBar:SetMinMaxValues(0, runtimeMax)
            bar:SetMinMaxValues(0, runtimeMax)
        elseif IsSecret(absorb) then
            -- If our first useful reading happens in combat, a native StatusBar
            -- can safely accept the protected value as the initial maximum.
            SetBarMaximum(absorb)
        elseif type(absorb) == "number" and absorb > 0 then
            SetBarMaximum(absorb)
        else
            -- Do not lock a new character to a meaningless 0 maximum before
            -- their first shield is applied.
            ghostBar:SetMinMaxValues(0, 1)
            bar:SetMinMaxValues(0, 1)
        end
    end

    -- Out of combat the absorb is an ordinary number, so a newly applied or
    -- stacked shield can safely become the new 100% value. This makes the HUD
    -- self-calibrate for most absorb effects, not only Power Word: Shield.
    if not IsSecret(absorb) and type(absorb) == "number" and absorb > 0 then
        local canCompareLast = lastAbsorb == nil or not IsSecret(lastAbsorb)
        if runtimeMax == nil or (canCompareLast and (lastAbsorb == nil or absorb > lastAbsorb)) then
            SetBarMaximum(absorb)
            SaveMaximum(absorb)
        end
    end

    -- Secret-safe in combat: protected previous/current values are only handed
    -- to native StatusBars. Out of combat, animate only genuine decreases so
    -- adding/refreshing a shield does not create a false loss animation.
    local shouldAnimate = animateChange and lastAbsorb ~= nil
    if shouldAnimate and not IsSecret(absorb) and not IsSecret(lastAbsorb) then
        shouldAnimate = type(absorb) == "number" and type(lastAbsorb) == "number" and absorb < lastAbsorb
    end
    if shouldAnimate then
        StartLossAnimation(lastAbsorb)
    end
    bar:SetValue(absorb)
    lastAbsorb = absorb

    if db and db.showText ~= false then
        if C_StringUtil and C_StringUtil.TruncateWhenZero then
            local text = C_StringUtil.TruncateWhenZero(absorb)
            valueText:SetText(text)
        else
            valueText:SetFormattedText("%.0f", absorb)
        end
    end
end

local function Calibrate(silent)
    if not UnitGetTotalAbsorbs then
        if not silent then Print("UnitGetTotalAbsorbs is unavailable on this client.") end
        return
    end

    local ok, absorb = pcall(UnitGetTotalAbsorbs, "player")
    if not ok or absorb == nil then
        if not silent then Print("Could not read your current absorb value.") end
        return
    end

    if IsSecret(absorb) then
        SetBarMaximum(absorb)
        bar:SetValue(absorb)
        lastAbsorb = absorb
        if not silent then
            Print("Temporary combat calibration applied. A fresh shield cast out of combat can save its full value for this character.")
        end
        return
    end

    if type(absorb) == "number" and absorb > 0 then
        SaveMaximum(absorb)
        runtimeMax = absorb
        ghostBar:SetMinMaxValues(0, absorb)
        bar:SetMinMaxValues(0, absorb)
        bar:SetValue(absorb)
        lastAbsorb = absorb
        if not silent then
            Print("Calibrated full shield at " .. math.floor(absorb) .. ".")
        end
    elseif not silent then
        Print("Nothing to calibrate. Apply a fresh absorb shield to yourself, then calibrate.")
    end
end

local function IsPowerWordShieldSpell(spellID)
    if spellID == nil or IsSecret(spellID) then return false end
    if type(spellID) ~= "number" then return false end

    if C_Spell and C_Spell.GetSpellName then
        local pwsName = C_Spell.GetSpellName(17)
        local castName = C_Spell.GetSpellName(spellID)
        return pwsName ~= nil and castName == pwsName
    end

    return spellID == 17 or spellID == 592 or spellID == 600 or spellID == 3747
        or spellID == 6065 or spellID == 6066 or spellID == 10898
        or spellID == 10899 or spellID == 10900 or spellID == 10901
end

local function IsVoidwalkerSacrificeSpell(spellID)
    if spellID == nil or IsSecret(spellID) or type(spellID) ~= "number" then return false end

    -- Forever currently uses the classic Voidwalker Sacrifice rank spell IDs.
    return spellID == 7812 or spellID == 19438 or spellID == 19440
        or spellID == 19441 or spellID == 19442 or spellID == 19443
end

-- -----------------------------------------------------------------------------
-- Shared settings actions
-- -----------------------------------------------------------------------------

local function SetLocked(locked, silent)
    db.locked = locked and true or false
    ApplyLayout()
    if not silent then
        Print(db.locked and "locked." or "unlocked. Drag the shaded box; lock it when finished.")
    end
end

local function SetScale(value, silent)
    local n = tonumber(value)
    if not n then return false end
    n = math.max(0.5, math.min(2.5, n))
    n = math.floor(n * 20 + 0.5) / 20
    db.scale = n
    ApplyLayout()
    if not silent then Print(string.format("scale set to %.2f.", n)) end
    return true
end

local function ResetHUDLayout(preserveCalibration)
    local savedMax = preserveCalibration and GetSavedMaximum() or nil
    db.x = defaults.x
    db.y = defaults.y
    db.horizontalX = defaults.horizontalX
    db.horizontalY = defaults.horizontalY
    db.layout = defaults.layout
    db.barStyle = defaults.barStyle
    db.colorMode = defaults.colorMode
    db.scale = defaults.scale
    db.locked = defaults.locked
    db.showText = defaults.showText
    db.textPosition = defaults.textPosition
    db.reverseFill = defaults.reverseFill
    db.mirrorCurve = defaults.mirrorCurve
    if not preserveCalibration and db.maxAbsorbs then
        db.maxAbsorbs[CharacterKey()] = nil
    end
    runtimeMax = savedMax
    testing = false
    if ghostAnim:IsPlaying() then ghostAnim:Stop() end
    ghostBar:Hide()
    ApplyLayout()
    if runtimeMax ~= nil then
        ghostBar:SetMinMaxValues(0, runtimeMax)
        bar:SetMinMaxValues(0, runtimeMax)
    else
        ghostBar:SetMinMaxValues(0, 1)
        ghostBar:SetValue(0)
        ghostBar:Hide()
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        lastAbsorb = nil
        suppressAnimationUntil = 0
        valueText:SetText("")
    end
    UpdateAbsorb()
end

local function ToggleTestPreview(silent)
    testing = not testing
    if testing then
        if ghostAnim:IsPlaying() then ghostAnim:Stop() end
        ghostBar:Hide()
        ghostBar:SetMinMaxValues(0, 100)
        bar:SetMinMaxValues(0, 100)
        bar:SetValue(72)
        valueText:SetText("72")
        if db.showText ~= false then valueText:Show() end
        if not silent then Print("test preview on. Toggle it again to return to live data.") end
    else
        runtimeMax = GetSavedMaximum()
        if runtimeMax ~= nil then
            ghostBar:SetMinMaxValues(0, runtimeMax)
            bar:SetMinMaxValues(0, runtimeMax)
        end
        ApplyLayout()
        UpdateAbsorb()
        if not silent then Print("test preview off.") end
    end
end

-- Forward declarations for UI refresh/open functions.
local RefreshAllUI
local OpenControlWindow
local ToggleControlWindow
local OpenBlizzardOptions

-- -----------------------------------------------------------------------------
-- Minimap button
-- -----------------------------------------------------------------------------

local function Atan2(y, x)
    if math.atan2 then return math.atan2(y, x) end
    if _G.atan2 then return _G.atan2(y, x) end
    if x > 0 then return math.atan(y / x) end
    if x < 0 and y >= 0 then return math.atan(y / x) + math.pi end
    if x < 0 and y < 0 then return math.atan(y / x) - math.pi end
    if x == 0 and y > 0 then return math.pi / 2 end
    if x == 0 and y < 0 then return -math.pi / 2 end
    return 0
end

local function PositionMinimapButton()
    if not minimapButton or not db or not Minimap then return end
    local angle = math.rad(db.minimapAngle or defaults.minimapAngle)
    local radius = db.minimapRadius or defaults.minimapRadius
    minimapButton:ClearAllPoints()
    minimapButton:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * radius, math.sin(angle) * radius)
end

local function SetMinimapVisible(show, silent)
    if not db then return end
    db.showMinimap = show and true or false
    if minimapButton then
        if db.showMinimap then
            minimapButton:Show()
            PositionMinimapButton()
        else
            minimapButton:Hide()
        end
    end
    if not silent then
        Print(db.showMinimap and "minimap button shown." or "minimap button hidden. Use /saf minimap on to restore it.")
    end
    if RefreshAllUI then RefreshAllUI() end
end

local function SetMinimapRadius(value, silent)
    if not db then return false end
    local n = tonumber(value)
    if not n then return false end
    n = math.max(55, math.min(200, n))
    n = math.floor(n + 0.5)
    db.minimapRadius = n
    PositionMinimapButton()
    if not silent then Print(string.format("minimap button distance set to %d px.", n)) end
    if RefreshAllUI then RefreshAllUI() end
    return true
end

local function CreateMinimapButton()
    if minimapButton or not Minimap then return end

    local button = CreateFrame("Button", "ShieldAuraForeverMinimapButton", Minimap)
    minimapButton = button
    button:SetSize(32, 32)
    button:SetFrameStrata("MEDIUM")
    button:SetFrameLevel((Minimap:GetFrameLevel() or 1) + 8)
    button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    button:RegisterForDrag("LeftButton")
    button:SetMovable(true)

    local icon = button:CreateTexture(nil, "BACKGROUND")
    icon:SetSize(20, 20)
    icon:SetPoint("CENTER")
    icon:SetTexture(ICON_TEXTURE)

    local border = button:CreateTexture(nil, "OVERLAY")
    border:SetSize(54, 54)
    border:SetPoint("TOPLEFT", 0, 0)
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

    local highlight = button:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetSize(32, 32)
    highlight:SetPoint("CENTER")
    highlight:SetTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")
    highlight:SetBlendMode("ADD")

    button:SetScript("OnClick", function(_, mouseButton)
        if mouseButton == "RightButton" then
            OpenBlizzardOptions()
        else
            ToggleControlWindow()
        end
    end)

    button:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText("Shield Aura Forever")
        GameTooltip:AddLine("Left-click: open movable settings", 1, 1, 1)
        GameTooltip:AddLine("Right-click: open Blizzard AddOns page", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Drag: move this button around the minimap", 0.85, 0.85, 0.85)
        GameTooltip:AddLine("Settings: adjust distance from minimap center", 0.85, 0.85, 0.85)
        GameTooltip:Show()
    end)
    button:SetScript("OnLeave", function() GameTooltip:Hide() end)

    button:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cursorX, cursorY = GetCursorPosition()
            local uiScale = UIParent:GetEffectiveScale()
            if not mx or not my or not uiScale or uiScale == 0 then return end
            cursorX, cursorY = cursorX / uiScale, cursorY / uiScale
            local angle = math.deg(Atan2(cursorY - my, cursorX - mx))
            db.minimapAngle = angle
            PositionMinimapButton()
        end)
    end)

    button:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)

    PositionMinimapButton()
    if db.showMinimap == false then button:Hide() end
end

-- -----------------------------------------------------------------------------
-- Movable control window
-- -----------------------------------------------------------------------------

local function SaveWindowPosition()
    if not controlWindow or not db then return end
    local wx, wy = controlWindow:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if wx and wy and ux and uy then
        db.windowX = wx - ux
        db.windowY = wy - uy
    end
end

local function RefreshControlWindow()
    if not db or not controlWindow then return end
    local c = windowControls

    if c.lockButton then c.lockButton:SetText(db.locked and "Unlock HUD" or "Lock HUD") end
    if c.lockState then
        c.lockState:SetText(db.locked and "Locked" or "Unlocked — drag the shaded HUD")
    end
    if c.scaleSlider and not c.scaleSlider._safUpdating then
        c.scaleSlider._safUpdating = true
        c.scaleSlider:SetValue(db.scale or 1)
        c.scaleSlider._safUpdating = false
    end
    if c.scaleValue then c.scaleValue:SetText(string.format("%.2fx", db.scale or 1)) end
    if c.textCheck then c.textCheck:SetChecked(db.showText ~= false) end
    if c.textPositionCheck then c.textPositionCheck:SetChecked(db.textPosition == "top") end
    if c.directionCheck then c.directionCheck:SetChecked(db.reverseFill ~= true) end
    if c.mirrorCheck then
        c.mirrorCheck:SetChecked(db.mirrorCurve == true)
        if db.layout == "horizontal" then c.mirrorCheck:Disable() else c.mirrorCheck:Enable() end
    end
    if c.colorDropDown and c.colorDropDown._safColorMode ~= db.colorMode then
        c.colorDropDown._safColorMode = db.colorMode
        -- External slash/reset changes require refreshing the selection text.
        -- Selection clicks are refreshed automatically by Blizzard's menu.
        if not c.colorDropDown:IsMenuOpen() then c.colorDropDown:GenerateMenu() end
    end
    if c.colorFallbackButton then
        for _, option in ipairs(colorOptions) do
            if option.value == db.colorMode then
                c.colorFallbackButton:SetText(option.label)
                break
            end
        end
    end
    if c.layoutCheck then c.layoutCheck:SetChecked(db.layout == "horizontal") end
    if c.solidCheck then c.solidCheck:SetChecked(db.barStyle == "solid") end
    if c.directionCheck and c.directionCheck.Text then
        c.directionCheck.Text:SetText(db.layout == "horizontal"
            and "Drain from right first (off = left first)"
            or "Drain from top first (off = bottom first)")
    end
    if c.animationCheck then
        if db.layout == "horizontal" then c.animationCheck:Disable() else c.animationCheck:Enable() end
        c.animationCheck:SetChecked(db.animateLoss ~= false)
    end
    if c.minimapCheck then c.minimapCheck:SetChecked(db.showMinimap ~= false) end
    if c.minimapRadiusSlider and not c.minimapRadiusSlider._safUpdating then
        c.minimapRadiusSlider._safUpdating = true
        c.minimapRadiusSlider:SetValue(db.minimapRadius or defaults.minimapRadius)
        c.minimapRadiusSlider._safUpdating = false
    end
    if c.minimapRadiusValue then c.minimapRadiusValue:SetText(string.format("%d px", db.minimapRadius or defaults.minimapRadius)) end
    if c.animationCheck then c.animationCheck:SetChecked(db.animateLoss ~= false) end
    if c.testButton then c.testButton:SetText(testing and "Stop Test Preview" or "Start Test Preview") end
end

local function CreateControlWindow()
    if controlWindow or not db then return end

    local frame = CreateFrame("Frame", "ShieldAuraForeverControlWindow", UIParent, "BackdropTemplate")
    controlWindow = frame
    frame:SetSize(500, 700)
    frame:SetPoint("CENTER", UIParent, "CENTER", db.windowX or defaults.windowX, db.windowY or defaults.windowY)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    frame:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    frame:SetBackdropColor(0.05, 0.05, 0.05, 0.96)

    table.insert(UISpecialFrames, "ShieldAuraForeverControlWindow")

    local titleBar = CreateFrame("Frame", nil, frame)
    titleBar:SetPoint("TOPLEFT", 12, -8)
    titleBar:SetPoint("TOPRIGHT", -34, -8)
    titleBar:SetHeight(28)
    titleBar:EnableMouse(true)
    titleBar:RegisterForDrag("LeftButton")
    titleBar:SetScript("OnDragStart", function() frame:StartMoving() end)
    titleBar:SetScript("OnDragStop", function()
        frame:StopMovingOrSizing()
        SaveWindowPosition()
    end)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 22, -18)
    title:SetText("Shield Aura Forever")

    local version = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    version:SetPoint("LEFT", title, "RIGHT", 10, -1)
    version:SetText("v" .. ADDON_VERSION)

    local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -5, -5)

    local subtitle = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", frame, "RIGHT", -24, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetText("Move this window anywhere while adjusting the HUD. Changes apply immediately.")

    local hudHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hudHeader:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -22)
    hudHeader:SetText("HUD")

    local lockButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    lockButton:SetSize(130, 24)
    lockButton:SetPoint("TOPLEFT", hudHeader, "BOTTOMLEFT", 0, -10)
    lockButton:SetScript("OnClick", function()
        SetLocked(not db.locked, true)
        RefreshAllUI()
    end)
    windowControls.lockButton = lockButton

    local lockState = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    lockState:SetPoint("LEFT", lockButton, "RIGHT", 12, 0)
    lockState:SetTextColor(0.75, 0.75, 0.75)
    windowControls.lockState = lockState

    local scaleLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    scaleLabel:SetPoint("TOPLEFT", lockButton, "BOTTOMLEFT", 0, -20)
    scaleLabel:SetText("Scale")

    local scaleSlider = CreateFrame("Slider", "ShieldAuraForeverWindowScaleSlider", frame, "OptionsSliderTemplate")
    scaleSlider:SetPoint("TOPLEFT", scaleLabel, "BOTTOMLEFT", 6, -7)
    scaleSlider:SetWidth(280)
    scaleSlider:SetMinMaxValues(0.5, 2.5)
    scaleSlider:SetValueStep(0.05)
    if scaleSlider.SetObeyStepOnDrag then scaleSlider:SetObeyStepOnDrag(true) end
    if _G[scaleSlider:GetName() .. "Low"] then _G[scaleSlider:GetName() .. "Low"]:SetText("0.5") end
    if _G[scaleSlider:GetName() .. "High"] then _G[scaleSlider:GetName() .. "High"]:SetText("2.5") end
    if _G[scaleSlider:GetName() .. "Text"] then _G[scaleSlider:GetName() .. "Text"]:SetText("") end
    scaleSlider:SetScript("OnValueChanged", function(self, value)
        if self._safUpdating or not db then return end
        SetScale(value, true)
        RefreshAllUI()
    end)
    windowControls.scaleSlider = scaleSlider

    local scaleValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    scaleValue:SetPoint("LEFT", scaleSlider, "RIGHT", 15, 0)
    windowControls.scaleValue = scaleValue

    local textCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    textCheck:SetPoint("TOPLEFT", scaleSlider, "BOTTOMLEFT", -6, -14)
    textCheck.Text:SetText("Show remaining absorb number")
    textCheck:SetScript("OnClick", function(self)
        db.showText = self:GetChecked() and true or false
        ApplyLayout()
        UpdateAbsorb()
        RefreshAllUI()
    end)
    windowControls.textCheck = textCheck

    local textPositionCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    textPositionCheck:SetPoint("TOPLEFT", textCheck, "BOTTOMLEFT", 0, -2)
    textPositionCheck.Text:SetText("Place absorb number at top (off = bottom)")
    textPositionCheck:SetScript("OnClick", function(self)
        db.textPosition = self:GetChecked() and "top" or "bottom"
        ApplyLayout()
        UpdateAbsorb()
        RefreshAllUI()
    end)
    windowControls.textPositionCheck = textPositionCheck

    local directionCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    directionCheck:SetPoint("TOPLEFT", textPositionCheck, "BOTTOMLEFT", 0, -2)
    directionCheck.Text:SetText("Drain from top first (off = bottom first)")
    directionCheck:SetScript("OnClick", function(self)
        db.reverseFill = not (self:GetChecked() and true or false)
        ApplyLayout()
        RefreshAllUI()
    end)
    windowControls.directionCheck = directionCheck

    local animationCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    animationCheck:SetPoint("TOPLEFT", directionCheck, "BOTTOMLEFT", 0, -2)
    animationCheck.Text:SetText("Animate consumed segments (follows drain direction)")
    animationCheck:SetScript("OnClick", function(self)
        db.animateLoss = self:GetChecked() and true or false
        if db.animateLoss == false and ghostAnim:IsPlaying() then ghostAnim:Stop() end
        RefreshAllUI()
    end)
    windowControls.animationCheck = animationCheck

    local mirrorCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    mirrorCheck:SetPoint("TOPLEFT", animationCheck, "BOTTOMLEFT", 0, -2)
    mirrorCheck.Text:SetText("Mirror curve to left")
    mirrorCheck:SetScript("OnClick", function(self)
        db.mirrorCurve = self:GetChecked() and true or false
        ApplyLayout()
        RefreshAllUI()
    end)
    windowControls.mirrorCheck = mirrorCheck

    local appearanceHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    appearanceHeader:SetPoint("TOPLEFT", mirrorCheck, "BOTTOMLEFT", 6, -8)
    appearanceHeader:SetText("Bar appearance")

    local layoutCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    layoutCheck:SetPoint("TOPLEFT", appearanceHeader, "BOTTOMLEFT", -6, -3)
    layoutCheck.Text:SetText("Horizontal bar (movable)")
    layoutCheck:SetScript("OnClick", function(self)
        db.layout = self:GetChecked() and "horizontal" or "curved"
        ApplyLayout()
        RefreshAllUI()
    end)
    windowControls.layoutCheck = layoutCheck

    local solidCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    solidCheck:SetPoint("TOPLEFT", layoutCheck, "BOTTOMLEFT", 0, -2)
    solidCheck.Text:SetText("Solid bar (off = segmented)")
    solidCheck:SetScript("OnClick", function(self)
        db.barStyle = self:GetChecked() and "solid" or "segmented"
        ApplyLayout()
        RefreshAllUI()
    end)
    windowControls.solidCheck = solidCheck

    local colorLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    colorLabel:SetPoint("TOPLEFT", appearanceHeader, "TOPLEFT", 234, 0)
    colorLabel:SetText("Shield color")

    -- Forever ships the modern Blizzard DropdownButton menu templates.
    -- Selecting a class is only a color preset, NOT shield-type detection.
    local pendingDropDown
    local dropdownOK, colorDropDown = pcall(function()
        local dropdown = CreateFrame("DropdownButton", nil, frame, "WowStyle1DropdownTemplate")
        pendingDropDown = dropdown
        dropdown:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -6)
        dropdown:SetSize(203, 28)
        dropdown:SetDefaultText("Automatic - My Class")
        dropdown:SetupMenu(function(_, rootDescription)
            for _, option in ipairs(colorOptions) do
                rootDescription:CreateRadio(option.label,
                    function(value) return db.colorMode == value end,
                    function(value)
                        db.colorMode = value
                        ApplyLayout()
                        RefreshAllUI()
                    end,
                    option.value)
            end
        end)
        return dropdown
    end)
    if dropdownOK and colorDropDown then
        windowControls.colorDropDown = colorDropDown
    else
        if pendingDropDown then pendingDropDown:Hide() end
        -- Don't break the HUD if a future Forever build changes menu templates.
        -- An ordinary button cycles the same presets until dropdown support is restored.
        local fallback = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
        fallback:SetPoint("TOPLEFT", colorLabel, "BOTTOMLEFT", 0, -6)
        fallback:SetSize(203, 26)
        fallback:SetScript("OnClick", function()
            local nextChoice = 1
            for i, option in ipairs(colorOptions) do
                if option.value == db.colorMode then
                    nextChoice = i % #colorOptions + 1
                    break
                end
            end
            db.colorMode = colorOptions[nextChoice].value
            ApplyLayout()
            RefreshAllUI()
        end)
        windowControls.colorFallbackButton = fallback
    end

    local minimapCheck = CreateFrame("CheckButton", nil, frame, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", solidCheck, "BOTTOMLEFT", 0, -2)
    minimapCheck.Text:SetText("Show minimap button")
    minimapCheck:SetScript("OnClick", function(self)
        SetMinimapVisible(self:GetChecked() and true or false, true)
    end)
    windowControls.minimapCheck = minimapCheck

    local minimapRadiusLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    minimapRadiusLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 6, -10)
    minimapRadiusLabel:SetText("Minimap button distance")

    local minimapRadiusSlider = CreateFrame("Slider", "ShieldAuraForeverWindowMinimapRadiusSlider", frame, "OptionsSliderTemplate")
    minimapRadiusSlider:SetPoint("TOPLEFT", minimapRadiusLabel, "BOTTOMLEFT", 6, -7)
    minimapRadiusSlider:SetWidth(280)
    minimapRadiusSlider:SetMinMaxValues(55, 200)
    minimapRadiusSlider:SetValueStep(1)
    if minimapRadiusSlider.SetObeyStepOnDrag then minimapRadiusSlider:SetObeyStepOnDrag(true) end
    if _G[minimapRadiusSlider:GetName() .. "Low"] then _G[minimapRadiusSlider:GetName() .. "Low"]:SetText("Closer") end
    if _G[minimapRadiusSlider:GetName() .. "High"] then _G[minimapRadiusSlider:GetName() .. "High"]:SetText("Farther") end
    if _G[minimapRadiusSlider:GetName() .. "Text"] then _G[minimapRadiusSlider:GetName() .. "Text"]:SetText("") end
    minimapRadiusSlider:SetScript("OnValueChanged", function(self, value)
        if self._safUpdating or not db then return end
        SetMinimapRadius(value, true)
        RefreshAllUI()
    end)
    windowControls.minimapRadiusSlider = minimapRadiusSlider

    local minimapRadiusValue = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    minimapRadiusValue:SetPoint("LEFT", minimapRadiusSlider, "RIGHT", 15, 0)
    windowControls.minimapRadiusValue = minimapRadiusValue

    local actionHeader = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    actionHeader:SetPoint("TOPLEFT", minimapRadiusSlider, "BOTTOMLEFT", -6, -18)
    actionHeader:SetText("Actions")

    local testButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    testButton:SetSize(145, 24)
    testButton:SetPoint("TOPLEFT", actionHeader, "BOTTOMLEFT", 0, -9)
    testButton:SetScript("OnClick", function()
        ToggleTestPreview(true)
        RefreshAllUI()
    end)
    windowControls.testButton = testButton

    local calibrateButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    calibrateButton:SetSize(145, 24)
    calibrateButton:SetPoint("LEFT", testButton, "RIGHT", 8, 0)
    calibrateButton:SetText("Calibrate Shield")
    calibrateButton:SetScript("OnClick", function()
        testing = false
        Calibrate(false)
        UpdateAbsorb()
        RefreshAllUI()
    end)

    local resetButton = CreateFrame("Button", nil, frame, "UIPanelButtonTemplate")
    resetButton:SetSize(145, 24)
    resetButton:SetPoint("LEFT", calibrateButton, "RIGHT", 8, 0)
    resetButton:SetText("Reset HUD Layout")
    resetButton:SetScript("OnClick", function()
        ResetHUDLayout(true)
        RefreshAllUI()
        Print("HUD layout reset; shield calibration and minimap settings preserved.")
    end)

    local commandsHint = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    commandsHint:SetPoint("TOPLEFT", testButton, "BOTTOMLEFT", 0, -14)
    commandsHint:SetText("|cffffd35a/saf help|r lists every command. Horizontal mode temporarily disables loss animation.")

    local note = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    note:SetPoint("BOTTOMLEFT", frame, "BOTTOMLEFT", 22, 20)
    note:SetPoint("RIGHT", frame, "RIGHT", -22, 0)
    note:SetJustifyH("LEFT")
    note:SetWordWrap(true)
    note:SetText("Minimap: left-click opens this window, right-click opens the Blizzard AddOns page, drag to reposition around the rim, and use the distance slider to move it inward/outward. The AddOn Compartment entry opens this window too.")

    frame:SetScript("OnShow", RefreshControlWindow)
    RefreshControlWindow()
end

OpenControlWindow = function()
    if not controlWindow then CreateControlWindow() end
    if not controlWindow then return end

    -- If launched from Blizzard Settings, close that large panel first so the
    -- movable controls and the HUD are both visible at the same time.
    if _G.SettingsPanel and _G.SettingsPanel:IsShown() then
        if HideUIPanel then HideUIPanel(_G.SettingsPanel) else _G.SettingsPanel:Hide() end
    end

    controlWindow:ClearAllPoints()
    controlWindow:SetPoint("CENTER", UIParent, "CENTER", db.windowX or defaults.windowX, db.windowY or defaults.windowY)
    controlWindow:Show()
    RefreshControlWindow()
end

ToggleControlWindow = function()
    if controlWindow and controlWindow:IsShown() then
        controlWindow:Hide()
    else
        OpenControlWindow()
    end
end

-- -----------------------------------------------------------------------------
-- Blizzard Options > AddOns launcher panel
-- -----------------------------------------------------------------------------

local function RefreshOptionsPanel()
    if not db then return end
    local c = optionControls
    if c.minimapCheck then c.minimapCheck:SetChecked(db.showMinimap ~= false) end
    if c.minimapRadiusSlider and not c.minimapRadiusSlider._safUpdating then
        c.minimapRadiusSlider._safUpdating = true
        c.minimapRadiusSlider:SetValue(db.minimapRadius or defaults.minimapRadius)
        c.minimapRadiusSlider._safUpdating = false
    end
    if c.minimapRadiusValue then c.minimapRadiusValue:SetText(string.format("%d px", db.minimapRadius or defaults.minimapRadius)) end
end

local function CreateOptionsPanel()
    if optionsPanel or not Settings or not Settings.RegisterCanvasLayoutCategory then return end

    local panel = CreateFrame("Frame", "ShieldAuraForeverOptionsPanel")
    optionsPanel = panel

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("Shield Aura Forever")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetPoint("RIGHT", panel, "RIGHT", -24, 0)
    subtitle:SetJustifyH("LEFT")
    subtitle:SetWordWrap(true)
    subtitle:SetText("Visual controls live in a movable window so you can see the shield HUD while adjusting it.")

    local openButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openButton:SetSize(200, 28)
    openButton:SetPoint("TOPLEFT", subtitle, "BOTTOMLEFT", 0, -24)
    openButton:SetText("Open Movable Settings")
    openButton:SetScript("OnClick", OpenControlWindow)

    local minimapCheck = CreateFrame("CheckButton", nil, panel, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", openButton, "BOTTOMLEFT", -6, -18)
    minimapCheck.Text:SetText("Show minimap button")
    minimapCheck:SetScript("OnClick", function(self)
        SetMinimapVisible(self:GetChecked() and true or false, true)
    end)
    optionControls.minimapCheck = minimapCheck

    local minimapRadiusLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
    minimapRadiusLabel:SetPoint("TOPLEFT", minimapCheck, "BOTTOMLEFT", 6, -14)
    minimapRadiusLabel:SetText("Minimap button distance")

    local minimapRadiusSlider = CreateFrame("Slider", "ShieldAuraForeverOptionsMinimapRadiusSlider", panel, "OptionsSliderTemplate")
    minimapRadiusSlider:SetPoint("TOPLEFT", minimapRadiusLabel, "BOTTOMLEFT", 6, -7)
    minimapRadiusSlider:SetWidth(280)
    minimapRadiusSlider:SetMinMaxValues(55, 200)
    minimapRadiusSlider:SetValueStep(1)
    if minimapRadiusSlider.SetObeyStepOnDrag then minimapRadiusSlider:SetObeyStepOnDrag(true) end
    if _G[minimapRadiusSlider:GetName() .. "Low"] then _G[minimapRadiusSlider:GetName() .. "Low"]:SetText("Closer") end
    if _G[minimapRadiusSlider:GetName() .. "High"] then _G[minimapRadiusSlider:GetName() .. "High"]:SetText("Farther") end
    if _G[minimapRadiusSlider:GetName() .. "Text"] then _G[minimapRadiusSlider:GetName() .. "Text"]:SetText("") end
    minimapRadiusSlider:SetScript("OnValueChanged", function(self, value)
        if self._safUpdating or not db then return end
        SetMinimapRadius(value, true)
        RefreshAllUI()
    end)
    optionControls.minimapRadiusSlider = minimapRadiusSlider

    local minimapRadiusValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    minimapRadiusValue:SetPoint("LEFT", minimapRadiusSlider, "RIGHT", 15, 0)
    optionControls.minimapRadiusValue = minimapRadiusValue

    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", minimapRadiusSlider, "BOTTOMLEFT", -6, -20)
    info:SetPoint("RIGHT", panel, "RIGHT", -28, 0)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(true)
    info:SetText(
        "The minimap button opens the same movable settings window. Drag it around the rim to change angle; use the distance slider to move it toward or away from the minimap center.\n\n" ..
        "Shield Aura Forever also registers with Blizzard's AddOn Compartment. That entry remains available even if you hide the custom minimap button.\n\n" ..
        "|cffffd35a/saf options|r — movable settings     |cffffd35a/saf blizzard|r — this page\n" ..
        "|cffffd35a/saf help|r — print the full command reference to chat"
    )

    local version = panel:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
    version:SetPoint("BOTTOMLEFT", panel, "BOTTOMLEFT", 16, 16)
    version:SetText("Version " .. ADDON_VERSION)

    panel.OnCommit = function() end
    panel.OnRefresh = RefreshOptionsPanel
    panel.OnDefault = function()
        SetMinimapVisible(defaults.showMinimap, true)
        SetMinimapRadius(defaults.minimapRadius, true)
        RefreshAllUI()
    end
    panel:SetScript("OnShow", RefreshOptionsPanel)

    local category = Settings.RegisterCanvasLayoutCategory(panel, "Shield Aura Forever")
    Settings.RegisterAddOnCategory(category)
    optionsCategoryID = category:GetID()
end

OpenBlizzardOptions = function()
    if optionsCategoryID and Settings and Settings.OpenToCategory then
        Settings.OpenToCategory(optionsCategoryID)
    else
        Print("Blizzard AddOns page is not available yet. Try again after /reload.")
    end
end

RefreshAllUI = function()
    RefreshControlWindow()
    RefreshOptionsPanel()
    if minimapButton and db then
        if db.showMinimap == false then minimapButton:Hide() else minimapButton:Show() end
        PositionMinimapButton()
    end
end

-- -----------------------------------------------------------------------------
-- AddOn Compartment callbacks (referenced by the TOC; must be global)
-- -----------------------------------------------------------------------------

function ShieldAuraForever_OnCompartmentClick(addonName, buttonInfo)
    local buttonName = buttonInfo
    if type(buttonInfo) == "table" then buttonName = buttonInfo.buttonName or buttonInfo.button end
    if buttonName == "RightButton" then
        OpenBlizzardOptions()
    else
        ToggleControlWindow()
    end
end

function ShieldAuraForever_OnCompartmentEnter(addonName, frameOrInfo)
    local owner = frameOrInfo
    if type(owner) ~= "table" or not owner.GetObjectType then
        owner = _G.AddonCompartmentFrame or UIParent
    end
    GameTooltip:SetOwner(owner, "ANCHOR_LEFT")
    GameTooltip:SetText("Shield Aura Forever")
    GameTooltip:AddLine("Click: open movable settings", 1, 1, 1)
    GameTooltip:AddLine("Right-click: Blizzard AddOns page", 0.85, 0.85, 0.85)
    GameTooltip:Show()
end

function ShieldAuraForever_OnCompartmentLeave()
    GameTooltip:Hide()
end

-- -----------------------------------------------------------------------------
-- Events
-- -----------------------------------------------------------------------------

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:RegisterEvent("PLAYER_ENTERING_WORLD")
events:RegisterUnitEvent("UNIT_ABSORB_AMOUNT_CHANGED", "player")
events:RegisterUnitEvent("UNIT_SPELLCAST_SUCCEEDED", "player", "pet")

events:SetScript("OnEvent", function(_, event, ...)
    if event == "PLAYER_LOGIN" then
        CopyDefaults()
        runtimeMax = GetSavedMaximum()
        ApplyLayout()
        CreateControlWindow()
        CreateOptionsPanel()
        CreateMinimapButton()
        if runtimeMax ~= nil then
            ghostBar:SetMinMaxValues(0, runtimeMax)
            bar:SetMinMaxValues(0, runtimeMax)
        end
        RefreshAllUI()
        C_Timer.After(0.2, UpdateAbsorb)
        return
    end

    if event == "PLAYER_ENTERING_WORLD" then
        C_Timer.After(0.2, UpdateAbsorb)
        return
    end

    if event == "UNIT_ABSORB_AMOUNT_CHANGED" then
        local animateChange = GetTime() >= (suppressAnimationUntil or 0)
        UpdateAbsorb(animateChange)
        return
    end

    if event == "UNIT_SPELLCAST_SUCCEEDED" then
        local unit, castGUID, spellID = ...
        local freshShield = (unit == "player" and IsPowerWordShieldSpell(spellID))
            or (unit == "pet" and IsVoidwalkerSacrificeSpell(spellID))

        if freshShield then
            -- Avoid treating a fresh/renewed shield as shield loss. Capturing
            -- the total shortly after the cast also gives PW:S and Voidwalker
            -- Sacrifice an accurate 100% maximum even when applied in combat.
            suppressAnimationUntil = GetTime() + 0.35
            C_Timer.After(0.05, function() Calibrate(true); UpdateAbsorb() end)
            C_Timer.After(0.20, function() Calibrate(true); UpdateAbsorb() end)
        end
    end
end)

-- -----------------------------------------------------------------------------
-- Slash commands
-- -----------------------------------------------------------------------------

local function ShowHelp()
    Print("commands:")
    Print("/saf options  - toggle the movable settings window")
    Print("/saf blizzard - open Game Menu > Options > AddOns page")
    Print("/saf unlock   - drag the HUD")
    Print("/saf lock     - lock the HUD")
    Print("/saf scale N  - resize HUD (0.5 to 2.5)")
    Print("/saf text on|off")
    Print("/saf textpos top|bottom - place the absorb number above or below the aura")
    Print("/saf flip     - reverse which end of the shield aura drains")
    Print("/saf mirror [on|off] - mirror the curved HUD")
    Print("/saf layout curved|horizontal - select HUD layout")
    Print("/saf style segmented|solid - select bar style")
    Print("/saf color auto|gold|warrior|paladin|hunter|rogue|priest|shaman|mage|warlock|druid")
    Print("/saf minimap on|off")
    Print("/saf radius N  - minimap button distance (55 to 200 pixels)")
    Print("/saf animation on|off - toggle shield-loss animation (follows drain direction)")
    Print("/saf calibrate - use current total absorb as 100%")
    Print("/saf test     - preview the shield aura")
    Print("/saf reset    - reset all addon settings and calibration")
end

SLASH_SHIELDAURAFOREVER1 = "/saf"
SLASH_SHIELDAURAFOREVER2 = "/shieldaura"
SLASH_SHIELDAURAFOREVER3 = "/shieldauraforever"
SlashCmdList.SHIELDAURAFOREVER = function(msg)
    if not db then CopyDefaults() end
    local cmd, arg = (msg or ""):match("^(%S*)%s*(.-)$")
    cmd = (cmd or ""):lower()
    arg = (arg or ""):lower()

    if cmd == "" or cmd == "options" or cmd == "config" or cmd == "window" then
        ToggleControlWindow()
    elseif cmd == "blizzard" or cmd == "settings" then
        OpenBlizzardOptions()
    elseif cmd == "help" then
        ShowHelp()
    elseif cmd == "unlock" then
        SetLocked(false, false)
        RefreshAllUI()
    elseif cmd == "lock" then
        SetLocked(true, false)
        RefreshAllUI()
    elseif cmd == "scale" then
        local n = tonumber(arg)
        if n and n >= 0.5 and n <= 2.5 then
            SetScale(n, false)
            RefreshAllUI()
        else
            Print("scale must be between 0.5 and 2.5.")
        end
    elseif cmd == "text" then
        if arg == "on" then
            db.showText = true
        elseif arg == "off" then
            db.showText = false
        else
            Print("use /saf text on or /saf text off")
            return
        end
        ApplyLayout()
        UpdateAbsorb()
        RefreshAllUI()
    elseif cmd == "textpos" or cmd == "textposition" or cmd == "numberpos" then
        if arg == "top" or arg == "above" then
            db.textPosition = "top"
        elseif arg == "bottom" or arg == "below" then
            db.textPosition = "bottom"
        else
            Print("use /saf textpos top or /saf textpos bottom")
            return
        end
        ApplyLayout()
        UpdateAbsorb()
        RefreshAllUI()
        Print("absorb number position set to " .. db.textPosition .. ".")
    elseif cmd == "flip" then
        db.reverseFill = not db.reverseFill
        ApplyLayout()
        RefreshAllUI()
        Print("aura fill direction flipped.")
    elseif cmd == "mirror" or cmd == "curve" then
        if arg == "on" or arg == "left" then
            db.mirrorCurve = true
        elseif arg == "off" or arg == "right" then
            db.mirrorCurve = false
        elseif arg == "" then
            db.mirrorCurve = not db.mirrorCurve
        else
            Print("use /saf mirror, /saf mirror on, or /saf mirror off")
            return
        end
        ApplyLayout()
        RefreshAllUI()
        Print(db.mirrorCurve and "aura curve mirrored to the left." or "aura curve bows to the right.")
    elseif cmd == "layout" then
        if arg ~= "curved" and arg ~= "horizontal" then
            Print("use /saf layout curved or /saf layout horizontal")
            return
        end
        db.layout = arg
        ApplyLayout()
        RefreshAllUI()
        Print("HUD layout set to " .. arg .. ". Each layout remembers its own dragged position.")
    elseif cmd == "style" then
        if arg ~= "segmented" and arg ~= "solid" then
            Print("use /saf style segmented or /saf style solid")
            return
        end
        db.barStyle = arg
        ApplyLayout()
        RefreshAllUI()
        Print("HUD bar style set to " .. arg .. ".")
    elseif cmd == "color" then
        local selected = arg:upper()
        if arg == "auto" or arg == "gold" then selected = arg end
        local valid = false
        for _, option in ipairs(colorOptions) do
            if option.value == selected then valid = true; break end
        end
        if not valid then
            Print("invalid color. Use /saf help for color preset names.")
            return
        end
        db.colorMode = selected
        ApplyLayout()
        RefreshAllUI()
        Print("HUD color set to " .. arg .. ".")
    elseif cmd == "minimap" then
        if arg == "on" then
            SetMinimapVisible(true, false)
        elseif arg == "off" then
            SetMinimapVisible(false, false)
        else
            Print("use /saf minimap on or /saf minimap off")
        end
    elseif cmd == "radius" or cmd == "minimapradius" then
        local n = tonumber(arg)
        if n and n >= 55 and n <= 200 then
            SetMinimapRadius(n, false)
            RefreshAllUI()
        else
            Print("minimap radius must be between 55 and 200 pixels.")
        end
    elseif cmd == "animation" or cmd == "animate" then
        if arg == "on" then
            db.animateLoss = true
            Print("shield-loss animation enabled; drift follows the selected drain direction.")
        elseif arg == "off" then
            db.animateLoss = false
            if ghostAnim:IsPlaying() then ghostAnim:Stop() end
            Print("shield-loss animation disabled.")
        else
            Print("use /saf animation on or /saf animation off")
            return
        end
        RefreshAllUI()
    elseif cmd == "calibrate" then
        testing = false
        Calibrate(false)
        UpdateAbsorb()
        RefreshAllUI()
    elseif cmd == "test" then
        ToggleTestPreview(false)
        RefreshAllUI()
    elseif cmd == "reset" then
        ShieldAuraForeverDB = {}
        CopyDefaults()
        runtimeMax = nil
        testing = false
        ApplyLayout()
        if ghostAnim:IsPlaying() then ghostAnim:Stop() end
        ghostBar:SetMinMaxValues(0, 1)
        ghostBar:SetValue(0)
        ghostBar:Hide()
        bar:SetMinMaxValues(0, 1)
        bar:SetValue(0)
        lastAbsorb = nil
        valueText:SetText("")
        PositionMinimapButton()
        SetMinimapVisible(db.showMinimap, true)
        if controlWindow then
            controlWindow:ClearAllPoints()
            controlWindow:SetPoint("CENTER", UIParent, "CENTER", db.windowX, db.windowY)
        end
        RefreshAllUI()
        Print("all settings reset. Apply a fresh absorb shield to calibrate automatically, or use /saf calibrate.")
    else
        ShowHelp()
    end
end
