extends Node3D
## Integration test: drives the real scene and checks that the wheels turn, the
## engine synth follows the revs, and the traffic moves along the road.
##
##   godot --headless --path . res://tests/drive_state.tscn

const DRIVE_SECONDS := 4.0
const STEER_SECONDS := 1.5

var _game: Node3D
var _truck: TruckController
var _wheels: WheelVisuals
var _audio: EngineAudio
var _traffic: Node3D

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

	_check(_truck != null, "truck found")
	_check(_wheels != null, "wheel visuals found")
	_check(_audio != null, "engine audio found")
	_check(_traffic != null, "traffic found")

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
