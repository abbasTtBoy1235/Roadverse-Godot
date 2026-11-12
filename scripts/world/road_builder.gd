class_name RoadBuilder
extends Node3D
## Builds the whole roadside procedurally from a Curve3D: asphalt, shoulders,
## markings, guardrails, delineator posts, street lamps, trees, rocks, power
## poles, signs and distant hills.
##
## No imported assets, everything is generated at runtime, so a fresh clone has
## a detailed road. Repeated props go through MultiMesh to keep draw calls low.

@export_group("Road")
@export var road_length := 640.0
@export var road_width := 13.0
@export var shoulder_width := 2.6
@export var bend_amplitude := 28.0
@export var mesh_step := 2.5
@export var seed_value := 20261112

@export_group("Markings")
@export var edge_line_offset := 0.42
@export var dash_length := 4.0
@export var dash_gap := 7.0

@export_group("Furniture")
@export var lamp_spacing := 44.0
@export var delineator_spacing := 24.0
@export var rail_post_spacing := 5.0
@export var tree_spacing := 9.0
@export var max_trees_per_spot := 2
@export var rock_spacing := 24.0
@export var pole_spacing := 68.0
@export var sign_count := 7

@export_group("Distant scenery")
@export var hill_count := 9
@export var hill_distance := 300.0

var curve: Curve3D

var _rng := RandomNumberGenerator.new()
var _baked_length := 0.0
var _built := false

var _asphalt: StandardMaterial3D
var _shoulder: StandardMaterial3D
var _paint: StandardMaterial3D
var _rail: StandardMaterial3D
var _bark: StandardMaterial3D
var _leaves: StandardMaterial3D
var _rock: StandardMaterial3D
var _metal: StandardMaterial3D
var _lamp_glass: StandardMaterial3D
var _reflector: StandardMaterial3D
var _sign_face: StandardMaterial3D
var _hill: StandardMaterial3D


func _ready() -> void:
	build()


## Generates everything. Public so tests can build without the scene tree.
func build() -> void:
	if _built:
		return
	_built = true

	_rng.seed = seed_value
	curve = _generate_curve()
	_baked_length = curve.get_baked_length()

	_create_materials()
	_build_surface()
	_build_shoulders()
	_build_edge_lines()
	_build_centre_line()
	_build_guardrails()
	_build_delineators()
	_build_lamps()
	_build_trees()
	_build_rocks()
	_build_power_poles()
	_build_signs()
	_build_distant_hills()


# ------------------------------------------------------------------ curve ----

## Gentle alternating bends heading towards -Z. The hill-free terrain and the
## truck physics stay flat, so only the ribbon curves.
func _generate_curve() -> Curve3D:
	var result := Curve3D.new()
	result.bake_interval = 1.0

	var phase_a := _rng.randf() * TAU
	var phase_b := _rng.randf() * TAU
	var points := maxi(3, int(road_length / 20.0))

	for i in points + 1:
		var travelled := float(i) / float(points) * road_length
		var wave := sin(travelled * 0.011 + phase_a) * 0.62 + sin(travelled * 0.027 + phase_b) * 0.38
		# Ramp the bend in so the road starts exactly at the origin, where the
		# truck spawns.
		var ramp := clampf(travelled / 60.0, 0.0, 1.0)
		result.add_point(Vector3(wave * bend_amplitude * ramp, 0.0, -travelled))

	return result


func _point(distance: float) -> Vector3:
	return curve.sample_baked(clampf(distance, 0.0, _baked_length))


func _tangent(distance: float) -> Vector3:
	var a := _point(distance - 0.6)
	var b := _point(distance + 0.6)
	var direction := (b - a).normalized()
	return direction if direction.length() > 0.001 else Vector3.FORWARD


func _right(distance: float) -> Vector3:
	return _tangent(distance).cross(Vector3.UP).normalized()


func _place(distance: float, lateral: float, height: float) -> Vector3:
	return _point(distance) + _right(distance) * lateral + Vector3.UP * height


## Basis with -Z pointing along the road, so meshes face the driving direction.
func _basis(distance: float) -> Basis:
	return Basis(_right(distance), Vector3.UP, -_tangent(distance))


# -------------------------------------------------------------- materials ----

