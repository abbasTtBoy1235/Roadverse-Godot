class_name Traffic
extends Node3D
## Two-way traffic that actually behaves: cars in either lane keep their distance
## from the car ahead, brake when they close in, and light their brake lamps
## while doing it. The oncoming lane sweeps past you; the slow lane ahead is
## there to be overtaken.
##
## Purely visual — no collision — so the truck can always be driven through them.

@export var car_count := 7
@export var forward_car_count := 4
@export var road_path: NodePath
@export var lane_offset := 3.3
@export var oncoming_speed_min := 15.0
@export var oncoming_speed_max := 24.0
@export var slow_lane_speed_min := 9.0
@export var slow_lane_speed_max := 14.0
@export var spawn_spacing := 62.0
@export var safe_gap := 26.0
@export var car_length := 4.3
@export var brake_rate := 9.0
@export var throttle_rate := 3.5
@export var seed_value := 4711

var _road: Node3D
var _curve: Curve3D
var _length := 0.0

var _bodies: Array[Node3D] = []
var _distances: Array[float] = []
var _speeds: Array[float] = []
var _cruise: Array[float] = []
var _lanes: Array[float] = []
var _directions: Array[float] = []
var _brake_materials: Array[StandardMaterial3D] = []
var _braking: Array[bool] = []


## Keeps a car's position inside the road, looping at the ends.
static func wrap_distance(distance: float, road_length: float) -> float:
	if road_length <= 0.0:
		return 0.0

	return fposmod(distance, road_length)


## Speed a car settles on when the car ahead is `gap` metres away.
static func follow_speed(cruise: float, gap: float, safe: float) -> float:
	if safe <= 0.0:
		return cruise

	if gap >= safe:
		return cruise

	if gap <= 0.0:
		return 0.0

	return cruise * clampf(gap / safe, 0.0, 1.0) * 0.85


func _ready() -> void:
	_road = get_node_or_null(road_path) as Node3D

	if _road == null or not ("curve" in _road):
		push_warning("Traffic: road_path must point at a RoadBuilder.")
		return

	_curve = _road.get("curve") as Curve3D

	if _curve == null:
		push_warning("Traffic: the road has no curve yet.")
		return

	_length = _curve.get_baked_length()
	_spawn_all()


func _spawn_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# Oncoming lane: drives back down the curve towards the player.
	for i in car_count:
		_add_car(rng, -1.0, lane_offset, rng.randf_range(oncoming_speed_min, oncoming_speed_max))

	# Slow lane going the same way: rolling roadblocks worth overtaking.
	for i in forward_car_count:
		_add_car(rng, 1.0, -lane_offset, rng.randf_range(slow_lane_speed_min, slow_lane_speed_max))


func _add_car(rng: RandomNumberGenerator, direction: float, lane: float, cruise: float) -> void:
	var index := _bodies.size()
	var car := _build_car(index)

	if car == null:
		return

	add_child(car)

	_bodies.append(car)
	_cruise.append(cruise)
	_speeds.append(cruise * 0.9)
	_lanes.append(lane)
	_directions.append(direction)
	_braking.append(false)
	_distances.append(wrap_distance(spawn_spacing * float(index) + rng.randf_range(-8.0, 8.0), _length))


