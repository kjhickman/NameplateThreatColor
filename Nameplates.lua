local _, addon = ...

local threatColors = {}
local overlays = {}
local partyUnits = { "party1", "party2", "party3", "party4" }

local function GetThreatColor(frame)
    -- Reject restricted (secret) values before inspecting them or branching on them.
    -- Unusable threat data leaves Blizzard's native color visible.
    local unit = frame.displayedUnit
    if issecretvalue(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then
        return
    end

    local enabled = frame.displayThreatHealthBarColor
    if issecretvalue(enabled) or not enabled or not UnitInParty("player") then
        return
    end

    -- Frames are recycled; only color the frame currently owned by this nameplate unit.
    local nameplate = C_NamePlate.GetNamePlateForUnit(unit)
    if not nameplate or nameplate.UnitFrame ~= frame then
        return
    end

    local enemy = UnitCanAttack("player", unit)
    if issecretvalue(enemy) or not enemy then
        return
    end

    -- These APIs report different per-player states, not a shared state for the mob.
    -- Tanks: 0 = safe lead, 1/2 = weaker leads, 3 = unsafe/not highest threat.
    -- Non-tanks: 0 = low threat, 1 = high threat/no aggro, 2 = aggro/not highest
    -- threat, 3 = aggro/highest threat. Highest threat does not guarantee actual aggro.
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

    -- A missing non-tank threat entry is safe only when known party threat confirms
    -- this engaged enemy is fighting our group, rather than someone else's.
    if status == nil and not isTank then
        local inCombat = UnitAffectingCombat(unit)
        if issecretvalue(inCombat) or not inCombat then
            return
        end
        for index = 1, GetNumSubgroupMembers() do
            local partyStatus = UnitThreatSituation(partyUnits[index], unit)
            if not issecretvalue(partyStatus) and threatColors[partyStatus] then
                return threatColors[0]
            end
        end
    end

    -- Confirm actual aggro before showing a tank's safe color. States 1/2 remain
    -- threat-lead warnings and do not guarantee the tank is being attacked.
    if status == 0 and isTank then
        local isTanking = UnitDetailedThreatSituation("player", unit)
        if issecretvalue(isTanking) or isTanking ~= true then
            return
        end
    end

    return threatColors[status]
end

local function UpdateThreatColor(frame)
    if frame:IsForbidden() then
        return
    end

    local color = GetThreatColor(frame)
    local overlay = overlays[frame]
    if not color then
        if overlay and overlay.shown then
            overlay.bar:Hide()
            overlay.shown = false
        end
        return
    end

    -- Use an addon-owned bar above the native fill instead of changing Blizzard's
    -- bar or textures. Reusing its art preserves the original shading and borders.
    local bar = frame.healthBar
    if not overlay then
        local overlayBar = CreateFrame("StatusBar", nil, bar)
        overlayBar:SetAllPoints(bar)
        overlayBar:SetFrameLevel(bar:GetFrameLevel())
        local fill = bar:GetStatusBarTexture()
        local texture = overlayBar:CreateTexture(nil, "ARTWORK", nil, 1)
        local atlas = fill:GetAtlas()
        if atlas then
            texture:SetAtlas(atlas)
        else
            texture:SetTexture(fill:GetTexture())
        end
        texture:SetAllPoints(overlayBar)
        overlayBar:SetStatusBarTexture(texture)
        overlay = { bar = overlayBar }
        overlays[frame] = overlay
    end
    -- Forward native health values, including secret values, directly to the renderer
    -- without inspecting or calculating with them in Lua.
    overlay.bar:SetMinMaxValues(bar:GetMinMaxValues())
    overlay.bar:SetValue(bar:GetValue())
    -- Shared color-table identity avoids redundant recoloring between palette changes.
    if overlay.color ~= color then
        overlay.bar:SetStatusBarColor(unpack(color))
        overlay.color = color
    end
    if not overlay.shown then
        overlay.bar:Show()
        overlay.shown = true
    end
end

-- Run after Blizzard's normal update without replacing its health-color logic.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", UpdateThreatColor)

function addon.ApplyColors(colors)
    local secure = CreateColorFromHexString(colors.secureAggroColor)
    local warning = CreateColorFromHexString(colors.warningColor)
    local urgent = CreateColorFromHexString(colors.urgentWarningColor)
    local high = CreateColorFromHexString(colors.highThreatColor)
    threatColors[0] = { secure:GetRGB() }
    threatColors[1] = { warning:GetRGB() }
    threatColors[2] = { urgent:GetRGB() }
    threatColors[3] = { high:GetRGB() }

    for frame in pairs(overlays) do
        UpdateThreatColor(frame)
    end
end
