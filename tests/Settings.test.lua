local helpers = ...
local state = helpers.state
local test = helpers.test
local newFrame = helpers.newFrame
local assertColor = helpers.assertColor

local function promptControl(label)
    for _, child in ipairs(state.prompt.children) do
        if child.text == label or (child.Text and child.Text.text == label) then
            return child
        end
    end
    error("Prompt has no control labeled " .. label, 2)
end

test("canvas settings expose four color swatches with persisted defaults", function()
    assert(
        state.category.name == "NameplateThreatColor" and state.registeredCategory == state.category
    )
    local warning = state.settings.NameplateThreatColor_warningColor
    local urgent = state.settings.NameplateThreatColor_urgentWarningColor
    local high = state.settings.NameplateThreatColor_highThreatColor
    local secure = state.settings.NameplateThreatColor_secureAggroColor
    assert(warning.swatch and urgent.swatch and high.swatch and secure.swatch)
    assert(secure.label == "Secure aggro color")
    assert(warning.label == "Threat warning color")
    assert(urgent.label == "Urgent threat warning color")
    assert(high.label == "Pulled / lost aggro color")
    assert(warning:GetValue() == "ffffff00" and high:GetValue() == "ffff0000")
    assert(urgent:GetValue() == "ffff9900")
    assert(secure:GetValue() == "ff00ff00")
    assert(NameplateThreatColorDB.warningColor == "ffffff00")
    assert(NameplateThreatColorDB.urgentWarningColor == "ffff9900")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
    local count = 0
    for _ in pairs(state.settings) do
        count = count + 1
    end
    assert(count == 10)
    assert(not state.settings.NameplateThreatColor_roleLock.swatch)
    assert(not state.settings.NameplateThreatColor_separateTankColors.swatch)
end)

test("the four tank color swatches mirror the shared defaults", function()
    local expected = {
        { "tankSecureAggroColor", "Tank secure aggro color", "ff00ff00" },
        { "tankWarningColor", "Tank threat warning color", "ffffff00" },
        { "tankUrgentWarningColor", "Tank urgent threat warning color", "ffff9900" },
        { "tankHighThreatColor", "Tank lost aggro color", "ffff0000" },
    }
    for _, case in ipairs(expected) do
        local setting = state.settings["NameplateThreatColor_" .. case[1]]
        assert(setting.swatch and setting.label == case[2])
        assert(setting:GetValue() == case[3] and setting.default == case[3])
        assert(NameplateThreatColorDB[case[1]] == case[3])
    end
end)

