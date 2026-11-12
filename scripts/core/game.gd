extends Node3D
## Root of the playable scene. Keeps only the cross-cutting concerns:
## restart, and the optional telemetry used by the headless smoke test.

const TELEMETRY_FLAG := "--rv-telemetry"


func _ready() -> void:
	InputSetup.ensure_registered()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("rv_restart"):
		get_tree().reload_current_scene()


func _physics_process(_delta: float) -> void:
	if not _telemetry_enabled():
		return

	if Engine.get_physics_frames() % 30 != 0:
		return

	var truck := get_node_or_null("Truck") as TruckController
	if truck == null:
		return

	print("RV_TELEMETRY speed_kph=%.2f gear=%d rpm=%.0f pos_z=%.2f" % [
		truck.speed_kph(),
		truck.gearbox.current_gear,
		truck.engine_rpm,
		truck.global_position.z,
	])


func _telemetry_enabled() -> bool:
	return TELEMETRY_FLAG in OS.get_cmdline_args()
