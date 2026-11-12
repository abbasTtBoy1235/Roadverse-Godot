extends Node3D
## Integration test: drives the real scene and checks that the wheels turn, the
## engine synth follows the revs, and the traffic moves along the road.
##
##   godot --headless --path . res://tests/drive_state.tscn

const DRIVE_SECONDS := 4.0
const STEER_SECONDS := 1.0
const RAIN_SECONDS := 2.0
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
	_check(_weather != null, "weather found")
	_check(_noise != null, "road noise found")
	_check(_road != null, "road found")
	# The GLB is a complete truck with its own cargo body; the game used to hang
	# a second, procedural trailer behind it. It must not come back.
	_check(_trailer == null, "no second trailer is attached behind the truck")
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

	if _mission != null:
		_check(_mission.gate_built, "the delivery gate was built")
		_check(_mission.goal_distance > 100.0, "the gate sits down the road (%.0f m)" % _mission.goal_distance)

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
		_arm_delivery()

	elif _phase == 3 and _elapsed >= DRIVE_SECONDS + STEER_SECONDS + RAIN_SECONDS + DELIVERY_SECONDS:
		_phase = 4
		_check_delivery()
		Input.action_release("rv_throttle")
		_finish()


func _check_drive() -> void:
	if _wheels != null:
		_check(absf(_wheels.spin_angle(0) - _spin_before) > 0.5, "wheels spin while driving")

	if _audio != null:
		var frequency := _audio.current_frequency()
		_check(frequency > 30.0, "engine synth runs at a believable pitch (%.0f Hz)" % frequency)

	if _traffic != null:
		var after: Array[float] = _traffic.call("car_distances")
		var moved := 0
		for i in mini(after.size(), _traffic_before.size()):
			if absf(after[i] - _traffic_before[i]) > 0.5:
				moved += 1
		_check(moved > 0, "traffic cars move along the road (%d of %d moved)" % [moved, after.size()])

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
	_check(wheel_bottom > -0.12, "the model's wheels are not buried in the road (bottom %.2f)" % wheel_bottom)

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
