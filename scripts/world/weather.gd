class_name Weather
extends Node3D
## Rain. Particles fall around the truck, the tarmac goes wet and glossy, and the
## fog thickens. Toggled with F, so the same build has both a clear and a rainy
## night.
##
## Everything is generated in code — no textures, no particle resources.

@export var road_path: NodePath
@export var truck_path: NodePath
@export var raining := false
@export var particle_count := 1200
@export var wet_target := 1.0
@export var dry_fog_density := 0.008
@export var wet_fog_density := 0.022
@export var rain_radius := 42.0
@export var rain_height := 14.0

var _road: Node3D
var _truck: Node3D
var _rain: CPUParticles3D
var _wetness := 0.0


## Fog thickness for a given rain state.
static func fog_density(raining_now: bool, dry: float, wet: float) -> float:
	return wet if raining_now else dry


## How wet the road should be, 0..1.
static func target_wetness(raining_now: bool, soak: float) -> float:
	return clampf(soak, 0.0, 1.0) if raining_now else 0.0


func _ready() -> void:
	_road = get_node_or_null(road_path) as Node3D
	_truck = get_node_or_null(truck_path) as Node3D

	_build_rain()
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


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("rv_weather"):
		set_raining(not raining)

	# Follow the player so rain is never "somewhere else".
	if _rain != null and _truck != null:
		_rain.global_position = _truck.global_position + Vector3(0.0, rain_height, 0.0)

	# Soak in gradually instead of snapping.
	var target := target_wetness(raining, wet_target)
	_wetness = move_toward(_wetness, target, delta * 0.8)

	if _road != null and _road.has_method("set_wetness"):
		_road.call("set_wetness", _wetness)


func set_raining(value: bool, immediate := false) -> void:
	raining = value

	if _rain != null:
		_rain.emitting = value

	if immediate:
		_wetness = target_wetness(value, wet_target)

	_apply_fog()


func _apply_fog() -> void:
	var environment := get_viewport().world_3d.environment if get_viewport() != null and get_viewport().world_3d != null else null

	if environment == null:
		return

	environment.fog_density = fog_density(raining, dry_fog_density, wet_fog_density)


func toggle() -> void:
	set_raining(not raining)


## Test hook: current soak level.
func wetness() -> float:
	return _wetness


## Test hook: is the particle system actually emitting?
func is_emitting() -> bool:
	return _rain != null and _rain.emitting
