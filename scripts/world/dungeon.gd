class_name DungeonGenerator
extends Node3D
## Procedural dungeon (UE5 AstrawildDungeonGeneratorActor, Batch 6 + 8).
## Linear room chain with sealed gates that open when a room clears, hand-authored
## room templates, deterministic layout (world seed + dungeon salt), a phased boss
## in the final room, resonance portals (entrance/exit), and clear rewards.
## Hollow Underlight: 5 rooms east of the wilds' edge. Sunken Vault: 4 rooms
## deep in the Tidebreaker Isles, boss Dawnfang (Creature_VaultColossus).

var dungeon_id := "Dungeon_HollowUnderlight"
var display_name := "The Hollow Underlight"
var start := Vector3.ZERO
var direction := Vector3(1, 0, 0)      # room chain heading
var rooms: Array = []                   # built room dicts
var room_count := 5
var boss_species_id := "Creature_UnderlightWarden"
var boss_defeat_event := "Creature_UnderlightWarden"
var reward_rp := 10
var reward_tech := "Tech_AncientResonance"
var reward_loot: Array = [{"item": "Item_AncientCore", "qty": 1}, {"item": "Item_CrystalShard", "qty": 3}, {"item": "Item_DawnShard", "qty": 2}]
var creature_pool := ["Echo_Gloomfang", "Echo_Gloomfang", "Echo_Stonehide"]
var _rng := RandomNumberGenerator.new()
var _world: Node3D = null
var cleared := {}                      # room index -> bool
var completed := false
var _gate_bodies: Array = []
var _exit_portal: Node3D = null
var _rooms_root: Node3D = null


## UE5 room templates: half-extents (m) per room type.
const ROOM_TEMPLATES := [
        {"type": "Entry", "size": Vector3(10, 6, 10), "guards": 0},
        {"type": "Combat", "size": Vector3(13, 6.4, 13), "guards": 2},
        {"type": "Puzzle", "size": Vector3(12, 6, 12), "guards": 1},
        {"type": "Elite", "size": Vector3(14, 6.8, 14), "guards": 2},
        {"type": "Boss", "size": Vector3(18, 8, 18), "guards": 0},
]


func setup(p_id: String, p_name: String, p_start: Vector3, p_dir: Vector3, p_rooms: int, p_boss: String, p_boss_event: String) -> void:
        dungeon_id = p_id
        display_name = p_name
        start = p_start
        direction = p_dir.normalized()
        room_count = clampi(p_rooms, 3, 12)
        boss_species_id = p_boss
        boss_defeat_event = p_boss_event


func build(parent: Node3D, world: Node3D) -> void:
        _world = world
        _rng.seed = hash("dungeon-%s-%d" % [dungeon_id, Game.world_seed + 777])
        _rooms_root = Node3D.new()
        _rooms_root.name = "Dungeon_%s" % dungeon_id
        parent.add_child(_rooms_root)

        var cursor := start
        for i in room_count:
                var tpl: Dictionary = _template_for(i)
                var size: Vector3 = tpl["size"]
                var pos := cursor + Vector3(0, 0, 0)
                var floor_y: float = world.tile_height(pos.x, pos.z) if world and world.has_method("tile_height") else 0.0
                # UE5: +-400 cm lateral zigzag between room centers
                var lateral: float = _rng.randf_range(-4.0, 4.0) * (0.0 if i == 0 else 1.0)
                var perp := Vector3(-direction.z, 0, direction.x)
                pos = cursor + perp * lateral
                pos.y = world.tile_height(pos.x, pos.z) if world and world.has_method("tile_height") else 0.0
                var room := _build_room(i, tpl, pos, floor_y)
                rooms.append(room)
                # 22 m between room centers (UE5: 2200 cm)
                cursor = pos + direction * (size.x * 0.5 + _template_for(i + 1)["size"].x * 0.5 + 4.0) if i + 1 < room_count else cursor

        # gates between consecutive rooms
        for i in room_count - 1:
                _build_gate(i)

        # portals: entrance pad outside + exit pad beside the entry room
        _build_portals(world)

        # entry room auto-clears
        cleared[0] = true
        _open_gate(0)
        _check_room_states()


