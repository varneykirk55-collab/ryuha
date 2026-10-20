class_name DeviceInput
extends InputSource
## Reads a keyboard scheme or a specific gamepad and produces InputState frames.
## Reads raw devices (not the InputMap) so two players never steal each other's
## gamepad and schemes can be swapped at runtime.

const FLICK_WINDOW := 3        ## frames a stick flick counts as a "smash" input
const TAP_THRESHOLD := 0.6
const DEADZONE := 0.22

var scheme: Dictionary
var tap_jump: bool = false

var _prev_held: Dictionary = {}
var _prev_stick := Vector2.ZERO
var _prev_c := Vector2.ZERO
var _prev_pause := false
var _flick_age := 99


func _init(scheme_id: StringName, use_tap_jump: Variant = null) -> void:
	scheme = ControlSchemes.find(scheme_id)
	# Tap-jump (up on the stick jumps) defaults on for pads, off for keyboards so
	# W + attack can up-tilt.
	tap_jump = (scheme["kind"] == ControlSchemes.Kind.GAMEPAD) if use_tap_jump == null else bool(use_tap_jump)


func display_name() -> String:
	return scheme["name"]


func poll(_fighter) -> InputState:
	var s := InputState.new()
	var held := {}
	var stick := Vector2.ZERO
	var c := Vector2.ZERO
	var pause := false

	if scheme["kind"] == ControlSchemes.Kind.KEYBOARD:
		var k: Dictionary = scheme["keys"]
		stick.x = float(_any(k["right"])) - float(_any(k["left"]))
		stick.y = float(_any(k["up"])) - float(_any(k["down"]))
		for action in InputState.ACTIONS:
			held[action] = _any(k[String(action)])
		pause = _any(k["pause"])
	else:
		var d: int = scheme["device"]
		var ax := Vector2(Input.get_joy_axis(d, JOY_AXIS_LEFT_X), -Input.get_joy_axis(d, JOY_AXIS_LEFT_Y))
		if ax.length() < DEADZONE:
			ax = Vector2.ZERO
		var dpad := Vector2(
			float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_RIGHT)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_LEFT)),
			float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_UP)) - float(Input.is_joy_button_pressed(d, JOY_BUTTON_DPAD_DOWN)))
		stick = dpad if dpad != Vector2.ZERO else ax.limit_length(1.0)
		c = Vector2(Input.get_joy_axis(d, JOY_AXIS_RIGHT_X), -Input.get_joy_axis(d, JOY_AXIS_RIGHT_Y))
		c = _cardinal(c) if c.length() > 0.5 else Vector2.ZERO
		held[&"attack"] = Input.is_joy_button_pressed(d, JOY_BUTTON_A)
		held[&"special"] = Input.is_joy_button_pressed(d, JOY_BUTTON_B)
		held[&"jump"] = Input.is_joy_button_pressed(d, JOY_BUTTON_X) or Input.is_joy_button_pressed(d, JOY_BUTTON_Y)
		held[&"shield"] = Input.is_joy_button_pressed(d, JOY_BUTTON_LEFT_SHOULDER) \
			or Input.is_joy_button_pressed(d, JOY_BUTTON_RIGHT_SHOULDER) \
			or Input.get_joy_axis(d, JOY_AXIS_TRIGGER_LEFT) > 0.5 \
			or Input.get_joy_axis(d, JOY_AXIS_TRIGGER_RIGHT) > 0.5
		held[&"strong"] = c != Vector2.ZERO
		pause = Input.is_joy_button_pressed(d, JOY_BUTTON_START)
		# Flick detection: stick went from near-neutral to the rim very quickly.
		if (absf(stick.x) > 0.8 and absf(_prev_stick.x) < 0.3) or (absf(stick.y) > 0.8 and absf(_prev_stick.y) < 0.3):
			_flick_age = 0

	if tap_jump and stick.y > 0.66:
		held[&"jump"] = true

	for action in InputState.ACTIONS:
		s.pressed[action] = held.get(action, false) and not _prev_held.get(action, false)
	if c != Vector2.ZERO and _prev_c == Vector2.ZERO:
		s.pressed[&"strong"] = true

	s.flicked = _flick_age <= FLICK_WINDOW
	if s.flicked and s.pressed[&"attack"]:
		s.pressed[&"attack"] = false
		s.pressed[&"strong"] = true
	_flick_age += 1

	var cur := _digital(stick)
	var prev := _digital(_prev_stick)
	s.tapped = Vector2i(cur.x if cur.x != prev.x else 0, cur.y if cur.y != prev.y else 0)

	s.stick = stick
	s.cstick = c
	s.held = held
	s.pause_pressed = pause and not _prev_pause

	_prev_held = held
	_prev_stick = stick
	_prev_c = c
	_prev_pause = pause
	state = s
	return s


static func _any(keys: Array) -> bool:
	for key in keys:
		if Input.is_physical_key_pressed(key):
			return true
	return false


static func _digital(v: Vector2) -> Vector2i:
	return Vector2i(
		(1 if v.x > TAP_THRESHOLD else (-1 if v.x < -TAP_THRESHOLD else 0)),
		(1 if v.y > TAP_THRESHOLD else (-1 if v.y < -TAP_THRESHOLD else 0)))


static func _cardinal(v: Vector2) -> Vector2:
	if absf(v.x) >= absf(v.y):
		return Vector2(signf(v.x), 0)
	return Vector2(0, signf(v.y))
