local addonName, addon = ...

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

local defaultSeparateTankColors = false
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

-- These frames belong only to this canvas, never to Blizzard's shared settings
-- list/pool. In particular, visibility changes must not use AddShownPredicate.
local function AddControl(parent, initializer, offset)
    local control = CreateFrame("Frame", nil, parent, initializer:GetTemplate())
    control:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -offset)
    control:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -offset)
    control.GetElementData = function()
        return initializer
    end
    -- List narration expects a vertical layout; this canvas has no list indices.
    control.GetNarrationIndexString = function()
        return nil
    end
    initializer:InitFrame(control)
    return control
end

local function RegisterColorSetting(category, parent, offset, key, label, tooltip)
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
    return AddControl(parent, Settings.CreateColorSwatchInitializer(setting, nil, tooltip), offset)
end

local function RegisterSeparateTankColorsSetting(category, panel, tankSection)
    local setting = Settings.RegisterProxySetting(
        category,
        "NameplateThreatColor_separateTankColors",
        Settings.VarType.Boolean,
        "Separate tank colors",
        defaultSeparateTankColors,
        function()
            return NameplateThreatColorDB.separateTankColors
        end,
        function(value)
            NameplateThreatColorDB.separateTankColors = value
            addon.ApplyColors(NameplateThreatColorDB)
            tankSection:SetShown(value)
        end
    )
    AddControl(
        panel,
        Settings.CreateCheckboxInitializer(
            setting,
            nil,
            "Give tanking its own set of colors. While off, both roles share the colors above."
        ),
        232
    )
end

local function RegisterRoleLockSetting(category, panel)
    local setting = Settings.RegisterProxySetting(
        category,
        "NameplateThreatColor_roleLock",
        Settings.VarType.String,
        "Role",
        defaultRoleLock,
        function()
            return NameplateThreatColorCharDB.roleLock
        end,
        function(value)
            NameplateThreatColorCharDB.roleLock = value
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
    AddControl(
        panel,
        Settings.CreateDropdownInitializer(
            setting,
            GetOptions,
            "Which threat states the colors describe. Automatic follows your current role, while Tank or Non-tank keeps the same colors through stance, form and specialization changes."
        ),
        62
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
    if type(NameplateThreatColorDB.separateTankColors) ~= "boolean" then
        NameplateThreatColorDB.separateTankColors = defaultSeparateTankColors
    end

    -- The role lock is per character so a locked tank does not follow you onto an alt.
    if type(NameplateThreatColorCharDB) ~= "table" then
        NameplateThreatColorCharDB = {}
    end
    if not IsKnownRoleLock(NameplateThreatColorCharDB.roleLock) then
        NameplateThreatColorCharDB.roleLock = defaultRoleLock
    end

    addon.ApplyColors(NameplateThreatColorDB)
    addon.ApplyRoleLock(NameplateThreatColorCharDB.roleLock)

    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(panel, "NameplateThreatColor")
    local tankSection = CreateFrame("Frame", nil, panel)
    tankSection:SetPoint("TOPLEFT", panel, "TOPLEFT", 0, -266)
    tankSection:SetPoint("TOPRIGHT", panel, "TOPRIGHT", 0, -266)
    tankSection:SetHeight(136)
    panel.OnRefresh = function()
        tankSection:SetShown(NameplateThreatColorDB.separateTankColors)
    end
    panel:OnRefresh()

    local note = AddControl(
        panel,
        Settings.CreateElementInitializer("SettingsListSectionHeaderTemplate", {
            name = "Requires being in a party and Nameplates > Threat Display > Health Bar Color enabled.",
        }),
        0
    )
    note.Title:SetFontObject("GameFontHighlightSmall")
    note.Title:SetPoint("TOPRIGHT", note, "TOPRIGHT", -8, -16)
    RegisterRoleLockSetting(category, panel)
    RegisterColorSetting(
        category,
        panel,
        96,
        "secureAggroColor",
        "Secure aggro color",
        "For tanks: holding aggro with a safe threat lead. For non-tanks: no aggro and safely below the pull threshold."
    )
    RegisterColorSetting(
        category,
        panel,
        130,
        "warningColor",
        "Threat warning color",
        "For tanks: a threat-lead warning. For non-tanks: high threat without holding aggro."
    )
    RegisterColorSetting(
        category,
        panel,
        164,
        "urgentWarningColor",
        "Urgent threat warning color",
        "For tanks: a more urgent threat-lead warning. For non-tanks: holding aggro while another unit has higher threat."
    )
    RegisterColorSetting(
        category,
        panel,
        198,
        "highThreatColor",
        "Pulled / lost aggro color",
        "For tanks: lost or unsafe aggro. For non-tanks: holding aggro."
    )
    RegisterSeparateTankColorsSetting(category, panel, tankSection)
    RegisterColorSetting(
        category,
        tankSection,
        0,
        "tankSecureAggroColor",
        "Tank secure aggro color",
        "For tanks: holding aggro with a safe threat lead."
    )
    RegisterColorSetting(
        category,
        tankSection,
        34,
        "tankWarningColor",
        "Tank threat warning color",
        "For tanks: a threat-lead warning."
    )
    RegisterColorSetting(
        category,
        tankSection,
        68,
        "tankUrgentWarningColor",
        "Tank urgent threat warning color",
        "For tanks: a more urgent threat-lead warning."
    )
    RegisterColorSetting(
        category,
        tankSection,
        102,
        "tankHighThreatColor",
        "Tank lost aggro color",
        "For tanks: lost or unsafe aggro."
    )
    Settings.RegisterAddOnCategory(category)
end)
