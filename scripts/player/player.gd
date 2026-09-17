class_name PlayerCharacter
extends CharacterBody3D
## Third-person survivor. Movement, spring camera, melee/ranged combat,
## dodge i-frames, block, interaction, observation journal, capture, build mode.

const WALK_SPEED := 4.5
const SPRINT_SPEED := 7.0
const JUMP_VELOCITY := 6.0
const AIR_CONTROL := 0.35
const LIGHT_DAMAGE := 25.0
const HEAVY_DAMAGE := 60.0
const LIGHT_CD := 0.45
const HEAVY_CD := 1.3
const HEAVY_STAMINA := 25.0
const DODGE_CD := 0.9
const DODGE_STAMINA := 22.0
const DODGE_IFRAMES := 0.4
const DODGE_IMPULSE := 9.0
const SWEEP_RANGE := 3.2
const SWEEP_RADIUS := 0.9
const INTERACT_RANGE := 3.6
const CAPTURE_RANGE := 12.0
const OBSERVE_RANGE := 14.0

var camera_pivot: Node3D
var camera: Camera3D
var spring: SpringArm3D
var model_root: Node3D
var weapon_holder: Node3D
var anim: AnimationPlayer
var attack_cd := 0.0
var dodge_cd := 0.0
var dodge_timer := 0.0
var heavy_charge := 0.0
var _cam_yaw := 0.0
var _cam_pitch := -0.35
var _world: Node3D
var _observed: Echo = null
var _observe_progress_frame := 0.0
var _footstep_timer := 0.0
var _build_mode := false
var _build_ghost: MeshInstance3D
var _build_def: Dictionary = {}
var _build_rot := 0.0
var _sfx := {}


func _ready() -> void:
        add_to_group("player")
        collision_layer = 2
        collision_mask = 1 | 4 | 8 | 16
        var col := CollisionShape3D.new()
        var cap := CapsuleShape3D.new()
        cap.radius = 0.42
        cap.height = 1.8
        col.shape = cap
        col.position = Vector3(0, 0.9, 0)
        add_child(col)

        _setup_model()
        _setup_camera()
        _setup_sfx()
        Game.screen_requested.connect(_on_screen_requested)
        Game.equipment_changed.connect(_refresh_weapon_visual)


func _setup_model() -> void:
        model_root = Node3D.new()
        model_root.name = "Model"
        add_child(model_root)
        var scene: PackedScene = load("res://assets/meshes/characters/SK_Survivor_Exosuit.glb")
        if scene:
                var visual := scene.instantiate()
                model_root.add_child(visual)
                anim = _find_anim(visual)
                if anim and anim.has_animation("AM_Survivor_Idle"):
                        anim.play("AM_Survivor_Idle")
                var hand := _find_node(visual, "Hand_R")
                if hand:
                        weapon_holder = Node3D.new()
                        weapon_holder.name = "WeaponHolder"
                        hand.add_child(weapon_holder)
                        weapon_holder.position = Vector3(0, 0.1, 0.05)
        _refresh_weapon_visual()


func _find_anim(node: Node) -> AnimationPlayer:
        for c in node.get_children():
                if c is AnimationPlayer:
                        return c
                var found := _find_anim(c)
                if found:
                        return found
        return null


func _find_node(node: Node, name: String) -> Node:
        if node.name == name:
                return node
        for c in node.get_children():
                var found := _find_node(c, name)
                if found:
                        return found
        return null


