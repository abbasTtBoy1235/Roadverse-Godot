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
	background.color = Color(0.02, 0.025, 0.04)
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var glow := ColorRect.new()
	glow.name = "HorizonGlow"
	glow.color = Color(0.10, 0.07, 0.13, 0.9)
	glow.set_anchors_preset(Control.PRESET_FULL_RECT)
	glow.anchor_top = 0.55
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(glow)

	var title := Label.new()
	title.name = "Title"
	title.text = "ROADVERSE"
	title.add_theme_font_size_override("font_size", 92)
	title.add_theme_color_override("font_color", Color(0.96, 0.93, 0.86))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_preset(Control.PRESET_TOP_WIDE)
	title.offset_top = 120
	add_child(title)

	var subtitle := Label.new()
	subtitle.name = "Subtitle"
	subtitle.text = "night hauls on the long road"
	subtitle.add_theme_font_size_override("font_size", 20)
	subtitle.add_theme_color_override("font_color", Color(0.55, 0.6, 0.72))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.set_anchors_preset(Control.PRESET_TOP_WIDE)
	subtitle.offset_top = 224
	add_child(subtitle)

	_menu_box = VBoxContainer.new()
	_menu_box.name = "MenuBox"
	_menu_box.set_anchors_preset(Control.PRESET_CENTER)
	_menu_box.custom_minimum_size = Vector2(320, 0)
	_menu_box.position = Vector2(-160, 40)
	_menu_box.add_theme_constant_override("separation", 14)
	add_child(_menu_box)

	play_button = _make_button(_menu_box, "PlayButton", "PLAY")
	settings_button = _make_button(_menu_box, "SettingsButton", "SETTINGS")
	quit_button = _make_button(_menu_box, "QuitButton", "QUIT")

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
	add_child(_settings_panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_settings_panel.add_child(column)

	var heading := Label.new()
	heading.text = "SETTINGS"
	heading.add_theme_font_size_override("font_size", 26)
	column.add_child(heading)

	var sensitivity_label := Label.new()
	sensitivity_label.text = "Mouse sensitivity"
	column.add_child(sensitivity_label)

	sensitivity_slider = HSlider.new()
	sensitivity_slider.name = "SensitivitySlider"
	sensitivity_slider.min_value = 0.02
	sensitivity_slider.max_value = 0.40
	sensitivity_slider.step = 0.01
	sensitivity_slider.value = Settings.mouse_sensitivity
	sensitivity_slider.value_changed.connect(_on_sensitivity_changed)
	column.add_child(sensitivity_slider)

	invert_check = CheckButton.new()
	invert_check.name = "InvertCheck"
	invert_check.text = "Invert vertical look"
	invert_check.button_pressed = Settings.invert_y
	invert_check.toggled.connect(_on_invert_toggled)
	column.add_child(invert_check)

	fullscreen_check = CheckButton.new()
	fullscreen_check.name = "FullscreenCheck"
	fullscreen_check.text = "Fullscreen"
	fullscreen_check.button_pressed = Settings.fullscreen
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	column.add_child(fullscreen_check)

	back_button = _make_button(column, "BackButton", "BACK")
	back_button.pressed.connect(_on_back_pressed)


func _make_button(parent: Node, node_name: String, text: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.text = text
	button.custom_minimum_size = Vector2(0, 46)
	button.add_theme_font_size_override("font_size", 20)
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
