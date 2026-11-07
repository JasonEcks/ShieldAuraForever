-- Shield Aura Forever v1.2.0
-- Clean-room WoW Forever addon. No WeakAuras or nanShield code/assets are reused.
-- Designed around Forever's secret-value restrictions: raw absorb values are only
-- passed into Blizzard-native display APIs, never used in combat arithmetic.

local ADDON_NAME = ...
local ADDON_VERSION = "1.2.0"
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
    { value = "custom", label = "Custom - RGB / HEX" },
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
    horizontalBarWidth = 160, -- exact width/height for the horizontal bar only
    horizontalBarHeight = 16,
    barOpacity = 1, -- overall HUD opacity when the absorb number is linked
    numberOpacity = 1, -- separate number alpha when explicitly unlinked
    linkNumberOpacity = true, -- default: one coherent opacity setting for bar and number
    combatOnly = false,
    numberDetached = false,
    numberFontSize = 13,
    -- numberX/numberY are assigned when independently positioning for the first time
    customR = 63, customG = 199, customB = 235, -- editable 0-255 RGB values
    windowX = -420,
    windowY = 80,
    schemaVersion = 12,
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

    -- v1.2 adds independent number positioning, exact dimensions, opacity,
    -- combat-only visibility, and user-defined RGB. Do not replace old choices.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 11 then
        ShieldAuraForeverDB.schemaVersion = 11
    end

    -- Phase 1 refinement: link bar and number opacity by default. If someone
    -- already used the Phase 1 build to set different alpha values, keep that
    -- separate appearance rather than silently overriding their choice.
    if (ShieldAuraForeverDB.schemaVersion or 1) < 12 then
        local barAlpha = tonumber(ShieldAuraForeverDB.barOpacity) or 1
        local numberAlpha = tonumber(ShieldAuraForeverDB.numberOpacity) or 1
        if ShieldAuraForeverDB.linkNumberOpacity == nil then
            ShieldAuraForeverDB.linkNumberOpacity = math.abs(barAlpha - numberAlpha) < 0.0001
        end
        ShieldAuraForeverDB.schemaVersion = 12
    end

    ShieldAuraForeverDB.maxAbsorbs = ShieldAuraForeverDB.maxAbsorbs or {}

    for k, v in pairs(defaults) do
        if ShieldAuraForeverDB[k] == nil then
            ShieldAuraForeverDB[k] = v
        end
    end
    db = ShieldAuraForeverDB
    -- Clamp only the new visual settings. Bad or manually edited SavedVariables
    -- should not create off-screen/zero-size frames or invalid alpha values.
    local function ClampSaved(key, minimum, maximum, fallback)
        local n = tonumber(db[key])
        if not n or n ~= n then n = fallback end
        db[key] = math.max(minimum, math.min(maximum, n))
    end
    ClampSaved("horizontalBarWidth", 60, 500, 160)
    ClampSaved("horizontalBarHeight", 6, 64, 16)
    ClampSaved("numberFontSize", 8, 40, 13)
    ClampSaved("barOpacity", 0, 1, 1)
    ClampSaved("numberOpacity", 0, 1, 1)
    if type(db.linkNumberOpacity) ~= "boolean" then db.linkNumberOpacity = true end
    for _, key in ipairs({"customR", "customG", "customB"}) do
        ClampSaved(key, 0, 255, defaults[key])
        db[key] = math.floor(db[key] + 0.5)
    end
    if db.colorMode == "custom" and not db.customR then db.colorMode = "gold" end
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
    if mode == "custom" then
        return (db.customR or 63) / 255, (db.customG or 199) / 255,
            (db.customB or 235) / 255, false
    end
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

-- The number has its own frame so it can be detached and dragged without
-- moving the bar. In attached mode it follows the same bar anchors as v1.1.
local numberFrame = CreateFrame("Frame", "ShieldAuraForeverNumberFrame", UIParent)
numberFrame:SetSize(140, 28)
numberFrame:SetMovable(true)
numberFrame:SetClampedToScreen(true)
numberFrame:RegisterForDrag("LeftButton")
numberFrame:SetFrameStrata("MEDIUM")
local valueText = numberFrame:CreateFontString(nil, "OVERLAY")
valueText:SetFont(STANDARD_TEXT_FONT, BASE_FONT_SIZE, "OUTLINE")
valueText:SetPoint("CENTER", numberFrame, "CENTER")
valueText:SetTextColor(1.0, 0.90, 0.20, 1)
valueText:SetShadowOffset(1, -1)
valueText:SetText("")

local numberUnlockBG = numberFrame:CreateTexture(nil, "BACKGROUND")
numberUnlockBG:SetAllPoints()
numberUnlockBG:SetColorTexture(0.2, 0.35, 0.5, 0.38)
numberUnlockBG:Hide()
local numberUnlockLabel = numberFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
numberUnlockLabel:SetPoint("BOTTOM", numberFrame, "TOP", 0, 2)
numberUnlockLabel:SetText("Drag absorb number")
numberUnlockLabel:Hide()

local function SaveNumberPosition()
    if not db or not db.numberDetached then return end
    local x, y = numberFrame:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if x and y and ux and uy then
        db.numberX, db.numberY = x - ux, y - uy
    end
end

numberFrame:SetScript("OnDragStart", function(self)
    if db and db.numberDetached and not db.locked then self:StartMoving() end
end)
numberFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    SaveNumberPosition()
    -- Do not move the shield bar: only this frame is repositioned.
