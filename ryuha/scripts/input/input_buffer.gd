class_name InputBuffer
extends RefCounted
## Remembers button presses for a few frames so inputs made slightly early (during
## landing lag, hitstun, the end of another move…) still come out.
## Each press also stores the stick direction at the time of the press, which is
## what decides tilt/smash/aerial direction — this makes buffered moves come out
## in the direction the player actually intended.

var window: int = 7
var _frame: int = 0
var _stamp: Dictionary = {}   # action -> frame pressed
var _dir: Dictionary = {}     # action -> Vector2 stick at press


func push(state: InputState, frame: int) -> void:
	_frame = frame
	for action in InputState.ACTIONS:
		if state.is_pressed(action):
			_stamp[action] = frame
			# A c-stick press carries its own direction.
			_dir[action] = state.cstick if (action == &"strong" and state.cstick.length() > 0.5) else state.stick


func has(action: StringName) -> bool:
	return _frame - int(_stamp.get(action, -100000)) <= window


func consume(action: StringName) -> bool:
	if has(action):
		_stamp[action] = -100000
		return true
	return false


func dir(action: StringName) -> Vector2:
	return _dir.get(action, Vector2.ZERO)


func clear() -> void:
	_stamp.clear()