test("the role setting offers automatic, tank and non-tank with automatic saved", function()
    local setting = state.settings.NameplateThreatColor_roleLock
    assert(setting.label == "Role" and setting.default == "auto")
    assert(setting:GetValue() == "auto" and NameplateThreatColorCharDB.roleLock == "auto")
    assert(NameplateThreatColorDB.roleLock == nil)
    local expected = {
        { "auto", "Automatic" },
        { "tank", "Tank" },
        { "nontank", "Non-tank" },
    }
    assert(#setting.options == #expected)
    for index, option in ipairs(expected) do
        assert(setting.options[index].value == option[1])
        assert(setting.options[index].label == option[2])
    end
end)

test("a single requirements note appears above the role and color settings", function()
    local panel = state.category.frame
    local notes = {}
    for _, frame in ipairs(state.uiFrames) do
        local initializer = frame.initializer
        if initializer and initializer.template == "SettingsListSectionHeaderTemplate" then
            notes[#notes + 1] = initializer
        end
    end
    assert(#notes == 1)
    assert(
        notes[1].data.name
            == "Requires being in a party and Nameplates > Aggro Display > Health Bar Color enabled."
    )
    local keys = {
        "roleLock",
        "secureAggroColor",
        "warningColor",
        "urgentWarningColor",
        "highThreatColor",
        "separateTankColors",
        "tankSecureAggroColor",
        "tankWarningColor",
        "tankUrgentWarningColor",
        "tankHighThreatColor",
    }
    for _, key in ipairs(keys) do
        local setting = state.settings["NameplateThreatColor_" .. key]
        local control = setting.control
        assert(control:GetElementData().data.setting == setting)
        assert(control.parent == panel or control.parent.parent == panel)
        assert(control:GetNarrationIndexString() == nil)
        assert(not setting.tooltip:find("Requires", 1, true))
        assert(not setting.tooltip:find("Nameplates >", 1, true))
    end
end)

for _, role in ipairs({ false, true }) do
    local label = role and "tank" or "non-tank"
    for _, case in ipairs({
        { "secureAggroColor", 0 },
        { "warningColor", 1 },
        { "urgentWarningColor", 2 },
        { "highThreatColor", 3 },
    }) do
        local key, status = case[1], case[2]
        test(key .. " independently refreshes " .. label .. " overlays", function()
            state.tank = role
            local defaults = {
                { 0, 1, 0 },
                { 1, 1, 0 },
                { 1, 0.6, 0 },
                { 1, 0, 0 },
            }
            for index, color in ipairs(defaults) do
                local unit = "nameplate" .. index
                if role then
                    state.unitThreatLead[unit] = index - 1
                else
                    state.unitThreat[unit] = index - 1
                end
                state.update(newFrame(unit))
                assertColor(state.textures[index], color[1], color[2], color[3])
            end
            local setting = state.settings["NameplateThreatColor_" .. key]
            setting:SetValue("ff0000ff")
            for index, color in ipairs(defaults) do
                if index == status + 1 then
                    assertColor(state.textures[index], 0, 0, 1)
                else
                    assertColor(state.textures[index], color[1], color[2], color[3])
                end
            end
            assert(NameplateThreatColorDB[key] == "ff0000ff")
            assert(setting:GetValue() == "ff0000ff")
            setting:SetValue(setting.default)
            for index, color in ipairs(defaults) do
                assertColor(state.textures[index], color[1], color[2], color[3])
            end
            assert(NameplateThreatColorDB[key] == setting.default)
            assert(setting:GetValue() == setting.default and #state.textures == 4)
        end)
    end
end

test("locking the tank role recolors live overlays and persists the choice", function()
    state.status, state.leadStatus = 2, 0
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 1, 0.6, 0)
    local setting = state.settings.NameplateThreatColor_roleLock
    setting:SetValue("tank")
    assertColor(state.textures[1], 0, 1, 0)
    assert(setting:GetValue() == "tank" and NameplateThreatColorCharDB.roleLock == "tank")
    setting:SetValue("auto")
    assertColor(state.textures[1], 1, 0.6, 0)
    assert(setting:GetValue() == "auto" and NameplateThreatColorCharDB.roleLock == "auto")
    assert(#state.textures == 1 and NameplateThreatColorDB.roleLock == nil)
end)

test("locking the non-tank role ignores a tank's threat lead", function()
    state.tank, state.status, state.leadStatus = true, 2, 3
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)
    state.settings.NameplateThreatColor_roleLock:SetValue("nontank")
    assertColor(state.textures[1], 1, 0.6, 0)
    assert(NameplateThreatColorCharDB.roleLock == "nontank")
end)

test("a saved role lock survives addon reinitialization", function()
    state.settings.NameplateThreatColor_roleLock:SetValue("tank")
    helpers.reloadAddon(nil, { roleLock = NameplateThreatColorCharDB.roleLock })
    assert(state.settings.NameplateThreatColor_roleLock:GetValue() == "tank")
    assert(NameplateThreatColorCharDB.roleLock == "tank")
    state.status, state.leadStatus = 2, 0
    state.update(newFrame())
    assertColor(state.textures[1], 0, 1, 0)
end)

test("unknown saved role locks fall back to automatic", function()
    for _, saved in ipairs({ false, true, 0, {}, "", "TANK", "healer", "nontank ", "non-tank" }) do
        helpers.reloadAddon(nil, { roleLock = saved })
        assert(NameplateThreatColorCharDB.roleLock == "auto")
        assert(state.settings.NameplateThreatColor_roleLock:GetValue() == "auto")
    end
    helpers.reloadAddon(nil, {})
    assert(NameplateThreatColorCharDB.roleLock == "auto")
end)

test("non-table saved character databases are replaced with defaults", function()
    for _, saved in ipairs({ false, true, 0, 12345678, "", "tank" }) do
        helpers.reloadAddon(nil, saved)
        assert(type(NameplateThreatColorCharDB) == "table")
        assert(NameplateThreatColorCharDB.roleLock == "auto")
        assert(state.settings.NameplateThreatColor_roleLock:GetValue() == "auto")
    end
end)

test("the role lock stays out of the account database", function()
    local account = {}
    helpers.reloadAddon(account, { roleLock = "tank" })
    state.settings.NameplateThreatColor_roleLock:SetValue("nontank")
    assert(NameplateThreatColorCharDB.roleLock == "nontank" and account.roleLock == nil)
    -- A second character keeps its own lock while sharing the account-wide colors.
    account.highThreatColor = "ff0000ff"
    helpers.reloadAddon(account, nil)
    assert(NameplateThreatColorCharDB.roleLock == "auto")
    assert(NameplateThreatColorDB == account and account.highThreatColor == "ff0000ff")
    state.update(newFrame())
    assertColor(state.textures[1], 0, 0, 1)
end)

test("saved colors survive addon reinitialization", function()
    state.settings.NameplateThreatColor_warningColor:SetValue("ff336699")
    state.settings.NameplateThreatColor_urgentWarningColor:SetValue("ffcc6633")
    state.settings.NameplateThreatColor_highThreatColor:SetValue("ff0000ff")
    state.settings.NameplateThreatColor_secureAggroColor:SetValue("ff996633")
    local saved = {
        warningColor = NameplateThreatColorDB.warningColor,
        urgentWarningColor = NameplateThreatColorDB.urgentWarningColor,
        highThreatColor = NameplateThreatColorDB.highThreatColor,
        secureAggroColor = NameplateThreatColorDB.secureAggroColor,
    }
    helpers.reloadAddon(saved)
    assert(state.settings.NameplateThreatColor_warningColor:GetValue() == "ff336699")
    assert(state.settings.NameplateThreatColor_urgentWarningColor:GetValue() == "ffcc6633")
    assert(state.settings.NameplateThreatColor_highThreatColor:GetValue() == "ff0000ff")
    assert(state.settings.NameplateThreatColor_secureAggroColor:GetValue() == "ff996633")
    local states = {
        { 0, 0x99 / 255, 0x66 / 255, 0x33 / 255 },
        { 1, 0x33 / 255, 0x66 / 255, 0x99 / 255 },
        { 2, 0xcc / 255, 0x66 / 255, 0x33 / 255 },
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
    assert(NameplateThreatColorDB.urgentWarningColor == "ffff9900")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
    assert(NameplateThreatColorCharDB.roleLock == "auto")
end)

test("non-table saved databases are replaced with defaults", function()
    for _, saved in ipairs({ false, true, 0, 12345678, "", "ff112233" }) do
        helpers.reloadAddon(saved)
        assert(type(NameplateThreatColorDB) == "table")
        assert(NameplateThreatColorDB.separateTankColors == false)
        assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
        assert(NameplateThreatColorDB.warningColor == "ffffff00")
        assert(NameplateThreatColorDB.urgentWarningColor == "ffff9900")
        assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
        assert(state.registeredCategory == state.category)
    end
end)

test("malformed saved colors are replaced without changing valid entries", function()
    local defaults = {
        secureAggroColor = "ff00ff00",
        warningColor = "ffffff00",
        urgentWarningColor = "ffff9900",
        highThreatColor = "ffff0000",
        tankSecureAggroColor = "ff00ff00",
        tankWarningColor = "ffffff00",
        tankUrgentWarningColor = "ffff9900",
        tankHighThreatColor = "ffff0000",
    }
    local valid = {
        secureAggroColor = "00112233",
        warningColor = "FF445566",
        urgentWarningColor = "00AaBbCc",
        highThreatColor = "aB778899",
        tankSecureAggroColor = "11223344",
        tankWarningColor = "FF556677",
        tankUrgentWarningColor = "00BbCcDd",
        tankHighThreatColor = "aB8899aa",
        separateTankColors = true,
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

test("tank swatches appear only while separate tank colors is enabled", function()
    local checkbox = state.settings.NameplateThreatColor_separateTankColors
    assert(checkbox.checkbox and checkbox.label == "Separate tank colors")
    assert(checkbox.default == false and checkbox:GetValue() == false)
    assert(NameplateThreatColorDB.separateTankColors == false)
    local shared = {
        "roleLock",
        "secureAggroColor",
        "warningColor",
        "urgentWarningColor",
        "highThreatColor",
        "separateTankColors",
    }
    local tankKeys = {
        "tankSecureAggroColor",
        "tankWarningColor",
        "tankUrgentWarningColor",
        "tankHighThreatColor",
    }
    for _, key in ipairs(shared) do
        assert(state.settings["NameplateThreatColor_" .. key].control:IsShown())
    end
    for _, key in ipairs(tankKeys) do
        assert(not state.settings["NameplateThreatColor_" .. key].control:IsShown())
    end
    checkbox:SetValue(true)
    for _, key in ipairs(shared) do
        assert(state.settings["NameplateThreatColor_" .. key].control:IsShown())
    end
    for _, key in ipairs(tankKeys) do
        assert(state.settings["NameplateThreatColor_" .. key].control:IsShown())
    end
    checkbox:SetValue(false)
    for _, key in ipairs(tankKeys) do
        assert(not state.settings["NameplateThreatColor_" .. key].control:IsShown())
    end
end)

test("saved separate tank colors show the tank section on initialization and refresh", function()
    helpers.reloadAddon({ separateTankColors = true })
    local control = state.settings.NameplateThreatColor_tankSecureAggroColor.control
    assert(control:IsShown())
    NameplateThreatColorDB.separateTankColors = false
    state.category.frame:OnRefresh()
    assert(not control:IsShown())
    NameplateThreatColorDB.separateTankColors = true
    state.category.frame:OnRefresh()
    assert(control:IsShown())
end)

test("non-boolean separate tank color flags fall back to off", function()
    for _, saved in ipairs({ 0, 1, "", "true", "false", {} }) do
        helpers.reloadAddon({ separateTankColors = saved })
        assert(NameplateThreatColorDB.separateTankColors == false)
        assert(state.settings.NameplateThreatColor_separateTankColors:GetValue() == false)
    end
end)

test("both roles share one palette while separate tank colors is off", function()
    state.settings.NameplateThreatColor_tankHighThreatColor:SetValue("ff0000ff")
    for index, role in ipairs({ false, true }) do
        state.tank = role
        state.update(newFrame("nameplate" .. index))
        assertColor(state.textures[index], 1, 0, 0)
    end
    assert(#state.textures == 2 and NameplateThreatColorDB.tankHighThreatColor == "ff0000ff")
end)

test("separate tank colors apply only while the role is tank", function()
    state.settings.NameplateThreatColor_tankHighThreatColor:SetValue("ff0000ff")
    state.settings.NameplateThreatColor_separateTankColors:SetValue(true)
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)
    state.tank = true
    state.update(frame)
    assertColor(state.textures[1], 0, 0, 1)
    state.tank = false
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)
    assert(#state.textures == 1)
end)

test("a locked role chooses the palette ahead of the live role", function()
    state.settings.NameplateThreatColor_tankHighThreatColor:SetValue("ff0000ff")
    state.settings.NameplateThreatColor_separateTankColors:SetValue(true)
    state.leadStatus = 3
    local frame = newFrame()
    state.settings.NameplateThreatColor_roleLock:SetValue("tank")
    state.update(frame)
    assertColor(state.textures[1], 0, 0, 1)
    state.tank = true
    state.settings.NameplateThreatColor_roleLock:SetValue("nontank")
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)
end)

test("toggling separate tank colors refreshes live overlays", function()
    state.tank = true
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 1, 0, 0)
    local tankHigh = state.settings.NameplateThreatColor_tankHighThreatColor
    tankHigh:SetValue("ff0000ff")
    assertColor(state.textures[1], 1, 0, 0)
    local checkbox = state.settings.NameplateThreatColor_separateTankColors
    checkbox:SetValue(true)
    assertColor(state.textures[1], 0, 0, 1)
    assert(checkbox:GetValue() == true and NameplateThreatColorDB.separateTankColors == true)
    tankHigh:SetValue("ff00ff00")
    assertColor(state.textures[1], 0, 1, 0)
    checkbox:SetValue(false)
    assertColor(state.textures[1], 1, 0, 0)
    assert(#state.textures == 1)
end)

test("each tank setting independently refreshes tank overlays", function()
    state.tank = true
    state.settings.NameplateThreatColor_separateTankColors:SetValue(true)
    local defaults = {
        { 0, 1, 0 },
        { 1, 1, 0 },
        { 1, 0.6, 0 },
        { 1, 0, 0 },
    }
    local keys = {
        "tankSecureAggroColor",
        "tankWarningColor",
        "tankUrgentWarningColor",
        "tankHighThreatColor",
    }
    for index, color in ipairs(defaults) do
        local unit = "nameplate" .. index
        state.unitThreatLead[unit] = index - 1
        state.update(newFrame(unit))
        assertColor(state.textures[index], color[1], color[2], color[3])
    end
    for status, key in ipairs(keys) do
        local setting = state.settings["NameplateThreatColor_" .. key]
        setting:SetValue("ff0000ff")
        for index, color in ipairs(defaults) do
            if index == status then
                assertColor(state.textures[index], 0, 0, 1)
            else
                assertColor(state.textures[index], color[1], color[2], color[3])
            end
        end
        setting:SetValue(setting.default)
        assertColor(
            state.textures[status],
            defaults[status][1],
            defaults[status][2],
            defaults[status][3]
        )
    end
    assert(#state.textures == 4)
end)

test("shared color changes leave separate tank colors alone", function()
    state.tank = true
    state.settings.NameplateThreatColor_separateTankColors:SetValue(true)
    state.settings.NameplateThreatColor_tankHighThreatColor:SetValue("ff0000ff")
    local frame = newFrame()
    state.update(frame)
    assertColor(state.textures[1], 0, 0, 1)
    state.settings.NameplateThreatColor_highThreatColor:SetValue("ff00ffff")
    assertColor(state.textures[1], 0, 0, 1)
    state.tank = false
    state.update(frame)
    assertColor(state.textures[1], 0, 1, 1)
end)

test("saved tank colors survive addon reinitialization", function()
    state.settings.NameplateThreatColor_separateTankColors:SetValue(true)
    state.settings.NameplateThreatColor_tankHighThreatColor:SetValue("ff0000ff")
    helpers.reloadAddon({
        separateTankColors = NameplateThreatColorDB.separateTankColors,
        tankHighThreatColor = NameplateThreatColorDB.tankHighThreatColor,
    })
    assert(NameplateThreatColorDB.separateTankColors == true)
    assert(state.settings.NameplateThreatColor_separateTankColors:GetValue() == true)
    assert(state.settings.NameplateThreatColor_tankHighThreatColor:GetValue() == "ff0000ff")
    assert(state.settings.NameplateThreatColor_highThreatColor:GetValue() == "ffff0000")
    state.tank = true
    state.update(newFrame())
    assertColor(state.textures[1], 0, 0, 1)
end)

test("enabled or unavailable Health Bar Color CVar does not show a prompt", function()
    assert(state.prompt == nil and NameplateThreatColorDB.hideHealthBarColorPrompt == false)
    state.healthBarColorCVar = nil
    helpers.reloadAddon()
    assert(state.prompt == nil)
end)

test("disabled Health Bar Color waits for CVars to load before prompting", function()
    state.healthBarColorCVar, state.variablesLoaded = false, false
    helpers.reloadAddon()
    assert(state.prompt == nil and state.onVariablesLoaded)
    state.onVariablesLoaded()
    assert(state.prompt and state.prompt:IsShown())
    assert(
        state.prompt.fontString.text:find("Nameplates > Aggro Display > Health Bar Color", 1, true)
    )
    assert(not promptControl("Don't show this again"):GetChecked())
    assert(promptControl("Enable") and promptControl("Dismiss"))
end)

test("enabling from the prompt turns Health Bar Color on and hides the dialog", function()
    state.healthBarColorCVar = false
    helpers.reloadAddon()
    promptControl("Enable"):Click()
    assert(state.healthBarColorCVar == true)
    assert(not state.prompt:IsShown())
    assert(NameplateThreatColorDB.hideHealthBarColorPrompt == false)
end)

test("dismissing without checking don't show again prompts again on reload", function()
    state.healthBarColorCVar = false
    helpers.reloadAddon()
    promptControl("Dismiss"):Click()
    assert(state.healthBarColorCVar == false and not state.prompt:IsShown())
    assert(NameplateThreatColorDB.hideHealthBarColorPrompt == false)
    helpers.reloadAddon(NameplateThreatColorDB)
    assert(state.prompt and state.prompt:IsShown())
end)

test("checking don't show again persists across dismiss and enable", function()
    for _, enable in ipairs({ false, true }) do
        state.healthBarColorCVar = false
        helpers.reloadAddon()
        promptControl("Don't show this again"):SetChecked(true)
        promptControl(enable and "Enable" or "Dismiss"):Click()
        assert(state.healthBarColorCVar == enable)
        assert(NameplateThreatColorDB.hideHealthBarColorPrompt == true)
        state.healthBarColorCVar = false
        helpers.reloadAddon(NameplateThreatColorDB)
        assert(state.prompt == nil)
    end
end)

test("non-boolean saved prompt suppression flags fall back to showing", function()
    state.healthBarColorCVar = false
    for _, saved in ipairs({ 0, 1, "", "true", "false", {} }) do
        helpers.reloadAddon({ hideHealthBarColorPrompt = saved })
        assert(NameplateThreatColorDB.hideHealthBarColorPrompt == false)
        assert(state.prompt and state.prompt:IsShown())
    end
end)