func _build_car(index: int) -> Node3D:
	var car := Node3D.new()
	car.name = "Car%d" % index

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.9, 1.5, car_length)

	var body := MeshInstance3D.new()
	body.mesh = body_mesh
	body.material_override = _body_material()
	body.position = Vector3(0.0, 0.9, 0.0)
	car.add_child(body)

	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.32, 0.22, 0.08)
	var lamp_material := _lamp_material()

	for side: float in [-0.62, 0.62]:
		var lamp := MeshInstance3D.new()
		lamp.mesh = lamp_mesh
		lamp.material_override = lamp_material
		lamp.position = Vector3(side, 0.75, -car_length * 0.5 + 0.05)
		car.add_child(lamp)

	# Rear lamps share one material per car so they can light up when braking.
	var brake_material := StandardMaterial3D.new()
	brake_material.albedo_color = Color(0.4, 0.05, 0.04)
	brake_material.emission_enabled = true
	brake_material.emission = Color(1.0, 0.12, 0.08)
	brake_material.emission_energy_multiplier = 0.35
	_brake_materials.append(brake_material)

	var brake_mesh := BoxMesh.new()
	brake_mesh.size = Vector3(0.3, 0.16, 0.07)

	for side: float in [-0.62, 0.62]:
		var brake := MeshInstance3D.new()
		brake.mesh = brake_mesh
		brake.material_override = brake_material
		brake.position = Vector3(side, 0.72, car_length * 0.5 - 0.02)
		car.add_child(brake)

	# One real light per car so the road actually lights up as they approach.
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.9, -car_length * 0.5 - 0.3)
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 3.0
	light.omni_range = 22.0
	light.shadow_enabled = false
	car.add_child(light)

	return car


func _body_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.09, 0.1, 0.12)
	material.metallic = 0.5
	material.roughness = 0.4
	return material


func _lamp_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(1.0, 0.96, 0.9)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.93, 0.8)
	material.emission_energy_multiplier = 6.0
	return material


func _physics_process(delta: float) -> void:
	if _curve == null:
		return

	for i in _bodies.size():
		var gap := _gap_ahead(i)
		var target := follow_speed(_cruise[i], gap, safe_gap)
		var previous := _speeds[i]

		# Brake hard, accelerate gently — the way traffic actually moves.
		var rate := brake_rate if target < previous else throttle_rate
		_speeds[i] = move_toward(previous, target, rate * delta)

		_braking[i] = _speeds[i] < previous - 0.02
		_brake_materials[i].emission_energy_multiplier = 3.5 if _braking[i] else 0.35

		_distances[i] = wrap_distance(_distances[i] + _directions[i] * _speeds[i] * delta, _length)
		_bodies[i].transform = _frame(_distances[i], _directions[i], _lanes[i])


## Distance to the nearest car ahead in the same lane and direction.
func _gap_ahead(index: int) -> float:
	var best := INF

	for other in _bodies.size():
		if other == index:
			continue

		if _directions[other] != _directions[index] or _lanes[other] != _lanes[index]:
			continue

		var ahead := wrap_distance((_distances[other] - _distances[index]) * _directions[index], _length)
		best = minf(best, ahead - car_length)

	return best if best != INF else 9999.0


## Position and orientation on the road for a given direction and lane.
func _frame(distance: float, direction: float, lane: float) -> Transform3D:
	var point := _curve.sample_baked(clampf(distance, 0.0, _length))
	var ahead := _curve.sample_baked(clampf(distance + direction, 0.0, _length))
	var behind := _curve.sample_baked(clampf(distance - direction, 0.0, _length))

	var forward := (ahead - behind).normalized()
	if forward.length() < 0.001:
		forward = Vector3.FORWARD

	var right := forward.cross(Vector3.UP).normalized()
	var basis := Basis(right, Vector3.UP, -forward)

	return Transform3D(basis, point + right * lane)


## Test hook: distances of the live cars.
func car_distances() -> Array[float]:
	return _distances.duplicate()


## Test hook: current speeds of the live cars, m/s.
func car_speeds() -> Array[float]:
	return _speeds.duplicate()


## Test hook: which cars have their brake lamps on.
func braking_flags() -> Array[bool]:
	return _braking.duplicate()


## Test hook: how many cars drive with the player and how many against.
func direction_counts() -> Dictionary:
	var forward := 0
	var oncoming := 0

	for direction in _directions:
		if direction > 0.0:
			forward += 1
		else:
			oncoming += 1

	return {"forward": forward, "oncoming": oncoming}
