class_name GameWorld
extends Node3D

## PS-2 staged loading: (honest stage name, fraction 0..1) — the main scene
## turns these into the loading bar; worldgen yields frames between stages.
signal build_progress(stage_text: String, fraction: float)
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
var apexes := []                # v1.5.2: zone Apex boss Echoes (8)
var prop_mesh_paths := {}       # v1.5.2 smoke telemetry: path -> instances
var landmark_count := 0        # v1.1 Phase V6 named landmarks placed
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
        _bp("Carving the terrain…", 0.04)
        _build_terrain()
        await _breathe()
        _bp("Raising the far ridges…", 0.06)
        _build_vista_ring()
        _bp("Filling the waters…", 0.08)
        _build_water()
        _bp("Raising sky and weather…", 0.12)
        daynight = DayNightCycle.new()
        daynight.setup()
        add_child(daynight)
        weather_fx = WeatherFX.new()
        weather_fx.setup()
        add_child(weather_fx)

        _bp("Rooting the world…", 0.14)
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

        # PS-2: the two heavy loops report per-zone progress and yield frames
        # so even web builds keep rendering the loading screen (no 1-3 min freeze)
        await _dress_all_zones()
        _bp("Seeding resources…", 0.64)
        _spawn_resource_nodes()
        await _breathe()
        _bp("Raising the home camp…", 0.68)
        _build_camp()
        await _breathe()
        _bp("Founding villages…", 0.72)
        _build_villages()
        _dress_village_paths()
        _spawn_skiffs()
        await _breathe()
        _bp("Placing locations…", 0.80)
        _build_locations()
        _build_landmarks()
        await _breathe()
        _bp("Opening dungeons…", 0.86)
        _build_dungeons()
        _build_work_sites()
        await _breathe()
        await _spawn_all_creatures()
        _bp("The Vale is ready.", 1.0)
        Game.party_changed.connect(_sync_party)
        Game.party_changed.emit()
        # v1.7 Phase 1: weather-coupled foliage wind — materials were created
        # with the boot weather's strength already; re-assert it now that all
        # batches exist, and follow every weather transition from here on.
        apply_weather_wind(Game.weather_id)
        Game.weather_changed.connect(apply_weather_wind)


func _build_vista_ring() -> void:
        ## v1.7 Phase 1: Distant Vista Ring — two low-poly mountain-ridge rings
        ## (no collision, no shadows) around the 3.2×2.4 km playfield so the
        ## straight cut horizon reads as layered peaks instead. Depth fog does
        ## the aerial-perspective blending; height fog sinks the bases into
        ## morning mist. Deterministic from the world seed.
        var rng := RandomNumberGenerator.new()
        rng.seed = hash("vista-%d" % Game.world_seed)
        vista_peak_count = 0
        var root := Node3D.new()
        root.name = "VistaRing"
        root.add_to_group("vista")
        add_child(root)
        # far ring: tall, cooler, carries the snow caps; near ring: lower,
        # greener — sits between the far ring and the playfield edge
        _vista_ring_mesh(root, rng, 44, 2050.0, 1620.0, 150.0, 380.0,
                Color(0.36, 0.40, 0.50), Color(0.62, 0.66, 0.74), Color(0.92, 0.94, 0.98))
        _vista_ring_mesh(root, rng, 32, 1840.0, 1430.0, 60.0, 170.0,
                Color(0.22, 0.28, 0.22), Color(0.34, 0.38, 0.34), Color(0.55, 0.60, 0.62))


func _vista_ring_mesh(root: Node3D, rng: RandomNumberGenerator, count: int, rx: float, rz: float,
                h_min: float, h_max: float, base_col: Color, mid_col: Color, cap_col: Color) -> void:
        ## One ArrayMesh of `count` faceted peaks on an ellipse (rx, rz) around
        ## the map centre. Each peak = a shallow pyramid of 6 base corners →
        ## ~12 triangles, flat shaded, vertex-coloured base→cap gradient.
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for i in count:
                var ang: float = TAU * float(i) / float(count) + rng.randf_range(-0.04, 0.04)
                var px: float = cos(ang) * rx * rng.randf_range(0.97, 1.06)
                var pz: float = sin(ang) * rz * rng.randf_range(0.97, 1.06)
                var peak_h: float = rng.randf_range(h_min, h_max)
                var base_r: float = peak_h * rng.randf_range(0.75, 1.15)
                var apex := Vector3(px, peak_h, pz)
                var prev := Vector3.ZERO
                var corners := 6
                for c in corners + 1:
                        var ca: float = ang + TAU * float(c) / float(corners)
                        var corner := Vector3(px + cos(ca) * base_r, -12.0, pz + sin(ca) * base_r)
                        if c > 0:
                                # two triangles per ring segment: base→apex fan
                                # (flat, stylized) + a thin skirt wall so the
                                # ridge reads solid from inside the valley too
                                var b0 := base_col.lerp(mid_col, 0.45 + 0.2 * sin(ca))
                                var b1 := base_col.lerp(mid_col, 0.45 + 0.2 * sin(ca - TAU / float(corners)))
                                var cap := cap_col
                                _vista_tri(st, prev, corner, apex, b0, b1, cap)
                                _vista_tri(st, corner, prev, Vector3(prev.x, -14.0, prev.z), b0, b1, base_col.darkened(0.35))
                        prev = corner
                vista_peak_count += 1
        st.generate_normals()
        var mesh := st.commit()
        var mat := StandardMaterial3D.new()
        mat.vertex_colors_use_as_albedo = true
        mat.roughness = 1.0
        mat.specular = 0.1
        var mmi := MeshInstance3D.new()
        mmi.mesh = mesh
        mmi.material_override = mat
        mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        root.add_child(mmi)


