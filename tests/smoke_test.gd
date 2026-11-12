extends Node3D
## Physics smoke test: does the truck actually accelerate under throttle?
##
##   godot --headless --path . res://tests/smoke_test.tscn
##
## Exits 0 on success, 1 on failure.

const TRUCK_SCENE := preload("res://scenes/truck.tscn")
const INPUT_SETUP := preload("res://scripts/core/input_setup.gd")

const SETTLE_SECONDS := 2.5
const DRIVE_SECONDS := 6.0
const STEER_SECONDS := 3.0
const MIN_SPEED_KPH := 8.0

var _truck: TruckController
var _elapsed := 0.0
var _phase := 0
var _failures := 0


func _ready() -> void:
	INPUT_SETUP.ensure_registered()

	var ground := StaticBody3D.new()
	ground.name = "TestGround"
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(600, 1, 600)
	shape.shape = box
	shape.position = Vector3(0, -0.5, 0)
	ground.add_child(shape)
	add_child(ground)

	_truck = TRUCK_SCENE.instantiate()
	_truck.position = Vector3(0, 1.0, 0)
	add_child(_truck)

	print("[smoke] settling for %.1fs ..." % SETTLE_SECONDS)


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if _phase == 0 and _elapsed >= SETTLE_SECONDS:
		_phase = 1
		var rest_speed := _truck.linear_velocity.length()
		print("[smoke] settled at %.2f m/s, applying throttle" % rest_speed)
		_check(rest_speed < 1.0, "truck is at rest before throttle (got %.2f m/s)" % rest_speed)
		_check(_truck.global_position.y > -1.0, "truck did not fall through the ground (y=%.2f)" % _truck.global_position.y)
		Input.action_press("rv_throttle", 1.0)
		return

	if _phase == 1 and _elapsed >= SETTLE_SECONDS + DRIVE_SECONDS:
		_phase = 2
		_check(_truck.gearbox.current_gear > 1, "automatic gearbox upshifted (gear %d)" % _truck.gearbox.current_gear)
		print("[smoke] steering right for %.1fs" % STEER_SECONDS)
		Input.action_press("rv_steer_right", 1.0)
		return

	if _phase == 2 and _elapsed >= SETTLE_SECONDS + DRIVE_SECONDS + STEER_SECONDS:
		_phase = 3
		Input.action_release("rv_steer_right")
		Input.action_release("rv_throttle")

		# Truck faces -Z, so a right turn moves its forward vector towards +X.
		var forward := -_truck.global_basis.z
		print("[smoke] heading after right turn: x=%.2f z=%.2f" % [forward.x, forward.z])
		print("[smoke] diag: y=%.2f up.y=%.2f roll_deg=%.0f ang_vel=%.2f speed_mps=%.2f" % [
			_truck.global_position.y,
			_truck.global_basis.y.y,
			rad_to_deg(acos(clampf(_truck.global_basis.y.y, -1.0, 1.0))),
			_truck.angular_velocity.length(),
			_truck.linear_velocity.length(),
		])
		_check(forward.x > 0.1, "steering right turns towards +X (x=%.2f)" % forward.x)
		var roll_deg := rad_to_deg(acos(clampf(_truck.global_basis.y.y, -1.0, 1.0)))
		_check(roll_deg < 35.0, "truck stayed upright through the turn (roll %.0f deg)" % roll_deg)
		_check(_truck.linear_velocity.length() > 3.0, "still moving after the turn (%.2f m/s)" % _truck.linear_velocity.length())

		_finish()


func _finish() -> void:
	var speed_kph := _truck.speed_kph()
	var forward := _truck.forward_speed()

	print("[smoke] after %.1fs of throttle: %.1f km/h (forward %.2f m/s), gear %d, %.0f rpm"
		% [DRIVE_SECONDS, speed_kph, forward, _truck.gearbox.current_gear, _truck.engine_rpm])

	_check(speed_kph >= MIN_SPEED_KPH, "reached at least %d km/h (got %.1f)" % [MIN_SPEED_KPH, speed_kph])
	_check(forward > 0.0, "moved forward, not backward (%.2f m/s)" % forward)
	_check(_truck.engine_rpm >= _truck.idle_rpm, "engine rpm is above idle")
	_check(is_finite(_truck.linear_velocity.length()), "velocity is finite (no physics explosion)")

	if _failures == 0:
		print("[smoke] PASS")
		get_tree().quit(0)
	else:
		printerr("[smoke] FAIL (%d checks)" % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)
