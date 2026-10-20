extends FighterState
## Clank recoil when two grounded attacks collide.

const FRAMES := 16


func enter(_msg: Dictionary) -> void:
	fighter.velocity.x = -fighter.facing * 320.0
	fighter.play_anim(&"attack_recovery")


func tick() -> void:
	frame += 1
	var f := fighter
	if f.grounded:
		f.apply_friction()
		f.ground_physics()
	else:
		f.apply_gravity()
		f.physics_move()
	if f.state == self and frame >= FRAMES:
		f.change_state(&"idle" if f.grounded else &"air")