func _template_for(index: int) -> Dictionary:
        if index >= room_count - 1:
                return ROOM_TEMPLATES[4]  # boss last
        return ROOM_TEMPLATES[index]


func _build_room(index: int, tpl: Dictionary, pos: Vector3, floor_y: float) -> Dictionary:
        var size: Vector3 = tpl["size"]
        var room := {"index": index, "type": tpl["type"], "pos": pos, "size": size, "creatures": [], "cleared": index == 0}

        var room_node := Node3D.new()
        room_node.name = "Room%d_%s" % [index, tpl["type"]]
        room_node.position = pos
        _rooms_root.add_child(room_node)

        var stone := StandardMaterial3D.new()
        stone.albedo_color = Color(0.22, 0.2, 0.26)
        stone.roughness = 0.95
        var accent := StandardMaterial3D.new()
        accent.albedo_color = Color(0.5, 0.35, 0.6)
        accent.emission_enabled = true
        accent.emission = Color(0.55, 0.3, 0.65)
        accent.emission_energy_multiplier = 1.6

        # floor plate
        var floor_mesh := _box(room_node, Vector3(size.x, 0.4, size.z), Vector3(0, 0.2, 0), stone)
        floor_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        # perimeter walls (gap on the chain axis for gates)
        var wall_h := size.y
        var wall_t := 0.5
        var gate_gap := 3.2
        # side walls
        _box(room_node, Vector3(size.x + wall_t, wall_h, wall_t), Vector3(0, wall_h * 0.5, size.z * 0.5), stone)
        _box(room_node, Vector3(size.x + wall_t, wall_h, wall_t), Vector3(0, wall_h * 0.5, -size.z * 0.5), stone)
        # back wall (behind entry axis) and front wall split around the gate gap
        var back_axis := -direction
        var back_off := back_axis * (size.x * 0.5)
        var fwd_off := direction * (size.x * 0.5)
        var perp := Vector3(-direction.z, 0, direction.x)
        # local-space axis math: rooms extend along world direction; convert to local boxes via a wrapper
        var shell := Node3D.new()
        shell.rotation.y = atan2(direction.x, direction.z) - PI / 2.0
        room_node.add_child(shell)
        _box(shell, Vector3(wall_t, wall_h, size.z + wall_t), Vector3(-size.x * 0.5, wall_h * 0.5, 0), stone)
        _box(shell, Vector3(wall_t, wall_h, size.z * 0.5 - gate_gap * 0.5), Vector3(size.x * 0.5, wall_h * 0.5, -(size.z * 0.25 + gate_gap * 0.25)), stone)
        _box(shell, Vector3(wall_t, wall_h, size.z * 0.5 - gate_gap * 0.5), Vector3(size.x * 0.5, wall_h * 0.5, (size.z * 0.25 + gate_gap * 0.25)), stone)
        _box(shell, Vector3(wall_t, wall_h, gate_gap), Vector3(size.x * 0.5, wall_h - 1.2, 0), stone)  # lintel above the gate gap

        # corner braziers
        for corner in [Vector3(size.x * 0.42, 0, size.z * 0.42), Vector3(-size.x * 0.42, 0, -size.z * 0.42)]:
                var brz := _mesh_sphere(room_node, 0.28, corner + Vector3(0, 1.1, 0), accent)
                var light := OmniLight3D.new()
                light.position = corner + Vector3(0, 1.4, 0)
                light.omni_range = 12.0
                light.light_color = Color(0.75, 0.5, 0.9)
                light.light_energy = 1.2
                room_node.add_child(light)

        # collision floor
        var body := StaticBody3D.new()
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(size.x, 0.4, size.z)
        col.shape = shape
        col.position = Vector3(0, 0.2, 0)
        body.add_child(col)
        body.collision_layer = 1
        room_node.add_child(body)

        # link the room node before creature spawns need it
        room["node"] = room_node
        # room creatures (pool cycled by room index; boss room spawns the boss + 1 add offset)
        if index > 0 and index < room_count - 1:
                var guards: int = int(tpl.get("guards", 1))
                for g in guards:
                        var sid: String = creature_pool[(index + g) % creature_pool.size()]
                        _spawn_room_creature(room, sid, Vector3(randf() * 6.0 - 3.0, 0, randf() * 6.0 - 3.0))
        elif index == room_count - 1:
                _spawn_room_creature(room, boss_species_id, Vector3(4, 0, 0), true)
                if index >= 3:
                        _spawn_room_creature(room, creature_pool[0], Vector3(-5, 0, 3))
        return room


