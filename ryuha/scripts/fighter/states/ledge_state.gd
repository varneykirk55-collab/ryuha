extends FighterState
## Hanging on a ledge, plus the four ledge options:
##   jump (jump / up on pad), get-up (toward stage / up), roll (shield),
##   attack (attack/special/smash), drop (down / away).
## Grabbing grants intangibility that halves on each regrab without touching
## the ground, so ledge camping is limited.

const LOCKOUT := 8
const ACTION_FRAMES := {&"getup": 26, &"roll": 34, &"attack": 22}

var ledge: Ledge
var phase: StringName = &"hang"
var _action_frame := 0
var _from := Vector2.ZERO
var _to := Vector2.ZERO


func enter(msg: Dictionary) -> void:
	var f := fighter
	ledge = msg["ledge"]
	ledge.occupant = f
	phase = &"hang"
	f.velocity = Vector2.ZERO
	f.kb_velocity = Vector2.ZERO
	f.facing = -ledge.dir
	f.air_jumps_left = f.data.air_jumps
	f.airdodge_used = false
	f.fast_falling = false
	f.move_air_uses.clear()
	var cfg := Game.config
	f.intangible = maxi(f.intangible, int(cfg.ledge_intangibility_frames * pow(0.5, f.ledge_grabs_since_ground)))
	f.ledge_grabs_since_ground += 1
	f.global_position = _hang_pos()
	f.play_anim(&"ledge")


func exit() -> void:
	fighter.release_ledge()


func tick() -> void:
	frame += 1
	var f := fighter
	if phase == &"hang":
		_hang()
		return
	# Climbing / rolling / attacking up onto the stage.
	_action_frame += 1
	var total: int = ACTION_FRAMES[phase]
	var t := clampf(float(_action_frame) / total, 0.0, 1.0)
	# Rise first, then move across.
	var rise := clampf(t * 2.0, 0.0, 1.0)
	var across := clampf(t * 1.6 - 0.4, 0.0, 1.0)
	f.global_position = Vector2(lerpf(_from.x, _to.x, across), lerpf(_from.y, _to.y, rise))
	f.intangible = maxi(f.intangible, 1 if _action_frame < total - 4 else 0)
	if _action_frame >= total:
		f.velocity = Vector2.ZERO
		f.grounded = true
		if phase == &"attack":
			var m := f.data.ledge_attack if f.data.ledge_attack else Game.config.ledge_attack
			if m:
				f.start_move(m)
				return
		if phase == &"roll":
			f.facing = ledge.dir
		f.change_state(&"idle")


func _hang() -> void:
	var f := fighter
	f.global_position = _hang_pos()
	f.play_anim(&"ledge")
	if frame < LOCKOUT:
		return
	var toward := -ledge.dir
	var i := f.input
	if frame >= Game.config.ledge_max_hang_frames:
		_drop()
		return
	if f.buffer.consume(&"jump"):
		f.release_ledge()
		f.velocity = Vector2(toward * 260.0, -f.data.jump_velocity(f.data.full_hop_height * 1.05))
		f.leave_ground()
		Sfx.play(&"jump", f.global_position)
		f.change_state(&"air")
		return
	if f.buffer.consume(&"attack") or f.buffer.consume(&"special") or f.buffer.consume(&"strong"):
		_begin(&"attack", 40.0)
		return
	if f.buffer.consume(&"shield"):
		_begin(&"roll", 190.0)
		return
	if i.tapped.x == toward or i.tapped.y > 0:
		_begin(&"getup", 36.0)
		return
	if i.tapped.y < 0 or i.tapped.x == -toward:
		_drop()


func _begin(action: StringName, inset: float) -> void:
	var f := fighter
	phase = action
	_action_frame = 0
	_from = f.global_position
	_to = ledge.global_position + Vector2(-ledge.dir * (f.data.collision_size.x * 0.5 + inset), 0)
	f.play_anim(&"dodge" if action == &"roll" else &"crouch")


func _drop() -> void:
	var f := fighter
	f.release_ledge()
	f.ledge_cooldown = Game.config.ledge_regrab_cooldown
	f.global_position.x += ledge.dir * 4.0
	f.velocity = Vector2.ZERO
	f.change_state(&"air")


func _hang_pos() -> Vector2:
	var f := fighter
	return ledge.global_position + Vector2(ledge.dir * (f.data.collision_size.x * 0.5 + 6.0), f.data.hurtbox_size.y * 0.6)
