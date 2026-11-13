class_name RoadBuilder
extends Node3D
## Builds the whole roadside procedurally from a Curve3D: asphalt, shoulders,
## markings, guardrails, delineator posts, street lamps, trees, rocks, power
## poles, signs and distant hills.
##
## No imported assets, everything is generated at runtime, so a fresh clone has
## a detailed road. Repeated props go through MultiMesh to keep draw calls low.

@export_group("Road")
@export var road_length := 1500.0
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

@export_group("Extra detail")
@export var stud_spacing := 8.0
@export var fence_post_spacing := 6.0
@export var shrub_spacing := 7.0
@export var km_marker_spacing := 100.0
@export var wire_sag := 1.1
@export var overpass_at := 0.55

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
var _wire_material: StandardMaterial3D
var _concrete: StandardMaterial3D
var _city_glow: StandardMaterial3D

## Lateral offset of the guardrail from the centre line, set while building.
var rail_lateral := 0.0
## How many collision boxes the guardrails produced.
var collision_shapes := 0
var _wetness := 0.0
var _dry_asphalt_roughness := 0.95

## Radius and position of every solid roadside prop, for collision building.
var prop_spots: Array[Dictionary] = []
var prop_shapes := 0
## Top of every tall city block, for the warning beacons.
var city_tops: Array[Vector3] = []
var beacon_count := 0
## How many blocks and lit windows the city got. Test hooks.
var city_block_count := 0
var city_window_count := 0
var city_street_count := 0
var city_lamp_count := 0
var rooftop_count := 0
var gantry_sign_count := 0
## Route furniture from the details pass. Test hooks.
var toll_distance := 0.0
var toll_booth_count := 0
## Lateral position of the inner booth islands: sets the centre-lane width.
var toll_inner_island_x := 0.0
var billboard_count := 0
var chevron_count := 0
var rest_stop_count := 0
var lake_blob_count := 0
var city_tier_count := 0
## Current lamp dimmer, 0 by day and 1 at night. Test hook.
var lamp_level := 1.0

var _lamp_lights: Array[OmniLight3D] = []
var _lamp_base_energy: Array[float] = []
var _window_mat: StandardMaterial3D

var _beacon_material: StandardMaterial3D


func _ready() -> void:
	build()


## Generates everything. Public so tests can build without the scene tree.
func build() -> void:
	add_to_group("rv_time_aware")
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
	_build_power_wires()
	_build_signs()
	_build_gantry_signs()
	_build_km_markers()
	_build_road_studs()
	_build_fence()
	_build_shrubs()
	_build_overpass()
	_build_rest_stop()
	_build_lake()
	_build_billboards()
	_build_chevrons()
	_build_toll_plaza()
	_build_distant_hills()
	_build_city_glow()
	_build_prop_collision()
	_build_collision()


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
	_dry_asphalt_roughness = _asphalt.roughness

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

	_wire_material = _mat(Color(0.05, 0.05, 0.06), 0.6)
	_wire_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	_concrete = _mat(Color(0.22, 0.21, 0.2), 0.85)

	_city_glow = _mat(Color(0.13, 0.15, 0.21), 0.85)
	_city_glow.emission_enabled = true
	_city_glow.emission = Color(0.9, 0.68, 0.4)
	_city_glow.emission_energy_multiplier = 0.25


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


## 0 = dry tarmac, 1 = soaked. Rain drives this.
## TimeOfDay calls this every frame: street lamps, lamp glass, city windows,
## the skyline glow and the tower beacons all follow the same dimmer.
func apply_time_of_day(night_factor: float) -> void:
	lamp_level = clampf(night_factor, 0.0, 1.0)

	for i in _lamp_lights.size():
		_lamp_lights[i].visible = lamp_level > 0.03
		_lamp_lights[i].light_energy = _lamp_base_energy[i] * lamp_level

	if _lamp_glass != null:
		_lamp_glass.emission_energy_multiplier = lerpf(0.12, 4.5, lamp_level)

	if _window_mat != null:
		_window_mat.emission_energy_multiplier = lerpf(0.1, 2.4, lamp_level)

	if _city_glow != null:
		_city_glow.emission_energy_multiplier = lerpf(0.03, 0.25, lamp_level)

	if _beacon_material != null:
		_beacon_material.emission_energy_multiplier = lerpf(0.0, 3.0, lamp_level)


func set_wetness(amount: float) -> void:
	_wetness = clampf(amount, 0.0, 1.0)

	if _asphalt == null:
		return

	_asphalt.roughness = lerpf(_dry_asphalt_roughness, 0.16, _wetness)
	_asphalt.metallic = lerpf(0.0, 0.6, _wetness)
	_asphalt.metallic_specular = lerpf(0.5, 0.9, _wetness)

	if _shoulder != null:
		_shoulder.roughness = lerpf(1.0, 0.35, _wetness)


func wetness() -> float:
	return _wetness


## The guardrails are just geometry, so give them boxes to stop the truck.
func _build_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "GuardrailCollision"

	var lateral := road_width * 0.5 + shoulder_width + 0.35
	rail_lateral = lateral

	var shape := BoxShape3D.new()
	shape.size = Vector3(0.32, 1.25, mesh_step + 0.15)

	var distance := 0.0
	while distance < _baked_length:
		var next := minf(distance + mesh_step, _baked_length)
		var mid := clampf((distance + next) * 0.5, 0.0, _baked_length)

		for side: float in [-1.0, 1.0]:
			var collision := CollisionShape3D.new()
			collision.shape = shape
			collision.transform = Transform3D(_basis(mid), _place(mid, side * lateral, 0.66))
			body.add_child(collision)
			collision_shapes += 1

		distance = next

	add_child(body)


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
		_lamp_lights.append(light)
		_lamp_base_energy.append(light.light_energy)

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
			prop_spots.append({"position": base, "radius": 0.55 * scale})
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
		var rock_position := _place(offset, lateral, scale * 0.28)
		transforms.append(Transform3D(basis, rock_position))
		prop_spots.append({"position": rock_position, "radius": 0.95 * scale})

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


