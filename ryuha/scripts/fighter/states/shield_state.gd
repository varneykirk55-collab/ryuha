extends FighterState
## Shielding. The bubble shrinks as it takes damage and while held; if it empties
## the shield breaks. Out of shield: jump, roll, spot dodge, up-smash, up-special.

const DROP_FRAMES := 7

var stun: int = 0
var _drop: int = 0


func enter(_msg: Dictionary) -> void:
	stun = 0
	_drop = 0
	fighter.play_anim(&"shield")


func tick() -> void:
	frame += 1
	var f := fighter
	if stun > 0:
		stun -= 1
		f.apply_friction(0.7)
		f.ground_physics()
		return
	if _drop > 0:
		_drop -= 1
		f.apply_friction()
		f.ground_physics()
		if f.state == self and _drop == 0:
			f.change_state(&"idle")
		return

	f.shield_hp -= Game.config.shield_decay_per_frame
	if f.shield_hp <= 0.0:
		f.change_state(&"shield_break")
		return

	if f.buffer.consume(&"jump"):
		f.change_state(&"jump_squat")
		return
	if f.buffer.has(&"special") and f.buffer.dir(&"special").y > 0.5:
		f.buffer.consume(&"special")
		if f.start_slot(&"up_special"):
			return
	for a in [&"strong", &"attack"]:
		if f.buffer.has(a) and f.buffer.dir(a).y > 0.5:
			f.buffer.consume(a)
			if f.start_slot(&"up_smash"):
				return
	if f.input.tapped.x != 0:
		f.change_state(&"dodge", {"mode": &"roll", "dir": f.input.tapped.x})
		return
	if f.input.tapped.y < 0:
		f.change_state(&"dodge", {"mode": &"spot"})
		return
	if not f.input.is_held(&"shield"):
		_drop = DROP_FRAMES
	f.apply_friction()
	f.ground_physics()


func is_blocking() -> bool:
	return _drop == 0


func is_bubble_visible() -> bool:
	return _drop == 0


## Called by Fighter.receive_hit when the bubble absorbs a hit.
func block(hit: HitInfo) -> void:
	var f := fighter
	f.shield_hp -= hit.damage + hit.hitbox.shield_damage
	stun = int(hit.damage * 0.8 + 2.0)
	f.velocity.x = hit.direction * minf(hit.damage * 45.0, 900.0)
	f.hitstop = Game.config.compute_hitlag(hit.damage, hit.hitbox)
	Sfx.play(&"shield_hit", f.global_position)
	if f.shield_hp <= 0.0:
		f.change_state(&"shield_break")
