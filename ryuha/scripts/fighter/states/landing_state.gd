extends FighterState
## Landing lag after jumps, aerials and helpless falls.

var _frames := 4


func enter(msg: Dictionary) -> void:
	_frames = maxi(int(msg.get("frames", fighter.data.landing_frames)), 1)
	fighter.play_anim(&"land")
	if _frames > 6:
		fighter.flash(Color(0.2, 0.2, 0.25), 0.25)
	Sfx.play(&"land", fighter.global_position)


func tick() -> void:
	frame += 1
	var f := fighter
	f.apply_friction()
	f.ground_physics()
	if f.state != self:
		return
	if frame >= _frames:
		f.change_state(&"idle")
