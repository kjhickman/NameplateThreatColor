local helpers = ...
local state = helpers.state
local test = helpers.test
local newFrame = helpers.newFrame
local assertColor = helpers.assertColor

test("applying a supplied palette refreshes overlays without changing saved settings", function()
    local states = {
        { 0, 0, 0, 1 },
        { 1, 1, 0, 1 },
        { 2, 1, 1, 1 },
        { 3, 0, 1, 1 },
    }
    for index, expected in ipairs(states) do
        local unit = "nameplate" .. index
        state.unitThreat[unit] = expected[1]
        state.update(newFrame(unit))
    end
    state.addon.ApplyColors({
        secureAggroColor = "ff0000ff",
        warningColor = "ffff00ff",
        urgentWarningColor = "ffffffff",
        highThreatColor = "ff00ffff",
    })
    for index, expected in ipairs(states) do
        assertColor(state.textures[index], expected[2], expected[3], expected[4])
    end
    assert(#state.textures == 4)
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
    assert(NameplateThreatColorDB.warningColor == "ffffff00")
    assert(NameplateThreatColorDB.urgentWarningColor == "ffff9900")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
end)

test("party frames are not queried or given overlays", function()
    state.update(newFrame("player"))
    assert(#state.textures == 0 and state.threatQuery == nil)
end)

test("highest threat is red without changing Blizzard's bar", function()
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)
    local overlay = state.textures[1].owner
    assert(overlay.anchor == frame.healthBar and state.textures[1].anchor == overlay)
    assert(state.threatQuery == "normal")
end)

test("custom threat colors draw above Blizzard's health-bar fill", function()
    local frame = newFrame()
    state.update(frame)
    local layer, sublevel = frame.healthBar:GetStatusBarTexture():GetDrawLayer()
    local texture = state.textures[1]
    assert(texture.layer == layer and texture.sublevel > sublevel)
    assert(texture.owner.level == frame.healthBar:GetFrameLevel())
end)

test("the overlay reuses Blizzard's atlas and tints it without flattening it", function()
    local frame = newFrame()
    local fill = frame.healthBar:GetStatusBarTexture()
    state.update(frame)
    local texture = state.textures[1]
    assert(texture.atlas == fill:GetAtlas() and texture.file == nil)
    assertColor(texture, 1, 0, 0)
    state.status = 1
    state.update(frame)
    assertColor(texture, 1, 1, 0)
    assert(texture.atlas == fill:GetAtlas() and texture.atlasCalls == 1)
end)

test("classic-style overlays reuse Blizzard's texture file", function()
    local frame = newFrame()
    local fill = frame.healthBar:GetStatusBarTexture()
    fill.atlas = nil
    state.update(frame)
    local texture = state.textures[1]
    assert(texture.file == fill:GetTexture() and texture.atlas == nil)
    assert(texture.textureCalls == 1 and texture.atlasCalls == 0)
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
        assert(texture.colorCalls == 1 and texture.showCalls == 1 and texture.hideCalls == 0)
    end
end)

test("secret native health is forwarded without inspection or calculation", function()
    local frame = newFrame()
    frame.healthBar.maximum, frame.healthBar.value = state.secret, state.secret
    state.update(frame)
    local texture = state.textures[1]
    assert(texture.owner.maximum == state.secret and texture.owner.value == state.secret)
    assert(not state.secretChecked)
    assertColor(texture, 1, 0, 0)
end)

for _, role in ipairs({ false, true }) do
    local label = role and "tank" or "non-tank"
    test(label .. " warning states use yellow and orange while reusing the overlay", function()
        state.tank = role
        local frame = newFrame()
        local states = {
            { 1, 1, 1, 0 },
            { 2, 1, 0.6, 0 },
            { 1, 1, 1, 0 },
        }
        for _, expected in ipairs(states) do
            state.status = expected[1]
            state.update(frame)
            assertColor(state.textures[1], expected[2], expected[3], expected[4])
        end
        assert(#state.textures == 1)
        local texture = state.textures[1]
        assert(texture.colorCalls == 3 and texture.showCalls == 1 and texture.hideCalls == 0)
    end)
end

test("repeated updates across many nameplates avoid redundant texture calls", function()
    local frames = {}
    for index = 1, 40 do
        local unit = "nameplate" .. index
        state.unitThreat[unit] = index % 4
        frames[index] = newFrame(unit)
        state.update(frames[index])
    end
    for _ = 1, 100 do
        for _, frame in ipairs(frames) do
            state.update(frame)
        end
    end
    assert(#state.textures == 40)
    for _, texture in ipairs(state.textures) do
        assert(texture.shown and texture.colorCalls == 1)
        assert(texture.showCalls == 1 and texture.hideCalls == 0)
        assert(texture.atlasCalls + texture.textureCalls == 1)
    end
end)

test("changing threat recolors a visible overlay without hiding or showing it", function()
    local frame = newFrame()
    state.update(frame)
    state.status = 1
    state.update(frame)
    local texture = state.textures[1]
    assertColor(texture, 1, 1, 0)
    assert(texture.colorCalls == 2 and texture.showCalls == 1 and texture.hideCalls == 0)
end)

test("inactive overlays hide once and reuse their color when shown again", function()
    local frame = newFrame()
    state.update(frame)
    state.status = nil
    for _ = 1, 10 do
        state.update(frame)
    end
    local texture = state.textures[1]
    assert(not texture.shown and texture.hideCalls == 1)
    assert(texture.colorCalls == 1 and texture.showCalls == 1)
    state.status = 3
    state.update(frame)
    assertColor(texture, 1, 0, 0)
    assert(texture.colorCalls == 1 and texture.showCalls == 2 and texture.hideCalls == 1)
end)

test("palette changes while inactive are applied when the overlay returns", function()
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
    assert(not texture.shown and texture.hideCalls == 1)
    assert(texture.colorCalls == 1 and texture.showCalls == 1)
    native.displayThreatHealthBarColor = true
    state.update(frame)
    assertColor(texture, 0, 0, 1)
    assert(texture.colorCalls == 2 and texture.showCalls == 2 and texture.hideCalls == 1)
end)

test("tank recognition selects the threat-lead API", function()
    state.tank = true
    state.update(newFrame())
    assert(state.threatQuery == "tank" and state.textures[1].shown)
end)

test("a non-tank with safe low threat uses green without a tanking query", function()
    state.status = 0
    state.update(newFrame())
    local color = state.textures[1].color
    assert(state.textures[1].shown and color[1] == 0 and color[2] == 1 and color[3] == 0)
    assert(state.threatQuery == "normal" and state.tankingQuery == nil)
end)

test("a non-tank losing all threat turns green until the enemy leaves combat", function()
    state.combat = true
    state.partyThreat.nameplate1 = { party1 = 3 }
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)
    state.status = 2
    state.update(frame)
    assertColor(state.textures[1], 1, 0.6, 0)
    state.status = nil
    for _ = 1, 10 do
        state.update(frame)
    end
    local texture = state.textures[1]
    assertColor(texture, 0, 1, 0)
    assert(state.combatQuery == "nameplate1" and state.tankingQuery == nil)
    assert(texture.colorCalls == 3 and texture.showCalls == 1 and texture.hideCalls == 0)
    state.combat = false
    state.update(frame)
    assert(not texture.shown and texture.hideCalls == 1)
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
    assert(#state.partyThreatQueries == 16)
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

test("nil tank threat stays unchanged even while the enemy is in combat", function()
    state.tank, state.combat = true, true
    local frame = newFrame()
    state.update(frame)
    state.status = nil
    state.update(frame)
    assert(not state.textures[1].shown and state.combatQuery == nil)
end)

test("a secret combat state hides the no-threat color", function()
    local frame = newFrame()
    state.update(frame)
    state.status, state.combat = nil, state.secret
    state.update(frame)
    assert(state.secretChecked and not state.textures[1].shown)
end)

test("secure tanks use green only while actually holding aggro", function()
    state.tank, state.status = true, 0
    local frame = newFrame()
    state.update(frame)
    local color = state.textures[1].color
    assert(state.textures[1].shown and color[1] == 0 and color[2] == 1 and color[3] == 0)
    assert(state.threatQuery == "tank" and state.tankingQuery == "nameplate1")
    state.isTanking = false
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("a secret tanking sentinel is checked and hides the secure color", function()
    state.tank, state.status = true, 0
    local frame = newFrame()
    state.update(frame)
    state.isTanking = state.secret
    state.update(frame)
    assert(state.secretChecked and not state.textures[1].shown)
end)

test("missing tanking confirmation does not show the secure color", function()
    state.tank, state.status, state.isTanking = true, 0, nil
    state.update(newFrame())
    assert(#state.textures == 0 and state.tankingQuery == "nameplate1")
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
            state.status = expected[1]
            state.update(frame)
            local texture = state.textures[#state.textures]
            local color = texture.color
            assert(texture.shown)
            assert(color[1] == expected[2] and color[2] == expected[3] and color[3] == expected[4])
        end
    end
    assert(#state.textures == 2)
end)

for _, case in ipairs({ { "unknown", 4 }, { "secret", 0 } }) do
    test(case[1] .. " threat hides a previous overlay", function()
        state.combat = true
        local frame = newFrame()
        state.update(frame)
        assert(state.textures[1].shown)
        if case[1] == "secret" then
            state.secret = case[2]
            state.tank = true
        end
        state.status = case[2]
        state.update(frame)
        assert(not state.textures[1].shown and #state.textures == 1)
        if case[1] == "secret" then
            assert(state.secretChecked and state.tankingQuery == nil)
        end
    end)
end

test("nil threat on an idle enemy hides a previous overlay", function()
    local frame = newFrame()
    state.update(frame)
    state.status = nil
    state.update(frame)
    assert(not state.textures[1].shown)
end)

test("turning Health Bar Color off restores the native fill", function()
    local frame, native = newFrame()
    state.update(frame)
    native.displayThreatHealthBarColor = false
    state.threatQuery, state.nameplateQuery = nil, nil
    state.update(frame)
    assert(not state.textures[1].shown and state.threatQuery == nil)
    assert(state.nameplateQuery == nil)
end)

test("leaving the party restores the native fill", function()
    local frame = newFrame()
    state.update(frame)
    state.party, state.threatQuery = false, nil
    state.nameplateQuery = nil
    state.update(frame)
    assert(not state.textures[1].shown and state.threatQuery == nil)
    assert(state.nameplateQuery == nil)
end)

test("a nameplate reused for a friendly unit loses its custom color", function()
    local frame = newFrame()
    state.update(frame)
    state.enemy, state.threatQuery = false, nil
    state.update(frame)
    assert(not state.textures[1].shown and state.threatQuery == nil)
end)

test("a frame reused for a non-nameplate unit loses its custom color", function()
    local frame, native = newFrame()
    state.update(frame)
    native.displayedUnit = "party1"
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
    assert(#state.textures == 0 and state.threatQuery == nil)
end)

test("missing or mismatched nameplate ownership is ignored", function()
    local frame = newFrame()
    state.nameplates.nameplate1 = nil
    state.update(frame)
    state.nameplates.nameplate1 = { UnitFrame = {} }
    state.update(frame)
    assert(#state.textures == 0 and state.threatQuery == nil)
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
    assert(#state.textures == 0 and state.threatQuery == nil)
end)

test("a secret unit token hides its overlay without a nameplate or threat query", function()
    local frame, native = newFrame()
    state.update(frame)
    assert(state.textures[1].shown)
    state.secret = native.displayedUnit
    state.nameplateQuery, state.threatQuery = nil, nil
    state.update(frame)
    assert(state.secretChecked and not state.textures[1].shown)
    assert(state.nameplateQuery == nil and state.threatQuery == nil)
end)

for _, field in ipairs({ "display flag", "enemy check" }) do
    test("a secret " .. field .. " sentinel hides its overlay without a threat query", function()
        local frame, native = newFrame()
        state.update(frame)
        assert(state.textures[1].shown)
        if field == "display flag" then
            native.displayThreatHealthBarColor = state.secret
        else
            state.enemy = state.secret
        end
        state.threatQuery = nil
        state.update(frame)
        assert(state.secretChecked and not state.textures[1].shown and state.threatQuery == nil)
    end)
end

test("the overlay returns when Health Bar Color is enabled again", function()
    local frame, native = newFrame()
    state.update(frame)
    native.displayThreatHealthBarColor = false
    state.update(frame)
    native.displayThreatHealthBarColor = true
    state.update(frame)
    assert(state.textures[1].shown and #state.textures == 1)
end)

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