end)

local unlockBG = hud:CreateTexture(nil, "BACKGROUND")
unlockBG:SetAllPoints()
unlockBG:SetColorTexture(0.1, 0.1, 0.1, 0.45)
unlockBG:Hide()

local unlockLabel = hud:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
unlockLabel:SetPoint("BOTTOM", hud, "TOP", 0, 3)
unlockLabel:SetText("Shield Aura Forever — drag to move")
unlockLabel:Hide()

-- Visibility uses only the player's combat state. Never branches on shield data.
local function ApplyVisibility()
    if not db then return end
    local visible = not db.combatOnly or (InCombatLockdown and InCombatLockdown())
        or testing or not db.locked
    if visible then hud:Show() else hud:Hide() end
    if db.showText ~= false and visible then numberFrame:Show() else numberFrame:Hide() end
end

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
    -- Linked by default: one HUD opacity governs bar and number. Users can
    -- explicitly unlink the number to preserve 100% text readability.
    local textAlpha = db.linkNumberOpacity and db.barOpacity or db.numberOpacity
    valueText:SetAlpha(textAlpha or 1)
    bar:SetAlpha(db.barOpacity or 1)
    ghostFade:SetFromAlpha(0.72 * (db.barOpacity or 1))

    -- Resize geometry, not Frame:SetScale(), preserving accurate drag offsets.
    hud:SetScale(1)
    local hudW = horizontal and ((db.horizontalBarWidth or HORIZONTAL_BAR_W) + 24) or BASE_HUD_W
    local hudH = horizontal and math.max(HORIZONTAL_HUD_H, (db.horizontalBarHeight or HORIZONTAL_BAR_H) + 38) or BASE_HUD_H
    local barW = horizontal and (db.horizontalBarWidth or HORIZONTAL_BAR_W) or BASE_BAR_W
    local barH = horizontal and (db.horizontalBarHeight or HORIZONTAL_BAR_H) or BASE_BAR_H
    local barTop = horizontal and -9 or -4
    hud:SetSize(hudW * scale, hudH * scale)
    for _, status in ipairs({ ghostBar, bar }) do
        status:SetSize(barW * scale, barH * scale)
        status:ClearAllPoints()
        status:SetPoint("TOP", hud, "TOP", 0, barTop * scale)
        status:SetOrientation(horizontal and "HORIZONTAL" or "VERTICAL")
        status:SetReverseFill(db.reverseFill == true)
    end

    numberFrame:ClearAllPoints()
    if db.numberDetached then
        numberFrame:SetPoint("CENTER", UIParent, "CENTER", db.numberX or 0, db.numberY or 0)
    elseif db.textPosition == "top" then
        numberFrame:SetPoint("BOTTOM", bar, "TOP", 0, 1 * scale)
    else
        numberFrame:SetPoint("TOP", bar, "BOTTOM", 0, 1 * scale)
    end
    local fontScale = db.numberDetached and 1 or scale
    local size = math.max(8, (db.numberFontSize or BASE_FONT_SIZE) * fontScale)
    numberFrame:SetSize(math.max(100, size * 7), size + 9)
    valueText:SetFont(STANDARD_TEXT_FONT, size, "OUTLINE")

    hud:ClearAllPoints()
    if horizontal then
        hud:SetPoint("CENTER", UIParent, "CENTER", db.horizontalX or defaults.horizontalX, db.horizontalY or defaults.horizontalY)
    else
        hud:SetPoint("CENTER", UIParent, "CENTER", db.x or defaults.x, db.y or defaults.y)
    end

    local allowDrag = not db.locked
    hud:EnableMouse(allowDrag)
    numberFrame:EnableMouse(allowDrag and db.numberDetached)
    if db.locked then
        unlockBG:Hide()
        unlockLabel:Hide()
        numberUnlockBG:Hide()
        numberUnlockLabel:Hide()
    else
        unlockBG:Show()
        unlockLabel:Show()
        if db.numberDetached and db.showText ~= false then
            numberUnlockBG:Show()
            numberUnlockLabel:Show()
        else
            numberUnlockBG:Hide()
            numberUnlockLabel:Hide()
        end
    end
    ApplyVisibility()
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
    ghostBar:SetAlpha(0.72 * (db.barOpacity or 1))
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
    db.numberDetached = defaults.numberDetached
    db.numberX = nil
    db.numberY = nil
    db.numberFontSize = defaults.numberFontSize
    db.horizontalBarWidth = defaults.horizontalBarWidth
    db.horizontalBarHeight = defaults.horizontalBarHeight
    db.barOpacity = defaults.barOpacity
    db.numberOpacity = defaults.numberOpacity
    db.linkNumberOpacity = defaults.linkNumberOpacity
    db.combatOnly = defaults.combatOnly
    db.customR, db.customG, db.customB = defaults.customR, defaults.customG, defaults.customB
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
        ApplyLayout() -- test preview overrides combat-only visibility
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

-- -----------------------------------------------------------------------------
-- v1.2 settings window: searchable sidebar and editable controls, all visual.
-- No game-combat data is read here.
-- -----------------------------------------------------------------------------

