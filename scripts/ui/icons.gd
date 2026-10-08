class_name GameIcons
extends RefCounted
## v1.2 de-jank pass: crisp vector UI icons drawn procedurally in _draw().
## No external assets, style-locked to the flat amber/teal palette, works in
## every renderer including the Web (gl_compatibility) export.

## Factory: returns a Control that draws the named icon.
## Valid names: heart, bolt, meat, drop, paw, sword, shield, gear, book,
## map, flask, backpack, star, coin, eye, check.
static func make(icon_name: String, color: Color, px: int = 18) -> Control:
        var c := IconDraw.new()
        c.icon_name = icon_name
        c.icon_color = color
        c.icon_px = px
        c.custom_minimum_size = Vector2(px, px)
        c.mouse_filter = Control.MOUSE_FILTER_IGNORE
        return c


## Re-theme an existing icon control in place (e.g. check state colors).
static func set_icon(ctrl: Control, icon_name: String, color: Color) -> void:
        if ctrl is IconDraw:
                ctrl.icon_name = icon_name
                ctrl.icon_color = color
                ctrl.queue_redraw()


class IconDraw extends Control:
        var icon_name := "heart"
        var icon_color := Color.WHITE
        var icon_px := 18

        func _draw() -> void:
                var s: float = icon_px
                var col := icon_color
                var dark := icon_color.darkened(0.42)
                var lite := icon_color.lightened(0.35)
                match icon_name:
                        "heart":
                                _poly([[0.50, 0.90], [0.08, 0.44], [0.08, 0.30], [0.18, 0.16], [0.34, 0.12], [0.50, 0.24], [0.66, 0.12], [0.82, 0.16], [0.92, 0.30], [0.92, 0.44]], dark, s, Vector2(0, 0.045))
                                _poly([[0.50, 0.90], [0.08, 0.44], [0.08, 0.30], [0.18, 0.16], [0.34, 0.12], [0.50, 0.24], [0.66, 0.12], [0.82, 0.16], [0.92, 0.30], [0.92, 0.44]], col, s)
                                _circle(0.34, 0.30, 0.075, lite, s)
                        "bolt":
                                _poly([[0.62, 0.02], [0.26, 0.56], [0.46, 0.56], [0.34, 0.98], [0.78, 0.40], [0.55, 0.40], [0.74, 0.02]], dark, s, Vector2(0.035, 0.045))
                                _poly([[0.62, 0.02], [0.26, 0.56], [0.46, 0.56], [0.34, 0.98], [0.78, 0.40], [0.55, 0.40], [0.74, 0.02]], col, s)
                        "meat":
                                # drumstick: bone first, meat blob on top
                                _rect(0.60, 0.60, 0.30, 0.09, lite, s)
                                _circle(0.90, 0.62, 0.075, lite, s)
                                _circle(0.84, 0.72, 0.075, lite, s)
                                _circle(0.42, 0.42, 0.28, dark, s, Vector2(0, 0.05))
                                _circle(0.42, 0.42, 0.28, col, s)
                                _circle(0.36, 0.34, 0.09, lite, s)
                        "drop":
                                _poly([[0.50, 0.04], [0.28, 0.44], [0.72, 0.44]], dark, s, Vector2(0, 0.05))
                                _poly([[0.50, 0.04], [0.28, 0.44], [0.72, 0.44]], col, s)
                                _circle(0.50, 0.62, 0.26, dark, s, Vector2(0, 0.05))
                                _circle(0.50, 0.62, 0.26, col, s)
                                _circle(0.42, 0.62, 0.075, lite, s)
                        "paw":
                                _circle(0.50, 0.68, 0.21, dark, s, Vector2(0, 0.05))
                                _circle(0.50, 0.68, 0.21, col, s)
                                _circle(0.20, 0.40, 0.095, dark, s, Vector2(0, 0.05))
                                _circle(0.20, 0.40, 0.095, col, s)
                                _circle(0.80, 0.40, 0.095, dark, s, Vector2(0, 0.05))
                                _circle(0.80, 0.40, 0.095, col, s)
                                _circle(0.50, 0.28, 0.105, dark, s, Vector2(0, 0.05))
                                _circle(0.50, 0.28, 0.105, col, s)
                                _circle(0.33, 0.62, 0.05, lite, s)
                        "sword":
                                # blade
                                _poly([[0.50, 0.0], [0.41, 0.58], [0.59, 0.58]], lite, s)
                                _poly([[0.50, 0.0], [0.50, 0.58], [0.59, 0.58]], col, s)
                                # guard + grip + pommel
                                _rect(0.24, 0.58, 0.52, 0.09, dark, s)
                                _rect(0.45, 0.67, 0.10, 0.20, dark, s)
                                _circle(0.50, 0.92, 0.075, col, s)
                        "shield":
                                _poly([[0.50, 0.03], [0.93, 0.16], [0.88, 0.56], [0.50, 0.97], [0.12, 0.56], [0.07, 0.16]], dark, s, Vector2(0, 0.05))
                                _poly([[0.50, 0.03], [0.93, 0.16], [0.88, 0.56], [0.50, 0.97], [0.12, 0.56], [0.07, 0.16]], col, s)
                                _poly([[0.50, 0.16], [0.72, 0.24], [0.50, 0.58], [0.28, 0.24]], lite, s)
                        "gear":
                                # rounded teeth ring, then body, then dark hole
                                for i in 8:
                                        var ang: float = TAU * i / 8.0
                                        _circle(0.5 + cos(ang) * 0.30, 0.5 + sin(ang) * 0.30, 0.105, dark, s, Vector2(0, 0.05))
                                        _circle(0.5 + cos(ang) * 0.30, 0.5 + sin(ang) * 0.30, 0.105, col, s)
                                _circle(0.50, 0.50, 0.29, dark, s, Vector2(0, 0.05))
                                _circle(0.50, 0.50, 0.29, col, s)
                                _circle(0.50, 0.50, 0.115, dark, s)
                        "book":
                                _rect(0.10, 0.10, 0.80, 0.80, dark, s)
                                _rect(0.14, 0.14, 0.36, 0.72, col, s)
                                _rect(0.50, 0.14, 0.36, 0.72, lite, s)
                                _rect(0.48, 0.14, 0.04, 0.72, dark, s)
                                _rect(0.20, 0.30, 0.22, 0.045, dark, s)
                                _rect(0.58, 0.30, 0.22, 0.045, dark, s)
                        "map":
                                _poly([[0.04, 0.22], [0.36, 0.06], [0.36, 0.78], [0.04, 0.94]], dark, s, Vector2(0, 0.05))
                                _poly([[0.04, 0.22], [0.36, 0.06], [0.36, 0.78], [0.04, 0.94]], col, s)
                                _poly([[0.36, 0.06], [0.64, 0.22], [0.64, 0.94], [0.36, 0.78]], lite, s)
                                _poly([[0.64, 0.22], [0.96, 0.06], [0.96, 0.78], [0.64, 0.94]], col, s)
                                _circle(0.64, 0.48, 0.075, Color(0.95, 0.35, 0.30), s)
                        "flask":
                                _rect(0.43, 0.04, 0.14, 0.16, dark, s)
                                _poly([[0.30, 0.96], [0.70, 0.96], [0.57, 0.30], [0.43, 0.30]], dark, s, Vector2(0, 0.05))
                                _poly([[0.30, 0.96], [0.70, 0.96], [0.57, 0.30], [0.43, 0.30]], col, s)
                                _poly([[0.37, 0.78], [0.63, 0.78], [0.55, 0.46], [0.45, 0.46]], lite, s)
                                _circle(0.44, 0.64, 0.045, lite, s)
                                _circle(0.56, 0.72, 0.035, lite, s)
                        "backpack":
                                _rect(0.30, 0.10, 0.13, 0.18, dark, s)
                                _rect(0.57, 0.10, 0.13, 0.18, dark, s)
                                _rect(0.16, 0.26, 0.68, 0.66, dark, s, Vector2(0, 0.05))
                                _rect(0.16, 0.26, 0.68, 0.66, col, s)
                                _rect(0.16, 0.26, 0.68, 0.22, dark, s)
                                _rect(0.42, 0.44, 0.16, 0.10, lite, s)
                                _rect(0.24, 0.58, 0.52, 0.05, dark, s)
                        "star":
                                var pts: Array = []
                                for i in 10:
                                        var a: float = -PI / 2.0 + TAU * i / 10.0
                                        var r: float = 0.48 if i % 2 == 0 else 0.20
                                        pts.append([0.5 + cos(a) * r, 0.5 + sin(a) * r])
                                _poly(pts, dark, s, Vector2(0, 0.05))
                                _poly(pts, col, s)
                        "coin":
                                _circle(0.50, 0.50, 0.40, dark, s, Vector2(0, 0.05))
                                _circle(0.50, 0.50, 0.40, col, s)
                                _circle(0.50, 0.50, 0.29, lite, s)
                                _rect(0.46, 0.28, 0.08, 0.44, col, s)
                        "eye":
                                _ellipse(0.50, 0.50, 0.44, 0.26, dark, s, Vector2(0, 0.05))
                                _ellipse(0.50, 0.50, 0.44, 0.26, col, s)
                                _circle(0.50, 0.50, 0.135, dark, s)
                                _circle(0.55, 0.45, 0.04, lite, s)
                        "check":
                                _poly([[0.10, 0.52], [0.22, 0.40], [0.42, 0.60], [0.80, 0.16], [0.92, 0.28], [0.42, 0.84]], col, s)
                        _:
                                _circle(0.5, 0.5, 0.35, col, s)

        func _pts(unit_pts: Array, s: float, off: Vector2) -> PackedVector2Array:
                var out := PackedVector2Array()
                for p in unit_pts:
                        out.append(Vector2(p[0] * s + off.x * s, p[1] * s + off.y * s))
                return out

        func _poly(unit_pts: Array, col: Color, s: float, off: Vector2 = Vector2.ZERO) -> void:
                draw_colored_polygon(_pts(unit_pts, s, off), col)

        func _circle(ux: float, uy: float, ur: float, col: Color, s: float, off: Vector2 = Vector2.ZERO) -> void:
                draw_circle(Vector2(ux * s + off.x * s, uy * s + off.y * s), ur * s, col)

        func _ellipse(ux: float, uy: float, rx: float, ry: float, col: Color, s: float, off: Vector2 = Vector2.ZERO) -> void:
                var pts: Array = []
                for i in 24:
                        var a: float = TAU * i / 24.0
                        pts.append([ux + cos(a) * rx, uy + sin(a) * ry])
                _poly(pts, col, s, off)

        func _rect(ux: float, uy: float, uw: float, uh: float, col: Color, s: float, off: Vector2 = Vector2.ZERO) -> void:
                draw_rect(Rect2(ux * s + off.x * s, uy * s + off.y * s, uw * s, uh * s), col)
