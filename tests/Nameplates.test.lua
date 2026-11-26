local helpers = ...
local state = helpers.state
local test = helpers.test
local newFrame = helpers.newFrame
local assertColor = helpers.assertColor

test("party frames are not given overlays", function()
    state.update(newFrame("player"))
    assert(#state.textures == 0)
end)

test("custom threat colors draw above Blizzard's health-bar fill", function()
    local frame = newFrame()
    state.update(frame)
    local layer, sublevel = frame.healthBar:GetStatusBarTexture():GetDrawLayer()
    local texture = state.textures[1]
    assert(texture.layer == layer and texture.sublevel > sublevel)
    assert(texture.owner.usingParentLevel == true)
end)

test("the overlay tints Blizzard's own atlas", function()
    local frame = newFrame()
    local fill = frame.healthBar:GetStatusBarTexture()
    state.update(frame)
    local texture = state.textures[1]
    assert(texture.atlas == fill:GetAtlas() and texture.file == nil)
    assertColor(texture, 1, 0, 0)
end)

test("classic-style overlays reuse Blizzard's texture file", function()
    local frame = newFrame()
    local fill = frame.healthBar:GetStatusBarTexture()
    fill.atlas = nil
    state.update(frame)
    local texture = state.textures[1]
    assert(texture.file == fill:GetTexture() and texture.atlas == nil)
    assertColor(texture, 1, 0, 0)
end)

test("switching nameplate style live updates the cached overlay texture", function()
    local frame = newFrame()
    local fill = frame.healthBar:GetStatusBarTexture()
    state.update(frame)
    local texture = state.textures[1]
    assert(texture.atlas == "test-nameplate-bar" and texture.atlasCalls == 1)

    state.update(frame)
    assert(texture.atlasCalls == 1 and texture.textureCalls == nil)

    fill.atlas = nil
    state.update(frame)
    assert(texture.file == 12345 and texture.atlas == nil and texture.textureCalls == 1)
    assert(
        texture.texCoord[1] == 0
            and texture.texCoord[2] == 1
            and texture.texCoord[3] == 0
            and texture.texCoord[4] == 1
    )

    state.update(frame)
    assert(texture.textureCalls == 1)

    fill.atlas = "test-nameplate-bar"
    state.update(frame)
    assert(texture.atlas == "test-nameplate-bar" and texture.file == nil)
    assert(texture.atlasCalls == 2)
    assertColor(texture, 1, 0, 0)
end)

test("WoW's status-bar renderer receives native health without stretching the texture", function()
    for index, useAtlas in ipairs({ true, false }) do
        local frame = newFrame("nameplate" .. index)
        local native = frame.healthBar
        if not useAtlas then
            native:GetStatusBarTexture().atlas = nil
        end
        for _, value in ipairs({ 100, 50, 10, 100 }) do
            native.value = value
            state.update(frame)
            local texture = state.textures[index]
            local overlay = texture.owner
            assert(overlay.anchor == native and texture.anchor == overlay)
            assert(overlay.minimum == native.minimum and overlay.maximum == native.maximum)
            assert(overlay.value == value)
        end
        native.maximum, native.value = 200, 150
        state.update(frame)
        local texture = state.textures[index]
        assert(texture.owner.maximum == 200 and texture.owner.value == 150)
        assertColor(texture, 1, 0, 0)
    end
end)

test("secret native health is forwarded without calculation", function()
    local frame = newFrame()
    frame.healthBar.maximum, frame.healthBar.value = state.secret, state.secret
    state.update(frame)
    local texture = state.textures[1]
    assert(texture.owner.maximum == state.secret and texture.owner.value == state.secret)
    assertColor(texture, 1, 0, 0)
end)

test("Health Bar Color off hides the overlay, which returns with the latest palette", function()
    local frame, native = newFrame()
    state.update(frame)
    native.displayThreatHealthBarColor = false
    state.update(frame)
    state.addon.ApplyColors({
        secureAggroColor = "ff00ff00",
        warningColor = "ffffff00",
        urgentWarningColor = "ffff9900",
        highThreatColor = "ff0000ff",
    })
    local texture = state.textures[1]
    assert(not texture.shown)
    native.displayThreatHealthBarColor = true
    state.update(frame)
    assertColor(texture, 0, 0, 1)
end)

test("a non-tank losing all threat turns green until the enemy leaves combat", function()
    state.combat = true
    state.partyThreat.nameplate1 = { party1 = 3 }
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)
    state.status = nil
    state.update(frame)
    assertColor(state.textures[1], 0, 1, 0)
    state.combat = false
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("a non-tank with no threat on an engaged enemy uses the configured safe color", function()
    state.status, state.combat = nil, true
    state.partyThreat.nameplate1 = { party1 = 3 }
    state.update(newFrame())
    assertColor(state.textures[1], 0, 1, 0)
    state.addon.ApplyColors({
        secureAggroColor = "ff0000ff",
        warningColor = "ffffff00",
        urgentWarningColor = "ffff9900",
        highThreatColor = "ffff0000",
    })
    assertColor(state.textures[1], 0, 0, 1)
end)

test("other people's fighting mobs do not get the no-threat green color", function()
    state.status, state.combat = nil, true
    local frame = newFrame()
    state.update(frame)
    assert(#state.textures == 0)
    state.status = 3
    state.update(frame)
    state.status = nil
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("any known party threat state confirms the no-threat fallback", function()
    state.status, state.combat = nil, true
    local frame = newFrame()
    for status = 0, 3 do
        state.partyThreat.nameplate1 = { party4 = status }
        state.update(frame)
        assertColor(state.textures[1], 0, 1, 0)
    end
end)

test("secret or unknown party threat does not confirm engagement", function()
    state.status, state.combat = nil, true
    local frame = newFrame()
    state.partyThreat.nameplate1 = { party1 = state.secret, party2 = 4 }
    state.update(frame)
    assert(state.secretChecked and #state.textures == 0)
end)

test("party threat on one mob does not color another mob green", function()
    state.status, state.combat = nil, true
    state.partyThreat.nameplate1 = { party1 = 3 }
    state.update(newFrame("nameplate1"))
    assertColor(state.textures[1], 0, 1, 0)
    state.update(newFrame("nameplate2"))
    assert(#state.textures == 1)
end)

test("a non-tank in a raid confirms engagement from any raid member", function()
    state.party, state.partyMembers = false, 0
    state.raidIndex = 6
    state.raidRoles = { "TANK", "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER" }
    state.status, state.combat = nil, true
    state.raidThreat.nameplate1 = { raid1 = 3 }
    state.update(newFrame("nameplate1"))
    assertColor(state.textures[1], 0, 1, 0)
    state.update(newFrame("nameplate2"))
    assert(#state.textures == 1)
end)

test("a tank without threat-lead data does not get the no-threat color", function()
    state.tank, state.combat = true, true
    state.partyThreat.nameplate1 = { party1 = 3 }
    local frame = newFrame()
    state.update(frame)
    state.leadStatus = nil
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("a secret combat state hides the no-threat color", function()
    state.partyThreat.nameplate1 = { party1 = 3 }
    local frame = newFrame()
    state.update(frame)
    state.status, state.combat = nil, state.secret
    state.update(frame)
    assert(state.secretChecked and not state.textures[1].shown)
end)

test("secure tanks use green only while normal threat confirms holding aggro", function()
    state.tank, state.leadStatus = true, 0
    local frame = newFrame()
    for _, status in ipairs({ 2, 3 }) do
        state.status = status
        state.update(frame)
        assertColor(state.textures[1], 0, 1, 0)
    end
    for _, status in ipairs({ 0, 1, 4 }) do
        state.status = status
        state.update(frame)
        assert(not state.textures[1].shown)
    end
end)

test("secret normal threat is checked and hides the secure tank color", function()
    state.tank, state.leadStatus = true, 0
    local frame = newFrame()
    state.update(frame)
    state.status = state.secret
    state.update(frame)
    assert(state.secretChecked and not state.textures[1].shown)
end)

test("missing normal threat confirmation does not show the secure tank color", function()
    state.tank, state.leadStatus, state.status = true, 0, nil
    state.update(newFrame())
    assert(#state.textures == 0)
end)

test("tank confirmation uses the same mob as the threat-lead query", function()
    state.tank = true
    state.unitThreatLead = { nameplate1 = 0, nameplate2 = 0 }
    state.unitThreat = { nameplate1 = 3, nameplate2 = 0 }
    state.update(newFrame("nameplate1"))
    assertColor(state.textures[1], 0, 1, 0)
    state.update(newFrame("nameplate2"))
    assert(#state.textures == 1)
end)

test("tank warning and lost-aggro colors do not require normal threat confirmation", function()
    state.tank, state.status = true, state.secret
    local frame = newFrame()
    for _, expected in ipairs({ { 1, 1, 1, 0 }, { 2, 1, 0.6, 0 }, { 3, 1, 0, 0 } }) do
        state.leadStatus = expected[1]
        state.update(frame)
        assertColor(state.textures[1], expected[2], expected[3], expected[4])
    end
end)

test("the co-tank color follows actual aggro on each enemy during a raid tank swap", function()
    state.party, state.tank, state.raidIndex = false, true, 2
    state.raidRoles = { "DAMAGER", "TANK", "TANK" }
    state.raidThreat.nameplate1 = { raid3 = 2 }
    state.unitThreatLead = { nameplate1 = 1, nameplate2 = 0 }
    state.unitThreat = { nameplate1 = 1, nameplate2 = 3 }
    local boss = newFrame("nameplate1")
    local add = newFrame("nameplate2")
    state.update(boss)
    state.update(add)
    local bossColor, addColor = state.textures[1], state.textures[2]
    assertColor(bossColor, 0x3b / 255, 0x82 / 255, 0xf6 / 255)
    assertColor(addColor, 0, 1, 0)

    state.unitThreat.nameplate1, state.unitThreatLead.nameplate1 = 2, 2
    state.update(boss)
    assertColor(bossColor, 1, 0.6, 0)
    state.unitThreat.nameplate1, state.unitThreatLead.nameplate1 = 3, 0
    state.raidThreat.nameplate1.raid3 = 1
    state.update(boss)
    assertColor(bossColor, 0, 1, 0)
end)

test("the co-tank must be assigned Tank and holding aggro, not just on the threat list", function()
    state.tank, state.raidIndex, state.status = true, 1, nil
    state.raidRoles = { "TANK", "DAMAGER", "TANK" }
    local frame = newFrame()
    local threats = { raid2 = 3, raid3 = 1 }
    state.raidThreat.nameplate1 = threats
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)

    threats.raid2, threats.raid3, state.leadStatus = 1, 3, nil
    state.update(frame)
    assertColor(state.textures[1], 0x3b / 255, 0x82 / 255, 0xf6 / 255)
end)

test("a raid main tank assignment also qualifies as a co-tank", function()
    state.party, state.tank, state.raidIndex, state.status = false, true, 1, 0
    state.raidRoles = { "NONE", "NONE" }
    state.raidMainTanks = { [2] = true }
    state.raidThreat.nameplate1 = { raid2 = 3 }
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 0x3b / 255, 0x82 / 255, 0xf6 / 255)

    state.secretChecked, state.raidMainTanks[2] = false, state.secret
    state.events.GROUP_ROSTER_UPDATE()
    assert(state.secretChecked)
    assertColor(state.textures[1], 1, 0, 0)
end)

test("raid co-tank roles are cached until roster or role events fire", function()
    state.party, state.tank, state.raidIndex, state.status = false, true, 1, 0
    state.raidRoles = { "TANK", "DAMAGER", "DAMAGER", "TANK" }
    state.raidThreat.nameplate1 = { raid4 = 3 }
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 0x3b / 255, 0x82 / 255, 0xf6 / 255)
    assert(state.roleChecks == 3)

    state.update(frame)
    state.update(frame)
    assert(state.roleChecks == 3)

    state.raidRoles[4] = "DAMAGER"
    state.events.PLAYER_ROLES_ASSIGNED()
    assert(state.roleChecks == 6)
    assertColor(state.textures[1], 1, 0, 0)
end)

test("non-tank raid fallback checks raid tanks before scanning other members", function()
    state.party, state.partyMembers = false, 0
    state.raidIndex = 1
    state.raidRoles = { "DAMAGER", "DAMAGER", "DAMAGER", "DAMAGER", "TANK" }
    state.status, state.combat = nil, true
    state.raidThreat.nameplate1 = { raid5 = 3 }
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 0, 1, 0)
    assert(state.unitThreatChecks == 1)
end)

test("secure tanks in a raid query their own threat once per update", function()
    state.party, state.tank, state.raidIndex = false, true, 1
    state.raidRoles = { "TANK", "TANK" }
    state.status, state.leadStatus = 3, 0
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 0, 1, 0)
    assert(state.playerThreatChecks == 1)
end)

test("enemy players skip threat scans and secret player checks hide overlays", function()
    local frame = newFrame()
    state.combat = true
    state.partyThreat.nameplate1 = { party1 = 3 }
    state.isPlayer = true
    state.update(frame)
    assert(#state.textures == 0 and state.playerThreatChecks == 0 and state.unitThreatChecks == 0)

    state.isPlayer = false
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)

    state.secretChecked, state.isPlayer = false, state.secret
    state.update(frame)
    assert(state.secretChecked and not state.textures[1].shown)
end)

test("frames without threat health bar coloring exit before inspecting unit tokens", function()
    local frame = setmetatable({}, {
        __index = function(_, key)
            if key == "IsForbidden" then
                return function()
                    return false
                end
            end
            assert(key == "displayThreatHealthBarColor", "Inspected " .. tostring(key))
            return nil
        end,
    })
    state.update(frame)
    assert(#state.textures == 0)
end)

test("secret raid, role or threat data does not confirm co-tank aggro", function()
    state.tank, state.raidIndex, state.status = true, 1, 0
    state.raidRoles = { "TANK", "TANK" }
    state.raidThreat.nameplate1 = { raid2 = 3 }
    local frame = newFrame()
    for _, case in ipairs({
        { state, "raidIndex" },
        { state, "status" },
        { state.raidRoles, 2 },
        { state.raidThreat.nameplate1, "raid2" },
    }) do
        local source, key = case[1], case[2]
        local original = source[key]
        state.secretChecked, source[key] = false, state.secret
        state.update(frame)
        assert(state.secretChecked)
        assertColor(state.textures[1], 1, 0, 0)
        source[key] = original
    end
end)

test("raid role and roster changes refresh nameplates even without a threat update", function()
    state.party, state.tank, state.raidIndex = false, true, 1
    state.status, state.leadStatus = nil, nil
    state.raidRoles = { "TANK", "DAMAGER" }
    state.raidThreat.nameplate1 = { raid2 = 3 }
    state.update(newFrame())
    assert(#state.textures == 0)

    state.raidRoles[2] = "TANK"
    state.events.PLAYER_ROLES_ASSIGNED()
    assertColor(state.textures[1], 0x3b / 255, 0x82 / 255, 0xf6 / 255)

    state.raidIndex = nil
    state.events.GROUP_ROSTER_UPDATE()
    assert(not state.textures[1].shown)
end)

test("automatic role refreshes on stance, spec and player aura changes", function()
    state.status, state.leadStatus = 2, 0
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 1, 0.6, 0)

    state.tank = true
    state.events.UPDATE_SHAPESHIFT_FORM()
    assertColor(state.textures[1], 0, 1, 0)

    state.tank = false
    state.events.ACTIVE_PLAYER_SPECIALIZATION_CHANGED()
    assertColor(state.textures[1], 1, 0.6, 0)

    state.tank = true
    state.events.UNIT_AURA("player")
    assertColor(state.textures[1], 0, 1, 0)

    -- Unrelated player aura updates while role is unchanged do not refresh overlays.
    state.leadStatus = 3
    state.events.UNIT_AURA("player")
    assertColor(state.textures[1], 0, 1, 0)

    -- Locked roles ignore automatic stance/aura/spec transitions.
    state.addon.ApplyRoleLock("nontank")
    assertColor(state.textures[1], 1, 0.6, 0)
    state.status = 3
    state.tank = false
    state.events.UPDATE_SHAPESHIFT_FORM()
    state.events.UNIT_AURA("player")
    assertColor(state.textures[1], 1, 0.6, 0)
end)

test("safe, transitioning, and dangerous states use the same palette for both roles", function()
    local states = {
        { 0, 0, 1, 0 },
        { 1, 1, 1, 0 },
        { 2, 1, 0.6, 0 },
        { 3, 1, 0, 0 },
        { 0, 0, 1, 0 },
    }
    for _, role in ipairs({ false, true }) do
        state.tank = role
        local frame = newFrame()
        for _, expected in ipairs(states) do
            state.status = role and 3 or expected[1]
            state.leadStatus = expected[1]
            state.update(frame)
            assertColor(state.textures[#state.textures], expected[2], expected[3], expected[4])
        end
    end
    assert(#state.textures == 2)
end)

test("unknown threat hides a previous overlay", function()
    local frame = newFrame()
    state.update(frame)
    state.status = 4
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("secret threat hides a previous overlay", function()
    local frame = newFrame()
    state.update(frame)
    state.status = state.secret
    state.update(frame)
    assert(state.secretChecked and not state.textures[1].shown)
end)

test("leaving the party restores the native fill", function()
    local frame = newFrame()
    state.update(frame)
    state.party = false
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("a nameplate reused for a friendly unit loses its custom color", function()
    local frame = newFrame()
    state.update(frame)
    state.enemy = false
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("clearing a unit hides its previous custom color", function()
    local frame, native = newFrame()
    state.update(frame)
    native.displayedUnit = nil
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("scripted preview frames are ignored", function()
    state.update(newFrame("nameplate-preview"))
    assert(#state.textures == 0)
end)

test("missing or mismatched nameplate ownership is ignored", function()
    local frame = newFrame()
    state.nameplates.nameplate1 = nil
    state.update(frame)
    state.nameplates.nameplate1 = { UnitFrame = {} }
    state.update(frame)
    assert(#state.textures == 0)
end)

test("forbidden frames are not inspected", function()
    local frame = setmetatable({}, {
        __index = function(_, key)
            assert(key == "IsForbidden", "Forbidden frame fields were inspected")
            return function()
                return true
            end
        end,
    })
    state.update(frame)
end)

test("a secret unit token hides its overlay without reaching game APIs", function()
    local frame, native = newFrame()
    state.update(frame)
    assert(state.textures[1].shown)
    state.secret = native.displayedUnit
    state.update(frame)
    assert(state.secretChecked and not state.textures[1].shown)
end)

for _, field in ipairs({ "display flag", "enemy check" }) do
    test("a secret " .. field .. " sentinel hides its overlay", function()
        local frame, native = newFrame()
        state.update(frame)
        assert(state.textures[1].shown)
        if field == "display flag" then
            native.displayThreatHealthBarColor = state.secret
        else
            state.enemy = state.secret
        end
        state.update(frame)
        assert(state.secretChecked and not state.textures[1].shown)
    end)
end

test("different nameplates have independent overlays", function()
    local first = newFrame("nameplate1")
    local second = newFrame("nameplate2")
    state.update(first)
    state.status = 1
    state.update(second)
    assert(#state.textures == 2 and state.textures[1].shown and state.textures[2].shown)
    assert(state.textures[1].color[2] == 0 and state.textures[2].color[2] == 1)
    state.status = nil
    state.update(first)
    assert(not state.textures[1].shown and state.textures[2].shown)
end)