func _create_materials() -> void:
	_asphalt = _mat(Color(0.075, 0.075, 0.085), 0.95)
	_asphalt.cull_mode = BaseMaterial3D.CULL_DISABLED

	_shoulder = _mat(Color(0.13, 0.12, 0.11), 1.0)
	_shoulder.cull_mode = BaseMaterial3D.CULL_DISABLED

	_paint = _mat(Color(0.86, 0.86, 0.80), 0.55)
	_paint.cull_mode = BaseMaterial3D.CULL_DISABLED

	_rail = _mat(Color(0.42, 0.44, 0.47), 0.42)
	_rail.metallic = 0.85

	_bark = _mat(Color(0.16, 0.13, 0.11), 1.0)
	_leaves = _mat(Color(0.07, 0.13, 0.09), 0.95)
	_rock = _mat(Color(0.16, 0.16, 0.17), 0.9)
	_metal = _mat(Color(0.2, 0.21, 0.23), 0.45)
	_metal.metallic = 0.8

	_lamp_glass = _mat(Color(1.0, 0.9, 0.7), 0.3)
	_lamp_glass.emission_enabled = true
	_lamp_glass.emission = Color(1.0, 0.86, 0.6)
	_lamp_glass.emission_energy_multiplier = 4.5

	_reflector = _mat(Color(0.95, 0.95, 0.9), 0.35)
	_reflector.emission_enabled = true
	_reflector.emission = Color(1.0, 0.55, 0.15)
	_reflector.emission_energy_multiplier = 1.6

	_sign_face = _mat(Color(0.85, 0.87, 0.9), 0.4)
	_sign_face.emission_enabled = true
	_sign_face.emission = Color(0.55, 0.6, 0.7)
	_sign_face.emission_energy_multiplier = 0.35

	_hill = _mat(Color(0.035, 0.04, 0.055), 1.0)


