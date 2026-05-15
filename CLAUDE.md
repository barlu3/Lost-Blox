# Project Instructions

## Commands

```bash
# Dev (sync to Roblox Studio)
rojo serve
```

## Architecture

- `src/client/` → StarterPlayerScripts (client-side Luau)
- `src/server/` → ServerScriptService (server-side Luau)
- `src/shared/` → ReplicatedStorage.Shared (shared modules)
- FilteringEnabled is on — server must validate all RemoteEvent/RemoteFunction input; never trust the client.

## Workflow

- Prefer fixing the root cause over adding workarounds
- When unsure about approach, use plan mode (`Shift+Tab`) before coding