func _refresh_weapon_visual() -> void:
        if weapon_holder == null:
                return
        for c in weapon_holder.get_children():
                c.queue_free()
        var wid: String = Game.equipment["weapon"]
        if wid == "":
                return
        var def := Data.item(wid)
        var mesh: Mesh = null
        match wid:
                "Item_PulseLance":
                        mesh = _mesh("res://assets/meshes/weapons/SM_Weapon_PlasmaCarbine.glb")
                "Item_Scrapshot":
                        mesh = _mesh("res://assets/meshes/weapons/SM_Weapon_ScrapRifle.glb")
                "Item_PlasmaCharger":
                        mesh = _mesh("res://assets/meshes/weapons/SM_Weapon_PlasmaCarbine.glb")
                "Item_LumenBeam", "Item_ArcCaster":
                        mesh = _mesh("res://assets/meshes/weapons/SM_Weapon_ArcCannon.glb")
                "Item_MagrailDriver":
                        mesh = _mesh("res://assets/meshes/weapons/SM_Weapon_Railgun.glb")
                "Item_StarlancePrototype":
                        mesh = _mesh("res://assets/meshes/weapons/SM_Weapon_SingularityCannon.glb")
                "Item_DawnwoodClub":
                        var box := BoxMesh.new()
                        box.size = Vector3(0.12, 0.12, 0.8)
                        mesh = box
                "Item_CrystalBlade":
                        var blade := BoxMesh.new()
                        blade.size = Vector3(0.06, 0.16, 1.1)
                        mesh = blade
                "Item_AncientResonator":
                        var staff := CylinderMesh.new()
                        staff.top_radius = 0.05
                        staff.bottom_radius = 0.05
                        staff.height = 1.4
                        mesh = staff
        if mesh:
                var mi := MeshInstance3D.new()
                mi.mesh = mesh
                var mat := StandardMaterial3D.new()
                mat.albedo_color = Data.element_color(def.get("element", "None"))
                if def.get("ranged", false) or def.get("element", "None") != "None":
                        mat.emission_enabled = true
                        mat.emission = Data.element_color(def.get("element", "None"))
                        mat.emission_energy_multiplier = 0.9
                if wid in ["Item_DawnwoodClub"]:
                        mat.albedo_color = Color(0.5, 0.38, 0.26)
                        mat.emission_enabled = false
                mi.material_override = mat
                mi.rotation_degrees = Vector3(0, 0, 0)
                weapon_holder.add_child(mi)


func _mesh(path: String) -> Mesh:
        var scene: PackedScene = load(path)
        if scene == null:
                return null
        var inst := scene.instantiate()
        var mi := _find_mesh(inst)
        var mesh: Mesh = null
        if mi:
                mesh = mi.mesh
        inst.queue_free()
        return mesh


func _find_mesh(node: Node) -> MeshInstance3D:
        if node is MeshInstance3D:
                return node
        for c in node.get_children():
                var found := _find_mesh(c)
                if found:
                        return found
        return null


func _setup_camera() -> void:
        camera_pivot = Node3D.new()
        camera_pivot.position = Vector3(0, 1.55, 0)
        add_child(camera_pivot)
        spring = SpringArm3D.new()
        spring.spring_length = 4.2
        spring.collision_mask = 1
        spring.margin = 0.35
        camera_pivot.add_child(spring)
        camera = Camera3D.new()
        camera.fov = 72.0
        spring.add_child(camera)
        camera.make_current()


func _setup_sfx() -> void:
        for id in ["A_Footstep_Grass", "A_Echo_Capture_Success", "A_SFX_Hit_Validate", "A_SFX_Attack_Swing"]:
                var path := "res://assets/audio/%s.wav" % id
                if ResourceLoader.exists(path):
                        _sfx[id] = load(path)
        # attack swing fallback: use footstep if no sfx
        if not _sfx.has("A_SFX_Attack_Swing") and _sfx.has("A_Footstep_Grass"):
                _sfx["A_SFX_Attack_Swing"] = _sfx["A_Footstep_Grass"]


func _play_sfx(id: String, vol: float = -12.0) -> void:
        if _sfx.has(id):
                var player := AudioStreamPlayer.new()
                player.stream = _sfx[id]
                player.volume_db = vol
                add_child(player)
                player.play()
                player.finished.connect(player.queue_free)


