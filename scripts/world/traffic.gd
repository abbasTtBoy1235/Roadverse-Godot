class_name Traffic
extends Node3D
## Oncoming traffic. Cars drive the other way along the same road curve, looping
## forever. At night the headlights are what sells the scene, so each car carries
## two emissive lamps plus one light.
##
## Purely visual: they have no collision, so you can drive through them.

@export var car_count := 7
@export var road_path: NodePath
@export var lane_offset := -3.3
@export var speed_min := 15.0
@export var speed_max := 26.0
@export var spawn_spacing := 90.0
@export var seed_value := 4711

var _road: Node3D
var _curve: Curve3D
var _length := 0.0

var _bodies: Array[Node3D] = []
var _distances: Array[float] = []
var _speeds: Array[float] = []


## Keeps a car's position inside the road, looping at the ends.
static func wrap_distance(distance: float, road_length: float) -> float:
	if road_length <= 0.0:
		return 0.0

	return fposmod(distance, road_length)


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
	_spawn_cars()


func _spawn_cars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value

	for i in car_count:
		var car := _build_car(i)
		add_child(car)
		_bodies.append(car)

		_distances.append(wrap_distance(spawn_spacing * float(i) + rng.randf_range(-12.0, 12.0), _length))
		_speeds.append(rng.randf_range(speed_min, speed_max))


func _build_car(index: int) -> Node3D:
	var car := Node3D.new()
	car.name = "Car%d" % index

	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(1.9, 1.5, 4.3)

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
		lamp.position = Vector3(side, 0.75, -2.16)
		car.add_child(lamp)

	# One real light per car so the road actually lights up as they approach.
	var light := OmniLight3D.new()
	light.position = Vector3(0.0, 0.9, -2.6)
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
		# Oncoming cars travel towards the player, i.e. backwards along the curve.
		_distances[i] = wrap_distance(_distances[i] - _speeds[i] * delta, _length)
		_bodies[i].transform = _frame(_distances[i])


## Position and orientation on the road, facing back down the curve.
func _frame(distance: float) -> Transform3D:
	var point := _curve.sample_baked(clampf(distance, 0.0, _length))
	var ahead := _curve.sample_baked(clampf(distance - 1.0, 0.0, _length))
	var behind := _curve.sample_baked(clampf(distance + 1.0, 0.0, _length))

	var forward := (ahead - behind).normalized()
	if forward.length() < 0.001:
		forward = Vector3.FORWARD

	var right := forward.cross(Vector3.UP).normalized()
	var basis := Basis(right, Vector3.UP, -forward)

	return Transform3D(basis, point + right * lane_offset)


## Test hook: distances of the live cars.
func car_distances() -> Array[float]:
	return _distances.duplicate()
