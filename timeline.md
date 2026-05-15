# Lost Blox — Development Timeline

**Project:** Lost Blox (working title)
**Strategy:** Option C → Option B (Prototype-validate → Scoped v1.0)
**Total horizon:** 18 months to v1.0 launch + ongoing seasonal cadence
**Team:** 3 devs + 1 animator (→3 animators by Q2)
**Stack:** Roblox Studio, Luau, Rojo, ProfileService, Claude Code via MCP
**Engine target:** Roblox client, PC-only at launch

---

## 0. Build Philosophy

```
┌──────────────────────────────────────────────────────────────┐
│  PHASE C (validate)   →   GATE   →   PHASE B (build v1.0)    │
│  Q1 (3 months)              ▼              Q2-Q6 (15 months) │
│  Prototype + measure   GO / NO-GO    Scoped MMO build        │
└──────────────────────────────────────────────────────────────┘
```

- **Phase C goal:** prove team can ship a fun 30-minute slice. If not, re-scope or pivot.
- **Phase B goal:** ship the 3-class / T0–T2 / 1-raid v1.0 defined in the master spec.
- **Hard rule:** no Phase B work begins until Phase C gate clears.

---

## 1. Quarterly Roadmap (high-level)

| Quarter | Months | Phase | Theme | Headline Deliverable |
|---|---|---|---|---|
| **Q1** | M0–M3 | C | Prototype | Playable vertical slice (T0 + 1 class + 1 boss) |
| **Q2** | M3–M6 | B | Pre-production | Design lock, pipeline tools, 3 classes scaffolded |
| **Q3** | M6–M9 | B | Alpha I | T0–T1 content live, 3 classes playable, honing v1 |
| **Q4** | M9–M12 | B | Alpha II | T2 content, 1 Guardian + 1 Abyss raid, engravings live |
| **Q5** | M12–M15 | B | Closed Beta | 1 Legion Raid (4-gate), economy live, NDA beta |
| **Q6** | M15–M18 | B | Soft Launch → v1.0 | Public launch, BP S0, marketing push |
| **Q7+** | M18+ | Seasonal | Live ops | New class + content every 12 weeks |

---

## 2. Q1 — Phase C: Prototype (M0–M3)

### Goals
- Prove the **core combat loop is fun** (30-minute slice).
- Validate **server-authoritative combat with client prediction** works on Roblox at acceptable latency ($\Delta t < 120$ms perceived).
- Measure **30-min retention rate** in closed playtest ($\geq 60\%$ = green light).
- Build minimal but **production-quality** systems — no throwaway code.

### Deliverables
- [ ] T0 prologue zone (1 map, ~10 min play)
- [ ] 1 fully playable class: **Ironclad** (Warrior, simplest to balance)
- [ ] 8 skills bound to Q/W/E/R/A/S/D/F
- [ ] 1 boss encounter (1-phase, 3 mechanics: AoE dodge, color match, DPS burn)
- [ ] Click-to-move + WASD toggle
- [ ] Top-down camera lock (`CFrame.Angles(-60°, 0, 0)`, 25-stud offset)
- [ ] Save system (ProfileService) — character slot + inventory
- [ ] Damage formula implementation server-side
- [ ] Closed playtest (10–20 testers, internal Discord)

### Claude Code Tasks (Q1)
Tasks ordered from most feasible/testable (no game session needed) to least (requires MCP or live game).

---

#### TASK_Q1_01: Scaffold Rojo project structure
> **Feasibility: High** — pure file/directory creation; verify with `find src/` immediately.

**Semantics:**
Creates the canonical directory layout that Rojo maps to Roblox services. The `default.project.json` file tells Rojo which `src/` subdirectory maps to which Roblox service (`ServerScriptService`, `ReplicatedStorage`, etc.). Getting this right now means all future tasks drop files into the correct location without rework.

`Types.luau` is the shared type manifest: it exports type aliases (`PlayerData`, `SkillDef`, `ItemStack`, `ProfileTemplate`) that both server and client require. Defining these early enforces a contract between modules.

**Implementation notes:**
- `default.project.json` must declare each service path explicitly; Rojo does not infer from folder names.
- `.gitignore`: ignore `*.rbxl`, `*.rbxlx`, `*.lock`, `.DS_Store`, Roblox auto-saves.
- `.vscode/settings.json`: set `"luau-lsp.sourcemap.enabled": true` and point to the Rojo sourcemap.
- `Types.luau` exports empty type stubs at first; fill in as other tasks define their shapes.

**Acceptance criteria:**
- `rojo serve` runs without errors against `default.project.json`.
- `find src/ -type d` matches the canonical tree in section 9 exactly.
- `Types.luau` exports at minimum: `PlayerData`, `SkillDef`, `ItemStack`.
- `.gitignore` blocks all Roblox binary files from being staged.

**Test approach:** `unit` — file existence checks, `rojo serve` smoke test.
**Depends on:** nothing.

---

#### TASK_Q1_06: ProfileService integration
> **Feasibility: High** — pure Luau logic; ProfileService can be mocked with a table that mirrors its API.

**Semantics:**
`ProfileManager` is the single point of contact for player persistence. It wraps ProfileService so the rest of the codebase never calls ProfileService directly.

On `Players.PlayerAdded`: call `ProfileStore:LoadProfileAsync(userId)`. This yields until the profile is loaded or the player leaves. If nil is returned (session lock timeout), kick the player with a friendly message. Once loaded, call `profile:Reconcile()` to add any keys present in `ProfileTemplate` but missing from the saved data — this is the schema migration path.

On `Players.PlayerRemoving`: call `profile:Save()` synchronously within the same frame, then `profile:Release()`. ProfileService's session lock prevents another server from loading the same profile until release completes.

`ProfileTemplate.luau` defines the default shape of a new profile. Every new field added here is automatically reconciled into existing profiles on next load.

**Implementation notes:**
- Never store the profile object outside `ProfileManager`. Expose only `GetData(player)` and `SetData(player, key, value)`.
- `Reconcile()` adds missing keys; it does not overwrite existing values. Safe to call every load.
- Wrap `LoadProfileAsync` in a timeout guard: if the player leaves before load completes, the profile reference is stale — check `profile ~= nil` before use.
- `ProfileTemplate` keys: `characterSlot` (number), `inventory` (array), `equippedItems` (table), `honing` (table), `questProgress` (table), `createdAt` (number).

**Acceptance criteria:**
- Loading the same player on two servers simultaneously results in one server receiving `nil` (session lock works).
- Adding a new key to `ProfileTemplate` causes it to appear in an existing profile on next load without wiping other data.
- `PlayerRemoving` completes `profile:Save()` before the function returns.
- Data persists across server restarts in Studio's `DataModel` save mode.

**Test approach:** `unit` with mocked ProfileService; integration test in Studio using two-server simulation.
**Depends on:** TASK_Q1_01.

---

#### TASK_Q1_07: Telemetry harness (retention measurement)
> **Feasibility: High** — pure event logging; output verifiable by reading the log table in tests.

**Semantics:**
`SessionLogger` collects structured events in-memory and flushes them out-of-band so it never blocks gameplay code. The goal is to measure the Gate G1 criteria: 30-min retention and skill/death patterns.

Every event has the same envelope: `{ event: string, userId: number, timestamp: number, data: table }`. The `data` field is event-specific. Events:
- `session_start`: `{ class: string, iLvl: number }`
- `session_end`: `{ duration_seconds: number, cause: "voluntary"|"kick"|"crash" }`
- `death`: `{ killer: string, zone: string, session_elapsed: number }`
- `boss_kill`: `{ boss_id: string, time_to_kill: number, party_size: number }`
- `skill_used`: `{ skill_id: string, hit: boolean, damage: number }`

Flush strategy: buffer events in `SessionLogger._queue`, flush every 60 seconds via a background task and immediately on `session_end`. Flush encodes the queue as JSON and sends via `HttpService:PostAsync` to an external endpoint (or prints in Studio).

**Implementation notes:**
- Use a module-level queue table, not per-player, to avoid memory leaks if player tables are cleaned up before flush.
- `HttpService:PostAsync` only works on live Roblox servers, not Studio. Gate the HTTP call behind `RunService:IsStudio()` check; in Studio, use `print(HttpService:JSONEncode(batch))` instead.
- Never log PII beyond `userId`. No usernames in events.
- Batch events per flush: send one POST with an array, not one POST per event.

**Acceptance criteria:**
- All 5 event types fire at the correct moment with the correct envelope shape.
- Flush executes within 5 seconds of `session_end`.
- In Studio mode, events print as valid JSON (parseable by `json.loads`).
- A 60-minute session produces `session_start` + `session_end` + all intermediate events in correct timestamp order.

**Test approach:** `unit` — mock players, trigger events, assert queue contents.
**Depends on:** TASK_Q1_01.

---

#### TASK_Q1_02: Implement server-auth combat skeleton
> **Feasibility: Medium-High** — core math and validation logic are unit-testable; requires mocking character state tables.

**Semantics:**
The server owns all combat resolution. The client fires a `CastSkill` RemoteEvent with `{ skillId: string, targetId: number }` and waits for the server to deal damage and respond. The client never writes health values.

**SkillRegistry** is a table of skill definitions keyed by `skillId`:
```
{
  id: string,
  cooldown: number,        -- seconds
  range: number,           -- studs
  damageMultiplier: number,
  resourceCost: number,
  targetType: "single"|"aoe"|"self"
}
```

**SkillExecutor** validates a cast in order:
1. Skill exists in registry.
2. Cooldown not expired (`os.clock() - lastCast[player][skillId] >= skill.cooldown`).
3. Target exists and is alive.
4. Target is within `skill.range` studs of caster (`(targetPos - casterPos).Magnitude`).
5. Caster has enough resource.

