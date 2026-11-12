class_name Gearbox
extends RefCounted
## Pure gearbox model with no engine dependency, so it can be unit tested
## headlessly (see tests/test_gearbox.gd).
##
## Gear index 0 is reverse, 1..N are forward gears. There is no neutral.

const REVERSE := 0


var final_drive: float
var upshift_rpm: float
var downshift_rpm: float

var _ratios: PackedFloat32Array
var _current_gear: int = 1


func _init(
	ratios: PackedFloat32Array,
	final_drive_ratio: float = 3.7,
	up_shift_rpm: float = 2000.0,
	down_shift_rpm: float = 1100.0
) -> void:
	var problem := validate(ratios, final_drive_ratio, up_shift_rpm, down_shift_rpm)
	if problem != "":
		push_error("Gearbox: " + problem)

	_ratios = ratios.duplicate()
	final_drive = final_drive_ratio
	upshift_rpm = up_shift_rpm
	downshift_rpm = down_shift_rpm


static func validate(
	ratios: PackedFloat32Array,
	final_drive_ratio: float,
	up_shift_rpm: float,
	down_shift_rpm: float
) -> String:
	if ratios.size() < 2:
		return "a gearbox needs at least a reverse and one forward gear"

	if final_drive_ratio <= 0.0:
		return "final drive must be positive"

	if down_shift_rpm >= up_shift_rpm:
		return "downshift threshold must be below the upshift threshold"

	for i in ratios.size():
		if absf(ratios[i]) < 0.0001:
			return "gear %d has a zero ratio" % i

	return ""


var current_gear: int:
	get:
		return _current_gear

var top_forward_gear: int:
	get:
		return _ratios.size() - 1

var current_ratio: float:
	get:
		return _ratios[_current_gear]

var is_reverse: bool:
	get:
		return _current_gear == REVERSE


func get_ratios() -> PackedFloat32Array:
	return _ratios.duplicate()


## Engine RPM implied by the current wheel speed and engaged gear.
func engine_rpm(wheel_rpm: float) -> float:
	return absf(wheel_rpm) * final_drive * absf(current_ratio)


func shift_to(gear: int) -> bool:
	if gear < REVERSE or gear > top_forward_gear:
		return false

	_current_gear = gear
	return true


func shift_up() -> bool:
	return shift_to(_current_gear + 1)


func shift_down() -> bool:
	return shift_to(_current_gear - 1)


## Returns +1 on upshift, -1 on downshift, 0 when nothing happened.
## Never drops into reverse on its own.
func update_auto_shift(rpm: float) -> int:
	if rpm > upshift_rpm and _current_gear < top_forward_gear:
		shift_up()
		return 1

	if rpm < downshift_rpm and _current_gear > 1:
		shift_down()
		return -1

	return 0


## Torque delivered to the wheels for a given engine torque.
## The sign comes from the gear ratio itself: reverse ratios are negative, so a
## reverse gear returns negative torque. Never multiply this by a direction
## again, or the two negatives cancel out.
func wheel_torque(engine_torque: float) -> float:
	return engine_torque * current_ratio * final_drive
