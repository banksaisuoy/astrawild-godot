# VISUAL AUDIT — ASTRAWILD Godot Division
**Phase V1 · truth-only pass · generated 2025-09-24 · repo @ aacf4d3 (v1.0.4)**

> Written per the Visual & World Directive V1. No fixes were made in this phase.
> Every number below comes from commands run against the working tree. The directive
> says "226 species" — the real shipped count is **228** (204 generated + 24 special).

## 1 · Mesh file inventory (real `find` output)

The repo contains exactly **one** 3D format: GLB. No glTF/FBX/OBJ/DAE/PLY exist.

| folder | files | total size | contents |
|---|---|---|---|
| `assets/meshes/characters/` | 1 | 191 KB | player survivor rig |
| `assets/meshes/echoes/` | 6 | 717 KB | 6 production Echo rigs |
| `assets/meshes/environment/` | 19 | 375 KB | trees, rocks, ferns, ruins, nodes |
| `assets/meshes/vehicles/` | 1 | 134 KB | Dawn Skiff |
| `assets/meshes/weapons/` | 5 | 281 KB | ranged weapons |
| **total meshes** | **32** | **1.75 MB** | all vertex/material-coloured low-poly, **0 textures** |

Other asset weight: `assets/audio/` = **36 WAV, 15 MB**. Whole repo (incl. .git-import) = **31 MB**.

### Animation inventory (parsed from GLB JSON chunks)

| file | animations |
|---|---|
| `SK_Survivor_Exosuit.glb` | 7: AM_Survivor_Idle, AM_Survivor_Walk, AM_Survivor_Run, AM_Survivor_Jump, AM_Survivor_Aim, AM_Survivor_Fire, AM_Survivor_Gather |
| `SK_Echo_Bastionbeetle.glb` | 3: AM_Bastionbeetle_Idle, AM_Bastionbeetle_Move, AM_Bastionbeetle_Hit |
| `SK_Echo_Cindermule.glb` | 3: AM_Cindermule_Idle, AM_Cindermule_Move, AM_Cindermule_Hit |
| `SK_Echo_Deepdelver.glb` | 3: AM_Deepdelver_Idle, AM_Deepdelver_Move, AM_Deepdelver_Hit |
| `SK_Echo_Mistmender.glb` | 3: AM_Mistmender_Idle, AM_Mistmender_Move, AM_Mistmender_Hit |
| `SK_Echo_Terraquill.glb` | 3: AM_Terraquill_Idle, AM_Terraquill_Move, AM_Terraquill_Hit |
| `SK_Echo_Voltpylon.glb` | 3: AM_Voltpylon_Idle, AM_Voltpylon_Move, AM_Voltpylon_Hit |
| all 19 environment + vehicle + weapon GLBs | 0 (static) |

## 2 · Species coverage table (all 228)

Machine-generated from `data/bestiary.json` + `data/species_special.json`.

