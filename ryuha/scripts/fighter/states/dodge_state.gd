extends FighterState
## All evasive movement in one data table: rolls, spot dodge, air dodge, techs
## and get-ups. Each mode = duration, intangible window, travel and pose.

const MODES := {
	&"roll":       {"frames": 32, "intangible": Vector2i(4, 18), "distance": 190.0, "move_frames": Vector2i(4, 24), "pose": &"dodge", "turn": true},
	&"spot":       {"frames": 24, "intangible": Vector2i(3, 16), "distance": 0.0, "pose": &"crouch"},
	&"air":        {"frames": 30, "intangible": Vector2i(3, 24), "distance": 0.0, "pose": &"dodge"},
	&"tech":       {"frames": 26, "intangible": Vector2i(1, 20), "distance": 0.0, "pose": &"crouch"},
	&"tech_roll":  {"frames": 38, "intangible": Vector2i(1, 20), "distance": 170.0, "move_frames": Vector2i(2, 26), "pose": &"dodge"},
	&"getup":      {"frames": 28, "intangible": Vector2i(1, 22), "distance": 0.0, "pose": &"crouch"},
	&"getup_roll": {"frames": 36, "intangible": Vector2i(1, 22), "distance": 170.0, "move_frames": Vector2i(4, 28), "pose": &"dodge"},
}
const AIR_DODGE_SPEED := 1250.0
const AIR_DODGE_MOVE_FRAMES := 18
const AIR_DODGE_LANDING_LAG := 10

var mode: StringName = &"spot"
var cfg: Dictionary
var dir: int = 1
var _air_vec := Vector2.ZERO


func enter(msg: Dictionary) -> void:
	var f := fighter
	mode = msg.get("mode", &"spot")
	cfg = MODES[mode]
	dir = int(msg.get("dir", f.facing))
	f.play_anim(cfg["pose"])
	_air_vec = Vector2.ZERO
	if mode == &"air":
		f.airdodge_used = true
		f.fast_falling = false
		var s := f.input.stick
		if s.length() > 0.3:
			_air_vec = Vector2(s.x, -s.y).normalized()
			f.velocity = _air_vec * AIR_DODGE_SPEED
		else:
			f.velocity *= 0.4
	elif mode == &"roll" or mode == &"getup_roll" or mode == &"tech_roll":
		f.velocity.x = 0.0


func tick() -> void:
	frame += 1
	var f := fighter
	var inv: Vector2i = cfg["intangible"]
	if frame >= inv.x and frame <= inv.y:
		f.intangible = maxi(f.intangible, 1)

	if mode == &"air":
		if _air_vec != Vector2.ZERO and frame <= AIR_DODGE_MOVE_FRAMES:
			var t := 1.0 - float(frame) / AIR_DODGE_MOVE_FRAMES
			f.velocity = _air_vec * AIR_DODGE_SPEED * t * t
		else:
			f.apply_gravity()
			f.air_drift(0.6)
		f.physics_move()
		if f.grounded:
			f.land()
			f.change_state(&"landing", {"frames": AIR_DODGE_LANDING_LAG})
			return
		if frame > inv.y and f.check_ledge_grab():
			return
		if frame >= cfg["frames"]:
			f.change_state(&"air")
		return

	# Grounded modes.
	var dist: float = cfg["distance"]
	if dist > 0.0:
		var mf: Vector2i = cfg["move_frames"]
		if frame >= mf.x and frame <= mf.y:
			f.velocity.x = dir * dist / float(mf.y - mf.x + 1) / Fighter.DT
		else:
			f.velocity.x = 0.0
	else:
		f.apply_friction(2.0)
	f.ground_physics()
	if f.state != self:
		return
	if frame >= cfg["frames"]:
		if cfg.get("turn", false):
			f.facing = -dir
		f.change_state(&"idle")
