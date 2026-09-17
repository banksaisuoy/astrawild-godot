# ASTRAWILD — Echo Mods

ASTRAWILD ships with a runtime **mod loader**. Mods are plain folders containing a `mod.json` file — no engine, no compilation, no scripting. Drop them in and play.

## Where mods are loaded from (in order)

| Location | Purpose |
|---|---|
| `res://mods/` | Bundled mods shipped with the game (read-only inside the PCK) |
| `<game folder>/mods/` | **Portable mods** — put a `mods/` folder next to `Astrawild.exe` / `Astrawild.x86_64` |
| `user://mods/` | Persistent mods — Windows: `%APPDATA%/Astrawild/mods`, Linux: `~/.local/share/Astrawild/mods` |

Later mods with the same `id` override earlier ones.

## mod.json format

```json
{
  "id": "frost_legends",
  "name": "Frost Legends",
  "version": "1.0.0",
  "author": "you",
  "description": "Adds legendary frost Echoes.",
  "species": [ ... ],
  "items": [ ... ],
  "recipes": [ ... ]
}
```

All three content arrays are optional — ship only what your mod needs.

### species[]

```json
{
  "id": "Echo_Frostwyrm",
  "name": "Frostwyrm",
  "family": "Dragon",
  "body_plan": "Serpent",
  "size_class": "Huge",
  "element": "Frost",
  "weakness": "Ember",
  "role": "Combat",
  "home_zone": "Frostveil",
  "personality": "Territorial",
  "activity": "Nocturnal",
  "stats": { "hp": 520.0, "atk": 48.0, "def": 30.0, "spd": 300.0 },
  "capture_difficulty": 0.85,
  "hostile": true,
  "colors": { "primary": [0.6, 0.8, 1.0], "secondary": [0.3, 0.4, 0.6] },
  "foods": ["Item_CookedMeat"],
  "loot": [ { "item": "Item_CrystalShard", "qty": 3 } ],
  "work": ["Combat"],
  "sight_radius": 1600.0,
  "work_affinity": 1.4,
  "spawn_count": 1
}
```

- `body_plan` must be one of: `Quadruped`, `Biped`, `Serpent`, `Avian`, `Floating`, `Amorphous` (anything else falls back to Quadruped).
- `home_zone` must be a bare zone key: `Frostveil`, `Glimmerwood`, `EmberRidge`, `Sunscar`, `DuskMarsh`, `DawnFields`, `HollowApproach`, `AzureShallows`, `TidebreakerIsles`, `Stormcrest`, `VerdantReach`, `PearlseaReef`.
- `spawn_count` (default 1) controls how many spawn in the home zone each world generation. Mod species are **automatically appended to the zone's wildlife roster** so they appear in the world.
- Reusing an existing species `id` **overrides** the base-game entry — great for rebalance mods. Loot/food item ids must exist in the game (or in your own `items`).

### items[]

```json
{
  "id": "Item_Spicemix",
  "name": "Spice Mix",
  "category": "material",
  "weight": 0.3,
  "stack": 100,
  "desc": "Crushed wild herbs.",
  "food": 0, "water": 0, "feed_value": 0
}
```

`food`/`water`/`feed_value` only apply to `consumable` items.

### recipes[]

```json
{
  "id": "Recipe_Spicemix",
  "name": "Spice Mix",
  "inputs": [ { "item": "Item_Berry", "qty": 2 } ],
  "outputs": [ { "item": "Item_Spicemix", "qty": 1 } ],
  "time": 4.0,
  "tech": null,
  "station": null
}
```

- `station`: `null` (craft anywhere), `"Station_Campfire"` or `"Station_Workbench"`.
- `tech`: `null` or a tech id such as `"Tech_Cooking"`.

## Bundled mods

| Mod | Contents |
|---|---|
| **Mythic Echoes** | 4 legendary Huge Echoes: Solaris the Radiant (Ember Ridge), Umbrarch (Hollow Approach), Terravore (Glimmerwood), Chronoweave (Frostveil) |
| **Chef's Toolkit** | 3 items (Vale Spice Mix, Crystal-Cured Jerky, Traveler's Feast) + 3 campfire recipes |
| **Glimmer Garden** | 2 gentle Echoes (Petalume — gather helper in Glimmerwood; Corallume — support companion in Pearlsea Reef) + Glimmer Tonic item + 2 recipes |

## In-game commands

Open the console with `` ` `` (backquote):

- `AW.mods` — list loaded mods with contents
- `AW.SpawnEcho Echo_Solaris` — spawn any modded Echo
- `AW.GiveItem Item_TravelerFeast 3` — get modded items
- `AW.ListSpecies` — species count includes modded ones

## Legendary species (v1.0.3 balance pass)

Species with `"legendary": true` — or any hostile species with `capture_difficulty >= 0.85` — are treated as **legendaries**:

- They spawn **dormant** (☾ nameplate, golden pulsing ground ring, quarter movement speed) and **never aggro on sight** — the player always chooses the fight.
- Damaging a dormant legendary **wakes** it ("Solaris the Radiant awakens!" toast) and it fights to the end — legendaries never flee at low HP.

## Save compatibility

Mod content lives in the Data registries; saves only store ids. Removing a mod simply removes its creatures from future spawns — existing saves keep working.
