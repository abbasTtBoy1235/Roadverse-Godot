extends SceneTree
## Headless unit tests for the gearbox.
##
##   godot --headless --path . --script res://tests/test_gearbox.gd
##
## Exits with code 1 when any check fails, so it works in CI.

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[gearbox] running tests")

	_test_starts_in_first_forward_gear()
	_test_shift_up_advances()
	_test_cannot_shift_above_top()
	_test_cannot_shift_below_reverse()
	_test_auto_shift_upshifts()
	_test_auto_shift_never_drops_into_reverse()
	_test_engine_rpm_scales_with_speed_and_ratio()
	_test_reverse_torque_is_negative()
	_test_validate_rejects_zero_ratio()
	_test_validate_rejects_too_few_gears()
	_test_validate_rejects_bad_thresholds()
	_test_cruise()

	print("[gearbox] %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _box() -> Gearbox:
	return Gearbox.new(PackedFloat32Array([-4.0, 5.0, 2.5, 1.25]), 4.0, 2000.0, 1200.0)


func _test_cruise() -> void:
	_check(is_equal_approx(TruckController.cruise_throttle(40.0, 80.0), 1.0), "cruise floors it when far under target")
	_check(is_equal_approx(TruckController.cruise_throttle(80.0, 80.0), 0.0), "cruise eases off at the target speed")
	_check(is_equal_approx(TruckController.cruise_throttle(95.0, 80.0), 0.0), "cruise never accelerates downhill")
	_check(TruckController.cruise_throttle(74.0, 80.0) > 0.4 and TruckController.cruise_throttle(74.0, 80.0) < 0.6,
		"cruise feeds in gently near the target (%.2f)" % TruckController.cruise_throttle(74.0, 80.0))


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _test_starts_in_first_forward_gear() -> void:
	var gearbox := _box()
	_check(gearbox.current_gear == 1, "starts in first forward gear")
	_check(not gearbox.is_reverse, "not in reverse at start")
	_check(gearbox.top_forward_gear == 3, "top forward gear is 3")


func _test_shift_up_advances() -> void:
	var gearbox := _box()
	_check(gearbox.shift_up(), "shift_up returns true")
	_check(gearbox.current_gear == 2, "gear advanced to 2")
	_check(is_equal_approx(gearbox.current_ratio, 2.5), "ratio is 2.5 in second gear")


func _test_cannot_shift_above_top() -> void:
	var gearbox := _box()
	gearbox.shift_to(gearbox.top_forward_gear)
	_check(not gearbox.shift_up(), "cannot shift above top gear")
	_check(gearbox.current_gear == gearbox.top_forward_gear, "gear stayed at top")


func _test_cannot_shift_below_reverse() -> void:
	var gearbox := _box()
	gearbox.shift_to(Gearbox.REVERSE)
	_check(not gearbox.shift_down(), "cannot shift below reverse")
	_check(gearbox.is_reverse, "still in reverse")


func _test_auto_shift_upshifts() -> void:
	var gearbox := _box()
	_check(gearbox.update_auto_shift(2100.0) == 1, "auto shift reports upshift")
	_check(gearbox.current_gear == 2, "gear is 2 after upshift")


func _test_auto_shift_never_drops_into_reverse() -> void:
	var gearbox := _box()
	_check(gearbox.update_auto_shift(300.0) == 0, "auto shift does nothing in first gear")
	_check(gearbox.current_gear == 1, "gear stayed at 1")


func _test_engine_rpm_scales_with_speed_and_ratio() -> void:
	var gearbox := _box()
	_check(is_equal_approx(gearbox.engine_rpm(100.0), 2000.0), "100 wheel rpm in 1st = 2000 engine rpm")


func _test_reverse_torque_is_negative() -> void:
	var gearbox := _box()
	gearbox.shift_to(Gearbox.REVERSE)
	_check(gearbox.wheel_torque(100.0) < 0.0, "reverse ratio yields negative torque")

	var forward := _box()
	_check(forward.wheel_torque(100.0) > 0.0, "forward ratio yields positive torque")


func _test_validate_rejects_zero_ratio() -> void:
	var problem := Gearbox.validate(PackedFloat32Array([0.0, 5.0]), 3.7, 2000.0, 1100.0)
	_check(problem != "", "zero ratio is rejected")


func _test_validate_rejects_too_few_gears() -> void:
	var problem := Gearbox.validate(PackedFloat32Array([5.0]), 3.7, 2000.0, 1100.0)
	_check(problem != "", "single-gear gearbox is rejected")


func _test_validate_rejects_bad_thresholds() -> void:
	var problem := Gearbox.validate(PackedFloat32Array([-4.0, 5.0]), 3.7, 1000.0, 1500.0)
	_check(problem != "", "downshift above upshift is rejected")
