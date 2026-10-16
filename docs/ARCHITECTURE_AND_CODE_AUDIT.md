# ARCHITECTURE & CODE AUDIT — ASTRAWILD — Echoes of the First Dawn (v1.6)

**Date:** v1.6 read-only deep audit · **Auditor:** architecture-auditor (Task 2-a)
**Scope:** full source read of `/home/z/astrawild-godot` — every gameplay `.gd` script (31 files, 14,194 lines), `project.godot`, `scenes/main.tscn`, all `data/*.json`, `.github/workflows/ci.yml`, `README.md`, and the `godot_mcp` addon bridge (skimmed). **No game code was modified.**
**Method:** every claim below is backed by a `file:line` actually read during this audit. Data counts were machine-verified with a JSON parse of `data/*.json`. The game was **not executed** in this audit — runtime behavior claims marked *(not verified)* rely on the CI boot/smoke gates described in `.github/workflows/ci.yml` and prior worklog evidence.

---

## 1. System Map

### 1.1 Autoload layer (project.godot:19–26)

| Autoload | Script | Role | Key refs |
|---|---|---|---|
| `Data` | `scripts/autoload/data.gd` | Static content registry — loads all `data/*.json` once, builds typed lookups (`items`, `recipes`, `techs`, `buildings`, `resource_nodes`, `worksites`, `zones`, `species`, `species_by_zone`, `quests`, `species_rigs`) | data.gd:46–103 |
| `Mods` | `scripts/autoload/mod_loader.gd` | Runtime mod injection. Scans `res://mods` → `<exe_dir>/mods` → `user://mods`; each `mod.json` may add/override species, items, recipes; mutates `Data.*` in place | mod_loader.gd:20–29, 87–141 |
| `Game` | `scripts/autoload/game.gd` | Central run-state + shared event bus: clock, weather, survival, inventory, equipment, research, journal, quests, party/echo_box, eggs, achievements, difficulty presets. Declares 19 signals (game.gd:5–23) | game.gd:1–23 |
| `Saves` | `scripts/autoload/saves.gd` | Versioned save/load (schema v2) with backup rotation: `user://astrawild_save.json` → `.backup.json`; pulls world/dungeon/skiff/worksite/power/event state via `get_save_data()` | saves.gd:17–92 |
| `Sfx` | `scripts/autoload/sfx.gd` | Audio: 4 buses (SFX/Music/Ambience/UI), ~55 event→file mappings, 7 music tracks, zone ambience/footsteps, pooled `AudioStreamPlayer(3D)` | sfx.gd:14–157, 457–476 |
| `MCPGameBridge` | `addons/godot_mcp/game_bridge/mcp_game_bridge.gd` | Dev-tooling bridge (2,582-line addon). Registers an `EngineDebugger` message capture + frame profiler + runtime-state sampler; **no-ops entirely when `EngineDebugger.is_active()` is false** (exported/standalone builds) | mcp_game_bridge.gd:36–56 |

Load order is correct for the mutation chain: `Data` fills → `Mods` mutates → `Game`/`Saves`/`Sfx` consume. Note: the `MCPGameBridge` entry lacks the `*` singleton prefix the other five carry (project.godot:26) — see risk R9.

### 1.2 Runtime topology (ASCII)

```
                         ┌─────────────────── AUTOLOADS (root) ───────────────────┐
                         │  Data   Mods   Game(event bus)   Saves   Sfx            │
                         │  MCPGameBridge (debugger-only, inert in exports)        │
                         └───────┬─────────────────────────────────────────────────┘
                                 │ groups: "world" / "player" / "screens" / "hud"
scenes/main.tscn ── main.gd ─────┤
  title screen ──► staged loading (build_progress signal) ──► gameplay layer
                                 │
        ┌────────────────────────┴───────────────────────────────────────┐
        │ GameWorld (scripts/world/world.gd, 1,321 ln)  group:"world"    │
        │                                                               │
        │  ZoneTerrain ×12 ── WorldNoise(FBM) ── partition-of-unity      │
        │  DayNightCycle   WeatherFX   Props(MultiMesh batches)          │
        │  ResourceNodes(≈123)   Landmarks(15)+chests   Markers          │
        │  Village ×2 (Dawnstead 8 NPCs / Driftwood 3 NPCs)              │
        │  DawnSkiff ×2    DungeonGenerator ×2 (5+4 rooms)               │
        │  WorkSite ×4 ◄── PowerGrid (2 s resolve) ── BuildingPiece(s)    │
        │  WorldEventSystem (9 archetypes, weighted scheduler)           │
        │  creatures_root: Echo ×~150 (wild + 8 zone Apex + 2 dungeon    │
        │  bosses + followers)                                           │
        └───────┬───────────────────────────────┬────────────────────────┘
                │                               │
   PlayerCharacter (player.gd)          Hud (hud.gd) + UiScreens (screens.gd)
   combat / capture / build mode        13 panels; CheatConsole (cheats.gd)
   drone + robot automation             DamageNumbers (static Label3D pool)
```

