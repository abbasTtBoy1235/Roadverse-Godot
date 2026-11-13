class_name ExhaustSmoke
extends CPUParticles3D
## Diesel exhaust: a thin idle haze that thickens with engine load.
## Sits under the rear of the cargo body; built in the scene, positioned
## from the fitted model when there is one.

var _truck: TruckController


func _ready() -> void:
	_truck = get_parent() as TruckController

	var rear_z := 4.0
	var side_x := 0.95

	var socket := get_parent().get_node_or_null("TruckModel") as TruckModel

	if socket != null and socket.has_model:
		rear_z = socket.model_rear_z - 0.9
		side_x = socket.model_width * 0.5 - 0.35

	position = Vector3(side_x, 0.32, rear_z)

	amount = 28
	lifetime = 1.15
	local_coords = false
	direction = Vector3(0.25, 1.0, 0.55)
	spread = 24.0
	gravity = Vector3(0.0, 0.35, 0.0)
	initial_velocity_min = 1.1
	initial_velocity_max = 2.3
	scale_amount_min = 0.16
	scale_amount_max = 0.42
	color = Color(0.12, 0.12, 0.13, 0.4)
	emitting = false


func _process(_delta: float) -> void:
	if _truck == null:
		return

	var load := _truck.engine_load
	emitting = load > 0.02
	# A loaded engine puffs harder: same haze, thrown faster and further.
	initial_velocity_min = lerpf(0.8, 1.7, load)
	initial_velocity_max = lerpf(1.6, 3.4, load)


## Test hook: is the exhaust smoking right now?
func smoke_active() -> bool:
	return emitting
