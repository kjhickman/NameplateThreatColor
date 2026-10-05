local addonName, addon = ...

local defaults = {
    secureAggroColor = "ff00ff00",
    warningColor = "ffffff00",
    highThreatColor = "ffff0000",
}

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
    addon.ApplyColors(NameplateThreatColorDB)

    local category = Settings.RegisterVerticalLayoutCategory("NameplateThreatColor")
    RegisterColorSetting(
        category,
        "secureAggroColor",
        "Secure aggro color",
        "For tanks: holding aggro with a safe threat lead. For non-tanks: no aggro and safely below the pull threshold (threat state 0), or no threat on an enemy fighting your party. Unknown threat stays unchanged. Requires a party and Nameplates > Threat Display > Health Bar Color."
    )
    RegisterColorSetting(
        category,
        "warningColor",
        "Gaining / losing aggro color",
        "Color for gaining or losing aggro (threat states 1 and 2). Requires a party and Nameplates > Threat Display > Health Bar Color."
    )
    RegisterColorSetting(
        category,
        "highThreatColor",
        "Pulled / lost aggro color",
        "For non-tanks: holding aggro. For tanks: lost or unsafe aggro (threat state 3). Requires a party and Nameplates > Threat Display > Health Bar Color."
    )
    Settings.RegisterAddOnCategory(category)
end)
