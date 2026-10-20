class_name Fighter
extends CharacterBody2D
## The one and only fighter controller. Movement, defence and attacks are driven
## by CharacterData + MoveData resources; per-state logic lives in small
## FighterState objects (scripts/fighter/states/). Nothing in here knows which
## character it is playing.
##
## The Match calls tick() once per 60 Hz game frame — fighters don't use
## _physics_process themselves, so update order, hitstop and slow motion are
## fully deterministic.
##
## World conventions: origin = feet, Godot y-down. Input sticks use y-UP.

signal percent_changed(fighter: Fighter)
signal stocks_changed(fighter: Fighter)
signal knocked_out(fighter: Fighter)

enum HitResult { HIT, SHIELDED, ABSORBED }

const DT := 1.0 / 60.0
const PLATFORM_LAYER := 2

const STATES := {
	&"idle": preload("res://scripts/fighter/states/idle_state.gd"),
	&"walk": preload("res://scripts/fighter/states/walk_state.gd"),
	&"run": preload("res://scripts/fighter/states/run_state.gd"),
	&"crouch": preload("res://scripts/fighter/states/crouch_state.gd"),
	&"jump_squat": preload("res://scripts/fighter/states/jump_squat_state.gd"),
	&"air": preload("res://scripts/fighter/states/air_state.gd"),
	&"landing": preload("res://scripts/fighter/states/landing_state.gd"),
	&"attack": preload("res://scripts/fighter/states/attack_state.gd"),
	&"hitstun": preload("res://scripts/fighter/states/hitstun_state.gd"),
	&"knockdown": preload("res://scripts/fighter/states/knockdown_state.gd"),
	&"dodge": preload("res://scripts/fighter/states/dodge_state.gd"),
	&"shield": preload("res://scripts/fighter/states/shield_state.gd"),
	&"shield_break": preload("res://scripts/fighter/states/shield_break_state.gd"),
	&"ledge": preload("res://scripts/fighter/states/ledge_state.gd"),
	&"helpless": preload("res://scripts/fighter/states/helpless_state.gd"),
	&"rebound": preload("res://scripts/fighter/states/rebound_state.gd"),
	&"dead": preload("res://scripts/fighter/states/dead_state.gd"),
	&"respawn": preload("res://scripts/fighter/states/respawn_state.gd"),
}

## Animation fallbacks: if a SpriteFrames lacks an animation, use the next one.
## Add e.g. a "crouch" animation to a character's SpriteFrames and it is used
## automatically — no code changes.
const ANIM_FALLBACKS := {
	&"run": &"walk", &"crouch": &"attack_startup", &"land": &"attack_recovery",
	&"ledge": &"fall", &"helpless": &"fall", &"shield": &"idle", &"dodge": &"jump",
	&"knockdown": &"hurt", &"fall": &"jump", &"jump": &"idle", &"hurt": &"idle",
	&"attack_startup": &"idle", &"attack_active": &"attack_startup", &"attack_recovery": &"idle",
	&"walk": &"idle",
}

@export var data: CharacterData

var port: int = 0
var port_color: Color = Color.WHITE
var input_source: InputSource
var input: InputState = InputState.new()
var buffer: InputBuffer = InputBuffer.new()
var match_ref: Node      # the Match; provides stage, projectiles, effects

var facing: int = 1
var kb_velocity: Vector2 = Vector2.ZERO
var percent: float = 0.0
var stocks: int = 3
var infinite_stocks: bool = false
var eliminated: bool = false

var air_jumps_left: int = 1
var airdodge_used: bool = false
var fast_falling: bool = false
var move_air_uses: Dictionary = {}
var hitstop: int = 0
var intangible: int = 0
var invincible: int = 0
var shield_hp: float = 50.0
var ledge_cooldown: int = 0
var ledge_grabs_since_ground: int = 0
var on_respawn_platform: bool = false
var frozen: bool = false   ## intro countdown / round end

# Collision results from the last physics_move().
var grounded: bool = false
var on_platform: bool = false
var hit_wall: bool = false
var hit_ceiling: bool = false

