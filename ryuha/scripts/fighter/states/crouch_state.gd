extends FighterState
## Crouching: smaller hurtbox, down-tilt access, platform drop.


func enter(_msg: Dictionary) -> void:
	fighter.play_anim(&"crouch")


func tick() -> void:
	frame += 1
	var f := fighter
	if f.try_ground_actions():
		return
	if f.on_platform and f.input.tapped.y < 0 and frame > 1:
		f.drop_through_platform()
		return
	if f.input.stick.y > -0.5:
		f.change_state(&"idle")
		return
	f.apply_friction(1.5)
	f.ground_physics()


func hurtbox_height_scale() -> float:
	return 0.62


func is_actionable() -> bool:
	return true