func _vista_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color) -> void:
        st.set_color(ca)
        st.add_vertex(a)
        st.set_color(cb)
        st.add_vertex(b)
        st.set_color(cc)
        st.add_vertex(c)


func _bp(stage_text: String, fraction: float) -> void:
        ## PS-2 loading progress broadcast (staged, honest stage names).
        build_progress.emit(stage_text, fraction)


func _breathe() -> void:
        ## yield one frame so the loading screen renders between heavy stages.
        await get_tree().process_frame


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
        mat.roughness = 0.3
        mat.metallic = 0.0
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


func _multimesh(mesh_path: String, transforms: Array, mat: Material = null, shadow: bool = true, wind_mode: String = "") -> void:
        if transforms.is_empty():
                return
        var mesh: Mesh
        if mat != null:
                mesh = _mesh_for(mesh_path)
        else:
                # v1.6 Radiant Dawn: wind-mode batches swap the shared mesh for a
                # windified copy (per-surface sway shader preserving each
                # surface's texture + albedo) and carry per-instance tint
                # jitter in INSTANCE_CUSTOM — alive forests, zero extra draws.
                mesh = _windified_mesh(mesh_path, wind_mode) if wind_mode != "" else _mesh_for(mesh_path)
        if mesh == null:
                return
        # v1.5.2 smoke telemetry: distinct prop meshes actually instanced
        prop_mesh_paths[mesh_path] = int(prop_mesh_paths.get(mesh_path, 0)) + transforms.size()
        var mmi := MultiMeshInstance3D.new()
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = mesh
        if wind_mode != "" and mat == null:
                mm.set_use_custom_data(true)
        mm.instance_count = transforms.size()
        for i in transforms.size():
                mm.set_instance_transform(i, transforms[i])
                if mm.is_using_custom_data():
                        mm.set_instance_custom_data(i, _instance_tint(transforms[i].origin))
        mmi.multimesh = mm
        if mat:
                mmi.material_override = mat
        mmi.cast_shadow = 1 if shadow else 0
        props_root.add_child(mmi)


var _wind_shader: Shader
var _wind_mesh_cache := {}
var _wind_materials: Array[ShaderMaterial] = []      # v1.7: every cached sway material — weather wind updates them all in one pass
var _grove_noise: FastNoiseLite                       # v1.7: macro grove-density field (clustered scatter)
var vista_peak_count := 0                             # v1.7: smoke telemetry for the distant vista ring


const WEATHER_WIND := {                               # v1.7 Phase 1: wind strength per weather state
        "Clear": 0.55, "Cloudy": 0.72, "Rain": 1.05, "HeavyRain": 1.35,
        "Storm": 1.9, "Fog": 0.38, "Heatwave": 0.22, "ColdSnap": 0.68,
}


func apply_weather_wind(state: String) -> void:
        ## Push the weather's wind strength onto every cached foliage wind
        ## material (called at build time and on Game.weather_changed).
        var strength: float = float(WEATHER_WIND.get(state, 0.6))
        for m in _wind_materials:
                m.set_shader_parameter("wind_strength", strength)


func _grove_density_at(x: float, z: float) -> float:
        ## v1.7 Phase 1: macro grove-density noise (wavelength ~170 m). Forests
        ## cluster into groves with natural clearings between them — kills the
        ## "uniform random pattern" read VLM has flagged since v1.5.2.
        if _grove_noise == null:
                _grove_noise = FastNoiseLite.new()
                _grove_noise.seed = hash("groves-%d" % Game.world_seed)
                _grove_noise.frequency = 1.0 / 170.0
                _grove_noise.fractal_octaves = 2
        return _grove_noise.get_noise_2d(x, z)


func _scatter_clustered(rng: RandomNumberGenerator, count: int, zone: Dictionary, max_slope: float = 0.55, above_water: bool = true) -> Array:
        ## v1.7 Phase 1: FastNoiseLite 2-layer scatter — macro grove density
        ## decides WHICH areas carry trees (dense groves covering ~45% of the
        ## zone + genuine open clearings), micro jitter (±12 m) makes grove
        ## boundaries organic. 10% sprinkle keeps lone trees standing in the
        ## clearings (nature is never pure).
        var out := []
        var cx: float = zone["center"][0]
        var cz: float = zone["center"][1]
        var tries := 0
        while out.size() < count and tries < count * 16:
                tries += 1
                var x: float = cx + rng.randf_range(-390.0, 390.0)
                var z: float = cz + rng.randf_range(-390.0, 390.0)
                if _grove_density_at(x, z) < 0.05 and rng.randf() > 0.10:
                        continue
                x += rng.randf_range(-12.0, 12.0)
                z += rng.randf_range(-12.0, 12.0)
                var h: float = tile_height(x, z)
                if above_water and h < -3.8:
                        continue
                if slope_at(x, z) > max_slope:
                        continue
                out.append(Vector3(x, h, z))
        return out