var combo_count: int = 0
var last_hit_taken: HitInfo
var active_hitboxes: Array = []   ## [{hb: HitboxData, source: Object}] this frame

var state: FighterState
var state_name: StringName = &""
var state_name_next: StringName = &""
var states: Dictionary = {}
var game_frame: int = 0
var visual_rotation: float = 0.0

var _drop_frames: int = 0
var _tech_press_frame: int = -1000
var _tech_lock_until: int = -1000
var _anim: StringName = &""
var _anim_ticks: float = 0.0
var _anim_speed: float = 1.0
var _flash_amount: float = 0.0
var _shadow: Node2D

@onready var visual: Node2D = $Visual
@onready var body: Node2D = $Visual/Body
@onready var sprite: AnimatedSprite2D = $Visual/Body/Sprite
@onready var collision: CollisionShape2D = $Collision
@onready var overlay: Node2D = $Overlay


func _ready() -> void:
	collision_layer = 0
	collision_mask = 0b11
	up_direction = Vector2.UP
	floor_snap_length = 12.0
	floor_max_angle = deg_to_rad(50)
	for key in STATES:
		var s: FighterState = STATES[key].new()
		s.fighter = self
		s.state_name = key
		states[key] = s
	if data:
		_apply_data()


## Called by the Match after instancing.
func setup(p_data: CharacterData, p_port: int, p_input: InputSource, p_match: Node, tint: Color = Color.WHITE) -> void:
	data = p_data
	port = p_port
	input_source = p_input
	match_ref = p_match
	port_color = [Color(0.92, 0.27, 0.25), Color(0.27, 0.55, 0.95), Color(0.3, 0.8, 0.4), Color(0.95, 0.8, 0.25)][port % 4]
	buffer.window = Game.config.buffer_frames
	if is_node_ready():
		_apply_data()
	var mat := sprite.material as ShaderMaterial
	mat.set_shader_parameter(&"tint", tint)
	mat.set_shader_parameter(&"outline_color", Color(port_color.r, port_color.g, port_color.b, 0.85))
	# Outline thickness is in texture pixels; keep it ~2.5 world px regardless of sprite scale.
	mat.set_shader_parameter(&"outline_px", 2.5 / maxf(data.sprite_scale, 0.1))


func _apply_data() -> void:
	sprite.sprite_frames = data.sprite_frames
	sprite.centered = false
	sprite.offset = -data.sprite_foot
	sprite.stop()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/fighter_flash.gdshader")
	sprite.material = mat
	var rect := RectangleShape2D.new()
	rect.size = data.collision_size
	collision.shape = rect
	collision.position = Vector2(0, -data.collision_size.y * 0.5)
	if _shadow == null:
		# Soft contact shadow, drawn behind the sprite: grounds the fighter visually.
		_shadow = Node2D.new()
		_shadow.name = "Shadow"
		add_child(_shadow)
		move_child(_shadow, 0)
		_shadow.draw.connect(func():
			var w := data.hurtbox_size.x * 1.1
			_shadow.draw_set_transform(Vector2(0, 2), 0.0, Vector2(1.0, 0.22))
			_shadow.draw_circle(Vector2.ZERO, w, Color(0, 0, 0, 0.32))
			_shadow.draw_circle(Vector2.ZERO, w * 0.6, Color(0, 0, 0, 0.25)))
	reset_for_round(Vector2.ZERO, 1)


# --- Round / stock lifecycle ---------------------------------------------------

func reset_for_round(pos: Vector2, face: int) -> void:
	global_position = pos
	facing = face
	percent = 0.0
	eliminated = false
	visible = true
	hitstop = 0
	invincible = 0
	intangible = 0
	combo_count = 0
	shield_hp = Game.config.shield_max
	_reset_movement()
	change_state(&"idle")
	percent_changed.emit(self)
	stocks_changed.emit(self)


func reset_for_respawn() -> void:
	percent = 0.0
	shield_hp = Game.config.shield_max
	_reset_movement()
	percent_changed.emit(self)