## Overhead gantry signs, the way a real highway announces the city.
func _build_gantry_signs() -> void:
	var panel_material := _mat(Color(0.04, 0.22, 0.11), 0.6)

	var entries: Array = [
		[0.07, "NORTHBOUND"],
		[0.31, "CITY CENTRE"],
	]

	for entry in entries:
		var fraction: float = entry[0]
		var distance := _baked_length * fraction

		var root := Node3D.new()
		root.name = "GantrySign%d" % gantry_sign_count
		root.transform = Transform3D(_basis(distance), _place(distance, 0.0, 0.0))
		add_child(root)

		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.14
		post_mesh.bottom_radius = 0.18
		post_mesh.height = 6.4
		post_mesh.radial_segments = 8

		for side: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.material_override = _metal
			post.position = Vector3(side * (road_width * 0.5 + 1.4), 3.2, 0.0)
			root.add_child(post)

		var beam_mesh := BoxMesh.new()
		beam_mesh.size = Vector3(road_width + 3.2, 0.35, 0.35)

		var beam := MeshInstance3D.new()
		beam.mesh = beam_mesh
		beam.material_override = _metal
		beam.position = Vector3(0.0, 6.2, 0.0)
		root.add_child(beam)

		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(6.8, 1.6, 0.18)

		var panel := MeshInstance3D.new()
		panel.mesh = panel_mesh
		panel.material_override = panel_material
		panel.position = Vector3(0.0, 5.15, 0.0)
		root.add_child(panel)

		var label := Label3D.new()
		label.name = "Label"
		label.text = String(entry[1])
		label.font_size = 128
		label.pixel_size = 0.0085
		label.modulate = Color(0.92, 0.96, 0.92)
		label.position = Vector3(0.0, 5.15, 0.22)
		root.add_child(label)

		gantry_sign_count += 1


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


func _build_power_wires() -> void:
	# Catenary wires between consecutive crossbars. Flat ribbons with culling
	# disabled, so they read from below as well.
	var lateral := -(road_width * 0.5 + shoulder_width + 5.0)
	var spacing := pole_spacing
	var sag := wire_sag

	var pole_positions: Array[Vector3] = []
	var offset := spacing * 0.5
	while offset < _baked_length:
		pole_positions.append(_place(offset, lateral, 9.6))
		offset += spacing

	if pole_positions.size() < 2:
		return

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in pole_positions.size() - 1:
		var from := pole_positions[i]
		var to := pole_positions[i + 1]

		for wire_side: float in [-1.15, 1.15]:
			var a := from + _right(0.0) * wire_side
			var b := to + _right(0.0) * wire_side
			var previous := a

			var segments := 10
			for step in range(1, segments + 1):
				var t := float(step) / float(segments)
				var point := a.lerp(b, t) - Vector3.UP * (sin(t * PI) * sag)
				_add_wire_quad(st, previous, point)
				previous = point

	_commit(st, "PowerWires", _wire_material)


func _add_wire_quad(st: SurfaceTool, from: Vector3, to: Vector3) -> void:
	var half := 0.035
	var across := (to - from).cross(Vector3.UP).normalized() * half

	st.set_normal(Vector3.UP)
	st.add_vertex(from - across)
	st.set_normal(Vector3.UP)
	st.add_vertex(to - across)
	st.set_normal(Vector3.UP)
	st.add_vertex(to + across)

	st.set_normal(Vector3.UP)
	st.add_vertex(from - across)
	st.set_normal(Vector3.UP)
	st.add_vertex(to + across)
	st.set_normal(Vector3.UP)
	st.add_vertex(from + across)


func _build_road_studs() -> void:
	# Cat's eyes along the centre line, like a real highway at night.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(0.14, 0.05, 0.22)

	var transforms: Array[Transform3D] = []
	var offset := stud_spacing * 0.5

	while offset < _baked_length:
		transforms.append(Transform3D(_basis(offset), _place(offset, 0.0, 0.02)))
		offset += stud_spacing

	_add_multimesh("RoadStuds", mesh, _reflector, transforms)


func _build_km_markers() -> void:
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.05
	post_mesh.bottom_radius = 0.06
	post_mesh.height = 1.1
	post_mesh.radial_segments = 5

	var plate_mesh := BoxMesh.new()
	plate_mesh.size = Vector3(0.34, 0.46, 0.05)

	var lateral := road_width * 0.5 + shoulder_width + 1.1
	var post_transforms: Array[Transform3D] = []
	var plate_transforms: Array[Transform3D] = []

	var offset := km_marker_spacing
	while offset < _baked_length:
		var basis := _basis(offset)
		post_transforms.append(Transform3D(basis, _place(offset, lateral, 0.55)))
		plate_transforms.append(Transform3D(basis, _place(offset, lateral, 1.15)))
		offset += km_marker_spacing

	_add_multimesh("KmMarkerPosts", post_mesh, _metal, post_transforms)
	_add_multimesh("KmMarkerPlates", plate_mesh, _sign_face, plate_transforms)


