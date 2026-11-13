class_name TruckLights
extends Node3D
## Owns the truck's light nodes. Children are classified by group membership
## ("rv_headlight" / "rv_brakelight") so the node hierarchy stays free-form.

const HEADLIGHT_GROUP := "rv_headlight"
const BRAKELIGHT_GROUP := "rv_brakelight"

var headlights: Array[Light3D] = []
var brake_lights: Array[Light3D] = []

var headlights_on := false

var _indicator_materials: Dictionary = {}
var _indicators_built := false
var _blink_time := 0.0


func _ready() -> void:
	for node in find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.is_in_group(HEADLIGHT_GROUP):
			headlights.append(light)
		elif light.is_in_group(BRAKELIGHT_GROUP):
			brake_lights.append(light)

	set_headlights(headlights_on)
	call_deferred("_build_indicators")


## Small amber lamps at the four corners, built once the model (and so its
## corners) is known. Deferred: TruckModel readies after this node.
func _build_indicators() -> void:
	if _indicators_built:
		return
	_indicators_built = true

	var truck := get_parent() as Node3D
	var front_z := -3.95
	var rear_z := 4.05
	var half_width := 1.05

	var socket := truck.get_node_or_null("TruckModel") as TruckModel

	if socket != null and socket.has_model:
		front_z = socket.model_front_z + 0.06
		rear_z = socket.model_rear_z - 0.06
		half_width = socket.model_width * 0.5 - 0.14

	var lamp_mesh := BoxMesh.new()
	lamp_mesh.size = Vector3(0.2, 0.13, 0.07)

	for side in [-1.0, 1.0]:
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(0.85, 0.5, 0.1)
		material.emission_enabled = true
		material.emission = Color(1.0, 0.55, 0.1)
		material.emission_energy_multiplier = 0.15
		_indicator_materials[side] = material

		for z in [front_z, rear_z]:
			var lamp := MeshInstance3D.new()
			lamp.name = "Indicator%s%s" % ["L" if side < 0.0 else "R", "F" if z == front_z else "R"]
			lamp.mesh = lamp_mesh
			lamp.material_override = material
			lamp.position = Vector3(side * half_width, 0.9, z)
			add_child(lamp)


func _process(delta: float) -> void:
	if not _indicators_built:
		return

	_blink_time += delta
	var on := fmod(_blink_time * 1.5, 1.0) < 0.55
	var state := indicator_state()

	for side in _indicator_materials:
		var side_value := float(side)
		var active: bool = (state == "left" and side_value < 0.0) or (state == "right" and side_value > 0.0)
		(_indicator_materials[side] as StandardMaterial3D).emission_energy_multiplier = 4.5 if (active and on) else 0.15


## Which indicator is blinking: the side the truck is steering towards.
## Vehicle steering is positive to the left.
func indicator_state() -> String:
	var truck := get_parent() as VehicleBody3D

	if truck == null:
		return "off"

	if truck.steering > 0.07:
		return "left"

	if truck.steering < -0.07:
		return "right"

	return "off"


func set_headlights(on: bool) -> void:
	headlights_on = on
	_apply(headlights, on)


func toggle_headlights() -> void:
	set_headlights(not headlights_on)


func set_brake_lights(on: bool) -> void:
	_apply(brake_lights, on)


func _apply(lights: Array[Light3D], on: bool) -> void:
	for light in lights:
		if is_instance_valid(light):
			light.visible = on
