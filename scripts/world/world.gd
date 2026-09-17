class_name GameWorld
extends Node3D
## World bootstrapper: terrain, water, props, resource nodes, camp, NPCs,
## POIs, creature spawner, day/night + weather FX, party followers, buildings.

var noise: WorldNoise
var tiles := {}                 # zone_id -> ZoneTerrain
var daynight: DayNightCycle
var weather_fx: WeatherFX
var creatures_root: Node3D
var props_root: Node3D
var nodes_root: Node3D
var buildings_root: Node3D
var npcs_root: Node3D
var power_grid: PowerGrid       # UE5 PowerSubsystem — 12 m grid, 2 s resolve
var world_events: WorldEventSystem  # UE5 WorldEventSubsystem — 9 archetypes
var skiffs := []                # DawnSkiff aircraft (2 per world)
var dungeons := []              # DungeonGenerator instances
var worksites := []             # WorkSite actors
var villages := []              # Village actors
var followers := {}             # party index -> Echo creature node
var _hostile_sweep := 0.0
var _rng := RandomNumberGenerator.new()
var _camp_pos := Vector3(-400, 0, 0)

# mesh library (loaded lazily, shared)
var _mesh_cache := {}


func _ready() -> void:
        seed_rng(Game.world_seed)
        noise = WorldNoise.new(Game.world_seed)


func seed_rng(world_seed: int) -> void:
        _rng.seed = hash("astrawild-%d" % world_seed)


# ------------------------------------------------------------------ build --
func build() -> void:
        if noise == null:
                noise = WorldNoise.new(Game.world_seed)
        _build_terrain()
        _build_water()
        daynight = DayNightCycle.new()
        daynight.setup()
        add_child(daynight)
        weather_fx = WeatherFX.new()
        weather_fx.setup()
        add_child(weather_fx)

        props_root = Node3D.new()
        props_root.name = "Props"
        add_child(props_root)
        nodes_root = Node3D.new()
        nodes_root.name = "ResourceNodes"
        add_child(nodes_root)
        creatures_root = Node3D.new()
        creatures_root.name = "Creatures"
        add_child(creatures_root)
        npcs_root = Node3D.new()
        npcs_root.name = "NPCs"
        add_child(npcs_root)
        buildings_root = Node3D.new()
        buildings_root.name = "Buildings"
        add_child(buildings_root)

        # power grid + world events (UE5 subsystems)
        power_grid = PowerGrid.new()
        power_grid.name = "PowerGrid"
        add_child(power_grid)
        world_events = WorldEventSystem.new()
        world_events.name = "WorldEvents"
        add_child(world_events)

        _dress_all_zones()
        _spawn_resource_nodes()
        _build_camp()
        _build_villages()
        _spawn_skiffs()
        _build_locations()
        _build_dungeons()
        _build_work_sites()
        _spawn_all_creatures()
        Game.party_changed.connect(_sync_party)
        Game.party_changed.emit()


func _build_terrain() -> void:
        for zone in Data.zones:
                var tile := ZoneTerrain.new(zone, noise)
                tile.name = zone["id"]
                tile.build()
                tiles[zone["id"]] = tile
                add_child(tile)
        _camp_pos = Vector3(-400, tile_height(-400, 0) + 0.1, 0)


func _build_water() -> void:
        var water := MeshInstance3D.new()
        var pm := PlaneMesh.new()
        pm.size = Vector2(3400, 2600)
        pm.subdivide_width = 24
        pm.subdivide_depth = 18
        water.mesh = pm
        water.position = Vector3(0, -4.5, 0)
        var mat := StandardMaterial3D.new()
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.albedo_color = Color(0.16, 0.38, 0.52, 0.72)
        mat.roughness = 0.12
        mat.metallic = 0.1
        water.material_override = mat
        add_child(water)


func tile_height(x: float, z: float) -> float:
        # find tile whose rect contains point, else nearest tile
        var best: ZoneTerrain = null
        var best_d := INF
        for zid in tiles:
                var t: ZoneTerrain = tiles[zid]
                var o: Vector3 = t.tile_origin
                var dx: float = absf(x - (o.x + 400.0))
                var dz: float = absf(z - (o.z + 400.0))
                var d: float = maxf(dx, dz)
                if d < best_d:
                        best_d = d
                        best = t
        if best:
                return best.height_at(x, z)
        return 0.0


func slope_at(x: float, z: float) -> float:
        for zid in tiles:
                var t: ZoneTerrain = tiles[zid]
                var o: Vector3 = t.tile_origin
                if x >= o.x and x <= o.x + 800.0 and z >= o.z and z <= o.z + 800.0:
                        return t.slope_at(x, z)
        return 0.0


