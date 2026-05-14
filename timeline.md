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
Specific tasks to delegate to Claude Code via Rojo + MCP:

```
TASK_Q1_01: Scaffold Rojo project structure
  Path: src/
  Subtasks:
    - Create ServerScriptService/Combat/, Replication/, Save/
    - Create ReplicatedStorage/Modules/, Remotes/, Configs/
    - Create StarterPlayerScripts/Controllers/Camera/, Movement/, Input/
    - Create shared types in ReplicatedStorage/Modules/Types.lua
    - .gitignore for Roblox + .vscode/

TASK_Q1_02: Implement server-auth combat skeleton
  Files:
    - ServerScriptService/Combat/SkillRegistry.lua  (skill definitions)
    - ServerScriptService/Combat/SkillExecutor.lua  (validation + resolve)
    - ServerScriptService/Combat/DamageCalculator.lua  (formula impl)
    - ReplicatedStorage/Remotes/CastSkill.RemoteEvent
  Acceptance:
    - Client cannot bypass cooldown
    - Client cannot bypass range
    - Damage matches formula within floating-point tolerance

TASK_Q1_03: Click-to-move controller
  Files:
    - StarterPlayerScripts/Controllers/Movement/ClickToMove.lua
    - Uses PathfindingService with NavMesh caching per zone
    - Cancel-on-WASD toggle
  Acceptance:
    - Path computed client-side, validated server-side
    - Max move speed enforced server-side (anti-teleport)

TASK_Q1_04: Top-down camera
  Files:
    - StarterPlayerScripts/Controllers/Camera/TopDownCamera.lua
  Acceptance:
    - Locked pitch -60°, zoom range [18, 35] studs
    - Smooth lerp on player movement
    - Edge-of-screen mouse pan optional

TASK_Q1_05: Boss AI v1 (state machine)
  Files:
    - ServerScriptService/AI/BossController.lua
    - ServerScriptService/AI/States/*.lua  (Idle, Telegraph, Attack, Stagger, Enrage)
  Acceptance:
    - Telegraphs render 0.8-1.8s ahead of damage zone
    - Mechanic gates skippable only via correct player action

TASK_Q1_06: ProfileService integration
  Files:
    - ServerScriptService/Save/ProfileManager.lua
    - ReplicatedStorage/Configs/ProfileTemplate.lua
  Acceptance:
    - Session-locked per UserId
    - Auto-reconcile on schema change
    - Force-save on PlayerRemoving

TASK_Q1_07: Telemetry harness (retention measurement)
  Files:
    - ServerScriptService/Analytics/SessionLogger.lua
  Acceptance:
    - Logs: session start, session end, deaths, boss kills, skill usage
    - Output: JSON to MessagingService or external endpoint
```

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
```
TASK_Q2_01: Class authoring tool
  Files:
    - tools/class_builder/  (Python + JSON schema)
    - ReplicatedStorage/Configs/Classes/*.json
  Acceptance:
    - Designer edits JSON, Roblox runtime hot-reloads on join
    - Schema validates skill IDs, resource types, cooldowns

TASK_Q2_02: Stormcaller + Skystrike implementation
  Files:
    - ReplicatedStorage/Configs/Classes/Stormcaller.json
    - ReplicatedStorage/Configs/Classes/Skystrike.json
    - ServerScriptService/Combat/Identity/StormcallerIdentity.lua
    - ServerScriptService/Combat/Identity/SkystrikeIdentity.lua
  Acceptance:
    - Arcana resource accumulates 0-100, drains on identity
    - Chi stacks 0-3, consumed on identity

TASK_Q2_03: Engraving system core
  Files:
    - ReplicatedStorage/Configs/Engravings/*.json
    - ServerScriptService/Combat/EngravingResolver.lua
  Acceptance:
    - 6 engravings defined, 3-tier activation (5/10/15 points)
    - Resolved before damage calc, multiplies/adds correctly

TASK_Q2_04: Honing math implementation
  Files:
    - ServerScriptService/Progression/HoningCalculator.lua
    - Documentation: P_base curves, pity formula
  Acceptance:
    - Curves match design doc, pity force-success works
    - Material consumption atomic (no dupe on failure)

TASK_Q2_05: Inventory system
  Files:
    - ServerScriptService/Inventory/InventoryManager.lua
    - ReplicatedStorage/UI/InventoryUI.rbxm
  Acceptance:
    - Stack handling for materials
    - Equip/unequip atomic, stat recompute hooked
```

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
```
TASK_Q3_01: Chaos Dungeon generator
  Files:
    - ServerScriptService/Content/ChaosDungeonRunner.lua
    - ReplicatedStorage/Configs/ChaosTiers/*.json
  Acceptance:
    - 3-phase structure (clear, elite, boss)
    - Loot table scales with iLvl
    - Time limit + score multiplier

TASK_Q3_02: Guardian Raid framework
  Files:
    - ServerScriptService/Content/GuardianRaid.lua
    - 4-player matchmaking via TeleportService
  Acceptance:
    - Boss HP scales with player count: HP * (1 + 0.875*(n-1))
    - Wipe/retry within instance
    - 20-min hard timer

TASK_Q3_03: Quest system
  Files:
    - ServerScriptService/Quests/QuestManager.lua
    - ReplicatedStorage/Configs/Quests/*.json
  Acceptance:
    - Tracking, completion, reward distribution
    - Dialogue NPC integration with Sans-style voice blips

TASK_Q3_04: Dialogue system (Sans-blip voice)
  Files:
    - StarterPlayerScripts/UI/DialogueBox.lua
    - ReplicatedStorage/Sounds/Voices/*.wav
  Acceptance:
    - Per-NPC pitch constant
    - Vowel emphasis (volume +10%)
    - Skip-on-input, history scrollback
```

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
```
TASK_Q4_01: Abyss Dungeon scripting framework
  Files:
    - ServerScriptService/Content/AbyssRunner.lua
    - tools/mechanic_authoring/  (Python tool)
  Acceptance:
    - Designers define mechanics in JSON (color match, pillar phase, etc.)
    - Reusable mechanic primitives library

TASK_Q4_02: Accessory + drop table system
  Files:
    - ServerScriptService/Loot/LootTable.lua
    - ReplicatedStorage/Configs/Loot/*.json
  Acceptance:
    - Weighted random with seed for replay
    - iLvl-gated drops, quality roll 0-100

TASK_Q4_03: Tripod system v1
  Files:
    - ServerScriptService/Combat/TripodResolver.lua
  Acceptance:
    - 1 tripod per skill (vs LA's 3, defer)
    - Modifies damage/cooldown/AoE per config
```

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
```
TASK_Q5_01: Legion Raid orchestration
  Files:
    - ServerScriptService/Content/LegionRaid/Gate1.lua ... Gate4.lua
    - ServerScriptService/Content/LegionRaid/RaidController.lua
  Acceptance:
    - 8-player party formation pre-raid
    - Wipe-and-retry per gate, lockout per week
    - Mechanic timer accuracy <50ms drift

TASK_Q5_02: Battle Pass framework
  Files:
    - ServerScriptService/Monetization/BattlePass.lua
    - ReplicatedStorage/Configs/BattlePass/S0.json
  Acceptance:
    - XP tracking from all sources (raids, dailies, quests)
    - Tier rewards (free + premium tracks)
    - Season rollover handler

TASK_Q5_03: Anti-exploit behavioral layer
  Files:
    - ServerScriptService/Security/BehavioralDetector.lua
    - ServerScriptService/Security/AnomalyLog.lua
  Acceptance:
    - Flag: damage > theoretical max, position > vel_max*dt, skill spam
    - Log + auto-kick on persistent flags
    - Whitelist legitimate edge cases via review
```

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
```
TASK_Q6_01: Live ops dashboard
  Files:
    - External: dashboard/  (Next.js or simple HTML)
    - ServerScriptService/Analytics/Exporter.lua
  Acceptance:
    - Real-time CCU, retention cohorts, raid clear rates
    - Revenue per source (BP, gamepass, cosmetics)

TASK_Q6_02: Hotfix deployment process
  Files:
    - docs/hotfix_runbook.md
    - .github/workflows/deploy.yml  (or equivalent)
  Acceptance:
    - Patch flow: branch → test → ship in <2h
    - Rollback procedure documented

TASK_Q6_03: Community bot
  Files:
    - bot/  (Node.js or Python, Discord.py)
  Acceptance:
    - Bug report intake → triage channel
    - In-game name → roster query for support
```

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
```
TASK_LIVE_01: Per-season content pipeline
  - Class definition CSV → playable in <2 weeks
  - Raid mechanic library → new raid in <4 weeks
  - Balance pass automation: stat snapshot → CSV diff

TASK_LIVE_02: Telemetry-driven balance
  - Auto-generate weekly balance reports
  - Flag classes/builds with DPS variance >15% from median
  - A/B test framework for tuning changes

TASK_LIVE_03: Localization scaffolding
  - Externalize all dialogue strings to LocalizationService
  - Prep for KR + PT-BR + ID in S3 or later
```

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
