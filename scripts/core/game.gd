extends Node3D
## Root of the playable scene. Keeps only the cross-cutting concerns:
## restart, and the optional telemetry used by the headless smoke test.

const TELEMETRY_FLAG := "--rv-telemetry"


## Runs before the children enter the tree, which is the only moment the road's
## exported seed and length can still change what it builds.
func _enter_tree() -> void:
	var road := get_node_or_null("Road")

	if road == null:
		return

	var career := get_node_or_null("/root/Career")
	if career == null:
		return

	road.set("seed_value", career.call("current_seed"))
	road.set("road_length", career.call("current_route_length"))

	var profile: Dictionary = career.call("current_profile")
	road.set("bend_scale", float(profile.get("bend", 1.0)))
	road.set("wave_scale", float(profile.get("wave", 1.0)))
	road.set("tree_scale", float(profile.get("trees", 1.0)))
	road.set("rock_scale", float(profile.get("rocks", 1.0)))
	road.set("lake_scale", float(profile.get("lakes", 1.0)))
	road.set("start_city", String(profile.get("from", "NORTHGATE")))
	road.set("end_city", String(profile.get("to", "SOUTHPORT")))


func _ready() -> void:
	InputSetup.ensure_registered()
	_park_truck_in_loading_bay()


## A job starts the way a job starts: backed into the marked bay at the
## loading depot, freight on, yard around you — not dumped in the
## middle of the carriageway. Pull out and turn onto the road.
func _park_truck_in_loading_bay() -> void:
	var road := get_node_or_null("Road")
	var truck := get_node_or_null("Truck") as Node3D

	if road == null or truck == null:
		return

	var depot := road.get_node_or_null("LoadingDepot") as Node3D

	if depot == null:
		return

	truck.global_transform = Transform3D(depot.global_transform.basis, depot.to_global(Vector3(-14.0, 1.15, 0.0)))

	# Start framed, not mid-snap: the chase camera opens behind the rig.
	var camera := get_node_or_null("ChaseCamera") as Node3D

	if camera != null:
		camera.global_position = truck.global_position + truck.global_basis * Vector3(0.0, 4.8, 13.5)

	# The ground plane is a scene material; dress it in procedural turf so
	# five kilometres of it stops reading as one flat colour. One texture
	# tile covers about 14 m.
	var ground_mesh := get_node_or_null("Ground/Mesh") as MeshInstance3D

	if ground_mesh != null and ground_mesh.material_override != null:
		var ground_material := ground_mesh.material_override.duplicate() as StandardMaterial3D

		if ground_material != null:
			ground_material.albedo_texture = TextureFactory.ground()
			ground_material.uv1_scale = Vector3(7000.0, 7000.0, 7000.0)
			ground_mesh.material_override = ground_material


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("rv_restart"):
		get_tree().reload_current_scene()


func _physics_process(_delta: float) -> void:
	if not _telemetry_enabled():
		return

	if Engine.get_physics_frames() % 30 != 0:
		return

	var truck := get_node_or_null("Truck") as TruckController
	if truck == null:
		return

	print("RV_TELEMETRY speed_kph=%.2f gear=%d rpm=%.0f pos_z=%.2f" % [
		truck.speed_kph(),
		truck.gearbox.current_gear,
		truck.engine_rpm,
		truck.global_position.z,
	])


func _telemetry_enabled() -> bool:
	return TELEMETRY_FLAG in OS.get_cmdline_args()
