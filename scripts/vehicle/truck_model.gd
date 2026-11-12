class_name TruckModel
extends Node3D
## Socket for a real truck mesh. Drop `models/truck.glb` into the project and this
## swaps it in for the procedural box: the placeholder `Body` and `Cab` meshes go
## away, the physics wheels keep their VehicleWheel3D behaviour, and their visuals
## are attached to the model's own named wheel nodes if it has them.
##
## With no file present the procedural truck is left exactly as it is, so this is
## never a hard dependency.

const MODEL_PATH := "res://models/truck.glb"
const WHEEL_NAMES := {
	"wheel_fl": "WheelFL",
	"wheel_fr": "WheelFR",
	"wheel_rl": "WheelRL",
	"wheel_rr": "WheelRR",
}

## Set by the loader: true when a real model is in use.
var has_model := false
## Names of the wheel nodes the model provided.
var model_wheels: Array[String] = []

var _truck: Node3D
var _model_root: Node3D


static func model_exists() -> bool:
	return ResourceLoader.exists(MODEL_PATH)


func _ready() -> void:
	_truck = get_parent()

	if _truck == null:
		return

	if not model_exists():
		return

	var scene := load(MODEL_PATH) as PackedScene

	if scene == null:
		push_warning("TruckModel: %s is not a loadable scene." % MODEL_PATH)
		return

	var root := scene.instantiate() as Node3D

	if root == null:
		push_warning("TruckModel: %s has no 3D root node." % MODEL_PATH)
		return

	apply_model(root)


## Takes over an already-instantiated model. Public so the headless suite can
## feed it a synthetic tree instead of shipping a GLB in the repo.
func apply_model(root: Node3D) -> bool:
	if root == null or _truck == null:
		return false

	_model_root = root
	add_child(_model_root)
	has_model = true

	_hide_placeholder()
	_adopt_wheels()

	return true


## The procedural body and cab are only there to stand in for a real mesh.
func _hide_placeholder() -> void:
	for name in ["Body", "Cab"]:
		var node := _truck.get_node_or_null(name) as Node3D

		if node != null:
			node.visible = false


## If the model names its wheels, drive those instead of the primitive cylinders.
func _adopt_wheels() -> void:
	for key in WHEEL_NAMES.keys():
		var wheel_node := _truck.get_node_or_null(WHEEL_NAMES[key]) as VehicleWheel3D

		if wheel_node == null:
			continue

		var model_wheel := _model_root.find_child(String(key), true, false) as Node3D

		if model_wheel == null:
			continue

		var spin := wheel_node.get_node_or_null("Spin") as Node3D
		var visual := spin.get_node_or_null("Visual") as Node3D if spin != null else null

		if visual != null:
			visual.visible = false

		if spin != null:
			# reparent keeps the wheel's own local offset but moves it under the
			# physics pivot, so steering and rolling drive the real mesh.
			model_wheel.reparent(spin, false)
			model_wheels.append(String(key))


## Test hook: how many wheels the model supplied.
func adopted_wheel_count() -> int:
	return model_wheels.size()