func _build_fence() -> void:
	# Simple post-and-rail fence on the far side, behind the trees.
	var lateral := -(road_width * 0.5 + shoulder_width + 11.0)

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.07
	post_mesh.bottom_radius = 0.09
	post_mesh.height = 1.35
	post_mesh.radial_segments = 5

	var post_transforms: Array[Transform3D] = []
	var offset := 0.0
	while offset < _baked_length:
		post_transforms.append(Transform3D(_basis(offset), _place(offset, lateral, 0.67)))
		offset += fence_post_spacing

	_add_multimesh("FencePosts", post_mesh, _bark, post_transforms)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for height: float in [0.85, 1.25]:
		var distance := 0.0
		while distance < _baked_length:
			var next := minf(distance + mesh_step, _baked_length)
			_add_wall_quad(st, distance, next, lateral, height - 0.04, height + 0.04)
			distance = next

	_commit(st, "FenceRails", _bark)


func _build_shrubs() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0
	mesh.bottom_radius = 0.75
	mesh.height = 1.15
	mesh.radial_segments = 5

	var transforms: Array[Transform3D] = []
	var offset := 2.0

	while offset < _baked_length:
		if _rng.randf() < 0.55:
			var side := -1.0 if _rng.randf() < 0.5 else 1.0
			var lateral := side * _rng.randf_range(road_width * 0.5 + 4.2, road_width * 0.5 + 13.0)
			var scale := _rng.randf_range(0.5, 1.3)
			var basis := Basis(Vector3.UP, _rng.randf_range(0.0, TAU)).scaled(Vector3(scale, scale, scale))
			transforms.append(Transform3D(basis, _place(offset, lateral, 0.5 * scale)))
		offset += shrub_spacing

	_add_multimesh("Shrubs", mesh, _leaves, transforms)


func _build_overpass() -> void:
	var distance := _baked_length * overpass_at
	var basis := _basis(distance)
	var centre := _place(distance, 0.0, 0.0)

	var span := road_width + 2.0 * (shoulder_width + 2.5)
	var deck_height := 6.2

	var root := Node3D.new()
	root.name = "Overpass"
	root.transform = Transform3D(basis, centre)
	add_child(root)

	var deck_mesh := BoxMesh.new()
	deck_mesh.size = Vector3(span, 0.85, 7.5)
	var deck := MeshInstance3D.new()
	deck.name = "Deck"
	deck.mesh = deck_mesh
	deck.material_override = _concrete
	deck.position = Vector3(0.0, deck_height, 0.0)
	root.add_child(deck)

	for side: float in [-1.0, 1.0]:
		var parapet_mesh := BoxMesh.new()
		parapet_mesh.size = Vector3(span, 0.9, 0.35)

		var parapet := MeshInstance3D.new()
		parapet.mesh = parapet_mesh
		parapet.material_override = _concrete
		parapet.position = Vector3(0.0, deck_height + 0.85, side * 3.5)
		root.add_child(parapet)

		var pillar_mesh := BoxMesh.new()
		pillar_mesh.size = Vector3(1.5, deck_height, 1.5)

		var pillar := MeshInstance3D.new()
		pillar.mesh = pillar_mesh
		pillar.material_override = _concrete
		pillar.position = Vector3(side * (span * 0.5 - 1.6), deck_height * 0.5, 0.0)
		root.add_child(pillar)

		prop_spots.append({
			"position": centre + basis * pillar.position,
			"radius": 1.1,
			"box": Vector3(1.5, deck_height, 1.5),
		})