func _windified_mesh(mesh_path: String, mode: String) -> Mesh:
        ## v1.6 Radiant Dawn: duplicate the shared mesh and attach a wind-sway
        ## ShaderMaterial per surface, copying each surface's original albedo
        ## texture + color so textured trees keep their look while swaying.
        if _wind_shader == null:
                _wind_shader = load("res://shaders/foliage_wind.gdshader")
        var key := "%s|%s" % [mesh_path, mode]
        if _wind_mesh_cache.has(key):
                return _wind_mesh_cache[key]
        var base: Mesh = _mesh_for(mesh_path)
        if base == null:
                return null
        var mesh: Mesh = base.duplicate() as Mesh
        var aabb: AABB = mesh.get_aabb()
        var h_lo: float = maxf(aabb.size.y * 0.16, 0.04)
        var h_hi: float = maxf(aabb.size.y * 0.78, 0.12)
        var sway: float = 0.08
        var speed: float = 1.35
        if mode == "grass":
                h_lo = maxf(aabb.size.y * 0.04, 0.02)
                h_hi = maxf(aabb.size.y * 0.55, 0.08)
                sway = 0.055
                speed = 1.9
        for i in mesh.get_surface_count():
                var smat: ShaderMaterial = ShaderMaterial.new()
                smat.shader = _wind_shader
                var src: Material = mesh.surface_get_material(i)
                var col := Color.WHITE
                var tex: Texture2D = null
                if src is StandardMaterial3D:
                        col = src.albedo_color
                        tex = src.albedo_texture
                smat.set_shader_parameter("surface_col", col)
                smat.set_shader_parameter("base_tex", tex)
                smat.set_shader_parameter("sway_world", sway)
                smat.set_shader_parameter("sway_speed", speed)
                smat.set_shader_parameter("h_lo", h_lo)
                smat.set_shader_parameter("h_hi", h_hi)
                smat.set_shader_parameter("wind_strength", float(WEATHER_WIND.get(Game.weather_id, 0.6)))
                _wind_materials.append(smat)
                mesh.surface_set_material(i, smat)
        _wind_mesh_cache[key] = mesh
        return mesh


func _instance_tint(origin: Vector3) -> Color:
        ## deterministic per-instance warm/cool tint jitter (0.5 = neutral,
        ## shader doubles it) — breaks the "one flat forest color" read.
        var h: int = absi(hash("%.2f|%.2f" % [origin.x, origin.z]))
        var r: float = 0.5 + float(h % 17) / 17.0 * 0.10 - 0.05
        var g: float = 0.5 + float((h / 17) % 13) / 13.0 * 0.08 - 0.04
        var b: float = 0.5 + float((h / 221) % 11) / 11.0 * 0.10 - 0.05
        return Color(r, g, b, 1.0)


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
        var zones_total: int = Data.zones.size()
        var zi := 0
        for zone in Data.zones:
                _bp("Dressing %s…" % zone.get("name", zone["id"]), 0.16 + 0.44 * float(zi) / float(maxi(1, zones_total)))
                await _breathe()
                zi += 1
                var zid: String = zone["id"]
                var rng := RandomNumberGenerator.new()
                rng.seed = hash("dress-%s-%d" % [zid, Game.world_seed])
                var dressing: Dictionary = zone.get("dressing", {})

                # trees
                # v1.5.2 Wild Diversity: mixed-species forests. Each zone used to
                # clone ONE tree model ×820 — every forest in the world read as
                # a mirror of the same tree. Zones now draw from a weighted pool
                # (SM originals + Kenney CC0 species, understory + canopy mix).
                var tree_pool: Array = _tree_pool(String(dressing.get("trees", "none")))
                # v1.4 world-dress pass: density × ~2.3 (perf guard allows 22k instances,
                # v1.3 used only ~6.7k — the world read as empty at this scale)
                var tree_count := int(float(dressing.get("tree_density", 0.0)) * 820.0)
                if tree_pool.size() > 0 and tree_count > 0:
                        var stretch := 0.85 if String(dressing.get("trees", "")) == "dead" else 1.15
                        for member in tree_pool:
                                var mpath: String = String(member["path"])
                                var share := int(round(float(tree_count) * float(member["weight"])))
                                var trs := []
                                for p in _scatter_clustered(rng, share, zone, 0.55):
                                        var s := rng.randf_range(float(member["s_lo"]), float(member["s_hi"]))
                                        # v1.5.2 VLM pass: random lean ±6° breaks the cloned-tree
                                        # grid read — forests get organic, non-repeating postures
                                        var rot := Quaternion(Vector3.UP, rng.randf() * TAU)
                                        var tilt := Quaternion(Vector3(rng.randf_range(-1.0, 1.0), 0.0, rng.randf_range(-1.0, 1.0)).normalized(), rng.randf_range(-0.15, 0.15))
                                        var basis := Basis(rot * tilt).scaled(Vector3(s, s * stretch, s))
                                        trs.append(Transform3D(basis, p))
                                _multimesh(mpath, trs, member.get("mat", null), true, "tree")
                                if zid == "Zone_DawnFields":
                                        _add_tree_collisions(trs)

                # rocks
                var rock_count := int(float(dressing.get("rocks", 0.0)) * 420.0)
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
                var grass_count := int(float(dressing.get("grass", 0.0)) * 2100.0)
                if grass_count > 0:
                        var gtrs := []
                        for p in _scatter_clustered(rng, grass_count, zone, 0.5):
                                var s := rng.randf_range(1.15, 2.3)
                                gtrs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                        _multimesh("res://assets/meshes/environment/SM_Grass_Tuft.glb", gtrs, null, false, "grass")
                        if dressing.get("muck", false):
                                var ftrs := []
                                for p in _scatter_clustered(rng, int(float(dressing.get("grass", 0.0)) * 1150.0), zone, 0.4):
                                        ftrs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.9, 1.8)), p))
                                _multimesh("res://assets/meshes/environment/SM_Fern.glb", ftrs, null, true, "grass")

                # zone specials
                _dress_special(rng, zone)
                # v1.1 Phase V6: CC0 prop kits (Kenney nature + zone signatures)
                _dress_prop_kits(rng, zone)
                # v1.4: the home meadow — dense ring around the spawn camp so the
                # first frame a new player sees reads as alive, not empty
                if dressing.get("camp", false):
                        _dress_camp_richness(rng)