### 1.3 World generation pipeline (world.gd `build()`, world.gd:47–114)

Staged + frame-yielding (`_breathe()` between stages; per-zone yields inside the two heavy loops):

| Fraction | Stage | Where |
|---|---|---|
| 0.04 | 12× ZoneTerrain built (129×129 height grid each, vertex-color mesh, HeightMapShape3D collision) | world.gd:126–133, terrain.gd:100–113, 143–265 |
| 0.08–0.12 | Water plane, DayNightCycle, WeatherFX | world.gd:136–150 |
| 0.14 | Root nodes (props/nodes/creatures/npcs/buildings) + PowerGrid + WorldEventSystem | world.gd:63–86 |
| 0.16–0.60 | `_dress_all_zones` — mixed-species tree pools (5–7 silhouettes/biome), rocks, grass, zone specials, Kenney prop kits, camp richness ring | world.gd:328–408, 410–453, 601–653, 656–695 |
| 0.64 | Resource nodes scattered from zone `resources` tables (123 instances) | world.gd:857–872 |
| 0.68–0.72 | Home camp, villages (+paths), 2 Dawn Skiffs | world.gd:876–982 |
| 0.80 | Location markers + 15 landmarks + chests | world.gd:779–825, 1046–1078 |
| 0.86 | 2 dungeons + 4 work sites | world.gd:1082–1127 |
| 0.90–0.99 | `_spawn_all_creatures` — per-zone wildlife (passives ×2.2), 8 zone Apexes, Auroraling | world.gd:1149–1187 |
| 1.0 | `Game.party_changed.connect(_sync_party)` — follower sync armed | world.gd:112–113 |

Zone blending: `ZoneTerrain.zone_weights()` computes a partition-of-unity over the 4×3 zone grid with a 60 m blend ring (terrain.gd:38–54); `eval_world_height` blends base+amp per zone weights + 2 FBM detail layers + hand-placed camp micro-relief (terrain.gd:81–92). `WorldNoise` is a deterministic seeded value-noise FBM ported from the UE5 `EvalWorldHeight` math (noise.gd:13–47).

### 1.4 Echo system (scripts/creatures/echo.gd, 1,343 ln)

- **Spawn:** `world._spawn_creature()` → `Echo.new(def, rng)` → `boss_mode` set **before** `add_child` (world.gd:1190–1198) so `_ready` builds the boss-scaled body.
- **Variant identity (v1.5.2):** every wild Echo rolls `_vj = {scale, hp, atk, hue, bright}` + ~9.5% named variant (radiant 3.0% / dusk 2.5% / colossal 4.0%) in `_roll_identity()` (echo.gd:115–137). `apply_identity(variant, vj)` must be called pre-`add_child` (echo.gd:73–86); `identity()` returns a duplicate for persistence (echo.gd:88–90).
- **Body resolution chain:** `species_rigs` override (Quaternius CC0) → `def.model` (ArtSource production GLBs) → procedural Tier-B builder (8 body plans × family features × surface detail, echo.gd:425–646).
- **AI:** simplified UE5 state machine `Idle/Explore/Sleep/Investigate/Flee/Combat/Follow/Stay/Work/Defeated` on a 0.25 s think tick + per-frame `_move` with ground snapping (echo.gd:824–993). Far-field LOD gate freezes wild AI beyond 110 m of the player (echo.gd:781–797).
- **Combat:** `take_hit()` applies weakness ×1.5 / same-element ×0.8 / boss weak-orb ×2, flat defense subtraction, stagger, damage numbers, then `_die()` → loot (+100% radiant), `Game.echo_defeated.emit(def.id, loot)` (v1.5.2 fixed to match the 2-arg signal declaration), party XP (echo.gd:1057–1129).
- **Capture:** `Game.try_capture(echo)` — consumes a Resonator, computes the UE5 capture formula (`capture_chance`, game.gd:1209–1227: base + weaken + trust + situational + journal bonus), refuses bosses (game.gd:1249–1253), and on success stores `variant` + `vj` in the roster entry (game.gd:1260–1268); party members become followers in-place, box captures `queue_free()` the wild node.
- **Followers:** `world._sync_party()` (on `party_changed`) spawns/updates follower Echo nodes, re-applying persisted identity (`follower.apply_identity(entry.variant, entry.vj)`, world.gd:1253–1262); evolution swaps the species and rebuilds the body (echo.gd:1228–1243).

