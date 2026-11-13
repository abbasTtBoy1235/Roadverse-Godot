extends Node
## Registers the game's input actions at runtime.
##
## Actions live here instead of project.godot because the serialised InputEvent
## format in project.godot is painful to review in a diff. Everything is
## idempotent, so it is safe to call from an autoload and from headless tests.

const ACTIONS := {
	"rv_throttle": [KEY_W, KEY_UP],
	"rv_brake": [KEY_S, KEY_DOWN],
	"rv_steer_left": [KEY_A, KEY_LEFT],
	"rv_steer_right": [KEY_D, KEY_RIGHT],
	"rv_handbrake": [KEY_SPACE],
	"rv_shift_up": [KEY_E],
	"rv_shift_down": [KEY_Q],
	"rv_toggle_headlights": [KEY_L],
	"rv_toggle_camera": [KEY_C],
	"rv_restart": [KEY_R],
	"rv_pause": [KEY_ESCAPE],
	"rv_weather": [KEY_F],
	"rv_next_job": [KEY_ENTER, KEY_KP_ENTER],
}

## Mouse-bound actions: action name -> button index.
const MOUSE_ACTIONS := {
	"rv_look": MOUSE_BUTTON_RIGHT,
}

## Gamepad bindings: action name -> [buttons], and the two analogue axes.
const PAD_BUTTONS := {
	"rv_handbrake": [JOY_BUTTON_A],
	"rv_shift_up": [JOY_BUTTON_RIGHT_SHOULDER],
	"rv_shift_down": [JOY_BUTTON_LEFT_SHOULDER],
	"rv_toggle_headlights": [JOY_BUTTON_Y],
	"rv_toggle_camera": [JOY_BUTTON_X],
	"rv_restart": [JOY_BUTTON_BACK],
	"rv_pause": [JOY_BUTTON_START],
	"rv_next_job": [JOY_BUTTON_A],
}

## action -> (axis, direction): the stick steers, the triggers pedal.
const PAD_AXES := {
	"rv_steer_left": [JOY_AXIS_LEFT_X, -1.0],
	"rv_steer_right": [JOY_AXIS_LEFT_X, 1.0],
	"rv_throttle": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
	"rv_brake": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}


func _ready() -> void:
	ensure_registered()


static func ensure_registered() -> void:
	for action_name: String in MOUSE_ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name)

		var wanted: int = MOUSE_ACTIONS[action_name]
		var present := false
		for event: InputEvent in InputMap.action_get_events(action_name):
			if event is InputEventMouseButton and event.button_index == wanted:
				present = true
				break

		if present:
			continue

		var mouse_event := InputEventMouseButton.new()
		mouse_event.button_index = wanted
		InputMap.action_add_event(action_name, mouse_event)

	for action_name: String in PAD_BUTTONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)

		for button: JoyButton in PAD_BUTTONS[action_name]:
			var present := false

			for event: InputEvent in InputMap.action_get_events(action_name):
				if event is InputEventJoypadButton and event.button_index == button:
					present = true
					break

			if present:
				continue

			var pad_event := InputEventJoypadButton.new()
			pad_event.button_index = button
			InputMap.action_add_event(action_name, pad_event)

	for action_name: String in PAD_AXES:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)

		var spec: Array = PAD_AXES[action_name]
		var present := false

		for event: InputEvent in InputMap.action_get_events(action_name):
			if event is InputEventJoypadMotion and event.axis == (spec[0] as JoyAxis) and is_equal_approx(event.axis_value, float(spec[1])):
				present = true
				break

		if present:
			continue

		var axis_event := InputEventJoypadMotion.new()
		axis_event.axis = spec[0] as JoyAxis
		axis_event.axis_value = float(spec[1])
		InputMap.action_add_event(action_name, axis_event)

	for action_name: String in ACTIONS:
		if not InputMap.has_action(action_name):
			InputMap.add_action(action_name, 0.2)

		for keycode: Key in ACTIONS[action_name]:
			var already_bound := false
			for event: InputEvent in InputMap.action_get_events(action_name):
				if event is InputEventKey and event.physical_keycode == keycode:
					already_bound = true
					break

			if already_bound:
				continue

			var key_event := InputEventKey.new()
			key_event.physical_keycode = keycode
			InputMap.action_add_event(action_name, key_event)