func _build_city_glow() -> void:
	# A real city, laid out like one: city blocks on a street grid. Along the
	# road the districts follow the curve in rows and columns aligned to it,
	# with avenue gaps between the columns and cross streets between the
	# rows; past the end of the road a denser downtown grid takes over.
	# Heights grow towards the city, so the skyline builds up as you arrive.
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)

	var transforms: Array[Transform3D] = []
	var road_points: Array[Vector3] = []
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 7

	var pitch := 36.0
	var city_start := _baked_length * 0.30

	# The town you set out from: low blocks hugging the first stretch of
	# road, so the run reads as town -> countryside -> toll -> big city.
	var town_distance := 70.0

	while town_distance < _baked_length * 0.16:
		for side: float in [-1.0, 1.0]:
			for column in 2:
				if rng.randf() < 0.2:
					continue

				var town_w := rng.randf_range(14.0, 22.0)
				var town_h := rng.randf_range(6.0, 18.0)
				var town_basis := _basis(town_distance).scaled(Vector3(town_w, town_h, town_w))
				transforms.append(Transform3D(town_basis, _place(town_distance, side * (46.0 + float(column) * 30.0), town_h * 0.5)))
				road_points.append(_place(town_distance, 0.0, 0.0))

		town_distance += 34.0

	# Districts alongside the road, on both sides.
	var distance := city_start + pitch * 0.5

	while distance < _baked_length - 12.0:
		var downtown := clampf((distance / _baked_length - 0.3) / 0.7, 0.0, 1.0)

		for side: float in [-1.0, 1.0]:
			for column in 6:
				if rng.randf() < 0.14:
					continue  # a park, a car park, a gap in the street wall

				var width := rng.randf_range(22.0, 28.0)
				var depth := rng.randf_range(22.0, 28.0)
				var height := rng.randf_range(10.0, 26.0) \
					+ downtown * downtown * rng.randf_range(10.0, 55.0)
				var lateral := side * (54.0 + float(column) * pitch)

				var basis := _basis(distance).scaled(Vector3(width, height, depth))
				transforms.append(Transform3D(basis, _place(distance, lateral, height * 0.5)))
				road_points.append(_place(distance, 0.0, 0.0))

		distance += pitch

	# Downtown, past the end of the road: a full grid around the corridor
	# the road arrives on.
	var end_point := _point(_baked_length)
	var end_direction := _tangent(_baked_length)
	var end_right := _right(_baked_length)
	var end_basis := Basis(end_right, Vector3.UP, -end_direction)

	for row in 9:
		for column in range(-7, 8):
			if column == 0 and row < 2:
				continue  # the road's own corridor into the city

			if rng.randf() < 0.12:
				continue

			var width := rng.randf_range(22.0, 30.0)
			var depth := rng.randf_range(22.0, 30.0)
			var centre_factor := 1.15 - minf(absf(float(column)), 7.0) * 0.06
			var height := rng.randf_range(22.0, 60.0) * centre_factor + rng.randf_range(0.0, 30.0)
			var ahead := 26.0 + float(row) * pitch
			var lateral := float(column) * pitch

			var position := end_point + end_direction * ahead + end_right * lateral + Vector3.UP * (height * 0.5)
			transforms.append(Transform3D(end_basis.scaled(Vector3(width, height, depth)), position))
			road_points.append(end_point)

	city_block_count = transforms.size()
	_add_multimesh("CityBlocks", mesh, _city_glow, transforms)

	# Stepped crowns on the taller towers, so the skyline is not a row of
	# shoeboxes: a narrower tier on top of every block over 34 m.
	var tier_transforms: Array[Transform3D] = []

	for block in transforms:
		var size := block.basis.get_scale()

		if size.y < 34.0:
			continue

		var tier_height := size.y * 0.22
		var tier_basis := Basis(block.basis.x.normalized(), Vector3.UP, block.basis.z.normalized()) \
			.scaled(Vector3(size.x * 0.55, tier_height, size.z * 0.55))
		tier_transforms.append(Transform3D(tier_basis,
			block.origin + Vector3.UP * (size.y * 0.5 + tier_height * 0.5 - 0.1)))

	_add_multimesh("CityTiers", mesh, _city_glow, tier_transforms)
	city_tier_count = tier_transforms.size()
	_build_city_avenues(city_start, pitch)
	_build_city_streets(end_point, end_direction, end_right)
	_build_city_windows(transforms, road_points, rng)


## Avenues and cross streets for the districts alongside the road, drawn as
## dark ribbons on the ground so the blocks visibly sit in a street grid.
func _build_city_avenues(city_start: float, pitch: float) -> void:
	var material := _mat(Color(0.05, 0.055, 0.07), 0.95)
	material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# Avenues in the gaps between the building columns (columns sit at
	# 54/90/126... m with at most 28 m footprints, so these bands stay clear).
	var bands: Array = [[28.0, 40.0], [68.0, 76.0], [104.0, 112.0], [140.0, 148.0], [176.0, 184.0], [212.0, 220.0]]
	var streets := 0

	for side: float in [-1.0, 1.0]:
		for band in bands:
			_add_flat_quad(st, city_start, _baked_length, side * float(band[0]), side * float(band[1]), 0.03)
			streets += 1

	# Cross streets in the gaps between the building rows.
	var distance := city_start + pitch * 0.5

	while distance + pitch * 0.5 < _baked_length - 6.0:
		var from := distance + pitch * 0.5 + 1.0
		var to := distance + pitch * 1.5 - 1.0
		_add_flat_quad(st, from, to, 28.0, 250.0, 0.03)
		_add_flat_quad(st, from, to, -250.0, -28.0, 0.03)
		streets += 2
		distance += pitch * 2.0

	_commit(st, "CityAvenues", material)
	city_street_count += streets

	# Sidewalks between the road and the first avenue, both sides.
	var walk_material := _mat(Color(0.16, 0.16, 0.17), 1.0)
	walk_material.cull_mode = BaseMaterial3D.CULL_DISABLED

	var walk := SurfaceTool.new()
	walk.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_flat_quad(walk, city_start, _baked_length, 23.5, 27.5, 0.05)
	_add_flat_quad(walk, city_start, _baked_length, -27.5, -23.5, 0.05)
	_commit(walk, "CitySidewalks", walk_material)

	# City street lamps along the first avenues. The bulbs share the road
	# lamps' glass material, so the day/night dimmer reaches them too.
	var pole_mesh := CylinderMesh.new()
	pole_mesh.top_radius = 0.07
	pole_mesh.bottom_radius = 0.11
	pole_mesh.height = 6.5
	pole_mesh.radial_segments = 6

	var bulb_mesh := SphereMesh.new()
	bulb_mesh.radius = 0.22
	bulb_mesh.height = 0.44
	bulb_mesh.radial_segments = 6
	bulb_mesh.rings = 3

	var pole_transforms: Array[Transform3D] = []
	var bulb_transforms: Array[Transform3D] = []
	var lamp_distance := city_start + 12.0

	while lamp_distance < _baked_length:
		for lateral: float in [-34.0, 34.0, -72.0, 72.0]:
			var basis := _basis(lamp_distance)
			pole_transforms.append(Transform3D(basis, _place(lamp_distance, lateral, 3.25)))
			bulb_transforms.append(Transform3D(basis, _place(lamp_distance, lateral, 6.4)))

		lamp_distance += 26.0

	_add_multimesh("CityLampPoles", pole_mesh, _metal, pole_transforms)
	_add_multimesh("CityLampBulbs", bulb_mesh, _lamp_glass, bulb_transforms)
	city_lamp_count = bulb_transforms.size()



