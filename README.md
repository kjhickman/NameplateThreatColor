# NameplateThreatColor

A WoW: Forever addon for customizing the blizzard nameplate threat colors.

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
