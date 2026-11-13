extends Node3D
## Integration test: drives the real scene and checks that the wheels turn, the
## engine synth follows the revs, and the traffic moves along the road.
##
##   godot --headless --path . res://tests/drive_state.tscn

const DRIVE_SECONDS := 4.0
const STEER_SECONDS := 1.0
const RAIN_SECONDS := 2.0
const TOLL_SECONDS := 2.2
const DELIVERY_SECONDS := 6.0

var _game: Node3D
var _truck: TruckController
var _wheels: WheelVisuals
var _audio: EngineAudio
var _traffic: Node3D
var _weather: Node3D
var _noise: Node
var _road: Node3D
var _trailer: Node3D
var _mission: Mission
var _results: CanvasLayer
var _cash_before := 0
var _job_before := 0

var _elapsed := 0.0
var _phase := 0
var _spin_before := 0.0
var _traffic_before: Array[float] = []
var _peds: Node3D
var _peds_before: Array[Vector3] = []
var _failures := 0


func _ready() -> void:
	# The results screen pauses the tree, so this test must keep ticking.
	process_mode = Node.PROCESS_MODE_ALWAYS

	var career := get_node_or_null("/root/Career")

	if career != null:
		career.call("reset_progress")

	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_game)

	_truck = _game.get_node("Truck") as TruckController
	_wheels = _truck.get_node("WheelVisuals") as WheelVisuals
	_audio = _truck.get_node("EngineAudio") as EngineAudio
	_traffic = _game.get_node("Traffic") as Node3D
	_peds = _game.get_node_or_null("Pedestrians") as Node3D
	_weather = _game.get_node("Weather") as Node3D
	_noise = _truck.get_node("RoadNoise") as Node
	_road = _game.get_node("Road") as Node3D
	_trailer = _game.get_node_or_null("Trailer") as Node3D
	_mission = _game.get_node("Mission") as Mission
	_results = _game.get_node("Results") as CanvasLayer

	var career_node := get_node_or_null("/root/Career")

	if career_node != null:
		_cash_before = int(career_node.get("cash"))
		_job_before = int(career_node.get("job_index"))

	_check(_truck != null, "truck found")
	_check(_wheels != null, "wheel visuals found")
	_check(_audio != null, "engine audio found")
	_check(_traffic != null, "traffic found")

	if _peds != null:
		_check(int(_peds.call("pedestrian_count_live")) >= 24, "pedestrian NPCs are out walking (%d)" % int(_peds.call("pedestrian_count_live")))
		_peds_before = _peds.call("pedestrian_positions")

		var positions_finite := true
		for position in _peds_before:
			if not (is_finite(position.x) and is_finite(position.y) and is_finite(position.z)):
				positions_finite = false
		_check(positions_finite, "pedestrian positions are finite")

	_check(_weather != null, "weather found")
	_check(_noise != null, "road noise found")
	_check(_road != null, "road found")
	# The GLB is a complete truck with its own cargo body; the game used to hang
	# a second, procedural trailer behind it. It must not come back.
	_check(_trailer == null, "no second trailer is attached behind the truck")

	# Regression (user screenshot, 2026-11-12): the ground plane was 800x800
	# centred on the spawn, so it ended at z=-400 while the route runs past
	# 500 m — the map simply stopped working at ~77%. The ground has to cover
	# the gate and the end of the road, visually and physically.
	var ground_mesh := _game.get_node_or_null("Ground/Mesh") as MeshInstance3D
	var ground_shape := _game.get_node_or_null("Ground/Shape") as CollisionShape3D
	var mission := _game.get_node_or_null("Mission")

	if ground_mesh != null and _road != null and mission != null:
		var ground_box: AABB = ground_mesh.global_transform * ground_mesh.get_aabb()
		var goal_point: Vector3 = _road.call("point_at", float(mission.get("goal_distance")), 0.0, 0.0)
		var road_curve: Curve3D = _road.get("curve")
		var end_point: Vector3 = _road.call("point_at", road_curve.get_baked_length(), 0.0, 0.0)

		_check(ground_box.position.x <= goal_point.x and goal_point.x <= ground_box.end.x
			and ground_box.position.z <= goal_point.z and goal_point.z <= ground_box.end.z,
			"the ground reaches the delivery gate (z %.0f)" % goal_point.z)
		_check(ground_box.position.z <= end_point.z, "the ground reaches the end of the road (z %.0f)" % end_point.z)
		_check(ground_shape != null and (ground_shape.shape as BoxShape3D).size.x >= 3000.0,
			"the ground collision matches the visual ground")
	_check(_mission != null, "mission found")
	_check(_results != null, "results panel found")

	if _wheels != null:
		_check(_wheels.wheel_count() == 4, "all four wheels are driven visually (%d)" % _wheels.wheel_count())
		_spin_before = _wheels.spin_angle(0)

	_traffic_before = _traffic.call("car_distances")
	var expected_cars: int = int(_traffic.get("car_count")) + int(_traffic.get("forward_car_count"))
	_check(_traffic_before.size() == expected_cars,
		"traffic spawned %d cars" % _traffic_before.size())

	var counts: Dictionary = _traffic.call("direction_counts")
	_check(counts["oncoming"] == int(_traffic.get("car_count")), "the oncoming lane is full (%d)" % counts["oncoming"])
	_check(counts["forward"] == int(_traffic.get("forward_car_count")), "the slow lane has traffic to overtake (%d)" % counts["forward"])

	# Regression (user report, 2026-11-12): both directions of NPC traffic used
	# to drive on the same (left) side of the road, and the truck passed
	# straight through them. Lanes are road-space offsets now: oncoming cars
	# keep to the far side, same-direction cars keep to the player's side, and
	# every car carries a collision body.
	var lane_offsets: Array = _traffic.call("car_lane_offsets")
	var lanes_ok := lane_offsets.size() == expected_cars

	for i in lane_offsets.size():
		var should_be_negative := i < int(_traffic.get("car_count"))
		if (float(lane_offsets[i]) < 0.0) != should_be_negative:
			lanes_ok = false

	_check(lanes_ok, "NPC traffic keeps to its own side of the road in both directions")
	_check(int(_traffic.call("rounded_car_count")) >= 10, "NPC cars have rounded profile bodies, not boxes (%d)" % int(_traffic.call("rounded_car_count")))
	_check(int(_traffic.call("car_collision_count")) == expected_cars,
		"every NPC car is solid, not a ghost (%d)" % int(_traffic.call("car_collision_count")))

	_check_cockpit()

	if _mission != null:
		_check(_mission.gate_built, "the delivery gate was built")
		_check(_mission.goal_distance > 1000.0, "the gate sits down a long-haul road (%.0f m)" % _mission.goal_distance)

	Input.action_press("rv_throttle", 1.0)


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if _phase == 0 and _elapsed >= DRIVE_SECONDS:
		_phase = 1
		_check_drive()
		Input.action_press("rv_steer_right", 1.0)

	elif _phase == 1 and _elapsed >= DRIVE_SECONDS + STEER_SECONDS:
		_phase = 2
		_check_steering()
		Input.action_release("rv_steer_right")
		_check_barrier()
		_weather.call("set_raining", true)

	elif _phase == 2 and _elapsed >= DRIVE_SECONDS + STEER_SECONDS + RAIN_SECONDS:
		_phase = 3
		_check_weather()
		_check_props()
		_arm_toll()

	elif _phase == 3 and _elapsed >= DRIVE_SECONDS + STEER_SECONDS + RAIN_SECONDS + TOLL_SECONDS:
		_phase = 4
		_check_toll()
		_arm_delivery()

	elif _phase == 4 and _elapsed >= DRIVE_SECONDS + STEER_SECONDS + RAIN_SECONDS + TOLL_SECONDS + DELIVERY_SECONDS:
		_phase = 5
		_check_delivery()
		Input.action_release("rv_throttle")
		_finish()