## The toll plaza, roughly halfway between the town you leave and the city
## you are heading to: canopy, four booth islands, three barrier arms.
func _build_toll_plaza() -> void:
	toll_distance = _baked_length * 0.48

	var plaza := TollPlaza.new()
	plaza.name = "TollPlaza"
	plaza.toll_distance = toll_distance
	plaza.transform = Transform3D(_basis(toll_distance), _place(toll_distance, 0.0, 0.0))
	add_child(plaza)

	var slab_mesh := BoxMesh.new()
	slab_mesh.size = Vector3(19.5, 0.1, 48.0)

	var slab := MeshInstance3D.new()
	slab.name = "PlazaSlab"
	slab.mesh = slab_mesh
	slab.material_override = _concrete
	slab.position = Vector3(0.0, 0.0, 0.0)
	plaza.add_child(slab)

	# Canopy on four pillars.
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.16
	pillar_mesh.bottom_radius = 0.2
	pillar_mesh.height = 5.7
	pillar_mesh.radial_segments = 8

	for px: float in [-8.8, 8.8]:
		for pz: float in [-3.4, 3.4]:
			var pillar := MeshInstance3D.new()
			pillar.mesh = pillar_mesh
			pillar.material_override = _metal
			pillar.position = Vector3(px, 2.85, pz)
			plaza.add_child(pillar)
			prop_spots.append({"position": plaza.transform * pillar.position, "radius": 0.35})

	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(19.5, 0.45, 9.5)

	var roof := MeshInstance3D.new()
	roof.name = "Canopy"
	roof.mesh = roof_mesh
	roof.material_override = _concrete
	roof.position = Vector3(0.0, 5.7, 0.0)
	plaza.add_child(roof)

	var sign := Label3D.new()
	sign.name = "TollSign"
	sign.text = "TOLL"
	sign.font_size = 160
	sign.pixel_size = 0.01
	sign.modulate = Color(1.0, 0.85, 0.4)
	sign.position = Vector3(0.0, 5.7, 4.95)
	plaza.add_child(sign)

	# Booth islands between the lanes. Round booths, not boxes.
	var island_mesh := BoxMesh.new()
	island_mesh.size = Vector3(0.8, 0.24, 7.5)

	var booth_mesh := CylinderMesh.new()
	booth_mesh.top_radius = 0.44
	booth_mesh.bottom_radius = 0.5
	booth_mesh.height = 2.25
	booth_mesh.radial_segments = 10

	var booth_roof_mesh := CylinderMesh.new()
	booth_roof_mesh.top_radius = 0.68
	booth_roof_mesh.bottom_radius = 0.68
	booth_roof_mesh.height = 0.16
	booth_roof_mesh.radial_segments = 10

	toll_inner_island_x = 2.0

	for lateral: float in [-5.6, -2.0, 2.0, 5.6]:
		var island := MeshInstance3D.new()
		island.mesh = island_mesh
		island.material_override = _concrete
		island.position = Vector3(lateral, 0.12, 0.0)
		plaza.add_child(island)

		var booth := MeshInstance3D.new()
		booth.mesh = booth_mesh
		booth.material_override = _metal
		booth.position = Vector3(lateral, 1.36, 0.0)
		plaza.add_child(booth)

		var booth_roof := MeshInstance3D.new()
		booth_roof.mesh = booth_roof_mesh
		booth_roof.material_override = _concrete
		booth_roof.position = Vector3(lateral, 2.62, 0.0)
		plaza.add_child(booth_roof)

		# Slimmer than the island and centred on the booth: at 1.3 m wide the
		# box corners reached 5 cm into the centre lane and trucks landed on
		# top of them after a teleport.
		prop_spots.append({
			"position": plaza.transform * Vector3(lateral, 1.4, 0.0),
			"radius": 0.9,
			"box": Vector3(0.75, 2.8, 7.0),
			"basis": plaza.transform.basis,
		})
		toll_booth_count += 1

	# Barrier arms: one per lane, all hinged on the booth line.
	var arm_red := StandardMaterial3D.new()
	arm_red.albedo_color = Color(0.85, 0.12, 0.1)
	arm_red.emission_enabled = true
	arm_red.emission = Color(0.9, 0.15, 0.1)
	arm_red.emission_energy_multiplier = 0.7

	var arm_white := _mat(Color(0.9, 0.9, 0.92), 0.5)

	var post_mesh := BoxMesh.new()
	post_mesh.size = Vector3(0.2, 1.05, 0.2)

	var arm_mesh := BoxMesh.new()
	arm_mesh.size = Vector3(0.78, 0.11, 0.11)

	var arm_setup: Array = [[-2.0, -3.3], [2.0, 0.0], [5.6, 3.3]]

	for i in arm_setup.size():
		var pivot_x: float = arm_setup[i][0]

		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = _metal
		post.position = Vector3(pivot_x, 0.52, 1.15)
		plaza.add_child(post)

		var pivot := Node3D.new()
		pivot.name = "Arm%d" % i
		pivot.position = Vector3(pivot_x, 1.02, 1.15)
		plaza.add_child(pivot)

		for segment in 3:
			var bar := MeshInstance3D.new()
			bar.mesh = arm_mesh
			bar.material_override = arm_red if segment % 2 == 0 else arm_white
			bar.position = Vector3(-(0.45 + float(segment) * 0.8), 0.0, 0.0)
			pivot.add_child(bar)

	# Lane lights on the canopy edge: red shut, green go.
	var red_material := StandardMaterial3D.new()
	red_material.albedo_color = Color(1.0, 0.15, 0.1)
	red_material.emission_enabled = true
	red_material.emission = Color(1.0, 0.12, 0.08)
	red_material.emission_energy_multiplier = 3.0
	red_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var green_material := StandardMaterial3D.new()
	green_material.albedo_color = Color(0.2, 1.0, 0.35)
	green_material.emission_enabled = true
	green_material.emission = Color(0.15, 1.0, 0.3)
	green_material.emission_energy_multiplier = 3.0
	green_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var lamp_mesh := SphereMesh.new()
	lamp_mesh.radius = 0.15
	lamp_mesh.height = 0.3
	lamp_mesh.radial_segments = 8
	lamp_mesh.rings = 4

	for i in arm_setup.size():
		var lane_x: float = arm_setup[i][1]

		var red := MeshInstance3D.new()
		red.name = "LaneRed%d" % i
		red.mesh = lamp_mesh
		red.material_override = red_material
		red.position = Vector3(lane_x, 4.85, 4.55)
		plaza.add_child(red)

		var green := MeshInstance3D.new()
		green.name = "LaneGreen%d" % i
		green.mesh = lamp_mesh
		green.material_override = green_material
		green.position = Vector3(lane_x, 4.85, 4.55)
		green.visible = false
		plaza.add_child(green)