func zone_at(x: float, z: float) -> String:
        var weights := ZoneTerrain.zone_weights(x, z)
        var best_w := 0.0
        var best_z := ""
        for zid in weights:
                if weights[zid] > best_w:
                        best_w = weights[zid]
                        best_z = zid
        return best_z


# ------------------------------------------------------------------ props --
func _mesh_for(path: String) -> Mesh:
        if _mesh_cache.has(path):
                return _mesh_cache[path]
        var scene: PackedScene = load(path)
        if scene == null:
                push_error("World: missing mesh %s" % path)
                return null
        var inst := scene.instantiate()
        var mi := _find_mesh(inst)
        var mesh: Mesh = null
        if mi:
                mesh = mi.mesh
        inst.queue_free()
        _mesh_cache[path] = mesh
        return mesh


func _find_mesh(node: Node) -> MeshInstance3D:
        if node is MeshInstance3D:
                return node
        for c in node.get_children():
                var found := _find_mesh(c)
                if found:
                        return found
        return null


func _multimesh(mesh_path: String, transforms: Array, mat: Material = null, shadow: bool = true) -> void:
        if transforms.is_empty():
                return
        var mesh: Mesh = _mesh_for(mesh_path)
        if mesh == null:
                return
        var mmi := MultiMeshInstance3D.new()
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = mesh
        mm.instance_count = transforms.size()
        for i in transforms.size():
                mm.set_instance_transform(i, transforms[i])
        mmi.multimesh = mm
        if mat:
                mmi.material_override = mat
        mmi.cast_shadow = 1 if shadow else 0
        props_root.add_child(mmi)


func _scatter(rng: RandomNumberGenerator, count: int, zone: Dictionary, max_slope: float = 0.6, above_water: bool = true) -> Array:
        var out := []
        var cx: float = zone["center"][0]
        var cz: float = zone["center"][1]
        var tries := 0
        while out.size() < count and tries < count * 12:
                tries += 1
                var x: float = cx + rng.randf_range(-390.0, 390.0)
                var z: float = cz + rng.randf_range(-390.0, 390.0)
                var h: float = tile_height(x, z)
                if above_water and h < -3.8:
                        continue
                if slope_at(x, z) > max_slope:
                        continue
                out.append(Vector3(x, h, z))
        return out


func _dress_all_zones() -> void:
        for zone in Data.zones:
                var zid: String = zone["id"]
                var rng := RandomNumberGenerator.new()
                rng.seed = hash("dress-%s-%d" % [zid, Game.world_seed])
                var dressing: Dictionary = zone.get("dressing", {})

                # trees
                var tree_path := ""
                match String(dressing.get("trees", "none")):
                        "broadleaf": tree_path = "res://assets/meshes/environment/SM_Tree_Broadleaf.glb"
                        "conifer": tree_path = "res://assets/meshes/environment/SM_Tree_Conifer.glb"
                        "spore": tree_path = "res://assets/meshes/environment/SM_Tree_SporeCanopy.glb"
                        "dead": tree_path = "res://assets/meshes/environment/SM_Tree_Conifer.glb"
                var tree_count := int(float(dressing.get("tree_density", 0.0)) * 240.0)
                if tree_path != "" and tree_count > 0:
                        var tree_mat: Material = null
                        if String(dressing.get("trees", "")) == "dead":
                                tree_mat = StandardMaterial3D.new()
                                tree_mat.albedo_color = Color(0.28, 0.24, 0.22)
                                tree_mat.roughness = 1.0
                        var trs := []
                        for p in _scatter(rng, tree_count, zone, 0.55):
                                var s := rng.randf_range(0.75, 1.5)
                                var t := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * (0.85 if dressing.get("trees") == "dead" else 1.15), s)), p)
                                trs.append(t)
                        _multimesh(tree_path, trs, tree_mat)
                        if zid == "Zone_DawnFields":
                                _add_tree_collisions(trs)

                # rocks
                var rock_count := int(float(dressing.get("rocks", 0.0)) * 130.0)
                if rock_count > 0:
                        var rock_mat: Material = null
                        if dressing.get("char", false):
                                rock_mat = StandardMaterial3D.new()
                                rock_mat.albedo_color = Color(0.2, 0.17, 0.17)
                                rock_mat.roughness = 1.0
                        var rock_path := "res://assets/meshes/environment/SM_Rock_Granite_M.glb"
                        if dressing.get("snow", false):
                                rock_path = "res://assets/meshes/environment/SM_Rock_Boulder_Moss.glb"
                                rock_mat = StandardMaterial3D.new()
                                rock_mat.albedo_color = Color(0.82, 0.88, 0.95)
                        var rtrs := []
                        for p in _scatter(rng, rock_count, zone, 0.9):
                                var s := rng.randf_range(0.6, 2.2)
                                rtrs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p + Vector3(0, 0.2, 0)))
                        _multimesh(rock_path, rtrs, rock_mat)

                # grass
                var grass_count := int(float(dressing.get("grass", 0.0)) * 700.0)
                if grass_count > 0:
                        var gtrs := []
                        for p in _scatter(rng, grass_count, zone, 0.5):
                                var s := rng.randf_range(0.7, 1.6)
                                gtrs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        _multimesh("res://assets/meshes/environment/SM_Grass_Tuft.glb", gtrs, null, false)
                        if dressing.get("muck", false):
                                var ftrs := []
                                for p in _scatter(rng, int(float(dressing.get("grass", 0.0)) * 260.0), zone, 0.4):
                                        ftrs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.8)), p))
                                _multimesh("res://assets/meshes/environment/SM_Fern.glb", ftrs)

                # zone specials
                _dress_special(rng, zone)


