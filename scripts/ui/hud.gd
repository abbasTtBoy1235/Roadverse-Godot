extends CanvasLayer
## Minimal debug HUD: speed, gear, RPM, headlight state and the control reminder.
## Built in code so the scene file stays readable.

@export var truck_path: NodePath

var _truck: TruckController
var _speed_label: Label
var _gear_label: Label
var _hint_label: Label


func _ready() -> void:
	_truck = get_node_or_null(truck_path) as TruckController
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

	_hint_label = _make_label(self, 15, Color(0.75, 0.78, 0.85))
	_hint_label.position = Vector2(24, 170)
	_hint_label.text = "W/S throttle · A/D steer · Space handbrake · L lights · C camera · R restart"


func _make_label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label


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


func _process(_delta: float) -> void:
	if _truck == null:
		return

	_speed_label.text = "%d km/h" % roundi(_truck.speed_kph())

	var gear_text := "R" if _truck.gearbox.is_reverse else str(_truck.gearbox.current_gear)
	var lights := "lights ON" if _headlights_on() else "lights OFF"
	_gear_label.text = "gear %s   %d rpm   %s" % [gear_text, roundi(_truck.engine_rpm), lights]


func _headlights_on() -> bool:
	var lights := _truck.get_node_or_null("Lights") as TruckLights
	return lights != null and lights.headlights_on