## A rest stop on the right: layby, shelter, bench and a lamp.
func _build_rest_stop() -> void:
	rest_stop_count = 1
	var distance := _baked_length * 0.22

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_add_flat_quad(st, distance - 34.0, distance + 34.0, 9.6, 17.5, 0.015)
	_commit(st, "RestLayby", _asphalt)

	var root := Node3D.new()
	root.name = "RestStop"
	root.transform = Transform3D(_basis(distance), _place(distance, 0.0, 0.0))
	add_child(root)

	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = 0.08
	post_mesh.bottom_radius = 0.1
	post_mesh.height = 2.6
	post_mesh.radial_segments = 6

	for px: float in [-1.7, 1.7]:
		for pz: float in [-1.15, 1.15]:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.material_override = _bark
			post.position = Vector3(14.5 + px, 1.3, pz)
			root.add_child(post)
			prop_spots.append({"position": root.transform * post.position, "radius": 0.22})

	var shelter_roof_mesh := BoxMesh.new()
	shelter_roof_mesh.size = Vector3(4.4, 0.16, 3.2)

	var shelter_roof := MeshInstance3D.new()
	shelter_roof.mesh = shelter_roof_mesh
	shelter_roof.material_override = _concrete
	shelter_roof.position = Vector3(14.5, 2.65, 0.0)
	root.add_child(shelter_roof)

	var bench_mesh := BoxMesh.new()
	bench_mesh.size = Vector3(2.6, 0.12, 0.5)

	var bench := MeshInstance3D.new()
	bench.mesh = bench_mesh
	bench.material_override = _bark
	bench.position = Vector3(14.5, 0.55, 0.0)
	root.add_child(bench)

	# A lamp over the shelter, fed into the same dimmer as the road lamps.
	var light := OmniLight3D.new()
	light.name = "RestStopLamp"
	light.position = Vector3(14.5, 3.4, 0.0)
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = 5.0
	light.omni_range = 26.0
	light.shadow_enabled = false
	root.add_child(light)
	_lamp_lights.append(light)
	_lamp_base_energy.append(light.light_energy)


## A lake beside the road: overlapping flattened spheres read as water.
func _build_lake() -> void:
	var water := _mat(Color(0.06, 0.14, 0.22), 0.08)
	water.metallic = 0.65
	water.metallic_specular = 0.9

	var mesh := SphereMesh.new()
	mesh.radius = 1.0
	mesh.height = 2.0
	mesh.radial_segments = 14
	mesh.rings = 6

	var transforms: Array[Transform3D] = []
	var centre := _baked_length * 0.42
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 31

	for i in 6:
		var radius := rng.randf_range(16.0, 30.0)
		var position := _place(centre + rng.randf_range(-42.0, 42.0), 96.0 + rng.randf_range(-26.0, 34.0), 0.0)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(radius, 0.25, radius))
		transforms.append(Transform3D(basis, position))

	_add_multimesh("LakeSurface", mesh, water, transforms)
	lake_blob_count = transforms.size()


