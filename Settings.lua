local addonName, addon = ...

local defaults = {
    secureAggroColor = "ff00ff00",
    warningColor = "ffffff00",
    urgentWarningColor = "ffff9900",
    highThreatColor = "ffff0000",
}

local defaultRoleLock = "auto"
local roleLockOptions = {
    { "auto", "Automatic" },
    { "tank", "Tank" },
    { "nontank", "Non-tank" },
}

local function IsKnownRoleLock(value)
    for _, option in ipairs(roleLockOptions) do
        if option[1] == value then
            return true
        end
    end
    return false
end

local function RegisterColorSetting(category, key, label, tooltip)
    local setting = Settings.RegisterProxySetting(
        category,
        "NameplateThreatColor_" .. key,
        Settings.VarType.String,
        label,
        defaults[key],
        function()
            return NameplateThreatColorDB[key]
        end,
        function(value)
            NameplateThreatColorDB[key] = value
            addon.ApplyColors(NameplateThreatColorDB)
        end
    )
    Settings.CreateColorSwatch(category, setting, tooltip)
end

local function RegisterRoleLockSetting(category)
    local setting = Settings.RegisterProxySetting(
        category,
        "NameplateThreatColor_roleLock",
        Settings.VarType.String,
        "Role",
        defaultRoleLock,
        function()
            return NameplateThreatColorDB.roleLock
        end,
        function(value)
            NameplateThreatColorDB.roleLock = value
            addon.ApplyRoleLock(value)
        end
    )
    local function GetOptions()
        local container = Settings.CreateControlTextContainer()
        for _, option in ipairs(roleLockOptions) do
            container:Add(option[1], option[2])
        end
        return container:GetData()
    end
    Settings.CreateDropdown(
        category,
        setting,
        GetOptions,
        "Which threat states the colors describe. Automatic follows your current role, while Tank or Non-tank keeps the same colors through stance, form and specialization changes."
    )
end

EventUtil.ContinueOnAddOnLoaded(addonName, function()
    if type(NameplateThreatColorDB) ~= "table" then
        NameplateThreatColorDB = {}
    end
    for key, value in pairs(defaults) do
        local color = NameplateThreatColorDB[key]
        if type(color) ~= "string" or #color ~= 8 or not color:match("^%x+$") then
            NameplateThreatColorDB[key] = value
        end
    end
    if not IsKnownRoleLock(NameplateThreatColorDB.roleLock) then
        NameplateThreatColorDB.roleLock = defaultRoleLock
    end
    addon.ApplyColors(NameplateThreatColorDB)
    addon.ApplyRoleLock(NameplateThreatColorDB.roleLock)

    local category, layout = Settings.RegisterVerticalLayoutCategory("NameplateThreatColor")
    layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
        name = "Requires being in a party and Nameplates > Threat Display > Health Bar Color enabled.",
    }))
    RegisterRoleLockSetting(category)
    RegisterColorSetting(
        category,
        "secureAggroColor",
        "Secure aggro color",
        "For tanks: holding aggro with a safe threat lead. For non-tanks: no aggro and safely below the pull threshold."
    )
    RegisterColorSetting(
        category,
        "warningColor",
        "Threat warning color",
        "For tanks: a threat-lead warning. For non-tanks: high threat without holding aggro."
    )
    RegisterColorSetting(
        category,
        "urgentWarningColor",
        "Urgent threat warning color",
        "For tanks: a more urgent threat-lead warning. For non-tanks: holding aggro while another unit has higher threat."
    )
    RegisterColorSetting(
        category,
        "highThreatColor",
        "Pulled / lost aggro color",
        "For tanks: lost or unsafe aggro. For non-tanks: holding aggro."
    )
    Settings.RegisterAddOnCategory(category)
end)