## The in-cab camera used to ignore the mouse and lag behind the seat on a
## smoothing lerp. It must sit exactly on the driver's eye point and turn
## with the mouse.
func _check_cockpit() -> void:
	var camera := _game.get_node_or_null("ChaseCamera") as ChaseCamera

	if camera == null or _truck == null:
		_check(false, "chase camera found for the cockpit check")
		return

	camera.mode = ChaseCamera.Mode.COCKPIT

	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(120.0, 0.0)
	camera.handle_input_event(motion)
	camera.call("_process", 0.016)

	_check(camera.is_cockpit(), "cockpit camera mode engages")
	_check(camera.global_position.distance_to(camera.cockpit_seat_position()) < 0.05,
		"the cockpit camera sits exactly on the driver's seat (%.3f m off)" % camera.global_position.distance_to(camera.cockpit_seat_position()))

	var seat_local: Vector3 = _truck.global_transform.affine_inverse() * camera.global_position
	_check(seat_local.z > -4.3 and seat_local.z < -2.7, "the driver's eyes are inside the cab, not the cargo box (z %.2f)" % seat_local.z)
	_check(seat_local.x < 0.0, "the driver sits on the left seat (x %.2f)" % seat_local.x)

	var truck_forward := -_truck.global_basis.z
	var view_forward := -camera.global_basis.z
	var dot := clampf(truck_forward.normalized().dot(view_forward.normalized()), -1.0, 1.0)
	_check(dot < 0.995 and dot > 0.75, "the mouse turns the driver's head (%.0f deg off the nose)" % rad_to_deg(acos(dot)))

	camera.mode = ChaseCamera.Mode.CHASE
	camera.orbit.reset()


