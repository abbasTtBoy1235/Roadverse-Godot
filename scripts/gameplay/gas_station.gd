class_name GasStation
extends Node3D
## The fuel stop. Park in the bay and the pumps fill the tank at a few
## litres a second, charged to the career wallet by the litre.
##
## Like the toll plaza this polls the truck's position instead of using an
## Area3D: a teleported, sleeping VehicleBody3D never trips area signals.

const PRICE_PER_LITRE := 2
const PUMP_RATE := 7.0
const BAY_HALF := Vector2(18.0, 15.0)

var litres_pumped := 0.0

var _truck: Node3D
var _fuel: FuelTank
var _refuelling := false
var _unbilled := 0.0


func _physics_process(delta: float) -> void:
	_refuelling = false

	if _truck == null:
		_truck = get_tree().get_first_node_in_group("rv_truck") as Node3D

		if _truck != null:
			_fuel = _truck.get_node_or_null("FuelTank") as FuelTank

	if _truck == null or _fuel == null or not truck_inside():
		return

	var speed := 0.0

	if _truck is VehicleBody3D:
		speed = (_truck as VehicleBody3D).linear_velocity.length()

	if speed > 0.4 or _fuel.litres >= _fuel.capacity_litres - 0.01:
		return

	var added := _fuel.add_fuel(PUMP_RATE * delta)

	if added <= 0.0:
		return

	_refuelling = true
	litres_pumped += added
	_unbilled += added * float(PRICE_PER_LITRE)

	var whole := int(_unbilled)

	if whole >= 1:
		_unbilled -= float(whole)

		var career := get_node_or_null("/root/Career")

		if career != null:
			career.call("pay_toll", whole)


## Is the truck parked in the pump bay?
func truck_inside() -> bool:
	if _truck == null:
		return false

	var local := to_local(_truck.global_position)
	return absf(local.x) < BAY_HALF.x and absf(local.z) < BAY_HALF.y


func is_refuelling() -> bool:
	return _refuelling