func _reset_movement() -> void:
	velocity = Vector2.ZERO
	kb_velocity = Vector2.ZERO
	air_jumps_left = data.air_jumps
	airdodge_used = false
	fast_falling = false
	move_air_uses.clear()
	ledge_grabs_since_ground = 0
	ledge_cooldown = 0
	buffer.clear()
	_set_drop_through(false)


func ko() -> void:
	if state_name == &"dead":
		return
	if not infinite_stocks:
		stocks -= 1
		if stocks <= 0:
			stocks = 0
			eliminated = true
	stocks_changed.emit(self)
	knocked_out.emit(self)
	change_state(&"dead")


# --- Per-frame entry point (called by Match) ------------------------------------

func tick(frame_no: int) -> void:
	game_frame = frame_no
	input = input_source.poll(self) if input_source else InputState.new()
	buffer.push(input, frame_no)
	if input.is_pressed(&"shield") and not grounded:
		_register_tech_press()

	if frozen:
		_update_visuals(false)
		return

	if hitstop > 0:
		hitstop -= 1
		_update_visuals(true)
		return

	if intangible > 0:
		intangible -= 1
	if invincible > 0:
		invincible -= 1
	if ledge_cooldown > 0:
		ledge_cooldown -= 1
	if _drop_frames > 0:
		_drop_frames -= 1
		if _drop_frames == 0:
			_set_drop_through(false)
	if state_name != &"shield":
		shield_hp = minf(shield_hp + Game.config.shield_regen_per_frame, Game.config.shield_max)

	active_hitboxes.clear()
	state.tick()
	_update_visuals(false)


func change_state(new_name: StringName, msg: Dictionary = {}) -> void:
	state_name_next = new_name
	if state:
		state.exit()
	active_hitboxes.clear()
	visual_rotation = 0.0
	state = states[new_name]
	state_name = new_name
	state.frame = 0
	state.enter(msg)


# --- Movement helpers used by states ------------------------------------------

func is_grounded() -> bool:
	return grounded


func leave_ground() -> void:
	grounded = false
	on_platform = false


func ground_physics() -> void:
	## Standard grounded update: stick to the floor, fall if we walked off.
	velocity.y = 60.0
	physics_move()
	if not grounded and state_name != &"dead":
		change_state(&"air")


func physics_move() -> void:
	var own := velocity
	velocity = own + kb_velocity
	move_and_slide()
	grounded = is_on_floor()
	hit_wall = is_on_wall()
	hit_ceiling = is_on_ceiling()
	on_platform = false
	if grounded:
		for i in get_slide_collision_count():
			var col := get_slide_collision(i)
			var c := col.get_collider()
			if c is Node and (c as Node).is_in_group(&"platform") and col.get_normal().y < -0.5:
				on_platform = true
	velocity = own
	if grounded and velocity.y > 0.0:
		velocity.y = 0.0
	if hit_ceiling and velocity.y < 0.0:
		velocity.y = 0.0
	if hit_wall:
		velocity.x = 0.0


func apply_gravity(scale: float = 1.0) -> void:
	if fast_falling:
		velocity.y = data.fast_fall_speed
		return
	velocity.y = minf(velocity.y + data.gravity * scale * DT, data.max_fall_speed)


func air_drift(mult: float = 1.0) -> void:
	var sx := input.stick.x
	if absf(sx) < 0.2:
		velocity.x = move_toward(velocity.x, 0.0, data.air_friction * DT)
	else:
		velocity.x = move_toward(velocity.x, sx * data.air_speed * mult, data.air_accel * DT)


func ground_accelerate(target_speed: float) -> void:
	velocity.x = move_toward(velocity.x, target_speed, data.ground_accel * DT)


func apply_friction(scale: float = 1.0) -> void:
	velocity.x = move_toward(velocity.x, 0.0, data.ground_friction * scale * DT)


func check_fast_fall() -> void:
	if not fast_falling and velocity.y > -120.0 and input.tapped.y < 0:
		fast_falling = true
		flash(Color.WHITE, 0.35)