func _tree_pool(kind: String) -> Array:
        ## v1.5.2 Wild Diversity: per-forest-type weighted tree pools. Native
        ## heights were measured (tools/measure script): SM trees 5.6–8.0 m,
        ## Kenney trees 1.2–1.7 m, Kenney mushrooms 0.25 m — scales below land
        ## every member at a believable canopy/understory height (3.5–8 m).
        ## Returns [{path, s_lo, s_hi, weight, mat?}].
        var sm := "res://assets/meshes/environment/"
        match kind:
                "broadleaf":
                        return [
                                {"path": sm + "SM_Tree_Broadleaf.glb", "s_lo": 0.75, "s_hi": 1.5, "weight": 0.18},
                                {"path": KENNEY + "tree_oak.glb", "s_lo": 3.8, "s_hi": 6.4, "weight": 0.19},
                                {"path": KENNEY + "tree_detailed.glb", "s_lo": 3.6, "s_hi": 6.0, "weight": 0.17},
                                {"path": KENNEY + "tree_default.glb", "s_lo": 3.0, "s_hi": 5.2, "weight": 0.12},
                                {"path": KENNEY + "tree_fat.glb", "s_lo": 3.8, "s_hi": 6.2, "weight": 0.12},
                                {"path": KENNEY + "tree_thin.glb", "s_lo": 3.2, "s_hi": 5.4, "weight": 0.11},
                                {"path": KENNEY + "tree_small.glb", "s_lo": 2.8, "s_hi": 4.4, "weight": 0.11},
                        ]
                "conifer":
                        return [
                                {"path": sm + "SM_Tree_Conifer.glb", "s_lo": 0.75, "s_hi": 1.5, "weight": 0.26},
                                {"path": KENNEY + "tree_pineTallA.glb", "s_lo": 3.2, "s_hi": 5.8, "weight": 0.17},
                                {"path": KENNEY + "tree_pineRoundB.glb", "s_lo": 3.4, "s_hi": 5.8, "weight": 0.16},
                                {"path": KENNEY + "tree_cone.glb", "s_lo": 3.4, "s_hi": 5.6, "weight": 0.14},
                                {"path": KENNEY + "tree_plateau.glb", "s_lo": 3.2, "s_hi": 5.0, "weight": 0.11},
                                {"path": KENNEY + "tree_pineSmallA.glb", "s_lo": 2.6, "s_hi": 4.2, "weight": 0.08},
                                {"path": KENNEY + "tree_pineTallC.glb", "s_lo": 3.0, "s_hi": 5.2, "weight": 0.08},
                        ]
                "dead":
                        var dead_mat := StandardMaterial3D.new()
                        dead_mat.albedo_color = Color(0.28, 0.24, 0.22)
                        dead_mat.roughness = 1.0
                        return [
                                {"path": sm + "SM_Tree_Conifer.glb", "s_lo": 0.75, "s_hi": 1.5, "weight": 0.44, "mat": dead_mat},
                                {"path": KENNEY + "tree_thin_dark.glb", "s_lo": 3.4, "s_hi": 5.6, "weight": 0.30},
                                {"path": KENNEY + "tree_blocks_dark.glb", "s_lo": 3.6, "s_hi": 6.0, "weight": 0.26},
                        ]
                "spore":
                        return [
                                {"path": sm + "SM_Tree_SporeCanopy.glb", "s_lo": 0.75, "s_hi": 1.5, "weight": 0.52},
                                {"path": KENNEY + "mushroom_tanTall.glb", "s_lo": 14.0, "s_hi": 24.0, "weight": 0.27},
                                {"path": KENNEY + "mushroom_redTall.glb", "s_lo": 12.0, "s_hi": 20.0, "weight": 0.21},
                        ]
        return []


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


# ------------------------------------------------------ Phase V6 prop kits --
const KENNEY := "res://assets/meshes/kenney/nature/"
const QUAT_RUINS := "res://assets/meshes/quaternius/ruins/"