func _spawn_room_creature(room: Dictionary, species_id: String, local_offset: Vector3, boss: bool = false) -> void:
        var def: Dictionary = Data.species_def(species_id)
        if def.is_empty():
                return
        var echo = load("res://scripts/creatures/echo.gd").new(def, _rng)
        var room_node: Node3D = room["node"]
        var wp := room_node.position + room_node.basis * local_offset
        wp.y = _world.tile_height(wp.x, wp.z) + 0.2 if _world and _world.has_method("tile_height") else wp.y
        echo.position = wp
        echo.boss_mode = boss
        echo.set_meta("dungeon_id", dungeon_id)
        echo.set_meta("room_index", room["index"])
        # creatures live under the world's creatures root so sweeps can see them
        var world := _world
        if world and world.get("creatures_root"):
                world.creatures_root.add_child(echo)
        room["creatures"].append(echo)


# -------------------------------------------------------------------- gates --
func _build_gate(i: int) -> void:
        # gate i seals the passage between room i and room i+1
        var a: Dictionary = rooms[i]
        var b: Dictionary = rooms[i + 1]
        var gate_pos: Vector3 = (a["pos"] + b["pos"]) * 0.5
        gate_pos.y = _world.tile_height(gate_pos.x, gate_pos.z) if _world and _world.has_method("tile_height") else 0.0
        var gate := Node3D.new()
        gate.name = "Gate%d" % i
        gate.position = gate_pos
        gate.rotation.y = atan2(direction.x, direction.z) - PI / 2.0
        _rooms_root.add_child(gate)

        var arch_mat := StandardMaterial3D.new()
        arch_mat.albedo_color = Color(0.18, 0.16, 0.22)
        arch_mat.roughness = 0.9
        var rune_mat := StandardMaterial3D.new()
        rune_mat.albedo_color = Color(0.9, 0.5, 0.3)
        rune_mat.emission_enabled = true
        rune_mat.emission = Color(1.0, 0.45, 0.2)
        rune_mat.emission_energy_multiplier = 2.0

        # two pillars + lintel (the arch stays as a doorway when open)
        _box(gate, Vector3(0.7, 4.6, 0.7), Vector3(0, 2.3, -2.0), arch_mat)
        _box(gate, Vector3(0.7, 4.6, 0.7), Vector3(0, 2.3, 2.0), arch_mat)
        _box(gate, Vector3(0.8, 0.8, 4.8), Vector3(0, 4.8, 0), arch_mat)
        # crossbar: dropped at chest height while sealed, lifted into the lintel when open
        var crossbar := _box(gate, Vector3(0.35, 0.35, 4.2), Vector3(0, 1.5, 0), rune_mat)
        # blocking collision (UE5: 120x1040x840 cm box)
        var body := StaticBody3D.new()
        var col := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(1.2, 4.2, 3.4)
        col.shape = shape
        col.position = Vector3(0, 2.1, 0)
        body.add_child(col)
        body.collision_layer = 4
        gate.add_child(body)

        var gate_data := {"index": i, "node": gate, "body": body, "crossbar": crossbar, "open": false}
        _gate_bodies.append(gate_data)


