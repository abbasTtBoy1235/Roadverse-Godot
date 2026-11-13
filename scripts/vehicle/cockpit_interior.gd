class_name CockpitInterior
extends Node3D
## A simple cab interior — dashboard, gauge cluster and a steering wheel that
## actually turns — built around the cockpit camera's eye point. Without it
## the in-cab view floated inside a hollow shell.
##
## Positions come from the fitted GLB when there is one (TruckModel runs its
## _ready before this node, by tree order), with procedural-cab fallbacks.

var steering_wheel_pivot: Node3D

var _wheel: VehicleWheel3D


func _ready() -> void:
	var truck := get_parent() as Node3D
	_wheel = truck.get_node_or_null("WheelFL") as VehicleWheel3D

	var front_z := -3.95
	var width := 2.4
	var eye_y := 2.35

	var socket := truck.get_node_or_null("TruckModel") as TruckModel

	if socket != null and socket.has_model:
		front_z = socket.model_front_z
		width = socket.model_width
		eye_y = clampf(socket.model_height * 0.62, 1.8, 2.3)

	_build(front_z, width, eye_y)


func _build(front_z: float, width: float, eye_y: float) -> void:
	var dash_material := StandardMaterial3D.new()
	dash_material.albedo_color = Color(0.05, 0.055, 0.07)
	dash_material.roughness = 0.9

	# Dashboard: a dark slab across the cab, just under the windscreen.
	var dash_mesh := BoxMesh.new()
	dash_mesh.size = Vector3(width * 0.84, 0.34, 0.55)

	var dash := MeshInstance3D.new()
	dash.name = "Dashboard"
	dash.mesh = dash_mesh
	dash.material_override = dash_material
	dash.position = Vector3(0.0, eye_y - 0.48, front_z + 0.5)
	add_child(dash)

	# Gauge cluster glow behind the wheel.
	var gauge_material := StandardMaterial3D.new()
	gauge_material.albedo_color = Color(0.1, 0.5, 0.55)
	gauge_material.emission_enabled = true
	gauge_material.emission = Color(0.15, 0.7, 0.75)
	gauge_material.emission_energy_multiplier = 1.6
	gauge_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var gauge_mesh := BoxMesh.new()
	gauge_mesh.size = Vector3(0.52, 0.2, 0.04)

	var gauge := MeshInstance3D.new()
	gauge.name = "GaugeCluster"
	gauge.mesh = gauge_mesh
	gauge.material_override = gauge_material
	gauge.position = Vector3(-0.45, eye_y - 0.3, front_z + 0.68)
	gauge.rotation.x = -0.35
	add_child(gauge)

	# Steering wheel on a tilted pivot in front of the driver's seat.
	steering_wheel_pivot = Node3D.new()
	steering_wheel_pivot.name = "SteeringWheel"
	steering_wheel_pivot.position = Vector3(-0.45, eye_y - 0.32, front_z + 0.78)
	add_child(steering_wheel_pivot)

	var wheel_material := StandardMaterial3D.new()
	wheel_material.albedo_color = Color(0.03, 0.03, 0.04)
	wheel_material.roughness = 0.7

	var rim_mesh := TorusMesh.new()
	rim_mesh.inner_radius = 0.185
	rim_mesh.outer_radius = 0.235
	rim_mesh.rings = 20
	rim_mesh.ring_segments = 8

	var rim := MeshInstance3D.new()
	rim.mesh = rim_mesh
	rim.material_override = wheel_material
	rim.rotation.x = PI * 0.5
	steering_wheel_pivot.add_child(rim)

	var spoke_mesh := BoxMesh.new()
	spoke_mesh.size = Vector3(0.4, 0.05, 0.04)

	var spoke := MeshInstance3D.new()
	spoke.mesh = spoke_mesh
	spoke.material_override = wheel_material
	steering_wheel_pivot.add_child(spoke)

	steering_wheel_pivot.rotation.x = -0.42


func _physics_process(_delta: float) -> void:
	if _wheel == null or steering_wheel_pivot == null:
		return

	# The wheel turns several times further than the road wheels do.
	steering_wheel_pivot.rotation.z = _wheel.steering * 3.2


## Test hook: current steering wheel angle in radians.
func steering_wheel_angle() -> float:
	return 0.0 if steering_wheel_pivot == null else steering_wheel_pivot.rotation.z
