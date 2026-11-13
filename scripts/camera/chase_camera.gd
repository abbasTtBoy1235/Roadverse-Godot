class_name ChaseCamera
extends Camera3D
## Third-person camera with free mouse look.
##
## The mouse is captured while driving, so moving it always rotates the view —
## no modifier key needed. After a moment without mouse movement the camera eases
## back behind the truck. Scroll zooms, middle click recentres, C cycles modes.

@export var target_path: NodePath
@export var distance := 9.5
## High enough to see over the cargo body to the road ahead of the truck.
@export var height := 4.8
@export var look_height := 1.7
@export var smooth := 5.5
@export var recentre_speed := 1.6
## Seconds of no mouse movement before the camera drifts back behind the truck.
@export var auto_recentre_delay := 1.2
## If the camera ever falls further behind than this, snap instead of easing.
@export var snap_distance := 45.0
## The camera may never dip below this height, whatever the orbit asks for.
@export var min_camera_height := 0.5
## Clearance kept behind the back end of the truck itself.
@export var rear_clearance := 4.0
@export var shake_strength := 0.09
@export var impact_shake_threshold := 4.0

var _shake := 0.0
var _last_speed := 0.0
## Driver's eye point in truck space: left seat, up at cab height, just
## behind the windscreen (the model's nose is at model_front_z).
@export var cockpit_offset := Vector3(-0.45, 2.1, -2.2)

enum Mode { CHASE, CHASE_CLOSE, COCKPIT }

var mode: Mode = Mode.CHASE
var orbit := CameraOrbit.new()

var _target: Node3D
var _socket: TruckModel
var _since_look := 999.0


func _ready() -> void:
	_target = get_node_or_null(target_path) as Node3D

	if _target == null:
		push_warning("ChaseCamera: target_path is not set, camera will not follow anything.")
	else:
		# With a real model fitted, the placeholder's seat position is inside the
		# cargo box. Derive the seat from the fitted mesh instead.
		_socket = _target.get_node_or_null("TruckModel") as TruckModel

		if _socket != null and _socket.has_model:
			cockpit_offset = Vector3(
				-0.45,
				clampf(_socket.model_height * 0.62, 1.8, 2.3),
				_socket.model_front_z + 1.25
			)

	# Inside the cab the near plane has to be tight or the dashboard and
	# pillars clip away.
	near = 0.05
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


## Reads the truck's speed each physics frame and turns a sudden stop into a
## camera kick, so a guardrail strike is felt as well as heard.
func _track_impact(delta: float) -> void:
	if _target == null or not ("linear_velocity" in _target):
		return

	var speed: float = Vector3(_target.get("linear_velocity")).length()
	_shake = maxf(_shake, shake_for(speed - _last_speed, impact_shake_threshold))
	_last_speed = speed
	_shake = move_toward(_shake, 0.0, delta * 1.8)


func _process(delta: float) -> void:
	if _target == null:
		return

	_track_impact(delta)

	_since_look += delta
	# In the cab the driver keeps looking where they turned their head;
	# recentring there would fight every junction check.
	if mode != Mode.COCKPIT and _since_look > auto_recentre_delay and orbit.is_offset():
		orbit.recentre(delta, recentre_speed)

	var weight := 1.0 - exp(-smooth * delta)

	if mode == Mode.COCKPIT:
		# Locked to the seat, exactly, every frame: a smoothed follow makes
		# the cab swim around the driver in every bend. The mouse turns the
		# driver's head (clamped, so you cannot stare into the cargo box),
		# and impacts still kick.
		global_position = _target.global_transform * cockpit_offset

		var head := Basis(Vector3.UP, clampf(orbit.yaw, -1.35, 1.35)) \
			* Basis(Vector3.RIGHT, clampf(orbit.pitch, -0.45, 0.30))
		global_basis = _target.global_basis * head

		if _shake > 0.001:
			global_position += global_basis * Vector3(
				sin(Time.get_ticks_msec() * 0.05) * _shake * shake_strength,
				cos(Time.get_ticks_msec() * 0.07) * _shake * shake_strength,
				0.0
			)
		return

	var follow_distance := distance * orbit.zoom
	var follow_height := height * Settings.camera_height
	fov = Settings.camera_fov

	if mode == Mode.CHASE_CLOSE:
		follow_distance *= 0.55
		follow_height *= 0.75

	# The camera has to sit behind the back end of the truck, or it ends up
	# inside the cargo box (near plane inside the mesh, backfaces culled,
	# bodywork looking detached and floating).
	var rear := _rig_rear_z()

	if rear > 0.0:
		follow_distance = maxf(follow_distance, rear + rear_clearance)
		follow_height += maxf(0.0, follow_distance - distance) * 0.12

	# The truck's heading gives the base orientation; yaw and pitch ride on top.
	var base := Basis(Vector3.UP, _target.global_rotation.y)
	var view := base * Basis(Vector3.UP, orbit.yaw) * Basis(Vector3.RIGHT, orbit.pitch)

	var desired := _target.global_position + view * Vector3(0.0, 0.0, follow_distance) \
		+ Vector3.UP * follow_height

	if global_position.distance_to(desired) > snap_distance:
		global_position = desired
	else:
		global_position = global_position.lerp(desired, weight)

	global_position.y = maxf(global_position.y, min_camera_height)

	# A knocked rig shakes the camera: a decaying wobble on both axes.
	if _shake > 0.001:
		var wobble := Vector3(
			sin(Time.get_ticks_msec() * 0.05) * _shake * shake_strength,
			cos(Time.get_ticks_msec() * 0.07) * _shake * shake_strength,
			0.0
		)
		global_position += global_basis * wobble

	look_at(_target.global_position + Vector3.UP * look_height, Vector3.UP)


## Back end of the truck in its own local space (+Z is backwards), from the
## fitted model when there is one. 0 means "no model, use the plain distance".
func _rig_rear_z() -> float:
	if _socket == null or not _socket.has_model:
		return 0.0

	return _socket.model_rear_z


func _sensitivity() -> float:
	if Settings == null:
		return 0.003

	return Settings.mouse_sensitivity


## Camera shake demanded by a sudden change of speed, in m/s.
static func shake_for(delta_speed: float, threshold := 4.0) -> float:
	return clampf((absf(delta_speed) - threshold) * 0.12, 0.0, 1.0)


## Test hook: where the driver's eyes should be right now.
func cockpit_seat_position() -> Vector3:
	return Vector3.ZERO if _target == null else _target.global_transform * cockpit_offset


## Test hook: are we sitting in the cab?
func is_cockpit() -> bool:
	return mode == Mode.COCKPIT


## Test hook: current shake amount, 0..1.
func shake_amount() -> float:
	return _shake


## Test hook: the current view offset as (yaw, pitch).
func orbit_offset() -> Vector2:
	return Vector2(orbit.yaw, orbit.pitch)


## Test hook: how far the camera is from where it wants to be.
func follow_error() -> float:
	return 0.0 if _target == null else global_position.distance_to(_target.global_position)