func _open_gate(i: int) -> void:
        if i >= _gate_bodies.size():
                return
        var gd: Dictionary = _gate_bodies[i]
        if gd["open"]:
                return
        gd["open"] = true
        var body: StaticBody3D = gd["body"]
        body.set_collision_layer_value(1, false)
        body.set_collision_layer_value(2, false)
        # lift the crossbar into the lintel (UE5: Z 60 -> Z 520)
        var crossbar: MeshInstance3D = gd["crossbar"]
        var tw := create_tween()
        tw.tween_property(crossbar, "position:y", 4.4, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ------------------------------------------------------------------ portals --
func _build_portals(world: Node3D) -> void:
        var entrance_pos := start - direction * 14.0
        entrance_pos.y = world.tile_height(entrance_pos.x, entrance_pos.z) if world and world.has_method("tile_height") else 0.0
        var exit_pos := (rooms[0]["pos"] as Vector3) + Vector3(-direction.z, 0, direction.x) * 9.0
        exit_pos.y = world.tile_height(exit_pos.x, exit_pos.z) if world and world.has_method("tile_height") else 0.0

        var portal_script := load("res://scripts/world/dungeon_portal.gd")
        var entrance: Node3D = Node3D.new()
        entrance.set_script(portal_script)
        entrance.position = entrance_pos
        entrance.set_meta("portal_id", "Location_%s" % dungeon_id.replace("Dungeon_", ""))
        entrance.set_meta("portal_label", "%s — Resonance Gate" % display_name)
        entrance.set_meta("portal_color", Color(0.8, 0.45, 0.9))
        entrance.set_meta("portal_dest", (rooms[0]["pos"] as Vector3) + Vector3(0, 1.5, 0) + direction * 3.0)
        _rooms_root.add_child(entrance)

        _exit_portal = Node3D.new()
        _exit_portal.set_script(portal_script)
        _exit_portal.position = exit_pos
        _exit_portal.set_meta("portal_id", "Location_DawnCamp")
        _exit_portal.set_meta("portal_label", "Exit — Return to the Vale")
        _exit_portal.set_meta("portal_color", Color(0.45, 0.9, 0.8))
        _exit_portal.set_meta("portal_dest", entrance_pos + direction * 3.0)
        _rooms_root.add_child(_exit_portal)


# -------------------------------------------------------------------- clear --
func _process(_delta: float) -> void:
        if completed:
                return
        _check_room_states()


func _check_room_states() -> void:
        for room in rooms:
                var idx: int = room["index"]
                if room.get("cleared", false) or cleared.get(idx, false):
                        continue
                var all_dead := true
                for c in room["creatures"]:
                        if is_instance_valid(c) and not c.get("defeated"):
                                all_dead = false
                                break
                if all_dead and room["creatures"].size() > 0:
                        room["cleared"] = true
                        cleared[idx] = true
                        _open_gate(idx)
                        Game.toast.emit("%s chamber cleared — the gate resonates open." % display_name, Color(0.8, 0.7, 1.0))
                        if idx == room_count - 1:
                                _on_dungeon_complete()
                elif room["creatures"].is_empty() and idx == 0:
                        room["cleared"] = true


func _on_dungeon_complete() -> void:
        completed = true
        Game.add_research_points(reward_rp)
        for drop in reward_loot:
                Game.add_item(drop["item"], int(drop["qty"]))
        if reward_tech != "" and not Game.is_tech_unlocked(reward_tech):
                Game.force_unlock_tech(reward_tech)
        Game.toast.emit("%s CONQUERED — +%d RP, vault loot claimed!" % [display_name, reward_rp], Color(1.0, 0.85, 0.5))


# --------------------------------------------------------------------- save --
func get_save_data() -> Dictionary:
        return {"id": dungeon_id, "cleared": cleared, "completed": completed}


func apply_save_data(data: Dictionary) -> void:
        cleared = data.get("cleared", {})
        completed = data.get("completed", false)
        if completed:
                for i in _gate_bodies.size():
                        _open_gate(i)
        else:
                for i in _gate_bodies.size():
                        if cleared.get(i, false):
                                _open_gate(i)
        # remove already-cleared room creatures
        for room in rooms:
                if cleared.get(room["index"], false):
                        for c in room["creatures"]:
                                if is_instance_valid(c) and not c.get("defeated"):
                                        c.queue_free()
        if completed:
                for room in rooms:
                        for c in room["creatures"]:
                                if is_instance_valid(c):
                                        c.queue_free()


# ------------------------------------------------------------------ helpers --
func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = size
        mi.mesh = box
        mi.material_override = mat
        mi.position = pos
        mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
        parent.add_child(mi)
        return mi


func _mesh_sphere(parent: Node3D, radius: float, pos: Vector3, mat: Material) -> MeshInstance3D:
        var mi := MeshInstance3D.new()
        var sph := SphereMesh.new()
        sph.radius = radius
        sph.height = radius * 2.0
        mi.mesh = sph
        mi.material_override = mat
        mi.position = pos
        parent.add_child(mi)
        return mi
