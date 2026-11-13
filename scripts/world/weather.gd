class_name Weather
extends Node3D
## Weather fronts: clear, rain, fog and snow. Particles fall around the
## truck, the tarmac goes wet and glossy, the fog thickens — and the tyres
## lose grip, most of all on snow. Cycled with F.
##
## Everything is generated in code — no textures, no particle resources.

enum Mode { CLEAR, RAIN, FOG, SNOW }

@export var road_path: NodePath
@export var truck_path: NodePath
@export var raining := false
@export var particle_count := 1200
@export var wet_target := 1.0
@export var dry_fog_density := 0.008
@export var wet_fog_density := 0.022
@export var rain_radius := 42.0
@export var rain_height := 14.0

var mode: Mode = Mode.CLEAR

var _road: Node3D
var _truck: Node3D
var _rain: CPUParticles3D
var _snow: CPUParticles3D
var _wetness := 0.0


## Fog thickness for a given rain state.
static func fog_density(raining_now: bool, dry: float, wet: float) -> float:
	return wet if raining_now else dry


## How wet the road should be, 0..1.
static func target_wetness(raining_now: bool, soak: float) -> float:
	return clampf(soak, 0.0, 1.0) if raining_now else 0.0


## How soaked the ground gets under each front.
static func target_wetness_for(mode_value: int) -> float:
	match mode_value:
		Mode.RAIN:
			return 1.0
		Mode.SNOW:
			return 0.55
		Mode.FOG:
			return 0.25

	return 0.0


## Fog thickness per front.
static func fog_for_mode(mode_value: int, dry: float, wet: float) -> float:
	match mode_value:
		Mode.RAIN:
			return wet
		Mode.FOG:
			return 0.045
		Mode.SNOW:
			return 0.02

	return dry


## Tyre grip multiplier: snow is properly slippery, rain merely greasy.
static func grip_for(mode_value: int, wet: float) -> float:
	match mode_value:
		Mode.RAIN:
			return lerpf(1.0, 0.75, clampf(wet, 0.0, 1.0))
		Mode.SNOW:
			return 0.55
		Mode.FOG:
			return 0.95

	return lerpf(1.0, 0.92, clampf(wet, 0.0, 1.0))


func _ready() -> void:
	add_to_group("rv_weather")
	_road = get_node_or_null(road_path) as Node3D
	_truck = get_node_or_null(truck_path) as Node3D

	_build_rain()
	_build_snow()
	set_raining(raining, true)


func _build_rain() -> void:
	_rain = CPUParticles3D.new()
	_rain.name = "Rain"
	_rain.amount = particle_count
	_rain.lifetime = 1.3
	_rain.preprocess = 0.6
	_rain.emitting = false

	_rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_rain.emission_box_extents = Vector3(rain_radius, 2.0, rain_radius)
	_rain.direction = Vector3(0.06, -1.0, 0.12)
	_rain.spread = 2.0
	_rain.gravity = Vector3(0.0, -26.0, 0.0)
	_rain.initial_velocity_min = 16.0
	_rain.initial_velocity_max = 24.0
	_rain.scale_amount_min = 0.7
	_rain.scale_amount_max = 1.4

	# A streak, not a dot: thin and tall with a slight lean.
	var drop := BoxMesh.new()
	drop.size = Vector3(0.015, 0.55, 0.015)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.72, 0.78, 0.92, 0.5)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y

	drop.material = material
	_rain.mesh = drop

	add_child(_rain)


func _build_snow() -> void:
	_snow = CPUParticles3D.new()
	_snow.name = "Snow"
	_snow.amount = 900
	_snow.lifetime = 3.2
	_snow.preprocess = 1.2
	_snow.emitting = false

	_snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_snow.emission_box_extents = Vector3(rain_radius, 2.0, rain_radius)
	_snow.direction = Vector3(0.1, -1.0, 0.05)
	_snow.spread = 14.0
	_snow.gravity = Vector3(0.0, -3.2, 0.0)
	_snow.initial_velocity_min = 1.2
	_snow.initial_velocity_max = 2.6
	_snow.scale_amount_min = 0.8
	_snow.scale_amount_max = 1.8

	var flake := BoxMesh.new()
	flake.size = Vector3(0.05, 0.05, 0.05)

	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.92, 0.94, 1.0, 0.85)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED

	flake.material = material
	_snow.mesh = flake

	add_child(_snow)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("rv_weather"):
		cycle_mode()

	# Follow the player so the weather is never "somewhere else".
	if _truck != null:
		if _rain != null:
			_rain.global_position = _truck.global_position + Vector3(0.0, rain_height, 0.0)

		if _snow != null:
			_snow.global_position = _truck.global_position + Vector3(0.0, rain_height, 0.0)

	# Soak in gradually instead of snapping.
	var target := target_wetness_for(mode)
	_wetness = move_toward(_wetness, target, delta * 0.8)

	if _road != null and _road.has_method("set_wetness"):
		_road.call("set_wetness", _wetness)


func set_raining(value: bool, immediate := false) -> void:
	set_mode(Mode.RAIN if value else Mode.CLEAR)

	if immediate:
		_wetness = target_wetness_for(mode)


## Switch fronts. Keeps the legacy `raining` flag in step.
func set_mode(value: Mode) -> void:
	mode = value
	raining = mode == Mode.RAIN

	if _rain != null:
		_rain.emitting = mode == Mode.RAIN

	if _snow != null:
		_snow.emitting = mode == Mode.SNOW

	_apply_fog()


## F key: clear -> rain -> snow -> fog -> clear...
func cycle_mode() -> void:
	set_mode(((int(mode) + 1) % Mode.size()) as Mode)


## Grip the truck should be feeling right now, 0..1.
func grip_factor() -> float:
	return grip_for(mode, _wetness)


func _apply_fog() -> void:
	var environment := get_viewport().world_3d.environment if get_viewport() != null and get_viewport().world_3d != null else null

	if environment == null:
		return

	environment.fog_density = fog_for_mode(mode, dry_fog_density, wet_fog_density)


func toggle() -> void:
	set_raining(not raining)


## Test hook: current soak level.
func wetness() -> float:
	return _wetness


## Test hook: is the particle system actually emitting?
func is_emitting() -> bool:
	return _rain != null and _rain.emitting
