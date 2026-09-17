class_name WorldNoise
extends RefCounted
## Deterministic FBM value-noise matching the UE5 EvalWorldHeight math.
## Wavelength 512 m, 4 octaves, seed 1337; detail layer 90 m / 2 octaves.

var seed: int = 1337


func _init(p_seed: int = 1337) -> void:
	seed = p_seed & 0x7FFFFFFF


func _hash2(ix: int, iy: int) -> float:
	var h: int = (ix * 374761393 + iy * 668265263) ^ (seed * 1274126177)
	h = (h ^ (h >> 13)) * 1274126177
	h = h ^ (h >> 16)
	return float(h & 0x7FFFFFFF) / float(0x7FFFFFFF) * 2.0 - 1.0


func _value_noise(x: float, y: float, wavelength: float) -> float:
	var fx := x / wavelength
	var fy := y / wavelength
	var ix := int(floor(fx))
	var iy := int(floor(fy))
	var tx := fx - float(ix)
	var ty := fy - float(iy)
	# smoothstep
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a := _hash2(ix, iy)
	var b := _hash2(ix + 1, iy)
	var c := _hash2(ix, iy + 1)
	var d := _hash2(ix + 1, iy + 1)
	return lerp(lerp(a, b, tx), lerp(c, d, tx), ty)


func fbm(x: float, y: float, wavelength: float, octaves: int) -> float:
	var sum := 0.0
	var amp := 1.0
	var norm := 0.0
	var wl := wavelength
	for _i in octaves:
		sum += _value_noise(x, y, wl) * amp
		norm += amp
		amp *= 0.5
		wl *= 0.5
	return sum / norm