func _check_drive() -> void:
	# The game starts at 07:00 now: lamps must be off in the morning.
	if _road != null:
		_check(float(_road.get("lamp_level")) < 0.5, "street lamps are off at the morning start (level %.2f)" % float(_road.get("lamp_level")))

	if _wheels != null:
		_check(absf(_wheels.spin_angle(0) - _spin_before) > 0.5, "wheels spin while driving")

	if _audio != null:
		var frequency := _audio.current_frequency()
		_check(frequency > 30.0, "engine synth runs at a believable pitch (%.0f Hz)" % frequency)

	var exhaust := _truck.get_node_or_null("Exhaust")

	if exhaust != null:
		_check(bool(exhaust.call("smoke_active")), "the exhaust smokes under load")

	if _traffic != null:
		var after: Array[float] = _traffic.call("car_distances")
		var moved := 0
		for i in mini(after.size(), _traffic_before.size()):
			if absf(after[i] - _traffic_before[i]) > 0.5:
				moved += 1
		_check(moved > 0, "traffic cars move along the road (%d of %d moved)" % [moved, after.size()])

	if _peds != null and not _peds_before.is_empty():
		var after_positions: Array[Vector3] = _peds.call("pedestrian_positions")
		var walked := 0

		for i in mini(after_positions.size(), _peds_before.size()):
			if after_positions[i].distance_to(_peds_before[i]) > 0.3:
				walked += 1

		_check(walked > after_positions.size() / 2, "pedestrians actually walk (%d of %d moved)" % [walked, after_positions.size()])

	var speed := _truck.speed_kph()
	_check(speed > 8.0, "truck is actually moving (%.0f km/h)" % speed)

	if _mission != null:
		_check(_mission.progress > 5.0, "the mission is counting the distance covered (%.0f m)" % _mission.progress)
		_check(_mission.status_text().length() > 0, "the HUD has a mission line")

	var tank := _truck.get_node_or_null("FuelTank") as FuelTank

	if tank != null:
		_check(tank.level() < 1.0, "driving burns diesel (tank at %d%%)" % roundi(tank.level() * 100.0))
		_check(tank.level() > 0.5, "a single haul does not empty the tank")
		_check(tank.litres_used > 0.0, "the fuel counter is running (%.2f L)" % tank.litres_used)

	var camera := _game.get_node_or_null("ChaseCamera") as ChaseCamera

	if camera != null:
		_check(camera.shake_amount() >= 0.0, "the camera shake hook reports a value")

	if _noise != null:
		_check(_noise.call("tyre_level") > 0.1, "tyre noise follows the speed (%.2f)" % _noise.call("tyre_level"))
		_check(_noise.call("wind_level") >= 0.0, "wind level is sane (%.2f)" % _noise.call("wind_level"))


func _check_steering() -> void:
	var wheel := _truck.get_node_or_null("WheelFL") as VehicleWheel3D
	_check(wheel != null, "front wheel exists")

	if wheel == null:
		return

	var spin := wheel.get_node_or_null("Spin") as Node3D
	_check(spin != null, "front wheel has a spin pivot")

	if spin == null:
		return

	_check(absf(spin.rotation.y) > 0.01, "front wheels visually steer (%.2f rad)" % spin.rotation.y)
	_check(spin.rotation.y < 0.0, "steering right turns the wheels right (negative yaw)")

	# Detail pass: the cab interior and the indicators follow the same input.
	var interior := _truck.get_node_or_null("CockpitInterior")

	if interior != null:
		_check(absf(float(interior.call("steering_wheel_angle"))) > 0.25,
			"the steering wheel in the cab turns with the road wheels (%.2f rad)" % float(interior.call("steering_wheel_angle")))

	var lights := _truck.get_node_or_null("Lights") as TruckLights

	if lights != null:
		_check(lights.indicator_state() == "right", "the right indicator blinks while steering right (%s)" % lights.indicator_state())


