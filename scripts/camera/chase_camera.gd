class_name ChaseCamera
extends Camera3D
## Third-person camera with free mouse look.
##
## The mouse is captured while driving, so moving it always rotates the view —
## no modifier key needed. After a moment without mouse movement the camera eases
## back behind the truck. Scroll zooms, middle click recentres, C cycles modes.

@export var target_path: NodePath
@export var distance := 9.5
@export var height := 3.6
@export var look_height := 1.6
@export var smooth := 5.5
@export var recentre_speed := 1.6
## Seconds of no mouse movement before the camera drifts back behind the truck.
@export var auto_recentre_delay := 1.2
## If the camera ever falls further behind than this, snap instead of easing.
@export var snap_distance := 45.0
@export var cockpit_offset := Vector3(0.0, 2.35, -1.9)

enum Mode { CHASE, CHASE_CLOSE, COCKPIT }

var mode: Mode = Mode.CHASE
var orbit := CameraOrbit.new()

var _target: Node3D
var _since_look := 999.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D

	if _target == null:
		push_warning("ChaseCamera: target_path is not set, camera will not follow anything.")

	capture_mouse()


static func capture_mouse() -> void:
	if DisplayServer.get_name() == "headless":
		return

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	handle_input_event(event)


## Public so the headless tests can drive it without a real mouse.
func handle_input_event(event: InputEvent) -> void:
	if event.is_action_pressed("rv_toggle_camera"):
		mode = ((mode + 1) % 3) as Mode
		orbit.reset()
		return

	if event is InputEventMouseMotion:
		orbit.apply_mouse(event.relative, _sensitivity(), Settings.invert_y)
		_since_look = 0.0
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

	_since_look += delta
	if _since_look > auto_recentre_delay and orbit.is_offset():
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

	# The truck's heading gives the base orientation; yaw and pitch ride on top.
	var base := Basis(Vector3.UP, _target.global_rotation.y)
	var view := base * Basis(Vector3.UP, orbit.yaw) * Basis(Vector3.RIGHT, orbit.pitch)

	var desired := _target.global_position + view * Vector3(0.0, 0.0, follow_distance) \
		+ Vector3.UP * follow_height

	if global_position.distance_to(desired) > snap_distance:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, weight)

	look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)


func _sensitivity() -> float:
	if Settings == null:
		return 0.12

	return Settings.mouse_sensitivity


## Test hook: the current view offset as (yaw, pitch).
func orbit_offset() -> Vector2:
	return Vector2(orbit.yaw, orbit.pitch)


## Test hook: how far the camera is from where it wants to be.
func follow_error() -> float:
	return 0.0 if _target == null else global_position.distance_to(_target.global_position)