### 1.5 Elemental combat (6 elements)

Light↔Ash, Flora↔Ember, Frost↔Pulse pairs; weakness ×1.5, same-element ×0.8, then flat `def` subtraction (echo.gd:1062–1076; player side `Game.take_damage` with armor rating formula, game.gd:742–773). Status effects: Burning (4 s DoT), Chilled (×0.5 speed), Poisoned (6 s DoT), Shocked (0.8 s ×0.3) — applied by element in `Echo._apply_status_to_player` (echo.gd:1035–1040), ticked centrally in `Game._tick_status` (game.gd:713–725). Ranged weapons spawn physics-swept projectiles (projectile.gd:19–47); melee uses a shape-query sweep capped at one confirmed hit per swing (player.gd:500–521).

### 1.6 Villages, production & power

- **Villages (2):** Dawnstead (7 buildings + bell tower + palisade + 8 NPCs) and Driftwood Landing (dock + 3 NPCs) — built from Quaternius FBX with measured box collisions, waypoint circuits, night campfire gathering 21:00–06:00, guards aggro hostiles within 35 m and strike for 14 dmg/1.4 s (village.gd:45–113, 393–419; npc.gd:140–265).
- **Work sites (4):** definition-driven production (fiber/berries/cooked meat/stone×2), Echo workers rated by affinity×mood×energy×personality, powered sites ×1.5 or stall at ×0 (worksite.gd:118–193); Utility Robot mans an unmanned site at flat 0.8 (robot.gd:72–102).
- **Power grid:** auto-connect 12 m radius, re-solves every 2 s (never per frame), brownout sheds highest-draw consumers first, per-piece `set_powered()` drives lamp visibility (power.gd:35–106; building_piece.gd:250–271).
- **World events (9 archetypes):** weighted scheduler rolls every 20 world-minutes with cooldowns; effects = forced weather, species boosts, bonus nodes, loot, RP (world_events.gd:16–64, 84–102).

### 1.7 Bosses — 10 total (verified in data)

8 zone Apex (`Creature_{Cindermaw,Glaciarch,Voltrex,Dunetyrant,Mirebound,Thorncaller,TempestSovereign,ReefSovereign}Apex`, each with `apex_of` + `boss` flags in `data/species_special.json`) spawned one per deep zone (world.gd:1176–1181) + 2 dungeon bosses (`Creature_UnderlightWarden`, `Creature_VaultColossus`, dungeon.gd:164–167). Boss kit: 3 HP phases (×1.0/1.15/1.4 attack), 7 s telegraphed AoE slam (45 dmg, 3.5 m), 12 s weak-point orb (×2 damage window), boss-bar + phase pips in the HUD (echo.gd:1133–1217; hud.gd:624–662). Boss defeats route to achievements via `Game.echo_defeated` (game.gd:441–464).

### 1.8 Key signal flows (verified emitters → consumers)