| species_id | mesh_source | has_animation | verdict |
|---|---|---|---|
| `Echo_Mosspaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dawnhorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Duskhide` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Emberrunner` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Galewing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Plumeplume` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Skysong` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Fernbloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Boughsprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Bramblethorn` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Chitinmite` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dustweevil` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Irongolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Hollowshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Cinderblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Emberwing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Boughbloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Bramblesprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Petalthorn` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dawnpaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Duskhorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dustmite` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Thornweevil` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Gildedhornet` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Duskshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Whisperveil` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Coralfin` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Pearlgill` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Frostwing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Glacierblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Voltshard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Plumewing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Skyplume` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Stormwing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Ashfang` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Glimmerdrake` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Tidewyrm` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Voltblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Bloomshard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Zephyrsurge` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Duskpaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Emberhorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Runedgolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Clockworksentinel` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Thornmite` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Whispershade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Paleveil` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Bramblebloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Skywing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dawnplume` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Emberpaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Rimehorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Galehide` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Ashwing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Glimmerfang` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Bloomblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Zephyrshard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Magmasurge` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dawnwing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Stormplume` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Clockworkgolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Paleshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Abyssfin` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Reefgill` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Petalbloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Rootsprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Pollenthorn` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Wispshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Mourningveil` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Silenthaunt` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Glassgolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Stonesentinel` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Rootbloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Pollensprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Rimepaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Galehorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Hivemite` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Reedweevil` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Mistcry` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Zephyrblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Magmashard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Glimmerwing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Tidefang` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dunedrake` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Mourningshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Silentveil` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Fadedhaunt` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Lanternmote` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Tidewing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dunefang` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Galepaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Thornhorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Stonegolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Coppersentinel` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Magmablaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Reliccolossus` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Vespermonolith` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Reedmite` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sandweevil` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Pollenbloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Thornsprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Brinefin` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Lagoongill` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Undertowray` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Saltcrest` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Wavejelly` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Driftskimmer` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Tidenymph` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Rimeblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Staticshard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Thornpaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sunwing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dunewing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Silentshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Coppergolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Resonantsentinel` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Thornbloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Mycelsprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Lagoonfin` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Undertowgill` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Saltray` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Wavecrest` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Mistwing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Cometplume` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Downsong` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Voidwing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Dawnfang` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Riverpaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Resonantgolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Fadedshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Staticblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Pyreshard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Hallowedcolossus` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Primemonolith` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Monolithprimarch` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Stonepaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Hollowhorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sunhide` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Mudmite` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sporeweevil` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Glimmerhornet` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Pyreblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Frostshard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Pistongolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Gearsentinel` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Coralcrest` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Lanternshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Veilveil` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Cometwing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Downplume` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Bloombloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sapsprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Hollowpaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sunhorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Tidehide` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Magmawing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Abyssfang` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Coraldrake` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Geargolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Chimesentinel` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Frostblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Galeshard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Downwing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Monolithcolossus` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Astralmonolith` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Veilshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Ghostveil` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sporemite` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Glimmerweevil` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Verdantbloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Orchidsprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Fernthorn` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Boughbough` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Glimmermite` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Wireweevil` | procedural (Insectoid) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Chitinhornet` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sunpaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Tidehorn` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Ghostshade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Abysswing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Chimegolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Thermalwing` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Crestplume` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Galesong` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Galeblaze` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Voltcore` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Driftfin` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Tidegill` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Coralray` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Pearlcrest` | procedural (Serpent) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Abyssjelly` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Reefskimmer` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Voltheart` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Cindershard` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Embershade` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Hollowveil` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Coralwing` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Forgottencolossus` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Eldermonolith` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Latticegolem` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Ironsentinel` | procedural (Crystalline) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Tidepaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Orchidbloom` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Fernsprout` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Lumewisp` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Stonehide` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Voltling` | procedural (Biped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Duskmoth` | procedural (Avian) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Gloomfang` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Sprigling` | procedural (Amorphous) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Emberfang` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Rimefang` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Voltmaw` | procedural (Quadruped) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Auroraling` | procedural (Floating) | no AnimationPlayer — code bob/swing only | NAKED PRIMITIVES: flat-coloured boxes/spheres |
| `Echo_Terraquill` | `SK_Echo_Terraquill.glb` | yes (3) | REAL GLB rig (Terraquill) |
| `Echo_Cindermule` | `SK_Echo_Cindermule.glb` | yes (3) | REAL GLB rig (Cindermule) |
| `Echo_Voltpylon` | `SK_Echo_Voltpylon.glb` | yes (3) | REAL GLB rig (Voltpylon) |
| `Echo_Bastionbeetle` | `SK_Echo_Bastionbeetle.glb` | yes (3) | REAL GLB rig (Bastionbeetle) |
| `Echo_Mistmender` | `SK_Echo_Mistmender.glb` | yes (3) | REAL GLB rig (Mistmender) |
| `Echo_Deepdelver` | `SK_Echo_Deepdelver.glb` | yes (3) | REAL GLB rig (Deepdelver) |
| `Echo_TerraquillVerdant` | `SK_Echo_Terraquill.glb` | yes (3) | REAL GLB rig (Terraquill) |
| `Echo_CindermulePyre` | `SK_Echo_Cindermule.glb` | yes (3) | REAL GLB rig (Cindermule) |
| `Echo_VoltpylonTempest` | `SK_Echo_Voltpylon.glb` | yes (3) | REAL GLB rig (Voltpylon) |
| `Echo_BastionbeetleBulwark` | `SK_Echo_Bastionbeetle.glb` | yes (3) | REAL GLB rig (Bastionbeetle) |
| `Echo_MistmenderRime` | `SK_Echo_Mistmender.glb` | yes (3) | REAL GLB rig (Mistmender) |
| `Echo_DeepdelverAbyssal` | `SK_Echo_Deepdelver.glb` | yes (3) | REAL GLB rig (Deepdelver) |
| `Creature_UnderlightWarden` | `SK_Echo_Bastionbeetle.glb` | yes (3) | REAL GLB rig (Bastionbeetle) |
| `Creature_VaultColossus` | `SK_Echo_Deepdelver.glb` | yes (3) | REAL GLB rig (Deepdelver) |

**Summary:** 14 of 228 entries point at a real GLB (6 unique rigs — the 6 production
Echoes, reused by 6 evolutions and 2 dungeon bosses). **214 species (93.9%) are naked
primitive assemblies.** Procedural body-plan distribution of those 214:

- Quadruped: 59
- Amorphous: 36
- Floating: 29
- Biped: 24
- Avian: 21
- Serpent: 17
- Insectoid: 15
- Crystalline: 13

## 3 · Non-species visual inventory

| element | source | verdict |
|---|---|---|
| Player | `SK_Survivor_Exosuit.glb` + 7 anims | REAL — animated, weapon hardpoint |
| NPCs (11) | same survivor GLB, flat-tinted per role | REAL mesh but **every NPC is the player's clone recoloured**; no distinct villager silhouette |
| Village huts | `CylinderMesh` walls + `PrismMesh` roof + glowing box door | NAKED PRIMITIVES |
| Village stakes/dock/lamps | boxes + cylinders | NAKED PRIMITIVES |
| Resource nodes (4 types) | `SM_Node_*.glb` via MultiMesh | REAL |
| Trees (3), rocks (4), fern, grass, glowreed, sporebush, ruins (3), cliff shard | GLB via MultiMesh | REAL — world greenery is genuinely dressed |
| Ranged weapons (7 items) | 5 weapon GLBs (2 shared) | REAL |
| Melee weapons: DawnwoodClub / CrystalBlade / AncientResonator | `BoxMesh` / `BoxMesh` / `CylinderMesh` | NAKED PRIMITIVES in the player's hand |
| Dawn Skiff | `SM_Vehicle_DawnSkiff.glb` | REAL |
| Utility Drone (H) | glowing `SphereMesh` + rotor | NAKED PRIMITIVE |
| Utility Robot (U) | stacked `BoxMesh`es | NAKED PRIMITIVE |
| Building pieces (player base) | `BoxMesh` per piece | NAKED PRIMITIVES |
| Dungeon interiors | boxes + spheres (walls, orbs) | NAKED PRIMITIVES |
| Dungeon portal | `CylinderMesh` beam | NAKED PRIMITIVE |
| UI | text-only Labels/Panels; **zero icon assets, zero art** | TEXT-ONLY |
| Title screen | flat dark `ColorRect` + 64px text | TEXT-ONLY, no logo art |
| Terrain | procedural mesh, vertex-coloured per zone, flat-shaded | OK for the style lock (stylized low-poly) |
| Sky/fog | one global `ProceduralSkyMaterial` + day/night ramp | no per-zone identity |

### Audio cue audit (36 WAV / 34 wired streams)

| category | coverage | gaps |
|---|---|---|
| UI | hover/click/cancel/confirm/warning/craft/research | — |
| Player | jump, land, heartbeat, scan ping | no footsteps in these zones → falls back |
| Weapons | 5 fire sounds + 2 impacts | melee swing has **no sound** |
| Echoes | 6 production-species vocals | **208 species are silent** |
| Ambience | 5 beds mapped to all 12 zones (many zones share one bed) | only 5 unique beds for 12 zones |
| Footsteps | grass/stone/sand/water/metal | no snow/muck/ash mapping per zone |
| Music | **none** | no title theme, no exploration music, no day/night shift |
| Stingers | capture success, legendary wake, warning | **no evolve stinger**, no quest-complete |

## 4 · Naked primitives visible during normal play

1. **93.9% of all creatures** — 214 species are box/sphere assemblies with flat colours.
2. **Every village hut, stake, dock plank and lamp post** (cylinder+prism+boxes).
3. **3 melee weapons** held by the player (2 boxes + 1 cylinder).
4. **Utility Drone and Utility Robot** — a ball and stacked boxes.
5. **All player-built structures** (every building piece is one box).
6. **Both dungeon interiors** (walls/floors/orbs are boxes and spheres).
7. **Boss telegraphs** (cylinder discs, spheres) — acceptable as VFX, not as creatures.

## 5 · What a new player actually sees in the first 5 minutes (blunt)

**Boot:** a near-black rectangle with "ASTRAWILD" in 64 px gold text, a wall of
keybind text, and two default-styled Godot buttons. No logo, no background art,
no music, no version number. It looks like a debug build, because it is one.

**Minute 1–2 (Dawn Fields):** the surprise — terrain is flat-shaded stylized low-poly
with believable vertex-colour blending, there are real (if simple) GLB conifers and
broadleaf trees, granite boulders, grass tufts and ferns swaying on MultiMesh, and
glowing Astraite nodes scattered around. Fog + ACES tonemapping + a warm sun ramp
make the first frame genuinely pleasant. The world reads as a real (cheap) game.

**Minute 2–4 (first creatures):** the illusion breaks. The first wild Echoes are
**coloured boxes with glowing eyes** — a quadruped is a brown box with four box
legs and two sphere eyes; a floater is a sphere with orbiting box shards. They bob
and swing their legs convincingly (code animation is solid), but up close there is
no silhouette to distinguish a Thistlehare from a Gloomcub beyond colour and size.
Capturing one feels like catching an unshaped idea.

**Minute 4–5 (first village):** mud-coloured cylinder huts with pyramid roofs,
box lamp posts, and NPCs that are **the player's own model recoloured**, standing
behind text labels. Interactions work (vendor, quests), but visually the village
reads as "placeholder settlement".

**Honest verdict of the starting experience:** environment 6/10, creatures 2.5/10,
structures 3/10, UI 2/10, audio 4/10 (effects exist, music absent). The ground and
sky promise a stylized low-poly game; the creatures and huts break that promise
214 times in a row. This is exactly what Phase V2–V6 exist to fix.

## 6 · Style-lock check (C1)

Everything on disk today is already stylized flat-shaded low-poly with no textures —
the repo is *already* style-locked. Any Quaternius/Kenney/CC0 low-poly pack will
sit consistently beside these assets. No photoreal assets exist to reject.

---
*End of Phase V1. Nothing was changed in this phase except this document.*