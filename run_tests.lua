local helpers = dofile("tests/Helpers.lua")
assert(loadfile("tests/Nameplates.test.lua"))(helpers)
assert(loadfile("tests/Settings.test.lua"))(helpers)

print(helpers.tests .. " tests passed")