| Signal (declaration) | Emitted at | Consumed by |
|---|---|---|
| `toast(text, color)` | ~90 call sites (Game, world, echo, ui…) | `Hud._add_toast` (hud.gd:64, 678–691) |
| `stats_changed` | game.gd:710 (every frame), 772, 801… | `Hud._refresh_bars` (hud.gd:65) |
| `time_changed(day, minute)` | game.gd:378 (every frame) | `Hud._refresh_clock` (hud.gd:67) |
| `zone_changed(zone_id)` / `weather_changed(state_id)` | game.gd:1346 / 406, 429 | HUD clock refresh (hud.gd:68–69); ambience via polling |
| `quest_changed` | game.gd:1071, 1095, 1115, 1146 | `Hud._refresh_quest` (hud.gd:70) |
| `party_changed` | game.gd:1277, 1319, 1333… | `Hud._refresh_party` (hud.gd:71) **and** `GameWorld._sync_party` (world.gd:112) |
| `capture_attempt(species_id, success)` | game.gd:1258 | `Hud._on_capture_flash` (hud.gd:72) |
| `echo_defeated(species_id, loot)` | echo.gd:1124 | `Game._on_echo_defeated_ach` (self-connect, game.gd:180) |
| `screen_requested(screen)` | player.gd:472, 960 | `UiScreens.open` (screens.gd:35), player pause toggle (player.gd:67) |
| `equipment_changed` | game.gd:894 | `PlayerCharacter._refresh_weapon_visual` (player.gd:68) |
| `build_progress(stage, fraction)` | world.gd:118 (via `_bp`) | main.gd loading bar (main.gd:443) |
| `inventory_changed` | game.gd:840, 851 | HUD **no-op lambda** (hud.gd:66) — effectively dead |
| `research_changed`, `journal_changed`, `crafting_done`, `building_placed`, `achievements_changed`, `game_saved`, `game_loaded` | game.gd / saves.gd / player.gd | **no `.connect()` found anywhere** — screens re-pull state on open instead (declared-but-unwired API) |

All `emit()` arities were cross-checked against their declarations; the one historical arity bug (`echo_defeated` emitted with 1 arg) is already fixed and documented at echo.gd:1121–1124.

### 1.9 CI & tooling

`.github/workflows/ci.yml`: validate job (Godot 4.7.2 headless `--import`, clean-boot grep gate for `warning|error`, `--smoke` suite requiring `SMOKE COMPLETE` and no `SCRIPT ERROR`), export matrix (Linux/Windows/macOS/Web) on `v*` tags. The smoke suite itself lives in `main.gd:502–1183` (~680 lines — 44% of the file) and asserts world/creature/craft/quest/mod/drone/robot/worksites/rig coverage/perf budget (`props<700`, `mm_instances<22000`, `nodes<9000`, main.gd:796–807).

---

## 2. Runtime Risk Points

Findings ordered by severity. All file:line refs were read in this audit.

### Confirmed defects (verified against source)