func _dress_prop_kits(rng: RandomNumberGenerator, zone: Dictionary) -> void:
        ## Per-zone CC0 prop dressing (v1.1 Phase V6). Selection derives from the
        ## existing dressing keys so it stays data-driven + deterministic per seed.
        var zid: String = zone["id"]
        var d: Dictionary = zone.get("dressing", {})
        var trees: String = String(d.get("trees", "none"))
        var grass_k: float = float(d.get("grass", 0.0))
        var special: String = String(d.get("special", ""))

        # --- mushrooms: deep forest zones (v1.4 density pass) ---
        if trees == "broadleaf" and grass_k >= 0.6:
                _kit_multimesh(rng, zone, ["mushroom_redTall", "mushroom_tanTall"], 68, 0.85, 1.5, true)
        if zid == "Zone_Glimmerwood":
                _kit_multimesh(rng, zone, ["mushroom_redGroup"], 52, 0.9, 1.8, true, Color(0.9, 0.4, 0.45))

        # --- flowers: meadow zones ---
        if grass_k >= 0.8:
                _kit_multimesh(rng, zone, ["flower_redA", "flower_yellowB", "flower_purpleC"], 130, 0.6, 1.2, false)
        if zid == "Zone_VerdantReach":
                _kit_multimesh(rng, zone, ["flower_redB", "flower_yellowA", "flower_purpleA"], 200, 0.6, 1.3, false)

        # --- logs & stumps: forest floors ---
        if trees != "none" and d.get("tree_density", 0.0) >= 0.3:
                _kit_multimesh(rng, zone, ["log", "stump_round", "stump_old"], 40, 0.8, 1.4, true)

        # --- bushes: anywhere green ---
        if grass_k >= 0.4:
                _kit_multimesh(rng, zone, ["plant_bushSmall", "plant_bush", "plant_flatTall"], 88, 0.7, 1.5, false)

        # --- lily pads: marsh + shallows ---
        if special == "glow_reeds" or zid == "Zone_AzureShallows" or zid == "Zone_PearlseaReef":
                _kit_multimesh(rng, zone, ["lily_small", "lily_large"], 96, 0.5, 1.4, false)

        # --- cacti: the Sunscar signature ---
        if zid == "Zone_Sunscar":
                _kit_multimesh(rng, zone, ["cactus_tall", "cactus_short"], 84, 0.7, 1.4, true)

        # --- palms: isles + reef ---
        if zid == "Zone_TidebreakerIsles" or zid == "Zone_PearlseaReef":
                _kit_multimesh(rng, zone, ["tree_palmTall", "tree_palmShort"], 60, 0.35, 0.7, true)

        # --- big cliffs: ember + storm ---
        if zid == "Zone_EmberRidge":
                _kit_multimesh(rng, zone, ["cliff_rock", "cliff_large_stone"], 46, 0.55, 1.1, true)
        if zid == "Zone_Stormcrest":
                _kit_multimesh(rng, zone, ["rock_tallA", "rock_tallD", "rock_tallG"], 64, 0.5, 1.0, true)

        # --- snow boulders: frostveil ---
        if d.get("snow", false):
                _kit_multimesh(rng, zone, ["rock_largeB", "rock_largeE"], 48, 0.5, 1.0, true, Color(0.88, 0.92, 0.98))

        # --- scattered stones: everywhere, light density ---
        _kit_multimesh(rng, zone, ["rock_smallB", "rock_smallE", "stone_smallC"], 56, 0.5, 1.2, false)


func _dress_camp_richness(rng: RandomNumberGenerator) -> void:
        ## v1.4: concentrated dressing in a 95 m ring around the spawn camp —
        ## global scatter at zone scale can never look dense (640,000 m² per
        ## zone), but the player's first hour lives inside this ring.
        var ring: Array = []
        var f_red: Array = []
        var f_yellow: Array = []
        var f_purple: Array = []
        var ferns: Array = []
        var tries := 0
        while ring.size() < 1900 and tries < 22000:
                tries += 1
                var ang: float = rng.randf() * TAU
                var rad: float = sqrt(rng.randf()) * 95.0
                if rad < 4.0:
                        continue
                var x: float = _camp_pos.x + cos(ang) * rad
                var z: float = _camp_pos.z + sin(ang) * rad
                var h: float = tile_height(x, z)
                if h < -1.0:
                        continue
                if slope_at(x, z) > 0.5:
                        continue
                var p := Vector3(x, h, z)
                var s := rng.randf_range(1.8, 3.4)
                ring.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
                var roll: float = rng.randf()
                if f_red.size() < 150 and roll < 0.07:
                        f_red.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.4, 2.0) * KENNEY_PROP_SCALE), p + Vector3(0, 0.03, 0)))
                elif f_yellow.size() < 150 and roll < 0.14:
                        f_yellow.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.4, 2.0) * KENNEY_PROP_SCALE), p + Vector3(0, 0.03, 0)))
                elif f_purple.size() < 140 and roll < 0.21:
                        f_purple.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.4, 2.0) * KENNEY_PROP_SCALE), p + Vector3(0, 0.03, 0)))
                elif ferns.size() < 200 and roll < 0.33:
                        ferns.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(1.1, 2.0)), p + Vector3(0, 0.02, 0)))
        _multimesh("res://assets/meshes/environment/SM_Grass_Tuft.glb", ring, null, false)
        _multimesh("res://assets/meshes/kenney/nature/flower_redA.glb", f_red, null, false)
        _multimesh("res://assets/meshes/kenney/nature/flower_yellowB.glb", f_yellow, null, false)
        _multimesh("res://assets/meshes/kenney/nature/flower_purpleC.glb", f_purple, null, false)
        _multimesh("res://assets/meshes/environment/SM_Fern.glb", ferns, null, false)