## Billboards: the roadside economy announcing itself.
func _build_billboards() -> void:
	var entries: Array = [
		[0.18, 1.0, "ICE COLD COLA"],
		[0.62, -1.0, "HOTEL - NEXT EXIT"],
		[0.85, 1.0, "DINER 24H - 500 M"],
	]

	for entry in entries:
		var distance := _baked_length * float(entry[0])
		var side: float = entry[1]
		var lateral := side * (road_width * 0.5 + 8.0)

		var root := Node3D.new()
		root.name = "Billboard%d" % billboard_count
		root.transform = Transform3D(_basis(distance), _place(distance, lateral, 0.0))
		add_child(root)

		var post_mesh := CylinderMesh.new()
		post_mesh.top_radius = 0.14
		post_mesh.bottom_radius = 0.18
		post_mesh.height = 5.2
		post_mesh.radial_segments = 6

		for px: float in [-2.2, 2.2]:
			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.material_override = _metal
			post.position = Vector3(px, 2.6, 0.0)
			root.add_child(post)

		var panel_mesh := BoxMesh.new()
		panel_mesh.size = Vector3(7.2, 2.8, 0.22)

		var panel := MeshInstance3D.new()
		panel.mesh = panel_mesh
		panel.material_override = _sign_face
		panel.position = Vector3(0.0, 5.6, 0.0)
		root.add_child(panel)

		var label := Label3D.new()
		label.name = "Label"
		label.text = String(entry[2])
		label.font_size = 110
		label.pixel_size = 0.011
		label.modulate = Color(0.1, 0.12, 0.2)
		label.position = Vector3(0.0, 5.6, 0.2)
		root.add_child(label)

		billboard_count += 1


## Chevron boards on the outside of the sharper bends.
func _build_chevrons() -> void:
	var last_placed := -200.0
	var distance := 50.0

	while distance < _baked_length - 40.0:
		var before := _tangent(distance - 14.0)
		var after := _tangent(distance + 14.0)

		if before.angle_to(after) > 0.07 and distance - last_placed > 90.0:
			# Outside of the bend: left-hand bends open to the right.
			var turn := before.cross(after).y
			var side := 1.0 if turn > 0.0 else -1.0

			var root := Node3D.new()
			root.name = "Chevron%d" % chevron_count
			root.transform = Transform3D(_basis(distance), _place(distance, side * 10.6, 0.0))
			add_child(root)

			var post_mesh := CylinderMesh.new()
			post_mesh.top_radius = 0.06
			post_mesh.bottom_radius = 0.08
			post_mesh.height = 1.5
			post_mesh.radial_segments = 5

			var post := MeshInstance3D.new()
			post.mesh = post_mesh
			post.material_override = _metal
			post.position = Vector3(0.0, 0.75, 0.0)
			root.add_child(post)

			var panel_mesh := BoxMesh.new()
			panel_mesh.size = Vector3(1.6, 0.6, 0.06)

			var panel := MeshInstance3D.new()
			panel.mesh = panel_mesh
			panel.material_override = _sign_face
			panel.position = Vector3(0.0, 1.55, 0.0)
			root.add_child(panel)

			var slat_mesh := BoxMesh.new()
			slat_mesh.size = Vector3(0.5, 0.13, 0.05)

			for i in 3:
				var slat := MeshInstance3D.new()
				slat.mesh = slat_mesh
				slat.material_override = _reflector
				slat.position = Vector3(-0.5 + float(i) * 0.5, 1.55, 0.06)
				slat.rotation.z = -0.6 * side
				root.add_child(slat)

			chevron_count += 1
			last_placed = distance

		distance += 30.0


## A street grid under the end-of-road city, so the blocks sit in streets
## instead of floating on the plain. Dark ribbons just above the ground.
func _build_city_streets(end_point: Vector3, direction: Vector3, right: Vector3) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 1.0, 1.0)

	var material := _mat(Color(0.045, 0.05, 0.065), 0.95)
	var transforms: Array[Transform3D] = []

	# Avenues running away from the road's end.
	for k in range(-3, 4):
		var centre := end_point + right * (float(k) * 58.0) + direction * 130.0 + Vector3.UP * 0.04
		var basis := Basis(right, Vector3.UP, direction).scaled(Vector3(10.0, 0.08, 300.0))
		transforms.append(Transform3D(basis, centre))

	# Cross streets.
	for k in range(0, 7):
		var centre := end_point + direction * (float(k) * 48.0 - 10.0) + Vector3.UP * 0.04
		var basis := Basis(right, Vector3.UP, direction).scaled(Vector3(430.0, 0.08, 10.0))
		transforms.append(Transform3D(basis, centre))

	city_street_count += transforms.size()
	_add_multimesh("CityStreets", mesh, material, transforms)