func _add_tree_collisions(trs: Array) -> void:
        # only near the camp so the home grove feels solid
        for t in trs:
                var p: Vector3 = t.origin
                if p.distance_to(_camp_pos) > 140.0:
                        continue
                var body := StaticBody3D.new()
                body.collision_layer = 1
                var col := CollisionShape3D.new()
                var cyl := CylinderShape3D.new()
                cyl.radius = 0.55
                cyl.height = 6.0
                col.shape = cyl
                col.position = Vector3(0, 3.0, 0)
                body.add_child(col)
                body.position = p
                props_root.add_child(body)


func _dress_special(rng: RandomNumberGenerator, zone: Dictionary) -> void:
        var zid: String = zone["id"]
        var special: String = zone.get("dressing", {}).get("special", "")
        match special:
                "crystal_spires":
                        var trs := []
                        for p in _scatter(rng, 46, zone, 0.7):
                                var s := rng.randf_range(0.8, 2.6)
                                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        var mat := StandardMaterial3D.new()
                        mat.albedo_color = Color(0.72, 0.5, 1.0)
                        mat.emission_enabled = true
                        mat.emission = Color(0.55, 0.3, 0.95)
                        mat.emission_energy_multiplier = 2.2
                        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
                        mat.albedo_color.a = 0.85
                        _multimesh("res://assets/meshes/environment/SM_Node_Astraite.glb", trs, mat)
                "ice_pillars":
                        var trs := []
                        for p in _scatter(rng, 30, zone, 0.8):
                                var s := rng.randf_range(1.0, 3.0)
                                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        var mat := StandardMaterial3D.new()
                        mat.albedo_color = Color(0.75, 0.9, 1.0)
                        mat.emission_enabled = true
                        mat.emission = Color(0.55, 0.8, 1.0)
                        mat.emission_energy_multiplier = 0.8
                        _multimesh("res://assets/meshes/environment/SM_Node_Astraite.glb", trs, mat)
                "obsidian_spires":
                        var trs := []
                        for p in _scatter(rng, 34, zone, 0.95):
                                var s := rng.randf_range(1.2, 3.4)
                                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        var mat := StandardMaterial3D.new()
                        mat.albedo_color = Color(0.12, 0.1, 0.12)
                        mat.roughness = 0.35
                        _multimesh("res://assets/meshes/environment/SM_Cliff_Shard.glb", trs, mat)
                        # lava vents
                        var vtrs := []
                        for p in _scatter(rng, 14, zone, 0.6):
                                vtrs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.8)), p))
                        var lmat := StandardMaterial3D.new()
                        lmat.albedo_color = Color(1.0, 0.4, 0.1)
                        lmat.emission_enabled = true
                        lmat.emission = Color(1.0, 0.35, 0.05)
                        lmat.emission_energy_multiplier = 2.6
                        _multimesh("res://assets/meshes/environment/SM_Node_Pyronite.glb", vtrs, lmat)
                "ash_spires":
                        var trs := []
                        for p in _scatter(rng, 26, zone, 0.95):
                                var s := rng.randf_range(1.4, 3.2)
                                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        var mat := StandardMaterial3D.new()
                        mat.albedo_color = Color(0.22, 0.18, 0.2)
                        mat.emission_enabled = true
                        mat.emission = Color(0.45, 0.12, 0.1)
                        mat.emission_energy_multiplier = 0.9
                        _multimesh("res://assets/meshes/environment/SM_Cliff_Shard.glb", trs, mat)
                "glow_reeds":
                        var trs := []
                        for p in _scatter(rng, 60, zone, 0.35, false):
                                var s := rng.randf_range(0.8, 1.7)
                                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        var mat := StandardMaterial3D.new()
                        mat.albedo_color = Color(0.3, 0.85, 0.75)
                        mat.emission_enabled = true
                        mat.emission = Color(0.2, 0.8, 0.7)
                        mat.emission_energy_multiplier = 1.8
                        _multimesh("res://assets/meshes/environment/SM_GlowReed.glb", trs, mat)
                "ruins":
                        var trs := []
                        for i in _scatter(rng, 14, zone, 0.5):
                                var s := rng.randf_range(0.8, 1.6)
                                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), i))
                        _multimesh("res://assets/meshes/environment/SM_Ruin_Pillar.glb", trs)
                        var btrs := []
                        for p in _scatter(rng, 22, zone, 0.5):
                                btrs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.7, 1.5)), p))
                        _multimesh("res://assets/meshes/environment/SM_Ruin_Block.glb", btrs)
                        var atrs := []
                        for p in _scatter(rng, 6, zone, 0.4):
                                atrs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.0, 1.5)), p))
                        _multimesh("res://assets/meshes/environment/SM_Ruin_Arch.glb", atrs)
                "storm_array":
                        var trs := []
                        for p in _scatter(rng, 18, zone, 0.85):
                                var s := rng.randf_range(1.5, 2.8)
                                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        var mat := StandardMaterial3D.new()
                        mat.albedo_color = Color(0.45, 0.5, 0.6)
                        mat.metallic = 0.8
                        mat.roughness = 0.3
                        mat.emission_enabled = true
                        mat.emission = Color(0.5, 0.7, 1.0)
                        mat.emission_energy_multiplier = 1.4
                        _multimesh("res://assets/meshes/environment/SM_Ruin_Pillar.glb", trs, mat)
                "coral":
                        var trs := []
                        for p in _scatter(rng, 50, zone, 0.8, false):
                                var s := rng.randf_range(0.8, 2.2)
                                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        var mat := StandardMaterial3D.new()
                        mat.albedo_color = Color(1.0, 0.5, 0.62)
                        mat.emission_enabled = true
                        mat.emission = Color(0.9, 0.35, 0.5)
                        mat.emission_energy_multiplier = 0.9
                        _multimesh("res://assets/meshes/environment/SM_Node_Voidstone.glb", trs, mat)
                "heart_tree":
                        var p: Array = zone["center"]
                        var h := tile_height(p[0], p[1]) + 1.0
                        var heart := _mesh_instance("res://assets/meshes/environment/SM_Tree_Broadleaf.glb", Vector3(p[0], h - 0.5, p[1]), Vector3(4.5, 4.5, 4.5))
                        if heart:
                                var mat := StandardMaterial3D.new()
                                mat.albedo_color = Color(0.95, 0.6, 0.75)
                                mat.emission_enabled = true
                                mat.emission = Color(0.6, 0.3, 0.45)
                                mat.emission_energy_multiplier = 0.6
                                heart.material_override = mat
                        _dress_special_ferns(rng, zone)


