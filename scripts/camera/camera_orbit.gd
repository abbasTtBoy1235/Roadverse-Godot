class_name CameraOrbit
extends RefCounted
## Pure orbit state for the chase camera: yaw, pitch and zoom with clamping and
## recentring. No nodes involved, so it is unit tested in tests/test_camera_orbit.gd.

const MIN_PITCH := -0.30
## Positive pitch swings the camera *down* towards the road. At the old 0.95 rad
## limit the camera ended up ~4 m under the ground plane, looking up at the
## underside of the truck; 0.42 keeps a low dramatic angle without burying it.
const MAX_PITCH := 0.42
const MIN_ZOOM := 0.55
const MAX_ZOOM := 1.70

var yaw := 0.0
var pitch := 0.0
var zoom := 1.0


func apply_mouse(relative: Vector2, sensitivity: float, invert_y := false) -> void:
	yaw = wrapf(yaw - relative.x * sensitivity, -PI, PI)

	var sign := 1.0 if invert_y else -1.0
	pitch = clampf(pitch + relative.y * sensitivity * sign, MIN_PITCH, MAX_PITCH)


func apply_zoom(steps: float) -> void:
	zoom = clampf(zoom - steps * 0.08, MIN_ZOOM, MAX_ZOOM)


## Eases yaw and pitch back behind the truck.
func recentre(delta: float, speed: float) -> void:
	var weight := clampf(delta * speed, 0.0, 1.0)
	yaw = lerp_angle(yaw, 0.0, weight)
	pitch = lerpf(pitch, 0.0, weight)


func reset() -> void:
	yaw = 0.0
	pitch = 0.0
	zoom = 1.0


func is_offset() -> bool:
	return absf(yaw) > 0.001 or absf(pitch) > 0.001
