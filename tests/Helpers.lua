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
MAX_RAID_MEMBERS = 40
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
        assert(unit ~= state.secret, "Secret unit token passed into a game API")
        return state.nameplates[unit]
    end,
    GetNamePlates = function()
        local plates = {}
        for _, plate in pairs(state.nameplates) do
            plates[#plates + 1] = plate
        end
        return plates
    end,
}

function UnitInParty(unit)
    assert(unit == "player")
    return state.party
end

function UnitInRaid(unit)
    assert(unit == "player")
    return state.raidIndex
end

function GetNumGroupMembers()
    return #state.raidRoles
end

function UnitGroupRolesAssigned(unit)
    local index = assert(tonumber(unit:match("^raid(%d+)$")))
    assert(index ~= state.raidIndex, "The player is not a co-tank")
    state.roleChecks = state.roleChecks + 1
    return state.raidRoles[index]
end

function GetPartyAssignment(assignment, unit)
    assert(assignment == "MAINTANK")
    local index = assert(tonumber(unit:match("^raid(%d+)$")))
    assert(index ~= state.raidIndex, "The player is not a co-tank")
    return state.raidMainTanks[index] or false
end

function UnitCanAttack(player, unit)
    assert(player == "player" and state.nameplates[unit])
    return state.enemy
end

function UnitIsPlayer(unit)
    assert(state.nameplates[unit])
    return state.isPlayer
end

function UnitAffectingCombat(unit)
    assert(state.nameplates[unit])
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
        state.unitThreatChecks = state.unitThreatChecks + 1
        local threats
        if player:match("^raid%d+$") then
            threats = state.raidThreat[unit]
        else
            assert(player:match("^party%d+$"))
            threats = state.partyThreat[unit]
        end
        return threats and threats[player]
    end
    state.playerThreatChecks = state.playerThreatChecks + 1
    if state.unitThreat[unit] ~= nil then
        return state.unitThreat[unit]
    end
    return state.status
end

function UnitThreatLeadSituation(player, unit)
    assert(player == "player" and state.nameplates[unit])
    if state.unitThreatLead[unit] ~= nil then
        return state.unitThreatLead[unit]
    end
    return state.leadStatus
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
        function frame:RegisterEvent(event)
            assert(not state.events[event])
            state.events[event] = function(...)
                self.scripts.OnEvent(self, event, ...)
            end
        end
        function frame:RegisterUnitEvent(event, unit)
            assert(not state.events[event])
            assert(unit == "player")
            state.events[event] = function(eventUnit)
                assert(eventUnit == nil or eventUnit == unit)
                self.scripts.OnEvent(self, event, eventUnit or unit)
            end
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
    function bar:SetUsingParentLevel(usingParentLevel)
        self.usingParentLevel = usingParentLevel
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
        local texture = { layer = layer, sublevel = sublevel, owner = owner }
        function texture:SetAllPoints(relativeTo)
            assertCurrentTest()
            assert(relativeTo == owner, "The status-bar renderer must manage the overlay fill")
            self.anchor = relativeTo
        end
        function texture:SetAtlas(atlas)
            assertCurrentTest()
            self.atlas, self.file, self.texCoord = atlas, nil, nil
            self.atlasCalls = (self.atlasCalls or 0) + 1
        end
        function texture:SetTexture(file)
            assertCurrentTest()
            self.file, self.atlas = file, nil
            self.textureCalls = (self.textureCalls or 0) + 1
        end
        function texture:SetTexCoord(left, right, top, bottom)
            assertCurrentTest()
            self.texCoord = { left, right, top, bottom }
        end
        function texture:SetVertexColor(r, g, b)
            assertCurrentTest()
            self.color = { r, g, b }
        end
        function texture:Hide()
            assertCurrentTest()
            self.shown = false
        end
        function texture:Show()
            assertCurrentTest()
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
    state.nameplates[native.displayedUnit] = {
        UnitFrame = frame,
        IsForbidden = function()
            return false
        end,
    }
    return frame, native
end

function helpers.test(name, run)
    state.textures, state.nameplates, state.unitThreat = {}, {}, {}
    state.unitThreatLead, state.leadStatus = {}, 3
    state.party, state.enemy, state.isPlayer, state.tank, state.status = true, true, false, false, 3
    state.combat, state.partyMembers, state.partyThreat = false, 4, {}
    state.raidIndex, state.raidRoles, state.raidMainTanks, state.raidThreat = nil, {}, {}, {}
    state.roleChecks, state.playerThreatChecks, state.unitThreatChecks = 0, 0, 0
    state.secret, state.secretChecked = {}, false
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
    state.settings, state.uiFrames, state.events = {}, {}, {}
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
