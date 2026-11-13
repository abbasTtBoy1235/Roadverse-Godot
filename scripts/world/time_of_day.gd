class_name TimeOfDay
extends Node
## Drives the sun, moon, ambient light and fog from DayCycle.
## Set `enabled = false` for a permanently frozen night.

@export var enabled := true
@export_range(0.0, 24.0, 0.1) var start_hour := 7.0
## Real seconds for a full 24 h cycle. 900 = 15 minutes per in-game day.
@export var day_length_seconds := 900.0

@export_group("References")
@export var sun_path: NodePath = NodePath("../Sun")
@export var moon_path: NodePath = NodePath("../Moon")
@export var world_environment_path: NodePath = NodePath("../WorldEnvironment")

var hour := 0.0

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _environment: Environment


func _ready() -> void:
	day_length_seconds = Settings.day_length_seconds()
	hour = fposmod(start_hour, 24.0)

	_sun = get_node_or_null(sun_path) as DirectionalLight3D
	_moon = get_node_or_null(moon_path) as DirectionalLight3D

	var world_environment := get_node_or_null(world_environment_path) as WorldEnvironment
	if world_environment != null:
		_environment = world_environment.environment

	if _sun == null:
		push_warning("TimeOfDay: sun_path is not set, the sun will not move.")

	_apply()


func _process(delta: float) -> void:
	if not enabled:
		return

	if day_length_seconds <= 0.0:
		return

	hour = fposmod(hour + delta * 24.0 / day_length_seconds, 24.0)
	_apply()


func _apply() -> void:
	if _sun != null:
		_sun.rotation_degrees = Vector3(DayCycle.sun_pitch_degrees(hour), 35.0, 0.0)
		_sun.light_energy = DayCycle.sun_energy(hour)
		_sun.visible = DayCycle.sun_energy(hour) > 0.01

	if _moon != null:
		_moon.light_energy = DayCycle.moon_energy(hour)
		_moon.visible = DayCycle.moon_energy(hour) > 0.01

	if _moon != null:
		_moon.rotation_degrees = Vector3(DayCycle.sun_pitch_degrees(hour) + 180.0, 35.0, 0.0)

	if _environment != null:
		_environment.background_color = DayCycle.sky_color(hour)
		_environment.ambient_light_energy = DayCycle.ambient_energy(hour)
		_environment.ambient_light_color = DayCycle.ambient_color(hour)
		_environment.fog_light_color = DayCycle.fog_color(hour)
		_environment.fog_density = DayCycle.fog_density(hour)
		_environment.glow_intensity = DayCycle.glow_intensity(hour)

	# Street lamps, city windows, beacons and NPC headlights all follow the
	# same dimmer, so dawn actually looks like dawn everywhere at once.
	var night := DayCycle.night_factor(hour)

	for node in get_tree().get_nodes_in_group("rv_time_aware"):
		if node.has_method("apply_time_of_day"):
			node.call("apply_time_of_day", night)


## 0..24, for the HUD.
func current_hour() -> float:
	return hour
