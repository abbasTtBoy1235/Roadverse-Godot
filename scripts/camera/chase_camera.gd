class_name ChaseCamera
extends Camera3D
## Third-person camera. Drag with the right mouse button to look around, scroll to
## zoom, press C to cycle chase / close / cockpit. The camera drifts back behind
## the truck on its own once you let go.

@export var target_path: NodePath
@export var distance := 9.5
@export var height := 3.6
@export var look_height := 1.6
@export var smooth := 5.5
@export var recentre_speed := 1.8
@export var cockpit_offset := Vector3(0.0, 2.35, -1.9)

enum Mode { CHASE, CHASE_CLOSE, COCKPIT }

var mode: Mode = Mode.CHASE
var orbit := CameraOrbit.new()

var _target: Node3D
var _looking := false


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D

	if _target == null:
		push_warning("ChaseCamera: target_path is not set, camera will not follow anything.")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("rv_toggle_camera"):
		mode = ((mode + 1) % 3) as Mode
		orbit.reset()
		return

	if event is InputEventMouseMotion and _looking:
		orbit.apply_mouse(event.relative, _sensitivity(), Settings.invert_y)
		return

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			orbit.apply_zoom(1.0)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			orbit.apply_zoom(-1.0)
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			orbit.reset()


func _process(delta: float) -> void:
	if _target == null:
		return

	_looking = Input.is_action_pressed("rv_look")

	if not _looking and orbit.is_offset():
		orbit.recentre(delta, recentre_speed)

	var weight := 1.0 - exp(-smooth * delta)

	if mode == Mode.COCKPIT:
		var seat := _target.global_transform * cockpit_offset
		global_position = global_position.lerp(seat, weight)
		global_basis = _target.global_basis
		return

	var follow_distance := distance * orbit.zoom
	var follow_height := height

	if mode == Mode.CHASE_CLOSE:
		follow_distance *= 0.55
		follow_height *= 0.75

	# Base orientation follows the truck's heading; yaw and pitch are layered on
	# top so looking around stays relative to the truck.
	var base := Basis(Vector3.UP, _target.global_rotation.y)
	var view := base * Basis(Vector3.UP, orbit.yaw) * Basis(Vector3.RIGHT, orbit.pitch)

	var desired := _target.global_position + view * Vector3(0.0, 0.0, follow_distance) \
		+ Vector3.UP * follow_height

	global_position = global_position.lerp(desired, weight)
	look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)


func _sensitivity() -> float:
	if Settings == null:
		return 0.12

	return Settings.mouse_sensitivity


## Test hook: the current view offset in metres, used by the headless checks.
func orbit_offset() -> Vector2:
	return Vector2(orbit.yaw, orbit.pitch)
