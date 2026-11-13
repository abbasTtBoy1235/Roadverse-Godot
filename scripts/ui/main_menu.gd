extends Control
## Main menu. Built in code so the whole flow is testable headlessly.

const MAIN_SCENE := "res://scenes/main.tscn"

var play_button: Button
var career_button: Button
var help_button: Button
var settings_button: Button
var quit_button: Button
var back_button: Button
var sensitivity_slider: HSlider
var invert_check: CheckButton
var fullscreen_check: CheckButton
var volume_slider: HSlider
var fov_slider: HSlider
var height_slider: HSlider
var day_option: OptionButton
var quality_option: OptionButton
var career_stats_label: Label
var reset_career_button: Button
var driver_name_edit: LineEdit
var slot_option: OptionButton

var _settings_panel: PanelContainer
var _help_panel: PanelContainer
var _career_panel: PanelContainer
var _menu_box: VBoxContainer
var _status_label: Label
var _rule: ColorRect
var _pulse := 0.0


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
	_rule = ColorRect.new()
	var rule := _rule
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
		_status_label = status
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
	career_button = _make_button(_menu_box, "CareerButton", "CAREER")
	help_button = _make_button(_menu_box, "HelpButton", "HOW TO PLAY")
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
	career_button.pressed.connect(_on_career_pressed)
	help_button.pressed.connect(_on_help_pressed)
	settings_button.pressed.connect(_on_settings_pressed)
	quit_button.pressed.connect(_on_quit_pressed)

	var footer := Label.new()
	footer.name = "Footer"
	footer.text = "Two cities · a long road · one truck — every job deals a new route"
	footer.add_theme_font_size_override("font_size", 13)
	footer.add_theme_color_override("font_color", Color(0.4, 0.45, 0.58))
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	footer.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	footer.offset_top = -36
	add_child(footer)

	_build_settings_panel()
	_build_help_panel()
	_build_career_panel()


func _build_settings_panel() -> void:
	_settings_panel = PanelContainer.new()
	_settings_panel.name = "SettingsPanel"
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.custom_minimum_size = Vector2(460, 0)
	_settings_panel.position = Vector2(-230, -260)
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

	var volume_label := Label.new()
	volume_label.text = "Master volume"
	volume_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	column.add_child(volume_label)

	volume_slider = HSlider.new()
	volume_slider.name = "VolumeSlider"
	volume_slider.min_value = 0.0
	volume_slider.max_value = 100.0
	volume_slider.step = 1.0
	volume_slider.value = Settings.master_volume * 100.0
	volume_slider.value_changed.connect(_on_volume_changed)
	column.add_child(volume_slider)

	var fov_label := Label.new()
	fov_label.text = "Camera field of view"
	fov_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	column.add_child(fov_label)

	fov_slider = HSlider.new()
	fov_slider.name = "FovSlider"
	fov_slider.min_value = 50.0
	fov_slider.max_value = 90.0
	fov_slider.step = 1.0
	fov_slider.value = Settings.camera_fov
	fov_slider.value_changed.connect(_on_fov_changed)
	column.add_child(fov_slider)

	var height_label := Label.new()
	height_label.text = "Chase camera height"
	height_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	column.add_child(height_label)

	height_slider = HSlider.new()
	height_slider.name = "HeightSlider"
	height_slider.min_value = 0.6
	height_slider.max_value = 1.6
	height_slider.step = 0.05
	height_slider.value = Settings.camera_height
	height_slider.value_changed.connect(_on_height_changed)
	column.add_child(height_slider)

	var day_label := Label.new()
	day_label.text = "Day length"
	day_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	column.add_child(day_label)

	day_option = OptionButton.new()
	day_option.name = "DayOption"
	day_option.add_item("5 minutes", 5)
	day_option.add_item("15 minutes", 15)
	day_option.add_item("30 minutes", 30)
	day_option.add_item("60 minutes", 60)

	for i in day_option.item_count:
		if day_option.get_item_id(i) == Settings.day_minutes:
			day_option.select(i)

	day_option.item_selected.connect(_on_day_selected)
	column.add_child(day_option)

	var quality_label := Label.new()
	quality_label.text = "Graphics quality"
	quality_label.add_theme_color_override("font_color", Color(0.72, 0.76, 0.86))
	column.add_child(quality_label)

	quality_option = OptionButton.new()
	quality_option.name = "QualityOption"
	quality_option.add_item("Low", 0)
	quality_option.add_item("Medium", 1)
	quality_option.add_item("High", 2)
	quality_option.select(Settings.quality)
	quality_option.item_selected.connect(_on_quality_selected)
	column.add_child(quality_option)

	back_button = _make_button(column, "BackButton", "BACK")
	back_button.pressed.connect(_on_back_pressed)


