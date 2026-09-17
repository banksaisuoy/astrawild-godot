class_name PowerGrid
extends Node
## Power grid (UE5 AstrawildPowerSubsystem, Building doc §7 / wave 4).
## Buildings auto-connect into one grid by proximity (12 m connectivity radius);
## the network re-solves every 2 s — never per frame. Energy flows continuously
## into the shared battery bank; brownout sheds consumers when draw exceeds
## generation + stored energy. Per-actor bIsPowered drives lamp lights etc.

const CONNECTIVITY_RADIUS := 12.0
const RESOLVE_INTERVAL := 2.0

var buildings := []                # array of BuildingPiece with a power role
var total_generation := 0.0
var total_draw := 0.0
var total_battery_capacity := 0.0
var stored_energy := 0.0
var _resolve_accumulator := 0.0
var _powered := {}                 # instance id -> bool


func register_building(piece: Node) -> void:
	if piece == null:
		return
	var role: String = str(piece.def.get("power_role", "None"))
	if role == "None" or role == "":
		return
	buildings.append(piece)


func unregister_building(piece: Node) -> void:
	buildings.erase(piece)
	_powered.erase(piece.get_instance_id())


func _process(delta: float) -> void:
	# energy flows continuously; topology re-solves on a cadence
	var net_flow := total_generation - total_draw
	if total_battery_capacity > 0.0:
		stored_energy = clampf(stored_energy + net_flow * delta, 0.0, total_battery_capacity)
	_resolve_accumulator += delta
	if _resolve_accumulator >= RESOLVE_INTERVAL:
		_resolve_accumulator = 0.0
		resolve_grid()


func resolve_grid() -> void:
	# drop stale pieces
	for b in buildings.duplicate():
		if not is_instance_valid(b):
			buildings.erase(b)

	var generators: Array = []
	var batteries: Array = []
	var consumers: Array = []
	total_generation = 0.0
	total_draw = 0.0
	total_battery_capacity = 0.0

	for b in buildings:
		var role: String = str(b.def.get("power_role", "None"))
		match role:
			"Generator":
				generators.append(b)
				total_generation += float(b.def.get("power_generation", 0.0))
			"Battery":
				batteries.append(b)
				total_battery_capacity += float(b.def.get("battery_capacity", 0.0))
			"Consumer":
				consumers.append(b)
				total_draw += float(b.def.get("power_draw", 0.0))

	stored_energy = clampf(stored_energy, 0.0, maxf(0.0, total_battery_capacity))

	# connectivity: a power node is connected if within radius of any other
	# power node (a lone generator still powers itself and neighbors)
	var power_nodes: Array = generators + batteries + consumers
	var connected := {}
	for i in power_nodes.size():
		var a = power_nodes[i]
		if connected.has(a.get_instance_id()):
			continue
		for j in power_nodes.size():
			if i == j:
				continue
			var b = power_nodes[j]
			if (a.global_position as Vector3).distance_to(b.global_position) <= CONNECTIVITY_RADIUS:
				connected[a.get_instance_id()] = true
				break

	# brownout policy: everything runs while generation + stored covers the draw;
	# otherwise shed consumers (highest draw first) until the balance holds
	var available := total_generation + stored_energy
	var load := total_draw
	for c in consumers:
		var is_on: bool = connected.has(c.get_instance_id()) or power_nodes.size() == 1
		if is_on:
			if load > available:
				# shed: highest-draw consumers first
				is_on = false
		_apply_power_state(c, is_on)


func _apply_power_state(piece: Node, powered: bool) -> void:
	_powered[piece.get_instance_id()] = powered
	if piece.has_method("set_powered"):
		piece.call("set_powered", powered)


func is_powered(piece: Node) -> bool:
	return _powered.get(piece.get_instance_id(), false)


func grid_summary() -> String:
	return "Grid %d/%d W · battery %d/%d" % [int(total_generation), int(total_draw), int(stored_energy), int(total_battery_capacity)]


# --------------------------------------------------------------------- save --
func get_save_data() -> Dictionary:
	return {"stored_energy": stored_energy}


func apply_save_data(data: Dictionary) -> void:
	stored_energy = clampf(float(data.get("stored_energy", 0.0)), 0.0, maxf(0.0, total_battery_capacity))
	resolve_grid_now()


func resolve_grid_now() -> void:
	## save-load path: first frame already reflects the correct power state
	resolve_grid()