func _physics_process(delta: float) -> void:
        if Game.dead:
                velocity.x = 0
                velocity.z = 0
                if not is_on_floor():
                        velocity.y -= 18.0 * delta
                move_and_slide()
                return
        if _ui_open():
                velocity.x = move_toward(velocity.x, 0, 12.0 * delta)
                velocity.z = move_toward(velocity.z, 0, 12.0 * delta)
                move_and_slide()
                return
        if get_meta("piloting", false):
                # aboard the Dawn Skiff: the skiff owns movement, we keep camera + clock
                _handle_mouse_motion()
                _handle_camera_keys(delta)
                return
        _handle_mouse_motion()
        _handle_camera_keys(delta)
        _movement(delta)
        _actions(delta)
        _observation(delta)
        _build_update(delta)
        move_and_slide()
        _animate(delta)
        _zone_tracking()


## Aboard the Dawn Skiff: movement is disabled, mouse look stays free (UE5 policy).
func set_piloting(enabled: bool) -> void:
        set_meta("piloting", enabled)
        collision_layer = 0 if enabled else 2
        collision_mask = 0 if enabled else (1 | 4 | 8 | 16)
        velocity = Vector3.ZERO


func _ui_open() -> bool:
        var screens := get_tree().get_first_node_in_group("screens")
        if screens and screens.has_method("is_open"):
                return screens.is_open()
        return false


func _handle_mouse_motion() -> void:
        var vp := get_viewport()
        if Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
                return
        var md := vp.get_mouse_position()
        # use relative via warp-less approach: InputEventMouseMotion handled in _input
        # (fallback: nothing here)


func _input(event: InputEvent) -> void:
        if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
                _cam_yaw -= event.relative.x * 0.0032
                _cam_pitch = clampf(_cam_pitch - event.relative.y * 0.0028, -1.2, 0.6)
                camera_pivot.rotation = Vector3(_cam_pitch, _cam_yaw, 0)


func _handle_camera_keys(_delta: float) -> void:
        if Input.is_action_just_pressed("rotate_left"):
                _cam_yaw += 0.06
        if Input.is_action_just_pressed("rotate_right"):
                _cam_yaw -= 0.06


func _movement(delta: float) -> void:
        var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
        var cam_basis := camera.global_basis
        var forward := -cam_basis.z
        forward.y = 0.0
        forward = forward.normalized()
        var right := cam_basis.x
        right.y = 0.0
        right = right.normalized()
        var wish := (forward * -input_dir.y + right * input_dir.x)
        if wish.length() > 1.0:
                wish = wish.normalized()

        var sprinting := Input.is_action_pressed("sprint") and stamina_ok() and input_dir != Vector2.ZERO
        var speed := (SPRINT_SPEED if sprinting else WALK_SPEED) * Game.speed_bonus() * Game.status_speed_mult()
        if Game.get_meta("blocking", false):
                speed *= 0.45
        # swim
        var swimming := global_position.y < -3.6
        if swimming:
                speed *= 0.55

        if sprinting:
                Game.stamina = maxf(0.0, Game.stamina - 7.0 * delta)
                Game.stats_changed.emit()
        elif not Input.is_action_pressed("sprint"):
                Game.restore_stamina(Game.stamina_regen_rate() * delta)

        if is_on_floor():
                var target := wish * speed
                velocity.x = lerpf(velocity.x, target.x, 12.0 * delta)
                velocity.z = lerpf(velocity.z, target.z, 12.0 * delta)
                if Input.is_action_just_pressed("jump"):
                        velocity.y = JUMP_VELOCITY
                        _play_anim("Jump")
        else:
                var target := wish * speed
                velocity.x = lerpf(velocity.x, target.x, 12.0 * delta * AIR_CONTROL * 3.0)
                velocity.z = lerpf(velocity.z, target.z, 12.0 * delta * AIR_CONTROL * 3.0)
                velocity.y -= 18.0 * delta
        if swimming:
                velocity.y = maxf(velocity.y, 0.0)
        # dodge impulse decay handled by friction above


func stamina_ok() -> bool:
        return Game.stamina > 5.0


