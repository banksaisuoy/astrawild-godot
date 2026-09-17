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

## Play

| | |
|---|---|
| **Engine** | Godot 4.2+ (GDScript, GL Compatibility renderer — web ready) |
| **Open** | Import this folder with the Godot Project Manager, press F5 |
| **Web build** | `godot --headless --export-release "Web"` with export templates |

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
- **Bosses**: Underlight Warden (Hollow Approach gate) and Vault Colossus
  (Sunken Vault) — 3 phases, telegraphed AoE slams, weak-point windows (×2 damage).
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
scripts/systems/       Building pieces
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
