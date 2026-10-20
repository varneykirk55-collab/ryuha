extends FighterState
## Missed tech: lying on the ground. After a short delay choose get-up, get-up
## roll, or get-up attack; otherwise the fighter stands up automatically.

const MIN_FRAMES := 22
const AUTO_GETUP := 110


func enter(_msg: Dictionary) -> void:
	var f := fighter
	f.play_anim(&"knockdown")
	f.visual_rotation = -PI * 0.5 * f.facing
	f.velocity = Vector2(f.velocity.x * 0.3, 50)
	f.request_shake(0.12)
	Sfx.play(&"land", f.global_position)


func exit() -> void:
	fighter.visual_rotation = 0.0


func tick() -> void:
	frame += 1
	var f := fighter
	f.apply_friction(2.0)
	f.ground_physics()
	if f.state != self:
		return
	if frame < MIN_FRAMES:
		return
	var s := f.input.stick
	if f.buffer.consume(&"attack") or f.buffer.consume(&"strong") or f.buffer.consume(&"special"):
		var m := f.data.getup_attack if f.data.getup_attack else Game.config.getup_attack
		if m:
			f.start_move(m, {"intangible": 12})
			return
	if absf(s.x) > 0.6:
		f.change_state(&"dodge", {"mode": &"getup_roll", "dir": int(signf(s.x))})
		return
	if s.y > 0.6 or f.buffer.consume(&"jump") or f.buffer.consume(&"shield") or frame >= AUTO_GETUP:
		f.change_state(&"dodge", {"mode": &"getup"})