func _actions(delta: float) -> void:
        attack_cd = maxf(0.0, attack_cd - delta)
        dodge_cd = maxf(0.0, dodge_cd - delta)
        if dodge_timer > 0.0:
                dodge_timer -= delta
                set_meta("dodging", true)
        else:
                set_meta("dodging", false)
        set_meta("blocking", Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not _ranged_equipped())

        # dodge
        if Input.is_action_just_pressed("dodge") and dodge_cd <= 0.0 and is_on_floor():
                if Game.drain_stamina(DODGE_STAMINA):
                        dodge_cd = DODGE_CD
                        dodge_timer = DODGE_IFRAMES
                        var dir := Vector3(velocity.x, 0, velocity.z)
                        if dir.length() < 0.1:
                                var cam_basis := camera.global_basis
                                dir = -cam_basis.z
                                dir.y = 0
                                dir = dir.normalized()
                        else:
                                dir = dir.normalized()
                        velocity.x = dir.x * DODGE_IMPULSE
                        velocity.z = dir.z * DODGE_IMPULSE
                        _play_anim("Jump")

        # attack (melee) or fire (ranged)
        if _ranged_equipped():
                if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) and attack_cd <= 0.0:
                        _fire_weapon()
        else:
                if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
                        heavy_charge += delta
                        if heavy_charge > 0.45:
                                _heavy_attack()
                                heavy_charge = -0.3  # debounce
                else:
                        if heavy_charge > 0.0 and attack_cd <= 0.0:
                                _light_attack()
                        heavy_charge = maxf(0.0, heavy_charge)
                        if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
                                heavy_charge = 0.0

        # interact
        if Input.is_action_just_pressed("interact"):
                _try_interact()
        # capture
        if Input.is_action_just_pressed("capture"):
                _try_capture()
        # feed wild echo
        if Input.is_action_just_pressed("feed"):
                _try_feed()
        # party commands
        if Input.is_action_just_pressed("party_follow"):
                Game.set_party_command("Follow")
        if Input.is_action_just_pressed("party_stay"):
                Game.set_party_command("Stay")
        if Input.is_action_just_pressed("party_attack"):
                Game.set_party_command("Attack")
        # screens
        for pair in [["inventory", "inventory"], ["crafting", "crafting"], ["research", "research"], ["journal", "journal"], ["map", "map"], ["pause", "pause"], ["mods", "mods"]]:
                if Input.is_action_just_pressed(pair[0]):
                        Game.screen_requested.emit(pair[1])
        if Input.is_action_just_pressed("build"):
                _toggle_build_mode()


func _ranged_equipped() -> bool:
        var wid: String = Game.equipment["weapon"]
        return wid != "" and Data.item(wid).get("ranged", false)


func _light_attack() -> void:
        if attack_cd > 0.0:
                return
        attack_cd = LIGHT_CD
        _do_sweep(LIGHT_DAMAGE + Game.weapon_damage(), 0.9)
        _play_anim("Gather")
        _play_sfx("A_SFX_Attack_Swing", -16.0)


func _heavy_attack() -> void:
        if attack_cd > 0.0 or not Game.drain_stamina(HEAVY_STAMINA):
                return
        attack_cd = HEAVY_CD
        _do_sweep(HEAVY_DAMAGE + Game.weapon_damage(), 1.15)
        _play_anim("Fire")
        _play_sfx("A_SFX_Attack_Swing", -10.0)


func _do_sweep(damage: float, radius: float) -> void:
        var space := get_world_3d().direct_space_state
        var origin := global_position + Vector3(0, 1.1, 0)
        var facing := -camera.global_basis.z
        facing.y = 0.0
        facing = facing.normalized()
        var center := origin + facing * SWEEP_RANGE * 0.5
        var shape := SphereShape3D.new()
        shape.radius = SWEEP_RANGE * 0.5 + radius
        var query := PhysicsShapeQueryParameters3D.new()
        query.shape = shape
        query.transform = Transform3D(Basis(), center)
        query.collision_mask = 4  # creature areas
        var hits := space.intersect_shape(query, 16)
        for hit in hits:
                var collider = hit["collider"]
                var echo = collider.get_parent() if collider is Area3D else collider
                if echo and echo is Node and echo.has_method("take_hit"):
                        echo.take_hit(damage, Game.weapon_element())