const KENNEY_PROP_SCALE := 2.6  # Kenney nature props import at mini scale

func _kit_multimesh(rng: RandomNumberGenerator, zone: Dictionary, names: Array, count: int,
                s_lo: float, s_hi: float, shadow: bool, tint: Color = Color(1, 1, 1, 0)) -> void:
        var trs := []
        for p in _scatter(rng, count, zone, 0.65):
                var s := rng.randf_range(s_lo, s_hi) * KENNEY_PROP_SCALE
                trs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * s), p))
        if trs.is_empty():
                return
        # one MultiMesh per prop name round-robin
        for ni in names.size():
                var sub: Array = []
                for i in trs.size():
                        if i % names.size() == ni:
                                sub.append(trs[i])
                var mat: Material = null
                if tint.a > 0.0:
                        mat = StandardMaterial3D.new()
                        mat.albedo_color = Color(tint.r, tint.g, tint.b)
                        mat.roughness = 0.9
                _multimesh(KENNEY + String(names[ni]) + ".glb", sub, mat, shadow)


# ------------------------------------------------------ Phase V6 landmarks --
const LANDMARKS := [
        {"id": "Location_WaystoneDawn", "name": "Waystone of Dawn", "zone": "Zone_DawnFields",
                "pos": Vector3(-250, 0, 160), "props": ["Statue_Stag"], "chest": "gold",
                "lore": "A stag of grey stone watches the fields where the first camp woke."},
        {"id": "Location_GlimmerGrove", "name": "Glimmer Grove Heart", "zone": "Zone_Glimmerwood",
                "pos": Vector3(-430, 0, 700), "props": ["Candles_1", "Arch_Gothic"],
                "chest": "wood", "lore": "Mushroom-light pools around a gothic arch of the old wood."},
        {"id": "Location_OldBridge", "name": "The Old Bridge", "zone": "Zone_DuskMarsh",
                "pos": Vector3(-1150, 0, 90), "props": ["Arch_Round", "Support_Tall"],
                "chest": "wood", "lore": "Whoever raised this span crossed the muck long before the flood."},
        {"id": "Location_Frostwatch", "name": "Frostwatch Tower", "zone": "Zone_Frostveil",
                "pos": Vector3(-1050, 0, 860), "props": [], "tower": true,
                "chest": "gold", "lore": "A survey tower from the first expeditions, glass-frozen ever since."},
        {"id": "Location_Emberfall", "name": "Emberfall Crater", "zone": "Zone_EmberRidge",
                "pos": Vector3(520, 0, 880), "props": ["Arch_Gothic_RoundColumn"],
                "chest": "gold", "lore": "Something fell burning here. The obsidian still hums at dusk."},
        {"id": "Location_SunscarObelisk", "name": "Sunscar Obelisk", "zone": "Zone_Sunscar",
                "pos": Vector3(1150, 0, 830), "props": ["Arch_Round_RoundColumn", "Statue_Fox"],
                "chest": "wood", "lore": "A fox-headed gate marking the burned road to the far dunes."},
        {"id": "Location_DrownedBell", "name": "The Drowned Bell", "zone": "Zone_AzureShallows",
                "pos": Vector3(1120, 0, -120), "props": [], "bell": true,
                "chest": "wood", "lore": "A bell tower sunk to its knees in warm shallows. It still rings in storms."},
        {"id": "Location_TidebreakerWatch", "name": "Tidebreaker Watch", "zone": "Zone_TidebreakerIsles",
                "pos": Vector3(-1100, 0, -860), "props": [], "tower": true,
                "chest": "gold", "lore": "The last hex-tower of the isle wardens, salt-scoured but standing."},
        {"id": "Location_StormAltar", "name": "Storm Altar", "zone": "Zone_Stormcrest",
                "pos": Vector3(-390, 0, -880), "props": ["Arch_Gothic", "Candles_2"],
                "chest": "gold", "lore": "Lightning gathers over this arch like it owes the stone a debt."},
        {"id": "Location_HollowShrine", "name": "Hollow Shrine", "zone": "Zone_HollowApproach",
                "pos": Vector3(360, 0, 140), "props": ["Statue_Fox", "Skull", "Candles_1"],
                "chest": "wood", "lore": "Offerings to whatever sleeps below the approach."},
        {"id": "Location_MotherTree", "name": "The Verdant Mother", "zone": "Zone_VerdantReach",
                "pos": Vector3(420, 0, -780), "props": [], "heart": true,
                "chest": "gold", "lore": "The great heart-tree of the reach — every green thing answers to it."},
        {"id": "Location_PearlGrotto", "name": "Pearl Grotto", "zone": "Zone_PearlseaReef",
                "pos": Vector3(1180, 0, -820), "props": ["Arch_Round", "Pot1", "Pot2_Broken"],
                "chest": "gold", "lore": "A shrine of arch and pearl-bright water at the reef's crown."},
        {"id": "Location_SkiffWreck", "name": "The Skiff Wreck", "zone": "Zone_DawnFields",
                "pos": Vector3(-380, 0, -180), "props": ["Barrel", "Crate", "Cart"],
                "chest": "wood", "lore": "An expedition skiff that never flew again. Its crates remember it."},
        {"id": "Location_RangersCamp", "name": "Ranger's Last Camp", "zone": "Zone_Glimmerwood",
                "pos": Vector3(-520, 0, 620), "props": ["Chest", "Bookcase_Full", "Candles_2"],
                "chest": "wood", "lore": "A field library abandoned mid-page. The candles never burned out."},
        {"id": "Location_Westgate", "name": "The Westgate Ruin", "zone": "Zone_HollowApproach",
                "pos": Vector3(430, 0, -60), "props": ["Arch_Round_RoundColumn", "Wall_Broken", "Wall_Hole"],
                "chest": "wood", "lore": "The western gate of a settlement that the Hollow took whole."},
]