func turn_to(x: float) -> void:
	if x > 0.2:
		facing = 1
	elif x < -0.2:
		facing = -1


func land() -> void:
	grounded = true
	fast_falling = false
	air_jumps_left = data.air_jumps
	airdodge_used = false
	move_air_uses.clear()
	ledge_grabs_since_ground = 0
	kb_velocity = Vector2.ZERO


func do_jump(full: bool) -> void:
	var h := data.full_hop_height if full else data.short_hop_height
	velocity.y = -data.jump_velocity(h)
	velocity.x = clampf(velocity.x * 0.85 + input.stick.x * data.air_speed * 0.35, -data.air_speed * 1.1, data.air_speed * 1.1)
	leave_ground()
	Sfx.play(&"jump", global_position)
	change_state(&"air")


func double_jump() -> void:
	air_jumps_left -= 1
	fast_falling = false
	velocity.y = -data.jump_velocity(data.double_jump_height)
	velocity.x = input.stick.x * data.air_speed
	flash(Color.WHITE, 0.3)
	Sfx.play(&"jump", global_position)
	change_state(&"air")


func drop_through_platform() -> void:
	_set_drop_through(true)
	_drop_frames = 14
	leave_ground()
	global_position.y += 4.0
	velocity.y = 200.0
	change_state(&"air")


func _set_drop_through(on: bool) -> void:
	set_collision_mask_value(PLATFORM_LAYER, not on)
	if not on:
		_drop_frames = 0


# --- Action dispatch (shared by all actionable states) --------------------------

func try_ground_actions() -> bool:
	if buffer.has(&"special"):
		var d := buffer.dir(&"special")
		buffer.consume(&"special")
		if start_special(d):
			return true
	if buffer.has(&"strong"):
		var d := buffer.dir(&"strong")
		buffer.consume(&"strong")
		if start_smash(d):
			return true
	if buffer.has(&"attack"):
		var d := buffer.dir(&"attack")
		buffer.consume(&"attack")
		if start_ground_attack(d):
			return true
	if buffer.consume(&"jump"):
		change_state(&"jump_squat")
		return true
	var fresh_shield := buffer.consume(&"shield")
	if fresh_shield or input.is_held(&"shield"):
		var s := input.stick
		if fresh_shield and absf(s.x) > 0.6:
			change_state(&"dodge", {"mode": &"roll", "dir": int(signf(s.x))})
		elif fresh_shield and s.y < -0.6:
			change_state(&"dodge", {"mode": &"spot"})
		else:
			change_state(&"shield")
		return true
	return false


func try_air_actions() -> bool:
	if buffer.has(&"special"):
		var d := buffer.dir(&"special")
		buffer.consume(&"special")
		if start_special(d):
			return true
	for a in [&"strong", &"attack"]:
		if buffer.has(a):
			var d := buffer.dir(a)
			buffer.consume(a)
			if start_aerial(d):
				return true
	if buffer.has(&"jump") and air_jumps_left > 0:
		buffer.consume(&"jump")
		double_jump()
		return true
	if buffer.has(&"shield") and not airdodge_used:
		buffer.consume(&"shield")
		change_state(&"dodge", {"mode": &"air"})
		return true
	return false


func start_ground_attack(d: Vector2) -> bool:
	if state_name == &"run" and absf(d.y) < 0.5:
		return start_slot(&"dash_attack")
	if d.y > 0.5:
		return start_slot(&"up_tilt")
	if d.y < -0.5:
		return start_slot(&"down_tilt")
	if absf(d.x) > 0.3:
		turn_to(d.x)
		return start_slot(&"forward_tilt")
	return start_slot(&"jab")


func start_smash(d: Vector2) -> bool:
	if d.y > 0.5 and absf(d.y) >= absf(d.x):
		return start_slot(&"up_smash")
	if d.y < -0.5 and absf(d.y) >= absf(d.x):
		return start_slot(&"down_smash")
	turn_to(d.x)
	return start_slot(&"forward_smash")


