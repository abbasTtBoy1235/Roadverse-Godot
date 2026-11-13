extends Node
## User settings persisted to user://settings.cfg. Autoloaded as "Settings".

const CONFIG_PATH := "user://settings.cfg"

## Radians of camera yaw per pixel of mouse travel. 0.003 turns ~17 degrees
## for a 100 px sweep. The original scale (default 0.12) did that in 2 px.
var mouse_sensitivity := 0.003
var invert_y := false
var fullscreen := false
## 0..1, applied to the Master bus.
var master_volume := 0.8
var camera_fov := 70.0
## Multiplier on the chase camera's height.
var camera_height := 1.0
## Minutes of real time per in-game day.
var day_minutes := 15
## 0 = low, 1 = medium, 2 = high.
var quality := 2


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
	master_volume = clampf(float(config.get_value("audio", "master_volume", master_volume)), 0.0, 1.0)
	camera_fov = clampf(float(config.get_value("camera", "fov", camera_fov)), 50.0, 90.0)
	camera_height = clampf(float(config.get_value("camera", "height_scale", camera_height)), 0.6, 1.6)
	day_minutes = clampi(int(config.get_value("world", "day_minutes", day_minutes)), 1, 120)
	quality = clampi(int(config.get_value("video", "quality", quality)), 0, 2)


func save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("camera", "mouse_sensitivity", mouse_sensitivity)
	config.set_value("camera", "invert_y", invert_y)
	config.set_value("video", "fullscreen", fullscreen)
	config.set_value("audio", "master_volume", master_volume)
	config.set_value("camera", "fov", camera_fov)
	config.set_value("camera", "height_scale", camera_height)
	config.set_value("world", "day_minutes", day_minutes)
	config.set_value("video", "quality", quality)
	config.save(CONFIG_PATH)


func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))

	if DisplayServer.get_name() == "headless":
		return

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	)

	var viewport := get_viewport()

	if viewport != null:
		viewport.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][quality] as Viewport.MSAA


func day_length_seconds() -> float:
	return float(day_minutes) * 60.0


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


func set_master_volume(value: float) -> void:
	master_volume = clampf(value, 0.0, 1.0)
	apply()
	save_settings()


func set_camera_fov(value: float) -> void:
	camera_fov = clampf(value, 50.0, 90.0)
	save_settings()


func set_camera_height(value: float) -> void:
	camera_height = clampf(value, 0.6, 1.6)
	save_settings()


func set_day_minutes(value: int) -> void:
	day_minutes = clampi(value, 1, 120)
	save_settings()


func set_quality(value: int) -> void:
	quality = clampi(value, 0, 2)
	apply()
	save_settings()
