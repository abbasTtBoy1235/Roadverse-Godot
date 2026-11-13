extends Node
## Headless checks for the menus and the camera wiring. Runs as a scene so the
## autoloads (InputSetup, Settings) exist.
##
##   godot --headless --path . res://tests/ui_flow.tscn

var _checks := 0
var _failures := 0


func _ready() -> void:
	print("[ui] checking the menus")

	_check_menu()
	_check_settings_persistence()
	_check_game_scene()
	_check_camera_wiring()

	print("[ui] %d checks, %d failures" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _check_menu() -> void:
	var scene: PackedScene = load("res://scenes/menu.tscn")
	_check(scene != null, "menu scene loads")

	if scene == null:
		return

	var menu := scene.instantiate()
	add_child(menu)

	_check(menu.get_node_or_null("Title") != null, "menu has a title")
	_check(menu.find_child("PlayButton", true, false) != null, "menu has a PLAY button")
	_check(menu.find_child("CareerButton", true, false) != null, "menu has a CAREER button")
	_check(menu.find_child("HelpButton", true, false) != null, "menu has a HOW TO PLAY button")
	_check(menu.get_node_or_null("Footer") != null, "menu has a footer line")

	menu.call("_on_help_pressed")
	var help_panel := menu.get_node_or_null("HelpPanel")
	_check(help_panel != null and help_panel.visible, "the help panel opens")
	menu.call("_on_back_pressed")
	_check(help_panel != null and not help_panel.visible, "the help panel closes again")

	menu.call("_on_career_pressed")
	var career_panel := menu.get_node_or_null("CareerPanel")
	_check(career_panel != null and career_panel.visible, "the career panel opens")
	var stats := menu.find_child("CareerStats", true, false) as Label
	_check(stats != null and stats.text.contains("Rank"), "the career panel shows rank and cash")
	menu.call("_on_back_pressed")

	_check(menu.find_child("DriverNameEdit", true, false) != null, "the career panel has a driver name field")
	_check(menu.find_child("SlotOption", true, false) != null, "the career panel has save slots")

	var career := get_node_or_null("/root/Career")

	if career != null:
		career.call("set_driver_name", "Test Hauler")
		career.call("switch_slot", 2)
		career.call("reset_progress")
		career.set("cash", 500)
		career.call("save_progress")
		career.call("switch_slot", 1)
		_check(String(career.get("driver_name")) == "Test Hauler", "the driver profile name follows across slots")
		career.call("switch_slot", 2)
		_check(int(career.get("cash")) == 500, "slot 2 kept its own wallet ($%d)" % int(career.get("cash")))
		career.call("switch_slot", 0)

	_check(menu.find_child("Upgrade_engine", true, false) != null, "the workshop sells engine tunes")

	if career != null:
		career.call("switch_slot", 2)
		career.set("cash", 1000)
		_check(bool(career.call("buy_upgrade", "engine")), "cash buys the first engine level")
		_check(int(career.call("upgrade_level", "engine")) == 1, "the engine is now level 1")
		_check(int(career.get("cash")) == 200, "the tune was paid for ($%d left)" % int(career.get("cash")))
		_check(not bool(career.call("buy_upgrade", "engine")), "level 2 needs more cash than that")
		career.call("switch_slot", 0)

	_check(menu.find_child("VolumeSlider", true, false) != null, "settings has a volume slider")
	_check(menu.find_child("FovSlider", true, false) != null, "settings has a camera FOV slider")
	_check(menu.find_child("HeightSlider", true, false) != null, "settings has a camera height slider")
	_check(menu.find_child("DayOption", true, false) != null, "settings has a day-length choice")
	_check(menu.find_child("QualityOption", true, false) != null, "settings has a quality choice")
	_check(menu.find_child("SettingsButton", true, false) != null, "menu has a SETTINGS button")
	_check(menu.find_child("QuitButton", true, false) != null, "menu has a QUIT button")

	var panel := menu.get_node_or_null("SettingsPanel")
	_check(panel != null, "settings panel exists")
	if panel != null:
		_check(not panel.visible, "settings panel starts hidden")

	menu.call("_on_settings_pressed")
	if panel != null:
		_check(panel.visible, "settings panel opens")
	var menu_box := menu.get_node_or_null("MenuBox")
	if menu_box != null:
		_check(not menu_box.visible, "button list is hidden while in settings")

	menu.call("_on_back_pressed")
	if panel != null:
		_check(not panel.visible, "settings panel closes again")

	_check(ResourceLoader.exists("res://scenes/main.tscn"), "the PLAY target scene exists")

	menu.free()


func _check_settings_persistence() -> void:
	var original := Settings.mouse_sensitivity
	Settings.set_mouse_sensitivity(0.008)
	_check(is_equal_approx(Settings.mouse_sensitivity, 0.008), "sensitivity is stored")

	Settings.load_settings()
	_check(is_equal_approx(Settings.mouse_sensitivity, 0.008), "sensitivity survives a reload")

	Settings.set_mouse_sensitivity(1.5)
	_check(Settings.mouse_sensitivity <= 0.008, "sensitivity is clamped to the allowed range")

	# Regression: a save written on the old ~40x hotter scale (default was 0.12)
	# clamped to the new ceiling and the mouse still felt frantic. Old values
	# must be mapped across, not clamped.
	_check(Settings.migrated_sensitivity(0.12) < 0.004, "an old-scale save is migrated down (%.4f)" % Settings.migrated_sensitivity(0.12))
	_check(Settings.migrated_sensitivity(0.40) <= 0.008, "the hottest old save lands at the new ceiling")
	_check(is_equal_approx(Settings.migrated_sensitivity(0.005), 0.005), "new-scale saves pass through untouched")

	Settings.set_mouse_sensitivity(original)

	Settings.set_master_volume(0.35)
	Settings.set_camera_fov(80.0)
	Settings.set_day_minutes(30)
	Settings.load_settings()
	_check(is_equal_approx(Settings.master_volume, 0.35), "volume survives a reload")
	_check(is_equal_approx(Settings.camera_fov, 80.0), "camera FOV survives a reload")
	_check(Settings.day_minutes == 30, "day length survives a reload")
	_check(is_equal_approx(Settings.day_length_seconds(), 1800.0), "day length converts to seconds")
	Settings.set_master_volume(0.8)
	Settings.set_camera_fov(70.0)
	Settings.set_day_minutes(15)

	Settings.set_quality(0)
	_check(is_equal_approx(Settings.get_viewport().scaling_3d_scale, 0.75), "low quality renders at 75%% and upscales")
	Settings.set_quality(2)
	_check(is_equal_approx(Settings.get_viewport().scaling_3d_scale, 1.0), "high quality renders natively")


func _check_game_scene() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	_check(scene != null, "game scene loads")

	if scene == null:
		return

	var game := scene.instantiate()
	add_child(game)

	_check(game.get_node_or_null("Truck") != null, "game scene has a truck")
	_check(game.get_node_or_null("Road") != null, "game scene has a road")
	_check(game.get_node_or_null("ChaseCamera") != null, "game scene has a camera")
	_check(game.get_node_or_null("HUD") != null, "game scene has a HUD")

	var minimap := game.get_node_or_null("HUD/Minimap") as Minimap
	_check(minimap != null, "the HUD carries a minimap")

	if minimap != null:
		_check(minimap.has_road(), "the minimap mapped the route")
		_check(minimap.route_point_count() > 50, "the minimap route has detail (%d points)" % minimap.route_point_count())

		var truck := game.get_node_or_null("Truck") as Node3D

		if truck != null:
			var dot := minimap.project(truck.global_position)
			_check(dot.x >= 0.0 and dot.x <= Minimap.MAP_SIZE.x and dot.y >= 0.0 and dot.y <= Minimap.MAP_SIZE.y,
				"the truck marker lands on the map (%.0f, %.0f)" % [dot.x, dot.y])
	_check(game.get_node_or_null("TimeOfDay") != null, "game scene has a day/night driver")

	var tod := game.get_node_or_null("TimeOfDay")

	if tod != null:
		_check(bool(tod.get("sky_built")), "the procedural sky is installed")
		_check(float(tod.call("star_amount")) < 0.1, "no stars at the 07:00 start (%.2f)" % float(tod.call("star_amount")))

		Settings.set_quality(2)
		tod.call("_apply_quality")
		_check(bool(tod.call("ssao_on")), "high quality turns contact shadows (SSAO) on")
		_check(bool(tod.call("ssr_on")), "high quality turns wet-road reflections (SSR) on")
		Settings.set_quality(0)
		tod.call("_apply_quality")
		_check(not bool(tod.call("ssao_on")) and not bool(tod.call("ssr_on")), "low quality turns both off")
		Settings.set_quality(2)
		tod.call("_apply_quality")

	var pause_menu := game.get_node_or_null("PauseMenu")
	_check(pause_menu != null, "game scene has a pause menu")

	if pause_menu != null:
		_check(pause_menu.find_child("ResumeButton", true, false) != null, "pause menu has RESUME")
		_check(pause_menu.find_child("MenuButton", true, false) != null, "pause menu can return to the main menu")
		_check(not pause_menu.visible, "pause menu starts hidden")
		_check(pause_menu.process_mode == Node.PROCESS_MODE_ALWAYS, "pause menu keeps running while paused")

		pause_menu.call("set_paused", true)
		_check(get_tree().paused, "pausing stops the scene tree")
		_check(pause_menu.visible, "pause menu is visible while paused")

		pause_menu.call("set_paused", false)
		_check(not get_tree().paused, "resuming unpauses the scene tree")

	game.free()


func _check_camera_wiring() -> void:
	# Mouse look has to work with a plain mouse movement, no button held.
	var free_camera := ChaseCamera.new()
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(70.0, 0.0)
	free_camera.handle_input_event(motion)
	_check(free_camera.orbit.is_offset(), "plain mouse movement rotates the camera")
	_check(absf(free_camera.orbit.yaw) > 0.0, "a horizontal drag produces yaw")

	var zoom_event := InputEventMouseButton.new()
	zoom_event.button_index = MOUSE_BUTTON_WHEEL_UP
	zoom_event.pressed = true
	var zoom_before := free_camera.orbit.zoom
	free_camera.handle_input_event(zoom_event)
	_check(free_camera.orbit.zoom < zoom_before, "the wheel zooms in")
	free_camera.free()

	var orbit := CameraOrbit.new()
	orbit.apply_mouse(Vector2(80.0, 0.0), Settings.mouse_sensitivity)
	_check(orbit.is_offset(), "the camera orbit responds to mouse input")
	_check(absf(orbit.yaw) > 0.0, "mouse input produces yaw")

	var camera := ChaseCamera.new()
	_check(camera.orbit != null, "the chase camera owns an orbit state")
	camera.free()

	var hud_script: GDScript = load("res://scripts/ui/hud.gd")
	_check(int(hud_script.speed_limit_for(0.2)) == 90, "open road limit is 90")
	_check(int(hud_script.speed_limit_for(0.85)) == 50, "the city limit is 50")
	_check(int(hud_script.speed_limit_for(0.64)) == 30, "the roadworks limit is 30")

	# The gamepad is bound too: buttons for the switches, axes for the pedals.
	InputSetup.ensure_registered()

	var pad_buttons := 0
	var pad_axes := 0

	for action in InputMap.get_actions():
		for event in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				pad_buttons += 1
			elif event is InputEventJoypadMotion:
				pad_axes += 1

	_check(pad_buttons >= 8, "the gamepad buttons are bound (%d)" % pad_buttons)
	_check(pad_axes >= 4, "the stick and triggers are bound (%d axes)" % pad_axes)
	_check(Input.get_action_strength("rv_throttle") >= 0.0, "the throttle action reads on every device")
