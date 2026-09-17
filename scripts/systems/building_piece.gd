class_name BuildingPiece
extends StaticBody3D
## Player-placed building piece with a procedural silhouette.
## Station buildings (workbench/campfire) are interactable crafting stations.

var def: Dictionary = {}
var _station_id := ""
var _label: Label3D
var _power_role := "None"
var _powered := false
var _lamp_light: OmniLight3D = null


func _init(p_def: Dictionary) -> void:
        def = p_def


func _ready() -> void:
        collision_layer = 5
        collision_mask = 0
        _station_id = str(def.get("station", ""))
        _power_role = str(def.get("power_role", "None"))
        # power buildings register with the shared grid (12 m connectivity, 2 s resolve)
        if _power_role != "None" and _power_role != "":
                var world := get_tree().get_first_node_in_group("world")
                if world:
                        var grid = world.get("power_grid")
                        if grid and grid.has_method("register_building"):
                                grid.register_building(self)
        var color := Color(0.55, 0.42, 0.3)
        var emissive := Color.BLACK
        match def.get("id", ""):
                "Building_Foundation":
                        _add_box(Vector3(4, 0.35, 4), Vector3(0, 0.17, 0), Color(0.5, 0.4, 0.3))
                "Building_Wall":
                        _add_box(Vector3(4, 3, 0.3), Vector3(0, 1.5, 0), Color(0.58, 0.45, 0.33))
                "Building_Workbench":
                        _add_box(Vector3(2.2, 0.15, 1.2), Vector3(0, 0.9, 0), Color(0.55, 0.42, 0.3))
                        _add_box(Vector3(0.2, 0.9, 0.2), Vector3(-0.9, 0.45, -0.45), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.2, 0.9, 0.2), Vector3(0.9, 0.45, -0.45), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.2, 0.9, 0.2), Vector3(-0.9, 0.45, 0.45), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.2, 0.9, 0.2), Vector3(0.9, 0.45, 0.45), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.5, 0.18, 0.4), Vector3(0.6, 1.05, 0), Color(0.75, 0.75, 0.8))
                        color = Color(0.6, 0.8, 1.0)
                "Building_Campfire":
                        _add_box(Vector3(0.7, 0.25, 0.7), Vector3(0, 0.12, 0), Color(0.45, 0.42, 0.4))
                        _add_box(Vector3(0.4, 0.4, 0.4), Vector3(0, 0.35, 0), Color(0.9, 0.5, 0.2), true)
                        _add_fire()
                        color = Color(1.0, 0.7, 0.4)
                "Building_Generator":
                        _add_box(Vector3(1.6, 1.8, 1.2), Vector3(0, 0.9, 0), Color(0.45, 0.48, 0.52))
                        _add_box(Vector3(0.5, 0.5, 0.1), Vector3(0, 1.2, 0.62), Color(0.3, 0.9, 0.7), true)
                        color = Color(0.3, 0.95, 0.7)
                "Building_Battery":
                        _add_box(Vector3(1.2, 0.9, 0.9), Vector3(0, 0.45, 0), Color(0.4, 0.5, 0.55))
                        _add_box(Vector3(0.8, 0.12, 0.06), Vector3(0, 0.75, 0.47), Color(0.4, 0.9, 1.0), true)
                "Building_LampPost":
                        _add_box(Vector3(0.18, 3.2, 0.18), Vector3(0, 1.6, 0), Color(0.35, 0.3, 0.28))
                        _add_box(Vector3(0.5, 0.35, 0.5), Vector3(0, 3.35, 0), Color(1.0, 0.9, 0.6), true)
                        _add_light(Vector3(0, 3.4, 0), Color(1.0, 0.85, 0.55), 12.0, 1.4)
                "Building_FarmPlot":
                        _add_box(Vector3(3.2, 0.2, 3.2), Vector3(0, 0.1, 0), Color(0.35, 0.26, 0.18))
                        _add_box(Vector3(0.3, 0.4, 0.3), Vector3(-1, 0.35, -1), Color(0.4, 0.7, 0.3))
                        _add_box(Vector3(0.3, 0.5, 0.3), Vector3(1, 0.4, 1), Color(0.5, 0.8, 0.35))
                "Building_ResearchDesk":
                        _add_box(Vector3(1.8, 0.12, 0.9), Vector3(0, 0.85, 0), Color(0.5, 0.4, 0.32))
                        _add_box(Vector3(0.15, 0.85, 0.15), Vector3(-0.75, 0.42, -0.3), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.15, 0.85, 0.15), Vector3(0.75, 0.42, -0.3), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.15, 0.85, 0.15), Vector3(-0.75, 0.42, 0.3), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.15, 0.85, 0.15), Vector3(0.75, 0.42, 0.3), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.35, 0.5, 0.35), Vector3(0.5, 1.15, 0), Color(0.6, 0.85, 1.0), true)
                "Building_FeedTrough":
                        _add_box(Vector3(1.8, 0.15, 0.8), Vector3(0, 0.55, 0), Color(0.5, 0.4, 0.3))
                        _add_box(Vector3(1.6, 0.3, 0.6), Vector3(0, 0.35, 0), Color(0.42, 0.33, 0.25))
                        _add_box(Vector3(0.15, 0.55, 0.15), Vector3(-0.8, 0.27, 0), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.15, 0.55, 0.15), Vector3(0.8, 0.27, 0), Color(0.4, 0.32, 0.24))
                "Building_Sawmill":
                        _add_box(Vector3(2.6, 0.15, 1.6), Vector3(0, 1.0, 0), Color(0.5, 0.4, 0.3))
                        _add_box(Vector3(0.2, 1.0, 0.2), Vector3(-1.1, 0.5, -0.6), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.2, 1.0, 0.2), Vector3(1.1, 0.5, -0.6), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.2, 1.0, 0.2), Vector3(-1.1, 0.5, 0.6), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.2, 1.0, 0.2), Vector3(1.1, 0.5, 0.6), Color(0.4, 0.32, 0.24))
                        _add_box(Vector3(0.8, 0.08, 1.2), Vector3(0.6, 1.1, 0), Color(0.8, 0.8, 0.85))
                "Building_Heater":
                        _add_box(Vector3(1.0, 1.2, 1.0), Vector3(0, 0.6, 0), Color(0.4, 0.38, 0.4))
                        _add_box(Vector3(0.6, 0.3, 0.06), Vector3(0, 0.7, 0.52), Color(1.0, 0.5, 0.25), true)
                        _add_light(Vector3(0, 1.4, 0), Color(1.0, 0.5, 0.25), 7.0, 1.0)
                "Building_Composter":
                        _add_box(Vector3(1.4, 1.0, 1.4), Vector3(0, 0.5, 0), Color(0.35, 0.3, 0.22))
                        _add_box(Vector3(1.5, 0.12, 1.5), Vector3(0, 1.05, 0), Color(0.3, 0.45, 0.2))

        if _station_id != "" or def.get("id", "") in ["Building_ResearchDesk", "Building_FeedTrough"]:
                _label = Label3D.new()
                _label.text = def.get("name", "")
                _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
                _label.no_depth_test = true
                _label.position = Vector3(0, 2.4, 0)
                _label.font_size = 40
                _label.outline_size = 8
                _label.modulate = color
                add_child(_label)

        # interaction collision
        var area := Area3D.new()
        area.collision_layer = 0
        area.collision_mask = 2
        var col := CollisionShape3D.new()
        var box := BoxShape3D.new()
        box.size = Vector3(3.6, 3.2, 3.6)
        col.shape = box
        col.position = Vector3(0, 1.4, 0)
        area.add_child(col)
        add_child(area)

        # base collision
        var bcol := CollisionShape3D.new()
        var bbox := BoxShape3D.new()
        bbox.size = Vector3(2.6, 2.4, 2.6)
        bcol.shape = bbox
        bcol.position = Vector3(0, 1.2, 0)
        add_child(bcol)


