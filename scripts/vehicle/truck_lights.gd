class_name TruckLights
extends Node3D
## Owns the truck's light nodes. Children are classified by group membership
## ("rv_headlight" / "rv_brakelight") so the node hierarchy stays free-form.

const HEADLIGHT_GROUP := "rv_headlight"
const BRAKELIGHT_GROUP := "rv_brakelight"

var headlights: Array[Light3D] = []
var brake_lights: Array[Light3D] = []

var headlights_on := false
## Second stage of the L key: longer, brighter throw.
var high_beam := false

var _cones: Array[MeshInstance3D] = []
var _cone_material: StandardMaterial3D
var _cones_built := false
var _night := 0.0


func _ready() -> void:
	add_to_group("rv_time_aware")

	for node in find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.is_in_group(HEADLIGHT_GROUP):
			headlights.append(light)
		elif light.is_in_group(BRAKELIGHT_GROUP):
			brake_lights.append(light)

	set_headlights(headlights_on)
	call_deferred("_build_cones")


## Fake volumetric cones under the headlights: an additive transparent
## wedge that sells the beam on a dark road. Built once the model's nose
## (and so the lamps' real positions) is known.
func _build_cones() -> void:
	if _cones_built:
		return
	_cones_built = true

	_cone_material = StandardMaterial3D.new()
	var cone_mat := _cone_material
	cone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	cone_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	cone_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	cone_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	cone_mat.albedo_color = Color(1.0, 0.9, 0.7, 0.09)

	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.07
	cone_mesh.bottom_radius = 1.15
	cone_mesh.height = 7.0
	cone_mesh.radial_segments = 12

	for light in headlights:
		if not (light is SpotLight3D):
			continue

		var cone := MeshInstance3D.new()
		cone.name = "HeadlightCone"
		cone.mesh = cone_mesh
		cone.material_override = cone_mat
		# Cylinder axis is Y with the narrow end at +Y: pitch +84 degrees so
		# the narrow end sits at the lamp and the wide end opens down-road,
		# dropping slightly as it goes. (At -96 the cone stood fat-end
		# forward, like a megaphone held backwards.)
		cone.rotation_degrees = Vector3(84.0, 0.0, 0.0)
		cone.position = light.position + Vector3(0.0, -0.25, -3.4)
		cone.visible = headlights_on and _night > 0.03
		add_child(cone)
		_cones.append(cone)


## Test hook: how many beam cones the truck carries.
func headlight_cone_count() -> int:
	return _cones.size()


## Test hook: are the beam cones lit right now?
func cones_visible() -> bool:
	return not _cones.is_empty() and _cones[0].visible


## How many add-on indicator lamps are bolted onto the truck. The model
## has its own, so this must stay zero.
func indicator_lamp_count() -> int:
	return find_children("Indicator*", "", true, false).size()


func set_headlights(on: bool) -> void:
	headlights_on = on
	high_beam = false
	_apply(headlights, on)
	_apply_beam()


func set_high_beam(on: bool) -> void:
	high_beam = on and headlights_on
	_apply_beam()


## off -> low -> high -> off, the way a stalk switch feels.
func cycle_headlights() -> void:
	if not headlights_on:
		set_headlights(true)
	elif not high_beam:
		set_high_beam(true)
	else:
		set_headlights(false)


func _apply_beam() -> void:
	for light in headlights:
		var spot := light as SpotLight3D

		if spot == null:
			continue

		spot.spot_range = 120.0 if high_beam else 75.0
		spot.light_energy = 11.0 if high_beam else 8.0

	_refresh_cones()


## Beam cones are a night trick: at noon they would hang in the air like
## smoke. TimeOfDay broadcasts the dark through rv_time_aware.
func apply_time_of_day(night_factor: float) -> void:
	_night = clampf(night_factor, 0.0, 1.0)

	if _cone_material != null:
		_cone_material.albedo_color = Color(1.0, 0.9, 0.7, 0.11 * _night)

	_refresh_cones()


func _refresh_cones() -> void:
	for cone in _cones:
		cone.visible = headlights_on and _night > 0.03


func toggle_headlights() -> void:
	set_headlights(not headlights_on)


func set_brake_lights(on: bool) -> void:
	_apply(brake_lights, on)


func _apply(lights: Array[Light3D], on: bool) -> void:
	for light in lights:
		if is_instance_valid(light):
			light.visible = on
