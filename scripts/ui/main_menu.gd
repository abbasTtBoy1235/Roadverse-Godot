extends Control
## Main menu. Built in code so the whole flow is testable headlessly.

const MAIN_SCENE := "res://scenes/main.tscn"

var play_button: Button
var settings_button: Button
var quit_button: Button
var back_button: Button
var sensitivity_slider: HSlider
var invert_check: CheckButton
var fullscreen_check: CheckButton

var _settings_panel: PanelContainer
var _menu_box: VBoxContainer


func _ready() -> void:
	InputSetup.ensure_registered()

	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	_build()
	play_button.grab_focus()


func _build() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color(0.01, 0.015, 0.03)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	# Night-sky gradient: deep blue up top, a warm sodium glow at the horizon.
	var gradient := Gradient.new()
	gradient.set_color(0, Color(0.008, 0.012, 0.03))
	gradient.add_point(0.55, Color(0.02, 0.04, 0.09))
	gradient.add_point(0.8, Color(0.14, 0.08, 0.15))
	gradient.set_color(1, Color(0.03, 0.02, 0.05))

	var backdrop_texture := GradientTexture2D.new()
	backdrop_texture.gradient = gradient
	backdrop_texture.fill_from = Vector2(0.5, 0.0)
	backdrop_texture.fill_to = Vector2(0.5, 1.0)

	var backdrop := TextureRect.new()
	backdrop.name = "Backdrop"
	backdrop.texture = backdrop_texture
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.stretch_mode = TextureRect.STRETCH_SCALE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var title_settings := LabelSettings.new()
	title_settings.font_size = 96
	title_settings.font_color = Color(0.98, 0.94, 0.86)
	title_settings.shadow_color = Color(0.0, 0.0, 0.0, 0.65)
	title_settings.shadow_offset = Vector2(3.0, 4.0)
	title_settings.shadow_size = 6

	var title := Label.new()
	title.name = "Title"
	title.text = "ROADVERSE"
	title.label_settings = title_settings
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 104
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "N I G H T   H A U L S   O N   T H E   L O N G   R O A D"
	subtitle.add_theme_font_size_override("font_size", 16)
	subtitle.add_theme_color_override("font_color", Color(0.62, 0.68, 0.82))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 218
	add_child(subtitle)

	# Amber rule under the title, like a sodium lamp on wet tarmac.
	var rule := ColorRect.new()
	rule.name = "TitleRule"
	rule.color = Color(0.95, 0.62, 0.22, 0.9)
	rule.set_anchors_preset(Control.PRESET_CENTER_TOP)
	rule.offset_left = -110
	rule.offset_right = 110
	rule.offset_top = 256
	rule.offset_bottom = 259
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(rule)

	_menu_box = VBoxContainer.new()
	_menu_box.name = "MenuBox"
	_menu_box.set_anchors_preset(Control.PRESET_CENTER)
	_menu_box.custom_minimum_size = Vector2(360, 0)
	_menu_box.position = Vector2(-180, 52)
	_menu_box.add_theme_constant_override("separation", 12)
	add_child(_menu_box)

	var career := get_node_or_null("/root/Career")

	if career != null:
		var job := int(career.get("job_index")) + 1
		var cargo := String(career.call("current_cargo")).to_lower()

		var status := Label.new()
		status.name = "CareerStatus"
		status.text = "Job %d  ·  %s\n$%d  ·  %s  ·  best %d" % [
			job, cargo,
			int(career.get("cash")),
			String(career.call("rank")),
			int(career.get("best_score")),
		]
		status.add_theme_font_size_override("font_size", 16)
		status.add_theme_color_override("font_color", Color(0.5, 0.78, 0.6))
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_menu_box.add_child(status)

	play_button = _make_button(_menu_box, "PlayButton", "▶  PLAY", true)
	settings_button = _make_button(_menu_box, "SettingsButton", "SETTINGS")
	quit_button = _make_button(_menu_box, "QuitButton", "QUIT")

	var hint := Label.new()
	hint.name = "ControlsHint"
	hint.text = "W/S drive  ·  mouse look  ·  C camera  ·  Esc pause"
	hint.add_theme_font_size_override("font_size", 13)
	hint.add_theme_color_override("font_color", Color(0.45, 0.5, 0.62))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_menu_box.add_child(hint)

	play_button.pressed.connect(_on_play_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	_build_settings_panel()


func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(460, 0)
	_settings_panel.position = Vector2(-230, -80)
	_settings_panel.visible = false
	_settings_panel.add_theme_stylebox_override("panel", _card_style())
	add_child(_settings_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(column)

	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.95, 0.68, 0.3))
	column.add_child(heading)

	var sensitivity_label := Label.new()
	sensitivity_label.text = "Mouse sensitivity"
	sensitivity_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	column.add_child(sensitivity_label)

	sensitivity_slider = HSlider.new()
	sensitivity_slider.name = "SensitivitySlider"
	sensitivity_slider.min_value = 0.0008
	sensitivity_slider.max_value = 0.008
	sensitivity_slider.step = 0.0002
	sensitivity_slider.value = Settings.mouse_sensitivity
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	column.add_child(sensitivity_slider)

	invert_check = CheckButton.new()
	invert_check.name = "InvertCheck"
	invert_check.text = "Invert vertical look"
	invert_check.add_theme_color_override("font_color", Color(0.78, 0.81, 0.9))
	invert_check.button_pressed = Settings.invert_y
	invert_check.toggled.connect(_on_invert_toggled)
	column.add_child(invert_check)

	fullscreen_check = CheckButton.new()
	fullscreen_check.name = "FullscreenCheck"
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.add_theme_color_override("font_color", Color(0.78, 0.81, 0.9))
	fullscreen_check.button_pressed = Settings.fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	column.add_child(fullscreen_check)

	back_button = _make_button(column, "BackButton", "BACK")
	back_button.pressed.connect(_on_back_pressed)


