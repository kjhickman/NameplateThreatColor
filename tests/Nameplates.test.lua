local helpers = ...
local state = helpers.state
local test = helpers.test
local newFrame = helpers.newFrame
local assertColor = helpers.assertColor

test("applying a supplied palette refreshes overlays without changing saved settings", function()
    local states = {
        { 0, 0, 0, 1 },
        { 1, 1, 0, 1 },
        { 2, 1, 0, 1 },
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
        highThreatColor = "ff00ffff",
    })
    for index, expected in ipairs(states) do
        assertColor(state.textures[index], expected[2], expected[3], expected[4])
    end
    assert(#state.textures == 4)
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
    assert(NameplateThreatColorDB.warningColor == "ffffff00")
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
    assert(state.textures[1].anchor == frame.healthBar:GetStatusBarTexture())
    assert(state.threatQuery == "normal")
end)

test("both warning states are yellow and reuse the overlay", function()
    local frame = newFrame()
    for _, warning in ipairs({ 1, 2 }) do
        state.status = warning
        state.update(frame)
        local color = state.textures[1].color
        assert(state.textures[1].shown and color[1] == 1 and color[2] == 1 and color[3] == 0)
        assert(#state.textures == 1)
    end
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
        { 2, 1, 1, 0 },
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

test("nil threat hides a previous overlay", function()
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
    state.threatQuery = nil
    state.update(frame)
    assert(not state.textures[1].shown and state.threatQuery == nil)
end)

test("leaving the party restores the native fill", function()
    local frame = newFrame()
    state.update(frame)
    state.party, state.threatQuery = false, nil
    state.update(frame)
    assert(not state.textures[1].shown and state.threatQuery == nil)
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