func _fire_weapon() -> void:
        var wid: String = Game.equipment["weapon"]
        var def := Data.item(wid)
        var fire_interval: float = def.get("fire_interval", 0.5)
        if attack_cd > 0.0:
                return
        var ammo: String = def.get("ammo", "")
        if ammo != "" and Game.count_item(ammo) <= 0:
                Game.toast.emit("No %s left." % Data.item_name(ammo), Color(1.0, 0.7, 0.5))
                return
        attack_cd = fire_interval
        if ammo != "":
                Game.remove_item(ammo, 1)
        _play_anim("Fire")
        _spawn_projectile(def)


func _spawn_projectile(def: Dictionary) -> void:
        var projectile := Node3D.new()
        projectile.set_script(load("res://scripts/player/projectile.gd"))
        var origin := global_position + Vector3(0, 1.35, 0)
        var facing := -camera.global_basis.z
        facing = facing.normalized()
        projectile.position = origin + facing * 0.9
        projectile.set_meta("damage", def.get("atk", 10) + LIGHT_DAMAGE * 0.4)
        projectile.set_meta("element", def.get("element", "None"))
        projectile.set_meta("direction", facing)
        projectile.set_meta("speed", 55.0)
        projectile.set_meta("life", 1.6)
        var mi := MeshInstance3D.new()
        var sph := SphereMesh.new()
        sph.radius = 0.18
        sph.height = 0.36
        mi.mesh = sph
        var mat := StandardMaterial3D.new()
        var col := Data.element_color(def.get("element", "None"))
        mat.albedo_color = col
        mat.emission_enabled = true
        mat.emission = col
        mat.emission_energy_multiplier = 3.0
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mi.material_override = mat
        projectile.add_child(mi)
        var light := OmniLight3D.new()
        light.light_color = col
        light.light_energy = 2.0
        light.omni_range = 5.0
        projectile.add_child(light)
        get_parent().add_child(projectile)


# ----------------------------------------------------------- interaction ---
func _interaction_candidates() -> Array:
        var out := []
        # interactables group: markers, NPCs, skiffs, dungeon portals, work sites
        for c in get_tree().get_nodes_in_group("interactables"):
                if c is Node3D and c.has_method("prompt") and not c.is_queued_for_deletion():
                        out.append(c)
        # resource nodes + player-placed buildings live under the world roots
        var world := get_tree().get_first_node_in_group("world")
        if world:
                for arr_name in ["npcs_root", "nodes_root", "buildings_root"]:
                        var root: Node = world.get(arr_name)
                        if root:
                                for c in root.get_children():
                                        if c is Node3D and c.has_method("prompt") and not c.is_queued_for_deletion() and not out.has(c):
                                                out.append(c)
        return out


func _nearest_interactable() -> Node3D:
        var best: Node3D = null
        var best_d := INTERACT_RANGE
        var cam_facing := -camera.global_basis.z
        for c in _interaction_candidates():
                var d: float = global_position.distance_to(c.global_position)
                if d > INTERACT_RANGE:
                        continue
                var to_c: Vector3 = (c.global_position - global_position).normalized()
                if cam_facing.dot(to_c) < 0.25 and d > 1.8:
                        continue
                if d < best_d:
                        best_d = d
                        best = c
        return best


func _try_interact() -> void:
        if _build_mode:
                _place_building()
                return
        var target := _nearest_interactable()
        if target == null:
                return
        if target.has_method("interact"):
                target.interact()


func _try_capture() -> void:
        var echo := _nearest_echo(CAPTURE_RANGE, true)
        if echo == null:
                Game.toast.emit("No Echo in reach — weaken it first, then aim and press F.", Color(0.9, 0.9, 0.9))
                return
        Game.try_capture(echo)