func _dress_special_ferns(rng: RandomNumberGenerator, zone: Dictionary) -> void:
        var trs := []
        for p in _scatter(rng, 40, zone, 0.5):
                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.2, 2.2)), p))
        _multimesh("res://assets/meshes/environment/SM_Fern.glb", trs)


func _mesh_instance(path: String, pos: Vector3, scale: Vector3 = Vector3.ONE) -> MeshInstance3D:
        var mesh: Mesh = _mesh_for(path)
        if mesh == null:
                return null
        var mi := MeshInstance3D.new()
        mi.mesh = mesh
        mi.position = pos
        mi.scale = scale
        props_root.add_child(mi)
        return mi


# -------------------------------------------------------- resource nodes ---
func _spawn_resource_nodes() -> void:
        for zone in Data.zones:
                var zid: String = zone["id"]
                var rng := RandomNumberGenerator.new()
                rng.seed = hash("nodes-%s-%d" % [zid, Game.world_seed])
                for entry in zone.get("resources", []):
                        var node_id: String = entry[0]
                        var count: int = int(entry[1])
                        var def: Dictionary = Data.resource_nodes.get(node_id, {})
                        if def.is_empty():
                                continue
                        for p in _scatter(rng, count, zone, 0.75, not def.get("hidden", false)):
                                var node := ResourceNode.new(def)
                                node.position = p + Vector3(0, 0.1, 0)
                                node.rotation.y = rng.randf() * TAU
                                nodes_root.add_child(node)