| # | Severity | Finding | Evidence | Suggested fix |
|---|---|---|---|---|
| R1 | **HIGH** | **`Sfx.play_event()` does not exist.** Two live call sites hit a nonexistent method on the Sfx autoload → runtime script error (recoverable, but prints `SCRIPT ERROR` and skips the sound). Fires on **every landmark chest open** and on **onboarding completion**. | Calls: `marker.gd:76`, `hud.gd:513`. Full Sfx method list (verified): `play, play_at, play_stem, play_weapon, play_species, play_footstep, play_ambience, play_music, play_stinger, tick_heartbeat, set/get_bus_volume, save_settings` (sfx.gd:198–476) — no `play_event`. | Replace both with `Sfx.play("ui_confirm", -10.0)` (the event id exists in `EVENTS`, sfx.gd:19). |
| R2 | **HIGH** | **`screens.open_research()` does not exist.** Interacting with a player-placed Research Desk errors out; the research screen is unreachable from that station path (still reachable via R key → `screen_requested`). | Call: `building_piece.gd:206`. UiScreens exposes only `open`, `open_crafting` (494), `open_dialogue` (1401), `open_shop` (1458) — verified against the full function list of screens.gd. | Replace with `screens.open("research")`. |
| R3 | **MED** | **Achievement `ach_alloy` ("Ancient Gifts") can never unlock.** The check reads item id `"AncientAlloy"`, but the real id is `"Item_AncientAlloy"` (verified in `data/items.json`). | `game.gd:508` vs items.json ids (`Item_AncientAlloy`, `Item_AncientResonator`, `Item_Resonator`). | Change both probes to `Item_AncientAlloy`. |
| R4 | **MED** | **Worldgen determinism is broken by shared-RNG reseeding.** `Echo._init` re-seeds the *caller's* generator with `Time.get_ticks_msec()` (`rng.seed = hash(...)` mutates the passed RefCounted). Consequences: (a) after the first creature spawn in a zone, all subsequent `_scatter` rolls for that zone's remaining species are time-based, not seed-based (world.gd:1158–1171 passes one `rng` into both scatter and spawn); (b) dungeon room lateral offsets after the first creature-bearing room become non-deterministic despite the "deterministic layout" doc claim (dungeon.gd:63–65 rolls → dungeon.gd:171–175 spawns with the same `_rng`). Same seed ⇒ different wildlife layout / dungeon zigzag across runs. | echo.gd:140–143 (`rng.seed = hash("%s-%d" % [def.get("id"), Time.get_ticks_msec()])`); world.gd:1158–1171; dungeon.gd:53, 65, 175. | In `Echo._init`, create a private generator (`var own := RandomNumberGenerator.new(); own.seed = hash(...)`) instead of reseeding the shared one — or seed from `def.id + world_seed`. |
| R5 | **MED** | **Blocking discards difficulty + solo-grace multipliers.** `take_damage` applies difficulty (line 749) and the day≤3 ×0.65 grace (753–754) to `mitigated`, but the blocking branch **recomputes from the raw `amount`** (`mitigated = amount * (1.0 - mit)`), erasing both. A Veteran day-1 blocking player takes the same hit as a Standard day-10 one. The smoke test only exercises the non-blocking path (main.gd:941–943), so it can't catch this. | game.gd:747–759. | `mitigated = mitigated * (1.0 - clampf(mit, 0.0, 0.8))`. |
| R6 | **LOW** | **HUD build-mode prompt reads a nonexistent player property.** `player.get("build_def")` always returns `null` (the real var is `_build_def`), so the ghost prompt shows no piece name. | hud.gd:602 vs player.gd:47. | Expose a getter (`func build_def() -> Dictionary`) or read `_build_def` via `player.get("_build_def")`. |
| R7 | **LOW** | **Dead event-bus signals** (`research_changed`, `journal_changed`, `crafting_done`, `building_placed`, `achievements_changed`, `game_saved`, `game_loaded`) have no consumers; `inventory_changed` is connected to a no-op (hud.gd:66). Harmless today but invites drift — emitting code assumes something listens. | grep of all `.connect(` in `scripts/` (full list in §1.8). | Either wire the screens' refresh to them or delete the declarations. |

### Verified-safe areas (checked, no action needed)

- **Variant save/load round-trip (`entry.variant` + `entry.vj`)** — verified safe: `identity()` returns a duplicate of plain float scalars (echo.gd:88–90); JSON round-trip preserves floats; the reload path re-coerces everything through `float(p_vj.get(...))` with defaults (echo.gd:79–86), and `world._sync_party` re-applies it pre-`add_child` (world.gd:1257). One caveat: a foreign/older save whose `vj` has fewer than 5 keys is **silently ignored** (`p_vj.size() >= 5` gate, echo.gd:79) — the follower spawns with default identity instead of failing.
- **queue_free'd references** — all audited call sites guard with `is_instance_valid` or re-fetch by group: player drone/robot (player.gd:845, 863), NPC guard target (npc.gd:221–225), work-site workers/robot (worksite.gd:121–124, 144–154), world followers (world.gd:1237–1241; game.gd:1176–1179), skiff pilot (skiff.gd:171–173), boss bar id (hud.gd:632–639), power-grid stale pieces (power.gd:48–50), building exit_tree unregister (building_piece.gd:264–271).
- **Quest reward re-entrancy** — completion retires the quest *before* granting item rewards so `_notify_quest_counters` can't recurse infinitely; the hazard and fix are documented in-code (game.gd:1131–1135).
- **Async world build races** — `world._process` gates the hostile sweep on `creatures_root != null` (world.gd:1201–1209); Echoes spawned mid-build (before the player exists) null-check the player in `_think` (echo.gd:829–831); dungeons' room-state polling tolerates partially-built `rooms`. `main.gd` awaits `world.build()` before the HUD/player exist (main.gd:448–460).
- **Save-trigger ordering** — `Saves._apply` replaces `Game.party` and emits `party_changed` in the same synchronous block (saves.gd:121, 152), so `world._sync_party` rebuilds followers before any user input can index a stale follower (the `Game.party[idx]` lookup at worksite.gd:246).