func _try_feed() -> void:
        var echo := _nearest_echo(6.0, false)
        if echo == null:
                Game.toast.emit("No Echo nearby to feed.", Color(0.9, 0.9, 0.9))
                return
        var s: Dictionary = echo.def
        var chosen := ""
        for f in s.get("foods", []):
                if Game.count_item(f) > 0:
                        chosen = f
                        break
        if chosen == "":
                for f in ["Item_FeedMix", "Item_Berry"]:
                        if Game.count_item(f) > 0:
                                chosen = f
                                break
        if chosen == "":
                Game.toast.emit("No food it would enjoy.", Color(1.0, 0.7, 0.5))
                return
        var mult := 2.0 if chosen in s.get("foods", []) else 1.0
        var feed_value: float = Data.item(chosen).get("feed_value", 5.0)
        var trust_gain := 8.0 * mult * (0.01 * feed_value)
        echo.trust = minf(100.0, echo.trust + trust_gain)
        Game.remove_item(chosen, 1)
        Game.toast.emit("%s enjoyed the %s (+%d trust)" % [s.get("name", "Echo"), Data.item_name(chosen), int(trust_gain)], Color(0.7, 1.0, 0.7))


func _nearest_echo(range_m: float, require_wild: bool) -> Echo:
        var best: Echo = null
        var best_d := range_m
        var cam_facing := -camera.global_basis.z
        for c in get_tree().get_nodes_in_group("creatures"):
                if not (c is Echo) or c.is_defeated():
                        continue
                if require_wild and c.captured:
                        continue
                if not require_wild and c.captured:
                        continue
                var d: float = global_position.distance_to(c.global_position)
                if d > best_d:
                        continue
                var to_c: Vector3 = (c.global_position - global_position).normalized()
                if cam_facing.dot(to_c) < 0.35:
                        continue
                best_d = d
                best = c
        return best


# ----------------------------------------------------------- observation ---
func _observation(delta: float) -> void:
        var echo := _nearest_echo(OBSERVE_RANGE, false)
        if echo != null and not echo.is_defeated():
                var to_c := (echo.global_position + Vector3(0, 1, 0) - camera.global_position).normalized()
                var cam_facing := -camera.global_basis.z
                if cam_facing.dot(to_c) >= 0.75:
                        _observed = echo
                        echo.tracked = true
                        var mult := 3.0 if Game.equipment["tool"] == "Item_FieldScanner" else 1.0
                        Game.add_observation(echo.def["id"], 5.0 * delta * mult)
                        return
        if _observed:
                _observed.tracked = false
                _observed = null


func observed_echo() -> Echo:
        return _observed


# ------------------------------------------------------------------ build --
func _toggle_build_mode() -> void:
        _build_mode = not _build_mode
        if _build_mode:
                _build_def = Data.buildings.get("Building_Foundation", {})
                _build_rot = 0.0
                _make_ghost()
                Game.toast.emit("Build mode — [B] exit · [/] next piece · [,][.] rotate · [E] place", Color(0.9, 0.95, 1.0))
        else:
                _clear_ghost()
                Game.toast.emit("Build mode off.", Color(0.9, 0.9, 0.9))


func in_build_mode() -> bool:
        return _build_mode


func _make_ghost() -> void:
        _clear_ghost()
        _build_ghost = MeshInstance3D.new()
        var box := BoxMesh.new()
        box.size = Vector3(4, 0.35, 4)
        _build_ghost.mesh = box
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.5, 0.9, 1.0, 0.4)
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.emission_enabled = true
        mat.emission = Color(0.3, 0.8, 1.0)
        mat.emission_energy_multiplier = 0.6
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _build_ghost.material_override = mat
        add_child(_build_ghost)