func _make_panel(node_name: String, width: float) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.custom_minimum_size = Vector2(width, 0)
	panel.position = Vector2(-width * 0.5, -190)
	panel.visible = false
	panel.add_theme_stylebox_override("panel", _card_style())
	add_child(panel)
	return panel


func _panel_heading(column: VBoxContainer, text: String) -> void:
	var heading := Label.new()
	heading.text = text
	heading.add_theme_font_size_override("font_size", 26)
	heading.add_theme_color_override("font_color", Color(0.95, 0.68, 0.3))
	column.add_child(heading)


func _panel_text(column: VBoxContainer, text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.78, 0.81, 0.9))
	column.add_child(label)
	return label


func _build_help_panel() -> void:
	_help_panel = _make_panel("HelpPanel", 520)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_help_panel.add_child(column)

	_panel_heading(column, "HOW TO PLAY")
	_panel_text(column, "Pick up the load at the LOADING DEPOT in the city you start in, haul it down the highway — mind the toll plaza halfway — and stop gently inside the gate at the DELIVERY DEPOT. Hard hits wreck cargo; a wrecked load pays nothing.")
	_panel_text(column, "W / S — throttle & brake      A / D — steer\nSpace — handbrake      L — headlights\nC — camera (chase / close / cockpit)\nMouse — look around      Wheel — zoom\nF — cycle weather (rain / snow / fog)      R — recover truck\nEsc — pause\nLow on diesel? Park in the FUEL station bay halfway up the route — the pumps bill your wallet. Snow is slippery: brake early.")

	var back := _make_button(column, "HelpBackButton", "BACK")
	back.pressed.connect(_on_back_pressed)


func _build_career_panel() -> void:
	_career_panel = _make_panel("CareerPanel", 520)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	_career_panel.add_child(column)

	_panel_heading(column, "CAREER")

	var career := get_node_or_null("/root/Career")

	driver_name_edit = LineEdit.new()
	driver_name_edit.name = "DriverNameEdit"
	driver_name_edit.placeholder_text = "Driver name"
	driver_name_edit.text = String(career.get("driver_name")) if career != null else "Driver"
	driver_name_edit.text_submitted.connect(_on_driver_name_submitted)
	column.add_child(driver_name_edit)

	slot_option = OptionButton.new()
	slot_option.name = "SlotOption"
	slot_option.add_item("Save slot 1", 0)
	slot_option.add_item("Save slot 2", 1)
	slot_option.add_item("Save slot 3", 2)

	if career != null:
		slot_option.select(int(career.get("current_slot")))

	slot_option.item_selected.connect(_on_slot_selected)
	column.add_child(slot_option)

	career_stats_label = _panel_text(column, "")
	career_stats_label.name = "CareerStats"

	reset_career_button = _make_button(column, "ResetCareerButton", "RESET CAREER")
	reset_career_button.pressed.connect(_on_reset_career_pressed)

	var back := _make_button(column, "CareerBackButton", "BACK")
	back.pressed.connect(_on_back_pressed)

	_refresh_career_panel()


