class_name ChaseCamera
extends Camera3D
## Smooth third-person camera. Press C to cycle chase / close chase / cockpit.

@export var target_path: NodePath
@export var distance := 9.5
@export var height := 3.6
@export var look_height := 1.6
@export var smooth := 5.5
@export var cockpit_offset := Vector3(0.0, 2.35, -1.9)

enum Mode { CHASE, CHASE_CLOSE, COCKPIT }

var mode: Mode = Mode.CHASE

var _target: Node3D


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D

	if _target == null:
		push_warning("ChaseCamera: target_path is not set, camera will not follow anything.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("rv_toggle_camera"):
		mode = ((mode + 1) % 3) as Mode


func _physics_process(delta: float) -> void:
	if _target == null:
		return

	var weight := 1.0 - exp(-smooth * delta)

	if mode == Mode.COCKPIT:
		var seat := _target.global_transform * cockpit_offset
		global_position = global_position.lerp(seat, weight)
		global_basis = _target.global_basis
		return

	var follow_distance := distance if mode == Mode.CHASE else distance * 0.55
	var follow_height := height if mode == Mode.CHASE else height * 0.75

	var desired := _target.global_position \
		- _target.global_basis.z * -follow_distance \
		+ Vector3.UP * follow_height

	global_position = global_position.lerp(desired, weight)
	look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)
