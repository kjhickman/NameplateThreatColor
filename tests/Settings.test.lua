local helpers = ...
local state = helpers.state
local test = helpers.test
local newFrame = helpers.newFrame

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

test("the secure picker updates either role immediately without changing warnings", function()
    for _, role in ipairs({ false, true }) do
        state.tank = role
        local safe = newFrame("nameplate1")
        local warning = newFrame("nameplate2")
        local danger = newFrame("nameplate3")
        state.unitThreat = { nameplate1 = 0, nameplate2 = 1, nameplate3 = 3 }
        state.update(safe)
        state.update(warning)
        state.update(danger)
        state.settings.NameplateThreatColor_secureAggroColor:SetValue("ff0000ff")
        local color = state.textures[#state.textures - 2].color
        assert(color[1] == 0 and color[2] == 0 and color[3] == 1)
        color = state.textures[#state.textures - 1].color
        assert(color[1] == 1 and color[2] == 1 and color[3] == 0)
        color = state.textures[#state.textures].color
        assert(color[1] == 1 and color[2] == 0 and color[3] == 0)
    end
    assert(NameplateThreatColorDB.secureAggroColor == "ff0000ff")
end)

test("restoring the secure picker value restores the live green fill", function()
    state.tank, state.status = true, 0
    local frame = newFrame()
    state.update(frame)
    local setting = state.settings.NameplateThreatColor_secureAggroColor
    local previous = setting:GetValue()
    setting:SetValue("ff0000ff")
    setting:SetValue(previous)
    local color = state.textures[1].color
    assert(state.textures[1].shown and color[1] == 0 and color[2] == 1 and color[3] == 0)
    assert(NameplateThreatColorDB.secureAggroColor == previous)
end)

test("restoring a picker value on Cancel restores the live color", function()
    local frame = newFrame()
    state.update(frame)
    local setting = state.settings.NameplateThreatColor_highThreatColor
    local previous = setting:GetValue()
    setting:SetValue("ff0000ff")
    setting:SetValue(previous)
    local color = state.textures[1].color
    assert(state.textures[1].shown and color[1] == 1 and color[2] == 0 and color[3] == 0)
    assert(NameplateThreatColorDB.highThreatColor == previous)
end)

test("Cancel after reopening restores the previously accepted color", function()
    local frame = newFrame()
    state.update(frame)
    local setting = state.settings.NameplateThreatColor_highThreatColor
    setting:SetValue("ff0000ff")
    local previous = setting:GetValue()
    setting:SetValue("ff00ff00")
    setting:SetValue(previous)
    local color = state.textures[1].color
    assert(state.textures[1].shown and color[1] == 0 and color[2] == 0 and color[3] == 1)
    assert(NameplateThreatColorDB.highThreatColor == "ff0000ff")
end)

test("native setting defaults restore all three colors immediately", function()
    local frame = newFrame()
    state.update(frame)
    local warning = state.settings.NameplateThreatColor_warningColor
    local high = state.settings.NameplateThreatColor_highThreatColor
    local secure = state.settings.NameplateThreatColor_secureAggroColor
    warning:SetValue("ff00ff00")
    high:SetValue("ff0000ff")
    secure:SetValue("ff0000ff")
    warning:SetValue(warning.default)
    high:SetValue(high.default)
    secure:SetValue(secure.default)
    assert(NameplateThreatColorDB.warningColor == "ffffff00")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
    assert(
        state.textures[1].shown
            and state.textures[1].color[1] == 1
            and state.textures[1].color[3] == 0
    )
end)

test("settings changes leave secret threat values on the native fill", function()
    local frame = newFrame()
    state.update(frame)
    state.status = state.secret
    state.settings.NameplateThreatColor_highThreatColor:SetValue("ff0000ff")
    assert(state.secretChecked and not state.textures[1].shown)
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
    state.status = 1
    state.update(newFrame())
    local color = state.textures[1].color
    assert(color[1] == 0x33 / 255 and color[2] == 0x66 / 255 and color[3] == 0x99 / 255)
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
