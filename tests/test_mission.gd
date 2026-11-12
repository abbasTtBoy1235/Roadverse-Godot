extends SceneTree
## Headless tests for the mission scoring model and the city beacons.
##
##   godot --headless --path . --script res://tests/test_mission.gd

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[mission] running tests")

	_test_impact_damage()
	_test_scoring()
	_test_arrival()
	_test_progress()
	_test_beacons()

	print("[mission] %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _test_impact_damage() -> void:
	_check(is_equal_approx(Mission.damage_for_impact(1.0, 0.02, 3.0), 0.0), "a light touch costs nothing")
	_check(Mission.damage_for_impact(9.0, 0.02, 3.0) > 0.0, "a real hit damages the load")
	_check(Mission.damage_for_impact(9.0, 0.02, 3.0) > Mission.damage_for_impact(5.0, 0.02, 3.0),
		"harder hits hurt more")
	_check(Mission.damage_for_impact(500.0, 0.02, 3.0) <= 0.4, "one crash cannot total the cargo")


func _test_scoring() -> void:
	var clean := Mission.score_for(60.0, 0.0, 95.0, 1000.0)
	var damaged := Mission.score_for(60.0, 0.5, 95.0, 1000.0)
	var slow := Mission.score_for(300.0, 0.0, 95.0, 1000.0)

	_check(clean > damaged, "undamaged cargo scores higher (%d vs %d)" % [roundi(clean), roundi(damaged)])
	_check(clean > slow, "arriving late costs points (%d vs %d)" % [roundi(clean), roundi(slow)])
	_check(slow > 0.0, "a slow delivery still pays something")
	_check(clean <= 1000.0, "you cannot beat the base score")
	_check(Mission.score_for(1.0, 0.0, 95.0, 1000.0) <= 1000.0, "a suspiciously fast run is capped")


func _test_arrival() -> void:
	_check(Mission.is_arrived(600.0, 590.0, 5.0, 15.0), "reaching the gate slowly delivers")
	_check(not Mission.is_arrived(600.0, 590.0, 60.0, 15.0), "you must slow down for the gate")
	_check(not Mission.is_arrived(400.0, 590.0, 5.0, 15.0), "you must actually reach the gate")


func _test_progress() -> void:
	_check(is_equal_approx(Mission.progress_fraction(300.0, 600.0), 0.5), "halfway is 50%")
	_check(is_equal_approx(Mission.progress_fraction(900.0, 600.0), 1.0), "progress is capped at 100%")
	_check(is_equal_approx(Mission.progress_fraction(10.0, 0.0), 1.0), "a zero-length job is done instantly")


func _test_beacons() -> void:
	var lowest := 1.0
	var highest := 0.0
	var time := 0.0

	while time < 6.0:
		var energy := RoadBuilder.beacon_energy(time)
		lowest = minf(lowest, energy)
		highest = maxf(highest, energy)
		time += 0.05

	_check(highest > 0.9, "the beacons reach full brightness (%.2f)" % highest)
	_check(lowest > 0.2, "the beacons never go fully dark (%.2f)" % lowest)
