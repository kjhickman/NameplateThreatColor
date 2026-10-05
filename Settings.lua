local addonName, addon = ...

local defaults = {
    secureAggroColor = "ff00ff00",
    warningColor = "ffffff00",
    urgentWarningColor = "ffff9900",
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

    local category, layout = Settings.RegisterVerticalLayoutCategory("NameplateThreatColor")
    layout:AddInitializer(Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
        name = "Requires being in a party and Nameplates > Threat Display > Health Bar Color enabled.",
    }))
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
