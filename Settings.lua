local addonName, addon = ...

local defaults = {
    secureAggroColor = "ff00ff00",
    warningColor = "ffffff00",
    urgentWarningColor = "ffff9900",
    highThreatColor = "ffff0000",
    coTankAggroColor = "ff3b82f6",
    tankSecureAggroColor = "ff00ff00",
    tankWarningColor = "ffffff00",
    tankUrgentWarningColor = "ffff9900",
    tankHighThreatColor = "ffff0000",
}

local defaultShowCoTankColor = true
local defaultSeparateTankColors = false
local defaultRoleLock = "auto"
local threatDisplayCVar = "nameplateThreatDisplay"
local rowHeight = 34

local function SetRowOffset(frame, parent, offset)
    frame:ClearAllPoints()
    frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -offset)
    frame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -offset)
end

-- These frames belong only to this canvas, never to Blizzard's shared settings
-- list/pool. In particular, visibility changes must not use AddShownPredicate.
local function AddControl(parent, initializer, offset)
    local control = CreateFrame("Frame", nil, parent, initializer:GetTemplate())
    SetRowOffset(control, parent, offset)
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

local function CheckHealthBarColorSetting()
    if NameplateThreatColorDB.hideHealthBarColorPrompt then
        return
    end
    if
        C_CVar.GetCVarBitfield(threatDisplayCVar, Enum.NamePlateThreatDisplay.HealthBarColor)
        ~= false
    then
        return
    end

    local prompt = CreateFrame("Frame", nil, UIParent)
    prompt:SetWidth(360)
    prompt:SetPoint("TOP", UIParent, "TOP", 0, -135)
    prompt:SetFrameStrata("DIALOG")
    prompt:SetToplevel(true)
    prompt:EnableMouse(true)

    local border = CreateFrame("Frame", nil, prompt, "DialogBorderDarkTemplate")
    border:SetAllPoints(prompt)

    local text = prompt:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
    text:SetWidth(312)
    text:SetPoint("TOP", prompt, "TOP", 0, -18)
    text:SetText(
        "NameplateThreatColor needs Nameplates > Aggro Display > Health Bar Color enabled to color enemy health bars."
    )

    local dontShow = CreateFrame("CheckButton", nil, prompt, "UICheckButtonTemplate")
    dontShow:SetSize(24, 24)
    dontShow.Text:SetText("Don't show this again")
    local labelWidth = dontShow.Text:GetStringWidth()
    dontShow:SetHitRectInsets(0, -labelWidth, 0, 0)
    local checkboxOffset = labelWidth / 2
    dontShow:SetPoint("TOP", text, "BOTTOM", -checkboxOffset, -10)

    for _, spec in ipairs({
        { "Enable", "TOPRIGHT", -5, true },
        { "Dismiss", "TOPLEFT", 5, false },
    }) do
        local button = CreateFrame("Button", nil, prompt, "UIPanelButtonTemplate")
        button:SetSize(128, 21)
        button:SetPoint(spec[2], dontShow, "BOTTOM", checkboxOffset + spec[3], -8)
        button:SetText(spec[1])
        button:SetScript("OnClick", function()
            if spec[4] then
                if
                    not C_CVar.SetCVarBitfield(
                        threatDisplayCVar,
                        Enum.NamePlateThreatDisplay.HealthBarColor,
                        true
                    )
                then
                    return
                end
            end
            if dontShow:GetChecked() then
                NameplateThreatColorDB.hideHealthBarColorPrompt = true
            end
            prompt:Hide()
        end)
    end

    prompt:SetHeight(text:GetStringHeight() + 95)
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
    if type(NameplateThreatColorDB.showCoTankColor) ~= "boolean" then
        NameplateThreatColorDB.showCoTankColor = defaultShowCoTankColor
    end
    if type(NameplateThreatColorDB.hideHealthBarColorPrompt) ~= "boolean" then
        NameplateThreatColorDB.hideHealthBarColorPrompt = false
    end

    -- The role lock is per character so a locked tank does not follow you onto an alt.
    if type(NameplateThreatColorCharDB) ~= "table" then
        NameplateThreatColorCharDB = {}
    end
    local roleLock = NameplateThreatColorCharDB.roleLock
    if roleLock ~= "tank" and roleLock ~= "nontank" then
        NameplateThreatColorCharDB.roleLock = defaultRoleLock
    end

    addon.ApplyColors(NameplateThreatColorDB)
    addon.ApplyRoleLock(NameplateThreatColorCharDB.roleLock)
    EventUtil.ContinueOnVariablesLoaded(CheckHealthBarColorSetting)

    local panel = CreateFrame("Frame")
    local category = Settings.RegisterCanvasLayoutCategory(panel, "NameplateThreatColor")
    local registeredSettings = {}

    local function RegisterSetting(key, db, varType, label, default, onChange)
        local setting = Settings.RegisterAddOnSetting(
            category,
            "NameplateThreatColor_" .. key,
            key,
            db,
            varType,
            label,
            default
        )
        setting:SetValueChangedCallback(onChange)
        registeredSettings[#registeredSettings + 1] = setting
        return setting
    end

    local function ApplyColors()
        addon.ApplyColors(NameplateThreatColorDB)
    end

    local function RegisterColorSetting(parent, rowOffset, key, label, tooltip)
        local setting = RegisterSetting(
            key,
            NameplateThreatColorDB,
            Settings.VarType.String,
            label,
            defaults[key],
            ApplyColors
        )
        return AddControl(
            parent,
            Settings.CreateColorSwatchInitializer(setting, nil, tooltip),
            rowOffset
        )
    end

    local function RegisterColorToggle(rowOffset, key, label, default, tooltip)
        local setting = RegisterSetting(
            key,
            NameplateThreatColorDB,
            Settings.VarType.Boolean,
            label,
            default,
            function()
                ApplyColors()
                panel:OnRefresh()
            end
        )
        return AddControl(
            panel,
            Settings.CreateCheckboxInitializer(setting, nil, tooltip),
            rowOffset
        )
    end

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightHuge")
    title:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -22)
    title:SetText("NameplateThreatColor")

    local divider = panel:CreateTexture(nil, "ARTWORK")
    divider:SetAtlas("Options_HorizontalDivider", true)
    divider:SetPoint("TOP", panel, "TOP", 0, -50)

    local defaultsButton = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    defaultsButton:SetSize(96, 22)
    defaultsButton:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -36, -16)
    defaultsButton:SetText(SETTINGS_DEFAULTS)
    defaultsButton:SetScript("OnClick", function()
        for _, setting in ipairs(registeredSettings) do
            setting:SetValueToDefault()
        end
        panel:OnRefresh()
    end)

    local note = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    note:SetJustifyH("LEFT")
    note:SetPoint("TOPLEFT", panel, "TOPLEFT", 7, -66)
    note:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -8, -66)
    note:SetText(
        "Requires a party or raid and Nameplates > Aggro Display > Health Bar Color enabled."
    )

    local offset = 106
    local function NextOffset()
        local current = offset
        offset = offset + rowHeight
        return current
    end

    local roleLockSetting = RegisterSetting(
        "roleLock",
        NameplateThreatColorCharDB,
        Settings.VarType.String,
        "Role",
        defaultRoleLock,
        function(_, value)
            addon.ApplyRoleLock(value)
        end
    )
    AddControl(
        panel,
        Settings.CreateDropdownInitializer(
            roleLockSetting,
            function()
                local container = Settings.CreateControlTextContainer()
                container:Add("auto", "Automatic")
                container:Add("tank", "Tank")
                container:Add("nontank", "Non-tank")
                return container:GetData()
            end,
            "Which threat states the colors describe. Automatic follows your current role, while Tank or Non-tank keeps the same colors through stance, form and specialization changes."
        ),
        NextOffset()
    )
    for _, spec in ipairs({
        {
            "secureAggroColor",
            "Secure aggro color",
            "For tanks: holding aggro with a safe threat lead. For non-tanks: no aggro and safely below the pull threshold.",
        },
        {
            "warningColor",
            "Threat warning color",
            "For tanks: a threat-lead warning. For non-tanks: high threat without holding aggro.",
        },
        {
            "urgentWarningColor",
            "Urgent threat warning color",
            "For tanks: a more urgent threat-lead warning. For non-tanks: holding aggro while another unit has higher threat.",
        },
        {
            "highThreatColor",
            "Pulled / lost aggro color",
            "For tanks: lost or unsafe aggro. For non-tanks: holding aggro.",
        },
    }) do
        RegisterColorSetting(panel, NextOffset(), spec[1], spec[2], spec[3])
    end
    RegisterColorToggle(
        NextOffset(),
        "showCoTankColor",
        "Show co-tank aggro color",
        defaultShowCoTankColor,
        "Use a distinct nameplate color when another tank is holding aggro in your raid."
    )
    local coTankOffset = NextOffset()
    local coTankSwatch = RegisterColorSetting(
        panel,
        coTankOffset,
        "coTankAggroColor",
        "Co-tank holding aggro",
        "While tanking in a raid, marks an enemy when another raid tank (Tank role or Main Tank) is holding aggro and you are not."
    )
    local separateTankToggle = RegisterColorToggle(
        NextOffset(),
        "separateTankColors",
        "Separate tank colors",
        defaultSeparateTankColors,
        "Give tanking its own set of threat colors. This does not affect the co-tank color."
    )

    local tankSection = CreateFrame("Frame", nil, panel)
    tankSection:SetHeight(rowHeight * 4)
    local tankOffset = 0
    for _, spec in ipairs({
        {
            "tankSecureAggroColor",
            "Tank secure aggro color",
            "For tanks: holding aggro with a safe threat lead.",
        },
        {
            "tankWarningColor",
            "Tank threat warning color",
            "For tanks: a threat-lead warning.",
        },
        {
            "tankUrgentWarningColor",
            "Tank urgent threat warning color",
            "For tanks: a more urgent threat-lead warning.",
        },
        {
            "tankHighThreatColor",
            "Tank lost aggro color",
            "For tanks: lost or unsafe aggro.",
        },
    }) do
        RegisterColorSetting(tankSection, tankOffset, spec[1], spec[2], spec[3])
        tankOffset = tankOffset + rowHeight
    end

    panel.OnRefresh = function()
        local showCoTank = NameplateThreatColorDB.showCoTankColor
        coTankSwatch:SetShown(showCoTank)
        local separateOffset = showCoTank and (coTankOffset + rowHeight) or coTankOffset
        SetRowOffset(separateTankToggle, panel, separateOffset)
        SetRowOffset(tankSection, panel, separateOffset + rowHeight)
        tankSection:SetShown(NameplateThreatColorDB.separateTankColors)
    end
    panel.OnDefault = panel.OnRefresh
    panel:OnRefresh()
    Settings.RegisterAddOnCategory(category)
end)