func _refresh_career_panel() -> void:
	var career := get_node_or_null("/root/Career")

	if career == null or career_stats_label == null:
		return

	driver_name_edit.text = String(career.get("driver_name"))

	var cash := int(career.get("cash"))
	var next := CareerMath.next_rank(cash)
	var next_line := "Top rank reached" if String(next.get("name", "")).is_empty() else "Next rank: %s — $%d to go" % [String(next.get("name", "")), int(next.get("remaining", 0))]

	career_stats_label.text = "Cash  $%d\nRank  %s\n%s\nDeliveries  %d      Best score  %d\nNext job  #%d · %s (%s) · %.1f km" % [
		cash,
		String(career.call("rank")),
		next_line,
		int(career.get("jobs_done")),
		int(career.get("best_score")),
		int(career.get("job_index")) + 1,
		String(career.call("current_cargo")),
		String(career.call("current_kind")),
		float(career.call("current_route_length")) / 1000.0,
	]

	var board: Array = career.get("leaderboard")

	if not board.is_empty():
		career_stats_label.text += "\n\n— BEST RUNS —"

		for i in mini(5, board.size()):
			var entry: Dictionary = board[i]
			career_stats_label.text += "\n%d.  %d pts · %s · %ds" % [i + 1, int(entry.get("score", 0)), String(entry.get("cargo", "")), int(entry.get("seconds", 0))]

	var unlocked: Array = career.get("unlocked_achievements")

	if not unlocked.is_empty():
		var names: Array = []

		for id in unlocked:
			names.append(CareerMath.achievement_name(String(id)))

		career_stats_label.text += "\n\n🏆 %s" % ", ".join(PackedStringArray(names))


func _show_only(panel: PanelContainer) -> void:
	_menu_box.visible = panel == null
	_settings_panel.visible = panel == _settings_panel
	_help_panel.visible = panel == _help_panel
	_career_panel.visible = panel == _career_panel


func _process(delta: float) -> void:
	_pulse += delta

	if _rule != null:
		_rule.color.a = 0.55 + 0.4 * (0.5 + 0.5 * sin(_pulse * 2.2))


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
	_show_only(_settings_panel)
	sensitivity_slider.grab_focus()


func _on_career_pressed() -> void:
	_refresh_career_panel()
	_show_only(_career_panel)


func _on_help_pressed() -> void:
	_show_only(_help_panel)


func _on_driver_name_submitted(value: String) -> void:
	var career := get_node_or_null("/root/Career")

	if career != null:
		career.call("set_driver_name", value)

	_refresh_career_panel()


func _on_slot_selected(index: int) -> void:
	var career := get_node_or_null("/root/Career")

	if career != null:
		career.call("switch_slot", slot_option.get_item_id(index))

	_refresh_career_panel()


func _on_reset_career_pressed() -> void:
	var career := get_node_or_null("/root/Career")

	if career != null:
		career.call("reset_progress")

	_refresh_career_panel()

	if _status_label != null:
		_status_label.text = "Job 1  ·  fresh start"


func _on_back_pressed() -> void:
	_show_only(null)
	settings_button.grab_focus()


func _on_quit_pressed() -> void:
	get_tree().quit()


func _on_sensitivity_changed(value: float) -> void:
	Settings.set_mouse_sensitivity(value)


func _on_invert_toggled(value: bool) -> void:
	Settings.set_invert_y(value)


func _on_fullscreen_toggled(value: bool) -> void:
	Settings.set_fullscreen(value)


func _on_volume_changed(value: float) -> void:
	Settings.set_master_volume(value / 100.0)


func _on_fov_changed(value: float) -> void:
	Settings.set_camera_fov(value)


func _on_height_changed(value: float) -> void:
	Settings.set_camera_height(value)


func _on_day_selected(index: int) -> void:
	Settings.set_day_minutes(day_option.get_item_id(index))


func _on_quality_selected(index: int) -> void:
	Settings.set_quality(quality_option.get_item_id(index))