local SETTINGS_PAGES = {
    {id="bar", label="Shield Bar"},
    {id="number", label="Absorb Number"},
    {id="color", label="Colors"},
    {id="visibility", label="Visibility & Effects"},
    {id="minimap", label="Minimap"},
}
local activeSettingsPage = "bar"
local settingsRows = {}
local pageButtons = {}
local settingsContent
local settingsScroll
local settingsHeading
local settingsEmpty
local settingsSearch

local function SaveWindowPosition()
    if not controlWindow or not db then return end
    local wx, wy = controlWindow:GetCenter()
    local ux, uy = UIParent:GetCenter()
    if wx and wy and ux and uy then db.windowX, db.windowY = wx - ux, wy - uy end
end

local function SetNumberDetached(detached)
    if detached and not db.numberDetached and db.numberX == nil then
        local nx, ny = numberFrame:GetCenter()
        local ux, uy = UIParent:GetCenter()
        if nx and ny and ux and uy then
            db.numberX, db.numberY = nx - ux, ny - uy
        else
            db.numberX, db.numberY = 0, -50
        end
    end
    db.numberDetached = detached and true or false
    ApplyLayout()
end

local function ParseRGBHex(s)
    s = (s or ""):gsub("^%s*#?", ""):gsub("%s+$", "")
    if #s ~= 6 or not s:match("^%x%x%x%x%x%x$") then return nil end
    return tonumber(s:sub(1,2),16), tonumber(s:sub(3,4),16), tonumber(s:sub(5,6),16)
end

local function CommitRGB(r, g, b)
    if not r or not g or not b then return false end
    for _, c in ipairs({r,g,b}) do
        if c ~= c or c < 0 or c > 255 or c ~= math.floor(c) then return false end
    end
    db.customR, db.customG, db.customB = r, g, b
    db.colorMode = "custom"
    ApplyLayout()
    RefreshAllUI()
    return true
end

local function OpenCustomColorPicker()
    if not ColorPickerFrame or not ColorPickerFrame.SetupColorPickerAndShow then
        Print("Color picker unavailable; enter HEX or RGB instead.")
        return
    end
    local oldR, oldG, oldB = db.customR, db.customG, db.customB
    local oldMode = db.colorMode
    local function Changed()
        local r, g, b = ColorPickerFrame:GetColorRGB()
        CommitRGB(math.floor(r*255+0.5),math.floor(g*255+0.5),math.floor(b*255+0.5))
    end
    ColorPickerFrame:SetupColorPickerAndShow({
        r=oldR/255, g=oldG/255, b=oldB/255, hasOpacity=false,
        swatchFunc=Changed,
        cancelFunc=function()
            db.customR, db.customG, db.customB = oldR, oldG, oldB
            db.colorMode = oldMode
            ApplyLayout()
            RefreshAllUI()
        end,
    })
end

local RenderSettingsRows

local function RefreshControlWindow()
    if not db or not controlWindow then return end
    if windowControls.lockButton then
        windowControls.lockButton:SetText(db.locked and "Unlock HUD" or "Lock HUD")
    end
    if windowControls.testButton then
        windowControls.testButton:SetText(testing and "Stop Preview" or "Test Preview")
    end
    for _, row in ipairs(settingsRows) do
        if row.refresh then row.refresh() end
    end
    if RenderSettingsRows then RenderSettingsRows(false) end
end