If any check fails, the cast is silently dropped (no error to client — don't leak validation logic). On success, call `DamageCalculator` and apply damage server-side.

**DamageCalculator** formula (Q1, no engravings):
```
damage = base_attack * skill.damageMultiplier * crit_modifier
crit_modifier = if (math.random() < crit_chance) then (1 + crit_damage) else 1
```
All stats read from server-side `CharacterStats[player]` table, never from client.

**Implementation notes:**
- Store `lastCast` and `CharacterStats` as server-side module tables, keyed by `Player` object (not userId — players are removed from the table on `PlayerRemoving`).
- `CastSkill` RemoteEvent fires from client; server has one `OnServerEvent` handler that calls `SkillExecutor`.
- Never expose `CharacterStats` to the client. Replicate only health values via a separate RemoteEvent or `Humanoid.Health`.

**Acceptance criteria:**
- Client cannot bypass cooldown: firing the RemoteEvent twice within the cooldown window results in the second cast being dropped.
- Client cannot bypass range: firing at a target 200 studs away when skill range is 20 results in no damage.
- Damage output matches formula within floating-point tolerance (±0.001).
- Mocked 1000-cast simulation shows crit rate within ±5% of `crit_chance`.

**Test approach:** `unit` with mocked RemoteEvent and character tables.
**Depends on:** TASK_Q1_01.

---

#### TASK_Q1_04: Top-down camera
> **Feasibility: Medium** — code is fully writable and reviewable; actual feel (lerp smoothness, zoom comfort) requires a game session.

**Semantics:**
`TopDownCamera` takes over the Roblox camera by setting `Camera.CameraType = Enum.CameraType.Scriptable` and updating `Camera.CFrame` each `RenderStepped`.

The desired camera position each frame:
```
local target = character.HumanoidRootPart.Position
local offset = Vector3.new(0, offset_studs * math.sin(PITCH_RAD), offset_studs * math.cos(PITCH_RAD))
local desired = CFrame.new(target + offset) * CFrame.Angles(PITCH_RAD, 0, 0)
Camera.CFrame = Camera.CFrame:Lerp(desired, LERP_ALPHA)
```
- `PITCH_RAD = -math.rad(60)` (looking down 60°)
- `offset_studs` starts at 25, clamped to `[18, 35]` by scroll wheel
- `LERP_ALPHA = 0.15` per frame (frame-rate-independent via `dt * TARGET_HZ * 0.15`)

Zoom: `UserInputService.InputChanged` fires on `Enum.UserInputType.MouseWheel`. Delta ±1 adjusts `offset_studs` by ±1.5 studs, clamped to `[18, 35]`.

Mouse pan (optional): if cursor is within 50px of screen edge, pan camera by shifting the `target` horizontally up to 20 studs. Disabled while in combat.

**Implementation notes:**
- Frame-rate-independent lerp: `alpha = 1 - (1 - BASE_ALPHA)^(dt * 60)`. At 60fps this equals `BASE_ALPHA`; at 30fps the camera keeps up.
- On module load, save `Camera.CameraType` and restore it on module cleanup (for Studio live-edit).
- The camera module should expose `enable()` and `disable()` so cutscenes can take control.

**Acceptance criteria:**
- Camera pitch locks at -60° ± 0.1° regardless of character orientation.
- Zoom range `[18, 35]` studs enforced; scrolling past limits does nothing.
- Camera does not jitter on a stationary character (lerp settles to exact target within 10 frames).
- `disable()` restores default Roblox camera behavior.

**Test approach:** `unit` for math (CFrame construction, zoom clamp); **game session required** for feel validation.
**Depends on:** TASK_Q1_01.

---

#### TASK_Q1_03: Click-to-move controller
> **Feasibility: Low-Medium** — `PathfindingService` only runs in Roblox runtime; anti-teleport validation requires server simulation; needs MCP or game session for integration test.

**Semantics:**
The client computes a path on click; the server validates movement speed to prevent teleport exploits. The two sides are decoupled: the client moves freely along the computed path, and the server periodically samples position to check for impossible movement.

**Client side (`ClickToMove.luau`):**
1. `UserInputService.InputBegan` on `MouseButton1` → raycast from camera through mouse position to find world hit.
2. Call `PathfindingService:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = false })`.
3. `path:ComputeAsync(HRP.Position, hitPosition)` — yields briefly.
4. If status is `PathStatus.Success`, iterate `path:GetWaypoints()` and call `Humanoid:MoveTo(waypoint.Position)` for each in sequence, yielding on `Humanoid.MoveToFinished`.
5. Cache last computed path per zone: store the path object keyed by `tostring(zoneId)`. Invalidate cache if zone geometry changes (server fires a `ZoneReloaded` RemoteEvent).
6. Any `WASD` input during path walk fires `cancelPath()`, which stops `MoveTo` and clears the waypoint iterator.

**Server side (speed validation in `MovementValidator.luau`):**
- Every 0.5 seconds, for each player: compute `delta = (currentPos - lastPos).Magnitude / 0.5`. Compare to `MAX_SPEED_STUDS_PER_SEC` (character's walk speed + 10% tolerance for network jitter).
- If `delta > MAX_SPEED * 1.2`, log to `SessionLogger` as a `teleport_flag` event and teleport player back to `lastPos`.

**Implementation notes:**
- `ComputeAsync` can fail silently if no navmesh exists. Check `path.Status` before iterating waypoints.
- NavMesh must be baked in the map. Ensure `NavigationMesh` part covers walkable areas.
- The client-side path is cosmetic only — the server does not trust waypoints sent by the client.

**Acceptance criteria:**
- Clicking an unreachable point (behind a wall with no navmesh gap) does not cause the character to walk through geometry.
- Pressing any WASD key while path-walking stops the path within 1 frame.
- Server rejects a position delta > 2× max walk speed and returns the player to last valid position.
- NavMesh cache is reused on repeated clicks to the same zone (no redundant `ComputeAsync` call within 5 seconds).

**Test approach:** **game session required** for PathfindingService and movement feel; server-side speed check is `unit`-testable with mock position data.
**Depends on:** TASK_Q1_01.

---

#### TASK_Q1_05: Boss AI v1 (state machine)
> **Feasibility: Low** — state transition logic is unit-testable, but telegraph visual timing, player-reaction windows, and mechanic "feel" require live game testing; most of the acceptance criteria are experiential.

**Semantics:**
The boss runs a server-side state machine. Each state is a module that exports `onEnter`, `onTick`, and `onExit`. The `BossController` holds the current state, calls `onTick` each heartbeat, and transitions based on return values.

**States:**
- `Idle`: boss stands at spawn. Transitions to `Approach` when any player enters aggro radius (40 studs).
- `Approach`: boss moves toward nearest player using `Humanoid:MoveTo`. Transitions to `Telegraph` when within melee range (6 studs) or skill range for ranged mechanics.
- `Telegraph`: boss plays wind-up animation; a semi-transparent `Part` (the "danger zone") appears at the attack position. Duration varies per mechanic (`0.8–1.8s`). Transitions to `Attack` after duration. Cannot be interrupted once entered.
- `Attack`: boss deals damage to all players inside the danger zone `Part`. Danger zone `Part` is destroyed. Transitions back to `Approach` or directly to next `Telegraph` based on attack pattern sequence.
- `Stagger`: boss is interrupted (triggered externally when stagger threshold HP is crossed). Brief 2s window where boss takes +50% damage. Transitions to `Approach` after duration.
- `Enrage`: triggered when boss HP < 30%. Modifiers: `moveSpeed *= 1.5`, `damageMultiplier *= 1.3`. Boss enters Enrage on transition; it does not leave Enrage.

**Mechanic table** (each boss defines a sequence):
```lua
{
  { name = "AoE Sweep",    telegraph = 1.2, radius = 10, shape = "circle" },
  { name = "Color Match",  telegraph = 1.8, radius = 5,  shape = "square", colorHint = true },
  { name = "DPS Burn",     telegraph = 0.8, radius = 20, shape = "ring",   checkThreshold = 0.15 },
}
```
The `BossController` cycles through the mechanic sequence, resetting to index 1 after the last mechanic.

**Implementation notes:**
- Danger zone `Part` is a `BasePart` with `CanCollide = false`, `Transparency = 0.5`, colored by mechanic type. Created in `Telegraph.onEnter`, destroyed in `Attack.onExit`.
- All damage dealt in `Attack` state is validated server-side: only players whose `HRP.Position` is inside the danger zone `Part` bounds take damage.
- Color Match mechanic: floor tiles change color. Correct tile defined in mechanic config. Players on wrong tile take damage on `Attack`; players on correct tile are immune.

**Acceptance criteria:**
- Telegraph Part appears ≥ 0.8s before damage resolves (measured via `os.clock()` delta in unit test).
- Boss transitions from `Idle` → `Approach` when a mock player enters 40-stud radius.
- Enrage modifier applies exactly once (not stacked on subsequent HP checks).
- Boss does not deal damage to players outside the danger zone Part bounds.

**Test approach:** state transition logic is `unit`-testable with mock players; **game session required** for telegraph timing feel, mechanic clarity, and difficulty calibration.
**Depends on:** TASK_Q1_01, TASK_Q1_02.

---

### Decision Gate G1 (end of M3)
Proceed to Phase B **only if all 4 conditions hold**:

| # | Criterion | Threshold |
|---|---|---|
| G1.1 | 30-min retention | $\geq 60\%$ |
| G1.2 | Combat feels good (tester survey, 1–10) | mean $\geq 7.0$ |
| G1.3 | Server tick stable at 8-player load | $\geq 30$ Hz |
| G1.4 | Exploitable hits found | $\leq 2$ critical |

**If any fails:** stop. Diagnose. Re-prototype before committing 15 more months.

---

## 3. Q2 — Phase B: Pre-Production (M3–M6)

### Goals
- Lock final v1.0 design across all systems.
- Build the **content pipeline** (tools that let designers add content without programmer time).
- Scaffold remaining 2 classes.
- Hire/onboard if Phase C revealed bandwidth gaps.

### Deliverables
- [ ] Final Design Doc v1.0 (locked, change-controlled from here)
- [ ] Content tooling: class definition CSV/JSON → in-game skill registry
- [ ] **Stormcaller** class implemented (Mage)
- [ ] **Skystrike** class implemented (Martial Artist)
- [ ] Engraving system architecture (no content yet)
- [ ] Honing system architecture (no UI yet)
- [ ] Inventory + accessory slot system
- [ ] Realm 1 of T1 designed (greybox)

### Claude Code Tasks (Q2)
Tasks ordered from most feasible/testable to least.

---

#### TASK_Q2_03: Engraving system core
> **Feasibility: High** — pure math and data lookup; fully unit-testable with no game session.

**Semantics:**
Engravings are passive modifiers that a player accumulates points in (0–15 per engraving). At 5, 10, and 15 points, a tier activates (Tier 1/2/3), each applying a stronger effect. The system resolves before damage is calculated.

Each player's `ProfileData` stores `{ engravings: { [engraving_id]: number } }`. The `EngravingResolver` takes the player's engraving book and the skill being cast, and returns a `modifier` table that `DamageCalculator` applies.

Engraving definitions live in `ReplicatedStorage/Configs/Engravings/*.json`:
```json
{
  "id": "keen_blunt",
  "tiers": [
    { "threshold": 5,  "type": "crit_rate",    "value": 0.04 },
    { "threshold": 10, "type": "crit_rate",    "value": 0.10 },
    { "threshold": 15, "type": "crit_rate",    "value": 0.20 }
  ]
}
```

`EngravingResolver.resolve(engravings, skillId)` iterates all active engravings, finds the highest activated tier for each, and accumulates modifiers:
- `damage_add`: flat additive bonus, summed.
- `damage_mul`: multiplicative, chained as `(1 + a) * (1 + b) - 1` (not `a + b`).
- `crit_rate`: additive, capped at 1.0 total.
- `crit_damage`: additive.

Negative engravings (penalty book entries) use the same schema but with negative `value`. They always apply; players choose how many penalty points to accept.

**Implementation notes:**
- Resolver is a pure function: `resolve(engravingBook, skillId) → modifierTable`. No side effects, no state.
- Tier lookup: iterate thresholds in descending order, return first that `points >= threshold`. If none, tier 0 (no bonus).
- Engravings that apply only to specific skill types check `skillId` against a `filter` field in the JSON.

**Acceptance criteria:**
- `resolve({ keen_blunt = 10 }, "any_skill")` returns `{ crit_rate = 0.10 }`.
- `resolve({ keen_blunt = 15 }, "any_skill")` returns `{ crit_rate = 0.20 }` (highest tier only, not cumulative).
- Two `damage_mul` engravings of 0.1 each yield `0.21`, not `0.20`.
- Penalty engraving with -0.15 at 5 pts applied when player has ≥ 5 pts in that engraving.

**Test approach:** `unit` — pure function with table inputs.
**Depends on:** TASK_Q1_01, TASK_Q1_02.

---

#### TASK_Q2_04: Honing math implementation
> **Feasibility: High** — pure math with a lookup table; formula and pity logic are fully unit-testable.

**Semantics:**
Honing upgrades equipment item level in steps (`+1`, `+2`, ...). Each attempt has a base success probability `P_base(tier, level)` defined in a design doc table. On failure, a pity counter increments and a flat bonus `pity_bonus` is added to the next attempt's probability. When `pity_counter >= MAX_PITY`, the next attempt is guaranteed to succeed.

`HoningCalculator.attempt(player, itemId, materials)`:
1. Look up item's current `{ tier, level, pity_counter, pity_bonus }` from `ProfileData`.
2. Validate player has required `materials` in inventory. If not, return `{ success = false, reason = "insufficient_materials" }` without modifying state.
3. Deduct materials atomically (within a single ProfileService write operation).
4. Compute `P_attempt = math.min(P_base(tier, level) + pity_bonus, 1.0)`.
5. Roll `math.random()`:
   - If `pity_counter >= MAX_PITY` or roll ≤ `P_attempt`: success → `level += 1`, reset `pity_counter = 0`, `pity_bonus = 0`.
   - Else: failure → `pity_counter += 1`, `pity_bonus += PITY_INCREMENT(tier)`.
6. Return `{ success: boolean, new_level: number, pity_counter: number }`.

Material consumption is atomic: deduct materials and write the attempt result in a single `profile:Set()` call so a server crash mid-attempt cannot consume materials without recording the outcome.

**Implementation notes:**
- `P_base` is a 2D table: `P_BASE[tier][level]`. Example: T0+1 = 0.80, T0+10 = 0.15, T1+10 = 0.10.
- `PITY_INCREMENT` is per-tier (higher tiers have smaller increments, requiring more failures before pity kicks in).
- Never call `math.randomseed` inside this module; the caller sets the seed for determinism in tests.
- This module is server-only; the client gets results via a RemoteFunction response.

**Acceptance criteria:**
- Force-success triggers exactly when `pity_counter >= MAX_PITY`, not before.
- A simulated 10,000-attempt run at `P_base = 0.20` with pity yields observed success rate within ±2% of theoretical with-pity rate.
- Insufficient materials returns error without modifying the item's pity state.
- Deducting materials and recording the attempt result cannot be split across two separate writes.

**Test approach:** `unit` — mock profile, seeded `math.random`, simulate sequences.
**Depends on:** TASK_Q1_06, TASK_Q2_05.

---

#### TASK_Q2_01: Class authoring tool
> **Feasibility: Medium-High** — Python validation tool is testable standalone; Roblox hot-reload on join needs a game session to verify.

**Semantics:**
Designers define a class by filling out a JSON file in `ReplicatedStorage/Configs/Classes/`. The Python tool validates the JSON against a schema and reports errors before the file is committed. The Roblox runtime loads all class JSONs at server start and registers them in `SkillRegistry`.

**JSON schema** (validated by `tools/class_builder/validate.py`):
```json
{
  "id": "ironclad",
  "display_name": "Ironclad",
  "resource_type": "fury",
  "resource_max": 100,
  "identity": {
    "skill_id": "shield_charge",
    "resource_threshold": 100
  },
  "skills": [
    {
      "id": "heavy_strike",
      "key": "Q",
      "cooldown": 4.0,
      "range": 8,
      "damage_multiplier": 1.8,
      "resource_cost": 10,
      "target_type": "single"
    }
  ]
}
```

Validation checks: all `skill_id` references exist in the `skills` array, `cooldown > 0`, `resource_cost <= resource_max`, `key` values are unique within the class, `target_type` is one of `"single"|"aoe"|"self"`.

On Roblox server start, a script in `ServerScriptService/Combat/ClassLoader.luau` iterates all `*.json` files in `ReplicatedStorage/Configs/Classes/`, decodes each, and calls `SkillRegistry.register(classId, skillDef)` for every skill in the class.

**Implementation notes:**
- `validate.py` exits with code 1 and prints errors if schema fails; exit 0 on success. This lets CI block a PR on invalid class JSON.
- `ClassLoader` uses `require(script.Parent.SkillRegistry)` — not `game.ServerScriptService` path — to avoid hard-coded service traversal.
- Hot-reload is not truly hot (Roblox does not hot-reload server scripts); "on join" means the class data is fresh each time a new server starts.

**Acceptance criteria:**
- `python validate.py Classes/Ironclad.json` exits 0 for a valid file.
- A file with a duplicate key binding (`Q` used twice) causes `validate.py` to exit 1 with a message naming the duplicate.
- After placing a new valid `*.json` in the Classes folder and running `rojo serve`, the class appears in `SkillRegistry` on server start (verified via print log).

**Test approach:** `unit` for Python validator (pytest with fixture JSON files); **game session required** for Roblox runtime loading verification.
**Depends on:** TASK_Q1_01, TASK_Q1_02.

---

#### TASK_Q2_05: Inventory system
> **Feasibility: Medium** — stack math, equip/unequip logic, and stat recompute are unit-testable; inventory UI requires a game session.

**Semantics:**
`InventoryManager` manages the player's item storage and equipped loadout. All mutations happen server-side; the client receives a replicated snapshot after each change.

**Profile shape:**
```lua
inventory = {
  { id = "iron_sword", quantity = 1, quality = 72, iLvl = 302 },
  { id = "mana_shard", quantity = 47, quality = 0, iLvl = 0 },
}
equipped = {
  weapon = { id = "iron_sword", quality = 72, iLvl = 302 },
  head = nil, chest = nil, legs = nil,
  accessory1 = nil, accessory2 = nil,
}
```

**`AddItem(player, itemDef)`:**
- If `itemDef.stackable = true`: find existing stack with same `id` and `quality`, increment `quantity`. If none found, append new entry.
- If `stackable = false`: append new entry regardless.
- Cap inventory at `MAX_SLOTS = 120` total entries. Return `false` if full.

**`EquipItem(player, inventoryIndex, slot)`:**
- Validate `slot` is a valid slot name.
- If `equipped[slot]` is occupied, swap it back into inventory (find first empty slot or return if full).
- Move item from `inventory[inventoryIndex]` to `equipped[slot]`.
- Call `StatRecomputer.recompute(player)` to recalculate all stats from equipped items + engravings.
- Replicate new `equippedSnapshot` and `statSnapshot` to client via RemoteEvent.

**`StatRecomputer.recompute(player)`:** sums base stats + all equipped item stats + engraving bonuses → writes to server-side `CharacterStats[player]`. This is the single source of truth for `DamageCalculator`.

**Implementation notes:**
- Equip/unequip is a single atomic profile write: both the inventory array and equipped table change together.
- Never expose the raw `inventory` array to the client. Send a sanitized snapshot (strip internal indices).

**Acceptance criteria:**
- Adding 50 stackable items of the same type produces 1 inventory entry with `quantity = 50`, not 50 entries.
- Equipping an item when a slot is occupied moves the old item to inventory without item loss.
- `StatRecomputer` is called exactly once per equip action (not multiple times).
- A client cannot equip an item it doesn't own (server re-validates inventory ownership before equipping).

**Test approach:** `unit` for all mutation functions; **game session required** for UI.
**Depends on:** TASK_Q1_06, TASK_Q1_01.

---

#### TASK_Q2_02: Stormcaller + Skystrike implementation
> **Feasibility: Low-Medium** — resource accumulation math is unit-testable; class feel, visual identity, and balance require live game testing.

**Semantics:**
Each class has a **resource type** (distinct from the generic Fury used by Ironclad) and an **identity skill** that consumes the resource for a powerful effect.

**Stormcaller (Mage) — Arcana:**
- `Arcana`: float `0–100`, starts at 0, does not regenerate passively.
- Builder skills (low-damage, quick cooldowns): each hit generates `+8 Arcana`.
- Spender skills: cost `20–40 Arcana`. If player has insufficient Arcana, the cast is rejected server-side.
- Identity skill "Arcane Surge": requires `Arcana = 100`, drains to 0, triggers a 6-second buff that increases all damage by 30% and reduces skill cooldowns by 50%.
- Arcana replicates to client each change so the resource bar stays accurate.

**Skystrike (Martial Artist) — Chi:**
- `Chi`: integer `0–3`, starts at 0.
- Builder skills add `+1 Chi` stack on successful hit (not on cast — must connect).
- Spender skills consume all current Chi stacks. Damage scales: `base * (1 + 0.25 * chi_count)`. If `chi_count = 0`, spender deals base damage with no bonus (not rejected).
- Identity skill "Tiger's Wrath": requires `Chi >= 3`, consumes all 3, deals a high-damage combo finisher. Server validates Chi count before resolving.
- Chi resets to 0 on player death.

**Implementation notes:**
- Resource state lives in `CharacterStats[player].resource` on the server, not in the profile (it resets on death/relog).
- Arcana identity skill buff is tracked as a timed effect in `ActiveEffects[player]`: `{ effect = "arcane_surge", expiresAt = os.clock() + 6 }`. `DamageCalculator` checks active effects before resolving.
- Chi stacks must be validated on the server before the spender resolves — the client reporting Chi count is not trusted.

**Acceptance criteria:**
- Stormcaller casting a builder 13 times accumulates exactly `104 Arcana` (capped at `100`).
- Stormcaller cannot cast a 40-Arcana spender with 30 Arcana.
- Skystrike spender at 3 Chi stacks deals `base * 1.75` damage.
- Skystrike Chi resets to 0 on `Humanoid.Died`.

**Test approach:** `unit` for resource math; **game session required** for balance and feel.
**Depends on:** TASK_Q1_02, TASK_Q2_01.

---

### Risks Q2
- **Animator pipeline ramp-up** — 2 devs learning Blender will be slow Q2. Plan buffer.
- **Designer/programmer bandwidth split** — tooling for designers takes programmer time. Don't skip it; pay now or pay 3× later.

---

## 4. Q3 — Phase B: Alpha I (M6–M9)

### Goals
- Make T0 + T1 fully playable end-to-end.
- All 3 launch classes feel distinct and balanced (rough pass).
- Honing live with material economy.

### Deliverables
- [ ] T0 polished (final pass)
- [ ] T1 zones complete (Realm 1, Realm 2)
- [ ] Main story quests for T0–T1
- [ ] 2 Chaos Dungeon tiers
- [ ] 1 Guardian Raid (4-player)
- [ ] Honing UI + flow
- [ ] All 3 classes balanced to within $\pm 10\%$ DPS at iLvl 600
- [ ] First closed alpha (50 testers)

### Claude Code Tasks (Q3)
Tasks ordered from most feasible/testable to least.

---

#### TASK_Q3_04: Dialogue system (Sans-blip voice)
> **Feasibility: High** — text reveal logic, blip timing, and history scrollback are unit-testable; visual/audio feel requires a game session.

**Semantics:**
`DialogueBox` is a LocalScript UI module. It presents a conversation sequence: a series of `{ speaker, text, portrait }` entries. Text types out character-by-character to create the typewriter effect.

**Text reveal:** iterate characters at a rate of 1 char per `0.025s` (40 chars/sec) using `task.wait()`. Each frame append the next character to the visible `TextLabel.Text`.

**Voice blips:** on each character appended, check if the character is a vowel (`a, e, i, o, u`, case-insensitive):
- Play the NPC's assigned voice `Sound` object.
- Vowels: `Sound.Volume = 1.1`, `Sound.PlaybackSpeed = NPC_PITCH ± math.random() * 0.05`.
- Consonants: `Sound.Volume = 1.0`, same pitch variation.
- Punctuation and spaces: no sound.

**Skip / advance:** `UserInputService.InputBegan` on any key or mouse click during reveal → instantly show full text (set `TextLabel.Text = full_text`, cancel the character loop). A second press on a completed line → advance to next entry.

**History:** each completed line is appended to a scrolling `ScrollingFrame` above the active line. Player can scroll up to re-read. History is cleared on dialogue end.

**NPC pitch constant:** defined in the NPC's server config JSON `{ "voice_pitch": 1.2 }`. Replicated to client on dialogue start via a RemoteEvent so `DialogueBox` doesn't need to query the server mid-playback.

**Implementation notes:**
- The dialogue sequence is driven by a queue: `DialogueBox.playSequence(entries)` takes a table of entries and plays them in order.
- Cancel the character-reveal coroutine cleanly: use a `running` boolean flag; the loop checks it each iteration.
- Do not play a sound for the same character more than once per `0.025s` to avoid audio spam on fast CPUs.

**Acceptance criteria:**
- 40-character line completes reveal in `1.0s ± 0.05s`.
- Vowels trigger a sound at volume `1.1`; consonants at `1.0`; spaces trigger no sound.
- Pressing any key during reveal instantly shows full text without playing remaining blips.
- History scrollback shows all previous lines in the current dialogue session.

**Test approach:** `unit` for blip triggering logic (mock Sound, mock input); **game session required** for audio feel and visual timing.
**Depends on:** TASK_Q1_01.

---

#### TASK_Q3_03: Quest system
> **Feasibility: Medium-High** — tracking, completion, and reward distribution are unit-testable; NPC interaction and dialogue integration need a game session.

**Semantics:**
`QuestManager` is a server-side module. Quests are defined in JSON, tracked in the player's profile, and completed when all objectives are met. The system is event-driven: other systems (combat, inventory, movement) fire events to `QuestManager`, which checks all active quests for matching objectives.

**Quest definition JSON:**
```json
{
  "id": "find_the_herald",
  "name": "Find the Herald",
  "objectives": [
    { "id": "kill_scouts", "type": "kill", "target": "void_scout", "count": 5 },
    { "id": "reach_waypoint", "type": "reach", "target": "herald_shrine_zone" }
  ],
  "rewards": [
    { "type": "item", "id": "iron_sword", "quantity": 1 },
    { "type": "exp", "amount": 500 }
  ]
}
```

**Profile shape:**
```lua
activeQuests = {
  find_the_herald = {
    progress = { kill_scouts = 3, reach_waypoint = false },
    startedAt = 1700000000
  }
}
completedQuests = { "intro_prologue" }
```

**Event flow:**
- `QuestManager.onMobKilled(player, mobId)`: iterate active quests, find `kill` objectives matching `mobId`, increment `progress[obj.id]`. Check completion.
- `QuestManager.onZoneReached(player, zoneId)`: find `reach` objectives matching `zoneId`, set `progress[obj.id] = true`. Check completion.
- `checkCompletion(player, questId)`: if all objectives met → call `grantRewards(player, quest)`, move quest to `completedQuests`, fire `QuestCompleted` RemoteEvent to client.

**grantRewards:** calls `InventoryManager.AddItem` for item rewards, directly mutates `CharacterStats.exp` for exp rewards. All changes are batched into a single profile write.

**Implementation notes:**
- `QuestManager` subscribes to a server-side event bus (a `BindableEvent`) rather than being called directly from combat code. This keeps `CombatResolver` from importing `QuestManager`.
- Duplicate objective completion (killing the same mob twice rapidly) is prevented by checking `progress[obj.id] < obj.count` before incrementing.

**Acceptance criteria:**
- Killing 5 `void_scout` mobs while `find_the_herald` is active marks `kill_scouts` complete.
- Completing all objectives fires exactly one `QuestCompleted` event (not once per objective).
- Rewards are granted atomically: if server crashes mid-reward, the quest is not marked complete and rewards are not partially granted.
- A quest already in `completedQuests` cannot be started again.

**Test approach:** `unit` with mock event bus and mock InventoryManager; **game session required** for NPC dialogue integration.
**Depends on:** TASK_Q1_06, TASK_Q2_05, TASK_Q3_04.

---

#### TASK_Q3_02: Guardian Raid framework
> **Feasibility: Medium** — HP scaling formula and wipe logic are unit-testable; 4-player matchmaking, TeleportService, and actual raid feel require a game session.

**Semantics:**
Guardian Raids are instanced 4-player boss fights. Players queue via a UI, the server forms a party when enough players are ready, and `TeleportService` sends them to a private server running the raid.

**HP scaling:** `HP_final = HP_base * (1 + 0.875 * (n - 1))` where `n` is the number of players who entered the raid (1–4). `n` is locked at teleport time and does not change if a player disconnects mid-raid.

**Matchmaking:**
- Player clicks "Find Party" → server writes `{ userId, iLvl, timestamp }` to a `MemoryStoreService` sorted map keyed by `os.time()`.
- A polling loop runs every 10 seconds: read entries from the map, group into parties of ≤ 4 by iLvl proximity (max ±100 iLvl range). If a group is found, remove entries from the map and call `TeleportService:TeleportAsync`.
- Solo queueing is allowed; `n = 1` is valid.

**In-raid flow:**
- Raid server is a separate place. On `Players.PlayerAdded`, the raid server reads `TeleportData` to know the raid config (boss_id, player_count).
- `GuardianRaid` module runs the boss (uses the same state machine from TASK_Q1_05).
- **Wipe:** all players `Humanoid.Health == 0` → respawn all players at the raid entrance `SpawnLocation`, boss HP is retained (no reset on wipe).
- **Hard timer:** 20-minute countdown starts on first player spawn. On expiry → fire `RaidFailed` event, teleport all players back to the overworld lobby.

**Implementation notes:**
- Use `MemoryStoreService:GetSortedMap` for the queue, not `DataStoreService` — queue entries are transient and must expire.
- Set a 5-minute TTL on queue entries so disconnected players don't block matchmaking.
- The raid place must be published separately; store `RAID_PLACE_ID` in a server config module.

**Acceptance criteria:**
- `HP_final` for 4 players at `HP_base = 10000` equals `41250`.
- A solo player completes matchmaking and enters the raid (no hang waiting for 4 players).
- Wipe resets all player positions to the entrance but retains boss HP at the value it was when the last player died.
- A raid running past 20 minutes terminates with no reward and returns players to the lobby.

**Test approach:** `unit` for HP formula and wipe condition; **game session required** for matchmaking flow and TeleportService.
**Depends on:** TASK_Q1_05, TASK_Q1_06.

---

#### TASK_Q3_01: Chaos Dungeon generator
> **Feasibility: Low-Medium** — loot table math and phase-transition logic are unit-testable; phase spawning, visual score display, and timer UI require a game session.

**Semantics:**
Chaos Dungeons are solo/party timed instances with 3 phases. Each run uses the same map layout but randomizes mob positions and elite placement. The system rewards players based on iLvl and score multiplier.

**Phase structure:**
- **Phase 1 (Clear):** spawn `N` mobs from `spawn_points`. Player must kill all mobs. Phase ends when mob count = 0. Time bonus: `remaining_seconds * 10` points per second.
- **Phase 2 (Elite):** spawn 1 elite (miniboss). Kill it within a sub-timer (3 min). Failure skips Phase 3 with reduced reward.
- **Phase 3 (Boss):** spawn the dungeon boss. Kill it for full reward. Boss HP scales with player count (same formula as Guardian Raid).

**Score:** `score = base_score + time_bonus + kill_chain_bonus`. `kill_chain_bonus`: each consecutive kill within 5 seconds of the last adds `+50` points. Breaking the chain resets it.

**Loot:** `LootTable.roll(tier, player_iLvl)` is called once per phase completion. Rewards scale:
- Phase 1 completion: honing materials.
- Phase 2 completion: accessory or ability stone.
- Phase 3 completion: rare accessory + bonus honing materials.
- iLvl gate: items below `player_iLvl - 50` are excluded from the roll.

**Config JSON** (`ReplicatedStorage/Configs/ChaosTiers/T0.json`):
```json
{
  "tier": 0,
  "ilvl_min": 0,
  "ilvl_max": 299,
  "mob_count": 30,
  "elite_hp_multiplier": 2.5,
  "time_limit_seconds": 600,
  "loot_table_id": "chaos_t0"
}
```

**Implementation notes:**
- Mob spawning uses a pre-defined `SpawnPoints` folder in the map, not random positions, to avoid geometry clipping.
- Phase transitions are event-driven: when the mob counter reaches 0, fire `PhaseComplete`. Do not poll the mob count every heartbeat.
- The dungeon runner module lives entirely on the server. The client UI only receives score and phase updates via RemoteEvent.

**Acceptance criteria:**
- Phase 1 ends within 1 server frame of the last mob dying.
- Score increases by exactly `50` per consecutive kill when chain is active; resets to 0 on a 5-second gap.
- `LootTable.roll` excludes items below `player_iLvl - 50` (unit-testable).
- A Tier 0 dungeon with `ilvl_min = 0` is accessible to a player at iLvl 100 but not an iLvl-300 character (iLvl gate enforced on dungeon entry, not just loot).

**Test approach:** `unit` for loot table and score math; **game session required** for phase spawning, timer UI, and boss feel.
**Depends on:** TASK_Q1_05, TASK_Q2_05, TASK_Q4_02.

---

### Decision Gate G2 (end of M9)
| # | Criterion | Threshold |
|---|---|---|
| G2.1 | All 3 classes balanced | DPS variance $\leq 10\%$ |
| G2.2 | T0–T1 completable in <8h | Alpha tester median |
| G2.3 | Server stable at 8p combat | $\geq 30$ Hz |
| G2.4 | Critical bugs open | $\leq 5$ |

---

## 5. Q4 — Phase B: Alpha II (M9–M12)

### Goals
- Add T2 content (mid-game).
- Ship engraving system with content.
- Add 1 Abyss Dungeon (4p scripted).
- Internal pre-beta.

### Deliverables
- [ ] T2 zones (Realm 3, Realm 4)
- [ ] iLvl progression 600 → 1100
- [ ] 6 engravings fully content-complete
- [ ] 1 Abyss Dungeon (3-room, mechanic-gated)
- [ ] Card system architecture (defer content)
- [ ] Accessory drop tables tuned

### Claude Code Tasks (Q4)
Tasks ordered from most feasible/testable to least.

---

#### TASK_Q4_02: Accessory + drop table system
> **Feasibility: High** — weighted random and quality roll are pure math; fully unit-testable with seeded randomness.

**Semantics:**
`LootTable` is a pure module: given a table definition, an iLvl gate, and a seed, it returns a deterministic item drop.

**Table definition (`ReplicatedStorage/Configs/Loot/chaos_t1.json`):**
```json
{
  "id": "chaos_t1",
  "entries": [
    { "id": "void_necklace",   "weight": 10, "min_ilvl": 600 },
    { "id": "storm_earring",   "weight": 15, "min_ilvl": 600 },
    { "id": "shadow_ring",     "weight": 20, "min_ilvl": 600 },
    { "id": "honing_shard_t1", "weight": 55, "min_ilvl": 0   }
  ]
}
```

**Drop algorithm:**
1. Filter entries: remove any with `min_ilvl > player_iLvl`.
2. Normalize remaining weights to cumulative probabilities.
3. Roll `rng.nextNumber()` in `[0, 1]`, walk the cumulative array to find the selected entry.
4. Roll quality: `quality = math.floor(rng.nextNumber() * 100)`. Quality affects stat values on the item.

**Seeded RNG:** `LootTable.new(seed)` creates an instance wrapping Roblox's `Random.new(seed)`. Default seed for live play: `os.time() + player.UserId`. For replay testing: explicit seed.

**Quality buckets** (used by display and stat scaling):
- 0–30: Common (grey)
- 31–60: Uncommon (green)
- 61–85: Rare (blue)
- 86–99: Epic (purple)
- 100: Legendary (gold) — 1-in-100 chance

**Implementation notes:**
- Never call `math.random()` directly in this module. All randomness flows through the injected `Random` instance for testability.
- Normalize weights after filtering to avoid skewed probabilities when high-iLvl entries are removed.
- The module is pure: no profile reads, no RemoteEvents. Callers (ChaosDungeonRunner, GuardianRaid, etc.) call `roll()` and pass the result to `InventoryManager.AddItem`.

**Acceptance criteria:**
- With seed 12345, `roll("chaos_t1", 700)` returns the same item every time.
- Entries with `min_ilvl = 600` are excluded when `player_iLvl = 400`.
- After filtering, weights renormalize: if total remaining weight is 45, a weight-15 entry has probability `15/45`, not `15/100`.
- Simulated 100,000 rolls with seed range produces legendary quality in `1.0% ± 0.2%` of rolls.

**Test approach:** `unit` — seeded Random, assertion on output.
**Depends on:** TASK_Q1_01.

---

#### TASK_Q4_03: Tripod system v1
> **Feasibility: High** — pure modifier lookup and application; fully unit-testable.

**Semantics:**
Each skill has one tripod slot (simplified from Lost Ark's 3). The player equips one of three options for each skill's tripod, stored in the profile. `TripodResolver` applies the modifier before `DamageCalculator` resolves.

**Tripod definition** (inline in the skill's class JSON):
```json
{
  "skill_id": "heavy_strike",
  "tripod": {
    "options": [
      { "id": "crushing_blow",  "type": "damage",   "value": 0.20 },
      { "id": "wide_arc",       "type": "aoe_radius","value": 0.30 },
      { "id": "rapid_recovery", "type": "cooldown",  "value": -0.15 }
    ]
  }
}
```

**`TripodResolver.resolve(skillDef, equippedTripodId)`:**
- Find the tripod option with matching `id` in `skillDef.tripod.options`.
- Apply to a copy of `skillDef` (never mutate the registry definition):
  - `"damage"`: `skillCopy.damageMultiplier *= (1 + value)`
  - `"cooldown"`: `skillCopy.cooldown *= (1 + value)` (negative value = shorter cooldown)
  - `"aoe_radius"`: `skillCopy.aoeRadius *= (1 + value)` (add `aoeRadius` field if not present)
- Return the modified copy.

**Profile shape:** `equippedTripods = { heavy_strike = "crushing_blow", storm_lance = "chain_lightning" }`. One entry per skill that has a tripod option equipped.

**Implementation notes:**
- `TripodResolver` is a pure function operating on copies. The `SkillRegistry` definitions are immutable constants.
- If a player has no tripod equipped for a skill, `resolve` returns the unmodified `skillDef`.
- `SkillExecutor` calls `TripodResolver.resolve` after looking up the skill definition but before passing to `DamageCalculator`.

**Acceptance criteria:**
- `resolve` with `crushing_blow` (0.20 damage) on a `damageMultiplier = 1.5` skill returns `damageMultiplier = 1.80`.
- `resolve` with `rapid_recovery` (-0.15 cooldown) on a `cooldown = 4.0` skill returns `cooldown = 3.40`.
- `resolve` does not modify the original `SkillRegistry` definition.
- A skill with no tripod equipped returns the base skill definition unchanged.

**Test approach:** `unit` — pure function.
**Depends on:** TASK_Q1_02, TASK_Q2_01.

---

#### TASK_Q4_01: Abyss Dungeon scripting framework
> **Feasibility: Low-Medium** — Python mechanic authoring tool is testable standalone; dungeon execution, mechanic timing, and player comprehension require a game session.

**Semantics:**
Abyss Dungeons are scripted 4-player instances where each room has a mandatory mechanic that must be solved correctly to proceed. Failing a mechanic causes a room wipe; the party retries from the room start. Unlike Chaos Dungeons, there is no RNG phase — every mechanic is deterministic and teaches a specific pattern.

**Mechanic primitives library (`ServerScriptService/Content/AbyssRunner/Mechanics/`):**
- `ColorMatch.luau`: tiles on the floor light up in colors. One color is marked "safe". Players must stand on the safe color before `detonation_time`. Players on wrong color take lethal damage.
- `PillarPhase.luau`: several pillars appear. All pillars must be destroyed within `time_limit` seconds. Failure = wipe.
- `DPSCheck.luau`: boss must be reduced to a HP threshold within `time_limit`. Failure = wipe with "Raid Enrage" screen message.

**Dungeon definition JSON (`ReplicatedStorage/Configs/AbyssDungeons/abyss_d1.json`):**
```json
{
  "id": "abyss_d1",
  "rooms": [
    {
      "id": "room_1",
      "boss_id": "dungeon_warden",
      "mechanics": [
        { "type": "ColorMatch",  "trigger_hp": 0.80, "detonation_time": 6 },
        { "type": "DPSCheck",    "trigger_hp": 0.50, "threshold": 0.35, "time_limit": 30 },
        { "type": "PillarPhase", "trigger_hp": 0.20, "pillar_count": 4, "time_limit": 45 }
      ]
    }
  ]
}
```

`AbyssRunner` loads the room definition and passes `trigger_hp` checks to the boss HP watcher. When a trigger fires, `AbyssRunner` hands control to the mechanic module, which runs its logic and returns `success` or `fail`. On `fail`, `AbyssRunner` calls `wipeRoom()`: kill all players, reset boss HP to room-start HP, respawn party at room entrance.

**Python authoring tool (`tools/mechanic_authoring/`):** validates Abyss JSON against the schema, checks that `trigger_hp` values are in descending order (mechanics can't trigger out of sequence), and checks all referenced `boss_id` values exist in the boss registry CSV.

**Implementation notes:**
- Mechanic modules are loaded dynamically: `require(script.Parent.Mechanics[mechanic.type])`. This allows adding new primitive types without modifying `AbyssRunner`.
- `wipeRoom()` must reset the boss to its room-start HP, not its total HP. Store `room_start_hp` on room entry.
- Mechanic timing uses `task.delay` not `wait()` for precision.

**Acceptance criteria:**
- `validate.py abyss_d1.json` catches `trigger_hp` values in non-descending order and exits 1.
- A ColorMatch mechanic with `detonation_time = 6` deals lethal damage to players on wrong tiles exactly 6 seconds after trigger (±0.1s, unit-testable with mocked `task.delay`).
- A room wipe resets boss HP to the HP it had at room entry, not global boss HP.
- Adding a new mechanic type by creating a new `.luau` file in `Mechanics/` requires zero changes to `AbyssRunner.luau`.

**Test approach:** `unit` for Python validation and mechanic timing logic; **game session required** for player comprehension, visual clarity, and feel.
**Depends on:** TASK_Q1_05, TASK_Q3_02.

---

## 6. Q5 — Phase B: Closed Beta (M12–M15)

### Goals
- Ship the headline content: **1 Legion Raid, 4-gate, 8-player**.
- Open to closed beta (NDA-bound, ~200 testers).
- Stress test economy.

### Deliverables
- [ ] Legion Raid Gate 1–4 (boss: "First Hollow Lord")
- [ ] 8-player matchmaking infrastructure
- [ ] Battle Pass scaffold (no S1 content yet)
- [ ] Cosmetic shop framework
- [ ] Gamepass: extra character slots, premium currency boost
- [ ] Closed beta build deployed to PrivateServers
- [ ] Anti-exploit pass: server-auth audit + behavioral detection layer

### Claude Code Tasks (Q5)
Tasks ordered from most feasible/testable to least.

---

#### TASK_Q5_03: Anti-exploit behavioral layer
> **Feasibility: High** — detection logic operates on position/damage data; fully unit-testable with mock inputs.

**Semantics:**
`BehavioralDetector` monitors server-side player state each heartbeat and flags statistical anomalies. It does not attempt to reverse-engineer exploits; it detects impossible outcomes.

**Detection checks (run every `0.5s` per player):**

1. **Position delta:** `delta = (currentPos - lastPos).Magnitude / 0.5s`. If `delta > MAX_WALK_SPEED * 1.25`, flag `teleport`. Allow 1.25× tolerance for network jitter. Exclude players on mount (mounts increase max speed).

2. **Damage ceiling:** on each `DamageCaused` event, compare `dealt_damage` vs `theoretical_max`. `theoretical_max = base_attack * max_skill_multiplier * max_crit_modifier * max_engraving_multiplier`. If `dealt_damage > theoretical_max * 1.10`, flag `damage_overflow`.

3. **Skill spam:** if a `CastSkill` event fires with `os.clock() - lastCast < skill.cooldown * 0.80`, flag `cooldown_bypass`.

**Flag accumulation:**
- Each flag writes a record to `AnomalyLog` with `{ userId, type, value, threshold, timestamp }`.
- Flags are scored by severity: `teleport` = 3, `damage_overflow` = 5, `cooldown_bypass` = 2.
- If cumulative score in the last 60 seconds exceeds `KICK_THRESHOLD = 10`, auto-kick with message "Unusual activity detected."
- If cumulative score in the session exceeds `BAN_REVIEW_THRESHOLD = 30`, add to `ban_review_log` for human review.

**Whitelist:** a server config table `SPEED_WHITELIST = { "launch_pad_boost", "sprint_buff" }` lists `ActiveEffect` types that legitimately increase move speed. Before flagging, check if the player has any whitelisted effect active.

**Implementation notes:**
- `AnomalyLog` writes to `DataStoreService` only for `ban_review_log` entries; in-session flags are in-memory only.
- Never kick a player based on a single flag — only on score threshold. False positives are inevitable; the threshold provides a buffer.
- This module is invisible to the client. Never send "you have been flagged" messages; just kick with a neutral message.

**Acceptance criteria:**
- A mocked position sequence showing `100 studs / 0.5s` on a `16 stud/s` walk-speed character triggers a `teleport` flag.
- Damage `1.05× theoretical_max` does NOT flag (within tolerance). Damage `1.15× theoretical_max` flags.
- 5 cooldown bypasses in 60s (score = 10) triggers auto-kick.
- A player with an active `sprint_buff` whitelisted effect is not flagged for higher movement speed.

**Test approach:** `unit` with mock position/damage sequences.
**Depends on:** TASK_Q1_02, TASK_Q1_07.

---

#### TASK_Q5_02: Battle Pass framework
> **Feasibility: Medium-High** — XP tracking, tier calculation, and reward distribution are pure logic; UI, season rollover timing, and premium-track gating need game verification.

**Semantics:**
The Battle Pass is a seasonal progression system with two reward tracks (free and premium). Players earn BP XP from all gameplay activities. Reaching XP thresholds unlocks tier rewards.

**XP sources (defined in `S0.json`):**
- Guardian Raid kill: `1000 XP`
- Daily quest completion: `200 XP`
- Chaos Dungeon clear: `300 XP`
- Legion Raid gate clear: `2500 XP`

These are additive bonuses on top of normal gameplay rewards. `SessionLogger` fires a `bp_xp_earned` event on each source; `BattlePass.addXp(player, amount)` is called server-side.

**Tier thresholds:** stored in `S0.json` as a cumulative array `[500, 1200, 2100, 3200, ...]`. Current tier = `bisect(thresholds, total_xp)` (index of last threshold ≤ `total_xp`).

**Reward grants:** when `currentTier` increases, for each newly unlocked tier: look up `rewards[tier]` in `S0.json`, call `grantReward(player, reward)`. Free track rewards always granted. Premium track rewards: check `player.gamepass_premium` flag (set by `MarketplaceService` gamepass check on join).

**Season rollover:** `S0.json` includes `"season_end": 1761955200` (Unix timestamp). A background task checks `os.time() > season_end` once per server start. If true: archive current BP data to a `SeasonArchive` key in the profile, reset `bp_xp = 0`, `bp_tier = 0`, load the next season JSON.

**Implementation notes:**
- BP profile data: `{ season = "S0", xp = 4200, tier = 5, premiumUnlocked = false, claimedTiers = [1,2,3,4,5] }`.
- `claimedTiers` tracks which tier rewards have been granted. This prevents re-granting on profile reload.
- `bisect` is a pure Luau function over the thresholds array — not a binary search library, just a linear scan for correctness first.

**Acceptance criteria:**
- Adding `4200 XP` against thresholds `[500, 1200, 2100, 3200, 5000]` returns tier `4`.
- A free-track player does not receive premium-track rewards even after reaching the tier threshold.
- Season rollover preserves the season archive and resets current XP/tier to 0.
- Claiming a tier reward marks it in `claimedTiers`; server restart does not re-grant it.

**Test approach:** `unit` for XP math and tier bisect; **game session required** for UI and premium gating with real gamepass.
**Depends on:** TASK_Q1_06, TASK_Q2_05.

---

#### TASK_Q5_01: Legion Raid orchestration
> **Feasibility: Low** — party formation and gate progression logic are partially unit-testable; 8-player sync, mechanic timer accuracy, and raid feel require full game sessions with multiple players; MCP or manual coordination needed.

**Semantics:**
Legion Raids are the game's hardest content: 8-player, 4-gate encounters. Each gate is a separate boss fight. Players clear gates in sequence; failing a gate retries it without losing progress on earlier gates. A weekly lockout prevents replaying the same gates for rewards.

**Party formation:**
- Leader creates a party of up to 8 in the overworld lobby.
- Leader clicks "Enter Raid" → server validates party size (≥ 1), all members' weekly lockout (not already cleared), and minimum iLvl.
- `TeleportService:TeleportAsync` sends all 8 to the raid place with `TeleportData` encoding `{ raid_id, gate_number, party_leader }`.

**Gate flow (`RaidController.luau`):**
- On server start, read `TeleportData` to know which gate and raid.
- Load gate script (`Gate1.luau` through `Gate4.luau`). Each gate script exports `{ boss_id, mechanics[], hp_base }`.
- `RaidController` runs the gate using `BossController` (TASK_Q1_05) extended with mechanic callbacks.
- **Clear:** boss HP reaches 0 → grant loot (once per week per player, via lockout check) → fire `GateCleared` event → teleport party to next gate or overworld if Gate 4.
- **Wipe:** all 8 players dead → respawn at gate entrance, boss HP retained (no reset).
- **Weekly lockout:** on `GateCleared`, write `{ raid_id, gate_number }` to player profile `weeklyLockout` table with the current week's ISO week key. On raid entry, check lockout; locked players can enter but receive no loot.

**Mechanic timer accuracy:**
- All mechanic timers use `os.clock()` for start time, not `tick()` (monotonic). Target `< 50ms drift` from scheduled detonation.
- Timer drift logging: record `(actual_fire_time - scheduled_fire_time)` for each mechanic; log if `> 50ms`.

**Implementation notes:**
- Gate scripts do not import `RaidController` directly. They define a data table; `RaidController` orchestrates execution. One-way dependency.
- 8-player communication: use `MessagingService` if players are on different servers (split raids). For v1.0, assume all 8 are on the same private server; cross-server coordination is a future optimization.

**Acceptance criteria:**
- A party of 1 (solo) can enter a Legion Raid (no forced 8-player requirement; HP scales via Guardian Raid formula extended to 8).
- Clearing Gate 2 records the lockout; re-entering the raid shows "Locked" on Gate 2's reward screen but the player can still assist others.
- `os.clock()` drift on mechanic timers is < 50ms in a unit test with a mock `task.delay` scheduler.
- Wipe does not reset the boss to full HP; it retains the HP from the moment the last player died.

**Test approach:** `unit` for lockout logic and timer drift measurement; **game session required** for all multiplayer coordination, mechanic legibility, and difficulty tuning.
**Depends on:** TASK_Q1_05, TASK_Q1_06, TASK_Q3_02, TASK_Q4_01.

---

### Decision Gate G3 (end of M15)
| # | Criterion | Threshold |
|---|---|---|
| G3.1 | Legion Raid clear rate (beta) | $20\% \leq P_{\text{clear}} \leq 50\%$ |
| G3.2 | Average session length | $\geq 90$ min |
| G3.3 | Day-7 retention | $\geq 25\%$ |
| G3.4 | Exploit reports per 100 sessions | $\leq 1$ |

If G3 fails on retention or exploit count, **delay soft launch by 1 quarter**. Do not ship broken.

---

## 7. Q6 — Phase B: Soft Launch → v1.0 (M15–M18)

### Goals
- Public launch (no NDA).
- Marketing push via 2–3 mid-tier YouTubers + TikTok shorts.
- BP S0 live.

### Deliverables
- [ ] Public release on Roblox
- [ ] Marketing assets: trailer, screenshots, social
- [ ] Discord bot for community + bug reports
- [ ] Live ops dashboard (concurrency, retention, revenue)
- [ ] Day-1 patch pipeline
- [ ] v1.0 stable for 4 weeks post-launch

### Claude Code Tasks (Q6)
Tasks ordered from most feasible/testable to least.

---

#### TASK_Q6_02: Hotfix deployment process
> **Feasibility: High** — docs and CI config are immediately verifiable; no game session required.

**Semantics:**
Defines the end-to-end process for shipping a patch in under 2 hours, from the moment a critical bug is identified to the moment it is live in Roblox.

**`docs/hotfix_runbook.md` checklist:**
1. Create branch `hotfix/<issue_id>` from `main`.
2. Apply fix. Update `CHANGELOG.md`.
3. Run `rojo build` locally to verify no compile errors.
4. Push branch → GitHub Actions runs lint + unit tests.
5. If tests pass, lead reviews and approves PR.
6. Merge to `main` → GitHub Actions builds Roblox place file and publishes via `rojo publish` (using stored `ROBLOSECURITY` secret).
7. In Roblox Studio, set the live game's place to the new version.
8. Monitor `SessionLogger` for error spikes for 30 minutes post-deploy.
9. **Rollback:** `git revert <commit>` → push → repeat steps 3–7.

**`.github/workflows/deploy.yml`:**
- Trigger: push to `main` or `hotfix/*`.
- Steps: `actions/checkout`, `setup-python`, `pip install rojo`, `rojo build`, run `tests/`, on success: `rojo publish --asset-id $PLACE_ID`.
- Secrets used: `ROBLOSECURITY`, `PLACE_ID` — stored in GitHub repo secrets, never in code.

**Implementation notes:**
- `rojo publish` requires a valid `.ROBLOSECURITY` cookie with Creator access. This must be rotated on expiry.
- The `deploy.yml` should gate on `branch: [main, hotfix/*]` to avoid auto-deploying feature branches.
- Include a `workflow_dispatch` trigger so a deploy can be triggered manually without a push.

**Acceptance criteria:**
- `deploy.yml` syntax is valid (passes `act --list` dry run or `actionlint`).
- Runbook includes an explicit rollback procedure (not just "revert the commit").
- `ROBLOSECURITY` never appears in any committed file (grep check in CI).
- Runbook SLA: from branch creation to live — ≤ 2 hours, documented with time estimates per step.

**Test approach:** `unit` — YAML linting, secret grep check; **no game session required** for process docs.
**Depends on:** TASK_Q1_01.

---

#### TASK_Q6_03: Community bot
> **Feasibility: Medium** — bot logic is testable with Discord.py mocks and a test server; production use requires a live bot token and Discord server setup.

**Semantics:**
A Discord bot for community management and support. It reduces manual triage load by auto-formatting bug reports and enabling basic player lookups by support staff.

**Commands:**

`!bugreport` (any member):
- Prompts user for title and description (DM-based interactive flow, or a single-message format with template).
- Creates a new thread in `#bug-triage` channel with: `[BUG] <title>` as thread name, fields: Reporter (Discord tag), In-game name, Description, Reproduction steps (template), Roblox place version.
- Reacts to the original message with ✅ to confirm submission.

`!lookup <roblox_username>` (Support role only):
- Queries the game's analytics endpoint (or a cached export) for the player's stats: character level, iLvl, last online, current guild.
- Returns a Discord embed with a summary.
- Rate limit: 5 uses per user per minute (tracked in-memory, resets on bot restart).

**Error handling:**
- Unknown command: silent ignore (no "unknown command" noise).
- `!lookup` with invalid username: respond "Player not found." in the command channel.
- Discord API errors: log to `bot/logs/`, retry once, then fail silently.

**Implementation notes:**
- Use `discord.py >= 2.0` with slash commands if preferred over prefix commands. Prefix (`!`) is simpler to test.
- `!lookup` queries a lightweight HTTP endpoint from `TASK_Q6_01`'s Exporter, not directly from Roblox's API (to avoid rate limits and auth complexity).
- Store `BOT_TOKEN` and `GUILD_ID` in `.env`, never committed. Add `.env` to `.gitignore`.

**Acceptance criteria:**
- `!bugreport` creates a thread in the correct channel with all template fields present.
- `!lookup barlu3` returns a valid embed if the player exists, "Player not found." if not.
- A non-Support member cannot use `!lookup` (responds "You don't have permission to use this command.").
- 6 `!lookup` calls in under 60 seconds from the same user triggers "Rate limit exceeded. Try again in X seconds."

**Test approach:** `unit` with `discord.py` mock library (`discord.ext.test` or manual mocking); **live bot token required** for full integration.
**Depends on:** TASK_Q6_01.

---

#### TASK_Q6_01: Live ops dashboard
> **Feasibility: Low-Medium** — `Exporter.luau` logic is unit-testable; the dashboard UI and real-time data pipeline require a live game with real player data.

**Semantics:**
Two components: a Luau `Exporter` that runs on the game server and POSTs metrics to an HTTP endpoint, and a web dashboard that ingests those metrics and displays them.

**`Exporter.luau` (runs server-side, every 60 seconds):**
Collects and POSTs:
```json
{
  "timestamp": 1700000000,
  "server_id": "game_server_001",
  "ccu": 47,
  "active_raids": { "guardian": 3, "abyss": 1, "legion": 0 },
  "top_classes": { "ironclad": 18, "stormcaller": 15, "skystrike": 14 },
  "honing_success_rate_15min": 0.42,
  "revenue_session": { "bp": 4, "cosmetics": 2, "gamepasses": 1 }
}
```
Uses `HttpService:PostAsync(DASHBOARD_URL, payload, Enum.HttpContentType.ApplicationJson)`.

**Dashboard (Next.js + Recharts, hosted externally):**
- **CCU panel:** time-series line chart, last 24 hours, 1-minute resolution.
- **Retention panel:** cohort table — D1/D7/D30 retention per week of acquisition (data sourced from `SessionLogger` events).
- **Raid clear rates:** bar chart per gate, updated each time a `boss_kill` event arrives.
- **Revenue panel:** stacked bar chart per source (BP, gamepass, cosmetics) per day.

Auth: dashboard accepts POST from known server IPs only (IP allowlist or shared bearer token in request header).

**Implementation notes:**
- `Exporter.luau` must fail silently if `HttpService:PostAsync` throws (network down, dashboard offline). Wrap in `pcall`.
- In Studio, mock the POST with a print call. Gate with `RunService:IsStudio()`.
- The dashboard is a separate repo or `dashboard/` subdirectory. It can start as a simple HTML + Chart.js page before migrating to Next.js.

**Acceptance criteria:**
- `Exporter.luau` in Studio mode prints valid JSON matching the schema above.
- Dashboard renders a CCU chart from a static fixture JSON without errors (smoke test).
- A `PostAsync` failure does not crash the game server (pcall verified in unit test).
- Revenue data is broken down by source, not lumped as a single total.

**Test approach:** `unit` for Exporter JSON construction and pcall safety; **live game required** for real data ingestion and dashboard usefulness.
**Depends on:** TASK_Q1_07, TASK_Q1_01.

---

## 8. Q7+ — Live Ops (M18+)

### Cadence: 12-week seasons

| Season | Class added | Content added |
|---|---|---|
| S1 | Voidblade (Assassin) | T3 zones, 1 new Legion Raid |
| S2 | Vaultshot (Gunner) | Stronghold (player housing) |
| S3 | Beastcaller (Specialist) | Card system content + T4 raid |
| S4+ | (advanced subclasses) | Endgame mechanics, transcendence, elixirs |

### Claude Code Tasks (ongoing)
Tasks ordered from most feasible/testable to least.

---

#### TASK_LIVE_03: Localization scaffolding
> **Feasibility: High** — code refactor with grep-verifiable output; no game session required to confirm no hardcoded strings remain.

**Semantics:**
Externalize all user-facing strings from Luau source files into `LocalizationService` so that translators can swap language without touching code.

**Process:**
1. Grep all `.luau` files for string literals that are user-visible (displayed in UI, spoken in dialogue, shown in notifications). Pattern: strings assigned to `TextLabel.Text`, passed to `DialogueBox.playSequence`, or sent via RemoteEvent to the client.
2. Assign each string a key: `QUEST_find_the_herald_name`, `DIALOGUE_herald_intro_001`, `UI_honing_insufficient_materials`.
3. Replace the literal with `Translator:FormatByKey("KEY")` where `Translator = LocalizationService:GetTranslatorForPlayerAsync(player)`.
4. Export all strings to `ReplicatedStorage/Configs/Localization/en.csv` with columns: `Key, Source, en`.
5. Add empty columns for `kr`, `pt_BR`, `id` — these stay empty until S3 translation work begins. The columns being present signals to `LocalizationService` that those locales are expected.

**Implementation notes:**
- `LocalizationService:GetTranslatorForPlayerAsync` yields. Call it once on player join and store the result in a module cache keyed by `player`.
- Do not localize internal log messages, error codes, or config keys — only user-visible text.
- A CI lint step (`tools/localization/check_hardcoded.py`) greps for string patterns that look user-visible but are not in the CSV. Fails CI if found.

**Acceptance criteria:**
- `grep -r 'TextLabel.Text = "' src/` returns zero matches after refactor.
- All dialogue lines in TASK_Q3_04 reference `Translator:FormatByKey` calls, not inline strings.
- `en.csv` contains every key referenced in code (no missing key at runtime that falls back to the key string itself).
- `check_hardcoded.py` exits 0 on the refactored codebase and exits 1 on a file with a hardcoded user-visible string.

**Test approach:** `unit` — grep checks; Python CI tool; no game session required.
**Depends on:** TASK_Q3_04, TASK_Q1_01.

---

#### TASK_LIVE_02: Telemetry-driven balance
> **Feasibility: Medium-High** — data pipeline and report generation are testable with synthetic telemetry; A/B framework needs live population to be meaningful.

**Semantics:**
A weekly automated job reads `SessionLogger` exports, aggregates class DPS, computes variance, and produces a markdown balance report for the lead designer to review.

**Weekly balance report (`tools/balance_reports/generate.py`):**
Input: a JSON file of `skill_used` events from the past 7 days (exported from the analytics endpoint).
Output: `reports/balance_YYYY-MM-DD.md` with:
- Table: class → median DPS, 10th/90th percentile, sample count.
- Flag: any class with median DPS more than `15%` above or below the overall median.
- Tripod usage breakdown: which tripod options are taken most per skill (signals imbalance in a tier).

**A/B test framework:**
- Server config includes `ab_tests: { "engraving_keen_blunt_t3": { variant_a: 0.20, variant_b: 0.25, split: 0.50 } }`.
- On player join, if an A/B test is active and player has no assigned variant, roll and store in profile `{ ab_assignments: { test_id: "a" } }`.
- `TelemetryLogger` tags all events with `ab_assignments` so post-hoc analysis can diff variant cohorts.

**Implementation notes:**
- `generate.py` is a pure data pipeline: reads JSON, writes markdown. No network calls.
- Minimum sample size for a flag: `n >= 100` sessions for that class. Classes with fewer sessions are noted but not flagged.
- The A/B framework only assigns variants — it does not apply them. The code that reads `ab_assignments` and branches is written per-test. This is intentional: tests are specific, not generic.

**Acceptance criteria:**
- `generate.py` with a fixture input of 3 classes where one class has `+20%` DPS vs. median outputs that class in the "flagged" section.
- A class with `n < 100` sessions appears in a "Insufficient data" section, not in the flagged section.
- Tripod usage table shows each option's percentage correctly (sums to 100% per skill).
- A player assigned to variant A in an A/B test retains that assignment across sessions (stored in profile, not re-rolled each login).

**Test approach:** `unit` with fixture JSON for report generation; **live population required** for A/B results to be statistically significant.
**Depends on:** TASK_Q1_07, TASK_Q4_03.

---

#### TASK_LIVE_01: Per-season content pipeline
> **Feasibility: Low-Medium** — the CSV → JSON converter and schema validator are testable standalone; full "class live in < 2 weeks" goal requires game integration testing and animator coordination outside Claude Code's scope.

**Semantics:**
Reduces the time to ship a new playable class from weeks of programmer time to a designer-driven pipeline targeting 2 weeks end-to-end.

**Class definition pipeline:**
1. Designer fills `tools/class_builder/class_template.csv` with columns: `skill_id, display_name, key, cooldown, range, damage_multiplier, resource_cost, target_type, tripod_a_id, tripod_a_type, tripod_a_value, ...`.
2. `tools/class_builder/csv_to_json.py` converts to `ReplicatedStorage/Configs/Classes/<ClassName>.json` and validates against the schema from TASK_Q2_01.
3. `validate.py` runs in CI. PR is blocked if schema fails.
4. Animator adds rig animations; combat dev sets `has_animations = true` in the JSON. Until then, animations fall back to Ironclad's placeholder rig.

**Raid mechanic pipeline:**
- A library of existing mechanic primitives (ColorMatch, PillarPhase, DPSCheck from TASK_Q4_01) is extended each season.
- New raids are defined entirely in JSON; no new `.luau` files required unless a mechanic type is novel.
- `validate.py` (mechanic authoring tool) checks the new raid JSON before PR merge.
- Target: a raid built from existing primitives ships in < 4 weeks.

**Balance pass automation:**
- Weekly report from TASK_LIVE_02 feeds into a `balance_delta.csv`: columns `class, skill_id, field, old_value, new_value, reason`.
- `tools/balance_reports/apply_delta.py` reads the CSV and patches the corresponding class JSON files.
- Changes are committed as a PR titled `[Balance] Week YYYY-WW patch`, reviewed by lead before merge.

**Acceptance criteria:**
- `csv_to_json.py Voidblade_template.csv` produces a valid `Voidblade.json` that passes `validate.py`.
- A CSV with a missing required column (`cooldown`) causes `csv_to_json.py` to exit 1 with a column-level error message.
- `apply_delta.py` with a fixture `balance_delta.csv` modifies the correct field in the correct class JSON without touching other fields.
- A new class JSON with `has_animations = false` is accepted by the schema (not a blocking error — just a warning).

**Test approach:** `unit` for Python tooling with fixture CSVs; **game session required** for confirming the class is fully playable within the 2-week target.
**Depends on:** TASK_Q2_01, TASK_Q2_02, TASK_Q4_03, TASK_LIVE_02.

---

## 9. Repo Structure (canonical)

```
lostblox/
├── src/                          # Rojo source (synced to Roblox)
│   ├── ServerScriptService/
│   │   ├── Combat/
│   │   ├── Content/
│   │   ├── AI/
│   │   ├── Save/
│   │   ├── Loot/
│   │   ├── Security/
│   │   └── Analytics/
│   ├── ReplicatedStorage/
│   │   ├── Modules/
│   │   ├── Configs/              # JSON authored, hot-reloadable
│   │   ├── Remotes/
│   │   └── UI/
│   └── StarterPlayerScripts/
│       └── Controllers/
├── tools/                        # Python tooling for designers
│   ├── class_builder/
│   ├── mechanic_authoring/
│   └── balance_reports/
├── tests/                        # Unit + integration tests
├── docs/
│   ├── design_doc.md
│   ├── timeline.md               # this file
│   └── hotfix_runbook.md
├── bot/                          # Discord bot
├── dashboard/                    # Live ops dashboard
└── .github/workflows/            # CI: lint, test, deploy
```

---

## 10. Definition of Done — per quarter

A quarter ends only when:

1. All deliverables shipped or explicitly deferred to next quarter (with reason).
2. Decision gate criteria met OR re-scope decision made.
3. Tests passing: unit, integration, server smoke.
4. Documentation updated: design doc, API, runbooks.
5. Retrospective held: what worked, what didn't, what to change next quarter.

---

## 11. Tech Stack Reference

| Layer | Tech |
|---|---|
| Engine | Roblox |
| Language | Luau (Roblox), Python (tooling), JS/TS (dashboard + bot) |
| Sync | Rojo |
| Save | ProfileService |
| Pathfinding | Roblox PathfindingService |
| Matchmaking | MemoryStoreService + TeleportService |
| AI dev assist | Claude Code via MCP |
| Source control | Git + GitHub |
| CI/CD | GitHub Actions |

---

## 12. Living Risk Register

| ID | Risk | Owner | Status |
|---|---|---|---|
| R1 | Team-vs-scope mismatch | Lead | Mitigate via Phase C gate |
| R2 | Skill-shot/cooldown combat tension | Combat dev | Hybrid design, validate Q1 |
| R3 | Genshin→MMO complexity jump | All | Lucky Brainrot as tech rehearsal |
| R4 | Claude Code over-reliance | Lead | Human-owned architecture, AI for boilerplate |
| R5 | 8p raid + mechanic-heavy QA load | QA lead | Launch 1 raid, expand seasonally |
| R6 | Self-funded burnout | Lead | Realistic milestones, no crunch |
| R7 | Custom obfuscation tick overhead | Security dev | Profile early, fallback to server-auth-only |
| R8 | EN-only excludes Roblox demo majority | Marketing | i18n scaffolding from day 1 |

Add new risks as they emerge. Review register monthly.

---

## 13. How to Use This Doc

- **Devs:** Reference for what's owed each quarter. Update task status weekly.
- **Claude Code:** Treat TASK_QX_NN blocks as work units. Each has explicit file paths and acceptance criteria. Open PR per task.
- **Lead:** Run decision gates rigorously. Do not skip a gate to maintain timeline.
- **Animators:** Pipeline tasks not enumerated here — coordinate with combat dev for rig + skill anim schedule.

---

*Last updated: M0 — kickoff. Update header on every quarter close.*
