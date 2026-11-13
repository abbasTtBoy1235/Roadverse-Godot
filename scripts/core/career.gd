extends Node
## Career state that outlives the scene: which job you are on, what you have earnt
## and your best run. Every delivery bumps the job index, and the next scene load
## builds a fresh road from it — so "next job" really is a new route.
##
## Registered as the `Career` autoload.

const SAVE_PATH := "user://career.cfg"

var job_index := 0
var cash := 0
var jobs_done := 0
var best_score := 0
var total_metres := 0.0
var perfect_runs := 0
var unlocked_achievements: Array = []
var leaderboard: Array = []
var last_summary: Dictionary = {}


func _ready() -> void:
	load_progress()


func current_cargo() -> String:
	return CareerMath.cargo_name(job_index)


func current_kind() -> String:
	return CareerMath.kind_for(job_index)


func current_seed() -> int:
	return CareerMath.route_seed(job_index)


func current_route_length() -> float:
	return CareerMath.route_length(job_index)


func rank() -> String:
	return CareerMath.rank_for(cash)


## Called once per successful delivery.
func record_delivery(summary: Dictionary) -> void:
	var run := summary.duplicate()
	run["delivered"] = true

	var paid := CareerMath.payout(run) + int(summary.get("fuel_bonus", 0))

	cash += paid
	jobs_done += 1
	best_score = maxi(best_score, int(roundf(float(summary.get("score", 0.0)))))
	total_metres += float(summary.get("route_metres", 0.0))

	if float(summary.get("damage", 0.0)) <= 0.001:
		perfect_runs += 1

	leaderboard = CareerMath.leaderboard_insert(leaderboard, {
		"score": int(roundf(float(summary.get("score", 0.0)))),
		"cargo": String(summary.get("cargo", "Cargo")),
		"kind": String(summary.get("kind", "standard")),
		"seconds": int(roundf(float(summary.get("seconds", 0.0)))),
	})

	last_summary = run
	last_summary["paid"] = paid

	var fresh := CareerMath.new_achievements({
		"deliveries": jobs_done, "perfect": perfect_runs, "metres": total_metres,
		"best": best_score, "cash": cash, "unlocked": unlocked_achievements,
	})
	var fresh_names: Array = []

	for id in fresh:
		unlocked_achievements.append(id)
		fresh_names.append(CareerMath.achievement_name(String(id)))

	last_summary["achievements"] = fresh_names

	job_index += 1
	save_progress()


## A wrecked load costs you the job but not the career: same route, no pay.
func record_failure(summary: Dictionary) -> void:
	var run := summary.duplicate()
	run["delivered"] = false
	run["paid"] = 0

	last_summary = run
	save_progress()


## Toll plazas and the like: money out of the wallet.
func pay_toll(amount: int) -> void:
	cash = maxi(0, cash - amount)
	save_progress()


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("career", "job_index", job_index)
	config.set_value("career", "cash", cash)
	config.set_value("career", "jobs_done", jobs_done)
	config.set_value("career", "best_score", best_score)
	config.set_value("career", "total_metres", total_metres)
	config.set_value("career", "perfect_runs", perfect_runs)
	config.set_value("career", "achievements", ",".join(PackedStringArray(unlocked_achievements)))
	config.set_value("career", "leaderboard", JSON.stringify(leaderboard))
	config.save(SAVE_PATH)


func load_progress() -> void:
	var config := ConfigFile.new()

	if config.load(SAVE_PATH) != OK:
		return

	job_index = int(config.get_value("career", "job_index", 0))
	cash = int(config.get_value("career", "cash", 0))
	jobs_done = int(config.get_value("career", "jobs_done", 0))
	best_score = int(config.get_value("career", "best_score", 0))
	total_metres = float(config.get_value("career", "total_metres", 0.0))
	perfect_runs = int(config.get_value("career", "perfect_runs", 0))

	var saved_achievements := String(config.get_value("career", "achievements", ""))
	unlocked_achievements = [] if saved_achievements.is_empty() else Array(saved_achievements.split(","))

	var saved_board = JSON.parse_string(String(config.get_value("career", "leaderboard", "[]")))
	leaderboard = saved_board if saved_board is Array else []


func reset_progress() -> void:
	job_index = 0
	cash = 0
	jobs_done = 0
	best_score = 0
	total_metres = 0.0
	perfect_runs = 0
	unlocked_achievements = []
	leaderboard = []
	last_summary = {}
	save_progress()
