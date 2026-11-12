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
}

## Mouse-bound actions: action name -> button index.
const MOUSE_ACTIONS := {
	"rv_look": MOUSE_BUTTON_RIGHT,
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
