class_name AmbientAudio
extends Node
## The world breathing around the truck: a low city hum near the two
## cities (distant traffic, plant rooms, life) and a weather layer —
## rain hiss, soft snow hush, fog stillness. Synthesised like the engine
## and tyre noise: filtered white noise, gain following place and sky.

@export var truck_path: NodePath
@export var road_path: NodePath
@export var weather_path: NodePath
@export_range(4000, 48000) var sample_rate := 22050

var _truck: Node3D
var _road: Node3D
var _weather: Node3D

var _city_player: AudioStreamPlayer
var _weather_player: AudioStreamPlayer
var _city_playback: AudioStreamGeneratorPlayback
var _weather_playback: AudioStreamGeneratorPlayback

var _city_state := 0.0
var _weather_state := 0.0
var _city_energy := 0.0
var _weather_energy := 0.0
var _rng := RandomNumberGenerator.new()


## How loud the city is at a route fraction: full inside either city
## (loading city to 24%, delivery city from 64%), fading through suburbs.
static func city_gain_for(progress: float) -> float:
	var origin := 1.0 - smoothstep(0.20, 0.32, progress)
	var destination := smoothstep(0.56, 0.68, progress)
	return clampf(maxf(origin, destination), 0.0, 1.0)


## The weather layer's target level for each front.
static func weather_gain_for(mode_value: int, wetness: float) -> float:
	match mode_value:
		Weather.Mode.RAIN:
			return lerpf(0.35, 1.0, clampf(wetness, 0.0, 1.0))
		Weather.Mode.SNOW:
			return 0.22
		Weather.Mode.FOG:
			return 0.10

	return 0.0


func _ready() -> void:
	_truck = get_node_or_null(truck_path) as Node3D
	_road = get_node_or_null(road_path) as Node3D
	_weather = get_node_or_null(weather_path) as Node3D
	_rng.seed = 41507

	_city_player = _make_player("CityHum", -20.0)
	_weather_player = _make_player("WeatherNoise", -18.0)
	_city_playback = _city_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_weather_playback = _weather_player.get_stream_playback() as AudioStreamGeneratorPlayback


func _make_player(node_name: String, volume_db: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = node_name
	player.volume_db = volume_db

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = float(sample_rate)
	generator.buffer_length = 0.2
	player.stream = generator

	add_child(player)
	player.play()
	return player


func _process(delta: float) -> void:
	if _truck == null or _road == null:
		return

	# Where along the route are we? The cities hum, the country doesn't.
	var progress := 0.0

	if _road.has_method("nearest_distance") and _road.get("curve") != null:
		var length := float(_road.get("curve").get_baked_length())

		if length > 0.0:
			progress = clampf(float(_road.call("nearest_distance", _truck.global_position)) / length, 0.0, 1.0)

	_city_state = move_toward(_city_state, city_gain_for(progress), delta * 1.5)

	var mode_value := 0
	var wet := 0.0

	if _weather != null:
		mode_value = int(_weather.get("mode"))

		if _weather.has_method("wetness"):
			wet = float(_weather.call("wetness"))

	_weather_state = move_toward(_weather_state, weather_gain_for(mode_value, wet), delta * 2.0)

	_fill_city()
	_fill_weather()


## City hum: deep one-pole rumble, barely music, mostly chest.
func _fill_city() -> void:
	if _city_playback == null:
		return

	var frames := _city_playback.get_frames_available()

	for i in frames:
		var white := _rng.randf_range(-1.0, 1.0)
		_city_energy += (white - _city_energy) * 0.03
		var sample := clampf(_city_energy * 3.2 * _city_state * 0.5, -1.0, 1.0)
		_city_playback.push_frame(Vector2(sample, sample))


## Rain is a bright hiss; snow and fog are the same noise, smothered.
func _fill_weather() -> void:
	if _weather_playback == null:
		return

	var frames := _weather_playback.get_frames_available()
	var snowy := _weather != null and int(_weather.get("mode")) == Weather.Mode.SNOW

	for i in frames:
		var white := _rng.randf_range(-1.0, 1.0)
		_weather_energy += (white - _weather_energy) * (0.06 if snowy else 0.7)
		var shaped := _weather_energy * 2.4 if snowy else white - _weather_energy * 0.4
		var sample := clampf(shaped * _weather_state * 0.32, -1.0, 1.0)
		_weather_playback.push_frame(Vector2(sample, sample))


## Test hooks.
func city_level() -> float:
	return _city_state


func weather_level() -> float:
	return _weather_state


func is_playing() -> bool:
	return _city_player != null and _city_player.playing