## Lit windows scattered over the faces of the skyline, plus blinking beacons on
## the tallest towers. Distance sells them: they read as a million tiny lights.
func _build_city_windows(blocks: Array[Transform3D], road_points: Array[Vector3], rng: RandomNumberGenerator) -> void:
	var window_mesh := BoxMesh.new()
	window_mesh.size = Vector3(1.9, 1.3, 0.25)

	var transforms: Array[Transform3D] = []

	# More city, more lit windows: the count follows the block count so a
	# 2 km map does not spread the same windows twice as thin.
	var window_target := clampi(2600 + blocks.size() * 14, 4200, 9500)

	for i in window_target:
		if blocks.is_empty():
			break

		var pick := rng.randi_range(0, blocks.size() - 1)
		var block := blocks[pick]
		var look_at_point: Vector3 = road_points[pick] if pick < road_points.size() else block.origin
		var size := block.basis.get_scale()
		var height := size.y

		# Only the upper part of a tower is lit; the rest is dark glass.
		var low := height * 0.08
		var high := height * 0.96

		if high <= low:
			continue

		var to_road := (look_at_point - block.origin)
		to_road.y = 0.0

		if to_road.length() < 1.0:
			to_road = Vector3.FORWARD
		else:
			to_road = to_road.normalized()

		# Push the window onto the face of the box that looks towards the road.
		var half := size * 0.5
		var lateral := rng.randf_range(-0.4, 0.4)
		var offset := to_road * (half.x * 0.92) + Vector3(-to_road.z, 0.0, to_road.x) * (half.z * lateral)

		var position := block.origin + offset + Vector3.UP * rng.randf_range(low, high)
		var basis := Basis(Vector3.UP, atan2(to_road.x, to_road.z)).scaled(Vector3(1.0, 1.0, 1.0))
		transforms.append(Transform3D(basis, position))

	city_window_count = transforms.size()
	_add_multimesh("CityWindows", window_mesh, _window_material(), transforms)

	# Rooftop clutter — water tanks and plant boxes — so the towers do not
	# end in billboard-flat tops when you pass them.
	var roof_mesh := BoxMesh.new()
	roof_mesh.size = Vector3(1.0, 1.0, 1.0)

	var roof_transforms: Array[Transform3D] = []

	for i in 170:
		if blocks.is_empty():
			break

		var block := blocks[rng.randi_range(0, blocks.size() - 1)]
		var size := block.basis.get_scale()
		var box_height := rng.randf_range(0.9, 2.4)
		var basis := Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(
			Vector3(size.x * rng.randf_range(0.2, 0.42), box_height, size.z * rng.randf_range(0.2, 0.42)))
		var top := block.origin + Vector3.UP * (size.y * 0.5 + box_height * 0.5)
		roof_transforms.append(Transform3D(basis, top))

	rooftop_count = roof_transforms.size()
	_add_multimesh("CityRooftops", roof_mesh, _metal, roof_transforms)

	# Beacons on the six tallest blocks.
	var tallest: Array = blocks.duplicate()
	tallest.sort_custom(func(a: Transform3D, b: Transform3D) -> bool:
		return a.basis.get_scale().y > b.basis.get_scale().y)

	var beacon_mesh := SphereMesh.new()
	beacon_mesh.radius = 1.6
	beacon_mesh.height = 3.2
	beacon_mesh.radial_segments = 6
	beacon_mesh.rings = 3

	_beacon_material = StandardMaterial3D.new()
	_beacon_material.albedo_color = Color(1.0, 0.2, 0.15)
	_beacon_material.emission_enabled = true
	_beacon_material.emission = Color(1.0, 0.16, 0.1)
	_beacon_material.emission_energy_multiplier = 3.0
	_beacon_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	var beacon_transforms: Array[Transform3D] = []

	for i in mini(12, tallest.size()):
		var block: Transform3D = tallest[i]
		var top: Vector3 = block.origin + Vector3.UP * (block.basis.get_scale().y * 0.5 + 2.0)
		beacon_transforms.append(Transform3D(Basis(), top))
		city_tops.append(top)

	_add_multimesh("CityBeacons", beacon_mesh, _beacon_material, beacon_transforms)
	beacon_count = beacon_transforms.size()


func _window_material() -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	_window_mat = material
	material.albedo_color = Color(1.0, 0.88, 0.62)
	material.emission_enabled = true
	material.emission = Color(1.0, 0.86, 0.55)
	material.emission_energy_multiplier = 2.4
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return material


## 0..1 blink for the tower beacons. Slow pulse, never fully dark.
static func beacon_energy(time: float) -> float:
	return 0.35 + 0.65 * (0.5 + 0.5 * sin(time * 2.2))


func _process(_delta: float) -> void:
	if _beacon_material == null:
		return

	_beacon_material.emission_energy_multiplier = 3.0 * beacon_energy(Time.get_ticks_msec() / 1000.0)


## Arc length of the point on the road closest to `point`. Used by the mission
## system to know how far along the route the truck is.
func nearest_distance(point: Vector3) -> float:
	var best := 0.0
	var best_squared := INF
	var step := 2.0
	var distance := 0.0

	while distance <= _baked_length:
		var squared := _point(distance).distance_squared_to(point)

		if squared < best_squared:
			best_squared = squared
			best = distance

		distance += step

	return best


## World position on the road, handy for placing markers.
func point_at(distance: float, lateral: float, height: float) -> Vector3:
	return _place(clampf(distance, 0.0, _baked_length), lateral, height)


## Forward direction of the road at a distance.
func direction_at(distance: float) -> Vector3:
	return _tangent(clampf(distance, 0.0, _baked_length))


## Solid props: trees, rocks and the overpass pillars.
func _build_prop_collision() -> void:
	var body := StaticBody3D.new()
	body.name = "PropCollision"

	var cylinders: Dictionary = {}
	var boxes: Dictionary = {}

	for spot in prop_spots:
		var radius: float = spot["radius"]

		if spot.has("box"):
			var size: Vector3 = spot["box"]
			var key := "%.2f/%.2f/%.2f" % [size.x, size.y, size.z]
			var shape: BoxShape3D = boxes.get(key)

			if shape == null:
				shape = BoxShape3D.new()
				shape.size = size
				boxes[key] = shape

			var collision := CollisionShape3D.new()
			collision.shape = shape
			var position: Vector3 = spot["position"]
			var spot_basis: Basis = spot.get("basis", Basis())
			collision.transform = Transform3D(spot_basis, position)
			body.add_child(collision)
		else:
			var key := "%.2f" % radius
			var shape: CylinderShape3D = cylinders.get(key)

			if shape == null:
				shape = CylinderShape3D.new()
				shape.radius = radius
				shape.height = 5.0
				cylinders[key] = shape

			var collision := CollisionShape3D.new()
			collision.shape = shape
			var position: Vector3 = spot["position"]
			collision.transform = Transform3D(Basis(), position + Vector3.UP * 2.5)
			body.add_child(collision)

		prop_shapes += 1

	add_child(body)


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