### Flagged, not fully verified

| # | Finding | Evidence |
|---|---|---|
| R8 | `MCPGameBridge` autoload is registered **without the `*` script-singleton prefix** the other five autoloads use. It points at a `.gd` path in scene form. CI's clean-boot gate has historically passed with this entry (worklog), so it evidently loads — but it deviates from the editor convention and is worth normalizing. *(not verified by running the engine in this audit)* | project.godot:26 vs 21–25 |
| R9 | README headline counts are stale vs data: "228 species (…234 with mods)" — the data files actually register **236** (204 bestiary + 32 special incl. the 8 v1.5.2 Apexes) + 6 modded = **242 at runtime**; README also says "34 recipes" vs 35 in `crafting.json`, and "33 resource node definitions" vs 10 definitions (123 placed instances). | README.md:10–12, 124–125 vs `data/*.json` parse (§4) |

---

## 3. Performance Bottlenecks

Ordered by expected per-frame impact. The smoke suite already enforces a hard budget (props < 700 children, MultiMesh instances < 22,000, total nodes < 9,000 — main.gd:796–807), which the world respects; the items below are *code-level* hot paths, not budget violations.

### B1 — HUD interactable scan every frame (highest steady-state cost)

- **Where:** `hud.gd:449–450` (`_update_prompt()` each `_process`) → `player._nearest_interactable()` (player.gd:595–609) → `_interaction_candidates()` (player.gd:577–592).
- **What it does per frame:** iterates the `interactables` group (~55 nodes: 15 chest + 15 location markers, 11 NPCs, 2 skiffs, 4 portals, 4 worksites, camp markers) **plus every child of `nodes_root` (≈123 resource nodes) and `buildings_root`**, allocates a fresh candidate Array, then distance-checks them all.
- **Fix:** throttle to ~5 Hz or cache the candidate list and invalidate on `inventory/building` changes; or replace with a single player-following `Area3D` overlap query.

### B2 — Compass objective resolution scans world nodes with string conversion every frame

- **Where:** `compass.queue_redraw()` per frame (hud.gd:457–458) → `_draw_compass()` → `_objective_world_pos()` (hud.gd:552–587).
- **What it does:** for creature objectives it loops the entire `creatures` group (~150 nodes, hud.gd:577–579); for `CollectItem` objectives it loops **all 123 resource nodes and calls `str(n2.get_meta("loot", []))` + `find()` per node per frame** (hud.gd:582–584) — sustained string allocation churn for the whole duration of a gather quest.
- **Fix:** resolve the objective position once per second (or on `quest_changed`) and cache the `Vector3`; precompute an item→nodes index at worldgen.

### B3 — Multiple independent full creature-group scans per frame

- **Where:** player observation `_nearest_echo` per physics frame (player.gd:681–691, via 658–677); HUD boss search loops all creatures each frame (hud.gd:624–631); minimap redraw loops all `creatures_root` children each frame (hud.gd:460–461 → 730–774); drone adds another scan every 4 s (drone.gd:103–113).
- **Cost:** ≈4 × ~150 distance checks + per-creature type checks per frame, on top of B1.
- **Fix:** one shared "nearby creatures" query per frame (or a 0.2 s cached result) consumed by observation/boss/minimap/drone.

### B4 — `tile_height()` / `slope_at()` are linear scans over all 12 tiles per call

- **Where:** world.gd:153–177.
- **Callers at runtime:** every moving Echo's ground snap (echo.gd:988 via `_ground_y`), NPC steps (npc.gd:186), the skiff hover clamp **twice per physics frame** (skiff.gd:195–209), the robot (robot.gd:93), projectiles (projectile.gd:46), build ghost (player.gd:752). Each call loops the 12-zone dictionary and computes rect distances — and `slope_at` calls `height_at` 4×.
- **Fix:** the zone grid is a known 4×3 layout — derive the tile index arithmetically from `x/z` (O(1)) instead of scanning; at minimum cache the last-hit tile (spatial locality is high).