func _mat(colour: Color, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = roughness
	return material


# ----------------------------------------------------------------- meshes ----

## Adds a flat ribbon following the curve between two lateral offsets.
func _add_flat_quad(st: SurfaceTool, d0: float, d1: float, inner: float, outer: float, height: float) -> void:
	var a := _place(d0, inner, height)
	var b := _place(d0, outer, height)
	var c := _place(d1, outer, height)
	var d := _place(d1, inner, height)

	_add_triangle(st, a, c, b)
	_add_triangle(st, a, d, c)


## Adds a vertical ribbon (used for guardrail beams).
func _add_wall_quad(st: SurfaceTool, d0: float, d1: float, lateral: float, bottom: float, top: float) -> void:
	var a := _place(d0, lateral, bottom)
	var b := _place(d0, lateral, top)
	var c := _place(d1, lateral, top)
	var d := _place(d1, lateral, bottom)

	_add_triangle(st, a, b, c)
	_add_triangle(st, a, c, d)


func _add_triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	st.set_normal(Vector3.UP)
	st.add_vertex(a)
	st.set_normal(Vector3.UP)
	st.add_vertex(b)
	st.set_normal(Vector3.UP)
	st.add_vertex(c)


func _commit(st: SurfaceTool, node_name: String, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = st.commit()
	instance.material_override = material
	add_child(instance)
	return instance


# ---------------------------------------------------------------- surfaces ----

func _build_surface() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := road_width * 0.5
	var distance := 0.0
	while distance < _baked_length:
		var next := minf(distance + mesh_step, _baked_length)
		_add_flat_quad(st, distance, next, -half, half, 0.0)
		distance = next

	_commit(st, "Asphalt", _asphalt)


func _build_shoulders() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var inner := road_width * 0.5
	var outer := inner + shoulder_width
	var distance := 0.0

	while distance < _baked_length:
		var next := minf(distance + mesh_step, _baked_length)
		_add_flat_quad(st, distance, next, inner, outer, -0.06)
		_add_flat_quad(st, distance, next, -outer, -inner, -0.06)
		distance = next

	_commit(st, "Shoulders", _shoulder)


func _build_edge_lines() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var half := road_width * 0.5 - edge_line_offset
	var inner := half - 0.09
	var outer := half + 0.09
	var distance := 0.0

	while distance < _baked_length:
		var next := minf(distance + mesh_step, _baked_length)
		_add_flat_quad(st, distance, next, inner, outer, 0.012)
		_add_flat_quad(st, distance, next, -outer, -inner, 0.012)
		distance = next

	_commit(st, "EdgeLines", _paint)


func _build_centre_line() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var inner := -0.09
	var outer := 0.09
	var distance := 0.0
	var period := dash_length + dash_gap

	while distance < _baked_length:
		var end := minf(distance + dash_length, _baked_length)
		var segment := distance
		while segment < end:
			var next := minf(segment + mesh_step, end)
			_add_flat_quad(st, segment, next, inner, outer, 0.012)
			segment = next
		distance += period

	_commit(st, "CentreLine", _paint)


# --------------------------------------------------------------- furniture ----

func _build_guardrails() -> void:
	var lateral := road_width * 0.5 + shoulder_width + 0.35
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for side: float in [-1.0, 1.0]:
		var distance := 0.0
		while distance < _baked_length:
			var next := minf(distance + mesh_step, _baked_length)
			_add_wall_quad(st, distance, next, side * lateral, 0.62, 0.95)
			distance = next

	var beam := _commit(st, "GuardrailBeams", _rail)
	beam.name = "GuardrailBeams"

	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.14, 1.05, 0.14)

	var transforms: Array[Transform3D] = []
	var post_material := _metal
	var offset := 0.0
	while offset < _baked_length:
		for side: float in [-1.0, 1.0]:
			var basis := _basis(offset)
			transforms.append(Transform3D(basis, _place(offset, side * lateral, 0.52)))
		offset += rail_post_spacing

	_add_multimesh("GuardrailPosts", post_mesh, post_material, transforms)


func _build_delineators() -> void:
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.05
	post_mesh.bottom_radius = 0.07
	post_mesh.height = 1.15

	var transforms: Array[Transform3D] = []
	var cap_transforms: Array[Transform3D] = []
	var lateral := road_width * 0.5 + shoulder_width + 0.9

	var offset := delineator_spacing * 0.5
	while offset < _baked_length:
		for side: float in [-1.0, 1.0]:
			var basis := _basis(offset)
			var base := _place(offset, side * lateral, 0.55)
			transforms.append(Transform3D(basis, base))
			cap_transforms.append(Transform3D(basis, base + Vector3.UP * 0.48))
		offset += delineator_spacing

	_add_multimesh("DelineatorPosts", post_mesh, _metal, transforms)

	var cap_mesh := BoxMesh.new()
	cap_mesh.size = Vector3(0.12, 0.16, 0.05)
	_add_multimesh("DelineatorReflectors", cap_mesh, _reflector, cap_transforms)


func _build_lamps() -> void:
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.1
	pole_mesh.bottom_radius = 0.17
	pole_mesh.height = 9.0
	pole_mesh.radial_segments = 8

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(2.1, 0.11, 0.11)

	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.3
	bulb_mesh.height = 0.6
	bulb_mesh.radial_segments = 8
	bulb_mesh.rings = 4

	var pole_transforms: Array[Transform3D] = []
	var arm_transforms: Array[Transform3D] = []
	var bulb_transforms: Array[Transform3D] = []

	var lateral := road_width * 0.5 + shoulder_width + 1.6
	var index := 0
	var offset := lamp_spacing * 0.35

	while offset < _baked_length:
		var side := -1.0 if index % 2 == 0 else 1.0
		var basis := _basis(offset)
		var base := _place(offset, side * lateral, 0.0)
		var reach := -side * 1.75

		pole_transforms.append(Transform3D(basis, base + Vector3.UP * 4.5))
		arm_transforms.append(Transform3D(basis, _place(offset, side * lateral + reach * 0.5, 8.85)))
		bulb_transforms.append(Transform3D(basis, _place(offset, side * lateral + reach, 8.6)))

		var light := OmniLight3D.new()
		light.name = "Lamp%d" % index
		light.position = _place(offset, side * lateral + reach, 8.5)
		light.light_color = Color(1.0, 0.82, 0.55).lerp(Color(0.75, 0.85, 1.0), _rng.randf_range(0.0, 0.45))
		light.light_energy = _rng.randf_range(5.0, 7.5)
		light.omni_range = 34.0
		light.shadow_enabled = false
		add_child(light)

		index += 1
		offset += lamp_spacing

	_add_multimesh("LampPoles", pole_mesh, _metal, pole_transforms)
	_add_multimesh("LampArms", arm_mesh, _metal, arm_transforms)
	_add_multimesh("LampBulbs", bulb_mesh, _lamp_glass, bulb_transforms)


func _build_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.22
	trunk_mesh.bottom_radius = 0.34
	trunk_mesh.height = 4.6
	trunk_mesh.radial_segments = 6

	var canopy_mesh := CylinderMesh.new()
	canopy_mesh.top_radius = 0.0
	canopy_mesh.bottom_radius = 2.7
	canopy_mesh.height = 6.4
	canopy_mesh.radial_segments = 7

	var trunk_transforms: Array[Transform3D] = []
	var canopy_transforms: Array[Transform3D] = []
	var offset := 6.0

	while offset < _baked_length:
		var count := _rng.randi_range(0, max_trees_per_spot)

		for i in count:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var lateral := side * _rng.randf_range(road_width * 0.5 + 7.0, road_width * 0.5 + 26.0)
			var distance := offset + _rng.randf_range(-3.0, 3.0)
			var scale := _rng.randf_range(0.8, 1.35)

			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale, scale))
			var base := _place(distance, lateral, 0.0)

			trunk_transforms.append(Transform3D(basis, base + Vector3.UP * 2.3 * scale))
			canopy_transforms.append(Transform3D(basis, base + Vector3.UP * (4.6 * scale + 2.4 * scale)))

		offset += tree_spacing

	_add_multimesh("TreeTrunks", trunk_mesh, _bark, trunk_transforms)
	_add_multimesh("TreeCanopies", canopy_mesh, _leaves, canopy_transforms)


