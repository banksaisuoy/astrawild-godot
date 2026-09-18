class_name UtilityDrone
extends Node3D
## Utility Drone (H key) — hover-follow companion (v1.0.4 field automation).
## - auto-scan: journal observation pulse (8% / 4 s, 18 m)
## - auto-harvest: resource nodes (14 m / 6 s) bypassing the scanner gate
## - 600 s battery, auto-recall refunds the item

const BATTERY_MAX := 600.0
const SCAN_INTERVAL := 4.0
const SCAN_RADIUS := 18.0
const SCAN_PROGRESS := 0.08
const HARVEST_INTERVAL := 6.0
const HARVEST_RADIUS := 14.0
const HOVER_HEIGHT := 3.2

var battery := BATTERY_MAX
var _player: Node3D
var _scan_timer := 0.0
var _harvest_timer := 0.0
var _label: Label3D
var _ring: MeshInstance3D


func setup(p_player: Node3D) -> void:
        _player = p_player


func _ready() -> void:
        add_to_group("drone")
        global_position = _player.global_position + Vector3(0.0, HOVER_HEIGHT, -1.6) if _player else Vector3.ZERO

        # body: glowing sphere + halo ring + light
        var body := MeshInstance3D.new()
        var sph := SphereMesh.new()
        sph.radius = 0.35
        sph.height = 0.7
        body.mesh = sph
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.55, 0.85, 1.0)
        mat.emission_enabled = true
        mat.emission = Color(0.45, 0.8, 1.0)
        mat.emission_energy_multiplier = 2.4
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        body.material_override = mat
        add_child(body)

        _ring = MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 0.55
        torus.outer_radius = 0.72
        _ring.mesh = torus
        var rmat := StandardMaterial3D.new()
        rmat.albedo_color = Color(0.7, 0.95, 1.0)
        rmat.emission_enabled = true
        rmat.emission = Color(0.5, 0.85, 1.0)
        rmat.emission_energy_multiplier = 1.6
        rmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        _ring.material_override = rmat
        _ring.position = Vector3(0, -0.1, 0)
        add_child(_ring)

        var light := OmniLight3D.new()
        light.light_color = Color(0.6, 0.9, 1.0)
        light.light_energy = 1.4
        light.omni_range = 6.0
        add_child(light)

        _label = Label3D.new()
        _label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        _label.no_depth_test = true
        _label.position = Vector3(0, 0.9, 0)
        _label.font_size = 34
        _label.outline_size = 7
        _label.modulate = Color(0.75, 0.92, 1.0)
        add_child(_label)
        _update_label()


func _process(delta: float) -> void:
        battery -= delta
        if battery <= 0.0:
                Game.toast.emit("Utility Drone battery depleted — recalled, drone refunded.", Color(1.0, 0.8, 0.55))
                Game.add_item("Item_UtilityDrone", 1)
                queue_free()
                return
        # hover-follow: orbit offset behind the player
        if _player and is_instance_valid(_player):
                var target := _player.global_position + Vector3(1.4, HOVER_HEIGHT, -1.6)
                global_position = global_position.lerp(target, clampf(delta * 2.4, 0.0, 1.0))
        if _ring:
                _ring.rotation.y += delta * 2.2
        _scan_timer -= delta
        if _scan_timer <= 0.0:
                _scan_timer = SCAN_INTERVAL
                _scan_pulse()
        _harvest_timer -= delta
        if _harvest_timer <= 0.0:
                _harvest_timer = HARVEST_INTERVAL
                _harvest_pulse()
        _update_label()


func _scan_pulse() -> void:
        # observation progress for every un-journaled creature in radius
        var scanned := 0
        for c in get_tree().get_nodes_in_group("creatures"):
                if not (c is Node3D) or c.captured or c.is_defeated():
                        continue
                if global_position.distance_to(c.global_position) <= SCAN_RADIUS:
                        Game.add_observation(str(c.def.get("id", "")), SCAN_PROGRESS)
                        scanned += 1
        if scanned > 0:
                Sfx.play("scan_ping", -18.0)


func _harvest_pulse() -> void:
        # nearest harvestable node in radius — the drone's own scanner
        # reveals hidden nodes, bypassing the player's Field Scanner gate
        var world := get_tree().get_first_node_in_group("world")
        if world == null:
                return
        var nodes_root: Node = world.get("nodes_root")
        if nodes_root == null:
                return
        var best: Node3D = null
        var best_d := HARVEST_RADIUS
        for c in nodes_root.get_children():
                if c is Node3D and c.has_method("drone_harvest"):
                        var d: float = global_position.distance_to(c.global_position)
                        if d < best_d:
                                best_d = d
                                best = c
        if best:
                best.drone_harvest()


func recall() -> void:
        Game.add_item("Item_UtilityDrone", 1)
        Game.toast.emit("Utility Drone recalled — item refunded.", Color(0.8, 0.95, 1.0))
        queue_free()


func _update_label() -> void:
        if _label:
                _label.text = "DRONE · %d%%" % int(ceilf(battery / BATTERY_MAX * 100.0))
