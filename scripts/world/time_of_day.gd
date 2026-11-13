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

## True once the procedural sky is installed. Test hook.
var sky_built := false

var _sun: DirectionalLight3D
var _moon: DirectionalLight3D
var _environment: Environment
var _sky_material: ShaderMaterial
var _star_amount := 0.0


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

	if _sun != null:
		_sun.directional_shadow_max_distance = 280.0

	_build_sky()
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

	if _environment != null and _sky_material != null:
		_sky_material.set_shader_parameter("top_color", DayCycle.sky_top_color(hour))
		_sky_material.set_shader_parameter("horizon_color", DayCycle.sky_horizon_color(hour))
		_sky_material.set_shader_parameter("ground_color", DayCycle.sky_ground_color(hour))
		_sky_material.set_shader_parameter("star_amount", DayCycle.night_factor(hour))
		_star_amount = DayCycle.night_factor(hour)

		if _sun != null:
			_sky_material.set_shader_parameter("sun_direction", _sun.global_basis.z.normalized())

		if _moon != null:
			_sky_material.set_shader_parameter("moon_direction", _moon.global_basis.z.normalized())

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


## Installs the procedural sky and makes the ambient/reflection light come
## from it, so dawn colours bounce onto the world instead of a flat tint.
func _build_sky() -> void:
	if _environment == null:
		return

	var shader := load("res://scripts/world/sky.gdshader") as Shader

	if shader == null:
		return

	_sky_material = ShaderMaterial.new()
	_sky_material.shader = shader

	var sky := Sky.new()
	sky.sky_material = _sky_material
	_environment.sky = sky
	_environment.background_mode = Environment.BG_SKY
	_environment.ambient_light_source = Environment.AMBIENT_SOURCE_BG
	_environment.reflected_light_source = Environment.REFLECTION_SOURCE_BG

	# Volumetric fog is what lets headlights and lamps carve visible cones
	# out of the night. Only worth its cost above the low quality tier.
	_environment.volumetric_fog_enabled = Settings.quality >= 1
	_environment.volumetric_fog_density = 0.012
	_environment.volumetric_fog_sky_affect = 0.25

	sky_built = true


## Test hook: how starry the sky is right now (0 by day, 1 at night).
func star_amount() -> float:
	return _star_amount


## 0..24, for the HUD.
func current_hour() -> float:
	return hour
