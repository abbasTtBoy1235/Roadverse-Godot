class_name Mission
extends Node
## One delivery job: drag the load from the start of the road to the gate at the
## far end without wrecking it. Tracks time and cargo damage, scores the run.
##
## The maths lives in static functions so the headless suite can test it without
## driving anywhere.

signal state_changed(state: int)
signal delivered(summary: Dictionary)
signal failed(summary: Dictionary)

enum State { DRIVING, DELIVERED, FAILED }

@export_group("Job")
@export var cargo_name := ""
@export var goal_fraction := 0.92
@export var arrival_speed_kph := 15.0
@export var par_seconds := 95.0
@export var base_score := 1000.0

@export_group("Damage")
## Speed change (m/s) in a single frame before the cargo takes a hit.
@export var impact_threshold := 3.0
@export var damage_per_impact := 0.02

@export_group("Wiring")
@export var truck_path: NodePath
@export var road_path: NodePath

var job_kind := "standard"

var state := State.DRIVING
var elapsed := 0.0
var damage := 0.0
var goal_distance := 0.0
var progress := 0.0
var score := 0.0
var best_score := 0.0
var gate_built := false

var _truck: TruckController
var _road: Node3D
var _gate: Node3D
var _bay_centre := Vector3.INF
var _last_speed := 0.0
var _fuel: FuelTank


## Damage caused by one shock, as a fraction of the cargo's value.
static func damage_for_impact(delta_speed: float, per_impact: float, threshold: float) -> float:
	if delta_speed <= threshold:
		return 0.0

	return clampf((delta_speed - threshold) * per_impact, 0.0, 0.4)


## Final score: the load's condition is worth most, then how quickly you got there.
static func score_for(elapsed_seconds: float, damage_taken: float, par: float, base: float) -> float:
	var condition := clampf(1.0 - damage_taken, 0.0, 1.0)
	var time_factor := clampf(par / maxf(elapsed_seconds, 1.0), 0.25, 1.0)

	return roundf(base * condition * (0.6 + 0.4 * time_factor))


## Has the truck arrived, i.e. reached the gate slowly enough to stop?
static func is_arrived(progress_distance: float, goal: float, speed_kph: float, arrival_speed: float) -> bool:
	return progress_distance >= goal and speed_kph <= arrival_speed


## Is the truck parked in the delivery bay (a precision finish)?
static func within_bay(position: Vector3, bay_centre: Vector3, radius: float) -> bool:
	var flat := Vector2(position.x - bay_centre.x, position.z - bay_centre.z)
	return flat.length() <= radius


## 0..1 progress towards the gate.
static func progress_fraction(progress_distance: float, goal: float) -> float:
	if goal <= 0.0:
		return 1.0

	return clampf(progress_distance / goal, 0.0, 1.0)


func _ready() -> void:
	_truck = get_node_or_null(truck_path) as TruckController

	var career := get_node_or_null("/root/Career")

	if cargo_name.is_empty():
		cargo_name = String(career.call("current_cargo")) if career != null else "Steel coils"

	if career != null:
		job_kind = String(career.call("current_kind"))

	_road = get_node_or_null(road_path) as Node3D

	if _road == null or not _road.has_method("nearest_distance"):
		push_warning("Mission: needs a road with nearest_distance().")
		return

	var length := float(_road.get("curve").get_baked_length()) if _road.get("curve") != null else 0.0
	goal_distance = length * clampf(goal_fraction, 0.1, 1.0)

	# The marked bay at the delivery depot is the precision finish.
	var depot := (_road as Node).get_node_or_null("DeliveryDepot") as Node3D

	if depot != null:
		_bay_centre = depot.to_global(Vector3(-14.0, 0.0, 0.0))

	_build_gate()
	gate_built = true

	if _truck != null:
		_last_speed = _truck.speed_kph()
		_fuel = _truck.get_node_or_null("FuelTank") as FuelTank

		if _fuel != null:
			_fuel.reset()


func _physics_process(delta: float) -> void:
	if state != State.DRIVING or _truck == null or _road == null:
		return

	elapsed += delta
	progress = float(_road.call("nearest_distance", _truck.global_position))

	var speed := _truck.speed_kph()
	var shock := absf(speed - _last_speed) / 3.6
	_last_speed = speed

	if shock > impact_threshold:
		var per_hit := damage_per_impact * CareerMath.damage_multiplier(job_kind)
		damage = clampf(damage + damage_for_impact(shock, per_hit, impact_threshold), 0.0, 1.0)

	if damage >= 1.0:
		_fail()
		return

	if is_arrived(progress, goal_distance, speed, arrival_speed_kph):
		_finish()
	elif _bay_centre != Vector3.INF and within_bay(_truck.global_position, _bay_centre, 9.5) and speed <= arrival_speed_kph:
		_finish()


