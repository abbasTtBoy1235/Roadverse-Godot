class_name EngineAudio
extends AudioStreamPlayer
## Procedural diesel engine sound, synthesised at runtime — no audio files.
##
## A four-stroke diesel fires cylinders/2 times per revolution, so the firing
## frequency is rpm / 120 * cylinders. Harmonics on top of that give it the
## lumpy low-frequency character a pure sine lacks.

@export_range(2, 16) var cylinders := 6
@export_range(4000, 48000) var sample_rate := 22050
@export var master_gain := 0.22
@export var idle_gain := 0.35
@export var truck_path: NodePath

var _playback: AudioStreamGeneratorPlayback
var _phase := 0.0
var _truck: TruckController


## Firing frequency in Hz for a given engine speed.
static func engine_frequency(rpm: float, cylinder_count: int) -> float:
	var safe_rpm := maxf(0.0, rpm)
	return maxf(12.0, safe_rpm / 120.0 * float(cylinder_count))


## Overall loudness from engine speed and load, both 0..1.
static func loudness(rpm_ratio: float, load: float) -> float:
	var rev := clampf(rpm_ratio, 0.0, 1.0)
	return clampf(0.55 + rev * 0.45 + clampf(load, 0.0, 1.0) * 0.25, 0.0, 1.4)


func _ready() -> void:
	_truck = get_node_or_null(truck_path) as TruckController

	var generator := AudioStreamGenerator.new()
	generator.mix_rate = float(sample_rate)
	generator.buffer_length = 0.15
	stream = generator

	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


func _process(_delta: float) -> void:
	if _playback == null or _truck == null:
		return

	var frames := _playback.get_frames_available()
	if frames <= 0:
		return

	var rpm := _truck.engine_rpm
	var max_rpm := maxf(1.0, _truck.max_rpm)
	var rpm_ratio := rpm / max_rpm

	var frequency := engine_frequency(rpm, cylinders)
	var increment := frequency / float(sample_rate)

	var gain := master_gain * idle_gain * loudness(rpm_ratio, _truck.engine_load)

	for i in frames:
		_phase = fmod(_phase + increment, 1.0)
		var angle := _phase * TAU

		# Fundamental plus two harmonics: reads as a diesel rumble.
		var sample := sin(angle) \
			+ 0.42 * sin(angle * 2.0) \
			+ 0.18 * sin(angle * 3.0) \
			+ 0.08 * sin(angle * 4.0)

		sample = clampf(sample * 0.55, -1.0, 1.0) * gain
		_playback.push_frame(Vector2(sample, sample))


## Test hook: the frequency the synth is currently running at.
func current_frequency() -> float:
	return engine_frequency(_truck.engine_rpm if _truck != null else 0.0, cylinders)
