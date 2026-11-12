class_name WheelVisuals
extends Node3D
## Spins the wheel meshes and turns the steered wheels. The physics wheels do not
## move their children, so this keeps the visuals honest.
##
## Each VehicleWheel3D has a "Spin" child holding the mesh. Spin.rotation is
## (spin_angle, steering, 0): Godot's Euler order YXZ applies the yaw first, so
## steering wraps around the spin instead of the other way round.

var _wheels: Array[VehicleWheel3D] = []
var _spins: Array[Node3D] = []
var _angles: Array[float] = []


func _ready() -> void:
	var truck := get_parent()

	if truck == null:
		return

	for child in truck.get_children():
		if child is not VehicleWheel3D:
			continue

		_wheels.append(child)
		_spins.append(child.get_node_or_null("Spin") as Node3D)
		_angles.append(0.0)


func _physics_process(delta: float) -> void:
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