func _add_box(size: Vector3, pos: Vector3, color: Color, emissive_on: bool = false) -> void:
        var mi := MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = size
        mi.mesh = box
        mi.position = pos
        var mat := StandardMaterial3D.new()
        mat.albedo_color = color
        mat.roughness = 0.85
        if emissive_on:
                mat.emission_enabled = true
                mat.emission = color
                mat.emission_energy_multiplier = 1.6
        mi.material_override = mat
        add_child(mi)


func _add_light(pos: Vector3, color: Color, range: float, energy: float) -> void:
        var light := OmniLight3D.new()
        light.position = pos
        light.omni_range = range
        light.light_color = color
        light.light_energy = energy
        add_child(light)
        # lamp lights are grid-gated (UE5 bIsPowered visuals)
        if _power_role == "Consumer":
                light.visible = false
                _lamp_light = light


func _add_fire() -> void:
        var fire := CPUParticles3D.new()
        fire.amount = 22
        fire.lifetime = 0.9
        fire.position = Vector3(0, 0.55, 0)
        fire.direction = Vector3(0, 1, 0)
        fire.spread = 10.0
        fire.initial_velocity_min = 0.6
        fire.initial_velocity_max = 1.4
        fire.gravity = Vector3(0, 1.0, 0)
        fire.scale_amount_min = 0.08
        fire.scale_amount_max = 0.22
        var quad := QuadMesh.new()
        quad.size = Vector2(0.2, 0.2)
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(1.0, 0.65, 0.25)
        mat.emission_enabled = true
        mat.emission = Color(1.0, 0.45, 0.1)
        mat.emission_energy_multiplier = 3.0
        mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        quad.material = mat
        fire.mesh = quad
        add_child(fire)
        _add_light(Vector3(0, 1.2, 0), Color(1.0, 0.6, 0.3), 12.0, 1.5)


