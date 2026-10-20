extends FighterState
## Walking. Holding full tilt for a moment breaks into a run.

const RUN_AFTER_FRAMES := 10
var _full_tilt_frames := 0


func enter(_msg: Dictionary) -> void:
	_full_tilt_frames = 0
	fighter.play_anim(&"walk")


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
	f.turn_to(s.x)
	_full_tilt_frames = _full_tilt_frames + 1 if absf(s.x) > 0.85 else 0
	if _full_tilt_frames >= RUN_AFTER_FRAMES or (f.input.flicked and absf(s.x) > 0.8):
		f.change_state(&"run")
		return
	f.ground_accelerate(f.data.walk_speed * absf(s.x) * f.facing)
	f.play_anim(&"walk", clampf(absf(f.velocity.x) / maxf(f.data.walk_speed, 1.0), 0.5, 1.2))
	f.ground_physics()


func is_actionable() -> bool:
	return true
