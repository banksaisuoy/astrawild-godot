class_name DamageNumbers
extends Object
## PS-1 (Production Systems Plan): floating world-space damage numbers.
## All creature damage funnels through Echo.take_hit(); player damage through
## Game.take_damage(). Both call DamageNumbers.spawn() — Label3D billboards,
## rise + fade tween, colour-coded by hit quality. Zero allocation on miss.

const STYLE := {
        "normal": {"color": Color(1.0, 0.95, 0.78), "size": 26, "outline": Color(0.1, 0.08, 0.05)},
        "weakness": {"color": Color(1.0, 0.72, 0.22), "size": 36, "outline": Color(0.16, 0.09, 0.02)},
        "resist": {"color": Color(0.55, 0.58, 0.62), "size": 19, "outline": Color(0.08, 0.08, 0.09)},
        "crit": {"color": Color(1.0, 0.32, 0.16), "size": 42, "outline": Color(0.2, 0.04, 0.02)},
        "player": {"color": Color(1.0, 0.28, 0.28), "size": 30, "outline": Color(0.18, 0.03, 0.03)},
        "heal": {"color": Color(0.55, 1.0, 0.62), "size": 24, "outline": Color(0.03, 0.14, 0.05)},
}

static func spawn(parent: Node, pos: Vector3, amount: float, kind: String = "normal") -> void:
        ## Spawn one floating number at world `pos`. `parent` should be a live
        ## Node in the world (creatures_root / player parent). Silently
        ## no-ops without a valid parent so headless tests never crash.
        if parent == null or not is_instance_valid(parent) or amount <= 0.5:
                return
        var st: Dictionary = STYLE.get(kind, STYLE["normal"])
        var rng := RandomNumberGenerator.new()
        rng.seed = hash(str(Time.get_ticks_msec()) + str(pos))
        var label := Label3D.new()
        label.text = str(int(round(amount)))
        label.modulate = st["color"]
        label.font_size = int(st["size"])
        label.outline_size = 8
        label.modulate.a = 1.0
        label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
        label.no_depth_test = true
        label.shaded = false
        label.pixel_size = 0.012
        label.fixed_size = false
        # lateral jitter so stacked hits on the same target don't perfectly overlap
        var jitter := Vector3(rng.randf_range(-0.45, 0.45), 0.0, rng.randf_range(-0.2, 0.2))
        label.position = pos + jitter
        label.rotation = Vector3(0.0, 0.0, rng.randf_range(-0.06, 0.06))
        parent.add_child(label)
        # rise + slight scale pop + fade, then free
        var tw := label.create_tween()
        var dx := rng.randf_range(-0.5, 0.5)
        tw.set_parallel(true)
        tw.tween_property(label, "position:y", pos.y + jitter.y + 1.4 + st["size"] * 0.006, 0.85).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
        tw.tween_property(label, "position:x", pos.x + jitter.x + dx, 0.85)
        tw.tween_property(label, "modulate:a", 0.0, 0.35).set_delay(0.5)
        if kind == "crit" or kind == "weakness":
                label.scale = Vector3(0.4, 0.4, 0.4)
                tw.tween_property(label, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
        tw.chain().tween_callback(label.queue_free)