## Fires a ray from the truck straight at the nearest piece of guardrail: it must
## be a real collision body, not just a mesh.
func _check_barrier() -> void:
	var body := _road.get_node_or_null("GuardrailCollision") as StaticBody3D
	_check(body != null, "the road has guardrail collision")

	if body == null:
		return

	var nearest: Node3D = null
	var nearest_distance := INF

	for child in body.get_children():
		var shape := child as Node3D

		if shape == null:
			continue

		var distance := shape.global_position.distance_to(_truck.global_position)

		if distance < nearest_distance:
			nearest_distance = distance
			nearest = shape

	_check(nearest != null, "a guardrail box is near the truck (%.1f m)" % nearest_distance)

	if nearest == null:
		return

	var from := _truck.global_position + Vector3(0.0, 0.4, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from, nearest.global_position)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	_check(not hit.is_empty(), "a ray from the truck hits the barrier")

	if hit.is_empty():
		return

	var collider := hit.get("collider") as Node
	_check(collider != null and collider.name == "GuardrailCollision",
		"the guardrail stops the truck (hit %s)" % (collider.name if collider != null else "nothing"))
	_check(float(hit.get("position").y) > 0.0, "the barrier is above the road surface")


func _check_weather() -> void:
	if _weather == null:
		return

	_check(_weather.call("is_emitting"), "rain particles are emitting")

	var soak: float = _weather.call("wetness")
	_check(soak > 0.3, "the road is soaking up (%.2f)" % soak)

	if _road != null and _road.has_method("wetness"):
		_check(float(_road.call("wetness")) > 0.3, "the road material knows it is wet")

	var asphalt := (_road.get_node("Asphalt") as MeshInstance3D).material_override as StandardMaterial3D

	if asphalt != null:
		_check(asphalt.metallic > 0.1, "wet tarmac has turned reflective (metallic %.2f)" % asphalt.metallic)


## Trees, rocks and the overpass pillars are solid, not decoration.
func _check_props() -> void:
	var body := _road.get_node_or_null("PropCollision") as StaticBody3D
	_check(body != null, "roadside props have collision")

	if body == null or body.get_child_count() == 0:
		return

	_check(body.get_child_count() > 50, "every tree and rock is walled (%d shapes)" % body.get_child_count())

	var shape := body.get_child(0) as Node3D
	var origin := shape.global_position + Vector3(0.0, 30.0, 0.0)
	var query := PhysicsRayQueryParameters3D.create(origin, origin - Vector3(0.0, 32.0, 0.0))
	var hit := get_world_3d().direct_space_state.intersect_ray(query)

	_check(not hit.is_empty(), "a ray dropped on a tree hits it")
	if not hit.is_empty():
		var collider := hit.get("collider") as Node
		_check(collider != null and collider.name == "PropCollision", "the prop is solid (hit %s)" % (collider.name if collider != null else "nothing"))


## Pulls the gate close and lets any arrival speed count, so the run finishes
## inside the test instead of after 600 m.
## Park the truck just short of the toll booths with money in the wallet,
## then drive through: arms should lift and the fee should land.
func _arm_toll() -> void:
	var toll_distance: float = _road.get("toll_distance")
	var spot: Vector3 = _road.call("point_at", toll_distance - 3.0, 0.0, 1.4)

	# Square the truck up with the road: after the steering phase its yaw is
	# off-line, and teleported like that it veers into a booth island.
	var forward: Vector3 = _road.call("direction_at", toll_distance - 3.0)
	var right := forward.cross(Vector3.UP).normalized()
	_truck.global_transform = Transform3D(Basis(right, Vector3.UP, -forward), spot)
	_truck.linear_velocity = Vector3.ZERO
	_truck.angular_velocity = Vector3.ZERO

	var career := get_node_or_null("/root/Career")

	if career != null:
		career.set("cash", 100)

	Input.action_press("rv_throttle", 1.0)


func _check_toll() -> void:
	var plaza := _road.get_node_or_null("TollPlaza") as TollPlaza
	_check(plaza != null, "toll plaza controller found")

	if plaza == null:
		return

	_check(plaza.is_open(), "the toll arms lifted for the truck")
	_check(plaza.charged(), "passing the booths charged the toll")

	var career := get_node_or_null("/root/Career")

	if career != null:
		_check(int(career.get("cash")) == 88, "the wallet paid the $12 toll ($%d left)" % int(career.get("cash")))


func _arm_delivery() -> void:
	if _mission == null:
		return

	# Put the truck a couple of metres short of the gate instead of driving the
	# remaining 570 m, then let the mission decide it has arrived.
	var target: float = _mission.progress + 30.0
	var spot: Vector3 = _road.call("point_at", target, 0.0, 1.4)
	_truck.global_transform = Transform3D(_truck.global_transform.basis, spot)
	_truck.linear_velocity = Vector3.ZERO
	_truck.angular_velocity = Vector3.ZERO

	_mission.goal_distance = target + 0.5
	_mission.arrival_speed_kph = 200.0
	Input.action_press("rv_throttle", 1.0)


