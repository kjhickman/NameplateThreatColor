std = "lua51"
max_line_length = false

read_globals = {
    "C_CVar",
    "C_NamePlate",
    "CreateColorFromHexString",
    "CreateFrame",
    "Enum",
    "EventUtil",
    "GetNumGroupMembers",
    "GetNumSubgroupMembers",
    "GetPartyAssignment",
    "hooksecurefunc",
    "issecretvalue",
    "MAX_RAID_MEMBERS",
    "PlayerUtil",
    "Settings",
    "UIParent",
    "UnitAffectingCombat",
    "UnitCanAttack",
    "UnitGroupRolesAssigned",
    "UnitInParty",
    "UnitInRaid",
    "UnitIsPlayer",
    "UnitThreatLeadSituation",
    "UnitThreatSituation",
}

globals = { "NameplateThreatColorCharDB", "NameplateThreatColorDB" }

files["tests/Helpers.lua"] = {
    new_read_globals = {},
    globals = read_globals,
    self = false,
}
