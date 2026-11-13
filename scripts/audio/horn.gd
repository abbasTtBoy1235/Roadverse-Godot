class_name Horn
extends AudioStreamPlayer
## The truck horn: two detuned tones through the same kind of generator
## the engine uses. Hold H (or click the pad's left stick).

@export_range(4000, 48000) var sample_rate := 22050

var _playback: AudioStreamGeneratorPlayback
var _phase_a := 0.0
var _phase_b := 0.0
var _held_by_code := false
var _sounding := false


func _ready() -> void:
	var generator := AudioStreamGenerator.new()
	generator.mix_rate = float(sample_rate)
	generator.buffer_length = 0.15
	stream = generator
	volume_db = -14.0
	play()
	_playback = get_stream_playback() as AudioStreamGeneratorPlayback


## Sound the horn from code (tests): stays on until released.
func hold(value: bool) -> void:
	_held_by_code = value


func is_sounding() -> bool:
	return _sounding


func _process(_delta: float) -> void:
	_sounding = Input.is_action_pressed("rv_horn") or _held_by_code

	if _playback == null:
		return

	var frames := _playback.get_frames_available()

	for i in frames:
		var sample := 0.0

		if _sounding:
			_phase_a = wrapf(_phase_a + 370.0 / float(sample_rate), 0.0, 1.0)
			_phase_b = wrapf(_phase_b + 466.0 / float(sample_rate), 0.0, 1.0)
			sample = sign(sin(_phase_a * TAU)) * 0.10 + sin(_phase_b * TAU) * 0.14

		_playback.push_frame(Vector2(sample, sample))