func start_aerial(d: Vector2) -> bool:
	var rel := d.x * facing
	if d.y > 0.5 and absf(d.y) >= absf(d.x):
		return start_slot(&"up_air")
	if d.y < -0.5 and absf(d.y) >= absf(d.x):
		return start_slot(&"down_air")
	if rel > 0.3:
		return start_slot(&"forward_air")
	if rel < -0.3:
		return start_slot(&"back_air")
	return start_slot(&"neutral_air")


func start_special(d: Vector2) -> bool:
	var slot := &"neutral_special"
	if d.y > 0.5 and absf(d.y) >= absf(d.x):
		slot = &"up_special"
	elif d.y < -0.5 and absf(d.y) >= absf(d.x):
		slot = &"down_special"
	elif absf(d.x) > 0.3:
		slot = &"side_special"
	var airborne := not grounded
	var move: MoveData = null
	if airborne and slot != &"up_special":
		move = data.get_move(StringName(String(slot) + "_air"))
	if move == null:
		move = data.get_move(slot)
	if move == null or (airborne and move.grounded_only):
		return false
	if airborne and move.air_uses > 0 and int(move_air_uses.get(move.id, 0)) >= move.air_uses:
		return false
	if slot == &"side_special":
		turn_to(d.x)
	start_move(move)
	return true


func start_slot(slot: StringName) -> bool:
	var move := data.get_move(slot)
	if move == null:
		return false
	if not grounded and move.grounded_only:
		return false
	start_move(move)
	return true


func start_move(move: MoveData, msg: Dictionary = {}) -> void:
	var m := msg.duplicate()
	m["move"] = move
	change_state(&"attack", m)


# --- Ledges ---------------------------------------------------------------------

func check_ledge_grab(allow_rising: bool = false) -> bool:
	if ledge_cooldown > 0 or match_ref == null or grounded:
		return false
	if not allow_rising and velocity.y + kb_velocity.y < -60.0:
		return false
	var half_w := data.collision_size.x * 0.5
	var h := data.hurtbox_size.y
	for ledge in match_ref.stage.ledges:
		if ledge.occupant != null and ledge.occupant != self:
			continue
		var lp: Vector2 = ledge.global_position
		var outside: float = (global_position.x - lp.x) * ledge.dir
		if outside < -half_w - 8.0 or outside > half_w + 52.0:
			continue
		if global_position.y < lp.y - 16.0 or global_position.y - h > lp.y + 24.0:
			continue
		change_state(&"ledge", {"ledge": ledge})
		return true
	return false


func release_ledge() -> void:
	if match_ref == null:
		return
	for ledge in match_ref.stage.ledges:
		if ledge.occupant == self:
			ledge.occupant = null


# --- Defence & damage -----------------------------------------------------------

func _register_tech_press() -> void:
	if game_frame < _tech_lock_until:
		return
	_tech_press_frame = game_frame
	_tech_lock_until = game_frame + Game.config.tech_lockout_frames


func tech_ready() -> bool:
	return game_frame - _tech_press_frame <= Game.config.tech_window_frames


func can_be_hit() -> bool:
	return state_name != &"dead" and state_name != &"respawn" and intangible <= 0 and invincible <= 0


func get_hurtbox_rect() -> Rect2:
	var size := data.hurtbox_size
	size.y *= state.hurtbox_height_scale()
	if state_name == &"knockdown":
		size = Vector2(data.hurtbox_size.y * 0.8, data.hurtbox_size.x * 0.8)
	var pos := global_position + Vector2(-size.x * 0.5, -size.y)
	if state_name == &"ledge":
		pos.y = global_position.y - data.hurtbox_size.y
	return Rect2(pos, size)


func add_percent(amount: float) -> void:
	percent = minf(percent + amount, 999.0)
	percent_changed.emit(self)


