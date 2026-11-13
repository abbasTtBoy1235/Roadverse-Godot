extends SceneTree
## Headless checks for the procedural road: every generator actually produced
## geometry, nothing produced NaN, and generation is deterministic.
##
##   godot --headless --path . --script res://tests/test_road_geometry.gd

const ROAD_SCRIPT := preload("res://scripts/world/road_builder.gd")

const EXPECTED_MESHES := [
	"Asphalt", "Shoulders", "EdgeLines", "CentreLine", "GuardrailBeams", "PowerWires", "FenceRails", "CityAvenues", "CitySidewalks", "RestLayby",
]
const EXPECTED_MULTIMESHES := [
	"GuardrailPosts", "DelineatorPosts", "LampPoles", "LampArms", "LampBulbs",
	"TreeTrunks", "TreeCanopies", "Rocks", "PowerPoles", "DistantHills",
	"RoadStuds", "KmMarkerPosts", "KmMarkerPlates", "FencePosts", "Shrubs", "CityBlocks", "CityStreets", "CityWindows",
	"CityLampPoles", "CityLampBulbs", "CityRooftops", "CityTiers", "LakeSurface",
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
	_check_overpass(road)
	_check_collision(road)
	_check_wetness(road)
	_check_city(road)
	_check_route_furniture(road)
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


func _check_city(road: Node3D) -> void:
	# The city used to be 70 blocks past the end of the road. It now runs
	# alongside the second half of the route as well as beyond it.
	_check(road.city_block_count >= 220, "the city has real bulk (%d blocks)" % road.city_block_count)
	_check(road.city_window_count >= 4000, "the city windows are dense (%d)" % road.city_window_count)
	_check(road.beacon_count >= 12, "the tall towers carry beacons (%d)" % road.beacon_count)

	_check(road.city_street_count >= 36, "the city has a street grid (%d streets)" % road.city_street_count)
	_check(road.city_lamp_count >= 40, "city streets have their own lamps (%d)" % road.city_lamp_count)
	_check(road.rooftop_count >= 100, "the towers carry rooftop clutter (%d)" % road.rooftop_count)
	_check(road.gantry_sign_count == 2, "overhead gantry signs announce the road (%d)" % road.gantry_sign_count)

	var gantry_label := road.get_node_or_null("GantrySign0/Label") as Label3D
	_check(gantry_label != null and gantry_label.text == "NORTHBOUND", "the first gantry sign reads NORTHBOUND")

	var streets := road.get_node_or_null("CityStreets") as MultiMeshInstance3D
	_check(streets != null and streets.multimesh.instance_count >= 12, "the downtown street grid was built (%d)" % (streets.multimesh.instance_count if streets != null else 0))

	# Street lamps must be dimmable by the day/night cycle.
	road.apply_time_of_day(0.0)
	_check(road.lamp_level < 0.01, "lamps go out by day")
	road.apply_time_of_day(1.0)
	_check(road.lamp_level > 0.99, "lamps come on at night")

	var blocks := road.get_node_or_null("CityBlocks") as MultiMeshInstance3D
	_check(blocks != null and blocks.multimesh.instance_count == road.city_block_count, "city multimesh matches the block count")

	if blocks != null:
		var length: float = road.get("curve").get_baked_length()
		var alongside := 0

		for i in blocks.multimesh.instance_count:
			var origin := blocks.multimesh.get_instance_transform(i).origin

			if road.nearest_distance(origin) < length * 0.97:
				alongside += 1

		_check(alongside >= 80, "districts run alongside the road, not only past its end (%d)" % alongside)


func _check_route_furniture(road: Node3D) -> void:
	var length: float = road.get("curve").get_baked_length()

	# The toll plaza sits between the start town and the destination city.
	_check(road.toll_distance > length * 0.4 and road.toll_distance < length * 0.56,
		"the toll plaza is midway along the route (%.0f of %.0f m)" % [road.toll_distance, length])
	_check(road.toll_booth_count == 4, "the toll plaza has four booths (%d)" % road.toll_booth_count)
	_check(road.get_node_or_null("TollPlaza/Arm0") != null, "the toll arms were built")
	_check(road.get_node_or_null("TollPlaza/TollSign") != null, "the toll canopy carries its sign")

	_check(road.billboard_count == 3, "billboards line the route (%d)" % road.billboard_count)

	var billboard_label := road.get_node_or_null("Billboard0/Label") as Label3D
	_check(billboard_label != null and billboard_label.text == "ICE COLD COLA", "the first billboard advertises cola")

	_check(road.chevron_count >= 2, "chevron boards mark the sharp bends (%d)" % road.chevron_count)
	_check(road.rest_stop_count == 1, "there is a rest stop (%d)" % road.rest_stop_count)
	_check(road.lake_blob_count == 6, "the lake was built (%d blobs)" % road.lake_blob_count)
	_check(road.city_tier_count >= 15, "tall towers get stepped crowns (%d)" % road.city_tier_count)


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

	_check(total_instances > 800, "roadside furniture is dense enough (%d instances)" % total_instances)


func _check_overpass(road: Node3D) -> void:
	var overpass := road.get_node_or_null("Overpass")
	_check(overpass != null, "overpass exists")

	if overpass == null:
		return

	_check(overpass.get_node_or_null("Deck") != null, "overpass has a deck")
	_check(overpass.get_child_count() >= 4, "overpass has deck, parapets and pillars (%d parts)" % overpass.get_child_count())


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


func _check_collision(road: Node3D) -> void:
	var body := road.get_node_or_null("GuardrailCollision") as StaticBody3D
	_check(body != null, "the guardrails have a collision body")

	if body == null:
		return

	_check(body.get_child_count() > 300, "the rail is covered in boxes (%d)" % body.get_child_count())
	_check(road.collision_shapes == body.get_child_count(), "collision_shapes counts every box")

	var left := 0
	var right := 0
	var lowest := INF
	var highest := -INF

	for child in body.get_children():
		var collision := child as CollisionShape3D

		if collision == null or collision.shape == null:
			continue

		var lateral: float = collision.transform.origin.x
		if lateral > 0.5:
			right += 1
		elif lateral < -0.5:
			left += 1

		lowest = minf(lowest, collision.transform.origin.y)
		highest = maxf(highest, collision.transform.origin.y)

	_check(left > 100 and right > 100, "both sides are walled (%d left, %d right)" % [left, right])
	_check(absf(absf(road.rail_lateral) - 9.45) < 0.01, "the rail sits at the edge of the shoulder (%.2f m)" % road.rail_lateral)
	_check(lowest > 0.2, "the barrier starts above the road surface (%.2f m)" % lowest)
	_check(highest < 1.6, "the barrier is truck-high, not a wall (%.2f m)" % highest)


func _check_wetness(road: Node3D) -> void:
	var asphalt := (road.get_node("Asphalt") as MeshInstance3D).material_override as StandardMaterial3D
	_check(asphalt != null, "asphalt material found")

	if asphalt == null:
		return

	var dry := asphalt.roughness
	road.set_wetness(1.0)
	var wet := asphalt.roughness
	var wet_metal := asphalt.metallic

	_check(wet < dry, "wet tarmac is smoother than dry (%.2f -> %.2f)" % [dry, wet])
	_check(wet_metal > 0.4, "wet tarmac reflects like a mirror (metallic %.2f)" % wet_metal)
	_check(is_equal_approx(road.wetness(), 1.0), "wetness is reported back")

	road.set_wetness(0.0)
	_check(is_equal_approx(asphalt.roughness, dry), "drying restores the original roughness")


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
