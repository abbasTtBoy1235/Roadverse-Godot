extends Node3D
## Integration test: wreck the cargo and check the career refuses to pay.
##
##   godot --headless --path . res://tests/mission_failure.tscn

const SETTLE_SECONDS := 0.4

var _game: Node3D
var _mission: Mission
var _results: CanvasLayer
var _career: Node

var _cash_before := 0
var _job_before := 0
var _elapsed := 0.0
var _phase := 0
var _failures := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_career = get_node_or_null("/root/Career")

	if _career != null:
		_career.call("reset_progress")
		_career.set("cash", 500)
		_cash_before = int(_career.get("cash"))
		_job_before = int(_career.get("job_index"))

	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(_game)

	_mission = _game.get_node("Mission") as Mission
	_results = _game.get_node("Results") as CanvasLayer

	_check(_mission != null, "mission found")
	_check(_results != null, "results panel found")
	_check(_mission.state == Mission.State.DRIVING, "the job starts in progress")

	_mission.take_damage(1.0)
	_check(is_equal_approx(_mission.damage, 1.0), "the load can be wrecked outright")


func _physics_process(delta: float) -> void:
	_elapsed += delta

	if _phase == 0 and _elapsed >= SETTLE_SECONDS:
		_phase = 1
		_check_failure()


func _check_failure() -> void:
	_check(_mission.state == Mission.State.FAILED, "a wrecked load fails the job")
	_check(_mission.score == 0.0, "no score is awarded")
	_check("WRECKED" in _mission.status_text(), "the HUD says the cargo is wrecked")

	if _career != null:
		_check(int(_career.get("cash")) == _cash_before, "a failed run pays nothing")
		_check(int(_career.get("job_index")) == _job_before, "the same job is waiting to be retried")

	if _results != null and _results.has_method("failed"):
		_check(bool(_results.call("is_showing")), "the failure screen is on")
		_check(bool(_results.call("failed")), "it is the failure screen, not the payout one")

	if _failures == 0:
		print("[failure] PASS")
		get_tree().paused = false
		get_tree().quit(0)
	else:
		printerr("[failure] FAIL (%d checks)" % _failures)
		get_tree().paused = false
		get_tree().quit(1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("  ok   %s" % message)
	else:
		_failures += 1
		printerr("  FAIL %s" % message)
