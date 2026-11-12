class_name Trailer
extends Node3D
## Curtain-sider trailer on a kinematic articulation model.
##
## A physics joint between two VehicleBody3D nodes is a jitter factory at these
## masses, so the trailer follows analytically instead: the tractor-to-trailer
## yaw rate is `speed / wheelbase * sin(yaw difference)`, the classic
## single-track trailer equation. It is stable, cheap, and still jackknifes when
## you reverse badly — which is the part that matters.

@export var truck_path: NodePath
## Hitch point in the truck's local space (+Z is the back of the truck).
@export var hitch_offset := Vector3(0.0, 0.75, 4.4)
@export var trailer_length := 10.5
@export var deck_height := 1.1
@export var wheelbase := 7.4
@export var cargo_color := Color(0.72, 0.74, 0.78)
## The road plane. The trailer's own geometry is built with its wheels on y=0,
## so its origin belongs here, not up at bumper height.
@export var ground_height := 0.0

var trailer_yaw := 0.0
var wheels: Array[MeshInstance3D] = []
var attached := true

var _truck: TruckController
var _last_yaw := 0.0


func _ready() -> void:
	add_to_group("rv_trailer")
	_truck = get_node_or_null(truck_path) as TruckController

	if _truck == null:
		push_warning("Trailer: no truck to follow.")
		return

	var socket := _truck.get_node_or_null("TruckModel") as TruckModel

	if socket != null and socket.has_model and socket.model_rear_z > 1.0:
		hitch_offset.z = socket.model_rear_z + 0.15

	trailer_yaw = _truck.global_rotation.y
	_last_yaw = trailer_yaw
	_build()
	_snap_to_hitch()


func _build() -> void:
	var frame := StandardMaterial3D.new()
	frame.albedo_color = Color(0.1, 0.11, 0.13)
	frame.metallic = 0.6
	frame.roughness = 0.45

	var tarp := StandardMaterial3D.new()
	tarp.albedo_color = cargo_color
	tarp.roughness = 0.85

	var tyre := StandardMaterial3D.new()
	tyre.albedo_color = Color(0.03, 0.03, 0.035)
	tyre.roughness = 1.0

	# Chassis rails.
	var rail_mesh := BoxMesh.new()
	rail_mesh.size = Vector3(2.3, 0.35, trailer_length)

	var rail := MeshInstance3D.new()
	rail.mesh = rail_mesh
	rail.material_override = frame
	rail.position = Vector3(0.0, deck_height, trailer_length * 0.5 - 0.6)
	add_child(rail)

	# The load: a tarped box that sits on the deck.
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(2.5, 2.7, trailer_length - 1.4)

	var body := MeshInstance3D.new()
	body.name = "Cargo"
	body.mesh = body_mesh
	body.material_override = tarp
	body.position = Vector3(0.0, deck_height + 1.5, trailer_length * 0.5 - 0.6)
	add_child(body)

	# Landing legs and a mudflap, so it does not look like a floating brick.
	var leg_mesh := BoxMesh.new()
	leg_mesh.size = Vector3(0.16, 1.0, 0.16)

	for side: float in [-0.85, 0.85]:
		var leg := MeshInstance3D.new()
		leg.mesh = leg_mesh
		leg.material_override = frame
		leg.position = Vector3(side, deck_height - 0.5, 1.4)
		add_child(leg)

	# Three axles at the back.
	var wheel_mesh := CylinderMesh.new()
	wheel_mesh.top_radius = 0.52
	wheel_mesh.bottom_radius = 0.52
	wheel_mesh.height = 0.34
	wheel_mesh.radial_segments = 14

	for axle in 3:
		var z := trailer_length - 1.6 - float(axle) * 1.35

		for side: float in [-1.05, 1.05]:
			var wheel := MeshInstance3D.new()
			wheel.mesh = wheel_mesh
			wheel.material_override = tyre
			wheel.rotation = Vector3(0.0, 0.0, PI * 0.5)
			wheel.position = Vector3(side, deck_height - 0.55, z)
			add_child(wheel)
			wheels.append(wheel)


func _physics_process(delta: float) -> void:
	if _truck == null:
		return

	var basis := _truck.global_transform.basis
	var forward_speed := -_truck.linear_velocity.dot(basis.z)

	# Trailer yaw integrates towards the truck's heading.
	var truck_yaw := _truck.global_rotation.y
	var difference := angle_difference(trailer_yaw, truck_yaw)
	trailer_yaw += (forward_speed / wheelbase) * sin(difference) * delta

	# Cheap self-alignment so it cannot creep away over a long drive.
	trailer_yaw = lerp_angle(trailer_yaw, truck_yaw, clampf(delta * 0.6, 0.0, 0.2))

	_snap_to_hitch()

	# Wheels roll with the trailer.
	var spin := forward_speed * delta / 0.52

	for wheel in wheels:
		wheel.rotation.z -= spin


## Where this node has to sit: on the hitch in x/z, on the road in y. Putting the
## origin at the hitch's height left the whole trailer floating ~0.7 m up, wheels
## dangling, because everything below the origin assumes it rests on the ground.
func _hitch_target() -> Vector3:
	var hitch := _truck.global_transform * hitch_offset
	hitch.y = ground_height
	return hitch


func _snap_to_hitch() -> void:
	global_transform = Transform3D(Basis(Vector3.UP, trailer_yaw), _hitch_target())


## Test hook: how far the hitch has drifted from the truck, in metres.
func hitch_error() -> float:
	if _truck == null:
		return INF

	return (global_position - _hitch_target()).length()


## Test hook: angle between the tractor and the trailer, in degrees.
func articulation_degrees() -> float:
	if _truck == null:
		return 0.0

	return rad_to_deg(absf(angle_difference(trailer_yaw, _truck.global_rotation.y)))


## World position of the trailer's back end. The chase camera uses it to stay
## behind the whole rig instead of inside the cargo box.
func rear_point() -> Vector3:
	return global_transform * Vector3(0.0, 0.0, trailer_length)


## Test hook: how tight a corner the rig is currently in.
func jackknifed() -> bool:
	return articulation_degrees() > 75.0
