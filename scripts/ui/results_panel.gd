extends CanvasLayer
## The end-of-job screen: what it paid, what it cost, and the way into the next
## route. Pauses the world while it is up, so a bad arrival is not scored while
## the rig keeps rolling.

@export var mission_path: NodePath

var _mission: Mission
var _title: Label
var _lines: Label
var _hint: Label
var _action: Button
var _visible := false
var _failed := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_mission = get_node_or_null(mission_path) as Mission
	_build()

	if _mission != null:
		_mission.delivered.connect(_on_delivered)
		_mission.failed.connect(_on_failed)


func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.visible = false
	add_child(root)

	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.02, 0.03, 0.82)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(shade)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(520, 0)
	panel.add_theme_stylebox_override("panel", _panel_style())
	root.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)

	_title = _make_label(column, 34, Color(0.6, 1.0, 0.75))
	_lines = _make_label(column, 19, Color(0.86, 0.9, 0.96))
	_hint = _make_label(column, 15, Color(0.6, 0.64, 0.72))

	_action = Button.new()
	_action.text = "NEXT JOB  (Enter)"
	_action.custom_minimum_size = Vector2(0, 42)
	_action.pressed.connect(_continue)
	column.add_child(_action)

	_visible = false
	_root_control().visible = false


func _make_label(parent: Node, font_size: int, colour: Color) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", colour)
	parent.add_child(label)
	return label


func _panel_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.05, 0.08, 0.96)
	style.border_color = Color(0.25, 0.55, 0.4, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(26)
	return style


func _root_control() -> Control:
	return get_node_or_null("Root") as Control


func _on_delivered(summary: Dictionary) -> void:
	_failed = false
	_title.text = "DELIVERED"
	_title.add_theme_color_override("font_color", Color(0.6, 1.0, 0.75))

	var career := get_node_or_null("/root/Career")
	var paid := int(summary.get("paid", 0))
	var cash := int(career.get("cash")) if career != null else paid
	var rank := String(career.call("rank")) if career != null else "Rookie"
	var best := int(career.get("best_score")) if career != null else int(summary.get("score", 0.0))

	_lines.text = "%s\n%s\nTime %.0fs   ·   damage %d%%\nPaid $%d   ·   total $%d   ·   best %d\nRank: %s" % [
		summary.get("cargo", "Cargo"),
		"Score %d" % roundi(float(summary.get("score", 0.0))),
		float(summary.get("seconds", 0.0)),
		roundi(float(summary.get("damage", 0.0)) * 100.0),
		paid, cash, best, rank,
	]

	_action.text = "NEXT JOB  (Enter)"
	_hint.text = "Press Enter to take the next route."
	_show()


func _on_failed(summary: Dictionary) -> void:
	_failed = true
	_title.text = "CARGO WRECKED"
	_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45))

	_lines.text = "%s\nDamage %d%%   ·   time %.0fs\nNo pay. The same route is waiting." % [
		summary.get("cargo", "Cargo"),
		roundi(float(summary.get("damage", 0.0)) * 100.0),
		float(summary.get("seconds", 0.0)),
	]

	_action.text = "TRY AGAIN  (Enter)"
	_hint.text = "Press Enter to run the load again."
	_show()


func _show() -> void:
	_visible = true
	var root := _root_control()

	if root != null:
		root.visible = true

	get_tree().paused = true
	_action.grab_focus()


func _unhandled_input(event: InputEvent) -> void:
	if _visible and event.is_action_pressed("rv_next_job"):
		_continue()
		get_viewport().set_input_as_handled()


func _continue() -> void:
	if not _visible:
		return

	_visible = false
	get_tree().paused = false
	get_tree().reload_current_scene()


## Test hook: is the summary on screen?
func is_showing() -> bool:
	return _visible


## Test hook: the line under the title.
func summary_text() -> String:
	return _lines.text if _lines != null else ""


## Test hook: did the last job fail?
func failed() -> bool:
	return _failed
