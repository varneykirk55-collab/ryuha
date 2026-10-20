extends FighterState
## Shield broke: popped into the air, then dazed on landing.

var _dazed := false


func enter(_msg: Dictionary) -> void:
	var f := fighter
	_dazed = false
	f.velocity = Vector2(0, -1100)
	f.leave_ground()
	f.play_anim(&"hurt")
	f.flash(Color(1.0, 0.9, 0.3), 1.0)
	f.request_shake(0.4)
	Sfx.play(&"clank", f.global_position)


func tick() -> void:
	frame += 1
	var f := fighter
	if not _dazed:
		f.apply_gravity()
		f.physics_move()
		if f.grounded and frame > 5:
			_dazed = true
			frame = 0
			f.land()
		return
	f.apply_friction()
	f.ground_physics()
	if f.state != self:
		return
	f.flash(Color(1.0, 0.9, 0.3), 0.25 * absf(sin(frame * 0.15)))
	if frame >= Game.config.shield_break_stun_frames:
		f.shield_hp = Game.config.shield_max * 0.6
		f.change_state(&"idle")
