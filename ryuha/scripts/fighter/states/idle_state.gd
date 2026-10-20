extends FighterState
## Standing still. Hub for every grounded action.


func enter(_msg: Dictionary) -> void:
	fighter.play_anim(&"idle")


func tick() -> void:
	frame += 1
	var f := fighter
	if f.try_ground_actions():
		return
	var s := f.input.stick
	if f.on_platform and f.input.tapped.y < 0:
		f.drop_through_platform()
		return
	if s.y < -0.6:
		f.change_state(&"crouch")
		return
	if absf(s.x) > 0.25:
		f.turn_to(s.x)
		f.change_state(&"run" if (f.input.flicked and absf(s.x) > 0.8) else &"walk")
		return
	f.apply_friction()
	f.play_anim(&"idle")
	f.ground_physics()


func is_actionable() -> bool:
	return true