# ------------------------------------------------------------------- camp --
func _build_camp() -> void:
        var cx: float = _camp_pos.x
        var cz: float = _camp_pos.z
        # camp ring visual: glowcap lights + fire
        var fire_pos := Vector3(cx, tile_height(cx, cz - 9.0), cz - 9.0)
        _add_campfire(fire_pos, true)
        var rest_pos := Vector3(cx + 9.0, tile_height(cx + 9.0, cz), cz)
        var rest := _add_marker(rest_pos, Color(1.0, 0.85, 0.5), "Rest Point")
        rest.set_meta("interact_kind", "rest")
        var wb_pos := Vector3(cx, tile_height(cx, cz + 9.0), cz + 9.0)
        var wb := _add_marker(wb_pos, Color(0.6, 0.8, 1.0), "Workbench")
        wb.set_meta("interact_kind", "station_workbench")
        # villagers live in Dawnstead, 280 m east (UE5 Batch 8 SpawnVillages)


# -------------------------------------------------------------- villages --
func _build_villages() -> void:
        var village_script := load("res://scripts/world/village.gd")
        # Dawnstead — the main village, camp + 280 m (Dawn Fields)
        var dawnstead_pos := Vector3(_camp_pos.x + 280.0, 0, _camp_pos.z)
        dawnstead_pos.y = tile_height(dawnstead_pos.x, dawnstead_pos.z)
        var dawnstead: Village = village_script.new()
        dawnstead.setup("Village_Dawnstead", "Dawnstead", dawnstead_pos)
        add_child(dawnstead)
        dawnstead.build(props_root, self)
        villages.append(dawnstead)
        # Driftwood Landing — the isles hamlet (Tidebreaker Isles)
        var driftwood_pos := Vector3(-1192.0, 0, -806.0)
        driftwood_pos.y = tile_height(driftwood_pos.x, driftwood_pos.z)
        var driftwood: Village = village_script.new()
        driftwood.setup("Village_Driftwood", "Driftwood Landing", driftwood_pos)
        add_child(driftwood)
        driftwood.build(props_root, self)
        villages.append(driftwood)


# ------------------------------------------------------------------ skiff --
func _spawn_skiffs() -> void:
        var skiff_script := load("res://scripts/world/skiff.gd")
        # Skiff_Dawnstead on the camp pad (between camp and Dawnstead)
        var pad := Vector3(_camp_pos.x + 150.0, 0, _camp_pos.z - 20.0)
        pad.y = tile_height(pad.x, pad.z) + 1.2
        var skiff1: DawnSkiff = skiff_script.new()
        skiff1.set_meta("skiff_id", "Skiff_Dawnstead")
        skiff1.set_meta("skiff_name", "Dawn Skiff · Dawnstead")
        skiff1.position = pad
        skiff1.rotation.y = PI * 0.5
        add_child(skiff1)
        skiffs.append(skiff1)
        # skiff landing pad ring
        var pad_ring := MeshInstance3D.new()
        var ring := CylinderMesh.new()
        ring.top_radius = 4.2
        ring.bottom_radius = 4.6
        ring.height = 0.08
        pad_ring.mesh = ring
        var pr_mat := StandardMaterial3D.new()
        pr_mat.albedo_color = Color(0.9, 0.75, 0.4)
        pr_mat.emission_enabled = true
        pr_mat.emission = Color(0.9, 0.6, 0.2)
        pr_mat.emission_energy_multiplier = 0.7
        pad_ring.material_override = pr_mat
        pad_ring.position = Vector3(pad.x, tile_height(pad.x, pad.z) + 0.04, pad.z)
        props_root.add_child(pad_ring)
        # Skiff_Driftwood at the isles dock
        var dock := Vector3(-1224.0, 0, -796.0)
        dock.y = tile_height(dock.x, dock.z) + 1.2
        var skiff2: DawnSkiff = skiff_script.new()
        skiff2.set_meta("skiff_id", "Skiff_Driftwood")
        skiff2.set_meta("skiff_name", "Dawn Skiff · Driftwood")
        skiff2.position = dock
        add_child(skiff2)
        skiffs.append(skiff2)


