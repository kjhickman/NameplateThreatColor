local unpack = unpack or table.unpack

std = "lua51"
max_line_length = false

read_globals = {
    "C_NamePlate",
    "CreateColorFromHexString",
    "EventUtil",
    "GetNumSubgroupMembers",
    "hooksecurefunc",
    "issecretvalue",
    "PlayerUtil",
    "Settings",
    "UnitAffectingCombat",
    "UnitCanAttack",
    "UnitDetailedThreatSituation",
    "UnitInParty",
    "UnitThreatLeadSituation",
    "UnitThreatSituation",
}

globals = { "NameplateThreatColorDB" }

files["tests/Helpers.lua"] = {
    new_read_globals = {},
    globals = {
        "GAINING_THREAT_COLOR",
        "HIGH_THREAT_COLOR",
        unpack(read_globals),
    },
    self = false,
}
