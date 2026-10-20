class_name InputState
extends RefCounted
## A snapshot of one player's controls for one 60 Hz frame.
##
## Stick convention (gameplay space): +x = right, +y = UP. (Godot's world y is
## down; Fighter converts where needed.)
##
## Actions: jump, attack, special, strong (smash attack), shield.

const ACTIONS: Array[StringName] = [&"jump", &"attack", &"special", &"strong", &"shield"]

var stick: Vector2 = Vector2.ZERO
## Right stick / smash-direction override (zero when unused).
var cstick: Vector2 = Vector2.ZERO
var held: Dictionary = {}
var pressed: Dictionary = {}
## Digital direction freshly entered this frame (x: -1/0/1, y: -1/0/1, +y = up).
## Used for drop-through, fast-fall, dodges and dash starts.
var tapped: Vector2i = Vector2i.ZERO
## True if the stick was smashed (fast flick) recently — turns attack into a smash.
var flicked: bool = false
var pause_pressed: bool = false


func is_held(action: StringName) -> bool:
	return held.get(action, false)


func is_pressed(action: StringName) -> bool:
	return pressed.get(action, false)


func copy_from(o: InputState) -> void:
	stick = o.stick
	cstick = o.cstick
	held = o.held.duplicate()
	pressed = o.pressed.duplicate()
	tapped = o.tapped
	flicked = o.flicked
	pause_pressed = o.pause_pressed