func _add_campfire(pos: Vector3, with_light: bool) -> void:
        var ring := _mesh_instance("res://assets/meshes/environment/SM_Rock_Granite_S.glb", pos + Vector3(0, 0.15, 0), Vector3.ONE * 0.5)
        if ring:
                ring.rotation.y = 0.5
        var fire := CPUParticles3D.new()
        fire.amount = 30
        fire.lifetime = 1.1
        fire.one_shot = false
        fire.position = pos + Vector3(0, 0.4, 0)
        fire.direction = Vector3(0, 1, 0)
        fire.spread = 12.0
        fire.initial_velocity_min = 0.8
        fire.initial_velocity_max = 1.8
        fire.gravity = Vector3(0, 1.2, 0)
        fire.scale_amount_min = 0.12
        fire.scale_amount_max = 0.3
        var quad := QuadMesh.new()
        quad.size = Vector2(0.28, 0.28)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(1.0, 0.6, 0.2)
        mat.emission_enabled = true
        mat.emission = Color(1.0, 0.45, 0.1)
        mat.emission_energy_multiplier = 3.0
        mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        quad.material = mat
        fire.mesh = quad
        add_child(fire)
        if with_light:
                var light := OmniLight3D.new()
                light.position = pos + Vector3(0, 1.4, 0)
                light.omni_range = 14.0
                light.light_color = Color(1.0, 0.6, 0.3)
                light.light_energy = 1.6
                light.omni_attenuation = 1.2
                add_child(light)
                var tween := create_tween().set_loops()
                tween.tween_property(light, "light_energy", 1.1, 0.4).set_trans(Tween.TRANS_SINE)
                tween.tween_property(light, "light_energy", 1.7, 0.4).set_trans(Tween.TRANS_SINE)


func _add_marker(pos: Vector3, color: Color, label: String) -> Node3D:
        var marker := Node3D.new()
        marker.set_script(load("res://scripts/world/marker.gd"))
        marker.position = pos
        marker.set_meta("interact_kind", "marker")
        marker.set_meta("marker_label", label)
        var beacon := _mesh_instance("res://assets/meshes/environment/SM_Node_Astraite.glb", pos + Vector3(0, 0.8, 0), Vector3(0.8, 1.4, 0.8))
        if beacon:
                var mat := StandardMaterial3D.new()
                mat.albedo_color = color
                mat.emission_enabled = true
                mat.emission = color
                mat.emission_energy_multiplier = 1.8
                beacon.material_override = mat
                marker.set_meta("beacon", beacon)
        npcs_root.add_child(marker)  # interactables live under npc root (both are "interactables")
        return marker


# -------------------------------------------------------------- locations --
func _build_locations() -> void:
        # Hollow Underlight gate (Hollow Approach, east of Dawn Fields)
        var gate_x := 400.0 - 120.0
        var gate_z := -40.0
        var gate_h := tile_height(gate_x, gate_z)
        var gate := _add_location_marker(Vector3(gate_x, gate_h, gate_z), "Location_HollowUnderlight", "The Hollow Underlight Gate", Color(0.9, 0.3, 0.3))
        var arch := _mesh_instance("res://assets/meshes/environment/SM_Ruin_Arch.glb", Vector3(gate_x, gate_h - 0.3, gate_z), Vector3(3.2, 3.2, 3.2))
        if arch:
                var mat := StandardMaterial3D.new()
                mat.albedo_color = Color(0.25, 0.2, 0.28)
                mat.emission_enabled = true
                mat.emission = Color(0.5, 0.1, 0.12)
                mat.emission_energy_multiplier = 1.2
                arch.material_override = mat
        # the Underlight Warden now coils inside the dungeon's boss room

        # Driftwood Landing (Tidebreaker Isles hamlet — village built in _build_villages)
        var dl := Vector3(-1200.0 + 8.0, 0.0, -800.0 - 6.0)
        dl.y = tile_height(dl.x, dl.z)
        _add_location_marker(dl, "Location_DriftwoodLanding", "Driftwood Landing", Color(0.4, 0.9, 0.85))

        # Sunken Vault (Tidebreaker Isles — dungeon entrance marker)
        var sv := Vector3(-1200.0 - 140.0, 0.0, -800.0 + 120.0)
        sv.y = tile_height(sv.x, sv.z)
        _add_location_marker(sv, "Location_SunkenVault", "The Sunken Vault", Color(0.5, 0.8, 1.0))
        var vault_arch := _mesh_instance("res://assets/meshes/environment/SM_Ruin_Arch.glb", sv + Vector3(0, -0.3, 0), Vector3(4.0, 4.5, 4.0))
        if vault_arch:
                var vmat := StandardMaterial3D.new()
                vmat.albedo_color = Color(0.3, 0.45, 0.55)
                vmat.emission_enabled = true
                vmat.emission = Color(0.2, 0.6, 0.9)
                vmat.emission_energy_multiplier = 1.4
                vault_arch.material_override = vmat