## Entry point for incoming hits (called by CombatResolver).
func receive_hit(hit: HitInfo) -> int:
	if state.on_hurt(hit):
		return HitResult.ABSORBED
	if state_name == &"shield" and state.is_blocking():
		state.block(hit)
		return HitResult.SHIELDED
	add_percent(hit.damage)
	var cfg := Game.config
	hit.knockback = cfg.compute_knockback(percent, hit.damage, data.weight, hit.hitbox, hit.knockback_mult)
	hit.hitstun_frames = int(hit.knockback * cfg.hitstun_per_kb)
	if state_name == &"hitstun" or state_name == &"knockdown":
		combo_count += 1
	else:
		combo_count = 1
	last_hit_taken = hit
	hitstop = cfg.compute_hitlag(hit.damage, hit.hitbox) + (3 if hit.knockback >= cfg.strong_hit_kb else 0)
	release_ledge()
	change_state(&"hitstun", {"hit": hit})
	flash(Color.WHITE, 1.0)
	return HitResult.HIT


# --- Projectiles & effects ------------------------------------------------------

func spawn_projectile(beh: ProjectileBehavior) -> void:
	if match_ref:
		match_ref.spawn_projectile(self, beh)


func spawn_trail(move: MoveData) -> void:
	if match_ref:
		match_ref.spawn_trail(self, move)


func request_shake(amount: float) -> void:
	if match_ref:
		match_ref.add_shake(amount)


func flash(color: Color, amount: float) -> void:
	var mat := sprite.material as ShaderMaterial
	if mat == null:
		return
	if amount >= _flash_amount:
		mat.set_shader_parameter(&"flash_color", color)
	_flash_amount = maxf(_flash_amount, amount)


# --- Visuals --------------------------------------------------------------------

func play_anim(anim: StringName, speed: float = 1.0) -> void:
	var resolved := anim
	var guard := 0
	while not sprite.sprite_frames.has_animation(resolved) and guard < 6:
		resolved = ANIM_FALLBACKS.get(resolved, &"idle")
		guard += 1
	_anim_speed = speed
	if resolved != _anim:
		_anim = resolved
		_anim_ticks = 0.0
		sprite.animation = resolved


func _update_visuals(in_hitstop: bool) -> void:
	# Idle "breathing" so a single drawn idle frame still feels alive.
	var breathe := 1.0 + (0.012 * sin(game_frame * 0.09) if _anim == &"idle" else 0.0)
	body.scale = Vector2(facing * data.sprite_scale, data.sprite_scale * breathe)
	visual.rotation = visual_rotation
	if _shadow:
		_shadow.visible = grounded and visible and state_name != &"knockdown"
	# Animation is stepped by game frames so it freezes during hitstop and
	# follows training-mode slow motion.
	if not in_hitstop and sprite.sprite_frames:
		_anim_ticks += _anim_speed
		var fps := sprite.sprite_frames.get_animation_speed(_anim)
		var count := sprite.sprite_frames.get_frame_count(_anim)
		var idx := int(_anim_ticks * fps / 60.0)
		if sprite.sprite_frames.get_animation_loop(_anim):
			idx = idx % maxi(count, 1)
		else:
			idx = mini(idx, count - 1)
		sprite.frame = idx
	# Hitlag shake on the victim.
	if in_hitstop and state_name == &"hitstun":
		visual.position = Vector2(randf_range(-5.0, 5.0), randf_range(-2.0, 2.0))
	else:
		visual.position = Vector2.ZERO
	var mat := sprite.material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(&"flash_amount", _flash_amount)
	if not in_hitstop:
		_flash_amount *= 0.78
		if _flash_amount < 0.02:
			_flash_amount = 0.0
	var a := 1.0
	var mod := Color.WHITE
	if invincible > 0:
		a = 0.6 + 0.4 * absf(sin(game_frame * 0.25))
	elif intangible > 0:
		mod = Color(0.75, 0.9, 1.3)
		a = 0.75
	if state_name == &"helpless":
		mod = Color(0.55, 0.55, 0.62)
	sprite.modulate = Color(mod.r, mod.g, mod.b, a)
	overlay.queue_redraw()
