class_name TruckLights
extends Node3D
## Owns the truck's light nodes. Children are classified by group membership
## ("rv_headlight" / "rv_brakelight") so the node hierarchy stays free-form.

const HEADLIGHT_GROUP := "rv_headlight"
const BRAKELIGHT_GROUP := "rv_brakelight"

var headlights: Array[Light3D] = []
var brake_lights: Array[Light3D] = []

var headlights_on := false


func _ready() -> void:
	for node in find_children("*", "Light3D", true, false):
		var light := node as Light3D
		if light.is_in_group(HEADLIGHT_GROUP):
			headlights.append(light)
		elif light.is_in_group(BRAKELIGHT_GROUP):
			brake_lights.append(light)

	set_headlights(headlights_on)


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
