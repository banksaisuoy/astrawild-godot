extends Node
## ModLoader — runtime mod injection (user request: "find/download mods to use").
## Scans, in order: res://mods (bundled), <exe_dir>/mods (portable), user://mods (persistent).
## Each mod lives in <scan_dir>/<mod-folder>/mod.json and may add:
##   species[] — Echo creatures (auto-appended to their home zone wildlife so they spawn)
##   items[]   — inventory items
##   recipes[] — crafting recipes (inputs/outputs/tech/station)
## Mod species with an id that already exists override the base game entry (rebalance mods).

const SCAN_DIRS_BUNDLED := "res://mods"
const SCAN_DIR_USER := "user://mods"

const SPECIES_REQUIRED := ["id", "name"]
const BODY_PLANS := ["Quadruped", "Biped", "Serpent", "Avian", "Floating", "Amorphous"]

var mods := {}  # mod id -> info dict {name, version, author, description, source, counts}
var load_log: Array[String] = []


func _ready() -> void:
        var dirs: Array[String] = [SCAN_DIRS_BUNDLED]
        # Portable mods folder next to the executable (desktop builds only).
        if OS.has_feature("template"):
                var exe_dir := OS.get_executable_path().get_base_dir()
                dirs.append(exe_dir.path_join("mods"))
        dirs.append(SCAN_DIR_USER)
        for d in dirs:
                _scan_dir(d)
        _report()


# ------------------------------------------------------------------ scan --

func _scan_dir(dir_path: String) -> void:
        if not DirAccess.dir_exists_absolute(dir_path):
                return
        var dir := DirAccess.open(dir_path)
        if dir == null:
                return
        dir.list_dir_begin()
        var name := dir.get_next()
        while not name.is_empty():
                if dir.current_is_dir() and not name.begins_with("."):
                        var mod_file := dir_path.path_join(name).path_join("mod.json")
                        if FileAccess.file_exists(mod_file):
                                _load_mod_file(mod_file, dir_path)
                name = dir.get_next()
        dir.list_dir_end()


func _load_mod_file(path: String, source_dir: String) -> void:
        var f := FileAccess.open(path, FileAccess.READ)
        if f == null:
                load_log.append("ModLoader: cannot read %s" % path)
                return
        var parsed: Variant = JSON.parse_string(f.get_as_text())
        if parsed == null or not (parsed is Dictionary):
                load_log.append("ModLoader: invalid JSON in %s" % path)
                return
        var mod: Dictionary = parsed
        var id := str(mod.get("id", ""))
        if id.is_empty():
                load_log.append("ModLoader: mod at %s has no id" % path)
                return
        var counts := _apply_mod(mod)
        var source := "bundled"
        if source_dir.begins_with("user://"):
                source = "user"
        elif not source_dir.begins_with("res://"):
                source = "portable"
        mods[id] = {
                "name": str(mod.get("name", id)),
                "version": str(mod.get("version", "0.0.0")),
                "author": str(mod.get("author", "unknown")),
                "description": str(mod.get("description", "")),
                "source": source,
                "path": path,
                "counts": counts,
        }
        load_log.append("ModLoader: loaded '%s' v%s [%s] — %d species, %d items, %d recipes" % [
                mods[id]["name"], mods[id]["version"], source,
                counts["species"], counts["items"], counts["recipes"]])


# ----------------------------------------------------------------- apply --

func _apply_mod(mod: Dictionary) -> Dictionary:
        var counts := {"species": 0, "items": 0, "recipes": 0}

        for raw in mod.get("species", []):
                if not (raw is Dictionary):
                        continue
                var s := _normalize_species(raw)
                if s.is_empty():
                        load_log.append("ModLoader: species entry in '%s' missing id/name — skipped" % str(mod.get("id", "?")))
                        continue
                var sid: String = s["id"]
                var is_new: bool = not Data.species.has(sid)
                Data.species[sid] = s
                var zid: String = s.get("home_zone", "")
                if not zid.is_empty():
                        # Zone index (uses the bare zone key, e.g. "Frostveil").
                        if not Data.species_by_zone.has(zid):
                                Data.species_by_zone[zid] = []
                        if not Data.species_by_zone[zid].has(sid):
                                Data.species_by_zone[zid].append(sid)
                        # Make it actually spawn: append to the zone wildlife roster.
                        _add_to_zone_wildlife(zid, sid, int(s.get("spawn_count", 1)), is_new)
                counts["species"] += 1

        for raw_it in mod.get("items", []):
                if not (raw_it is Dictionary) or not raw_it.has("id"):
                        continue
                _normalize_item(raw_it)
                Data.items[raw_it["id"]] = raw_it
                counts["items"] += 1

        for raw_r in mod.get("recipes", []):
                if not (raw_r is Dictionary) or not raw_r.has("id"):
                        continue
                var r: Dictionary = raw_r
                # v1.0.4: null-safety — mods may ship "tech": null / "station": null,
                # which crashes the crafting screen's typed String reads. Coerce.
                var tech_v: Variant = r.get("tech", "")
                r["tech"] = tech_v if tech_v is String else ""
                var station_v: Variant = r.get("station", "")
                r["station"] = station_v if station_v is String else ""
                r["inputs_by_item"] = {}
                for inp in r.get("inputs", []):
                        r["inputs_by_item"][inp["item"]] = inp["qty"]
                var replaced := false
                for i in Data.recipes.size():
                        if Data.recipes[i].get("id", "") == r["id"]:
                                Data.recipes[i] = r
                                replaced = true
                                break
                if not replaced:
                        Data.recipes.append(r)
                counts["recipes"] += 1

        return counts