local function CreateControlWindow()
    if controlWindow or not db then return end
    local frame = CreateFrame("Frame", "ShieldAuraForeverControlWindow", UIParent, "BackdropTemplate")
    controlWindow = frame
    frame:SetSize(710, 570)
    frame:SetPoint("CENTER", UIParent, "CENTER", db.windowX or defaults.windowX, db.windowY or defaults.windowY)
    frame:SetFrameStrata("DIALOG")
    frame:SetClampedToScreen(true)
    frame:SetMovable(true)
    frame:EnableMouse(true)
    frame:Hide()
    frame:SetBackdrop({
        bgFile="Interface\\DialogFrame\\UI-DialogBox-Background",
        edgeFile="Interface\\DialogFrame\\UI-DialogBox-Border",
        tile=true, tileSize=32, edgeSize=32,
        insets={left=11,right=12,top=12,bottom=11},
    })
    frame:SetBackdropColor(0.05,0.05,0.05,0.96)
    table.insert(UISpecialFrames, "ShieldAuraForeverControlWindow")

    local drag = CreateFrame("Frame",nil,frame)
    drag:SetPoint("TOPLEFT",12,-8)
    drag:SetPoint("TOPRIGHT",-36,-8)
    drag:SetHeight(32)
    drag:EnableMouse(true)
    drag:RegisterForDrag("LeftButton")
    drag:SetScript("OnDragStart", function() frame:StartMoving() end)
    drag:SetScript("OnDragStop", function() frame:StopMovingOrSizing(); SaveWindowPosition() end)

    local title = frame:CreateFontString(nil,"OVERLAY","GameFontNormalLarge")
    title:SetPoint("TOPLEFT",22,-19)
    title:SetText("Shield Aura Forever")
    local version = frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    version:SetPoint("LEFT",title,"RIGHT",9,0)
    version:SetText("v" .. ADDON_VERSION)
    local close = CreateFrame("Button",nil,frame,"UIPanelCloseButton")
    close:SetPoint("TOPRIGHT",-5,-5)

    settingsSearch = CreateFrame("EditBox", "ShieldAuraForeverSettingsSearch",frame,"InputBoxTemplate")
    settingsSearch:SetSize(603,28)
    settingsSearch:SetPoint("TOPLEFT",33,-58)
    settingsSearch:SetAutoFocus(false)
    settingsSearch:SetMaxLetters(60)
    settingsSearch:SetText("")
    settingsSearch:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    settingsSearch:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
    local searchHint = frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    searchHint:SetPoint("BOTTOMLEFT",settingsSearch,"TOPLEFT",0,4)
    searchHint:SetText("Search settings (e.g. height, display, move, opacity)")

    -- Always provide a mouse-only way to clear the search. Hide the control
    -- when empty, and let OnTextChanged restore the selected sidebar page.
    local clearSearch = CreateFrame("Button", "ShieldAuraForeverSearchClearButton", frame, "UIPanelCloseButton")
    clearSearch:SetSize(24,24)
    clearSearch:SetPoint("LEFT", settingsSearch, "RIGHT", 7, 0)
    clearSearch:SetScript("OnClick", function()
        settingsSearch:SetText("")
        settingsSearch:ClearFocus()
    end)
    clearSearch:Hide()
    windowControls.clearSearch = clearSearch

    local nav = CreateFrame("Frame",nil,frame,"BackdropTemplate")
    nav:SetPoint("TOPLEFT",22,-105)
    nav:SetSize(161,386)
    nav:SetBackdrop({bgFile="Interface\\Buttons\\WHITE8X8",edgeFile="Interface\\Buttons\\WHITE8X8",edgeSize=1})
    nav:SetBackdropColor(0.07,0.09,0.12,0.80)
    nav:SetBackdropBorderColor(0.23,0.28,0.33,0.8)
    for i,page in ipairs(SETTINGS_PAGES) do
        local button = CreateFrame("Button",nil,nav,"UIPanelButtonTemplate")
        button:SetSize(146,28)
        button:SetPoint("TOPLEFT",nav,"TOPLEFT",7,-11-(i-1)*33)
        button:SetText(page.label)
        button:SetScript("OnClick",function()
            activeSettingsPage=page.id
            settingsSearch:SetText("")
            settingsSearch:ClearFocus()
            RenderSettingsRows(true)
        end)
        pageButtons[page.id]=button
    end

    settingsHeading = frame:CreateFontString(nil,"OVERLAY","GameFontNormal")
    settingsHeading:SetPoint("TOPLEFT",frame,"TOPLEFT",199,-113)
    settingsHeading:SetText("Shield Bar")
    local searchCount = frame:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    searchCount:SetPoint("RIGHT",frame,"TOPRIGHT",-39,-115)
    windowControls.searchCount=searchCount

    settingsScroll = CreateFrame("ScrollFrame","ShieldAuraForeverSettingsScroll",frame,"UIPanelScrollFrameTemplate")
    settingsScroll:SetPoint("TOPLEFT",frame,"TOPLEFT",199,-136)
    settingsScroll:SetPoint("BOTTOMRIGHT",frame,"BOTTOMRIGHT",-43,74)
    settingsContent = CreateFrame("Frame",nil,settingsScroll)
    settingsContent:SetSize(448,400)
    settingsScroll:SetScrollChild(settingsContent)
    settingsEmpty = settingsContent:CreateFontString(nil,"OVERLAY","GameFontDisable")
    settingsEmpty:SetPoint("TOPLEFT",settingsContent,"TOPLEFT",8,-22)
    settingsEmpty:SetText("No matching settings. Try another keyword.")
    settingsEmpty:Hide()

    local function MakeRow(page,name,keywords,height)
        local row = CreateFrame("Frame",nil,settingsContent)
        row:SetSize(442,height or 36)
        local label = row:CreateFontString(nil,"OVERLAY","GameFontNormalSmall")
        label:SetPoint("LEFT",row,"LEFT",4,0)
        label:SetWidth(177)
        label:SetJustifyH("LEFT")
        label:SetWordWrap(true)
        label:SetText(name)
        row.page=page
        row.title=name
        row.keywords=(keywords or "")
        row.height=height or 36
        row.label=label
        settingsRows[#settingsRows+1]=row
        return row
    end

    local function Checkbox(page,name,keywords,key,onSet)
        local row=MakeRow(page,name,keywords,30)
        local cb=CreateFrame("CheckButton",nil,row,"UICheckButtonTemplate")
        cb:SetSize(26,26)
        cb:SetPoint("LEFT",row,"LEFT",204,0)
        cb:SetScript("OnClick",function(self)
            local val = self:GetChecked() and true or false
            if onSet then onSet(val) else db[key]=val; ApplyLayout() end
            RefreshAllUI()
        end)
        row.toggle=cb
        row.refresh=function() cb:SetChecked(db[key]==true) end
    end
    -- All scalar/ranged settings use the same slider + exact-entry control.
    -- RGB/HEX editing uses the game's color wheel instead of extra sliders.
    local function Number(page,name,keywords,key,lo,hi,step,formatter,onSet)
        local row=MakeRow(page,name,keywords,36)
        local slider=CreateFrame("Slider","ShieldAuraForeverV12"..key,row,"OptionsSliderTemplate")
        slider:SetPoint("LEFT",row,"LEFT",204,0)
        slider:SetWidth(131)
        slider:SetMinMaxValues(lo,hi)
        slider:SetValueStep(step or 1)
        if slider.SetObeyStepOnDrag then slider:SetObeyStepOnDrag(true) end
        for _,suffix in ipairs({"Low","High","Text"}) do
            local annotation=_G[slider:GetName()..suffix]
            if annotation then annotation:SetText("") end
        end
        local edit=CreateFrame("EditBox",nil,row,"InputBoxTemplate")
        edit:SetSize(66,24)
        edit:SetPoint("LEFT",row,"LEFT",351,0)
        edit:SetAutoFocus(false)
        edit:SetMaxLetters(10)
        local function ShowRange(owner)
            GameTooltip:SetOwner(owner, "ANCHOR_RIGHT")
            GameTooltip:SetText(name)
            GameTooltip:AddLine(string.format("Allowed range: %s to %s", tostring(lo), tostring(hi)), 0.9, 0.9, 0.9)
            GameTooltip:Show()
        end
        local function HideRange() GameTooltip:Hide() end
        slider:SetScript("OnEnter",ShowRange)
        slider:SetScript("OnLeave",HideRange)
        edit:SetScript("OnEnter",ShowRange)
        edit:SetScript("OnLeave",HideRange)

        local function DisplayValue()
            local stored=db[key]
            if key=="barOpacity" or key=="numberOpacity" then
                return math.floor((stored or 1)*100+0.5)
            end
            return stored
        end
        local function ApplyNumber(raw)
            if not raw or raw~=raw or raw<lo or raw>hi then return false end
            local val=step and (math.floor(raw/step+0.5)*step) or raw
            val=math.max(lo,math.min(hi,val))
            if onSet then onSet(val) else db[key]=val;ApplyLayout() end
            RefreshAllUI()
            return true
        end
        local function Commit(self)
            if not ApplyNumber(tonumber(self:GetText())) then
                Print(name.." must be between "..lo.." and "..hi..".")
                RefreshAllUI()
            end
        end
        edit:SetScript("OnEnterPressed",function(self) Commit(self);self:ClearFocus() end)
        edit:SetScript("OnEditFocusLost",Commit)
        edit:SetScript("OnEscapePressed",function(self) self:ClearFocus(); RefreshAllUI() end)
        slider:SetScript("OnValueChanged",function(self,val)
            if not self._safUpdating and db then ApplyNumber(val) end
        end)
        row.refresh=function()
            slider._safUpdating=true
            slider:SetValue(DisplayValue())
            slider._safUpdating=false
            if not edit:HasFocus() then
                local stored=db[key]
                edit:SetText(formatter and formatter(stored) or tostring(stored))
            end
        end
        return row
    end
    Checkbox("bar","Horizontal layout","layout display curved vertical horizontal","_horizontal",function(on)
        db.layout=on and "horizontal" or "curved";ApplyLayout()
    end)
    local layoutRow=settingsRows[#settingsRows]
    layoutRow.refresh=function() layoutRow.toggle:SetChecked(db.layout=="horizontal") end
    Checkbox("bar","Solid bar","solid segmented style visual","_solid",function(on)
        db.barStyle=on and "solid" or "segmented";ApplyLayout()
    end)
    local solidRow=settingsRows[#settingsRows]
    solidRow.refresh=function() solidRow.toggle:SetChecked(db.barStyle=="solid") end
    Number("bar","HUD scale","scale resize curved proportional size","scale",0.5,2.5,0.05,function(n) return string.format("%.2f",n) end,function(n) SetScale(n,true) end)
    Number("bar","Horizontal width (px)","width exact pixels dimensions stretch bar","horizontalBarWidth",60,500,1)
    Number("bar","Horizontal height (px)","height exact pixels dimensions stretch bar","horizontalBarHeight",6,64,1)
    Checkbox("bar","Reverse fill direction","drain left first right top bottom","reverseFill")
    Checkbox("bar","Mirror curved bar","mirror left right bow curve","mirrorCurve")
    Checkbox("bar","Shield-loss animation","animation fade drift curved","animateLoss")

    Checkbox("number","Show absorb number","display exact shield amount text visibility","showText",function(on)
        db.showText=on;ApplyLayout();UpdateAbsorb()
    end)
    Checkbox("number","Independent number position","detach separate drag move position float anchor","numberDetached",SetNumberDetached)
    Checkbox("number","Show number above bar","top bottom attached display location","_numberTop",function(on)
        db.textPosition=on and "top" or "bottom";ApplyLayout()
    end)
    local topRow=settingsRows[#settingsRows]
    topRow.refresh=function() topRow.toggle:SetChecked(db.textPosition=="top") end
    Number("number","Number font size (px)","number text font size readability accessibility","numberFontSize",8,40,1)

    local colorRow=MakeRow("color","Color preset","class auto automatic gold original custom RGB hex color palette",42)
    local colorDropdown
    local ok, dropdown=pcall(function()
        local d=CreateFrame("DropdownButton",nil,colorRow,"WowStyle1DropdownTemplate")
        d:SetSize(223,29)
        d:SetPoint("LEFT",colorRow,"LEFT",197,0)
        d:SetupMenu(function(_,root)
            for _,opt in ipairs(colorOptions) do
                root:CreateRadio(opt.label,function(v) return db.colorMode==v end,
                    function(v) db.colorMode=v;ApplyLayout();RefreshAllUI() end,opt.value)
            end
        end)
        return d
    end)
    if ok and dropdown then colorDropdown=dropdown else
        colorDropdown=CreateFrame("Button",nil,colorRow,"UIPanelButtonTemplate")
        colorDropdown:SetSize(224,26)
        colorDropdown:SetPoint("LEFT",colorRow,"LEFT",196,0)
        colorDropdown:SetScript("OnClick",function()
            local idx=1
            for i,opt in ipairs(colorOptions) do if opt.value==db.colorMode then idx=i;break end end
            db.colorMode=colorOptions[idx % #colorOptions+1].value
            ApplyLayout();RefreshAllUI()
        end)
    end
    colorRow.refresh=function()
        if colorDropdown.GenerateMenu then
            if colorDropdown._mode~=db.colorMode then
                colorDropdown._mode=db.colorMode
                if not colorDropdown:IsMenuOpen() then colorDropdown:GenerateMenu() end
            end
        else
            for _,o in ipairs(colorOptions) do if o.value==db.colorMode then colorDropdown:SetText(o.label) end end
        end
    end

    local rgbRow=MakeRow("color","Custom HEX / RGB","red green blue custom color picker hex precision accessibility",68)
    local hex=CreateFrame("EditBox",nil,rgbRow,"InputBoxTemplate")
    hex:SetSize(88,23)
    hex:SetPoint("TOPLEFT",rgbRow,"TOPLEFT",206,-8)
    hex:SetAutoFocus(false)
    hex:SetMaxLetters(7)
    local rgb=CreateFrame("EditBox",nil,rgbRow,"InputBoxTemplate")
    rgb:SetSize(129,23)
    rgb:SetPoint("LEFT",hex,"RIGHT",12,0)
    rgb:SetAutoFocus(false)
    rgb:SetMaxLetters(14)
    local pick=CreateFrame("Button",nil,rgbRow,"UIPanelButtonTemplate")
    pick:SetSize(118,24)
    pick:SetPoint("TOPLEFT",rgbRow,"TOPLEFT",203,-42)
    pick:SetText("Color Picker")
    pick:SetScript("OnClick",OpenCustomColorPicker)
    local helper=rgbRow:CreateFontString(nil,"OVERLAY","GameFontDisableSmall")
    helper:SetPoint("LEFT",pick,"RIGHT",8,0)
    helper:SetText("HEX | R, G, B")
    hex:SetScript("OnEnterPressed",function(self)
        if not CommitRGB(ParseRGBHex(self:GetText())) then Print("Use a six-digit HEX color, e.g. #3FC7EB.") end
        self:ClearFocus()
    end)
    rgb:SetScript("OnEnterPressed",function(self)
        local a,b,c=self:GetText():match("^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$")
        if not CommitRGB(tonumber(a),tonumber(b),tonumber(c)) then Print("Use RGB values 0–255, e.g. 63, 199, 235.") end
        self:ClearFocus()
    end)
    hex:SetScript("OnEscapePressed",function(self) self:ClearFocus();RefreshAllUI() end)
    rgb:SetScript("OnEscapePressed",function(self) self:ClearFocus();RefreshAllUI() end)
    rgbRow.refresh=function()
        if not hex:HasFocus() then hex:SetText(string.format("#%02X%02X%02X",db.customR,db.customG,db.customB)) end
        if not rgb:HasFocus() then rgb:SetText(string.format("%d, %d, %d",db.customR,db.customG,db.customB)) end
    end

    Checkbox("visibility","Combat only","display hide outside combat show in combat visibility","combatOnly")
    Number("visibility","HUD opacity (%)","overall bar shield number transparency alpha opacity fade", "barOpacity",0,100,1,
        function(n) return tostring(math.floor(n*100+0.5)) end,
        function(n) db.barOpacity=n/100;ApplyLayout() end)
    Checkbox("visibility","Match number to HUD opacity","number opacity number text same opacity alpha transparency link sync", "linkNumberOpacity")
    local numberAlphaRow=Number("visibility","Number opacity (%)","separate independent number text opacity alpha transparency", "numberOpacity",0,100,1,
        function(n) return tostring(math.floor(n*100+0.5)) end,
        function(n) db.numberOpacity=n/100;ApplyLayout() end)
    -- Keep the settings page short unless a user requests separate number
    -- transparency; search for 'opacity' still finds the linking checkbox.
    numberAlphaRow.visibleWhen=function() return db.linkNumberOpacity==false end

    Checkbox("minimap","Show minimap button","minimap show hide button icon","showMinimap",function(on)
        SetMinimapVisible(on,true)
    end)
    Number("minimap","Button distance (px)","minimap radius offset distance precise number", "minimapRadius",55,200,1,nil,function(n)
        SetMinimapRadius(n,true)
    end)

    RenderSettingsRows=function(resetScroll)
        local query = settingsSearch:GetText():lower():match("^%s*(.-)%s*$") or ""
        local searchMode = query~=""
        local title = "Shield Bar"
        for _,page in ipairs(SETTINGS_PAGES) do if page.id==activeSettingsPage then title=page.label end end
        settingsHeading:SetText(searchMode and "Search results" or title)
        for _,page in ipairs(SETTINGS_PAGES) do
            local b=pageButtons[page.id]
            if b then if page.id==activeSettingsPage and not searchMode then b:LockHighlight() else b:UnlockHighlight() end end
        end
        local top=0
        local matches=0
        for _,row in ipairs(settingsRows) do
            local haystack=(row.title.." "..row.page.." "..row.keywords):lower()
            local visible = ((searchMode and haystack:find(query,1,true)) or (not searchMode and row.page==activeSettingsPage))
                and (not row.visibleWhen or row.visibleWhen())
            if visible then
                row:ClearAllPoints()
                row:SetPoint("TOPLEFT",settingsContent,"TOPLEFT",0,-top)
                row:Show()
                top=top+row.height+1
                matches=matches+1
            else
                row:Hide()
            end
        end
        settingsEmpty:SetShown(matches==0)
        windowControls.searchCount:SetText(searchMode and (matches.." matches") or "")
        settingsContent:SetHeight(math.max(330,top+8))
        if resetScroll then settingsScroll:SetVerticalScroll(0) end
    end
    settingsSearch:SetScript("OnTextChanged",function(self)
        clearSearch:SetShown(self:GetText() ~= "")
        RenderSettingsRows(true)
    end)

    local divider=frame:CreateTexture(nil,"BACKGROUND")
    divider:SetColorTexture(0.27,0.30,0.35,0.8)
    divider:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",21,68)
    divider:SetSize(665,1)
    local lock=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    lock:SetSize(133,26)
    lock:SetPoint("BOTTOMLEFT",frame,"BOTTOMLEFT",24,27)
    lock:SetScript("OnClick",function() SetLocked(not db.locked,true);RefreshAllUI() end)
    windowControls.lockButton=lock
    local test=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    test:SetSize(133,26)
    test:SetPoint("LEFT",lock,"RIGHT",9,0)
    test:SetScript("OnClick",function() ToggleTestPreview(true);RefreshAllUI() end)
    windowControls.testButton=test
    local calib=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    calib:SetSize(133,26)
    calib:SetPoint("LEFT",test,"RIGHT",9,0)
    calib:SetText("Calibrate Shield")
    calib:SetScript("OnClick",function() testing=false;Calibrate(false);ApplyLayout();UpdateAbsorb();RefreshAllUI() end)
    local reset=CreateFrame("Button",nil,frame,"UIPanelButtonTemplate")
    reset:SetSize(133,26)
    reset:SetPoint("LEFT",calib,"RIGHT",9,0)
    reset:SetText("Reset Layout")
    reset:SetScript("OnClick",function()
        ResetHUDLayout(true); RefreshAllUI()
        Print("HUD layout reset; calibration and minimap settings preserved.")
    end)
    frame:SetScript("OnShow",RefreshControlWindow)
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
    -- Blizzard's Settings canvas can leave an inactive InputBoxTemplate blank,
    -- even when SetText has run. An always-visible FontString displays the saved
    -- value instead; activate the EditBox only while the player is editing.
    if c.minimapRadiusDisplayText then
        c.minimapRadiusDisplayText:SetText(tostring(math.floor(db.minimapRadius or defaults.minimapRadius)))
    end
    if c.minimapRadiusEdit and not c.minimapRadiusEdit:HasFocus() then
        c.minimapRadiusEdit:SetText(tostring(math.floor(db.minimapRadius or defaults.minimapRadius)))
    end
    if c.minimapRadiusValue then c.minimapRadiusValue:SetText("px") end
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

    -- Use ONE native, always-visible EditBox as the mouse/keyboard hit target.
    -- In the Blizzard Settings canvas an idle EditBox's text can be invisible
    -- despite SetText. A FontString child overlays the saved value when idle;
    -- when the user clicks, the native EditBox handles focus and typing.
    -- There is no separate button to intercept a click or hide/reparent input.
    local minimapRadiusEdit = CreateFrame("EditBox",nil,panel,"InputBoxTemplate")
    minimapRadiusEdit:SetSize(64,24)
    minimapRadiusEdit:SetPoint("LEFT",minimapRadiusSlider,"RIGHT",15,0)
    minimapRadiusEdit:SetAutoFocus(false)
    minimapRadiusEdit:SetMaxLetters(3)
    minimapRadiusEdit:SetFont(STANDARD_TEXT_FONT,14,"")
    minimapRadiusEdit:EnableMouse(true)
    minimapRadiusEdit:SetText(tostring(math.floor(db.minimapRadius or defaults.minimapRadius)))
    -- Hide only the EditBox's text when idle; keep the whole native input shown
    -- and clickable. Alpha is NOT applied to the EditBox frame itself.
    minimapRadiusEdit:SetTextColor(1,1,1,0)
    optionControls.minimapRadiusEdit=minimapRadiusEdit

    local minimapRadiusDisplayText = minimapRadiusEdit:CreateFontString(nil,"OVERLAY","GameFontHighlight")
    minimapRadiusDisplayText:SetPoint("CENTER",minimapRadiusEdit,"CENTER",0,0)
    minimapRadiusDisplayText:SetText(tostring(math.floor(db.minimapRadius or defaults.minimapRadius)))
    optionControls.minimapRadiusDisplayText=minimapRadiusDisplayText

    local editingRadius = false
    local function FinishRadiusEdit(self,shouldCommit)
        if not editingRadius then return end
        editingRadius = false
        local entered = self:GetText()
        if shouldCommit then
            local n=tonumber(entered)
            if n and n>=55 and n<=200 then
                SetMinimapRadius(math.floor(n+0.5),true)
            else
                Print("Minimap button distance must be 55–200 pixels.")
            end
        end
        -- ClearFocus may synchronously trigger OnEditFocusLost; editingRadius
        -- prevents a duplicate commit. We do not hide the EditBox itself.
        self:ClearFocus()
        self:SetTextColor(1,1,1,0)
        minimapRadiusDisplayText:Show()
        RefreshAllUI()
    end
    minimapRadiusEdit:SetScript("OnEditFocusGained",function(self)
        editingRadius = true
        minimapRadiusDisplayText:Hide()
        self:SetTextColor(1,1,1,1)
        self:SetText(tostring(math.floor(db.minimapRadius or defaults.minimapRadius)))
        self:HighlightText()
    end)
    -- Explicit mouse focus as a fallback for Settings canvas focus handling;
    -- the stock EditBox still receives native keyboard interaction.
    minimapRadiusEdit:SetScript("OnMouseDown",function(self)
        if not self:HasFocus() then self:SetFocus() end
    end)
    minimapRadiusEdit:SetScript("OnEnterPressed",function(self) FinishRadiusEdit(self,true) end)
    minimapRadiusEdit:SetScript("OnEditFocusLost",function(self) FinishRadiusEdit(self,true) end)
    minimapRadiusEdit:SetScript("OnEscapePressed",function(self) FinishRadiusEdit(self,false) end)
    minimapRadiusEdit:SetScript("OnEnter",function(self)
        GameTooltip:SetOwner(self,"ANCHOR_RIGHT")
        GameTooltip:SetText("Minimap button distance")
        GameTooltip:AddLine("Click to type an exact value (55–200 pixels).",0.9,0.9,0.9)
        GameTooltip:Show()
    end)
    minimapRadiusEdit:SetScript("OnLeave",function() GameTooltip:Hide() end)

    local minimapRadiusValue = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    minimapRadiusValue:SetPoint("LEFT", minimapRadiusEdit, "RIGHT", 8, 0)
    optionControls.minimapRadiusValue = minimapRadiusValue

    local info = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    info:SetPoint("TOPLEFT", minimapRadiusSlider, "BOTTOMLEFT", -6, -20)
    info:SetPoint("RIGHT", panel, "RIGHT", -28, 0)
    info:SetJustifyH("LEFT")
    info:SetWordWrap(true)
    info:SetText(
        "The minimap button opens the same movable settings window. Drag it around the rim to change angle; use the distance slider or click the number to enter an exact pixel distance.\n\n" ..
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
    RefreshOptionsPanel()
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
events:RegisterEvent("PLAYER_REGEN_DISABLED")
events:RegisterEvent("PLAYER_REGEN_ENABLED")
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
        ApplyVisibility() -- restore combat-only visibility on login/reload
        C_Timer.After(0.2, UpdateAbsorb)
        return
    end

    if event == "PLAYER_REGEN_DISABLED" or event == "PLAYER_REGEN_ENABLED" then
        -- Uses combat state, not combat-secret shield or aura data.
        ApplyVisibility()
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
    Print("/saf textpos top|bottom - attach the number above/below the aura")
    Print("/saf detach on|off - move the number separately (unlock to drag)")
    Print("/saf width N, /saf height N - exact horizontal bar size in pixels")
    Print("/saf opacity 0..100 - shield bar opacity percentage")
    Print("/saf combatonly on|off - hide HUD outside combat")
    Print("/saf hex RRGGBB - use a custom RGB color")
    Print("/saf flip     - reverse which end of the shield aura drains")
    Print("/saf mirror [on|off] - mirror the curved HUD")
    Print("/saf layout curved|horizontal - select HUD layout")
    Print("/saf style segmented|solid - select bar style")
    Print("/saf color auto|gold|custom|warrior|paladin|hunter|rogue|priest|shaman|mage|warlock|druid")
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
    elseif cmd == "detach" then
        if arg ~= "on" and arg ~= "off" then Print("use /saf detach on or /saf detach off"); return end
        SetNumberDetached(arg=="on")
        RefreshAllUI()
        Print(arg=="on" and "number detached; unlock and drag it independently." or "number attached to bar.")
    elseif cmd == "width" or cmd == "height" then
        local n=tonumber(arg)
        local key=cmd=="width" and "horizontalBarWidth" or "horizontalBarHeight"
        local lo=cmd=="width" and 60 or 6
        local hi=cmd=="width" and 500 or 64
        if not n or n<lo or n>hi then Print(cmd.." must be between "..lo.." and "..hi.." pixels."); return end
        db[key]=math.floor(n+0.5)
        ApplyLayout();RefreshAllUI()
    elseif cmd == "opacity" then
        local n=tonumber(arg)
        if not n or n<0 or n>100 then Print("opacity must be between 0 and 100 percent."); return end
        db.barOpacity=n/100
        ApplyLayout();RefreshAllUI()
    elseif cmd == "combatonly" then
        if arg~="on" and arg~="off" then Print("use /saf combatonly on or /saf combatonly off");return end
        db.combatOnly=arg=="on"
        ApplyLayout();RefreshAllUI()
    elseif cmd == "hex" then
        local r,g,b=ParseRGBHex(arg)
        if not CommitRGB(r,g,b) then Print("use /saf hex RRGGBB, e.g. /saf hex 3FC7EB") end
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
        if arg == "auto" or arg == "gold" or arg == "custom" then selected = arg end
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
