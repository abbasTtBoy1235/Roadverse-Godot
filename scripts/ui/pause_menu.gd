extends CanvasLayer
## Esc pause overlay. Runs while the tree is paused, so its process mode is
## forced to ALWAYS.

const MAIN_MENU_SCENE := "res://scenes/menu.tscn"

var resume_button: Button
var restart_button: Button
var menu_button: Button
var quit_button: Button

var _panel: PanelContainer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 10
	_build()
	visible = false


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("rv_pause") or event.is_action_pressed("ui_cancel"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	get_tree().paused = paused
	visible = paused

	if paused:
		resume_button.grab_focus()
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		ChaseCamera.capture_mouse()


func _build() -> void:
	var dim := ColorRect.new()
	dim.name = "Dim"
	dim.color = Color(0.01, 0.015, 0.03, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.custom_minimum_size = Vector2(340, 0)
	_panel.position = Vector2(-170, -130)

	var card := StyleBoxFlat.new()
	card.bg_color = Color(0.03, 0.04, 0.08, 0.97)
	card.border_color = Color(0.95, 0.62, 0.22, 0.55)
	card.set_border_width_all(1)
	card.set_corner_radius_all(14)
	card.content_margin_left = 24
	card.content_margin_right = 24
	card.content_margin_top = 20
	card.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", card)
	add_child(_panel)

	var column := VBoxContainer.new()
	column.name = "Buttons"
	column.add_theme_constant_override("separation", 12)
	_panel.add_child(column)

	var heading := Label.new()
	heading.name = "Heading"
	heading.text = "PAUSED"
	heading.add_theme_font_size_override("font_size", 30)
	heading.add_theme_color_override("font_color", Color(0.95, 0.68, 0.3))
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(heading)

	resume_button = _make_button(column, "ResumeButton", "RESUME")
	restart_button = _make_button(column, "RestartButton", "RESTART")
	menu_button = _make_button(column, "MenuButton", "MAIN MENU")
	quit_button = _make_button(column, "QuitButton", "QUIT")

	resume_button.pressed.connect(_on_resume)
	restart_button.pressed.connect(_on_restart)
	menu_button.pressed.connect(_on_menu)
	quit_button.pressed.connect(_on_quit)


func _make_button(parent: Node, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 48)
	button.add_theme_font_size_override("font_size", 19)
	button.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
	button.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.6))

	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.06, 0.075, 0.13, 0.95)
	normal.border_color = Color(0.35, 0.42, 0.58, 0.8)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(10)
	button.add_theme_stylebox_override("normal", normal)

	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.11, 0.14, 0.22, 0.98)
	hover.border_color = Color(0.95, 0.62, 0.22, 0.9)
	hover.set_border_width_all(1)
	hover.set_corner_radius_all(10)
	button.add_theme_stylebox_override("hover", hover)
	parent.add_child(button)
	return button


func _on_resume() -> void:
	set_paused(false)


func _on_restart() -> void:
	set_paused(false)
	get_tree().reload_current_scene()


func _on_menu() -> void:
	set_paused(false)
	get_tree().change_scene_to_file(MAIN_MENU_SCENE)


func _on_quit() -> void:
	get_tree().quit()
