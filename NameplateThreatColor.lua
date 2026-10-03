local defaults = {
    secureAggroColor = "ff00ff00",
    warningColor = "ffffff00",
    highThreatColor = "ffff0000",
}
local threatColors = {}
local overlays = {}

local function UpdateThreatColor(frame)
    if frame:IsForbidden() then
        return
    end

    local overlay = overlays[frame]
    if overlay then
        overlay:Hide()
    end

    local unit = frame.displayedUnit
    if issecretvalue(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then
        return
    end

    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or nameplate.UnitFrame ~= frame then
        return
    end

    local enabled = frame.displayThreatHealthBarColor
    if issecretvalue(enabled) or not enabled or not UnitInParty("player") then
        return
    end

    local enemy = UnitCanAttack("player", unit)
    if issecretvalue(enemy) or not enemy then
        return
    end

    local isTank = PlayerUtil.IsPlayerEffectivelyTank()
    local status
    if isTank then
        status = UnitThreatLeadSituation("player", unit)
    else
        status = UnitThreatSituation("player", unit)
    end
    if issecretvalue(status) then
        return
    end

    if status == 0 and isTank then
        local isTanking = UnitDetailedThreatSituation("player", unit)
        if issecretvalue(isTanking) or isTanking ~= true then
            return
        end
    end

    local color = threatColors[status]
    if not color then
        return
    end

    if not overlay then
        local bar = frame.healthBar
        overlay = bar:CreateTexture(nil, "ARTWORK", nil, 0)
        overlay:SetAllPoints(bar:GetStatusBarTexture())
        overlays[frame] = overlay
    end
    overlay:SetColorTexture(unpack(color))
    overlay:Show()
end

hooksecurefunc("CompactUnitFrame_UpdateHealthColor", UpdateThreatColor)

local function ApplyColors()
    local secure = CreateColorFromHexString(NameplateThreatColorDB.secureAggroColor)
    local warning = CreateColorFromHexString(NameplateThreatColorDB.warningColor)
    local high = CreateColorFromHexString(NameplateThreatColorDB.highThreatColor)
    threatColors[0] = { secure:GetRGB() }
    threatColors[1] = { warning:GetRGB() }
    threatColors[2] = threatColors[1]
    threatColors[3] = { high:GetRGB() }

    for frame in pairs(overlays) do
        UpdateThreatColor(frame)
    end
end

local function RegisterColorSetting(category, key, label, tooltip)
    local setting = Settings.RegisterProxySetting(
        category,
        "NameplateThreatColor_" .. key,
        Settings.VarType.String,
        label,
        defaults[key],
        function()
            return NameplateThreatColorDB[key]
        end,
        function(value)
            NameplateThreatColorDB[key] = value
            ApplyColors()
        end
    )
    Settings.CreateColorSwatch(category, setting, tooltip)
end

EventUtil.ContinueOnAddOnLoaded("NameplateThreatColor", function()
    NameplateThreatColorDB = NameplateThreatColorDB or {}
    for key, value in pairs(defaults) do
        if NameplateThreatColorDB[key] == nil then
            NameplateThreatColorDB[key] = value
        end
    end
    ApplyColors()

    local category = Settings.RegisterVerticalLayoutCategory("NameplateThreatColor")
    RegisterColorSetting(
        category,
        "secureAggroColor",
        "Secure aggro color",
        "For tanks: holding aggro with a safe threat lead. For non-tanks: no aggro and safely below the pull threshold (threat state 0). Unknown threat stays unchanged. Requires a party and Nameplates > Threat Display > Health Bar Color."
    )
    RegisterColorSetting(
        category,
        "warningColor",
        "Gaining / losing aggro color",
        "Color for gaining or losing aggro (threat states 1 and 2). Requires a party and Nameplates > Threat Display > Health Bar Color."
    )
    RegisterColorSetting(
        category,
        "highThreatColor",
        "Pulled / lost aggro color",
        "For non-tanks: holding aggro. For tanks: lost or unsafe aggro (threat state 3). Requires a party and Nameplates > Threat Display > Health Bar Color."
    )
    Settings.RegisterAddOnCategory(category)
end)
