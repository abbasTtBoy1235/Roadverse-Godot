extends Node3D
## Integration test: drives the real scene and checks that the wheels turn, the
## engine synth follows the revs, and the traffic moves along the road.
##
##   godot --headless --path . res://tests/drive_state.tscn

const DRIVE_SECONDS := 4.0
const STEER_SECONDS := 1.5
const RAIN_SECONDS := 2.0

var _game: Node3D
var _truck: TruckController
var _wheels: WheelVisuals
var _audio: EngineAudio
var _traffic: Node3D
var _weather: Node3D
var _noise: Node
var _road: Node3D

var _elapsed := 0.0
var _phase := 0
var _spin_before := 0.0
var _traffic_before: Array[float] = []
var _failures := 0


func _ready() -> void:
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_game)

	_truck = _game.get_node("Truck") as TruckController
	_wheels = _truck.get_node("WheelVisuals") as WheelVisuals
	_audio = _truck.get_node("EngineAudio") as EngineAudio
	_traffic = _game.get_node("Traffic") as Node3D
	_weather = _game.get_node("Weather") as Node3D
	_noise = _truck.get_node("RoadNoise") as Node
	_road = _game.get_node("Road") as Node3D

	_check(_truck != null, "truck found")
	_check(_wheels != null, "wheel visuals found")
	_check(_audio != null, "engine audio found")
	_check(_traffic != null, "traffic found")
	_check(_weather != null, "weather found")
	_check(_noise != null, "road noise found")
	_check(_road != null, "road found")

	if _wheels != null:
		_check(_wheels.wheel_count() == 4, "all four wheels are driven visually (%d)" % _wheels.wheel_count())
		_spin_before = _wheels.spin_angle(0)

	_traffic_before = _traffic.call("car_distances")
	_check(_traffic_before.size() == int(_traffic.get("car_count")),
		"traffic spawned %d cars" % _traffic_before.size())

	Input.action_press("rv_throttle", 1.0)


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if _phase == 0 and _elapsed >= DRIVE_SECONDS:
		_phase = 1
		_check_drive()
		Input.action_press("rv_steer_right", 1.0)

	elif _phase == 1 and _elapsed >= DRIVE_SECONDS + STEER_SECONDS:
		_phase = 2
		_check_steering()
		Input.action_release("rv_steer_right")
		_check_barrier()
		_weather.call("set_raining", true)

	elif _phase == 2 and _elapsed >= DRIVE_SECONDS + STEER_SECONDS + RAIN_SECONDS:
		_phase = 3
		_check_weather()
		Input.action_release("rv_throttle")
		_finish()


func _check_drive() -> void:
	if _wheels != null:
		_check(absf(_wheels.spin_angle(0) - _spin_before) > 0.5, "wheels spin while driving")

	if _audio != null:
		var frequency := _audio.current_frequency()
		_check(frequency > 30.0, "engine synth runs at a believable pitch (%.0f Hz)" % frequency)

	if _traffic != null:
		var after: Array[float] = _traffic.call("car_distances")
		var moved := 0
		for i in mini(after.size(), _traffic_before.size()):
			if absf(after[i] - _traffic_before[i]) > 0.5:
				moved += 1
		_check(moved > 0, "traffic cars move along the road (%d of %d moved)" % [moved, after.size()])

	var speed := _truck.speed_kph()
	_check(speed > 8.0, "truck is actually moving (%.0f km/h)" % speed)

	if _noise != null:
		_check(_noise.call("tyre_level") > 0.1, "tyre noise follows the speed (%.2f)" % _noise.call("tyre_level"))
		_check(_noise.call("wind_level") >= 0.0, "wind level is sane (%.2f)" % _noise.call("wind_level"))


func _check_steering() -> void:
	var wheel := _truck.get_node_or_null("WheelFL") as VehicleWheel3D
	_check(wheel != null, "front wheel exists")

	if wheel == null:
		return

	var spin := wheel.get_node_or_null("Spin") as Node3D
	_check(spin != null, "front wheel has a spin pivot")

	if spin == null:
		return

	_check(absf(spin.rotation.y) > 0.01, "front wheels visually steer (%.2f rad)" % spin.rotation.y)
	_check(spin.rotation.y < 0.0, "steering right turns the wheels right (negative yaw)")


## Fires a ray from the truck straight at the nearest piece of guardrail: it must
## be a real collision body, not just a mesh.
func _check_barrier() -> void:
	var body := _road.get_node_or_null("GuardrailCollision") as StaticBody3D
	_check(body != null, "the road has guardrail collision")

	if body == null:
		return

	var nearest: Node3D = null
	var nearest_distance := INF

	for child in body.get_children():
		var shape := child as Node3D

		if shape == null:
			continue

		var distance := shape.global_position.distance_to(_truck.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = shape

	_check(nearest != null, "a guardrail box is near the truck (%.1f m)" % nearest_distance)

	if nearest == null:
		return

	var from := _truck.global_position + Vector3(0.0, 0.4, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, nearest.global_position)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	_check(not hit.is_empty(), "a ray from the truck hits the barrier")

	if hit.is_empty():
		return

	var collider := hit.get("collider") as Node
	_check(collider != null and collider.name == "GuardrailCollision",
		"the guardrail stops the truck (hit %s)" % (collider.name if collider != null else "nothing"))
	_check(float(hit.get("position").y) > 0.0, "the barrier is above the road surface")


func _check_weather() -> void:
	if _weather == null:
		return

	_check(_weather.call("is_emitting"), "rain particles are emitting")

	var soak: float = _weather.call("wetness")
	_check(soak > 0.3, "the road is soaking up (%.2f)" % soak)

	if _road != null and _road.has_method("wetness"):
		_check(float(_road.call("wetness")) > 0.3, "the road material knows it is wet")

	var asphalt := (_road.get_node("Asphalt") as MeshInstance3D).material_override as StandardMaterial3D

	if asphalt != null:
		_check(asphalt.metallic > 0.1, "wet tarmac has turned reflective (metallic %.2f)" % asphalt.metallic)


func _finish() -> void:
	if _failures == 0:
		print("[drive] PASS")
		get_tree().quit(0)
	else:
		printerr("[drive] FAIL (%d checks)" % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)
