extends Node3D
## Regression test for "the camera stays behind while I drive".
## Drives the real game scene and asserts the camera keeps following the truck.
##
##   godot --headless --path . res://tests/camera_follow.tscn

const DRIVE_SECONDS := 5.0
const MIN_FOLLOW_METRES := 20.0
const MAX_DISTANCE := 30.0
const MIN_DISTANCE := 5.0

var _game: Node3D
var _truck: Node3D
var _camera: Camera3D

var _elapsed := 0.0
var _start_truck := Vector3.ZERO
var _start_camera := Vector3.ZERO
var _min_gap := 9999.0
var _max_gap := 0.0
var _failures := 0


func _ready() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_game = scene.instantiate()
	add_child(_game)

	_truck = _game.get_node("Truck") as Node3D
	_camera = _game.get_node("ChaseCamera") as Camera3D

	_start_truck = _truck.global_position
	_start_camera = _camera.global_position

	Input.action_press("rv_throttle", 1.0)


func _physics_process(delta: float) -> void:
	_elapsed += delta

	var gap := _truck.global_position.distance_to(_camera.global_position)
	_min_gap = minf(_min_gap, gap)
	_max_gap = maxf(_max_gap, gap)

	if _elapsed >= DRIVE_SECONDS:
		Input.action_release("rv_throttle")
		_finish()


func _finish() -> void:
	var truck_travel := _start_truck.distance_to(_truck.global_position)
	var camera_travel := _start_camera.distance_to(_camera.global_position)

	print("[follow] truck travelled %.1f m, camera travelled %.1f m" % [truck_travel, camera_travel])
	print("[follow] gap min %.1f m, max %.1f m" % [_min_gap, _max_gap])

	_check(truck_travel > MIN_FOLLOW_METRES, "the truck actually drives (%.1f m)" % truck_travel)
	_check(camera_travel > MIN_FOLLOW_METRES * 0.7, "the camera follows the truck (%.1f m)" % camera_travel)
	_check(_max_gap < MAX_DISTANCE, "the camera never falls too far behind (%.1f m)" % _max_gap)
	_check(_min_gap > MIN_DISTANCE, "the camera never sits inside the truck (%.1f m)" % _min_gap)

	# The camera should be behind the truck: -Z is forward for the truck.
	var behind := _camera.global_position - _truck.global_position
	behind.y = 0.0
	var forward := -_truck.global_basis.z
	forward.y = 0.0
	_check(behind.normalized().dot(forward.normalized()) < -0.5, "the camera stays behind the truck")

	if _failures == 0:
		print("[follow] PASS")
		get_tree().quit(0)
	else:
		printerr("[follow] FAIL (%d checks)" % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)
