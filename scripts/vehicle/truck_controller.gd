class_name TruckController
extends VehicleBody3D
## Drives the VehicleBody3D from the input actions, with a real gearbox and an
## engine torque curve on top. All tuning lives in the inspector.

@export_group("Engine")
@export var idle_rpm := 600.0
@export var max_rpm := 2400.0
## Optional torque curve: X = normalised RPM (0 at idle, 1 at redline), Y = torque
## fraction (0..1). When empty, a flat band between 30% and 85% is used.
@export var torque_curve: Curve
@export var peak_torque_nm := 1400.0

@export_group("Drivetrain")
@export var gear_ratios: PackedFloat32Array = PackedFloat32Array([-4.7, 5.4, 3.1, 1.85, 1.0, 0.72])
@export var final_drive := 3.7
@export var drivetrain_efficiency := 0.9
@export var automatic := true
@export var upshift_rpm := 2000.0
@export var downshift_rpm := 1100.0

@export_group("Brakes")
@export var max_brake := 45.0
@export var handbrake_brake := 90.0
@export var engine_brake := 2.5

@export_group("Steering")
@export var max_steer_angle := 0.61
@export var high_speed_steer_angle := 0.09
@export var steer_falloff_speed := 20.0
@export var steer_response := 3.5

var gearbox: Gearbox
var engine_rpm := 0.0

var _traction_wheels: Array[VehicleWheel3D] = []
var _steer := 0.0
var _wheel_radius := 0.5
var _lights: TruckLights


func _ready() -> void:
	gearbox = Gearbox.new(gear_ratios, final_drive, upshift_rpm, downshift_rpm)
	_lights = get_node_or_null("Lights") as TruckLights

	for child in get_children():
		if child is VehicleWheel3D and child.use_as_traction:
			_traction_wheels.append(child)
			_wheel_radius = child.wheel_radius

	if _traction_wheels.is_empty():
		for child in get_children():
			if child is VehicleWheel3D:
				_traction_wheels.append(child)
				_wheel_radius = child.wheel_radius

	if _lights != null:
		_lights.set_headlights(true)


func _physics_process(delta: float) -> void:
	_read_gear_input()
	_apply_engine_and_brakes()
	_apply_steering(delta)

	if Input.is_action_just_pressed("rv_toggle_headlights") and _lights != null:
		_lights.toggle_headlights()

	if _lights != null:
		_lights.set_brake_lights(brake > 0.1)


func _read_gear_input() -> void:
	if automatic:
		return

	if Input.is_action_just_pressed("rv_shift_up"):
		gearbox.shift_up()
	elif Input.is_action_just_pressed("rv_shift_down"):
		gearbox.shift_down()


func _apply_engine_and_brakes() -> void:
	var throttle := Input.get_action_strength("rv_throttle")
	var brake_input := Input.get_action_strength("rv_brake")
	var handbrake := Input.is_action_pressed("rv_handbrake")

	engine_rpm = _read_engine_rpm()

	if automatic and throttle > 0.05:
		gearbox.update_auto_shift(engine_rpm)
		engine_rpm = _read_engine_rpm()

	if handbrake:
		brake = handbrake_brake
		engine_force = 0.0
		return

	if brake_input > 0.01:
		brake = brake_input * max_brake
		engine_force = 0.0
		return

	if throttle <= 0.01:
		# Coasting: a touch of engine braking.
		brake = engine_brake
		engine_force = 0.0
		return

	var forward_speed := linear_velocity.dot(-global_transform.basis.z)

	# Reverse must not fight forward momentum at speed.
	if gearbox.current_ratio < 0.0 and forward_speed > 1.5:
		brake = 0.0
		engine_force = 0.0
		return

	# The gear ratio carries the sign: negative in reverse, so reverse torque
	# comes out negative on its own.
	var force_at_wheel := peak_torque_nm * _torque_fraction(engine_rpm) \
		* gearbox.current_ratio * final_drive * drivetrain_efficiency / _wheel_radius

	# VehicleBody3D pushes the body towards +Z for a positive engine_force, while
	# the project convention (and every node in truck.tscn) has the truck facing
	# -Z. Negating here keeps the two aligned; verified by tests/smoke_test.gd.
	engine_force = -force_at_wheel * throttle
	brake = 0.0


func _apply_steering(delta: float) -> void:
	var raw := Input.get_axis("rv_steer_left", "rv_steer_right")
	var falloff := clampf(linear_velocity.length() / steer_falloff_speed, 0.0, 1.0)
	var allowed := lerpf(max_steer_angle, high_speed_steer_angle, falloff)

	_steer = move_toward(_steer, allowed * raw, steer_response * delta)

	# Positive vehicle steering turns towards -X, which is the truck's left when
	# it faces -Z. Negate so that "steer right" means right.
	steering = -_steer


func _read_engine_rpm() -> float:
	if _traction_wheels.is_empty():
		return idle_rpm

	var wheel_rad_s := 0.0
	for wheel in _traction_wheels:
		wheel_rad_s += absf(wheel.get_rpm())

	wheel_rad_s /= float(_traction_wheels.size())

	var wheel_rpm := wheel_rad_s * 60.0 / TAU
	return clampf(maxf(idle_rpm, gearbox.engine_rpm(wheel_rpm)), idle_rpm, max_rpm)


func _torque_fraction(rpm: float) -> float:
	var t := clampf(inverse_lerp(idle_rpm, max_rpm, rpm), 0.0, 1.0)

	if torque_curve != null:
		return clampf(torque_curve.sample_baked(t), 0.0, 1.0)

	# Flat-ish band, falling off near idle and redline.
	return clampf(1.0 - absf(t - 0.55) * 1.4, 0.35, 1.0)


## Speed in km/h.
func speed_kph() -> float:
	return linear_velocity.length() * 3.6


## Signed forward speed in m/s (negative when reversing).
func forward_speed() -> float:
	return linear_velocity.dot(-global_transform.basis.z)
