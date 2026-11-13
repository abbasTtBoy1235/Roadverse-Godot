extends SceneTree
## Headless tests for the career maths: routes, pay, ranks.
##
##   godot --headless --path . --script res://tests/test_career.gd

var _checks := 0
var _failures := 0


func _initialize() -> void:
	print("[career] running tests")

	_test_routes()
	_test_job_kinds()
	_test_cargo_rotation()
	_test_pay()
	_test_ranks()
	_test_economy()
	_test_leaderboard_and_achievements()

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
	_check(CareerMath.route_length(99) >= 4000.0 and CareerMath.route_length(99) <= 6500.0,
		"even a long career keeps sane route lengths (%.0f m)" % CareerMath.route_length(99))
	_check(CareerMath.route_length(0) >= 4000.0, "the first job is a real long haul now (%.0f m)" % CareerMath.route_length(0))
	_check(CareerMath.reward_for(1000.0, 1680.0) > CareerMath.reward_for(1000.0, 560.0),
		"longer hauls pay more than short ones")


func _test_job_kinds() -> void:
	_check(CareerMath.kind_for(0) == "standard", "the first job is a standard haul")
	_check(CareerMath.kind_for(1) == "fragile", "job two is a fragile load")
	_check(CareerMath.kind_for(2) == "urgent", "job three is against the clock")
	_check(CareerMath.kind_for(3) == "standard", "job kinds rotate")
	_check(CareerMath.damage_multiplier("fragile") > 2.0, "fragile cargo breaks far easier (x%.1f)" % CareerMath.damage_multiplier("fragile"))
	_check(is_equal_approx(CareerMath.damage_multiplier("standard"), 1.0), "standard cargo takes normal knocks")
	_check(CareerMath.par_scale("urgent") < 1.0, "urgent jobs run a tighter clock (x%.2f)" % CareerMath.par_scale("urgent"))
	_check(CareerMath.urgent_bonus_earned("urgent", 50.0, 60.0), "beating the urgent clock earns the bonus")
	_check(not CareerMath.urgent_bonus_earned("urgent", 70.0, 60.0), "a late urgent run earns no bonus")
	_check(not CareerMath.urgent_bonus_earned("standard", 50.0, 60.0), "standard jobs have no clock bonus")


func _test_leaderboard_and_achievements() -> void:
	var board: Array = []

	for i in 12:
		board = CareerMath.leaderboard_insert(board, {"score": i * 100, "cargo": "x", "seconds": i})

	_check(board.size() == 10, "the leaderboard keeps only the top ten (%d)" % board.size())
	_check(int(board[0].get("score", 0)) == 1100, "the leaderboard is sorted best-first")
	_check(int(board[9].get("score", 0)) == 200, "the weakest runs fall off the board")

	var fresh := CareerMath.new_achievements({"deliveries": 1, "perfect": 1, "metres": 1500.0, "best": 500, "cash": 300, "unlocked": []})
	_check(fresh.has("first_load"), "the first delivery unlocks First load")
	_check(fresh.has("flawless"), "a clean run unlocks White gloves")
	_check(not fresh.has("ten_loads"), "one delivery is not Regular hauler yet")

	var later := CareerMath.new_achievements({"deliveries": 12, "perfect": 1, "metres": 15000.0, "best": 950, "cash": 13000, "unlocked": fresh})
	_check(later.has("ten_loads") and later.has("long_hauler") and later.has("sharp") and later.has("tycoon"),
		"a long career unlocks the rest (%s)" % str(later))
	_check(not later.has("first_load"), "already-unlocked achievements stay unlocked")
	_check(CareerMath.achievement_name("flawless") == "White gloves", "achievements have display names")
	_check(CareerMath.slot_path(0) != CareerMath.slot_path(2), "save slots are separate files")
	_check(CareerMath.slot_path(9) == CareerMath.slot_path(2), "slot numbers are clamped")
	_check(CareerMath.upgrade_cost("engine", 0) == 800, "the first engine tune costs $800")
	_check(CareerMath.upgrade_cost("engine", 1) == 1600, "the second level costs double")
	_check(CareerMath.torque_multiplier(3) > 1.3, "a maxed engine pulls much harder (x%.2f)" % CareerMath.torque_multiplier(3))
	_check(CareerMath.brake_multiplier(2) > 1.25, "brake kits bite harder (x%.2f)" % CareerMath.brake_multiplier(2))
	_check(is_equal_approx(CareerMath.tank_capacity(3), 120.0), "a maxed tank doubles the range (%.0f L)" % CareerMath.tank_capacity(3))


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
