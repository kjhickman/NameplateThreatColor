-- Run from the addon directory: lua NameplateThreatColor.test.lua
local update
local textures
local nameplates
local party, enemy, tank, status
local threatQuery
local secret = {}
local secretChecked
local tests = 0

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
    return status
end

function UnitThreatLeadSituation(player, unit)
    assert(player == "player" and nameplates[unit])
    threatQuery = "tank"
    return status
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
    textures, nameplates = {}, {}
    party, enemy, tank, status = true, true, false, 3
    threatQuery, secretChecked = nil, false
    run()
    tests = tests + 1
    print("ok - " .. name)
end

dofile("NameplateThreatColor.lua")
assert(update, "Health-color post-hook was not installed")

test("party frames are untouched, even with secret native colors", function()
    update(newFrame("player"))
    assert(#textures == 0 and threatQuery == nil)
end)

test("highest threat is magenta without changing Blizzard's bar", function()
    update(newFrame())
    local color = textures[1].color
    assert(textures[1].shown and color[1] == 1 and color[2] == 0 and color[3] == 1)
    assert(threatQuery == "normal")
end)

test("both warning states are cyan and reuse the overlay", function()
    local frame = newFrame()
    for _, warning in ipairs({ 1, 2 }) do
        status = warning
        update(frame)
        local color = textures[1].color
        assert(textures[1].shown and color[1] == 0 and color[2] == 1 and color[3] == 1)
        assert(#textures == 1)
    end
end)

test("tank recognition selects the threat-lead API", function()
    tank = true
    update(newFrame())
    assert(threatQuery == "tank" and textures[1].shown)
end)

for _, case in ipairs({ { "zero", 0 }, { "unknown", 4 }, { "secret", secret } }) do
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
    assert(textures[1].color[1] == 1 and textures[2].color[1] == 0)
    status = 0
    update(first)
    assert(not textures[1].shown and textures[2].shown)
end)

print(tests .. " tests passed")
