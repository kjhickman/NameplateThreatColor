# NameplateThreatColor

A WoW: Forever addon for customizing the blizzard nameplate threat colors.

When you're tanking in a raid, **Co-tank holding aggro** marks enemies held by
another player assigned the Tank role. It defaults to blue and can be changed
or turned off with **Show co-tank aggro color** in the addon settings,
independently of **Separate tank colors**.

## Development

Install [StyLua](https://github.com/JohnnyMorganz/StyLua) and
[Luacheck](https://github.com/lunarmodules/luacheck). Tests require Lua 5.1.

Run these commands from the repository root:

```sh
stylua .               # Format all Lua files
stylua --check .       # Check formatting without changing files
luacheck .             # Lint all Lua files
lua run_tests.lua      # Run tests
```
