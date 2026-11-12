extends SceneTree
## Headless unit tests for the camera orbit maths.
##
##   godot --headless --path . --script res://tests/test_camera_orbit.gd

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[orbit] running tests")

	_test_starts_centred()
	_test_horizontal_look()
	_test_vertical_clamp()
	_test_invert()
	_test_zoom_clamp()
	_test_recentre()
	_test_reset()

	print("[orbit] %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _test_starts_centred() -> void:
	var orbit := CameraOrbit.new()
	_check(not orbit.is_offset(), "starts centred")
	_check(is_equal_approx(orbit.zoom, 1.0), "starts at zoom 1")


func _test_horizontal_look() -> void:
	var orbit := CameraOrbit.new()
	orbit.apply_mouse(Vector2(10.0, 0.0), 0.1)
	_check(orbit.yaw < 0.0, "dragging right rotates the yaw (%.2f)" % orbit.yaw)
	_check(orbit.is_offset(), "orbit reports an offset after looking")

	var wrapped := CameraOrbit.new()
	wrapped.apply_mouse(Vector2(100000.0, 0.0), 0.1)
	_check(absf(wrapped.yaw) <= PI, "yaw wraps inside [-PI, PI] (%.2f)" % wrapped.yaw)


func _test_vertical_clamp() -> void:
	var orbit := CameraOrbit.new()
	for i in 100:
		orbit.apply_mouse(Vector2(0.0, 50.0), 0.1)
	_check(orbit.pitch >= CameraOrbit.MIN_PITCH - 0.001, "pitch cannot go below the minimum")
	_check(orbit.pitch <= CameraOrbit.MAX_PITCH + 0.001, "pitch cannot go above the maximum")


func _test_invert() -> void:
	var normal := CameraOrbit.new()
	normal.apply_mouse(Vector2(0.0, 40.0), 0.1)

	var inverted := CameraOrbit.new()
	inverted.apply_mouse(Vector2(0.0, 40.0), 0.1, true)

	_check(signf(normal.pitch) != signf(inverted.pitch), "invert flips the vertical direction")
	_check(absf(normal.pitch) > 0.0, "vertical look produces pitch")


func _test_zoom_clamp() -> void:
	var orbit := CameraOrbit.new()
	for i in 50:
		orbit.apply_zoom(1.0)
	_check(orbit.zoom >= CameraOrbit.MIN_ZOOM - 0.001, "zoom cannot go below the minimum (%.2f)" % orbit.zoom)

	for i in 100:
		orbit.apply_zoom(-1.0)
	_check(orbit.zoom <= CameraOrbit.MAX_ZOOM + 0.001, "zoom cannot go above the maximum (%.2f)" % orbit.zoom)


func _test_recentre() -> void:
	var orbit := CameraOrbit.new()
	orbit.apply_mouse(Vector2(200.0, 100.0), 0.1)
	var before := absf(orbit.yaw)

	orbit.recentre(0.5, 2.0)

	_check(absf(orbit.yaw) < before, "recentre pulls the yaw back (%.2f -> %.2f)" % [before, orbit.yaw])
	_check(absf(orbit.pitch) < 0.3, "recentre pulls the pitch back")


func _test_reset() -> void:
	var orbit := CameraOrbit.new()
	orbit.apply_mouse(Vector2(200.0, 100.0), 0.1)
	orbit.apply_zoom(2.0)
	orbit.reset()

	_check(not orbit.is_offset(), "reset clears the yaw and pitch")
	_check(is_equal_approx(orbit.zoom, 1.0), "reset restores the zoom")
