#!/usr/bin/env python3
"""v1.2 V11-c: expand Tier-B species → Quaternius rig mappings.

Every previously-procedural bestiary species gets a real animated rig,
chosen deterministically from its body_plan pool (stable md5 hash of the
species id, so rebuilds are reproducible), with a calibrated scale:

    rig.scale = TARGET_LEN[size_class] / rig_native_len

TARGET lengths match the existing Tier-A feel (Fox@Small ≈ 1.4 m,
Wolf@Medium ≈ 2.2 m). Existing manual mappings are never overwritten.
Existing species with their own production `model` are skipped.
"""
import json
import hashlib
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

# native max-extent (m) measured by tools/measure_rigs.gd (Godot 4.7.2 headless)
NATIVE = {
    "animals/Alpaca.gltf": 5.40, "animals/Bull.gltf": 8.07, "animals/Cow.gltf": 8.07,
    "animals/Deer.gltf": 4.40, "animals/Donkey.gltf": 4.71, "animals/Fox.gltf": 5.88,
    "animals/Horse.gltf": 5.68, "animals/Horse_White.gltf": 5.68, "animals/Husky.gltf": 3.89,
    "animals/ShibaInu.gltf": 3.95, "animals/Stag.gltf": 4.84, "animals/Wolf.gltf": 5.55,
    "monsters_big/Birb.gltf": 4.65, "monsters_big/BlueDemon.gltf": 4.63, "monsters_big/Bunny.gltf": 4.79,
    "monsters_big/Cactoro.gltf": 4.65, "monsters_big/Demon.gltf": 4.66, "monsters_big/Dino.gltf": 4.65,
    "monsters_big/Fish.gltf": 4.66, "monsters_big/Frog.gltf": 4.65, "monsters_big/Monkroose.gltf": 4.65,
    "monsters_big/MushroomKing.gltf": 4.65, "monsters_big/Orc.gltf": 4.68, "monsters_big/Orc_Skull.gltf": 4.69,
    "monsters_big/Tribal.gltf": 4.65, "monsters_big/Yeti.gltf": 4.65,
    "monsters_blob/Cat.gltf": 2.10, "monsters_blob/Chicken.gltf": 2.35, "monsters_blob/Dog.gltf": 2.14,
    "monsters_blob/GreenBlob.gltf": 2.25, "monsters_blob/GreenSpikyBlob.gltf": 4.16,
    "monsters_blob/Mushnub.gltf": 3.30, "monsters_blob/Mushnub_Evolved.gltf": 4.41,
    "monsters_blob/Pigeon.gltf": 2.35, "monsters_blob/PinkBlob.gltf": 2.01,
    "monsters_blob/Wizard.gltf": 2.60, "monsters_blob/Yeti.gltf": 2.59,
    "monsters_flying/Alpaking.gltf": 4.30, "monsters_flying/Alpaking_Evolved.gltf": 4.30,
    "monsters_flying/Armabee.gltf": 4.30, "monsters_flying/Armabee_Evolved.gltf": 4.30,
    "monsters_flying/Demon.gltf": 5.47, "monsters_flying/Dragon.gltf": 4.38,
    "monsters_flying/Dragon_Evolved.gltf": 5.48, "monsters_flying/Ghost.gltf": 5.50,
    "monsters_flying/Ghost_Skull.gltf": 5.50, "monsters_flying/Glub.gltf": 4.30,
    "monsters_flying/Glub_Evolved.gltf": 4.30, "monsters_flying/Goleling.gltf": 4.38,
    "monsters_flying/Goleling_Evolved.gltf": 4.38, "monsters_flying/Hywirl.gltf": 5.54,
    "monsters_flying/Pigeon.gltf": 4.13, "monsters_flying/Squidle.gltf": 5.47,
    "monsters_flying/Tribal.gltf": 5.50,
}

TARGET = {"Tiny": 0.8, "Small": 1.4, "Medium": 2.0, "Large": 3.2, "Huge": 4.6}

