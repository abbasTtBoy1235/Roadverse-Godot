extends SceneTree
## Headless unit tests for the day/night model.
##
##   godot --headless --path . --script res://tests/test_day_cycle.gd

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[daycycle] running tests")

	_test_sun_elevation_curve()
	_test_day_factor_extremes()
	_test_light_energies_swap_at_dusk()
	_test_is_night()
	_test_continuity_across_midnight()
	_test_clock_string()
	_test_night_is_darker_than_day()
	_test_sky_and_dimmers()

	print("[daycycle] %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _near(actual: float, expected: float, tolerance := 0.01) -> bool:
	return absf(actual - expected) <= tolerance


func _test_sun_elevation_curve() -> void:
	_check(_near(DayCycle.sun_elevation(12.0), 90.0), "sun is at +90 deg at noon")
	_check(_near(DayCycle.sun_elevation(0.0), -90.0), "sun is at -90 deg at midnight")
	_check(_near(DayCycle.sun_elevation(6.0), 0.0), "sun is at 0 deg at sunrise")
	_check(_near(DayCycle.sun_elevation(18.0), 0.0), "sun is at 0 deg at sunset")
	_check(_near(DayCycle.sun_pitch_degrees(12.0), -90.0), "sun light points straight down at noon")


func _test_day_factor_extremes() -> void:
	_check(_near(DayCycle.day_factor(12.0), 1.0), "day factor is 1 at noon")
	_check(_near(DayCycle.day_factor(0.0), 0.0), "day factor is 0 at midnight")


func _test_light_energies_swap_at_dusk() -> void:
	_check(DayCycle.sun_energy(12.0) > DayCycle.sun_energy(21.0), "sun is brighter at noon than at night")
	_check(DayCycle.moon_energy(0.0) > DayCycle.moon_energy(12.0), "moon is brighter at midnight than at noon")
	_check(_near(DayCycle.sun_energy(0.0), 0.0, 0.02), "sun is off at midnight")


func _test_is_night() -> void:
	_check(DayCycle.is_night(22.0), "22:00 counts as night")
	_check(DayCycle.is_night(3.0), "03:00 counts as night")
	_check(not DayCycle.is_night(12.0), "noon is not night")


func _test_continuity_across_midnight() -> void:
	var before := DayCycle.day_factor(23.99)
	var after := DayCycle.day_factor(0.01)
	_check(absf(before - after) < 0.02, "no jump in daylight across midnight (%.4f vs %.4f)" % [before, after])

	var dusk := DayCycle.sun_elevation(23.5)
	var dawn := DayCycle.sun_elevation(0.5)
	_check(absf(dusk - dawn) < 15.0, "sun elevation is continuous around midnight")


func _test_clock_string() -> void:
	_check(DayCycle.clock_string(21.5) == "21:30", "21.5 formats as 21:30 (got %s)" % DayCycle.clock_string(21.5))
	_check(DayCycle.clock_string(0.0) == "00:00", "0.0 formats as 00:00")
	_check(DayCycle.clock_string(23.99) == "23:59", "23.99 formats as 23:59")


func _test_sky_and_dimmers() -> void:
	_check(_near(DayCycle.night_factor(0.0), 1.0), "night factor is 1 at midnight")
	_check(_near(DayCycle.night_factor(12.0), 0.0), "night factor is 0 at noon")

	# The procedural sky's gradient stops.
	_check(DayCycle.sky_top_color(12.0).get_luminance() < DayCycle.sky_horizon_color(12.0).get_luminance(),
		"the midday zenith is deeper than the horizon")
	_check(DayCycle.sky_top_color(0.0).get_luminance() < 0.05, "the midnight zenith is nearly black (%.3f)" % DayCycle.sky_top_color(0.0).get_luminance())
	_check(DayCycle.sky_horizon_color(6.0).r > DayCycle.sky_horizon_color(6.0).b,
		"the horizon burns warm at sunrise (r %.2f > b %.2f)" % [DayCycle.sky_horizon_color(6.0).r, DayCycle.sky_horizon_color(6.0).b])
	_check(DayCycle.sky_horizon_color(12.0).b > DayCycle.sky_horizon_color(12.0).r, "the midday horizon is blue")
	_check(DayCycle.sky_color(13.0).v > DayCycle.sky_color(1.0).v, "the daytime sky is brighter than the night sky")
	_check(DayCycle.sky_color(6.0).r > DayCycle.sky_color(6.0).b, "the sunrise sky warms up (r %.2f > b %.2f)" % [DayCycle.sky_color(6.0).r, DayCycle.sky_color(6.0).b])
	_check(DayCycle.glow_intensity(0.0) > DayCycle.glow_intensity(12.0), "bloom is stronger at night")
	_check(DayCycle.fog_density(0.0) > DayCycle.fog_density(12.0), "fog is thicker at night")


func _test_night_is_darker_than_day() -> void:
	var night := DayCycle.ambient_color(1.0)
	var day := DayCycle.ambient_color(13.0)
	_check(night.v < day.v, "night ambient luminance is lower than daytime")
	_check(DayCycle.ambient_energy(1.0) < DayCycle.ambient_energy(13.0), "night ambient energy is lower")
