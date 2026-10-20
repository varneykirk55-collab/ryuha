class_name ControlSchemes
extends RefCounted
## Built-in control schemes. Keys are *physical* keycodes (layout independent).
## Add or remap schemes here; menus list them automatically.

enum Kind { KEYBOARD, GAMEPAD }


static func all() -> Array[Dictionary]:
	var list: Array[Dictionary] = [
		{
			"id": &"kb_solo", "name": "Keyboard (solo) WASD+JKL", "kind": Kind.KEYBOARD,
			"keys": {
				"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
				"jump": [KEY_SPACE], "attack": [KEY_J], "special": [KEY_K],
				"shield": [KEY_L, KEY_SEMICOLON], "strong": [KEY_I], "pause": [KEY_ESCAPE],
			},
			"help": "Move WASD · Jump Space · Attack J · Special K · Shield L · Smash I · Pause Esc",
		},
		{
			"id": &"kb_left", "name": "Keyboard L: WASD+FGH", "kind": Kind.KEYBOARD,
			"keys": {
				"left": [KEY_A], "right": [KEY_D], "up": [KEY_W], "down": [KEY_S],
				"jump": [KEY_SPACE], "attack": [KEY_F], "special": [KEY_G],
				"shield": [KEY_R], "strong": [KEY_H], "pause": [KEY_ESCAPE],
			},
			"help": "Move WASD · Jump Space · Attack F · Special G · Shield R · Smash H · Pause Esc",
		},
		{
			"id": &"kb_right", "name": "Keyboard R: Arrows+Numpad", "kind": Kind.KEYBOARD,
			"keys": {
				"left": [KEY_LEFT], "right": [KEY_RIGHT], "up": [KEY_UP], "down": [KEY_DOWN],
				"jump": [KEY_KP_0, KEY_M], "attack": [KEY_KP_1, KEY_COMMA], "special": [KEY_KP_2, KEY_PERIOD],
				"shield": [KEY_KP_ENTER, KEY_APOSTROPHE], "strong": [KEY_KP_3, KEY_SLASH],
				"pause": [KEY_BACKSPACE, KEY_KP_ADD],
			},
			"help": "Move Arrows · Jump Num0/M · Attack Num1/, · Special Num2/. · Shield NumEnter/' · Smash Num3// · Pause Backspace",
		},
	]
	for i in 4:
		list.append({
			"id": StringName("pad_%d" % i), "name": "Gamepad %d" % (i + 1), "kind": Kind.GAMEPAD, "device": i,
			"help": "Stick/D-pad move · A attack · B special · X/Y jump · LB/RB/triggers shield · Right stick smash · Start pause",
		})
	return list


static func find(id: StringName) -> Dictionary:
	for s in all():
		if s["id"] == id:
			return s
	return all()[0]


static func index_of(id: StringName) -> int:
	var list := all()
	for i in list.size():
		if list[i]["id"] == id:
			return i
	return 0