# --------------------------------------------------------------- dungeons --
func _build_dungeons() -> void:
        var dungeon_script := load("res://scripts/world/dungeon.gd")
        # Hollow Underlight — 5-room chain east of the gate (Hollow Approach)
        var hollow: DungeonGenerator = dungeon_script.new()
        hollow.setup("Dungeon_HollowUnderlight", "The Hollow Underlight",
                Vector3(280.0 + 12.0, 0, -40.0), Vector3(1, 0, 0), 5,
                "Creature_UnderlightWarden", "Creature_UnderlightWarden")
        add_child(hollow)
        hollow.build(self, self)
        dungeons.append(hollow)
        # Sunken Vault — 4-room chain west of the isles marker (Dawnfang boss)
        var vault: DungeonGenerator = dungeon_script.new()
        vault.setup("Dungeon_SunkenVault", "The Sunken Vault",
                Vector3(-1340.0 - 12.0, 0, -680.0), Vector3(-1, 0, 0), 4,
                "Creature_VaultColossus", "Creature_VaultColossus")
        vault.reward_rp = 25
        vault.reward_tech = ""
        vault.reward_loot = [{"item": "Item_SeaPearl", "qty": 2}, {"item": "Item_CoralShard", "qty": 3}, {"item": "Item_DawnShard", "qty": 3}]
        vault.creature_pool = ["Echo_Rimefang", "Echo_Voltmaw", "Echo_DeepdelverAbyssal"]
        add_child(vault)
        vault.build(self, self)
        dungeons.append(vault)


# -------------------------------------------------------------- work sites --
func _build_work_sites() -> void:
        var site_script := load("res://scripts/systems/worksite.gd")
        # UE5 ProductionContent BuildWorkSites placements
        var placements := [
                {"id": "Site_CampGathering", "pos": Vector3(_camp_pos.x - 30.0, 0, _camp_pos.z)},
                {"id": "Site_CampFarm", "pos": Vector3(_camp_pos.x - 21.0, 0, _camp_pos.z + 21.0)},
                {"id": "Site_CampKitchen", "pos": Vector3(_camp_pos.x + 14.0, 0, _camp_pos.z + 26.0)},
                {"id": "Site_RidgeMining", "pos": Vector3(360.0, 0, 830.0)},
        ]
        for p in placements:
                var def: Dictionary = Data.worksites.get(p["id"], {})
                if def.is_empty():
                        continue
                var site: WorkSite = site_script.new()
                site.setup(def)
                var pos: Vector3 = p["pos"]
                pos.y = tile_height(pos.x, pos.z)
                site.position = pos
                site.rotation.y = _rng.randf() * TAU
                add_child(site)
                worksites.append(site)


func _add_location_marker(pos: Vector3, location_id: String, label: String, color: Color) -> Node3D:
        var marker := _add_marker(pos, color, label)
        marker.set_meta("interact_kind", "location")
        marker.set_meta("location_id", location_id)
        return marker


func _spawn_boss(species_id: String, pos: Vector3) -> void:
        var def: Dictionary = Data.species_def(species_id)
        if def.is_empty():
                return
        pos.y = tile_height(pos.x, pos.z)
        var echo = load("res://scripts/creatures/echo.gd").new(def, _rng)
        echo.position = pos
        echo.boss_mode = true
        creatures_root.add_child(echo)


# -------------------------------------------------------------- creatures --
func _spawn_all_creatures() -> void:
        for zone in Data.zones:
                var zid: String = zone["id"]
                var rng := RandomNumberGenerator.new()
                rng.seed = hash("wild-%s-%d" % [zid, Game.world_seed])
                for entry in zone.get("wildlife", []):
                        var species_id: String = entry[0]
                        var count: int = int(entry[1])
                        var def: Dictionary = Data.species_def(species_id)
                        if def.is_empty():
                                continue
                        for p in _scatter(rng, count, zone, 0.5):
                                _spawn_creature(def, p, rng)
        # Auroraling: exactly one, deep in Glimmerwood
        var aura_def: Dictionary = Data.species_def("Echo_Auroraling")
        if not aura_def.is_empty():
                var p := Vector3(-400.0 - 260.0, 0, 800.0 - 210.0)
                p.y = tile_height(p.x, p.z)
                _spawn_creature(aura_def, p, _rng)


