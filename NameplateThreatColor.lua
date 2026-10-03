local threatColors = {
    [1] = { 0, 1, 1 },
    [2] = { 0, 1, 1 },
    [3] = { 1, 0, 1 },
}
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

    local status
    if PlayerUtil.IsPlayerEffectivelyTank() then
        status = UnitThreatLeadSituation("player", unit)
    else
        status = UnitThreatSituation("player", unit)
    end
    if issecretvalue(status) then
        return
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