const LANDMARK_CHEST_LOOT := {
        "gold": [{"item": "Item_Resonator", "qty": 1}, {"item": "Item_DawnShard", "qty": 40},
                        {"item": "Item_AncientAlloy", "qty": 2}],
        "wood": [{"item": "Item_DawnShard", "qty": 15}, {"item": "Item_Berry", "qty": 4},
                        {"item": "Item_Resonator", "qty": 1}],
}


func _build_landmarks() -> void:
        var marker_script := load("res://scripts/world/marker.gd")
        for lm in LANDMARKS:
                var pos: Vector3 = lm["pos"]
                pos.y = tile_height(pos.x, pos.z)
                # --- structures ---
                if lm.get("tower", false):
                        _mesh_instance("res://assets/meshes/kenney/castle/tower-hexagon-base.glb", pos, Vector3.ONE * 1.6)
                        _mesh_instance("res://assets/meshes/kenney/castle/tower-hexagon-mid.glb", pos + Vector3(0, 2.8, 0), Vector3.ONE * 1.6)
                        _mesh_instance("res://assets/meshes/kenney/castle/tower-hexagon-roof.glb", pos + Vector3(0, 5.6, 0), Vector3.ONE * 1.6)
                elif lm.get("bell", false):
                        _mesh_instance("res://assets/meshes/quaternius/village/Bell_Tower.fbx", pos, Vector3.ONE * 1.9)
                elif lm.get("heart", false):
                        _mesh_instance("res://assets/meshes/environment/SM_Tree_Broadleaf.glb", pos, Vector3.ONE * 6.0)
                for prop_name in lm.get("props", []):
                        var pp: Vector3 = pos + Vector3(randf_range(-3.0, 3.0), 0, randf_range(-3.0, 3.0))
                        pp.y = tile_height(pp.x, pp.z)
                        var sc := Vector3.ONE * randf_range(1.2, 1.7)
                        _mesh_instance(QUAT_RUINS + String(prop_name) + ".fbx", pp, sc)
                # --- the chest marker (reward) ---
                var chest_kind: String = String(lm.get("chest", "wood"))
                var chest_pos: Vector3 = pos + Vector3(2.2, 0, 1.4)
                chest_pos.y = tile_height(chest_pos.x, chest_pos.z)
                var chest_mesh_path := QUAT_RUINS + ("Chest_Gold.fbx" if chest_kind == "gold" else "Chest.fbx")
                var chest_node := _mesh_instance(chest_mesh_path, chest_pos, Vector3.ONE * 1.3)
                # glow ring so landmarks are findable
                var ring := _mesh_instance("res://assets/meshes/environment/SM_Rock_Granite_S.glb", chest_pos + Vector3(0, 0.12, 0), Vector3.ONE * 0.45)
                ring.material_override = _glow_ring_mat()
                # marker (interactable)
                var m: Node3D = Node3D.new()
                m.set_script(marker_script)
                m.position = chest_pos
                m.set_meta("interact_kind", "chest")
                m.set_meta("marker_label", lm["name"])
                m.set_meta("location_id", lm["id"])
                m.set_meta("chest_loot", LANDMARK_CHEST_LOOT.get(chest_kind, []))
                m.set_meta("chest_mesh", chest_node)
                props_root.add_child(m)
                # location marker on the structure itself (journal + RP once)
                var loc: Node3D = Node3D.new()
                loc.set_script(marker_script)
                loc.position = pos
                loc.set_meta("interact_kind", "location")
                loc.set_meta("marker_label", lm["name"])
                loc.set_meta("location_id", lm["id"])
                props_root.add_child(loc)
                landmark_count += 1


