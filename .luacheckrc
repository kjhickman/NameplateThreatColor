std = "lua51"
max_line_length = false

read_globals = {
    "C_CVar",
    "C_NamePlate",
    "CreateColorFromHexString",
    "CreateFrame",
    "Enum",
    "EventUtil",
    "GetNumSubgroupMembers",
    "hooksecurefunc",
    "issecretvalue",
    "PlayerUtil",
    "Settings",
    "UIParent",
    "UnitAffectingCombat",
    "UnitCanAttack",
    "UnitInParty",
    "UnitThreatLeadSituation",
    "UnitThreatSituation",
}

globals = { "NameplateThreatColorCharDB", "NameplateThreatColorDB" }

files["tests/Helpers.lua"] = {
    new_read_globals = {},
    globals = read_globals,
    self = false,
}
