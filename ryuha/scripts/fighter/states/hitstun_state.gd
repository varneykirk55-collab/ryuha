extends FighterState
## Being launched. Knockback is applied on the first frame AFTER hitlag so the
## stick position at that moment is used for Directional Influence (DI), as in
## the Smash games. Strong hits tumble: hitting the ground or a wall while
## tumbling either techs (shield pressed within the tech window) or knocks down.

var hit: HitInfo
var stun: int = 0
var tumble: bool = false
var _launched := false


func enter(msg: Dictionary) -> void:
	hit = msg["hit"]
	stun = hit.hitstun_frames
	tumble = hit.knockback >= Game.config.tumble_threshold
	_launched = false
	fighter.velocity = Vector2.ZERO
	fighter.kb_velocity = Vector2.ZERO
	fighter.fast_falling = false
	fighter.play_anim(&"hurt")


func exit() -> void:
	fighter.visual_rotation = 0.0
	fighter.combo_count = 0 if fighter.state_name_next != &"hitstun" else fighter.combo_count


func tick() -> void:
	frame += 1
	var f := fighter
	if not _launched:
		_launch()
	if stun > 0:
		stun -= 1

	# Launch speed decays; the fighter's own gravity keeps working underneath.
	var mag := f.kb_velocity.length()
	if mag > 0.0:
		f.kb_velocity = f.kb_velocity * (maxf(mag - Game.config.launch_decay * Fighter.DT, 0.0) / mag)

	if stun <= 0:
		if not tumble:
			f.kb_velocity = Vector2.ZERO
			f.change_state(&"idle" if f.grounded else &"air")
			return
		# Tumbling: actionable again, but still techs / knocks down on landing.
		if f.try_air_actions():
			return
		f.air_drift()
		f.check_fast_fall()

	f.apply_gravity()
	var vy_before := f.velocity.y + f.kb_velocity.y
	f.physics_move()

	# Tumble visual: lean along the launch.
	if tumble:
		f.visual_rotation = lerpf(f.visual_rotation, clampf(f.kb_velocity.x / 2500.0, -0.6, 0.6), 0.2)

	if f.hit_wall and frame > 1:
		if f.tech_ready():
			_wall_tech()
			return
		f.kb_velocity.x *= -0.5
	if f.hit_ceiling and frame > 1:
		if f.tech_ready():
			_wall_tech()
			return
		f.kb_velocity.y = absf(f.kb_velocity.y) * 0.5

	if f.grounded and frame > 1 and vy_before >= 0.0:
		if tumble:
			if f.tech_ready():
				f.kb_velocity = Vector2.ZERO
				f.land()
				var sx := f.input.stick.x
				if absf(sx) > 0.5:
					f.change_state(&"dodge", {"mode": &"tech_roll", "dir": int(signf(sx))})
				else:
					f.change_state(&"dodge", {"mode": &"tech"})
				Sfx.play(&"tech", f.global_position)
				f.flash(Color(0.7, 0.9, 1.0), 0.8)
				return
			f.kb_velocity = Vector2.ZERO
			f.land()
			f.change_state(&"knockdown")
			return
		# Light hitstun on the ground: slide it out.
		f.kb_velocity.y = 0.0
		f.kb_velocity.x = move_toward(f.kb_velocity.x, 0.0, f.data.ground_friction * Fighter.DT)
		f.velocity.y = 50.0


func _launch() -> void:
	_launched = true
	var f := fighter
	var cfg := Game.config
	var ang := hit.hitbox.angle
	if ang >= 360.5:  # Sakurai angle
		ang = 0.0 if (f.grounded and hit.knockback < 60.0) else 40.0
	var rad := deg_to_rad(ang)
	var d := Vector2(cos(rad) * hit.direction, -sin(rad))

	# Downward hits on grounded targets slide or bounce instead of burying.
	if f.grounded and d.y > 0.05:
		if hit.knockback < cfg.tumble_threshold:
			d = Vector2(signf(d.x) if absf(d.x) > 0.01 else float(hit.direction), 0.0)
		else:
			d.y = -d.y * 0.8
		d = d.normalized()

	# Directional Influence: the stick component perpendicular to the launch
	# rotates the trajectory by up to di_max_degrees.
	var s := f.input.stick
	var sg := Vector2(s.x, -s.y).limit_length(1.0)
	if sg.length() > 0.25:
		var perp := d.rotated(PI * 0.5)
		d = d.rotated(deg_to_rad(cfg.di_max_degrees) * sg.dot(perp))

	hit.launch_angle_deg = rad_to_deg(atan2(-d.y, d.x * hit.direction))
	f.kb_velocity = d * hit.knockback * cfg.launch_speed_per_kb
	f.velocity = Vector2.ZERO
	if f.kb_velocity.y < -1.0:
		f.leave_ground()


func _wall_tech() -> void:
	var f := fighter
	f.kb_velocity = Vector2.ZERO
	f.velocity = Vector2(0, -200)
	f.intangible = maxi(f.intangible, 20)
	Sfx.play(&"tech", f.global_position)
	f.flash(Color(0.7, 0.9, 1.0), 0.8)
	f.change_state(&"air")
