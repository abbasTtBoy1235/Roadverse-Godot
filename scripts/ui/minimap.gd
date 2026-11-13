class_name Minimap
extends Control
## A live route map in the corner of the HUD: the whole haul on one card —
## both cities, the depots, the toll, the gate, and you. Drawn from the
## road's own curve, so every procedurally dealt route maps itself.

const MAP_SIZE := Vector2(188, 188)
const PADDING := 10.0

var goal_distance := 0.0

var _truck: Node3D
var _road: Node3D
var _points: Array[Vector2] = []
var _min := Vector2.ZERO
var _span := Vector2.ONE
var _redraw_cooldown := 0.0


func setup(road: Node3D, truck: Node3D) -> void:
	_road = road
	_truck = truck
	_points.clear()

	if road == null or road.get("curve") == null:
		return

	var curve := road.get("curve") as Curve3D
	var length := curve.get_baked_length()
	var steps := clampi(int(length / 8.0), 24, 320)

	for i in steps + 1:
		var point := curve.sample_baked(length * float(i) / float(steps))
		_points.append(Vector2(point.x, point.z))

	if _points.is_empty():
		return

	_min = _points[0]
	var max_point := _points[0]

	for point in _points:
		_min.x = minf(_min.x, point.x)
		_min.y = minf(_min.y, point.y)
		max_point.x = maxf(max_point.x, point.x)
		max_point.y = maxf(max_point.y, point.y)

	_span = Vector2(maxf(max_point.x - _min.x, 1.0), maxf(max_point.y - _min.y, 1.0))
	queue_redraw()


## World (x,z) -> map-local pixels. North (-Z) is up.
func project(world: Vector3) -> Vector2:
	var inner := MAP_SIZE - Vector2(PADDING, PADDING) * 2.0
	var scale := minf(inner.x / _span.x, inner.y / _span.y)
	var used := _span * scale
	var origin := (MAP_SIZE - used) * 0.5

	return origin + Vector2((world.x - _min.x) * scale, (world.z - _min.y) * scale)


func _process(delta: float) -> void:
	_redraw_cooldown -= delta

	if _redraw_cooldown <= 0.0 and _truck != null:
		_redraw_cooldown = 0.15
		queue_redraw()


func _draw() -> void:
	if _points.size() < 2:
		return

	draw_rect(Rect2(Vector2.ZERO, MAP_SIZE), Color(0.01, 0.02, 0.04, 0.72))

	# Route ribbon, then the cities as brighter stretches at both ends.
	var line: PackedVector2Array = []

	for point in _points:
		line.append(project(Vector3(point.x, 0.0, point.y)))

	draw_polyline(line, Color(0.55, 0.62, 0.75, 0.9), 2.0)

	if _road != null:
		_draw_marker(_road.get("loading_depot_position"), Color(0.4, 0.8, 1.0), true)
		_draw_marker(_road.get("delivery_depot_position"), Color(0.45, 1.0, 0.65), true)

		var toll: float = _road.get("toll_distance")

		if toll > 0.0 and _road.has_method("point_at"):
			var toll_point: Vector3 = _road.call("point_at", toll, 0.0, 0.0)
			draw_circle(project(toll_point), 3.5, Color(1.0, 0.75, 0.3))

		if goal_distance > 0.0 and _road.has_method("point_at"):
			var gate_point: Vector3 = _road.call("point_at", goal_distance, 0.0, 0.0)
			var gate_pos := project(gate_point)
			draw_circle(gate_pos, 4.5, Color(0.45, 1.0, 0.65))
			draw_circle(gate_pos, 2.0, Color(0.02, 0.05, 0.03))

	if _truck != null:
		var truck_pos := project(_truck.global_position)
		draw_circle(truck_pos, 5.0, Color(1.0, 1.0, 1.0))
		draw_circle(truck_pos, 2.6, Color(0.95, 0.55, 0.2))


func _draw_marker(world: Variant, colour: Color, square: bool) -> void:
	if not (world is Vector3):
		return

	var pos := project(world as Vector3)

	if square:
		draw_rect(Rect2(pos - Vector2(3.5, 3.5), Vector2(7, 7)), colour)
	else:
		draw_circle(pos, 3.5, colour)


## Test hooks.
func route_point_count() -> int:
	return _points.size()


func has_road() -> bool:
	return _road != null and not _points.is_empty()
