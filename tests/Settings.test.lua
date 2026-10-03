local helpers = ...
local state = helpers.state
local test = helpers.test
local newFrame = helpers.newFrame
local assertColor = helpers.assertColor

test("native addon settings expose three color swatches with persisted defaults", function()
    assert(
        state.category.name == "NameplateThreatColor" and state.registeredCategory == state.category
    )
    local warning = state.settings.NameplateThreatColor_warningColor
    local high = state.settings.NameplateThreatColor_highThreatColor
    local secure = state.settings.NameplateThreatColor_secureAggroColor
    assert(warning.swatch and high.swatch and secure.swatch)
    assert(secure.label == "Secure aggro color")
    assert(warning.label == "Gaining / losing aggro color")
    assert(high.label == "Pulled / lost aggro color")
    assert(warning:GetValue() == "ffffff00" and high:GetValue() == "ffff0000")
    assert(secure:GetValue() == "ff00ff00")
    assert(NameplateThreatColorDB.warningColor == "ffffff00")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
    local count = 0
    for _ in pairs(state.settings) do
        count = count + 1
    end
    assert(count == 3)
end)

test("changing the warning setting updates both warning states immediately", function()
    local first = newFrame("nameplate1")
    local second = newFrame("nameplate2")
    local high = newFrame("nameplate3")
    state.unitThreat = { nameplate1 = 1, nameplate2 = 2, nameplate3 = 3 }
    state.update(first)
    state.update(second)
    state.update(high)
    state.settings.NameplateThreatColor_warningColor:SetValue("ff00ff00")
    for index = 1, 2 do
        local texture = state.textures[index]
        assert(texture.shown)
        assert(texture.color[1] == 0 and texture.color[2] == 1 and texture.color[3] == 0)
    end
    assert(
        state.textures[3].shown
            and state.textures[3].color[1] == 1
            and state.textures[3].color[2] == 0
    )
    assert(state.textures[3].color[3] == 0)
    assert(#state.textures == 3 and NameplateThreatColorDB.warningColor == "ff00ff00")
end)

test("changing the high-threat setting refreshes existing overlays", function()
    local frame = newFrame("nameplate1")
    local warning = newFrame("nameplate2")
    state.unitThreat = { nameplate1 = 3, nameplate2 = 1 }
    state.update(frame)
    state.update(warning)
    state.settings.NameplateThreatColor_highThreatColor:SetValue("ff0000ff")
    local color = state.textures[1].color
    assert(state.textures[1].shown and color[1] == 0 and color[2] == 0 and color[3] == 1)
    assert(#state.textures == 2 and NameplateThreatColorDB.highThreatColor == "ff0000ff")
    color = state.textures[2].color
    assert(state.textures[2].shown and color[1] == 1 and color[2] == 1 and color[3] == 0)
    assert(state.settings.NameplateThreatColor_warningColor:GetValue() == "ffffff00")
end)

for _, role in ipairs({ false, true }) do
    local label = role and "tank" or "non-tank"
    test("secure setting refreshes " .. label .. " overlays", function()
        state.tank = role
        local safe = newFrame("nameplate1")
        local warning = newFrame("nameplate2")
        local danger = newFrame("nameplate3")
        state.unitThreat = { nameplate1 = 0, nameplate2 = 1, nameplate3 = 3 }
        state.update(safe)
        state.update(warning)
        state.update(danger)
        assertColor(state.textures[1], 0, 1, 0)
        state.settings.NameplateThreatColor_secureAggroColor:SetValue("ff0000ff")
        assertColor(state.textures[1], 0, 0, 1)
        assertColor(state.textures[2], 1, 1, 0)
        assertColor(state.textures[3], 1, 0, 0)
        assert(#state.textures == 3)
        assert(state.settings.NameplateThreatColor_secureAggroColor:GetValue() == "ff0000ff")
        assert(NameplateThreatColorDB.secureAggroColor == "ff0000ff")
    end)
end

test("restoring the secure setting restores its live green color", function()
    state.tank, state.status = true, 0
    local frame = newFrame()
    state.update(frame)
    local setting = state.settings.NameplateThreatColor_secureAggroColor
    local previous = setting:GetValue()
    assert(previous == "ff00ff00")
    assertColor(state.textures[1], 0, 1, 0)
    setting:SetValue("ff0000ff")
    assertColor(state.textures[1], 0, 0, 1)
    assert(
        setting:GetValue() == "ff0000ff" and NameplateThreatColorDB.secureAggroColor == "ff0000ff"
    )
    setting:SetValue(previous)
    assertColor(state.textures[1], 0, 1, 0)
    assert(setting:GetValue() == previous and NameplateThreatColorDB.secureAggroColor == previous)
end)

test("restoring the high-threat setting restores its live red color", function()
    local frame = newFrame()
    state.update(frame)
    local setting = state.settings.NameplateThreatColor_highThreatColor
    local previous = setting:GetValue()
    assert(previous == "ffff0000")
    assertColor(state.textures[1], 1, 0, 0)
    setting:SetValue("ff0000ff")
    assertColor(state.textures[1], 0, 0, 1)
    assert(
        setting:GetValue() == "ff0000ff" and NameplateThreatColorDB.highThreatColor == "ff0000ff"
    )
    setting:SetValue(previous)
    assertColor(state.textures[1], 1, 0, 0)
    assert(setting:GetValue() == previous and NameplateThreatColorDB.highThreatColor == previous)
end)

test("restoring a previous non-default setting restores that live color", function()
    local frame = newFrame()
    state.update(frame)
    local setting = state.settings.NameplateThreatColor_highThreatColor
    setting:SetValue("ff0000ff")
    assertColor(state.textures[1], 0, 0, 1)
    assert(
        setting:GetValue() == "ff0000ff" and NameplateThreatColorDB.highThreatColor == "ff0000ff"
    )
    local previous = setting:GetValue()
    setting:SetValue("ff00ff00")
    assertColor(state.textures[1], 0, 1, 0)
    assert(
        setting:GetValue() == "ff00ff00" and NameplateThreatColorDB.highThreatColor == "ff00ff00"
    )
    setting:SetValue(previous)
    assertColor(state.textures[1], 0, 0, 1)
    assert(setting:GetValue() == previous and NameplateThreatColorDB.highThreatColor == previous)
end)

test("applying setting defaults restores every live threat color immediately", function()
    state.unitThreat = { nameplate1 = 0, nameplate2 = 1, nameplate3 = 2, nameplate4 = 3 }
    for index = 1, 4 do
        state.update(newFrame("nameplate" .. index))
    end
    local warning = state.settings.NameplateThreatColor_warningColor
    local high = state.settings.NameplateThreatColor_highThreatColor
    local secure = state.settings.NameplateThreatColor_secureAggroColor
    secure:SetValue("ff0000ff")
    warning:SetValue("ffff00ff")
    high:SetValue("ff00ffff")
    assertColor(state.textures[1], 0, 0, 1)
    assertColor(state.textures[2], 1, 0, 1)
    assertColor(state.textures[3], 1, 0, 1)
    assertColor(state.textures[4], 0, 1, 1)
    secure:SetValue(secure.default)
    assertColor(state.textures[1], 0, 1, 0)
    warning:SetValue(warning.default)
    assertColor(state.textures[2], 1, 1, 0)
    assertColor(state.textures[3], 1, 1, 0)
    high:SetValue(high.default)
    assertColor(state.textures[4], 1, 0, 0)
    assert(secure:GetValue() == "ff00ff00")
    assert(warning:GetValue() == "ffffff00")
    assert(high:GetValue() == "ffff0000")
    assert(NameplateThreatColorDB.warningColor == "ffffff00")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
    assert(#state.textures == 4)
end)

test("settings changes check a secret threat sentinel and hide its overlay", function()
    local frame = newFrame()
    state.update(frame)
    assert(state.textures[1].shown)
    state.secret, state.status, state.tank = 0, 0, true
    state.settings.NameplateThreatColor_highThreatColor:SetValue("ff0000ff")
    assert(state.secretChecked and not state.textures[1].shown and state.tankingQuery == nil)
end)

test("saved colors survive addon reinitialization", function()
    state.settings.NameplateThreatColor_warningColor:SetValue("ff336699")
    state.settings.NameplateThreatColor_highThreatColor:SetValue("ff0000ff")
    state.settings.NameplateThreatColor_secureAggroColor:SetValue("ff996633")
    local saved = {
        warningColor = NameplateThreatColorDB.warningColor,
        highThreatColor = NameplateThreatColorDB.highThreatColor,
        secureAggroColor = NameplateThreatColorDB.secureAggroColor,
    }
    helpers.reloadAddon(saved)
    assert(state.settings.NameplateThreatColor_warningColor:GetValue() == "ff336699")
    assert(state.settings.NameplateThreatColor_highThreatColor:GetValue() == "ff0000ff")
    assert(state.settings.NameplateThreatColor_secureAggroColor:GetValue() == "ff996633")
    local states = {
        { 0, 0x99 / 255, 0x66 / 255, 0x33 / 255 },
        { 1, 0x33 / 255, 0x66 / 255, 0x99 / 255 },
        { 2, 0x33 / 255, 0x66 / 255, 0x99 / 255 },
        { 3, 0, 0, 1 },
    }
    for index, expected in ipairs(states) do
        state.status = expected[1]
        state.update(newFrame("nameplate" .. index))
        assertColor(state.textures[index], expected[2], expected[3], expected[4])
    end
    assert(#state.textures == 4)
end)

test("missing saved colors get defaults without overwriting existing choices", function()
    helpers.reloadAddon({ warningColor = "ff00ff00" })
    assert(NameplateThreatColorDB.warningColor == "ff00ff00")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
end)

test("older saved palettes are preserved when the secure setting is added", function()
    helpers.reloadAddon({ warningColor = "ff00ffff", highThreatColor = "ffff00ff" })
    assert(NameplateThreatColorDB.warningColor == "ff00ffff")
    assert(NameplateThreatColorDB.highThreatColor == "ffff00ff")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
end)

test("non-table saved databases are replaced with defaults", function()
    for _, saved in ipairs({ false, true, 0, 12345678, "", "ff112233" }) do
        helpers.reloadAddon(saved)
        assert(type(NameplateThreatColorDB) == "table")
        assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
        assert(NameplateThreatColorDB.warningColor == "ffffff00")
        assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
        assert(state.registeredCategory == state.category)
    end
end)

test("malformed saved colors are replaced without changing valid entries", function()
    local defaults = {
        secureAggroColor = "ff00ff00",
        warningColor = "ffffff00",
        highThreatColor = "ffff0000",
    }
    local valid = {
        secureAggroColor = "00112233",
        warningColor = "FF445566",
        highThreatColor = "aB778899",
        unrelated = {},
    }
    local invalid = {
        false,
        true,
        12345678,
        {},
        "",
        "ff0000",
        "ff00000",
        "ff0000000",
        "gg000000",
        "ff00000g",
        "#ff00000",
        " ff00000",
        "ff00000\n",
    }
    for key, default in pairs(defaults) do
        for _, value in ipairs(invalid) do
            local saved = {}
            for savedKey, savedValue in pairs(valid) do
                saved[savedKey] = savedValue
            end
            saved[key] = value
            helpers.reloadAddon(saved)
            assert(NameplateThreatColorDB == saved)
            for savedKey, expected in pairs(valid) do
                assert(
                    NameplateThreatColorDB[savedKey] == (savedKey == key and default or expected)
                )
            end
            assert(state.settings["NameplateThreatColor_" .. key]:GetValue() == default)
            assert(state.registeredCategory == state.category)
        end
    end
end)
