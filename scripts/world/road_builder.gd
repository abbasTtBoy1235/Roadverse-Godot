class_name RoadBuilder
extends Node3D
## Builds the night road procedurally: asphalt surface, dashed centre line and
## street lamps on alternating sides. No imported assets needed, so the project
## runs from a fresh clone.

@export var road_length := 600.0
@export var road_width := 13.0
@export var lane_mark_length := 3.5
@export var lane_mark_gap := 6.0
@export var lamp_spacing := 40.0
@export var lamp_height := 9.0
@export var lamp_energy := 6.0
@export var lamp_range := 32.0
@export var lamp_color := Color(1.0, 0.82, 0.55)

var _asphalt_material: StandardMaterial3D
var _paint_material: StandardMaterial3D
var _metal_material: StandardMaterial3D
var _lamp_material: StandardMaterial3D


func _ready() -> void:
	_create_materials()
	_build_surface()
	_build_centre_line()
	_build_lamps()


func _create_materials() -> void:
	_asphalt_material = StandardMaterial3D.new()
	_asphalt_material.albedo_color = Color(0.09, 0.09, 0.1)
	_asphalt_material.roughness = 0.95
	_asphalt_material.metallic_specular = 0.15

	_paint_material = StandardMaterial3D.new()
	_paint_material.albedo_color = Color(0.85, 0.85, 0.8)
	_paint_material.roughness = 0.6

	_metal_material = StandardMaterial3D.new()
	_metal_material.albedo_color = Color(0.2, 0.21, 0.23)
	_metal_material.metallic = 0.8
	_metal_material.roughness = 0.45

	_lamp_material = StandardMaterial3D.new()
	_lamp_material.albedo_color = Color(1.0, 0.9, 0.7)
	_lamp_material.emission_enabled = true
	_lamp_material.emission = Color(1.0, 0.86, 0.6)
	_lamp_material.emission_energy_multiplier = 4.0


func _build_surface() -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(road_width, 0.2, road_length)

	var instance := MeshInstance3D.new()
	instance.name = "Asphalt"
	instance.mesh = mesh
	instance.material_override = _asphalt_material
	instance.position = Vector3(0.0, -0.1, 0.0)
	add_child(instance)


func _build_centre_line() -> void:
	var step := lane_mark_length + lane_mark_gap
	var count := int(road_length / step)
	var start := -road_length * 0.5 + step * 0.5

	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.16, 0.02, lane_mark_length)

	for i in count:
		var instance := MeshInstance3D.new()
		instance.mesh = mesh
		instance.material_override = _paint_material
		instance.position = Vector3(0.0, 0.005, start + i * step)
		add_child(instance)


func _build_lamps() -> void:
	var count := int(road_length / lamp_spacing)
	var start := -road_length * 0.5 + lamp_spacing * 0.5

	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.11
	pole_mesh.bottom_radius = 0.16
	pole_mesh.height = lamp_height

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(2.0, 0.12, 0.12)

	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.28
	bulb_mesh.height = 0.56

	for i in count:
		var side := -1.0 if i % 2 == 0 else 1.0
		var z := start + i * lamp_spacing
		var base_x := side * (road_width * 0.5 + 1.8)

		var lamp_root := Node3D.new()
		lamp_root.name = "Lamp%d" % i
		lamp_root.position = Vector3(base_x, 0.0, z)
		add_child(lamp_root)

		var pole := MeshInstance3D.new()
		pole.mesh = pole_mesh
		pole.material_override = _metal_material
		pole.position = Vector3(0.0, lamp_height * 0.5, 0.0)
		lamp_root.add_child(pole)

		var arm := MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.material_override = _metal_material
		arm.position = Vector3(-side * 0.9, lamp_height - 0.2, 0.0)
		lamp_root.add_child(arm)

		var bulb := MeshInstance3D.new()
		bulb.mesh = bulb_mesh
		bulb.material_override = _lamp_material
		bulb.position = Vector3(-side * 1.85, lamp_height - 0.35, 0.0)
		lamp_root.add_child(bulb)

		var light := OmniLight3D.new()
		light.position = bulb.position
		light.light_color = lamp_color
		light.light_energy = lamp_energy
		light.omni_range = lamp_range
		light.shadow_enabled = false
		lamp_root.add_child(light)