func _build_update(_delta: float) -> void:
        if not _build_mode or _build_ghost == null:
                return
        if Input.is_key_label_pressed(KEY_SLASH):
                _cycle_building()
        if Input.is_action_just_pressed("rotate_left"):
                _build_rot += 15.0
        if Input.is_action_just_pressed("rotate_right"):
                _build_rot -= 15.0
        var facing := -camera.global_basis.z
        facing.y = 0.0
        facing = facing.normalized()
        var pos := global_position + facing * 4.0
        var world := get_tree().get_first_node_in_group("world")
        var ground_y: float = world.tile_height(pos.x, pos.z) if world and world.has_method("tile_height") else pos.y
        _build_ghost.global_position = Vector3(pos.x, ground_y, pos.z)
        _build_ghost.rotation_degrees = Vector3(0, _build_rot, 0)


func _cycle_building() -> void:
        var ids := Data.buildings.keys()
        ids.sort()
        var idx := ids.find(_build_def.get("id", ""))
        idx = (idx + 1) % ids.size()
        _build_def = Data.buildings[ids[idx]]
        Game.toast.emit("Selected: %s" % _build_def.get("name", ""), Color(0.9, 0.95, 1.0))


func _clear_ghost() -> void:
        if _build_ghost:
                _build_ghost.queue_free()
                _build_ghost = null


func _place_building() -> void:
        if _build_def.is_empty():
                return
        var tech: String = _build_def.get("tech", "")
        if tech != "" and tech != null and not Game.unlocked_tech.has(tech):
                Game.toast.emit("Requires research: %s" % Data.techs.get(tech, {}).get("name", tech), Color(1.0, 0.7, 0.5))
                return
        for cost in _build_def.get("cost", []):
                if Game.count_item(cost["item"]) < cost["qty"]:
                        Game.toast.emit("Not enough %s." % Data.item_name(cost["item"]), Color(1.0, 0.7, 0.5))
                        return
        for cost in _build_def.get("cost", []):
                Game.remove_item(cost["item"], cost["qty"])
        var world := get_tree().get_first_node_in_group("world")
        if world:
                var piece = load("res://scripts/systems/building_piece.gd").new(_build_def)
                var pos := _build_ghost.global_position if _build_ghost else global_position
                piece.position = pos
                piece.rotation_degrees.y = _build_rot
                world.buildings_root.add_child(piece)
                Game.building_placed.emit(_build_def["id"])
                Game.notify_event("PlaceBuilding", _build_def["id"])
                Game.toast.emit("Built %s" % _build_def.get("name", ""), Color(0.7, 1.0, 0.8))


# ------------------------------------------------------------------ misc ---
func respawn_at_camp() -> void:
        var world := get_tree().get_first_node_in_group("world")
        if world and world.get("camp_pos") != null:
                global_position = world.camp_pos + Vector3(0, 1.0, 2.0)
        velocity = Vector3.ZERO


func _zone_tracking() -> void:
        var world := get_tree().get_first_node_in_group("world")
        if world and world.has_method("zone_at"):
                Game.notify_zone(world.zone_at(global_position.x, global_position.z))


func _animate(delta: float) -> void:
        if model_root == null:
                return
        # face movement / camera direction
        var facing := -camera.global_basis.z
        facing.y = 0.0
        if facing.length() > 0.01:
                facing = facing.normalized()
                var move := Vector3(velocity.x, 0, velocity.z)
                var look_dir := move if move.length() > 0.5 else facing
                var target_yaw := atan2(look_dir.x, look_dir.z) + PI
                model_root.rotation.y = lerp_angle(model_root.rotation.y, target_yaw, delta * 10.0)
        _play_anim("Run" if velocity.length() > 5.0 else "Walk" if velocity.length() > 0.5 else "Idle")
        # footsteps
        if is_on_floor() and velocity.length() > 1.0:
                _footstep_timer -= delta * velocity.length()
                if _footstep_timer <= 0.0:
                        _footstep_timer = 3.2
                        _play_sfx("A_Footstep_Grass", -18.0)


func _play_anim(kind: String) -> void:
        if anim == null:
                return
        var n := "AM_Survivor_%s" % kind
        if anim.has_animation(n):
                if anim.current_animation != n:
                        anim.play(n)


func _on_screen_requested(screen: String) -> void:
        if screen == "pause":
                Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED else Input.MOUSE_MODE_CAPTURED
