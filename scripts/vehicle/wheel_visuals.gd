class_name WheelVisuals
extends Node3D
## Spins the wheel meshes and turns the steered wheels. The physics wheels do not
## move their children, so this keeps the visuals honest.
##
## Each VehicleWheel3D has a "Spin" child holding the mesh. Spin.rotation is
## (spin_angle, steering, 0): Godot's Euler order YXZ applies the yaw first, so
## steering wraps around the spin instead of the other way round.

var _truck: VehicleBody3D
var _wheels: Array[VehicleWheel3D] = []
var _spins: Array[Node3D] = []
var _angles: Array[float] = []

## Extra wheels that came from a real model: {node, steers, angle}.
var _extra: Array[Dictionary] = []


func _ready() -> void:
	var truck := get_parent()
	_truck = truck as VehicleBody3D

	if truck == null:
		return

	for child in truck.get_children():
		if child is not VehicleWheel3D:
			continue

		_wheels.append(child)
		_spins.append(child.get_node_or_null("Spin") as Node3D)
		_angles.append(0.0)


## Called by TruckModel for every wheel it found on the mesh. The pivot spins on
## its own axle; only the front ones take the steering angle.
func register_model_wheel(pivot: Node3D, steers: bool) -> void:
	if pivot == null:
		return

	_extra.append({"node": pivot, "steers": steers, "angle": 0.0})


func model_wheel_count() -> int:
	return _extra.size()


## Test hook: how many of the model's wheels take the steering angle.
func model_steering_count() -> int:
	var count := 0
	for wheel in _extra:
		if bool(wheel["steers"]):
			count += 1
	return count


func _physics_process(delta: float) -> void:
	_drive_extra_wheels()
	_drive_procedural_wheels(delta)


## Real-model wheels roll with the truck's own speed.
func _drive_extra_wheels() -> void:
	if _truck == null or _extra.is_empty():
		return

	var speed := _truck.linear_velocity.length()
	var steering := 0.0
	var front := _truck.get_node_or_null("WheelFL") as VehicleWheel3D

	if front != null:
		steering = front.steering

	for wheel in _extra:
		var pivot := wheel["node"] as Node3D

		if pivot == null:
			continue

		wheel["angle"] = wrapf(float(wheel["angle"]) + speed / 0.5 * get_physics_process_delta_time(), -TAU, TAU)
		pivot.rotation = Vector3(float(wheel["angle"]), steering if bool(wheel["steers"]) else 0.0, 0.0)


func _drive_procedural_wheels(delta: float) -> void:
	for i in _wheels.size():
		var spin := _spins[i]
		if spin == null:
			continue

		var wheel := _wheels[i]

		# get_rpm() is the wheel's angular velocity in rad/s.
		_angles[i] = wrapf(_angles[i] + wheel.get_rpm() * delta, -TAU, TAU)

		# Physics steering is positive to the left, which matches a positive yaw.
		spin.rotation = Vector3(_angles[i], wheel.steering, 0.0)


## Test hook: how many wheels are being driven visually.
func wheel_count() -> int:
	return _wheels.size()


## Test hook: current spin angle of a wheel in radians.
func spin_angle(index: int) -> float:
	return _angles[index] if index >= 0 and index < _angles.size() else 0.0
