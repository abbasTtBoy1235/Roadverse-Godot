class_name FuelTank
extends Node
## Diesel tank. Big enough that a single haul never strands you, small enough that
## how you drive shows up on the gauge — and in the payout, because a job that
## burns less fuel pays a bonus.

@export var capacity_litres := 60.0
@export var truck_path: NodePath

var litres := 0.0
var litres_used := 0.0

var _truck: TruckController


## Litres per second: an idle tick-over plus what the pedal asks for.
static func burn_rate(load: float, rpm_ratio: float) -> float:
	var pedal := clampf(load, 0.0, 1.0)
	var revs := clampf(rpm_ratio, 0.0, 1.0)
	return 0.020 + 0.10 * pedal * (0.4 + 0.6 * revs)


func _ready() -> void:
	_truck = get_node_or_null(truck_path) as TruckController
	litres = capacity_litres


func _physics_process(delta: float) -> void:
	if _truck == null or litres <= 0.0:
		return

	var rate := burn_rate(_truck.engine_load, _truck.engine_rpm / maxf(1.0, _truck.max_rpm))
	var burnt := minf(rate * delta, litres)

	litres -= burnt
	litres_used += burnt


func is_empty() -> bool:
	return litres <= 0.0


func level() -> float:
	if capacity_litres <= 0.0:
		return 0.0

	return clampf(litres / capacity_litres, 0.0, 1.0)


## Full tank, zero counter: a new shift starts at the pump.
func reset() -> void:
	litres = capacity_litres
	litres_used = 0.0


func refill() -> void:
	litres = capacity_litres
