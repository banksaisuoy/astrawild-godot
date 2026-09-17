class_name ZoneTerrain
extends Node3D
## One 800x800 m terrain tile with procedural mesh + trimesh collision.
## Also keeps its height grid for cheap runtime height queries.

const TILE_QUADS := 128          # 6.25 m spacing
const HALF_SIZE := 400.0

var zone: Dictionary = {}
var noise: WorldNoise = null
var grid_size := TILE_QUADS + 1  # vertices per side
var heights := PackedFloat32Array()  # (z*grid + x)
var tile_origin := Vector3.ZERO   # world position of vertex (0,0) (min corner)
var step := 0.0


static func zone_weights(x: float, z: float) -> Dictionary:
	## Partition-of-unity weights over the 4x3 zone grid (60 m blend ring).
	var weights := {}
	var total := 0.0
	for zone in Data.zones:
		var cx: float = zone["center"][0]
		var cz: float = zone["center"][1]
		var d := maxf(absf(x - cx), absf(z - cz))
		var w: float = clampf((HALF_SIZE + 60.0 - d) / 60.0, 0.0, 1.0)
		if w > 0.0:
			weights[zone["id"]] = w
			total += w
	if total <= 0.0:
		return {}
	for k in weights:
		weights[k] /= total
	return weights


static func eval_world_height(x: float, z: float, noise: WorldNoise) -> float:
	var weights := zone_weights(x, z)
	var base := noise.fbm(x, z, 512.0, 4)
	var height := 0.0
	for zid in weights:
		var zone := Data.zone(zid)
		var ridge: float = zone.get("ridge", 0.0)
		var shaped := lerpf(base, 1.0 - 2.0 * absf(base), ridge)
		height += weights[zid] * (zone.get("base", 0.0) + zone.get("amp", 0.0) * shaped)
	height += 0.7 * noise.fbm(x, z, 90.0, 2)
	return height


func _init(p_zone: Dictionary, p_noise: WorldNoise) -> void:
	zone = p_zone
	noise = p_noise


func build() -> void:
	var cx: float = zone["center"][0]
	var cz: float = zone["center"][1]
	tile_origin = Vector3(cx - HALF_SIZE, 0.0, cz - HALF_SIZE)
	step = (HALF_SIZE * 2.0) / float(TILE_QUADS)

	heights.resize(grid_size * grid_size)
	for iz in grid_size:
		var wz: float = tile_origin.z + step * float(iz)
		for ix in grid_size:
			var wx: float = tile_origin.x + step * float(ix)
			heights[iz * grid_size + ix] = eval_world_height(wx, wz, noise)

	_build_mesh()
	_build_collision()


func height_at(wx: float, wz: float) -> float:
	var lx: float = (wx - tile_origin.x) / step
	var lz: float = (wz - tile_origin.z) / step
	lx = clampf(lx, 0.0, float(grid_size - 1))
	lz = clampf(lz, 0.0, float(grid_size - 1))
	var x0 := int(lx)
	var z0 := int(lz)
	var x1 := mini(x0 + 1, grid_size - 1)
	var z1 := mini(z0 + 1, grid_size - 1)
	var fx: float = lx - float(x0)
	var fz: float = lz - float(z0)
	var h00: float = heights[z0 * grid_size + x0]
	var h10: float = heights[z0 * grid_size + x1]
	var h01: float = heights[z1 * grid_size + x0]
	var h11: float = heights[z1 * grid_size + x1]
	return lerpf(lerpf(h00, h10, fx), lerpf(h01, h11, fx), fz)


func slope_at(wx: float, wz: float) -> float:
	var d := step
	var hx: float = height_at(wx + d, wz) - height_at(wx - d, wz)
	var hz: float = height_at(wx, wz + d) - height_at(wx, wz - d)
	return Vector2(hx / (2.0 * d), hz / (2.0 * d)).length()


# ------------------------------------------------------------------- mesh --
func _build_mesh() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var gt: Color = Color(zone["ground"][0], zone["ground"][1], zone["ground"][2])
	var rock := Color(0.42, 0.38, 0.34)
	var snow := Color(0.92, 0.95, 1.0)
	var char_col := Color(0.16, 0.13, 0.12)
	var muck := Color(0.18, 0.24, 0.16)

	for iz in grid_size:
		for ix in grid_size:
			var i := iz * grid_size + ix
			var h: float = heights[i]
			var v := Vector3(tile_origin.x + step * ix, h, tile_origin.z + step * iz)
			var col := gt
			# slope → rock
			var slope := _grid_slope(ix, iz)
			var rock_mix: float = clampf(slope * 2.2 - 0.55, 0.0, 1.0)
			col = col.lerp(rock, rock_mix * 0.85)
			# altitude rules
			if h > 18.0:
				col = col.lerp(snow, clampf((h - 18.0) / 8.0, 0.0, 1.0))
			if h > 24.0:
				col = col.lerp(char_col, clampf((h - 24.0) / 10.0, 0.0, 1.0) * 0.8)
			if h < 0.0 and zone.get("dressing", {}).get("muck", false):
				col = col.lerp(muck, clampf(-h / 1.5, 0.0, 1.0))
			if h < -3.0:
				col = col.lerp(Color(0.55, 0.5, 0.42), clampf((-3.0 - h) / 6.0, 0.0, 1.0))
			st.set_color(col)
			st.add_vertex(v)

	for iz in TILE_QUADS:
		for ix in TILE_QUADS:
			var a := iz * grid_size + ix
			var b := a + 1
			var c := a + grid_size
			var d := c + 1
			st.add_index(a); st.add_index(b); st.add_index(c)
			st.add_index(b); st.add_index(d); st.add_index(c)

	st.generate_normals()
	var mesh := st.commit()
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.cast_shadow = 0
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	mat.metallic = 0.0
	mi.material_override = mat
	add_child(mi)


func _grid_slope(ix: int, iz: int) -> float:
	var x0 := maxi(ix - 1, 0)
	var x1 := mini(ix + 1, grid_size - 1)
	var z0 := maxi(iz - 1, 0)
	var z1 := mini(iz + 1, grid_size - 1)
	var hx: float = heights[iz * grid_size + x1] - heights[iz * grid_size + x0]
	var hz: float = heights[z1 * grid_size + ix] - heights[z0 * grid_size + ix]
	var dx: float = step * float(x1 - x0)
	var dz: float = step * float(z1 - z0)
	return Vector2(hx / maxf(dx, 0.01), hz / maxf(dz, 0.01)).length()


# -------------------------------------------------------------- collision --
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := HeightMapShape3D.new()
	shape.map_width = grid_size
	shape.map_depth = grid_size
	shape.map_data = heights
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3(step, 1.0, step)
	body.add_child(cs)
	body.position = Vector3(zone["center"][0], 0.0, zone["center"][1])
	add_child(body)
