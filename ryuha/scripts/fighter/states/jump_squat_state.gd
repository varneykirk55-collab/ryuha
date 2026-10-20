extends FighterState
## The few frames of crouch before leaving the ground. Releasing jump (or pressing
## an attack) before it ends gives a short hop. Up-special and up-smash can be
## used straight out of jump squat.


func enter(_msg: Dictionary) -> void:
	fighter.play_anim(&"crouch")


func tick() -> void:
	frame += 1
	var f := fighter
	# Out-of-jump-squat options.
	if f.buffer.has(&"special") and f.buffer.dir(&"special").y > 0.5:
		f.buffer.consume(&"special")
		if f.start_slot(&"up_special"):
			return
	if f.buffer.has(&"strong") and f.buffer.dir(&"strong").y > 0.5:
		f.buffer.consume(&"strong")
		if f.start_slot(&"up_smash"):
			return
	f.apply_friction(0.5)
	f.ground_physics()
	if f.state != self:
		return
	if frame >= f.data.jump_squat_frames:
		var attack_queued := f.buffer.has(&"attack") or f.buffer.has(&"strong")
		var full := f.input.is_held(&"jump") and not attack_queued
		f.do_jump(full)
