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
	Settings.set_mouse_sensitivity(0.27)
	_check(is_equal_approx(Settings.mouse_sensitivity, 0.27), "sensitivity is stored")

	Settings.load_settings()
	_check(is_equal_approx(Settings.mouse_sensitivity, 0.27), "sensitivity survives a reload")

	Settings.set_mouse_sensitivity(1.5)
	_check(Settings.mouse_sensitivity <= 0.40, "sensitivity is clamped to the allowed range")

	Settings.set_mouse_sensitivity(original)


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
	_check(game.get_node_or_null("TimeOfDay") != null, "game scene has a day/night driver")

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
