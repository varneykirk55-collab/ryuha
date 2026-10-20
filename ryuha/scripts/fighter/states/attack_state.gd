extends FighterState
## Runs ANY MoveData: grounded normals, aerials, smashes and specials.
## Frame data, hitbox windows, poses, landing rules and chaining all come from the
## resource; special mechanics come from MoveBehavior resources. This is the
## only attack state in the game.
##
## Also acts as the "hit source" for the CombatResolver (can_hit / register_hit /
## hit_direction / on_hit) and exposes `vars` for behaviours' per-use scratch data.

var move: MoveData
var damage_mult: float = 1.0
var knockback_mult: float = 1.0
var charge_frames: int = 0
var charging: bool = false
var vars: Dictionary = {}
var started_airborne: bool = false

var _run_id: int = 0
var _hit_log: Dictionary = {}       # victim instance id -> {group -> frame}
var _swing_played := false
var _trail_spawned := false


func enter(msg: Dictionary) -> void:
	_run_id += 1
	move = msg["move"]
	frame = 0
	damage_mult = float(msg.get("damage_mult", 1.0))
	knockback_mult = 1.0
	charge_frames = 0
	charging = false
	vars = {}
	_hit_log = {}
	_swing_played = false
	_trail_spawned = false
	var f := fighter
	started_airborne = not f.grounded
	if msg.has("intangible"):
		f.intangible = maxi(f.intangible, int(msg["intangible"]))
	if started_airborne and move.air_uses > 0:
		f.move_air_uses[move.id] = int(f.move_air_uses.get(move.id, 0)) + 1
	f.visual_rotation = -deg_to_rad(move.pose_tilt) * f.facing
	f.play_anim(move.pose_startup)
	var id := _run_id
	for b in move.behaviors:
		b.on_start(self)
		if _interrupted(id):
			return


func exit() -> void:
	for b in move.behaviors:
		b.on_end(self)
	charging = false
	fighter.visual_rotation = 0.0


func tick() -> void:
	var f := fighter
	var id := _run_id

	# 1) Advance the move frame unless a behaviour holds it (charging).
	var hold := false
	for b in move.behaviors:
		if b.blocks_frame_advance(self):
			hold = true
	if _interrupted(id):
		return
	if not hold:
		frame += 1
		for b in move.behaviors:
			b.on_frame(self)
			if _interrupted(id):
				return

	# 2) Intangibility windows.
	if move.intangible_frames.y > 0 and frame >= move.intangible_frames.x and frame <= move.intangible_frames.y:
		f.intangible = maxi(f.intangible, 1)

	# 3) Pose for the current phase.
	var first := move.first_active_frame()
	var last := move.last_active_frame()
	if frame < first:
		f.play_anim(move.pose_startup)
	elif frame <= last:
		f.play_anim(move.pose_active)
	else:
		f.play_anim(move.pose_recovery)

	# 4) Hitboxes live this frame.
	if not charging:
		for hb in move.hitboxes:
			var w := hb.get_window(move.startup, move.active)
			if frame >= w.x and frame <= w.y:
				f.active_hitboxes.append({"hb": hb, "source": self})
		if frame >= first and not _swing_played:
			_swing_played = true
			Sfx.play(move.swing_sfx, f.global_position)
		if frame >= first and move.trail_enabled and not _trail_spawned:
			_trail_spawned = true
			f.spawn_trail(move)

	# 5) Physics.
	var was_airborne := not f.grounded
	if f.grounded:
		f.apply_friction(move.friction_scale)
		f.velocity.y = maxf(f.velocity.y, 50.0)
	else:
		f.apply_gravity(move.gravity_scale)
		if move.allow_drift:
			f.air_drift()
		if move.is_aerial:
			f.check_fast_fall()
	f.physics_move()

	# 6) Landing during the move.
	if was_airborne and f.grounded:
		for b in move.behaviors:
			if b.on_land(self):
				return
			if _interrupted(id):
				return
		if move.cancel_on_land:
			var lag := f.data.landing_frames
			if move.is_aerial and frame <= last + 2:
				lag = move.landing_lag
			elif not move.is_aerial:
				lag = move.helpless_landing_lag if move.ends_in_helpless else move.landing_lag
			f.land()
			f.change_state(&"landing", {"frames": lag})
			return
		f.land()

	# 7) Recovery moves may snap to the ledge.
	if move.ledge_grab_from_frame > 0 and frame >= move.ledge_grab_from_frame and not f.grounded:
		if f.check_ledge_grab(true):
			return

	# 8) Chains (jab combos).
	if move.next_on_attack != null and move.chain_from_frame > 0 and frame >= move.chain_from_frame:
		if f.buffer.consume(&"attack"):
			f.start_move(move.next_on_attack)
			return

	# 9) End of move.
	if frame >= move.total_frames():
		if f.grounded:
			f.change_state(&"idle")
		elif move.ends_in_helpless:
			f.change_state(&"helpless", {"landing_lag": move.helpless_landing_lag})
		else:
			f.change_state(&"air")


func on_hurt(hit: HitInfo) -> bool:
	for b in move.behaviors:
		if b.on_hurt(self, hit):
			return true
	return false


func charge_ratio() -> float:
	return clampf(float(charge_frames) / float(vars.get("charge_max", 1)), 0.0, 1.0)


func _interrupted(id: int) -> bool:
	return fighter.state != self or _run_id != id


# --- Hit-source interface used by CombatResolver ------------------------------

func can_hit(victim: Node, hb: HitboxData) -> bool:
	var log: Dictionary = _hit_log.get(victim.get_instance_id(), {})
	if not log.has(hb.group):
		return true
	return hb.rehit_rate > 0 and frame - int(log[hb.group]) >= hb.rehit_rate


func register_hit(victim: Node, hb: HitboxData) -> void:
	var key := victim.get_instance_id()
	if not _hit_log.has(key):
		_hit_log[key] = {}
	_hit_log[key][hb.group] = frame


func hit_origin() -> Vector2:
	return fighter.global_position


func hit_facing() -> int:
	return fighter.facing


func hit_direction(victim: Node, hb: HitboxData) -> int:
	if hb.hit_away_from_center:
		var dx: float = victim.global_position.x - fighter.global_position.x
		if absf(dx) > 1.0:
			return 1 if dx > 0.0 else -1
	return fighter.facing


func on_hit(victim: Node, hit: HitInfo) -> void:
	for b in move.behaviors:
		b.on_hit(self, victim, hit)


func is_ground_move() -> bool:
	return not move.is_aerial and fighter.grounded