### B5 — Zone identity recomputed per physics frame

- **Where:** `player._zone_tracking()` (player.gd:918–927) calls `world.zone_at()` → `ZoneTerrain.zone_weights()` which loops all 12 zones with dictionary access (terrain.gd:38–54) at 60 Hz. `DayNightCycle._apply_atmosphere` runs the same weights every 0.1 s (daynight.gd:79–84, 142–166) — that one is already throttled.
- **Fix:** throttle zone tracking to 5 Hz (zone changes are rare events) or reuse B4's cached tile.

### B6 — Per-frame signal emits drive redundant HUD work

- **Where:** `time_changed.emit(...)` every frame (game.gd:373–378) → `_refresh_clock` rebuilds three label texts and calls `_refresh_bars` (hud.gd:370–375); `stats_changed.emit()` **also** every frame from `_tick_survival` (game.gd:710) → `_refresh_bars` again (hud.gd:65). Net: the vitals bars and clock are rewritten ~120×/s from two emitters.
- **Fix:** emit `time_changed` only when the displayed minute changes and `stats_changed` on a ≥1% delta (or a 0.25 s cadence).

### B7 — Worldgen one-frame spikes

- **Terrain build is fully synchronous:** `_build_terrain()` computes 12 × 129² = **199,692** `eval_world_height` calls in a single frame (world.gd:126–133 has one `_breathe()` *after* the whole loop). Each call = 12-zone weight loop + 6-octave FBM (≈24 hash evals) + micro-relief; `_build_mesh` then adds **two more FBM samples per vertex** for tone/patch coloring (terrain.gd:179, 188). ≈600k value-noise evals in one frame — the one remaining stage that can stall a web build for seconds despite the PS-2 staged loader.
- **`_dress_camp_richness`** caps at **22,000 rejection-sampled tries**, each calling `tile_height` + `slope_at` (world.gd:656–695) — a second one-frame burst on the home meadow.
- **Fix:** yield every N rows inside `ZoneTerrain.build()` (the progress plumbing already exists) and chunk the camp-ring loop; both are mechanical.

### B8 — Echo nameplate rebuilt every frame for every active creature

- **Where:** `_update_label()` is called unconditionally at the end of `_process` (echo.gd:821) and rebuilds a 12-character block-bar string + two-line text (echo.gd:684–714) even when nothing changed. The far-field LOD gate (echo.gd:781–797) already freezes wild Echoes beyond 110 m — the residual cost is the ~dozen near creatures plus all followers/bosses.
- **Fix:** only rebuild when `hp`, `variant`, `captured`, `defeated` or trust stage changed (dirty flag).

### B9 — Minor allocation churn

- `DamageNumbers.spawn` constructs a new `RandomNumberGenerator` per number (damage_numbers.gd:24) and one `Label3D` + tween per hit — bounded by combat frequency (melee sweeps confirm at most one target per swing, player.gd:521), fine as-is.
- HUD toast labels are created/freed per toast (hud.gd:678–691) — acceptable.

### Existing mitigations worth keeping (verified in source)

Far-field Echo LOD gate (echo.gd:781–797) · power grid 2 s resolve cadence (power.gd:35–43) · hostile respawn sweep every 25 s (world.gd:1206–1209) · atmosphere throttle 0.1 s (daynight.gd:79–84) · music-context throttle 1.5 s (sfx.gd:160–165) · staged worldgen with per-zone `_breathe()` (world.gd:52–110) · shared `_mesh_cache`/`_wind_mesh_cache` for props (world.gd:34, 253–297) · MultiMesh batching for all vegetation (world.gd:219–250) · audio player pooling (sfx.gd:457–476) · CI perf-budget smoke gate (main.gd:796–807).

---

## 4. Code Statistics

### 4.1 GDScript volume (wc -l, machine-counted)

| Category | Files | Lines |
|---|---|---|
| Game scripts (`scripts/`) | **31** | **14,194** |
| MCP addon (`addons/godot_mcp/`) | 35 | 9,657 |
| **Total GDScript** | **66** | **23,851** |

Top files by size:

