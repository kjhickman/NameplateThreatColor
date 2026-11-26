local _, addon = ...

local nonTankColors = {}
local tankColors = {}
local coTankColor
local separateColors = false
local overlays = {}
local partyUnits = { "party1", "party2", "party3", "party4" }
local raidUnits = {}
for index = 1, MAX_RAID_MEMBERS do
    raidUnits[index] = "raid" .. index
end

-- nil follows the player's live role; true or false pins it to a locked choice.
local lockedRole
local lastEffectiveTank
local coTankUnits = {}
local coTankUnitsDirty = true
local cachedRaidIndex

local function IsRaidTank(member)
    local sawSecret = false
    local role = UnitGroupRolesAssigned(member)
    if issecretvalue(role) then
        sawSecret = true
    elseif role == "TANK" then
        return true, false
    end
    local mainTank = GetPartyAssignment("MAINTANK", member)
    if issecretvalue(mainTank) then
        return false, true
    end
    if mainTank then
        return true, false
    end
    return false, sawSecret
end

local function GetCoTankUnits(playerRaidIndex)
    if not coTankUnitsDirty and cachedRaidIndex == playerRaidIndex then
        return coTankUnits
    end

    local count = 0
    local sawSecret = false
    for index = 1, GetNumGroupMembers() do
        if index ~= playerRaidIndex then
            local member = raidUnits[index]
            if member then
                local isRaidTank, isSecret = IsRaidTank(member)
                if isSecret then
                    sawSecret = true
                elseif isRaidTank then
                    count = count + 1
                    coTankUnits[count] = member
                end
            end
        end
    end
    for index = count + 1, #coTankUnits do
        coTankUnits[index] = nil
    end
    cachedRaidIndex = playerRaidIndex
    coTankUnitsDirty = sawSecret
    return coTankUnits
end

local function IsCoTankHoldingAggro(unit, playerRaidIndex)
    for _, member in ipairs(GetCoTankUnits(playerRaidIndex)) do
        local status = UnitThreatSituation(member, unit)
        if not issecretvalue(status) and (status == 2 or status == 3) then
            return true
        end
    end
    return false
end

local function GetThreatColor(frame)
    -- Reject restricted (secret) values before inspecting them or branching on them.
    -- Unusable threat data leaves Blizzard's native color visible.
    -- Check the nameplate-only flag first so party/raid frames exit without pattern matching.
    local enabled = frame.displayThreatHealthBarColor
    if issecretvalue(enabled) or not enabled then
        return
    end

    local unit = frame.displayedUnit
    if issecretvalue(unit) or type(unit) ~= "string" or not unit:match("^nameplate%d+$") then
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

    -- Enemy players do not have threat tables; skip group and co-tank threat scans in PvP.
    local isPlayer = UnitIsPlayer(unit)
    if issecretvalue(isPlayer) or isPlayer then
        return
    end

    -- A locked role keeps these colors consistent across stance, form or
    -- specialization changes that would otherwise flip the live role mid-fight.
    local isTank = lockedRole
    if isTank == nil then
        isTank = PlayerUtil.IsPlayerEffectivelyTank() and true or false
        lastEffectiveTank = isTank
    end
    local raidIndex = UnitInRaid("player")
    if issecretvalue(raidIndex) then
        raidIndex = nil
    end
    if not raidIndex and not UnitInParty("player") then
        return
    end

    -- The co-tank color follows actual aggro, independent of the player's threat lead.
    local playerStatus
    local hasPlayerStatus = false
    if isTank and coTankColor and raidIndex then
        playerStatus = UnitThreatSituation("player", unit)
        hasPlayerStatus = true
        if
            not issecretvalue(playerStatus)
            and (playerStatus == nil or playerStatus == 0 or playerStatus == 1)
            and IsCoTankHoldingAggro(unit, raidIndex)
        then
            return coTankColor
        end
    end

    local palette = (isTank and separateColors) and tankColors or nonTankColors

    -- These APIs report different per-player states, not a shared state for the mob.
    -- Tanks: 0 = safe lead, 1/2 = weaker leads, 3 = unsafe/not highest threat.
    -- Non-tanks: 0 = low threat, 1 = high threat/no aggro, 2 = aggro/not highest
    -- threat, 3 = aggro/highest threat. Highest threat does not guarantee actual aggro.
    local status = (isTank and UnitThreatLeadSituation or UnitThreatSituation)("player", unit)
    if issecretvalue(status) then
        return
    end

    -- A missing non-tank threat entry is safe only when known group threat confirms
    -- this engaged enemy is fighting our group, rather than someone else's.
    if status == nil and not isTank then
        local inCombat = UnitAffectingCombat(unit)
        if issecretvalue(inCombat) or not inCombat then
            return
        end
        if raidIndex then
            for _, member in ipairs(GetCoTankUnits(raidIndex)) do
                local tankStatus = UnitThreatSituation(member, unit)
                if not issecretvalue(tankStatus) and palette[tankStatus] then
                    return palette[0]
                end
            end
            for index = 1, GetNumGroupMembers() do
                local member = raidUnits[index]
                if index ~= raidIndex and member then
                    local raidStatus = UnitThreatSituation(member, unit)
                    if not issecretvalue(raidStatus) and palette[raidStatus] then
                        return palette[0]
                    end
                end
            end
        else
            for index = 1, GetNumSubgroupMembers() do
                local partyStatus = UnitThreatSituation(partyUnits[index], unit)
                if not issecretvalue(partyStatus) and palette[partyStatus] then
                    return palette[0]
                end
            end
        end
    end

    -- Confirm actual aggro before showing a tank's safe color. States 1/2 remain
    -- threat-lead warnings and do not guarantee the tank is being attacked.
    if status == 0 and isTank then
        if not hasPlayerStatus then
            playerStatus = UnitThreatSituation("player", unit)
        end
        if issecretvalue(playerStatus) or (playerStatus ~= 2 and playerStatus ~= 3) then
            return
        end
    end

    return palette[status]
