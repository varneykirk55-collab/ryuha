extends FighterState
## Airborne and actionable: drift, fast-fall, double jump, aerials, specials,
## air dodge and ledge grabs.


func enter(_msg: Dictionary) -> void:
	fighter.play_anim(&"jump" if fighter.velocity.y < 0.0 else &"fall")


func tick() -> void:
	frame += 1
	var f := fighter
	if f.try_air_actions():
		return
	f.check_fast_fall()
	f.apply_gravity()
	f.air_drift()
	f.physics_move()
	if f.grounded:
		f.land()
		f.change_state(&"landing", {"frames": f.data.landing_frames})
		return
	if f.check_ledge_grab():
		return
	f.play_anim(&"jump" if f.velocity.y < -150.0 else &"fall")


func is_actionable() -> bool:
	return true
