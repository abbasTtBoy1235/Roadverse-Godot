extends SceneTree
## Headless tests for the weather and road-noise maths.
##
##   godot --headless --path . --script res://tests/test_weather_noise.gd

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[weather/noise] running tests")

	_test_tyre_curve()
	_test_wind_curve()
	_test_fog()
	_test_wetness_target()

	print("[weather/noise] %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _test_tyre_curve() -> void:
	_check(is_equal_approx(RoadNoise.tyre_gain(0.0), 0.0), "a parked truck makes no tyre noise")
	_check(RoadNoise.tyre_gain(30.0) > 0.3, "tyres are already loud in town (%.2f)" % RoadNoise.tyre_gain(30.0))
	_check(RoadNoise.tyre_gain(95.0) >= 0.99, "full gain at motorway speed")
	_check(RoadNoise.tyre_gain(400.0) <= 1.0, "tyre gain is clamped")
	_check(RoadNoise.tyre_gain(80.0) > RoadNoise.tyre_gain(40.0), "tyres get louder with speed")


func _test_wind_curve() -> void:
	_check(RoadNoise.wind_gain(0.0) < 0.01, "no wind when stopped")
	_check(RoadNoise.wind_gain(130.0) >= 0.99, "full wind at top speed")
	_check(RoadNoise.wind_gain(200.0) <= 1.0, "wind gain is clamped")

	var slow := RoadNoise.wind_gain(40.0)
	var fast := RoadNoise.wind_gain(80.0)
	_check(fast > slow * 3.0, "wind rises quadratically, not linearly (%.2f -> %.2f)" % [slow, fast])


func _test_fog() -> void:
	_check(is_equal_approx(Weather.fog_density(false, 0.008, 0.022), 0.008), "clear night keeps the thin fog")
	_check(is_equal_approx(Weather.grip_for(Weather.Mode.SNOW, 0.5), 0.55), "snow is properly slippery (%.2f)" % Weather.grip_for(Weather.Mode.SNOW, 0.5))
	_check(Weather.grip_for(Weather.Mode.RAIN, 1.0) < Weather.grip_for(Weather.Mode.RAIN, 0.0), "rain gets greasier as the road soaks")
	_check(is_equal_approx(Weather.grip_for(Weather.Mode.CLEAR, 0.0), 1.0), "dry tarmac grips fully")
	_check(Weather.fog_for_mode(Weather.Mode.FOG, 0.008, 0.022) > 0.04, "fog mode is a pea-souper (%.3f)" % Weather.fog_for_mode(Weather.Mode.FOG, 0.008, 0.022))
	_check(is_equal_approx(Weather.target_wetness_for(Weather.Mode.SNOW), 0.55), "snow leaves slush on the road")
	_check(is_equal_approx(Weather.fog_density(true, 0.008, 0.022), 0.022), "rain thickens the fog")
	_check(Weather.fog_density(true, 0.008, 0.022) > Weather.fog_density(false, 0.008, 0.022), "rain is hazier than clear")


func _test_wetness_target() -> void:
	_check(is_equal_approx(Weather.target_wetness(true, 1.0), 1.0), "rain soaks the road")
	_check(is_equal_approx(Weather.target_wetness(false, 1.0), 0.0), "a dry night dries the road")
	_check(is_equal_approx(Weather.target_wetness(true, 3.0), 1.0), "soak is clamped")
