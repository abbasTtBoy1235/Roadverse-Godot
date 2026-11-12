extends Node
## User settings persisted to user://settings.cfg. Autoloaded as "Settings".

const CONFIG_PATH := "user://settings.cfg"

var mouse_sensitivity := 0.12
var invert_y := false
var fullscreen := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	mouse_sensitivity = clampf(config.get_value("camera", "mouse_sensitivity", mouse_sensitivity), 0.02, 0.40)
	invert_y = bool(config.get_value("camera", "invert_y", invert_y))
	fullscreen = bool(config.get_value("video", "fullscreen", fullscreen))


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("camera", "invert_y", invert_y)
	config.set_value("video", "fullscreen", fullscreen)
	config.save(CONFIG_PATH)


func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)


## Changing a setting from the UI should persist immediately.
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.02, 0.40)
	save_settings()


func set_invert_y(value: bool) -> void:
	invert_y = value
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	save_settings()
