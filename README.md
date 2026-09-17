# ASTRAWILD — Echoes of the First Dawn (Godot Edition)

**The Shattered Vale · Grand Expanse (Batch 8)** — twelve 800 m zones over a
3.2 km × 2.4 km procedural continent, each zone with its own wildlife,
resources, landmarks and signature light.

This is the **Godot 4 port** of the [ASTRAWILD Unreal Engine 5 project](https://github.com/banksaisuoy/astrawild-game)
— a third-person cooperative survival adventure with Echo creature
companionship, crafting, base building and a data-driven bestiary of
**226 Echo species** (204 generated + 10 hand-authored + 6 production species
with evolutions + 2 dungeon bosses).

The gameplay rules (stats, capture formula, elemental combat, survival decay,
crafting costs, tech tree, quest chain) are ported 1:1 from the UE5 C++ core
(`AstrawildCore`), and the original `ArtSource` GLB models, audio and
procedural-terrain math are reused directly.

## Play — desktop builds (ready to run)

**No engine needed.** Download the native build for your OS from the
[GitHub Releases](https://github.com/banksaisuoy/astrawild-godot/releases) page:

| Build | File | How to run |
|---|---|---|
| **Windows x64** | `Astrawild-Windows-x64.zip` | Unzip anywhere → double-click `Astrawild.exe` |
| **Linux x64** | `Astrawild-Linux-x64.zip` | Unzip → `chmod +x Astrawild.x86_64` → `./Astrawild.x86_64` |

Both builds embed the entire game (78–113 MB single executable, PCK embedded).

**From source with the Godot editor:** import this folder in Godot 4.2+
(GDScript, GL Compatibility renderer) and press **F5** — zero extra setup,
all data is JSON-driven and every asset is in-repo.

**Re-export yourself:** `godot --headless --export-release "Linux"` or
`"Windows Desktop"` (export presets included; templates via the Godot editor).

## Controls

| Input | Action |
|---|---|
| WASD / mouse | Move / orbit third-person camera |
| Shift / Space | Sprint (stamina) / jump |
| LMB tap / hold | Light attack / heavy attack (25 stamina) |
| RMB hold | Block (unarmed 45% mitigation, shield 65%) |
| Q | Dodge — 0.4 s i-frames, 22 stamina |
| E | Interact (harvest, talk, rest, stations, place building) |
| F | Capture targeted Echo (consumes an Echo Resonator) |
| G | Feed nearest wild Echo (builds trust) |
| Aim at creatures | Passive observation — fills the field journal (+RP) |
| I / C / R / J | Inventory / Crafting / Research / Journal & Bestiary |
| B | Build mode (, . rotate, / cycle piece, E place) |
| M | Map |
| 1 / 2 / 3 | Party command: follow / stay / attack |
| Esc | Pause menu (save / load / restart) |
| **Dawn Skiff** | [E] near the hull to board · W/S thrust · A/D yaw · SPACE/CTRL climb/descend · SHIFT resonance boost (14→26 m/s) · [E] in flight to dismount |
| ` (backquote) | Debug console — the 15 `AW.*` cheat commands (SpawnEcho, GiveItem, SetTime, SetWeather, God, …) |

## Gameplay loop

`gather → observe → weaken & capture → feed & bond → craft → build → research → push into higher-threat zones → clear the two dungeons`

- **Survival**: HP / stamina / hunger / thirst / temperature with the UE5 decay rates.
- **Capture formula** (from `UAstrawildCaptureComponent`):
  `base 0.05×(1−0.5×diff) + weaken (1−hp%)×(1−resilience)×(1−0.5×diff) + trust×0.5 + situational (weather/activity) + journal bonus (up to +15% + 0.15)`.
- **Elements**: Light↔Ash, Flora↔Ember, Frost↔Pulse — weakness ×1.5, same element ×0.8,
  then flat defense subtraction. Status effects: Burning (4 s DoT), Chilled (slow ×0.5),
  Poisoned (6 s DoT), Shocked (0.8 s, ×0.3 speed).
- **Echo progression**: trust stages (Stranger → Acquainted → Familiar → Trusted → Bonded → Partner),
  levels (×1.1 HP / ×1.08 ATK per level), evolutions for the six production species
  (level + bond gates: Terraquill Verdant, Cindermule Pyre, Voltpylon Tempest,
  Bastionbeetle Bulwark, Mistmender Rime, Deepdelver Abyssal).
- **Bosses**: Underlight Warden and Vault Colossus (Dawnfang) — 3 phases,
  telegraphed AoE slams, weak-point windows (×2 damage).
- **Living villages (Batch 8)**: Dawnstead (7 huts, palisade, 8 NPCs — Warden
  Maren, Trader Tam, Herbalist Wren, Blacksmith Borin, Elder Rowan, guards Sela
  & Bram, Farmer Jori) and Driftwood Landing (dock, 3 NPCs — Skiff Warden Kael,
  Fisher Nima, Old Salt Perry). Villagers patrol waypoint circuits, gather at
  the campfire 21:00–06:00, and guards chase hostile Echoes within 35 m.
- **Dawn Skiff (Batch 8)**: two aircraft per world — board with [E], fly with
  WASD/SPACE/CTRL, SHIFT boosts 14→26 m/s; banking/pitch tilt, terrain hover
  clamps (+2.2 m floor, +120 m ceiling).
- **Dungeons (Batch 6)**: the Hollow Underlight — 5 sealed rooms east of the
  wilds' gate (gates open as rooms clear; Underlight Warden boss; +10 RP and the
  unique `Tech_AncientResonance` force-unlock) — and the Sunken Vault — 4 rooms
  deep in the Tidebreaker Isles (Dawnfang boss; 25 RP + pearls/coral/shards).
  Both are deterministic (world seed) with resonance portals in/out.
- **Power grid (Batch 4)**: Echo Dynamo (+8 W), Charge Cell (600 J battery),
  Dawn Lamp / Hearth Coil / Research Desk consumers — auto-connect within 12 m,
  re-solve every 2 s, brownout shedding, lamps go dark when unpowered.
- **Echo work sites (Production V2)**: Camp Gathering Post (fiber/10 s), Camp
  Berry Plot (berries/14 s), Camp Kitchen (raw meat → cooked meat/8 s) and the
  powered Ridge Breaker Rig (stone ×2/18 s — needs a Dynamo within 12 m, runs at
  ×1.5 when powered). Bring party Echoes within 20 m and press [E] to assign.
- **World events**: 9 data-driven archetypes — Storm Surge (forced storm),
  Great Migration, Resource Surge, Supply Drop, Ancient Signal, Night Raid,
  Meteor Fall, Rare Echo Bloom, Boss Stirring — weighted scheduler, world-hour
  durations, cooldowns.
- **Cheat console**: the UE5 `UAstrawildCheatManager`'s 15 commands, on the
  backquote key. `help` lists everything.
- **12-zone world** with day/night (1 s = 1 in-world minute), 8 weather states,
  hostile respawner sweeps every 25 s, 33 resource node definitions, 34 recipes,
  16 technologies, 13 building pieces, 11-quest main chain.

## Repository layout

```
project.godot          Godot project config (autoloads: Data, Game, Saves)
scenes/main.tscn       Entry scene (title → world → gameplay)
scripts/autoload/      Data registry / game state / save system
scripts/world/         Procedural terrain (FBM, partition-of-unity zone blend),
                       day-night atmosphere ramp, weather FX, markers, NPCs
scripts/player/        Third-person controller, combat, capture, build mode
scripts/creatures/     Echo AI + procedural body builder + boss logic
scripts/systems/       Building pieces, power grid, work sites,
                       world events, cheat console
scripts/ui/            HUD + all full-screen menus
data/                  All content tables (items, recipes, tech, buildings,
                       zones, bestiary 204 species, special species, quests)
assets/meshes|audio|textures   Original ArtSource packs (GLB/WAV/PNG)
```

## Credits

- Original design & UE5 C++ core: ASTRAWILD team (see the UE5 repository docs).
- Godot port: generated as a faithful 1:1 gameplay port; all balance data
  extracted from `AstrawildBestiaryData.cpp`, `AstrawildContentLibrary.cpp`,
  `AstrawildProductionContent.cpp` and `AstrawildZoneSubsystem.cpp`.
- Art/audio: the project's own `ArtSource` procedural packs.
