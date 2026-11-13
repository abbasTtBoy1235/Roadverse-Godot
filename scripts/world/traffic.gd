class_name Traffic
extends Node3D
## Two-way traffic that actually behaves: cars in either lane keep their distance
## from the car ahead, brake when they close in, and light their brake lamps
## while doing it. The oncoming lane sweeps past you; the slow lane ahead is
## there to be overtaken.
##
## Every car is an AnimatableBody3D with a real collision box, so the truck
## cannot be driven through them: you brake, overtake, or hit them.

@export var car_count := 10
@export var forward_car_count := 7
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
var _lengths: Array[float] = []
var _wheel_pivots: Array = []
var _headlights: Array[OmniLight3D] = []
var _lamp_materials: Array[StandardMaterial3D] = []
var _rounded_bodies := 0

const BODY_COLORS := [
	Color(0.55, 0.14, 0.12), Color(0.13, 0.3, 0.6), Color(0.8, 0.82, 0.85),
	Color(0.08, 0.09, 0.11), Color(0.9, 0.88, 0.84), Color(0.85, 0.5, 0.12),
	Color(0.12, 0.45, 0.45), Color(0.45, 0.16, 0.4),
]


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
	add_to_group("rv_time_aware")
	_road = get_node_or_null(road_path) as Node3D

	if _road == null or not ("curve" in _road):
		push_warning("Traffic: road_path must point at a RoadBuilder.")
		return

	_curve = _road.get("curve") as Curve3D

	if _curve == null:
		push_warning("Traffic: the road has no curve yet.")
		return

	_length = _curve.get_baked_length()

	# Density follows the map: the counts that filled 640 m would leave a
	# 2 km road feeling empty. The exports are rewritten with the real
	# counts, so tests and hooks keep reading the truth.
	car_count = clampi(int(round(_length / 62.0)), 10, 30)
	forward_car_count = clampi(int(round(_length / 95.0)), 7, 20)

	_spawn_all()


func _spawn_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	# Lanes are road-space lateral offsets (see _frame): positive is the
	# player's side of the road. Right-hand traffic, so same-direction cars
	# keep right and oncoming cars keep to the far side. Both directions used
	# to end up on the same (left) side because the offset was applied in
	# travel space, which flips sign for oncoming cars.
	# Oncoming lane: drives back down the curve towards the player.
	for i in car_count:
		_add_car(rng, -1.0, -lane_offset, rng.randf_range(oncoming_speed_min, oncoming_speed_max))

	# Slow lane going the same way: rolling roadblocks worth overtaking.
	for i in forward_car_count:
		_add_car(rng, 1.0, lane_offset, rng.randf_range(slow_lane_speed_min, slow_lane_speed_max))


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


func _build_car(index: int) -> AnimatableBody3D:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + index * 131

	# Vehicle variety: mostly cars, every fourth a taller van or box truck.
	var is_van := index % 4 == 3
	var vehicle_length := 5.4 if is_van else rng.randf_range(4.0, 4.7)
	var body_height := 1.95 if is_van else 1.05
	_lengths.append(vehicle_length)

	var car := AnimatableBody3D.new()
	car.name = "Car%d" % index

	# A solid box over the whole body, so the truck bounces off instead of
	# passing through. Kinematic, so the car itself never gets pushed around.
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.9, body_height + 0.9, vehicle_length)

	var collision := CollisionShape3D.new()
	collision.name = "CollisionShape3D"
	collision.shape = shape
	collision.position = Vector3(0.0, (body_height + 0.9) * 0.5 - 0.05, 0.0)
	car.add_child(collision)

	var paint := StandardMaterial3D.new()
	paint.albedo_color = BODY_COLORS[rng.randi_range(0, BODY_COLORS.size() - 1)]
	paint.metallic = 0.55
	paint.roughness = 0.38
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED

	var body := MeshInstance3D.new()
	body.material_override = paint

	if is_van:
		# Vans really are boxes; they keep theirs.
		var body_mesh := BoxMesh.new()
		body_mesh.size = Vector3(1.9, body_height, vehicle_length)
		body.mesh = body_mesh
		body.position = Vector3(0.0, 0.42 + body_height * 0.5, 0.0)
	else:
		# Cars get an extruded side profile: sloped nose, raked windscreen,
		# a roofline and a tail. Silhouette does what paint cannot.
		body.mesh = _car_body_mesh(vehicle_length)
		_rounded_bodies += 1

	car.add_child(body)

	if not is_van:
		var glass := StandardMaterial3D.new()
		glass.albedo_color = Color(0.1, 0.14, 0.19)
		glass.metallic = 0.7
		glass.roughness = 0.12

		var cabin_mesh := BoxMesh.new()
		cabin_mesh.size = Vector3(1.66, 0.34, vehicle_length * 0.33)

		var cabin := MeshInstance3D.new()
		cabin.mesh = cabin_mesh
		cabin.material_override = glass
		cabin.position = Vector3(0.0, 1.21, -0.05)
		car.add_child(cabin)

	# Wheels on pivots so they can roll with the car's speed.
	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color(0.03, 0.03, 0.035)
	tyre.roughness = 1.0

	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.34
	wheel_mesh.bottom_radius = 0.34
	wheel_mesh.height = 0.24
	wheel_mesh.radial_segments = 10

	var pivots: Array[Node3D] = []

	for side: float in [-0.85, 0.85]:
		for end: float in [-vehicle_length * 0.32, vehicle_length * 0.32]:
			var pivot := Node3D.new()
			pivot.position = Vector3(side, 0.34, end)
			car.add_child(pivot)

			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh
			wheel.material_override = tyre
			wheel.rotation = Vector3(0.0, 0.0, PI * 0.5)
			pivot.add_child(wheel)
			pivots.append(pivot)

	_wheel_pivots.append(pivots)

	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.32, 0.22, 0.08)
	var lamp_material := _lamp_material()
	_lamp_materials.append(lamp_material)

	for side: float in [-0.62, 0.62]:
		var lamp := MeshInstance3D.new()
		lamp.mesh = lamp_mesh
		lamp.material_override = lamp_material
		lamp.position = Vector3(side, 0.75, -vehicle_length * 0.5 + 0.05)
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
		brake.position = Vector3(side, 0.72, vehicle_length * 0.5 - 0.02)
		car.add_child(brake)

	# One real light per car so the road actually lights up as they approach.
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.9, -vehicle_length * 0.5 - 0.3)
	light.light_color = Color(1.0, 0.95, 0.85)
	light.light_energy = 3.0
	light.omni_range = 22.0
	light.shadow_enabled = false
	car.add_child(light)
	_headlights.append(light)

	return car


