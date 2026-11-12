extends SceneTree
## Headless checks for the procedural road: every generator actually produced
## geometry, nothing produced NaN, and generation is deterministic.
##
##   godot --headless --path . --script res://tests/test_road_geometry.gd

const ROAD_SCRIPT := preload("res://scripts/world/road_builder.gd")

const EXPECTED_MESHES := ["Asphalt", "Shoulders", "EdgeLines", "CentreLine", "GuardrailBeams"]
const EXPECTED_MULTIMESHES := [
	"GuardrailPosts", "DelineatorPosts", "LampPoles", "LampArms", "LampBulbs",
	"TreeTrunks", "TreeCanopies", "Rocks", "PowerPoles", "DistantHills",
]

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[road] building the road")

	var started := Time.get_ticks_msec()
	var road: Node3D = ROAD_SCRIPT.new()
	road.build()
	var elapsed := Time.get_ticks_msec() - started

	print("[road] built in %d ms, %d child nodes" % [elapsed, road.get_child_count()])

	_check(elapsed < 4000, "generation finishes in under 4s (%d ms)" % elapsed)
	_check_curve(road)
	_check_meshes(road)
	_check_multimeshes(road)
	_check_lamps(road)
	_check_determinism()

	var lights := _count_lamps(road)
	print("[road] lamps=%d meshes=%d multimeshes=%d" % [
		lights,
		EXPECTED_MESHES.size(),
		EXPECTED_MULTIMESHES.size()
	])

	road.free()

	print("[road] %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _check_curve(road: Node3D) -> void:
	var curve: Curve3D = road.curve
	_check(curve != null, "a road curve exists")

	if curve == null:
		return

	var length := curve.get_baked_length()
	_check(length > 100.0, "curve has a usable length (%.0f m)" % length)

	var start := curve.sample_baked(0.0)
	var end := curve.sample_baked(length)
	_check(start.distance_to(Vector3.ZERO) < 1.0, "road starts at the origin")
	_check(is_finite(start.x) and is_finite(end.z), "curve endpoints are finite")

	# The curve must actually bend, otherwise this is just the old straight strip.
	var max_lateral := 0.0
	var samples := 40
	for i in samples:
		var point := curve.sample_baked(length * float(i) / float(samples))
		max_lateral = maxf(max_lateral, absf(point.x))
	_check(max_lateral > 5.0, "road bends laterally (max %.1f m)" % max_lateral)


func _check_meshes(road: Node3D) -> void:
	for mesh_name: String in EXPECTED_MESHES:
		var instance := road.get_node_or_null(mesh_name) as MeshInstance3D
		_check(instance != null, "mesh '%s' exists" % mesh_name)

		if instance == null or instance.mesh == null:
			continue

		var surface_count := instance.mesh.get_surface_count()
		_check(surface_count > 0, "mesh '%s' has geometry" % mesh_name)

		var aabb := instance.mesh.get_aabb()
		var size := aabb.size
		_check(size.length() > 1.0 and is_finite(size.length()),
			"mesh '%s' has a sane bounding box (%.1f x %.1f x %.1f)" % [mesh_name, size.x, size.y, size.z])
		_check(is_finite(aabb.position.length()), "mesh '%s' bounds are finite" % mesh_name)


func _check_multimeshes(road: Node3D) -> void:
	var total_instances := 0

	for node_name: String in EXPECTED_MULTIMESHES:
		var instance := road.get_node_or_null(node_name) as MultiMeshInstance3D
		_check(instance != null, "multimesh '%s' exists" % node_name)

		if instance == null or instance.multimesh == null:
			continue

		var count := instance.multimesh.instance_count
		total_instances += count
		_check(count > 0, "multimesh '%s' has instances (%d)" % [node_name, count])

		if count == 0:
			continue

		var sample := instance.multimesh.get_instance_transform(count - 1)
		_check(is_finite(sample.origin.length()), "multimesh '%s' transforms are finite" % node_name)

	_check(total_instances > 200, "roadside furniture is dense enough (%d instances)" % total_instances)


func _check_lamps(road: Node3D) -> void:
	var lamps := _count_lamps(road)
	_check(lamps >= 6, "at least 6 street lamps (%d)" % lamps)
	_check(lamps <= 40, "lamp count stays reasonable for performance (%d)" % lamps)


func _count_lamps(road: Node3D) -> int:
	var count := 0
	for child in road.get_children():
		if child is OmniLight3D:
			count += 1
	return count


func _check_determinism() -> void:
	var first: Node3D = ROAD_SCRIPT.new()
	first.seed_value = 4242
	first.build()

	var second: Node3D = ROAD_SCRIPT.new()
	second.seed_value = 4242
	second.build()

	var first_trees := (first.get_node("TreeTrunks") as MultiMeshInstance3D).multimesh.instance_count
	var second_trees := (second.get_node("TreeTrunks") as MultiMeshInstance3D).multimesh.instance_count

	_check(first_trees == second_trees, "same seed produces the same tree count (%d)" % first_trees)

	var other: Node3D = ROAD_SCRIPT.new()
	other.seed_value = 999
	other.build()
	var other_trees := (other.get_node("TreeTrunks") as MultiMeshInstance3D).multimesh.instance_count
	_check(other_trees != first_trees, "a different seed produces a different layout (%d vs %d)" % [other_trees, first_trees])

	first.free()
	second.free()
	other.free()
