class_name Pedestrians
extends Node3D
## Pedestrian NPCs strolling along both sides of the road.
##
## Purely visual, like the traffic: each walker follows the road curve on a
## sidewalk offset, legs and arms swinging with a walk cycle and a slight bob.
## They wrap at the ends of the road, so the roadside never empties.

@export var pedestrian_count := 26
@export var road_path: NodePath
@export var sidewalk_offset_min := 9.6
@export var sidewalk_offset_max := 13.5
@export var walk_speed_min := 0.7
@export var walk_speed_max := 1.7
@export var seed_value := 9021

var _curve: Curve3D
var _length := 0.0

var _road_node: Node3D
var _crossing_distances: Array[float] = []
var _home_crossings: Array[float] = []
var _cross_states: Array[int] = []
var _cross_targets: Array[float] = []

var _bodies: Array[Node3D] = []
var _distances: Array[float] = []
var _speeds: Array[float] = []
var _directions: Array[float] = []
var _laterals: Array[float] = []
var _phases: Array[float] = []
var _left_legs: Array[Node3D] = []
var _right_legs: Array[Node3D] = []
var _left_arms: Array[Node3D] = []
var _right_arms: Array[Node3D] = []

const COAT_COLORS := [
	Color(0.55, 0.16, 0.14), Color(0.14, 0.28, 0.55), Color(0.85, 0.6, 0.15),
	Color(0.16, 0.45, 0.3), Color(0.75, 0.75, 0.78), Color(0.4, 0.2, 0.5),
	Color(0.9, 0.45, 0.2), Color(0.2, 0.2, 0.24),
]


func _ready() -> void:
	var road := get_node_or_null(road_path) as Node3D

	if road == null or not ("curve" in road):
		push_warning("Pedestrians: road_path must point at a RoadBuilder.")
		return

	_road_node = road
	_curve = road.get("curve") as Curve3D

	if road.get("crossing_distances") != null:
		_crossing_distances = road.get("crossing_distances")

	if _curve == null:
		push_warning("Pedestrians: the road has no curve yet.")
		return

	_length = _curve.get_baked_length()

	# More road, more walkers, or the sidewalks empty out on a long map.
	pedestrian_count = clampi(int(round(_length / 30.0)), 26, 64)

	_spawn_all()


func _spawn_all() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.17
	torso_mesh.height = 0.68
	torso_mesh.radial_segments = 8
	torso_mesh.rings = 3

	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.16
	head_mesh.height = 0.32
	head_mesh.radial_segments = 8
	head_mesh.rings = 4

	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.16, 0.58, 0.19)

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.13, 0.52, 0.16)

	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.85, 0.65, 0.5)
	skin.roughness = 0.8

	var trousers := StandardMaterial3D.new()
	trousers.albedo_color = Color(0.12, 0.12, 0.16)
	trousers.roughness = 0.95

	for i in pedestrian_count:
		var body := Node3D.new()
		body.name = "Pedestrian%d" % i
		add_child(body)

		var coat := StandardMaterial3D.new()
		coat.albedo_color = COAT_COLORS[rng.randi_range(0, COAT_COLORS.size() - 1)]
		coat.roughness = 0.85

		var torso := MeshInstance3D.new()
		torso.mesh = torso_mesh
		torso.material_override = coat
		torso.position = Vector3(0.0, 1.12, 0.0)
		body.add_child(torso)

		var head := MeshInstance3D.new()
		head.mesh = head_mesh
		head.material_override = skin
		head.position = Vector3(0.0, 1.6, 0.0)
		body.add_child(head)

		var left_leg := _limb(body, leg_mesh, trousers, Vector3(-0.12, 0.84, 0.0))
		var right_leg := _limb(body, leg_mesh, trousers, Vector3(0.12, 0.84, 0.0))
		var left_arm := _limb(body, arm_mesh, coat, Vector3(-0.3, 1.38, 0.0))
		var right_arm := _limb(body, arm_mesh, coat, Vector3(0.3, 1.38, 0.0))

		_bodies.append(body)
		_left_legs.append(left_leg)
		_right_legs.append(right_leg)
		_left_arms.append(left_arm)
		_right_arms.append(right_arm)

		var direction := 1.0 if i % 2 == 0 else -1.0
		_directions.append(direction)
		_laterals.append((1.0 if i % 4 < 2 else -1.0) * rng.randf_range(sidewalk_offset_min, sidewalk_offset_max))
		_speeds.append(rng.randf_range(walk_speed_min, walk_speed_max))
		_distances.append(fposmod(_length * float(i) / float(maxi(1, pedestrian_count)) + rng.randf_range(-6.0, 6.0), _length))
		_phases.append(rng.randf_range(0.0, TAU))

		# Every fourth walker is a crosser, tied to one signalised crossing.
		var home := -1.0

		if i % 4 == 0 and not _crossing_distances.is_empty():
			home = _crossing_distances[i % _crossing_distances.size()]

		_home_crossings.append(home)
		_cross_states.append(0)
		_cross_targets.append(0.0)

		body.transform = _frame(_distances[i], direction, _laterals[i], 0.0)


