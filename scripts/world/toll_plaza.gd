class_name TollPlaza
extends Node3D
## Controller for the toll plaza RoadBuilder builds: barrier arms that lift
## as the truck approaches, lane lights that follow them, and a fee taken
## from the career wallet on the way through.
##
## Geometry is built by RoadBuilder; this node only animates the parts it
## finds by name (Arm0..2, LaneRed0..2, LaneGreen0..2).

@export var toll_distance := 0.0
@export var toll_fee := 12
## How far opens the arms, 0..1. Test hook.
var arms_open := 0.0

var _pivots: Array[Node3D] = []
var _red: Array[MeshInstance3D] = []
var _green: Array[MeshInstance3D] = []
var _charged := false
var _prev_rel := -1.0


func _ready() -> void:
	_collect()


func _collect() -> void:
	if not _pivots.is_empty():
		return

	for i in 3:
		var arm := get_node_or_null("Arm%d" % i) as Node3D
		if arm != null:
			_pivots.append(arm)

		var red := get_node_or_null("LaneRed%d" % i) as MeshInstance3D
		if red != null:
			_red.append(red)

		var green := get_node_or_null("LaneGreen%d" % i) as MeshInstance3D
		if green != null:
			_green.append(green)


func _process(delta: float) -> void:
	_collect()

	var road := get_parent() as RoadBuilder
	var truck := get_tree().get_first_node_in_group("rv_truck") as Node3D

	if road == null or truck == null or toll_distance <= 0.0:
		return

	var rel := road.nearest_distance(truck.global_position) - toll_distance

	# Arms lift while the truck is in the plaza zone, from either side.
	var target := 1.0 if absf(rel) < 16.0 else 0.0
	arms_open = move_toward(arms_open, target, delta * 1.8)

	for pivot in _pivots:
		pivot.rotation.z = -arms_open * 1.15

	for lamp in _red:
		lamp.visible = arms_open < 0.7

	for lamp in _green:
		lamp.visible = arms_open >= 0.7

	# Crossing the booth line, in either direction, costs the fee once.
	if _prev_rel < 0.0 and rel >= 0.0 and not _charged:
		_charged = true

		var career := get_node_or_null("/root/Career")

		if career != null and career.has_method("pay_toll"):
			career.call("pay_toll", toll_fee)

	if rel < -30.0:
		_charged = false

	_prev_rel = rel


## Test hook: are the barriers up?
func is_open() -> bool:
	return arms_open > 0.7


## Test hook: has this pass been charged yet?
func charged() -> bool:
	return _charged