func _build_rocks() -> void:
	var rock_mesh := SphereMesh.new()
	rock_mesh.radius = 1.0
	rock_mesh.height = 1.3
	rock_mesh.radial_segments = 6
	rock_mesh.rings = 4

	var transforms: Array[Transform3D] = []
	var offset := rock_spacing * 0.5

	while offset < _baked_length:
		var side := -1.0 if _rng.randf() < 0.5 else 1.0
		var lateral := side * _rng.randf_range(road_width * 0.5 + 5.0, road_width * 0.5 + 20.0)
		var scale := _rng.randf_range(0.45, 1.7)

		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale * 0.75, scale))
		transforms.append(Transform3D(basis, _place(offset, lateral, scale * 0.28)))

		offset += rock_spacing

	_add_multimesh("Rocks", rock_mesh, _rock, transforms)


func _build_power_poles() -> void:
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.14
	pole_mesh.bottom_radius = 0.22
	pole_mesh.height = 10.5
	pole_mesh.radial_segments = 6

	var cross_mesh := BoxMesh.new()
	cross_mesh.size = Vector3(2.6, 0.12, 0.12)

	var pole_transforms: Array[Transform3D] = []
	var cross_transforms: Array[Transform3D] = []

	var lateral := -(road_width * 0.5 + shoulder_width + 5.0)
	var offset := pole_spacing * 0.5

	while offset < _baked_length:
		var basis := _basis(offset)
		var base := _place(offset, lateral, 0.0)
		pole_transforms.append(Transform3D(basis, base + Vector3.UP * 5.25))
		cross_transforms.append(Transform3D(basis, base + Vector3.UP * 9.6))
		offset += pole_spacing

	_add_multimesh("PowerPoles", pole_mesh, _bark, pole_transforms)
	_add_multimesh("PowerPoleCrossbars", cross_mesh, _metal, cross_transforms)


func _build_signs() -> void:
	if sign_count <= 0:
		return

	var panel_mesh := BoxMesh.new()
	panel_mesh.size = Vector3(1.7, 1.3, 0.07)

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.06
	post_mesh.bottom_radius = 0.08
	post_mesh.height = 2.5
	post_mesh.radial_segments = 6

	var step := _baked_length / float(sign_count + 1)

	for i in sign_count:
		var offset := step * float(i + 1)
		var side := 1.0 if i % 2 == 0 else -1.0
		var lateral := side * (road_width * 0.5 + shoulder_width + 2.2)
		var basis := _basis(offset)

		var root := Node3D.new()
		root.name = "Sign%d" % i
		root.transform = Transform3D(basis, _place(offset, lateral, 0.0))
		add_child(root)

		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = _metal
		post.position = Vector3(0.0, 1.25, 0.0)
		root.add_child(post)

		var panel := MeshInstance3D.new()
		panel.mesh = panel_mesh
		panel.material_override = _sign_face
		panel.position = Vector3(0.0, 2.75, 0.0)
		root.add_child(panel)


func _build_distant_hills() -> void:
	var hill_mesh := CylinderMesh.new()
	hill_mesh.top_radius = 0.0
	hill_mesh.bottom_radius = 1.0
	hill_mesh.height = 1.0
	hill_mesh.radial_segments = 7
	hill_mesh.rings = 1

	var transforms: Array[Transform3D] = []

	for i in hill_count:
		var distance := _rng.randf_range(0.0, _baked_length)
		var side := -1.0 if i % 2 == 0 else 1.0
		var lateral := side * _rng.randf_range(hill_distance * 0.8, hill_distance * 1.4)
		var scale := _rng.randf_range(55.0, 130.0)

		var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)) \
			.scaled(Vector3(scale, _rng.randf_range(28.0, 85.0), scale))
		transforms.append(Transform3D(basis, _place(distance, lateral, -2.0)))

	_add_multimesh("DistantHills", hill_mesh, _hill, transforms)


# ------------------------------------------------------------------ helper ----

func _add_multimesh(node_name: String, mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = mesh
	multimesh.instance_count = transforms.size()

	for i in transforms.size():
		multimesh.set_instance_transform(i, transforms[i])

	var instance := MultiMeshInstance3D.new()
	instance.name = node_name
	instance.multimesh = multimesh
	instance.material_override = material
	add_child(instance)
	return instance
