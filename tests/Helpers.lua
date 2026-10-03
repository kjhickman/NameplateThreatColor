local helpers = {
    state = { secret = {}, settings = {} },
    tests = 0,
}
local state = helpers.state

EventUtil = {
    ContinueOnAddOnLoaded = function(name, callback)
        assert(name == "NameplateThreatColor")
        state.initialize = callback
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

Settings = { VarType = { String = "string" } }

function Settings.RegisterVerticalLayoutCategory(name)
    state.category = { name = name }
    return state.category
end

function Settings.RegisterProxySetting(owner, variable, kind, label, default, getValue, setValue)
    assert(owner == state.category and kind == Settings.VarType.String)
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

function Settings.CreateColorSwatch(owner, setting, tooltip)
    assert(owner == state.category and type(tooltip) == "string" and #tooltip > 0)
    setting.swatch = true
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

PlayerUtil = {
    IsPlayerEffectivelyTank = function()
        return state.tank
    end,
}

function UnitThreatSituation(player, unit)
    assert(player == "player" and state.nameplates[unit])
    state.threatQuery = "normal"
    if state.unitThreat[unit] ~= nil then
        return state.unitThreat[unit]
    end
    return state.status
end

function UnitThreatLeadSituation(player, unit)
    assert(player == "player" and state.nameplates[unit])
    state.threatQuery = "tank"
    if state.unitThreat[unit] ~= nil then
        return state.unitThreat[unit]
    end
    return state.status
end

function UnitDetailedThreatSituation(player, unit)
    assert(player == "player" and state.nameplates[unit])
    state.tankingQuery = unit
    return state.isTanking
end

function helpers.newFrame(unit)
    local fill = { GetWidth = forbiddenWrite }
    local bar = {
        GetStatusBarColor = forbiddenWrite,
        SetStatusBarColor = forbiddenWrite,
        GetValue = forbiddenWrite,
    }
    function bar:GetStatusBarTexture()
        return fill
    end
    function bar:CreateTexture(name, layer, template, sublevel)
        assert(name == nil and layer == "ARTWORK" and template == nil and sublevel == 0)
        local texture = {}
        function texture:SetAllPoints(relativeTo)
            assert(relativeTo == fill, "Overlay must follow the existing fill")
        end
        function texture:SetColorTexture(r, g, b)
            self.color = { r, g, b }
        end
        function texture:Hide()
            self.shown = false
        end
        function texture:Show()
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
    state.party, state.enemy, state.tank, state.status = true, true, false, 3
    state.isTanking, state.tankingQuery = true, nil
    state.threatQuery, state.secretChecked = nil, false
    for _, setting in pairs(state.settings) do
        setting:SetValue(setting.default)
    end
    run()
    helpers.tests = helpers.tests + 1
    print("ok - " .. name)
end

local function loadAddon()
    local addon = {}
    assert(loadfile("Nameplates.lua"))("NameplateThreatColor", addon)
    assert(loadfile("Settings.lua"))("NameplateThreatColor", addon)
    return addon
end

function helpers.reloadAddon(saved)
    NameplateThreatColorDB = saved
    state.update, state.initialize, state.category, state.registeredCategory = nil, nil, nil, nil
    state.settings = {}
    state.addon = loadAddon()
    assert(state.update and state.initialize)
    state.initialize()
end

state.addon = loadAddon()
assert(state.update, "Health-color post-hook was not installed")
assert(state.initialize, "Settings initialization was not deferred until addon loading completes")
assert(NameplateThreatColorDB == nil and state.category == nil and next(state.settings) == nil)
state.initialize()

return helpers
