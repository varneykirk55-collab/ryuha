extends FighterState
## Running. Attack here gives the dash attack; reversing turns around with a skid.


func enter(_msg: Dictionary) -> void:
	fighter.play_anim(&"run", 1.6)


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
	if absf(s.x) < 0.25:
		f.change_state(&"idle")
		return
	if signf(s.x) != float(f.facing):
		# Skid-turn: lose speed, flip immediately.
		f.velocity.x *= 0.35
		f.turn_to(s.x)
	f.ground_accelerate(f.data.run_speed * f.facing)
	f.play_anim(&"run", 1.6)
	f.ground_physics()


func is_actionable() -> bool:
	return true
