extends Node
## User settings persisted to user://settings.cfg. Autoloaded as "Settings".

const CONFIG_PATH := "user://settings.cfg"

## Radians of camera yaw per pixel of mouse travel. 0.003 turns ~17 degrees
## for a 100 px sweep. The original scale (default 0.12) did that in 2 px.
var mouse_sensitivity := 0.003
var invert_y := false
var fullscreen := false


func _ready() -> void:
	load_settings()
	apply()


func load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(CONFIG_PATH) != OK:
		return

	# Saves written on the old, ~40x hotter scale (anything above the new
	# ceiling) are mapped across proportionally instead of clamped to max,
	# which is what left the mouse feeling frantic even after the rescale.
	mouse_sensitivity = migrated_sensitivity(float(config.get_value("camera", "mouse_sensitivity", mouse_sensitivity)))
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


## Maps a stored sensitivity onto the current scale. Values above the new
## ceiling can only have come from the old scale (0.02..0.40).
static func migrated_sensitivity(stored: float) -> float:
	if stored > 0.008:
		var fraction := clampf((stored - 0.02) / 0.38, 0.0, 1.0)
		return lerpf(0.0008, 0.008, fraction)

	return clampf(stored, 0.0008, 0.008)


## Changing a setting from the UI should persist immediately.
func set_mouse_sensitivity(value: float) -> void:
	mouse_sensitivity = clampf(value, 0.0008, 0.008)
	save_settings()


func set_invert_y(value: bool) -> void:
	invert_y = value
	save_settings()


func set_fullscreen(value: bool) -> void:
	fullscreen = value
	apply()
	save_settings()