## A swinging limb: a pivot at the joint, the mesh hanging below it.
func _limb(parent: Node3D, mesh: Mesh, material: Material, joint: Vector3) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	parent.add_child(pivot)

	var part := MeshInstance3D.new()
	part.mesh = mesh
	part.material_override = material
	part.position = Vector3(0.0, -mesh.get_aabb().size.y * 0.5, 0.0)
	pivot.add_child(part)

	return pivot


func _physics_process(delta: float) -> void:
	if _curve == null:
		return

	for i in _bodies.size():
		if _cross_states[i] == 1:
			# Mid-crossing: shuffle sideways, distance along the road frozen.
			_laterals[i] = move_toward(_laterals[i], _cross_targets[i], 1.5 * delta)
			_phases[i] = wrapf(_phases[i] + _speeds[i] * delta * 3.4, -TAU, TAU)

			if is_equal_approx(_laterals[i], _cross_targets[i]):
				_cross_states[i] = 0

			var cross_swing := sin(_phases[i]) * 0.55
			_left_legs[i].rotation.x = cross_swing
			_right_legs[i].rotation.x = -cross_swing
			_left_arms[i].rotation.x = -cross_swing * 0.7
			_right_arms[i].rotation.x = cross_swing * 0.7
			_bodies[i].transform = _frame(_distances[i], _directions[i], _laterals[i], absf(sin(_phases[i])) * 0.045)
			continue

		# At a red light, a crosser steps onto the zebra.
		if _home_crossings[i] >= 0.0 and absf(_distances[i] - _home_crossings[i]) < 0.9 \
				and _road_node != null and _road_node.has_method("current_signal_phase") \
				and int(_road_node.call("current_signal_phase")) == 2:
			_cross_states[i] = 1
			_cross_targets[i] = -signf(_laterals[i]) * absf(_laterals[i])
			continue

		_distances[i] = fposmod(_distances[i] + _directions[i] * _speeds[i] * delta, _length)
		_phases[i] = wrapf(_phases[i] + _speeds[i] * delta * 3.4, -TAU, TAU)

		var swing := sin(_phases[i]) * 0.55
		_left_legs[i].rotation.x = swing
		_right_legs[i].rotation.x = -swing
		_left_arms[i].rotation.x = -swing * 0.7
		_right_arms[i].rotation.x = swing * 0.7

		var bob := absf(sin(_phases[i])) * 0.045
		_bodies[i].transform = _frame(_distances[i], _directions[i], _laterals[i], bob)


## Position and facing on the road for a walker heading `direction`.
func _frame(distance: float, direction: float, lateral: float, bob: float) -> Transform3D:
	var point := _curve.sample_baked(clampf(distance, 0.0, _length))
	var ahead := _curve.sample_baked(clampf(distance + direction, 0.0, _length))
	var behind := _curve.sample_baked(clampf(distance - direction, 0.0, _length))

	var forward := (ahead - behind).normalized()
	if forward.length() < 0.001:
		forward = Vector3.FORWARD

	var right := forward.cross(Vector3.UP).normalized()
	var basis := Basis(right, Vector3.UP, -forward)

	return Transform3D(basis, point + right * lateral + Vector3.UP * bob)


## Test hook: how many walkers are assigned a crossing to use.
func crossers_assigned() -> int:
	var count := 0

	for home in _home_crossings:
		if home >= 0.0:
			count += 1

	return count


## Test hook: how many walkers are on a zebra right now.
func crossing_now() -> int:
	var count := 0

	for state in _cross_states:
		if state == 1:
			count += 1

	return count


## Test hook: how many walkers are live.
func pedestrian_count_live() -> int:
	return _bodies.size()


## Test hook: world positions of every walker.
func pedestrian_positions() -> Array[Vector3]:
	var out: Array[Vector3] = []

	for body in _bodies:
		out.append(body.global_position)

	return out
