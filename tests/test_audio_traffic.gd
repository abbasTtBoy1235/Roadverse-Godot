extends SceneTree
## Headless tests for the pure audio and traffic maths.
##
##   godot --headless --path . --script res://tests/test_audio_traffic.gd

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[audio/traffic] running tests")

	_test_firing_frequency_scales_with_rpm()
	_test_firing_frequency_floor()
	_test_loudness_curve()
	_test_distance_wraps()
	_test_zero_length_is_safe()
	_test_signals()
	_test_car_following()

	print("[audio/traffic] %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _test_firing_frequency_scales_with_rpm() -> void:
	# Six cylinders, four strokes: rpm / 120 * cylinders.
	_check(is_equal_approx(EngineAudio.engine_frequency(1200.0, 6), 60.0),
		"1200 rpm on six cylinders is 60 Hz")
	_check(is_equal_approx(EngineAudio.engine_frequency(2400.0, 6), 120.0),
		"2400 rpm is twice that")

	var low := EngineAudio.engine_frequency(800.0, 6)
	var high := EngineAudio.engine_frequency(2000.0, 6)
	_check(high > low, "frequency rises with rpm (%.0f -> %.0f)" % [low, high])


func _test_firing_frequency_floor() -> void:
	_check(EngineAudio.engine_frequency(0.0, 6) >= 12.0, "a stopped engine still has a minimum pitch")
	_check(is_finite(EngineAudio.engine_frequency(0.0, 6)), "frequency is finite at zero rpm")


func _test_loudness_curve() -> void:
	var idle := EngineAudio.loudness(0.25, 0.0)
	var revved := EngineAudio.loudness(0.9, 1.0)
	_check(revved > idle, "load and revs raise the volume (%.2f -> %.2f)" % [idle, revved])
	_check(EngineAudio.loudness(2.0, 5.0) <= 1.4, "loudness is clamped")
	_check(EngineAudio.loudness(0.0, 0.0) > 0.0, "the engine is audible at idle")


func _test_distance_wraps() -> void:
	_check(is_equal_approx(Traffic.wrap_distance(250.0, 200.0), 50.0), "distance wraps past the end")
	_check(is_equal_approx(Traffic.wrap_distance(-10.0, 200.0), 190.0), "negative distance wraps to the end")
	_check(is_equal_approx(Traffic.wrap_distance(75.0, 200.0), 75.0), "distance inside the road is untouched")


func _test_signals() -> void:
	_check(is_equal_approx(Traffic.signal_target_speed(12.0, 20.0, 0), 12.0), "green means go")
	_check(is_equal_approx(Traffic.signal_target_speed(12.0, 5.4, 2), 0.0), "a red at the stop line means stopped")
	_check(Traffic.signal_target_speed(12.0, 25.0, 2) < 12.0, "a red ahead means braking early")
	_check(is_equal_approx(Traffic.signal_target_speed(12.0, 80.0, 2), 12.0), "a distant red is not a brake yet")
	_check(is_equal_approx(Traffic.signal_target_speed(12.0, 9.0, 1), 12.0), "amber at the line means clear the crossing")
	_check(is_equal_approx(Traffic.signal_target_speed(12.0, 3.0, 2), 12.0), "already on the crossing means keep moving")


func _test_car_following() -> void:
	_check(is_equal_approx(Traffic.follow_speed(20.0, 100.0, 26.0), 20.0), "an empty road means cruise speed")
	_check(is_equal_approx(Traffic.follow_speed(20.0, 0.0, 26.0), 0.0), "a car on your bumper stops you")
	_check(Traffic.follow_speed(20.0, 13.0, 26.0) < 20.0, "closing in slows the car down")
	_check(Traffic.follow_speed(20.0, 13.0, 26.0) > Traffic.follow_speed(20.0, 5.0, 26.0),
		"the closer the car ahead, the slower you go")
	_check(is_equal_approx(Traffic.follow_speed(20.0, 100.0, 0.0), 20.0), "a zero safe gap never brakes")


func _test_zero_length_is_safe() -> void:
	_check(is_equal_approx(Traffic.wrap_distance(10.0, 0.0), 0.0), "a zero-length road does not divide by zero")