## A car body as an extruded side profile (Vector2 = forward, height).
## The outline loop becomes the skin; the two ends are fanned shut.
func _car_body_mesh(vehicle_length: float) -> ArrayMesh:
	var scale_z := vehicle_length / 4.5
	var half := 0.92
	var profile: Array[Vector2] = [
		Vector2(-2.25, 0.38), Vector2(-2.3, 0.72), Vector2(-1.55, 0.9),
		Vector2(-0.75, 1.36), Vector2(0.55, 1.4), Vector2(1.25, 1.0),
		Vector2(2.2, 0.96), Vector2(2.25, 0.4),
	]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var count := profile.size()

	var point := func(p: Vector2, x: float) -> Vector3:
		return Vector3(x, p.y, p.x * scale_z)

	# Skin: one quad per profile edge.
	for i in count:
		var a := profile[i]
		var b := profile[(i + 1) % count]

		st.add_vertex(point.call(a, -half))
		st.add_vertex(point.call(b, -half))
		st.add_vertex(point.call(b, half))

		st.add_vertex(point.call(a, -half))
		st.add_vertex(point.call(b, half))
		st.add_vertex(point.call(a, half))

	# Side caps: fans around the profile centroid.
	var centroid := Vector2.ZERO

	for p in profile:
		centroid += p

	centroid /= float(count)

	for i in count:
		var a := profile[i]
		var b := profile[(i + 1) % count]

		st.add_vertex(point.call(centroid, half))
		st.add_vertex(point.call(a, half))
		st.add_vertex(point.call(b, half))

		st.add_vertex(point.call(centroid, -half))
		st.add_vertex(point.call(b, -half))
		st.add_vertex(point.call(a, -half))

	st.generate_normals()
	return st.commit()


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

		for pivot in _wheel_pivots[i]:
			(pivot as Node3D).rotation.x -= _speeds[i] * delta / 0.34


## Distance to the nearest car ahead in the same lane and direction.
func _gap_ahead(index: int) -> float:
	var best := INF

	for other in _bodies.size():
		if other == index:
			continue

		if _directions[other] != _directions[index] or _lanes[other] != _lanes[index]:
			continue

		var ahead := wrap_distance((_distances[other] - _distances[index]) * _directions[index], _length)
		var nose_to_tail := (_lengths[other] + _lengths[index]) * 0.5 if other < _lengths.size() and index < _lengths.size() else car_length
		best = minf(best, ahead - nose_to_tail)

	return best if best != INF else 9999.0


## Position and orientation on the road for a given direction and lane.
## The lane offset is applied in *road* space (the road's own right-hand
## side), not in travel space: travel space flips for oncoming cars, which
## is how both directions used to end up in the same lane.
func _frame(distance: float, direction: float, lane: float) -> Transform3D:
	var point := _curve.sample_baked(clampf(distance, 0.0, _length))
	var ahead := _curve.sample_baked(clampf(distance + direction, 0.0, _length))
	var behind := _curve.sample_baked(clampf(distance - direction, 0.0, _length))

	var forward := (ahead - behind).normalized()
	if forward.length() < 0.001:
		forward = Vector3.FORWARD

	var travel_right := forward.cross(Vector3.UP).normalized()
	var basis := Basis(travel_right, Vector3.UP, -forward)

	var road_forward := (_curve.sample_baked(clampf(distance + 1.0, 0.0, _length))
		- _curve.sample_baked(clampf(distance - 1.0, 0.0, _length))).normalized()
	var road_right := road_forward.cross(Vector3.UP).normalized()

	return Transform3D(basis, point + road_right * lane)


## TimeOfDay calls this: headlights only earn their keep after dark.
func apply_time_of_day(night_factor: float) -> void:
	var level := clampf(night_factor, 0.0, 1.0)

	for light in _headlights:
		light.visible = level > 0.04
		light.light_energy = 3.0 * level

	for material in _lamp_materials:
		material.emission_energy_multiplier = lerpf(0.15, 6.0, level)


## Test hook: how many cars got the rounded profile body (vans stay boxy).
func rounded_car_count() -> int:
	return _rounded_bodies


## Test hook: road-space lane offset of every car, in spawn order
## (oncoming cars first, then same-direction cars).
func car_lane_offsets() -> Array[float]:
	return _lanes.duplicate()


## Test hook: how many cars carry a working collision body.
func car_collision_count() -> int:
	var count := 0

	for body in _bodies:
		if body is AnimatableBody3D and body.get_node_or_null("CollisionShape3D") != null:
			count += 1

	return count


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
