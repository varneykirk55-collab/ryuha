extends FighterState
## KO'd: hidden until the respawn delay passes (or forever if out of stocks).


func enter(_msg: Dictionary) -> void:
	var f := fighter
	f.visible = false
	f.velocity = Vector2.ZERO
	f.kb_velocity = Vector2.ZERO
	f.release_ledge()


func exit() -> void:
	fighter.visible = true


func tick() -> void:
	frame += 1
	var f := fighter
	if f.eliminated:
		return
	if frame >= Game.config.respawn_delay_frames:
		f.change_state(&"respawn")
