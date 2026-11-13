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


## Long-haul routes: 1.25 km for the first job, growing to nearly 2 km.
## The map used to top out at 770 m, which a truck covered in under a minute.
static func route_length(job_index: int) -> float:
	return 1250.0 + float(maxi(0, job_index) % 4) * 240.0


## Cargo rotates through the list so the HUD does not read the same forever.
static func cargo_name(job_index: int) -> String:
	return CARGO_NAMES[posmod(job_index, CARGO_NAMES.size())]


## Money paid for a delivery: from the score, scaled by how far the haul was
## (a 2 km run at the old flat rate paid the same as a trip round the block).
static func reward_for(score: float, route_metres := 560.0) -> int:
	var distance_factor := clampf(route_metres / 560.0, 1.0, 3.5)
	return maxi(0, int(roundf(maxf(score, 0.0) * 0.12 * distance_factor)))


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


## What a clean, frugal run of this length should burn, in litres.
static func par_fuel(route_metres: float) -> float:
	return maxf(1.0, route_metres / 620.0 * 6.0)


## Bonus for sipping rather than gulping: up to $200 for a perfect run, nothing
## for a thirsty one.
static func economy_bonus(litres_used: float, par_litres: float) -> int:
	if par_litres <= 0.0:
		return 0

	var saved := (par_litres - litres_used) / par_litres
	return maxi(0, int(roundf(clampf(saved, 0.0, 1.0) * 200.0)))


## A run is only paid out if the cargo survived and the gate was reached.
static func payout(summary: Dictionary) -> int:
	if not summary.get("delivered", true):
		return 0

	return reward_for(float(summary.get("score", 0.0)), float(summary.get("route_metres", 560.0)))