func _normalize_species(raw: Dictionary) -> Dictionary:
        for req in SPECIES_REQUIRED:
                if not raw.has(req) or str(raw[req]).is_empty():
                        return {}
        var body := str(raw.get("body_plan", "Quadruped"))
        if not BODY_PLANS.has(body):
                body = "Quadruped"
        var stats: Dictionary = raw.get("stats", {})
        if stats.is_empty():
                stats = {"hp": 110.0, "atk": 15.0, "def": 10.0, "spd": 420.0}
        for key in ["hp", "atk", "def", "spd"]:
                if not stats.has(key):
                        stats[key] = {"hp": 110.0, "atk": 15.0, "def": 10.0, "spd": 420.0}[key]
        var colors: Dictionary = raw.get("colors", {})
        if not colors.has("primary") or not colors.has("secondary"):
                colors = {"primary": [0.55, 0.48, 0.38], "secondary": [0.35, 0.32, 0.42]}
        var out := {
                "id": str(raw["id"]),
                "name": str(raw["name"]),
                "family": str(raw.get("family", "Beast")),
                "body_plan": body,
                "size_class": str(raw.get("size_class", "Medium")),
                "element": str(raw.get("element", "Flora")),
                "weakness": str(raw.get("weakness", "Ember")),
                "role": str(raw.get("role", "Base")),
                "home_zone": str(raw.get("home_zone", "")),
                "personality": str(raw.get("personality", "Curious")),
                "activity": str(raw.get("activity", "Diurnal")),
                "stats": stats,
                "capture_difficulty": float(raw.get("capture_difficulty", 0.5)),
                "hostile": bool(raw.get("hostile", false)),
                "colors": colors,
                "foods": raw.get("foods", []),
                "loot": raw.get("loot", []),
                "work": raw.get("work", []),
                "sight_radius": float(raw.get("sight_radius", 1200.0)),
                "work_affinity": float(raw.get("work_affinity", 1.0)),
                "spawn_count": int(raw.get("spawn_count", 1)),
                # v1.0.4: forward the flags the Echo runtime actually reads —
                # previously "legendary" was dropped, so modded legendaries
                # never spawned dormant in exports despite the flag.
                "legendary": bool(raw.get("legendary", false)),
                "passive": bool(raw.get("passive", not bool(raw.get("hostile", false)))),
                "model": str(raw.get("model", "")),
        }
        return out


func _normalize_item(it: Dictionary) -> void:
        if not it.has("name"):
                it["name"] = str(it["id"]).replace("Item_", "")
        if not it.has("category"):
                it["category"] = "material"
        if not it.has("weight"):
                it["weight"] = 0.5
        if not it.has("stack"):
                it["stack"] = 100
        if not it.has("desc"):
                it["desc"] = "A modded item."


func _add_to_zone_wildlife(zone_key: String, species_id: String, count: int, is_new: bool) -> void:
        var zone_id := "Zone_" + zone_key
        for zone in Data.zones:
                if zone.get("id", "") != zone_id:
                        continue
                var wildlife: Array = zone.get("wildlife", [])
                if not is_new:
                        # Overridden base species: replace its roster entry count if present.
                        for i in wildlife.size():
                                if wildlife[i][0] == species_id:
                                        wildlife[i] = [species_id, count]
                                        return
                wildlife.append([species_id, count])
                zone["wildlife"] = wildlife
                return


# ---------------------------------------------------------------- report --

func _report() -> void:
        if mods.is_empty():
                print("ModLoader: no mods found (res://mods, exe mods/, user://mods)")
                return
        print("ModLoader: %d mod(s) active — AW.mods in the console lists them" % mods.size())


func summary_bbcode() -> String:
        if mods.is_empty():
                return "[color=#ff9]No mods loaded.[/color] Drop mod folders with a mod.json into [color=#fc3]mods/[/color] next to the game executable or [color=#fc3]%s[/color]" % ProjectSettings.globalize_path(SCAN_DIR_USER).get_base_dir()
        var lines := "[b]%d mod(s) active:[/b]" % mods.size()
        for id in mods:
                var m: Dictionary = mods[id]
                var c: Dictionary = m["counts"]
                lines += "\n• [color=#fc3]%s[/color] v%s by %s [color=#888](%s)[/color]" % [m["name"], m["version"], m["author"], m["source"]]
                lines += "\n   %d species · %d items · %d recipes" % [c["species"], c["items"], c["recipes"]]
                if str(m["description"]) != "":
                        lines += "\n   [color=#aaa]%s[/color]" % m["description"]
        if not load_log.is_empty():
                lines += "\n[color=#888]Log tail: %s[/color]" % load_log[load_log.size() - 1]
        return lines
