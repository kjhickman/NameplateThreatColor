-- Run from the addon directory: lua NameplateThreatColor.test.lua
local update
local textures
local nameplates
local party, enemy, tank, status
local isTanking, tankingQuery
local threatQuery
local unitThreat
local secret = {}
local secretChecked
local tests = 0
local initialize
local settings = {}
local category
local registeredCategory

EventUtil = {
    ContinueOnAddOnLoaded = function(name, callback)
        assert(name == "NameplateThreatColor")
        initialize = callback
    end,
}

function CreateColorFromHexString(hex)
    assert(type(hex) == "string" and #hex == 8)
    local r = tonumber(hex:sub(3, 4), 16) / 255
    local g = tonumber(hex:sub(5, 6), 16) / 255
    local b = tonumber(hex:sub(7, 8), 16) / 255
    return { GetRGB = function() return r, g, b end }
end

Settings = { VarType = { String = "string" } }

function Settings.RegisterVerticalLayoutCategory(name)
    category = { name = name }
    return category
end

function Settings.RegisterProxySetting(owner, variable, kind, label, default, getValue, setValue)
    assert(owner == category and kind == Settings.VarType.String)
    assert(not settings[variable], "Setting registered twice")
    local setting = { label = label, default = default }
    function setting:GetValue()
        return getValue()
    end
    function setting:SetValue(value)
        setValue(value)
    end
    settings[variable] = setting
    return setting
end

function Settings.CreateColorSwatch(owner, setting, tooltip)
    assert(owner == category and type(tooltip) == "string" and #tooltip > 0)
    setting.swatch = true
end

function Settings.RegisterAddOnCategory(owner)
    assert(owner == category)
    registeredCategory = owner
end

local function forbiddenWrite()
    error("Addon touched Blizzard-owned state", 2)
end

GAINING_THREAT_COLOR = { SetRGB = forbiddenWrite }
HIGH_THREAT_COLOR = { SetRGB = forbiddenWrite }

function hooksecurefunc(name, callback)
    assert(name == "CompactUnitFrame_UpdateHealthColor")
    assert(not update, "Hook installed more than once")
    update = callback
end

function issecretvalue(value)
    if value == secret then
        secretChecked = true
        return true
    end
    return false
end

C_NamePlate = {
    GetNamePlateForUnit = function(unit)
        return nameplates[unit]
    end,
}

function UnitInParty(unit)
    assert(unit == "player")
    return party
end

function UnitCanAttack(player, unit)
    assert(player == "player" and nameplates[unit])
    return enemy
end

PlayerUtil = {
    IsPlayerEffectivelyTank = function()
        return tank
    end,
}

function UnitThreatSituation(player, unit)
    assert(player == "player" and nameplates[unit])
    threatQuery = "normal"
    if unitThreat[unit] ~= nil then return unitThreat[unit] end
    return status
end

function UnitThreatLeadSituation(player, unit)
    assert(player == "player" and nameplates[unit])
    threatQuery = "tank"
    if unitThreat[unit] ~= nil then return unitThreat[unit] end
    return status
end

function UnitDetailedThreatSituation(player, unit)
    assert(player == "player" and nameplates[unit])
    tankingQuery = unit
    return isTanking
end

local function newFrame(unit)
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
        textures[#textures + 1] = texture
        return texture
    end

    local native = {
        displayedUnit = unit or "nameplate1",
        displayThreatHealthBarColor = true,
        healthBar = bar,
        IsForbidden = function() return false end,
    }
    local frame = setmetatable({}, { __index = native, __newindex = forbiddenWrite })
    nameplates[native.displayedUnit] = { UnitFrame = frame }
    return frame, native
end

local function test(name, run)
    textures, nameplates, unitThreat = {}, {}, {}
    party, enemy, tank, status = true, true, false, 3
    isTanking, tankingQuery = true, nil
    threatQuery, secretChecked = nil, false
    for _, setting in pairs(settings) do
        setting:SetValue(setting.default)
    end
    run()
    tests = tests + 1
    print("ok - " .. name)
end

dofile("NameplateThreatColor.lua")
assert(update, "Health-color post-hook was not installed")
assert(initialize, "Settings initialization was not deferred until addon loading completes")
assert(NameplateThreatColorDB == nil and category == nil and next(settings) == nil)
initialize()

test("native addon settings expose three color swatches with persisted defaults", function()
    assert(category.name == "NameplateThreatColor" and registeredCategory == category)
    local warning = settings.NameplateThreatColor_warningColor
    local high = settings.NameplateThreatColor_highThreatColor
    local secure = settings.NameplateThreatColor_secureAggroColor
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
    for _ in pairs(settings) do count = count + 1 end
    assert(count == 3)
end)

test("party frames are untouched, even with secret native colors", function()
    update(newFrame("player"))
    assert(#textures == 0 and threatQuery == nil)
end)

test("highest threat is red without changing Blizzard's bar", function()
    update(newFrame())
    local color = textures[1].color
    assert(textures[1].shown and color[1] == 1 and color[2] == 0 and color[3] == 0)
    assert(threatQuery == "normal")
end)

test("both warning states are yellow and reuse the overlay", function()
    local frame = newFrame()
    for _, warning in ipairs({ 1, 2 }) do
        status = warning
        update(frame)
        local color = textures[1].color
        assert(textures[1].shown and color[1] == 1 and color[2] == 1 and color[3] == 0)
        assert(#textures == 1)
    end
end)

test("tank recognition selects the threat-lead API", function()
    tank = true
    update(newFrame())
    assert(threatQuery == "tank" and textures[1].shown)
end)

test("a non-tank with safe low threat uses green without a tanking query", function()
    status = 0
    update(newFrame())
    local color = textures[1].color
    assert(textures[1].shown and color[1] == 0 and color[2] == 1 and color[3] == 0)
    assert(threatQuery == "normal" and tankingQuery == nil)
end)

test("secure tanks use green only while actually holding aggro", function()
    tank, status = true, 0
    local frame = newFrame()
    update(frame)
    local color = textures[1].color
    assert(textures[1].shown and color[1] == 0 and color[2] == 1 and color[3] == 0)
    assert(threatQuery == "tank" and tankingQuery == "nameplate1")
    isTanking = false
    update(frame)
    assert(not textures[1].shown)
end)

test("secret tanking results hide the secure color", function()
    tank, status = true, 0
    local frame = newFrame()
    update(frame)
    isTanking = secret
    update(frame)
    assert(secretChecked and not textures[1].shown)
end)

test("missing tanking confirmation does not show the secure color", function()
    tank, status, isTanking = true, 0, nil
    update(newFrame())
    assert(#textures == 0 and tankingQuery == "nameplate1")
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
        tank = role
        local frame = newFrame()
        for _, expected in ipairs(states) do
            status = expected[1]
            update(frame)
            local texture = textures[#textures]
            local color = texture.color
            assert(texture.shown)
            assert(color[1] == expected[2] and color[2] == expected[3] and color[3] == expected[4])
        end
    end
    assert(#textures == 2)
end)

for _, case in ipairs({ { "unknown", 4 }, { "secret", secret } }) do
    test(case[1] .. " threat hides a previous overlay", function()
        local frame = newFrame()
        update(frame)
        status = case[2]
        update(frame)
        assert(not textures[1].shown and #textures == 1)
        if status == secret then assert(secretChecked) end
    end)
end

test("nil threat hides a previous overlay", function()
    local frame = newFrame()
    update(frame)
    status = nil
    update(frame)
    assert(not textures[1].shown)
end)

test("turning Health Bar Color off restores the native fill", function()
    local frame, native = newFrame()
    update(frame)
    native.displayThreatHealthBarColor = false
    threatQuery = nil
    update(frame)
    assert(not textures[1].shown and threatQuery == nil)
end)

test("leaving the party restores the native fill", function()
    local frame = newFrame()
    update(frame)
    party, threatQuery = false, nil
    update(frame)
    assert(not textures[1].shown and threatQuery == nil)
end)

test("a nameplate reused for a friendly unit loses its custom color", function()
    local frame = newFrame()
    update(frame)
    enemy, threatQuery = false, nil
    update(frame)
    assert(not textures[1].shown and threatQuery == nil)
end)

test("a frame reused for a non-nameplate unit loses its custom color", function()
    local frame, native = newFrame()
    update(frame)
    native.displayedUnit = "party1"
    update(frame)
    assert(not textures[1].shown)
end)

test("clearing a unit hides its previous custom color", function()
    local frame, native = newFrame()
    update(frame)
    native.displayedUnit = nil
    update(frame)
    assert(not textures[1].shown)
end)

test("scripted preview frames are ignored", function()
    update(newFrame("nameplate-preview"))
    assert(#textures == 0 and threatQuery == nil)
end)

test("missing or mismatched nameplate ownership is ignored", function()
    local frame = newFrame()
    nameplates.nameplate1 = nil
    update(frame)
    nameplates.nameplate1 = { UnitFrame = {} }
    update(frame)
    assert(#textures == 0 and threatQuery == nil)
end)

test("forbidden frames are not inspected", function()
    local frame = setmetatable({}, {
        __index = function(_, key)
            assert(key == "IsForbidden", "Forbidden frame fields were inspected")
            return function() return true end
        end,
    })
    update(frame)
    assert(#textures == 0 and threatQuery == nil)
end)

test("secret unit tokens are not passed into game APIs", function()
    local frame, native = newFrame()
    native.displayedUnit = secret
    update(frame)
    assert(secretChecked and #textures == 0 and threatQuery == nil)
end)

test("secret display flags and enemy checks are not used as booleans", function()
    local frame, native = newFrame()
    native.displayThreatHealthBarColor = secret
    update(frame)
    assert(secretChecked and #textures == 0 and threatQuery == nil)
    native.displayThreatHealthBarColor, enemy = true, secret
    secretChecked = false
    update(frame)
    assert(secretChecked and #textures == 0 and threatQuery == nil)
end)

test("the overlay returns when Health Bar Color is enabled again", function()
    local frame, native = newFrame()
    update(frame)
    native.displayThreatHealthBarColor = false
    update(frame)
    native.displayThreatHealthBarColor = true
    update(frame)
    assert(textures[1].shown and #textures == 1)
end)

test("different nameplates have independent overlays", function()
    local first = newFrame("nameplate1")
    local second = newFrame("nameplate2")
    update(first)
    status = 1
    update(second)
    assert(#textures == 2 and textures[1].shown and textures[2].shown)
    assert(textures[1].color[2] == 0 and textures[2].color[2] == 1)
    status = nil
    update(first)
    assert(not textures[1].shown and textures[2].shown)
end)

test("changing the warning setting updates both warning states immediately", function()
    local first = newFrame("nameplate1")
    local second = newFrame("nameplate2")
    local high = newFrame("nameplate3")
    unitThreat = { nameplate1 = 1, nameplate2 = 2, nameplate3 = 3 }
    update(first)
    update(second)
    update(high)
    settings.NameplateThreatColor_warningColor:SetValue("ff00ff00")
    for index = 1, 2 do
        local texture = textures[index]
        assert(texture.shown)
        assert(texture.color[1] == 0 and texture.color[2] == 1 and texture.color[3] == 0)
    end
    assert(textures[3].shown and textures[3].color[1] == 1 and textures[3].color[2] == 0)
    assert(textures[3].color[3] == 0)
    assert(#textures == 3 and NameplateThreatColorDB.warningColor == "ff00ff00")
end)

test("changing the high-threat setting refreshes existing overlays", function()
    local frame = newFrame("nameplate1")
    local warning = newFrame("nameplate2")
    unitThreat = { nameplate1 = 3, nameplate2 = 1 }
    update(frame)
    update(warning)
    settings.NameplateThreatColor_highThreatColor:SetValue("ff0000ff")
    local color = textures[1].color
    assert(textures[1].shown and color[1] == 0 and color[2] == 0 and color[3] == 1)
    assert(#textures == 2 and NameplateThreatColorDB.highThreatColor == "ff0000ff")
    color = textures[2].color
    assert(textures[2].shown and color[1] == 1 and color[2] == 1 and color[3] == 0)
    assert(settings.NameplateThreatColor_warningColor:GetValue() == "ffffff00")
end)

test("the secure picker updates either role immediately without changing warnings", function()
    for _, role in ipairs({ false, true }) do
        tank = role
        local safe = newFrame("nameplate1")
        local warning = newFrame("nameplate2")
        local danger = newFrame("nameplate3")
        unitThreat = { nameplate1 = 0, nameplate2 = 1, nameplate3 = 3 }
        update(safe)
        update(warning)
        update(danger)
        settings.NameplateThreatColor_secureAggroColor:SetValue("ff0000ff")
        local color = textures[#textures - 2].color
        assert(color[1] == 0 and color[2] == 0 and color[3] == 1)
        color = textures[#textures - 1].color
        assert(color[1] == 1 and color[2] == 1 and color[3] == 0)
        color = textures[#textures].color
        assert(color[1] == 1 and color[2] == 0 and color[3] == 0)
    end
    assert(NameplateThreatColorDB.secureAggroColor == "ff0000ff")
end)

test("restoring the secure picker value restores the live green fill", function()
    tank, status = true, 0
    local frame = newFrame()
    update(frame)
    local setting = settings.NameplateThreatColor_secureAggroColor
    local previous = setting:GetValue()
    setting:SetValue("ff0000ff")
    setting:SetValue(previous)
    local color = textures[1].color
    assert(textures[1].shown and color[1] == 0 and color[2] == 1 and color[3] == 0)
    assert(NameplateThreatColorDB.secureAggroColor == previous)
end)

test("restoring a picker value on Cancel restores the live color", function()
    local frame = newFrame()
    update(frame)
    local setting = settings.NameplateThreatColor_highThreatColor
    local previous = setting:GetValue()
    setting:SetValue("ff0000ff")
    setting:SetValue(previous)
    local color = textures[1].color
    assert(textures[1].shown and color[1] == 1 and color[2] == 0 and color[3] == 0)
    assert(NameplateThreatColorDB.highThreatColor == previous)
end)

test("Cancel after reopening restores the previously accepted color", function()
    local frame = newFrame()
    update(frame)
    local setting = settings.NameplateThreatColor_highThreatColor
    setting:SetValue("ff0000ff")
    local previous = setting:GetValue()
    setting:SetValue("ff00ff00")
    setting:SetValue(previous)
    local color = textures[1].color
    assert(textures[1].shown and color[1] == 0 and color[2] == 0 and color[3] == 1)
    assert(NameplateThreatColorDB.highThreatColor == "ff0000ff")
end)

test("native setting defaults restore all three colors immediately", function()
    local frame = newFrame()
    update(frame)
    local warning = settings.NameplateThreatColor_warningColor
    local high = settings.NameplateThreatColor_highThreatColor
    local secure = settings.NameplateThreatColor_secureAggroColor
    warning:SetValue("ff00ff00")
    high:SetValue("ff0000ff")
    secure:SetValue("ff0000ff")
    warning:SetValue(warning.default)
    high:SetValue(high.default)
    secure:SetValue(secure.default)
    assert(NameplateThreatColorDB.warningColor == "ffffff00")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
    assert(textures[1].shown and textures[1].color[1] == 1 and textures[1].color[3] == 0)
end)

test("settings changes leave secret threat values on the native fill", function()
    local frame = newFrame()
    update(frame)
    status = secret
    settings.NameplateThreatColor_highThreatColor:SetValue("ff0000ff")
    assert(secretChecked and not textures[1].shown)
end)

local function reloadAddon(saved)
    NameplateThreatColorDB = saved
    update, initialize, category, registeredCategory = nil, nil, nil, nil
    settings = {}
    dofile("NameplateThreatColor.lua")
    assert(update and initialize)
    initialize()
end

test("saved colors survive addon reinitialization", function()
    settings.NameplateThreatColor_warningColor:SetValue("ff336699")
    settings.NameplateThreatColor_highThreatColor:SetValue("ff0000ff")
    settings.NameplateThreatColor_secureAggroColor:SetValue("ff996633")
    local saved = {
        warningColor = NameplateThreatColorDB.warningColor,
        highThreatColor = NameplateThreatColorDB.highThreatColor,
        secureAggroColor = NameplateThreatColorDB.secureAggroColor,
    }
    reloadAddon(saved)
    assert(settings.NameplateThreatColor_warningColor:GetValue() == "ff336699")
    assert(settings.NameplateThreatColor_highThreatColor:GetValue() == "ff0000ff")
    assert(settings.NameplateThreatColor_secureAggroColor:GetValue() == "ff996633")
    status = 1
    update(newFrame())
    local color = textures[1].color
    assert(color[1] == 0x33 / 255 and color[2] == 0x66 / 255 and color[3] == 0x99 / 255)
end)

test("missing saved colors get defaults without overwriting existing choices", function()
    reloadAddon({ warningColor = "ff00ff00" })
    assert(NameplateThreatColorDB.warningColor == "ff00ff00")
    assert(NameplateThreatColorDB.highThreatColor == "ffff0000")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
end)

test("older saved palettes are preserved when the secure setting is added", function()
    reloadAddon({ warningColor = "ff00ffff", highThreatColor = "ffff00ff" })
    assert(NameplateThreatColorDB.warningColor == "ff00ffff")
    assert(NameplateThreatColorDB.highThreatColor == "ffff00ff")
    assert(NameplateThreatColorDB.secureAggroColor == "ff00ff00")
end)

print(tests .. " tests passed")
