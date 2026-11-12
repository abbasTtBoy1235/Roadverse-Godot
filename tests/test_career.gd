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
	_test_economy()

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


func _test_economy() -> void:
	var par := CareerMath.par_fuel(620.0)
	_check(par > 1.0, "a 620 m route has a fuel par (%.1f L)" % par)
	_check(CareerMath.par_fuel(1240.0) > par, "longer routes get a bigger allowance")

	_check(CareerMath.economy_bonus(par * 0.5, par) > 0, "a frugal run earns a bonus")
	_check(CareerMath.economy_bonus(par * 0.5, par) > CareerMath.economy_bonus(par, par),
		"the bonus shrinks as the tank empties faster")
	_check(CareerMath.economy_bonus(par * 0.5, par) <= 200, "the economy bonus is capped at $200")
	_check(CareerMath.economy_bonus(par * 2.0, par) == 0, "a thirsty run earns nothing extra")
	_check(CareerMath.economy_bonus(10.0, 0.0) == 0, "no par means no bonus")

	_check(FuelTank.burn_rate(0.0, 0.0) > 0.0, "an idling engine still burns diesel")
	_check(FuelTank.burn_rate(1.0, 1.0) > FuelTank.burn_rate(0.5, 0.5), "full throttle burns more")
	_check(FuelTank.burn_rate(5.0, 5.0) == FuelTank.burn_rate(1.0, 1.0), "the burn rate is clamped")

	_check(ChaseCamera.shake_for(1.0) == 0.0, "gentle speed changes do not shake the camera")
	_check(ChaseCamera.shake_for(12.0) > 0.0, "a crash shakes the camera")
	_check(ChaseCamera.shake_for(1000.0) <= 1.0, "shake is clamped")


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