| File | Lines | Role |
|---|---|---|
| scripts/ui/screens.gd | 1,962 | 13 full-screen panels (inventory/crafting/research/journal/map/pause/dialogue/shop/mods/help/credits/settings/nest) |
| scripts/main.gd | 1,530 | title → staged load → gameplay; **~680 lines (44%) are the headless smoke suite + screenshot harness** (main.gd:502–1183, 1195–1519) |
| scripts/autoload/game.gd | 1,361 | run-state + event bus + achievements + breeding |
| scripts/creatures/echo.gd | 1,343 | Echo AI, body builder, variants, boss logic |
| scripts/world/world.gd | 1,321 | world bootstrap + dressing + spawns + save data |
| scripts/player/player.gd | 962 | controller, combat, capture, build mode, automation |
| scripts/ui/hud.gd | 777 | HUD incl. boss bar, compass, minimap, onboarding |
| scripts/autoload/sfx.gd | 462 | audio buses/events/pools |
| scripts/world/village.gd | 419 | village builder + NPC rosters |
| scripts/world/dungeon.gd | 364 | 2 procedural dungeons |

Everything is code-built: **1 scene file** (`scenes/main.tscn` — a single `Node` + main.gd script) and **1 shader** (`shaders/wind_sway.gdshader`).

### 4.2 Data tables (machine-verified JSON parse)

| Table | File | Count |
|---|---|---|
| Echo species | bestiary.json + species_special.json | **236 registered** (204 generated + 32 special: 10 hand-authored, 6 production + 6 evolutions, 2 dungeon bosses, 8 zone Apexes) — +6 modded at runtime = 242 |
| Zones / weather states | zones.json | 12 zones (4×3 grid, 800 m each) / 8 weather states |
| Recipes | crafting.json | 35 (+5 modded) |
| Technologies | crafting.json | 16 (6 eras) |
| Building pieces | crafting.json | 14 |
| Resource node definitions → placed instances | crafting.json → zones.json | 10 defs → **123 instances** |
| Work sites | crafting.json | 4 (1 power-required) |
| Items | items.json | 50 (+4 modded) |
| Quests | quests.json | 11 (linear chain to `Quest_VanguardProtocol`) |
| Rig maps | species_models.json | 236 |
| Landmarks / achievements / world events / cheat commands | code constants | 15 (world.gd:723–769) / 28 (game.gd:98–127) / 9 (world_events.gd:16–45) / 15 + `mods` (cheats.gd:98–106) |
| Mods bundled | mods/*/mod.json | 3 (mythic_echoes 4 species, glimmer_garden 2 species, chefs_toolkit 3 items+3 recipes) |

### 4.3 Live world at boot (estimated from data + spawn math)

≈150 Echo nodes: ~130 wild (passives ×2.2 density multiplier, world.gd:1168–1169; 10 hostiles) + 8 zone Apexes + 1 Auroraling + ~12 dungeon guardians/bosses; 123 resource nodes; 15 landmark chests; 2 villages (11 NPCs); 2 skiffs; 4 work sites; ~540 MultiMesh prop instances per zone average, hard-capped <22,000 world-wide (main.gd:796–807).

---

## 5. Verification log

- **Read fully:** project.godot, README.md, ci.yml, main.tscn, all 5 autoloads, main.gd, world.gd, terrain.gd, noise.gd, echo.gd, player.gd, projectile.gd, hud.gd, damage_numbers.gd, icons.gd, marker.gd, resource_node.gd, npc.gd, village.gd, dungeon.gd, dungeon_portal.gd, skiff.gd, daynight.gd, weather_fx.gd, power.gd, worksite.gd, world_events.gd, drone.gd, robot.gd, building_piece.gd.
- **Read partially:** screens.gd (full function map + crafting/map/input/settings sections), cheats.gd (head + command list), mcp_game_bridge.gd (head; addon role inferred from structure + plugin registration).
- **Machine-verified:** all JSON counts (§4.2), boss/apex flags, item id `Item_AncientAlloy`, mod contents, line counts (`wc -l`).
- **Not verified in this audit:** actual runtime execution (read-only pass — no engine run); CI pass/fail status of the current HEAD (inferred from workflow design + worklog claims); MCP bridge behavior in an exported build (R8).