func _finish() -> void:
	state = State.DELIVERED
	var summary := {}
	# Par time scales with the haul: 95 s was generous for 560 m and
	# impossible for 2 km. Urgent jobs run a tighter clock for a bonus.
	var effective_par := par_seconds * maxf(1.0, goal_distance / 560.0) * CareerMath.par_scale(job_kind)
	score = score_for(elapsed, damage, effective_par, base_score)

	if CareerMath.urgent_bonus_earned(job_kind, elapsed, effective_par):
		score = roundf(score * 1.25)

	if score > best_score:
		best_score = score

	var fuel_used := _fuel.litres_used if _fuel != null else 0.0
	var par := CareerMath.par_fuel(goal_distance)
	var bonus := CareerMath.economy_bonus(fuel_used, par)

	summary = {
		"score": score,
		"seconds": elapsed,
		"damage": damage,
		"cargo": cargo_name,
		"kind": job_kind,
		"delivered": true,
		"fuel_used": fuel_used,
		"fuel_bonus": bonus,
		"route_metres": goal_distance,
	}

	var career := get_node_or_null("/root/Career")

	if career != null:
		career.call("record_delivery", summary)
		var stored: Dictionary = career.get("last_summary")
		summary["paid"] = int(stored.get("paid", 0))

	state_changed.emit(state)
	delivered.emit(summary)


## The load did not survive the trip.
func _fail() -> void:
	state = State.FAILED
	score = 0.0

	var summary := {
		"score": 0.0,
		"seconds": elapsed,
		"damage": damage,
		"cargo": cargo_name,
		"delivered": false,
		"paid": 0,
	}

	var career := get_node_or_null("/root/Career")

	if career != null:
		career.call("record_failure", summary)

	state_changed.emit(state)
	failed.emit(summary)


## Test hook: wreck the load on purpose.
func take_damage(amount: float) -> void:
	damage = clampf(damage + amount, 0.0, 1.0)


## Human readable line for the HUD.
func status_text() -> String:
	if state == State.DELIVERED:
		return "%s DELIVERED  ·  score %d  ·  damage %d%%" % [cargo_name.to_upper(), roundi(score), roundi(damage * 100.0)]

	if state == State.FAILED:
		return "%s WRECKED  ·  job lost" % cargo_name.to_upper()

	var tag := "" if job_kind == "standard" else "[%s] " % job_kind.to_upper()
	var percent := roundi(progress_fraction(progress, goal_distance) * 100.0)
	var minutes := int(elapsed) / 60
	var seconds := int(elapsed) % 60

	return "%s%s  ·  %d%%  ·  %d:%02d  ·  damage %d%%" % [tag, cargo_name.to_upper(), percent, minutes, seconds, roundi(damage * 100.0)]


## The gate itself: two posts, a beam and a lit sign, built from code.
func _build_gate() -> void:
	if _road == null:
		return

	var half_width := 8.5
	var height := 6.0
	var left := _road.call("point_at", goal_distance, -half_width, 0.0) as Vector3
	var right := _road.call("point_at", goal_distance, half_width, 0.0) as Vector3
	var forward := _road.call("direction_at", goal_distance) as Vector3
	var basis := Basis.looking_at(forward, Vector3.UP)

	_gate = Node3D.new()
	_gate.name = "Gate"
	(_road as Node).add_child(_gate)

	var frame_material := StandardMaterial3D.new()
	frame_material.albedo_color = Color(0.2, 0.95, 0.55)
	frame_material.emission_enabled = true
	frame_material.emission = Color(0.25, 1.0, 0.6)
	frame_material.emission_energy_multiplier = 3.5
	frame_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	for point: Vector3 in [left, right]:
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.5, height, 0.5)

		var post := MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = frame_material
		post.position = point + Vector3.UP * (height * 0.5)
		_gate.add_child(post)

	var beam_mesh := BoxMesh.new()
	beam_mesh.size = Vector3(half_width * 2.0, 0.6, 0.6)

	var beam := MeshInstance3D.new()
	beam.mesh = beam_mesh
	beam.material_override = frame_material
	beam.transform = Transform3D(basis, (left + right) * 0.5 + Vector3.UP * height)
	_gate.add_child(beam)

	var light := OmniLight3D.new()
	light.light_color = Color(0.35, 1.0, 0.6)
	light.light_energy = 4.0
	light.omni_range = 26.0
	light.position = (left + right) * 0.5 + Vector3.UP * (height - 1.0)
	_gate.add_child(light)


## World position of the delivery gate, for the HUD's navigation arrow.
func gate_world_position() -> Vector3:
	if _road == null:
		return Vector3.ZERO

	return _road.call("point_at", goal_distance, 0.0, 3.0)


## Test hook: distance the truck still has to cover.
func remaining() -> float:
	return maxf(0.0, goal_distance - progress)