## Dark glass card used by the settings panel.
func _card_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.045, 0.085, 0.97)
	style.border_color = Color(0.95, 0.62, 0.22, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(14)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	return style


func _button_style(bg: Color, border: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(10)
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _make_button(parent: Node, node_name: String, text: String, primary := false) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 52)
	button.add_theme_font_size_override("font_size", 20)

	if primary:
		button.add_theme_color_override("font_color", Color(0.12, 0.07, 0.02))
		button.add_theme_color_override("font_hover_color", Color(0.08, 0.04, 0.01))
		button.add_theme_stylebox_override("normal", _button_style(Color(0.93, 0.6, 0.2), Color(1.0, 0.75, 0.35)))
		button.add_theme_stylebox_override("hover", _button_style(Color(1.0, 0.68, 0.26), Color(1.0, 0.85, 0.5)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.78, 0.48, 0.14), Color(1.0, 0.75, 0.35)))
	else:
		button.add_theme_color_override("font_color", Color(0.88, 0.9, 0.96))
		button.add_theme_color_override("font_hover_color", Color(1.0, 0.85, 0.6))
		button.add_theme_stylebox_override("normal", _button_style(Color(0.06, 0.075, 0.13, 0.95), Color(0.35, 0.42, 0.58, 0.8)))
		button.add_theme_stylebox_override("hover", _button_style(Color(0.11, 0.14, 0.22, 0.98), Color(0.95, 0.62, 0.22, 0.9)))
		button.add_theme_stylebox_override("pressed", _button_style(Color(0.16, 0.1, 0.05, 0.98), Color(0.95, 0.62, 0.22)))

	button.add_theme_stylebox_override("focus", _button_style(Color(0, 0, 0, 0), Color(0.5, 0.75, 1.0, 0.9)))
	parent.add_child(button)
	return button


func _on_play_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_SCENE)


func _on_settings_pressed() -> void:
	_menu_box.visible = false
	_settings_panel.visible = true
	sensitivity_slider.grab_focus()


func _on_back_pressed() -> void:
	_settings_panel.visible = false
	_menu_box.visible = true
	settings_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_sensitivity_changed(value: float) -> void:
	Settings.set_mouse_sensitivity(value)


func _on_invert_toggled(value: bool) -> void:
	Settings.set_invert_y(value)


func _on_fullscreen_toggled(value: bool) -> void:
	Settings.set_fullscreen(value)
