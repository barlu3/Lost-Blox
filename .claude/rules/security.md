---
paths:
  - "src/server/**"
---

# Security

- Always validate RemoteEvent/RemoteFunction arguments server-side — clients can fire with arbitrary values.
- Never trust client-provided player identity. Use `game:GetService("Players"):GetPlayerFromCharacter()` to resolve the player from the server.
- Never store sensitive data in ReplicatedStorage or any client-accessible instance tree.
- DataStore keys must be scoped per-player. Never allow one player's key to be derived from another's data.
- Never log or print player PII (UserId, username, IP) in production output.
- Rate-limit repeated RemoteEvent calls server-side to prevent abuse.
