class_name CareerMath
extends RefCounted
## Pure career maths: how a job is chosen, what it pays, and what you are called
## once you have earned enough. Kept separate from the Career autoload so the
## headless suite can test it without touching a save file.

const CARGO_NAMES := [
	"Steel coils",
	"Timber",
	"Diesel drums",
	"Palletised freight",
	"Cold chain produce",
	"Concrete beams",
]

const RANKS := [
	{"name": "Rookie", "cash": 0},
	{"name": "Junior driver", "cash": 2000},
	{"name": "Company driver", "cash": 6000},
	{"name": "Long-haul driver", "cash": 12000},
	{"name": "Owner-operator", "cash": 24000},
]


## Every job gets its own road: a fixed seed plus a stride, so job 0 and job 1
## are never the same drive.
static func route_seed(job_index: int) -> int:
	return 20261112 + maxi(0, job_index) * 977


## Routes get a little longer as the career goes on.
static func route_length(job_index: int) -> float:
	return 560.0 + float(maxi(0, job_index) % 4) * 70.0


## Cargo rotates through the list so the HUD does not read the same forever.
static func cargo_name(job_index: int) -> String:
	return CARGO_NAMES[posmod(job_index, CARGO_NAMES.size())]


## Money paid for a delivery, straight from the score.
static func reward_for(score: float) -> int:
	return maxi(0, int(roundf(maxf(score, 0.0) * 0.12)))


## Rank title for a lifetime takings total.
static func rank_for(total_cash: int) -> String:
	var title := "Rookie"

	for rank in RANKS:
		if total_cash >= int(rank["cash"]):
			title = String(rank["name"])

	return title


## Cash still needed before the next promotion, and what that promotion is.
static func next_rank(total_cash: int) -> Dictionary:
	for rank in RANKS:
		if total_cash < int(rank["cash"]):
			return {"name": String(rank["name"]), "remaining": int(rank["cash"]) - total_cash}

	return {"name": "", "remaining": 0}


## A run is only paid out if the cargo survived and the gate was reached.
static func payout(summary: Dictionary) -> int:
	if not summary.get("delivered", true):
		return 0

	return reward_for(float(summary.get("score", 0.0)))