func interact() -> bool:
        if _station_id == "Station_Workbench":
                var screens := get_tree().get_first_node_in_group("screens")
                if screens:
                        screens.open_crafting("Station_Workbench")
                return true
        if _station_id == "Station_Campfire":
                var screens := get_tree().get_first_node_in_group("screens")
                if screens:
                        screens.open_crafting("Station_Campfire")
                return true
        if def.get("id", "") == "Building_ResearchDesk":
                var screens := get_tree().get_first_node_in_group("screens")
                if screens:
                        screens.open_research()
                return true
        if def.get("id", "") == "Building_FeedTrough":
                Game.feed_party()
                return true
        return false


func prompt() -> String:
        match _station_id:
                "Station_Workbench": return "Workbench — [E] craft"
                "Station_Campfire": return "Campfire — [E] cook"
        if def.get("id", "") == "Building_ResearchDesk":
                return "Research Desk — [E] research"
        if def.get("id", "") == "Building_FeedTrough":
                return "Feed Trough — [E] feed party"
        return ""


func get_save_data() -> Dictionary:
        return {"id": def.get("id", ""), "x": position.x, "y": position.y, "z": position.z, "rot": rotation_degrees.y}


# ------------------------------------------------------------------- power --
## Power grid callback — lamps go dark when the grid browns out, dynamos pulse.
func set_powered(state: bool) -> void:
        _powered = state
        if _lamp_light:
                _lamp_light.visible = state
        if _label and _power_role != "None":
                match _power_role:
                        "Generator":
                                _label.modulate = Color(0.3, 1.0, 0.7) if state else Color(0.5, 0.5, 0.5)
                        "Battery":
                                _label.modulate = Color(0.4, 0.9, 1.0) if state else Color(0.5, 0.5, 0.5)
                        "Consumer":
                                _label.modulate = Color(1.0, 0.9, 0.6) if state else Color(0.55, 0.45, 0.45)


func _exit_tree() -> void:
        # power buildings leave the grid when freed (dismantle/respawn)
        if _power_role != "None" and _power_role != "":
                var world := get_tree().get_first_node_in_group("world") if is_inside_tree() else null
                if world:
                        var grid = world.get("power_grid")
                        if grid and grid.has_method("unregister_building"):
                                grid.unregister_building(self)
