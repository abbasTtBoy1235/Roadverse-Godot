class_name RoadNoise
extends Node
## Tyre roar and wind, synthesised like the engine: filtered white noise whose
## gain follows road speed. Two players, one low-passed rumble and one bright hiss.

@export var truck_path: NodePath
@export_range(4000, 48000) var sample_rate := 22050
@export var tyre_gain_max := 0.16
@export var wind_gain_max := 0.10
@export var fade_speed := 2.5

var _truck: TruckController
var _tyre_player: AudioStreamPlayer
var _wind_player: AudioStreamPlayer
var _tyre_playback: AudioStreamGeneratorPlayback
var _wind_playback: AudioStreamGeneratorPlayback

var _tyre_state := 0.0
var _wind_state := 0.0
var _tyre_energy := 0.0
var _wind_energy := 0.0
var _rng := RandomNumberGenerator.new()


## Rolling resistance rises quickly then saturates: loud at walking pace already.
static func tyre_gain(speed_kph: float) -> float:
	return clampf(pow(clampf(speed_kph / 95.0, 0.0, 1.0), 0.55), 0.0, 1.0)


## Wind is quadratic: inaudible at town speed, obvious on the motorway.
static func wind_gain(speed_kph: float) -> float:
	var ratio := clampf(speed_kph / 130.0, 0.0, 1.0)
	return clampf(ratio * ratio, 0.0, 1.0)


func _ready() -> void:
	_truck = get_node_or_null(truck_path) as TruckController
	_rng.seed = 90210

	_tyre_player = _make_player("TyreNoise", -10.0)
	_wind_player = _make_player("WindNoise", -14.0)

	_tyre_playback = _tyre_player.get_stream_playback() as AudioStreamGeneratorPlayback
	_wind_playback = _wind_player.get_stream_playback() as AudioStreamGeneratorPlayback


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
	if _truck == null:
		return

	var speed := _truck.speed_kph()

	_tyre_state = move_toward(_tyre_state, tyre_gain(speed), delta * fade_speed)
	_wind_state = move_toward(_wind_state, wind_gain(speed), delta * fade_speed)

	_fill(_tyre_playback, _tyre_state * tyre_gain_max, 0.06, true)
	_fill(_wind_playback, _wind_state * wind_gain_max, 0.55, false)


## White noise through a one-pole low pass: 0.06 sounds like tyres, 0.55 like wind.
func _fill(playback: AudioStreamGeneratorPlayback, gain: float, cutoff: float, low: bool) -> void:
	if playback == null:
		return

	var frames := playback.get_frames_available()
	if frames <= 0:
		return

	for i in frames:
		var white := _rng.randf_range(-1.0, 1.0)

		if low:
			_tyre_energy += (white - _tyre_energy) * cutoff
			white = _tyre_energy * 3.0
		else:
			_wind_energy += (white - _wind_energy) * cutoff
			white = white - _wind_energy

		var sample := clampf(white * gain, -1.0, 1.0)
		playback.push_frame(Vector2(sample, sample))


## Test hook: smoothed tyre level the synth is using, 0..1 of full gain.
func tyre_level() -> float:
	return _tyre_state


## Test hook: smoothed wind level.
func wind_level() -> float:
	return _wind_state