func _check_delivery() -> void:
	if _mission == null:
		return

	_check(_mission.state == Mission.State.DELIVERED, "reaching the gate completes the delivery")
	_check(_mission.score > 0.0, "the run is scored (%d)" % roundi(_mission.score))
	_check(_mission.damage >= 0.0 and _mission.damage <= 1.0, "damage stays in range (%.0f%%)" % (_mission.damage * 100.0))
	_check("DELIVERED" in _mission.status_text(), "the HUD announces the delivery")

	var career := get_node_or_null("/root/Career")

	if career != null:
		_check(int(career.get("cash")) > _cash_before, "the delivery paid out ($%d)" % int(career.get("cash")))
		_check(int(career.get("job_index")) == _job_before + 1, "the next job is queued")

	if _results != null and _results.has_method("is_showing"):
		_check(_results.call("is_showing"), "the results screen is on")
		_check("Score" in String(_results.call("summary_text")), "the results screen shows the score")

	_check_model_socket()


## With models/truck.glb in the repo the real mesh has to be fitted and driving;
## without it the procedural truck has to be left alone. Both are exercised.
func _check_model_socket() -> void:
	var socket := _truck.get_node_or_null("TruckModel") as TruckModel
	_check(socket != null, "the truck has a model socket")

	if socket == null:
		return

	var visuals := _truck.get_node_or_null("WheelVisuals") as WheelVisuals

	if not TruckModel.model_exists():
		_check(not socket.has_model, "with no file on disk the procedural truck is used")
		_check(_truck.get_node("Body").visible, "the placeholder body stays visible")

		var fake := Node3D.new()
		fake.name = "FakeTruckModel"

		for wheel_name in ["wheel_fl", "wheel_fr", "wheel_rl", "wheel_rr"]:
			var wheel := Node3D.new()
			wheel.name = wheel_name
			var mesh := MeshInstance3D.new()
			mesh.name = "mesh_" + wheel_name
			mesh.mesh = BoxMesh.new()
			wheel.add_child(mesh)
			fake.add_child(wheel)

		_check(socket.apply_model(fake), "a model can be dropped in at runtime")
		_check(socket.adopted_wheel_count() >= 4, "the model's wheels were adopted (%d)" % socket.adopted_wheel_count())
		return

	_check(socket.has_model, "the GLB was loaded and fitted")
	_check(socket.glass_panel_count >= 1, "the cab glass was made see-through (%d panels)" % socket.glass_panel_count)
	_check(not (_truck.get_node("Body") as Node3D).visible, "the placeholder body is hidden")
	_check(not (_truck.get_node("Cab") as Node3D).visible, "the placeholder cab is hidden")

	_check(socket.model_width > 2.0 and socket.model_width < 3.0,
		"fitted to a real width (%.2f m)" % socket.model_width)
	_check(socket.model_length > 8.0, "fitted to a truck length (%.2f m)" % socket.model_length)
	_check(socket.model_height > 2.0, "fitted to a truck height (%.2f m)" % socket.model_height)

	if visuals != null:
		_check(visuals.model_wheel_count() >= 4, "the model's wheels are driven (%d)" % visuals.model_wheel_count())
		_check(visuals.model_steering_count() == 2, "both front wheels steer (%d)" % visuals.model_steering_count())

	# Regression (user screenshot, 2026-11-12): the fitted wheels sat 1.16 m too
	# low, buried in the road. Their centres must sit on the physics anchors.
	var wheel_heights_ok := true
	var wheel_bottom := INF

	for entry in socket.wheel_report():
		if absf(float(entry["y"]) - 0.7) > 0.15:
			wheel_heights_ok = false
		wheel_bottom = minf(wheel_bottom, float(entry["y"]) - float(entry["radius"]))

	_check(socket.wheel_report().size() >= 4, "the wheel report finds the wheels (%d)" % socket.wheel_report().size())
	_check(wheel_heights_ok, "the model's wheel centres sit on the wheel anchors")
	# The bound centres wobble ~0.2 m with wheel spin (spoked rims are not
	# centred on their pivots); the burial this guards against was -1.1 m.
	_check(wheel_bottom > -0.30, "the model's wheels are not buried in the road (bottom %.2f)" % wheel_bottom)

	_check(not (_truck.get_node("WheelFL/Spin/Visual") as Node3D).visible, "the primitive wheels are hidden")


func _finish() -> void:
	if _failures == 0:
		print("[drive] PASS")
		get_tree().quit(0)
	else:
		printerr("[drive] FAIL (%d checks)" % _failures)
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)
