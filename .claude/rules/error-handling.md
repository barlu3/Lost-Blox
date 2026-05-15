---
paths:
  - "src/server/**"
  - "src/shared/**"
---

# Anti-Cheat & Player Validation

- All game-state mutations must originate on the server. The client proposes; the server decides.
- Validate every RemoteEvent/RemoteFunction argument: type, range, and plausibility. Reject out-of-range or unexpected types immediately.
- Never trust client-reported position, velocity, health, or currency values. Compute or verify these server-side.
- Sanity-check movement speed and teleport distances. Flag or kick players whose deltas exceed physics limits.
- Use a server-side debounce per player per action to prevent rapid-fire RemoteEvent spam.
- Log suspicious patterns (impossible values, repeated edge-case inputs) with the player's UserId for later review. Never log PII beyond UserId.
- Never store authoritative game state in LocalScripts or ReplicatedStorage values the client can write.
- Wrap DataStore calls in `pcall`. On failure, retry with backoff; never silently drop the save.
