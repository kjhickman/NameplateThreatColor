local helpers = {
    state = {},
    tests = 0,
}
local state = helpers.state

EventUtil = {
    ContinueOnAddOnLoaded = function(name, callback)
        assert(name == "NameplateThreatColor")
        state.initialize = callback
    end,
    ContinueOnVariablesLoaded = function(callback)
        if state.variablesLoaded then
            callback()
        else
            state.onVariablesLoaded = callback
        end
    end,
}

Enum = { NamePlateThreatDisplay = { HealthBarColor = 3 } }
UIParent = {
    IsShown = function()
        return true
    end,
}

C_CVar = {
    GetCVarBitfield = function(name, index)
        assert(
            name == "nameplateThreatDisplay" and index == Enum.NamePlateThreatDisplay.HealthBarColor
        )
        return state.healthBarColorCVar
    end,
    SetCVarBitfield = function(name, index, value)
        assert(
            name == "nameplateThreatDisplay" and index == Enum.NamePlateThreatDisplay.HealthBarColor
        )
        assert(type(value) == "boolean")
        state.healthBarColorCVar = value
        return true
    end,
}

function CreateColorFromHexString(hex)
    assert(type(hex) == "string" and #hex == 8)
    local r = tonumber(hex:sub(3, 4), 16) / 255
    local g = tonumber(hex:sub(5, 6), 16) / 255
    local b = tonumber(hex:sub(7, 8), 16) / 255
    return {
        GetRGB = function()
            return r, g, b
        end,
    }
end

Settings = { VarType = { Boolean = "boolean", String = "string" } }

function Settings.RegisterCanvasLayoutCategory(frame, name)
    state.category = { name = name, frame = frame }
    return state.category
end

function Settings.CreateElementInitializer(template, data)
    local initializer = { template = template, data = data }
    function initializer:GetTemplate()
        return self.template
    end
    function initializer:InitFrame(frame)
        assert(frame:GetElementData() == self)
        frame.initializer = self
        local setting = self.data.setting
        if setting then
            setting.control = frame
            setting.tooltip = self.data.tooltip
            setting.swatch = self.template == "SettingsColorSwatchControlTemplate"
            setting.checkbox = self.template == "SettingsCheckboxControlTemplate"
            if self.data.options then
                setting.options = self.data.options()
            end
        end
    end
    return initializer
end

function Settings.RegisterProxySetting(owner, variable, kind, label, default, getValue, setValue)
    assert(owner == state.category)
    assert(kind == Settings.VarType.String or kind == Settings.VarType.Boolean)
    assert(type(default) == kind, "Default value does not match the declared variable type")
    assert(not state.settings[variable], "Setting registered twice")
    local setting = { label = label, default = default }
    function setting:GetValue()
        return getValue()
    end
    function setting:SetValue(value)
        setValue(value)
    end
    state.settings[variable] = setting
    return setting
end

function Settings.CreateColorSwatchInitializer(setting, options, tooltip)
    return Settings.CreateElementInitializer("SettingsColorSwatchControlTemplate", {
        setting = setting,
        options = options,
        tooltip = tooltip,
    })
end

function Settings.CreateCheckboxInitializer(setting, options, tooltip)
    assert(setting.default == false or setting.default == true)
    return Settings.CreateElementInitializer("SettingsCheckboxControlTemplate", {
        setting = setting,
        options = options,
        tooltip = tooltip,
    })
end

function Settings.CreateControlTextContainer()
    local container = { data = {} }
    function container:Add(value, label)
        table.insert(self.data, { value = value, label = label })
    end
    function container:GetData()
        return self.data
    end
    return container
end

function Settings.CreateDropdownInitializer(setting, options, tooltip)
    return Settings.CreateElementInitializer("SettingsDropdownControlTemplate", {
        setting = setting,
        options = options,
        tooltip = tooltip,
    })
end

function Settings.RegisterAddOnCategory(owner)
    assert(owner == state.category)
    state.registeredCategory = owner
end

local function forbiddenWrite()
    error("Addon touched Blizzard-owned state", 2)
end

GAINING_THREAT_COLOR = { SetRGB = forbiddenWrite }
HIGH_THREAT_COLOR = { SetRGB = forbiddenWrite }

function hooksecurefunc(name, callback)
    assert(name == "CompactUnitFrame_UpdateHealthColor")
    assert(not state.update, "Hook installed more than once")
    state.update = callback
end

function issecretvalue(value)
    if value == state.secret then
        state.secretChecked = true
        return true
    end
    return false
end

C_NamePlate = {
    GetNamePlateForUnit = function(unit)
        state.nameplateQuery = unit
        assert(unit ~= state.secret, "Secret unit token passed into a game API")
        return state.nameplates[unit]
    end,
}

function UnitInParty(unit)
    assert(unit == "player")
    return state.party
end

function UnitCanAttack(player, unit)
    assert(player == "player" and state.nameplates[unit])
    return state.enemy
end

function UnitAffectingCombat(unit)
    assert(state.nameplates[unit])
    state.combatQuery = unit
    return state.combat
end

PlayerUtil = {
    IsPlayerEffectivelyTank = function()
        return state.tank
    end,
}

function GetNumSubgroupMembers()
    return state.partyMembers
end

function UnitThreatSituation(player, unit)
    assert(state.nameplates[unit])
    if player ~= "player" then
        assert(player:match("^party%d+$"))
        state.partyThreatQueries[#state.partyThreatQueries + 1] = { player, unit }
        local threats = state.partyThreat[unit]
        return threats and threats[player]
    end
    state.threatQuery = "normal"
    if state.unitThreat[unit] ~= nil then
        return state.unitThreat[unit]
    end
    return state.status
end

function UnitThreatLeadSituation(player, unit)
    assert(player == "player" and state.nameplates[unit])
    state.threatQuery = "tank"
    state.threatLeadQuery = unit
    if state.unitThreatLead[unit] ~= nil then
        return state.unitThreatLead[unit]
    end
    return state.leadStatus
end

function UnitDetailedThreatSituation(player, unit)
    assert(player == "player" and state.nameplates[unit])
    state.tankingQuery = unit
    return state.isTanking
end

local function noop() end

function CreateFrame(kind, name, parent, template)
    if kind == "Frame" or kind == "Button" or kind == "CheckButton" then
        assert(name == nil)
        local frame = {
            parent = parent,
            template = template,
            shown = true,
            children = {},
            scripts = {},
            SetPoint = noop,
            SetWidth = noop,
            SetHeight = noop,
            SetSize = noop,
            SetAllPoints = noop,
            SetFrameStrata = noop,
            SetToplevel = noop,
            EnableMouse = noop,
        }
        if parent and parent.children then
            table.insert(parent.children, frame)
        end
        function frame:SetShown(shown)
            self.shown = shown
        end
        function frame:Hide()
            self.shown = false
        end
        function frame:IsShown()
            return self.shown and (not self.parent or self.parent:IsShown())
        end
        function frame:CreateFontString()
            local text = {
                SetPoint = noop,
                SetWidth = noop,
                GetStringHeight = function()
                    return 0
                end,
            }
            function text:SetText(value)
                self.text = value
            end
            frame.fontString = text
            return text
        end
        function frame:SetText(value)
            self.text = value
        end
        function frame:SetScript(event, handler)
            self.scripts[event] = handler
        end
        function frame:Click()
            self.scripts.OnClick(self)
        end
        if kind == "CheckButton" then
            frame.checked = false
            frame.Text = {
                GetStringWidth = function()
                    return 0
                end,
                SetText = function(self, value)
                    self.text = value
                end,
            }
            function frame:SetChecked(checked)
                self.checked = checked and true or false
            end
            function frame:GetChecked()
                return self.checked
            end
        end
        if template == "SettingsListSectionHeaderTemplate" then
            frame.Title = { SetFontObject = noop, SetPoint = noop }
        end
        if parent == UIParent then
            state.prompt = frame
        end
        table.insert(state.uiFrames, frame)
        return frame
    end
    assert(kind == "StatusBar" and name == nil and parent)
    local bar = { parent = parent, CreateTexture = parent.CreateTexture }
    function bar:SetAllPoints(relativeTo)
        assert(relativeTo == parent, "Overlay bar must cover the full native bar")
        self.anchor = relativeTo
    end
    function bar:SetFrameLevel(level)
        self.level = level
    end
    function bar:SetStatusBarTexture(texture)
        assert(texture.owner == self, "Native textures must not be reparented")
        self.texture = texture
    end
    function bar:SetMinMaxValues(minimum, maximum)
        self.minimum, self.maximum = minimum, maximum
    end
    function bar:SetValue(value)
        self.value = value
    end
    function bar:SetStatusBarColor(...)
        self.texture:SetVertexColor(...)
    end
    function bar:Hide()
        self.texture:Hide()
    end
    function bar:Show()
        self.texture:Show()
    end
    return bar
end

function helpers.newFrame(unit)
    local fill = {
        GetWidth = forbiddenWrite,
        GetTexCoord = forbiddenWrite,
        atlas = "test-nameplate-bar",
        file = 12345,
    }
    function fill:GetDrawLayer()
        return "ARTWORK", 0
    end
    function fill:GetAtlas()
        return self.atlas
    end
    function fill:GetTexture()
        return self.file
    end
    local bar = {
        GetStatusBarColor = forbiddenWrite,
        SetStatusBarColor = forbiddenWrite,
        minimum = 0,
        maximum = 100,
        value = 100,
    }
    function bar:GetStatusBarTexture()
        return fill
    end
    function bar:GetFrameLevel()
        return 5
    end
    function bar:GetMinMaxValues()
        return self.minimum, self.maximum
    end
    function bar:GetValue()
        return self.value
    end
    function bar:CreateTexture(name, layer, template, sublevel)
        assert(name == nil and layer == "ARTWORK" and template == nil)
        local owner = self
        assert(owner.parent == bar, "Texture must belong to the addon-owned status bar")
        local registry = state.textures
        local function assertCurrentTest()
            assert(state.textures == registry, "Texture from a previous test was touched")
        end
        local texture = {
            colorCalls = 0,
            hideCalls = 0,
            showCalls = 0,
            layer = layer,
            sublevel = sublevel,
            atlasCalls = 0,
            textureCalls = 0,
            owner = owner,
            SetColorTexture = forbiddenWrite,
        }
        function texture:SetAllPoints(relativeTo)
            assertCurrentTest()
            assert(relativeTo == owner, "The status-bar renderer must manage the overlay fill")
            self.anchor = relativeTo
        end
        function texture:SetAtlas(atlas)
            assertCurrentTest()
            self.atlasCalls = self.atlasCalls + 1
            self.atlas, self.file = atlas, nil
        end
        function texture:SetTexture(file)
            assertCurrentTest()
            self.textureCalls = self.textureCalls + 1
            self.file, self.atlas = file, nil
        end
        function texture:SetVertexColor(r, g, b)
            assertCurrentTest()
            self.colorCalls = self.colorCalls + 1
            self.color = { r, g, b }
        end
        function texture:Hide()
            assertCurrentTest()
            self.hideCalls = self.hideCalls + 1
            self.shown = false
        end
        function texture:Show()
            assertCurrentTest()
            self.showCalls = self.showCalls + 1
            self.shown = true
        end
        state.textures[#state.textures + 1] = texture
        return texture
    end

    local native = {
        displayedUnit = unit or "nameplate1",
        displayThreatHealthBarColor = true,
        healthBar = bar,
        IsForbidden = function()
            return false
        end,
    }
    local frame = setmetatable({}, { __index = native, __newindex = forbiddenWrite })
    state.nameplates[native.displayedUnit] = { UnitFrame = frame }
    return frame, native
end

function helpers.test(name, run)
    state.textures, state.nameplates, state.unitThreat = {}, {}, {}
    state.unitThreatLead, state.leadStatus, state.threatLeadQuery = {}, 3, nil
    state.party, state.enemy, state.tank, state.status = true, true, false, 3
    state.combat, state.combatQuery = false, nil
    state.partyMembers, state.partyThreat, state.partyThreatQueries = 4, {}, {}
    state.isTanking, state.tankingQuery = true, nil
    state.threatQuery, state.secretChecked = nil, false
    state.secret, state.nameplateQuery = {}, nil
    state.healthBarColorCVar, state.variablesLoaded = true, true
    helpers.reloadAddon()
    run()
    helpers.tests = helpers.tests + 1
    print("ok - " .. name)
end

function helpers.assertColor(texture, r, g, b)
    assert(texture and texture.shown, "Expected a visible overlay")
    local color = texture.color
    assert(color[1] == r and color[2] == g and color[3] == b, "Unexpected overlay color")
end

local function loadAddon()
    local addon = {}
    assert(loadfile("Nameplates.lua"))("NameplateThreatColor", addon)
    assert(loadfile("Settings.lua"))("NameplateThreatColor", addon)
    return addon
end

function helpers.reloadAddon(saved, charSaved)
    NameplateThreatColorDB, NameplateThreatColorCharDB = saved, charSaved
    state.update, state.initialize, state.category, state.registeredCategory = nil, nil, nil, nil
    state.onVariablesLoaded, state.prompt = nil, nil
    state.settings, state.uiFrames = {}, {}
    state.addon = loadAddon()
    assert(state.update, "Health-color post-hook was not installed")
    assert(
        state.initialize,
        "Settings initialization was not deferred until addon loading completes"
    )
    assert(
        NameplateThreatColorDB == saved and state.category == nil and next(state.settings) == nil
    )
    assert(NameplateThreatColorCharDB == charSaved)
    state.initialize()
end

return helpers
