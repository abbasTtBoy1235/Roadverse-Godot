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
var last_summary: Dictionary = {}


func _ready() -> void:
	load_progress()


func current_cargo() -> String:
	return CareerMath.cargo_name(job_index)


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

	var paid := CareerMath.payout(run)

	cash += paid
	jobs_done += 1
	best_score = maxi(best_score, int(roundf(float(summary.get("score", 0.0)))))
	last_summary = run
	last_summary["paid"] = paid

	job_index += 1
	save_progress()


## A wrecked load costs you the job but not the career: same route, no pay.
func record_failure(summary: Dictionary) -> void:
	var run := summary.duplicate()
	run["delivered"] = false
	run["paid"] = 0

	last_summary = run
	save_progress()


func save_progress() -> void:
	var config := ConfigFile.new()
	config.set_value("career", "job_index", job_index)
	config.set_value("career", "cash", cash)
	config.set_value("career", "jobs_done", jobs_done)
	config.set_value("career", "best_score", best_score)
	config.save(SAVE_PATH)


func load_progress() -> void:
	var config := ConfigFile.new()

	if config.load(SAVE_PATH) != OK:
		return

	job_index = int(config.get_value("career", "job_index", 0))
	cash = int(config.get_value("career", "cash", 0))
	jobs_done = int(config.get_value("career", "jobs_done", 0))
	best_score = int(config.get_value("career", "best_score", 0))


func reset_progress() -> void:
	job_index = 0
	cash = 0
	jobs_done = 0
	best_score = 0
	last_summary = {}
	save_progress()
