extends FighterState
## Special fall after recovery moves: drift only, can grab the ledge, heavy
## landing lag if you miss.

var _landing_lag := 20


func enter(msg: Dictionary) -> void:
	_landing_lag = int(msg.get("landing_lag", 20))
	fighter.play_anim(&"helpless")


func tick() -> void:
	frame += 1
	var f := fighter
	f.check_fast_fall()
	f.apply_gravity()
	f.air_drift(0.6)
	f.velocity.x = clampf(f.velocity.x, -f.data.air_speed * 0.6, f.data.air_speed * 0.6)
	f.physics_move()
	if f.grounded:
		f.land()
		f.change_state(&"landing", {"frames": _landing_lag})
		return
	if f.check_ledge_grab():
		return