end

local function SyncBarTexture(overlay, fill)
    local atlas = fill:GetAtlas()
    if atlas then
        if overlay.atlas ~= atlas then
            overlay.texture:SetAtlas(atlas)
            overlay.atlas = atlas
            overlay.file = nil
        end
        return
    end

    local file = fill:GetTexture()
    if overlay.atlas or overlay.file ~= file then
        overlay.texture:SetTexture(file)
        overlay.texture:SetTexCoord(0, 1, 0, 1)
        overlay.atlas = nil
        overlay.file = file
    end
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
    local fill = bar:GetStatusBarTexture()
    if not overlay then
        local overlayBar = CreateFrame("StatusBar", nil, bar)
        overlayBar:SetAllPoints(bar)
        overlayBar:SetUsingParentLevel(true)
        local texture = overlayBar:CreateTexture(nil, "ARTWORK", nil, 1)
        overlay = { bar = overlayBar, texture = texture }
        SyncBarTexture(overlay, fill)
        texture:SetAllPoints(overlayBar)
        overlayBar:SetStatusBarTexture(texture)
        overlays[frame] = overlay
    else
        SyncBarTexture(overlay, fill)
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

local function RefreshOverlays()
    for _, nameplate in ipairs(C_NamePlate.GetNamePlates()) do
        if not nameplate:IsForbidden() and nameplate.UnitFrame then
            UpdateThreatColor(nameplate.UnitFrame)
        end
    end
end

-- Run after Blizzard's normal update without replacing its health-color logic.
hooksecurefunc("CompactUnitFrame_UpdateHealthColor", UpdateThreatColor)

local function OnRoleOrRosterEvent(_, event)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ROLES_ASSIGNED" then
        coTankUnitsDirty = true
        if lockedRole == nil then
            lastEffectiveTank = PlayerUtil.IsPlayerEffectivelyTank() and true or false
        end
        RefreshOverlays()
        return
    end

    if lockedRole ~= nil then
        return
    end
    local isTank = PlayerUtil.IsPlayerEffectivelyTank() and true or false
    if isTank ~= lastEffectiveTank then
        lastEffectiveTank = isTank
        RefreshOverlays()
    end
end

local rosterEvents = CreateFrame("Frame")
rosterEvents:RegisterEvent("GROUP_ROSTER_UPDATE")
rosterEvents:RegisterEvent("PLAYER_ROLES_ASSIGNED")
rosterEvents:RegisterEvent("UPDATE_SHAPESHIFT_FORM")
rosterEvents:RegisterEvent("ACTIVE_PLAYER_SPECIALIZATION_CHANGED")
rosterEvents:RegisterUnitEvent("UNIT_AURA", "player")
rosterEvents:SetScript("OnEvent", OnRoleOrRosterEvent)

function addon.ApplyRoleLock(role)
    if role == "tank" then
        lockedRole = true
    elseif role == "nontank" then
        lockedRole = false
    else
        lockedRole = nil
        lastEffectiveTank = PlayerUtil.IsPlayerEffectivelyTank() and true or false
    end

    RefreshOverlays()
end

local function BuildPalette(palette, secure, warning, urgent, high)
    palette[0] = { CreateColorFromHexString(secure):GetRGB() }
    palette[1] = { CreateColorFromHexString(warning):GetRGB() }
    palette[2] = { CreateColorFromHexString(urgent):GetRGB() }
    palette[3] = { CreateColorFromHexString(high):GetRGB() }
end

function addon.ApplyColors(colors)
    coTankColor = colors.showCoTankColor
            and { CreateColorFromHexString(colors.coTankAggroColor):GetRGB() }
        or nil
    BuildPalette(
        nonTankColors,
        colors.secureAggroColor,
        colors.warningColor,
        colors.urgentWarningColor,
        colors.highThreatColor
    )

    separateColors = colors.separateTankColors
    if separateColors then
        BuildPalette(
            tankColors,
            colors.tankSecureAggroColor,
            colors.tankWarningColor,
            colors.tankUrgentWarningColor,
            colors.tankHighThreatColor
        )
    end

    RefreshOverlays()
end