POOLS = {
    "Quadruped": ["animals/Deer", "animals/Stag", "animals/Horse", "animals/Horse_White",
                  "animals/Donkey", "animals/Alpaca", "animals/Bull", "animals/Cow",
                  "animals/Husky", "animals/ShibaInu", "animals/Wolf", "animals/Fox"],
    "Biped": ["monsters_big/Tribal", "monsters_big/Orc", "monsters_big/Monkroose",
              "monsters_big/Yeti", "monsters_big/BlueDemon", "monsters_big/Demon",
              "monsters_blob/Wizard", "monsters_big/Orc_Skull"],
    "Avian": ["monsters_big/Birb", "monsters_blob/Chicken", "monsters_blob/Pigeon",
              "monsters_flying/Pigeon", "monsters_flying/Alpaking", "monsters_flying/Dragon"],
    "Floating": ["monsters_flying/Ghost", "monsters_flying/Ghost_Skull", "monsters_flying/Hywirl",
                 "monsters_flying/Squidle", "monsters_flying/Demon"],
    "Amorphous": ["monsters_blob/GreenBlob", "monsters_blob/PinkBlob", "monsters_blob/GreenSpikyBlob",
                  "monsters_blob/Mushnub", "monsters_big/Cactoro", "monsters_big/MushroomKing",
                  "monsters_flying/Glub"],
    "Insectoid": ["monsters_flying/Armabee", "monsters_flying/Armabee_Evolved",
                  "monsters_flying/Glub", "monsters_flying/Glub_Evolved", "monsters_flying/Squidle"],
    "Serpent": ["monsters_big/Fish", "monsters_flying/Hywirl", "monsters_flying/Squidle",
                "monsters_flying/Glub"],
    "Crystalline": ["monsters_flying/Goleling", "monsters_flying/Goleling_Evolved",
                    "monsters_big/Dino", "monsters_big/Monkroose"],
}

def stable_index(sid: str, n: int) -> int:
    return int(hashlib.md5(sid.encode()).hexdigest(), 16) % n


def size_jitter(sid: str) -> float:
    """deterministic ±8% so same-rig species differ in size"""
    return 0.92 + (int(hashlib.md5((sid + "#s").encode()).hexdigest(), 16) % 17) / 100.0

def main() -> None:
    with open(os.path.join(ROOT, "data", "bestiary.json")) as f:
        bestiary = json.load(f)
    species = bestiary if isinstance(bestiary, list) else bestiary.get("species", [])
    with open(os.path.join(ROOT, "data", "species_special.json")) as f:
        special = json.load(f)
    special_species = special if isinstance(special, list) else special.get("species", [])
    has_model = {s["id"] for s in special_species if s.get("model")}

    models_path = os.path.join(ROOT, "data", "species_models.json")
    with open(models_path) as f:
        doc = json.load(f)
    maps = doc.get("maps", {})
    before = len(maps)

    added = {}
    for s in species:
        sid = s["id"]
        if sid in maps or sid in has_model:
            continue
        plan = s.get("body_plan", "Quadruped")
        pool = POOLS.get(plan, POOLS["Quadruped"])
        rig = pool[stable_index(sid, len(pool))] + ".gltf"
        native = NATIVE[rig]
        target = TARGET.get(s.get("size_class", "Medium"), 2.0)
        scale = max(0.1, min(1.2, round(target / native * size_jitter(sid), 3)))
        added[sid] = {"rig": rig, "scale": scale, "tint": True}

    maps.update(added)
    doc["maps"] = dict(sorted(maps.items()))
    doc["_comment"] = (
        "Phase V4 mesh-resolution overrides + v1.2 V11-c Tier-B expansion. "
        "Manual entries first (Tier S/A); every remaining bestiary species is "
        "mapped deterministically (md5 of id) to a Quaternius CC0 rig from its "
        "body_plan pool, scale calibrated = TARGET[size_class]/native (see "
        "tools/build_rig_maps.py + tools/measure_rigs.gd)."
    )
    with open(models_path, "w") as f:
        json.dump(doc, f, indent=1, sort_keys=True)
        f.write("\n")

    from collections import Counter
    plan_counts = Counter()
    rig_counts = Counter()
    for sid, v in added.items():
        plan_counts[next(s["body_plan"] for s in species if s["id"] == sid)] += 1
        rig_counts[v["rig"]] += 1
    print(f"mapped before: {before}")
    print(f"added now:     {len(added)}")
    print(f"mapped total:  {len(maps)} / {len(species)} bestiary species")
    print(f"added by plan: {dict(plan_counts)}")
    print(f"top rigs used: {rig_counts.most_common(8)}")
    untouched = [s["id"] for s in species if s["id"] not in maps and s["id"] not in has_model]
    print(f"still procedural (no map, no model): {len(untouched)} {untouched[:8]}")

if __name__ == "__main__":
    sys.exit(main())