func _spawn_creature(def: Dictionary, pos: Vector3, rng: RandomNumberGenerator) -> Node:
        var echo_script := load("res://scripts/creatures/echo.gd")
        var echo: Node = echo_script.new(def, rng)
        echo.position = pos
        creatures_root.add_child(echo)
        return echo


func _process(delta: float) -> void:
        _hostile_sweep -= delta
        if _hostile_sweep <= 0.0:
                _hostile_sweep = 25.0
                _hostile_respawn_sweep()


func _hostile_respawn_sweep() -> void:
        # keep target wild hostile populations (UE5 HostileSpawnerSubsystem)
        var targets := {"Echo_Gloomfang": 4, "Echo_Emberfang": 2, "Echo_Rimefang": 3, "Echo_Voltmaw": 1}
        for sid in targets:
                var alive := 0
                for c in creatures_root.get_children():
                        if c is Node and c.get("def") != null and c.def.get("id", "") == sid and not c.is_defeated():
                                alive += 1
                var missing: int = int(targets[sid]) - alive
                if missing <= 0:
                        continue
                var home: Dictionary = Data.species_def(sid)
                var zone: Dictionary = Data.zone("Zone_" + String(home.get("home_zone", "DawnFields")))
                var rng := RandomNumberGenerator.new()
                rng.seed = hash("respawn-%s-%d" % [sid, Time.get_ticks_msec()])
                for p in _scatter(rng, missing, zone, 0.5):
                        _spawn_creature(home, p, rng)


# ------------------------------------------------------------ party sync ---
func _sync_party() -> void:
        # spawn follower bodies for active party entries
        var wanted := {}
        for i in Game.party.size():
                wanted[i] = Game.party[i]
        for idx in followers.keys():
                if not wanted.has(idx):
                        var f: Node = followers[idx]
                        f.queue_free()
                        followers.erase(idx)
        for idx in wanted:
                if followers.has(idx):
                        var f: Node = followers[idx]
                        f.bind_entry(wanted[idx])
                        continue
                var def: Dictionary = Data.species_def(wanted[idx]["species_id"])
                if def.is_empty():
                        continue
                var player := get_tree().get_first_node_in_group("player")
                var spawn_pos: Vector3 = player.global_position + Vector3(2.0, 0, 1.0) if player else _camp_pos
                spawn_pos.y = tile_height(spawn_pos.x, spawn_pos.z)
                var echo_script := load("res://scripts/creatures/echo.gd")
                var follower: Node = echo_script.new(def, _rng)
                follower.position = spawn_pos
                follower.become_captured(player)
                follower.bind_entry(wanted[idx])
                creatures_root.add_child(follower)
                followers[idx] = follower


# ------------------------------------------------------------------- save --
func get_save_data() -> Dictionary:
        var buildings := []
        for b in buildings_root.get_children():
                if b.has_method("get_save_data"):
                        buildings.append(b.get_save_data())
        var dungeon_data := []
        for d in dungeons:
                dungeon_data.append(d.get_save_data())
        var skiff_data := []
        for s in skiffs:
                skiff_data.append(s.get_save_data())
        var site_data := []
        for w in worksites:
                site_data.append(w.get_save_data())
        return {
                "buildings": buildings,
                "dungeons": dungeon_data,
                "skiffs": skiff_data,
                "worksites": site_data,
                "power": power_grid.get_save_data() if power_grid else {},
                "events": world_events.get_save_data() if world_events else {},
        }


func apply_save_data(data: Dictionary) -> void:
        var building_script := load("res://scripts/systems/building_piece.gd")
        for b in data.get("buildings", []):
                var def: Dictionary = Data.buildings.get(b.get("id", ""), {})
                if def.is_empty():
                        continue
                var piece: Node = building_script.new(def)
                piece.position = Vector3(float(b.get("x", 0.0)), float(b.get("y", 0.0)), float(b.get("z", 0.0)))
                piece.rotation_degrees.y = float(b.get("rot", 0.0))
                buildings_root.add_child(piece)
        for d in data.get("dungeons", []):
                for gen in dungeons:
                        if gen.dungeon_id == str(d.get("id", "")):
                                gen.apply_save_data(d)
        for s in data.get("skiffs", []):
                for sk in skiffs:
                        if sk.skiff_id == str(s.get("id", "")):
                                sk.apply_save_data(s)
        for w in data.get("worksites", []):
                for site in worksites:
                        if site.site_id == str(w.get("id", "")):
                                site.apply_save_data(w)
        if power_grid and data.has("power"):
                power_grid.apply_save_data(data["power"])
        if world_events and data.has("events"):
                world_events.apply_save_data(data["events"])
