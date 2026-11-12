extends SceneTree
## Headless tests for the career maths: routes, pay, ranks.
##
##   godot --headless --path . --script res://tests/test_career.gd

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[career] running tests")

	_test_routes()
	_test_cargo_rotation()
	_test_pay()
	_test_ranks()

	print("[career] %d checks, %d failures" % [_checks, _failures])
	quit(1 if _failures > 0 else 0)


func _check(condition: bool, message: String) -> void:
	_checks += 1
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)


func _test_routes() -> void:
	_check(CareerMath.route_seed(0) != CareerMath.route_seed(1), "job 1 gets a different road than job 0")
	_check(CareerMath.route_seed(3) != CareerMath.route_seed(4), "the whole career keeps rolling new roads")
	_check(CareerMath.route_seed(7) == CareerMath.route_seed(7), "the same job always rebuilds the same road")
	_check(CareerMath.route_seed(-5) == CareerMath.route_seed(0), "a negative job index is clamped")

	var short := CareerMath.route_length(0)
	var long := CareerMath.route_length(3)
	_check(long > short, "routes get longer with experience (%.0f -> %.0f m)" % [short, long])
	_check(CareerMath.route_length(99) >= 480.0 and CareerMath.route_length(99) <= 800.0,
		"even a long career keeps sane route lengths (%.0f m)" % CareerMath.route_length(99))


func _test_cargo_rotation() -> void:
	_check(CareerMath.cargo_name(0) == "Steel coils", "the career starts on steel coils")

	var names := {}
	for i in CareerMath.CARGO_NAMES.size():
		names[CareerMath.cargo_name(i)] = true

	_check(names.size() == CareerMath.CARGO_NAMES.size(), "every cargo in the list is reachable")
	_check(CareerMath.cargo_name(6) == CareerMath.cargo_name(0), "cargo cycles back around after the list")


func _test_pay() -> void:
	_check(CareerMath.reward_for(1000.0) > 0, "a decent run pays")
	_check(CareerMath.reward_for(2000.0) > CareerMath.reward_for(1000.0), "better runs pay more")
	_check(CareerMath.reward_for(0.0) == 0, "nothing is paid for nothing")
	_check(CareerMath.reward_for(-50.0) == 0, "a negative score does not bill the driver")

	_check(CareerMath.payout({"score": 800.0, "delivered": true}) > 0, "a delivered load pays")
	_check(CareerMath.payout({"score": 800.0, "delivered": false}) == 0, "a wrecked load pays nothing")


func _test_ranks() -> void:
	_check(CareerMath.rank_for(0) == "Rookie", "you start as a rookie")
	_check(CareerMath.rank_for(2500) != "Rookie", "money buys a promotion")
	_check(CareerMath.rank_for(1000000) == "Owner-operator", "the top rank is reachable")

	var previous := ""
	for total in [0, 2000, 6000, 12000, 24000]:
		var title := CareerMath.rank_for(total)
		_check(title != previous, "%d credits promotes beyond %s" % [total, previous if previous != "" else "nothing"])
		previous = title

	var next := CareerMath.next_rank(0)
	_check(next["name"] == "Junior driver" and int(next["remaining"]) == 2000, "the next promotion is advertised (needs $2000)")
	_check(int(CareerMath.next_rank(1000000)["remaining"]) == 0, "a top-ranked driver has nothing left to chase")