func _glow_ring_mat() -> StandardMaterial3D:
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.95, 0.8, 0.4)
        mat.emission_enabled = true
        mat.emission = Color(0.9, 0.7, 0.3)
        mat.emission_energy_multiplier = 1.8
        return mat


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
func _dress_village_paths() -> void:
        ## v1.1 Phase V6: stone paths radiating from each village campfire to its
        ## ring of buildings + a plaza circle, using Kenney path stones.
        var path_glb := KENNEY + "path_stone.glb"
        var circle_glb := KENNEY + "path_stoneCircle.glb"
        if not ResourceLoader.exists(path_glb):
                return
        for v in villages:
                var rng := RandomNumberGenerator.new()
                rng.seed = hash("paths-%s-%d" % [v.village_id, Game.world_seed])
                var trs: Array = []
                # plaza around the campfire
                for i in 10:
                        var ang := TAU * i / 10.0
                        var px: float = v.campfire.x + cos(ang) * 3.2
                        var pz: float = v.campfire.z + sin(ang) * 3.2
                        trs.append(Transform3D(Basis(Vector3.UP, ang).scaled(Vector3.ONE * 2.2), Vector3(px, tile_height(px, pz) + 0.06, pz)))
                # spokes to the ring radius
                for i in 8:
                        var ang := TAU * i / 8.0 + 0.18
                        for r in range(5, 24, 3):
                                var px: float = v.center.x + cos(ang) * float(r)
                                var pz: float = v.center.z + sin(ang) * float(r)
                                if px == v.campfire.x and pz == v.campfire.z:
                                        continue
                                var s := rng.randf_range(1.9, 2.5)
                                trs.append(Transform3D(Basis(Vector3.UP, ang + PI * 0.5).scaled(Vector3.ONE * s), Vector3(px, tile_height(px, pz) + 0.06, pz)))
                _multimesh(path_glb, trs, null, false)
                # plaza centrepiece ring
                if ResourceLoader.exists(circle_glb):
                        var ctrs: Array = [Transform3D(Basis().scaled(Vector3.ONE * 2.8), Vector3(v.campfire.x, tile_height(v.campfire.x, v.campfire.z) + 0.05, v.campfire.z))]
                        _multimesh(circle_glb, ctrs, null, false)


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
        var zones_total: int = Data.zones.size()
        var zi := 0
        for zone in Data.zones:
                _bp("Waking echoes — %s…" % zone.get("name", zone["id"]), 0.90 + 0.09 * float(zi) / float(maxi(1, zones_total)))
                if zi % 3 == 2:
                        await _breathe()
                zi += 1
                var zid: String = zone["id"]
                var rng := RandomNumberGenerator.new()
                rng.seed = hash("wild-%s-%d" % [zid, Game.world_seed])
                for entry in zone.get("wildlife", []):
                        var species_id: String = entry[0]
                        var count: int = int(entry[1])
                        var def: Dictionary = Data.species_def(species_id)
                        if def.is_empty():
                                continue
                        # v1.3 gallery pass: passive species ×2.2 so the world
                        # visibly teems with life; hostiles keep their balance
                        if not def.get("hostile", false):
                                count = int(round(count * 2.2))
                        for p in _scatter(rng, count, zone, 0.5):
                                _spawn_creature(def, p, rng)
                # v1.5.2 Wild Diversity: the zone Apex — ONE boss-mode individual
                # planted deep in the zone (furthest scatter point), full boss
                # kit: boss bar + phases + weak orb + telegraphs. 8 zones now
                # carry a roaming Apex on top of the 2 dungeon bosses.
                var apex_def: Dictionary = Data.apex_for_zone(zid)
                if not apex_def.is_empty():
                        var apex_pts := _scatter(rng, 12, zone, 0.8)
                        if apex_pts.size() > 0:
                                var apex: Node = _spawn_creature(apex_def, apex_pts[apex_pts.size() - 1], rng, true)
                                apexes.append(apex)
        # Auroraling: exactly one, deep in Glimmerwood
        var aura_def: Dictionary = Data.species_def("Echo_Auroraling")
        if not aura_def.is_empty():
                var p := Vector3(-400.0 - 260.0, 0, 800.0 - 210.0)
                p.y = tile_height(p.x, p.z)
                _spawn_creature(aura_def, p, _rng)


func _spawn_creature(def: Dictionary, pos: Vector3, rng: RandomNumberGenerator, boss: bool = false) -> Node:
        var echo_script := load("res://scripts/creatures/echo.gd")
        var echo: Node = echo_script.new(def, rng)
        # boss flag must land BEFORE add_child — _ready builds the body with
        # the boss 1.6× scale and rolls no random variant identity for bosses
        echo.boss_mode = boss
        echo.position = pos
        creatures_root.add_child(echo)
        return echo


func _process(delta: float) -> void:
        # PS-2: staged build is async — the world enters the tree before its
        # roots exist; skip sweeping until the Vale is fully built
        if creatures_root == null:
                return
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
                # v1.5.2: persisted individual identity (variant + jitters) so
                # the follower body matches the captured wild individual
                follower.apply_identity(str(wanted[idx].get("variant", "")), wanted[idx].get("vj", {}))
                follower.position = spawn_pos
                follower.become_captured(player)
                follower.bind_entry(wanted[idx])
                creatures_root.add_child(follower)
                followers[idx] = follower


# -------------------------------------------------- v1.3 V12-b: map support --
func landmark_list() -> Array:
        ## exposes the 15 named landmarks to the map screen (★ stars).
        return LANDMARKS


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
