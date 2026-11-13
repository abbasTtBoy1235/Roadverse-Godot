extends CanvasLayer
## Minimal debug HUD: speed, gear, RPM, headlight state and the control reminder.
## Built in code so the scene file stays readable.

@export var truck_path: NodePath

var _truck: TruckController
var _time: TimeOfDay
var _speed_label: Label
var _gear_label: Label
var _hint_label: Label
var _mission_label: Label
var _mission: Mission
var _career_label: Label
var _damage_bar: ProgressBar


func _ready() -> void:
	_truck = get_node_or_null(truck_path) as TruckController
	_time = get_node_or_null("../TimeOfDay") as TimeOfDay
	_mission = get_node_or_null("../Mission") as Mission
	_build()


func _build() -> void:
	var panel := PanelContainer.new()
	panel.position = Vector2(24, 24)
	panel.add_theme_stylebox_override("panel", _panel_style())
	add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	panel.add_child(column)

	_speed_label = _make_label(column, 40, Color(0.95, 0.97, 1.0))
	_gear_label = _make_label(column, 20, Color(0.75, 0.85, 1.0))

	_mission_label = _make_label(self, 20, Color(0.55, 1.0, 0.7))
	_mission_label.position = Vector2(24, 118)

	_career_label = _make_label(self, 15, Color(0.62, 0.66, 0.78))
	_career_label.position = Vector2(24, 146)

	_damage_bar = ProgressBar.new()
	_damage_bar.position = Vector2(24, 196)
	_damage_bar.size = Vector2(180, 8)
	_damage_bar.min_value = 0.0
	_damage_bar.max_value = 100.0
	_damage_bar.show_percentage = false
	_damage_bar.add_theme_stylebox_override("background", _bar_style(Color(0.08, 0.1, 0.12, 0.85)))
	_damage_bar.add_theme_stylebox_override("fill", _bar_style(Color(0.9, 0.55, 0.25)))
	add_child(_damage_bar)

	_hint_label = _make_label(self, 15, Color(0.75, 0.78, 0.85))
	_hint_label.position = Vector2(24, 172)
	_hint_label.text = "W/S throttle · A/D steer · Space handbrake · L lights · C camera · F rain · R restart · Esc pause"


func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


func _bar_style(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(4)
	return style


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.03, 0.05, 0.55)
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


## Speed limit by route progress: open road, then the city limit.
static func speed_limit_for(progress: float) -> int:
	return 50 if progress > 0.68 else 90


func _process(_delta: float) -> void:
	if _truck == null:
		return

	_speed_label.text = "%d km/h" % roundi(_truck.speed_kph())

	var road := get_node_or_null("../Road")
	var limit := 0

	if road != null and ("curve" in road):
		var curve: Curve3D = road.get("curve")
		var progress: float = road.call("nearest_distance", _truck.global_position) / maxf(1.0, curve.get_baked_length())
		limit = speed_limit_for(progress)

	if limit > 0:
		_speed_label.text += "  ·  limit %d" % limit
		_speed_label.add_theme_color_override("font_color",
			Color(1.0, 0.45, 0.3) if _truck.speed_kph() > float(limit) + 2.0 else Color(0.95, 0.97, 1.0))

	var gear_text := "R" if _truck.gearbox.is_reverse else str(_truck.gearbox.current_gear)
	var lights := "lights ON" if _headlights_on() else "lights OFF"
	var clock := DayCycle.clock_string(_time.current_hour()) if _time != null else "--:--"
	var fuel := _truck.get_node_or_null("FuelTank") as FuelTank
	var fuel_text := "fuel %d%%" % roundi(fuel.level() * 100.0) if fuel != null else "fuel --"
	_gear_label.text = "%s   gear %s   %d rpm   %s   %s" % [clock, gear_text, roundi(_truck.engine_rpm), fuel_text, lights]

	if _mission != null:
		_mission_label.text = _mission.status_text()
		_damage_bar.value = _mission.damage * 100.0

	var career := get_node_or_null("/root/Career")

	if career != null and _career_label != null:
		_career_label.text = "JOB %d  ·  $%d  ·  %s  ·  best %d" % [
			int(career.get("job_index")) + 1,
			int(career.get("cash")),
			String(career.call("rank")),
			int(career.get("best_score")),
		]


func _headlights_on() -> bool:
	var lights := _truck.get_node_or_null("Lights") as TruckLights
	return lights != null and lights.headlights_on
