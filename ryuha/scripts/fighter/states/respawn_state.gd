extends FighterState
## Revival platform above the stage. Invincible; drops on any input or timeout.


func enter(_msg: Dictionary) -> void:
	var f := fighter
	f.reset_for_respawn()
	f.global_position = f.match_ref.stage.respawn_point(f.port) if f.match_ref else Vector2(0, -500)
	f.velocity = Vector2.ZERO
	f.invincible = Game.config.respawn_invincibility_frames
	f.play_anim(&"idle")
	f.on_respawn_platform = true


func exit() -> void:
	fighter.on_respawn_platform = false


func tick() -> void:
	frame += 1
	var f := fighter
	f.invincible = maxi(f.invincible, Game.config.respawn_invincibility_frames - 30)
	var i := f.input
	var any := i.stick.length() > 0.5
	for a in InputState.ACTIONS:
		if i.is_pressed(a):
			any = true
	if (any and frame > 20) or frame >= Game.config.respawn_platform_max_frames:
		f.invincible = Game.config.respawn_invincibility_frames
		f.buffer.clear()
		f.change_state(&"air")
