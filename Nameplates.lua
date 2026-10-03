local _, addon = ...

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

function addon.ApplyColors(colors)
    local secure = CreateColorFromHexString(colors.secureAggroColor)
    local warning = CreateColorFromHexString(colors.warningColor)
    local high = CreateColorFromHexString(colors.highThreatColor)
    threatColors[0] = { secure:GetRGB() }
    threatColors[1] = { warning:GetRGB() }
    threatColors[2] = threatColors[1]
    threatColors[3] = { high:GetRGB() }

    for frame in pairs(overlays) do
        UpdateThreatColor(frame)
    end
end
