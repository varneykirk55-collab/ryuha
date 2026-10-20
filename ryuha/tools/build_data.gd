extends Node
## Generates the starter data set (.tres files) for the four fighters, the
## roster, combat config and audio library.
##
## The .tres files in res://data are the source of truth for the game and are
## meant to be edited in the Inspector. This script only exists so the initial
## data is reproducible and reviewable as text. Re-running it OVERWRITES data/.
##
## Run from the project folder:
##   godot --headless --import            (first time, to import textures)
##   godot --headless res://tools/build_data.tscn

const HB_SCALE := 1.12   ## move numbers below were authored for ~175px-tall fighters

var _meta: Dictionary


func _ready() -> void:
	_meta = JSON.parse_string(FileAccess.get_file_as_string("res://tools/frames_meta.json"))
	DirAccess.make_dir_recursive_absolute("res://data/characters")
	var cfg := _build_config()
	ResourceSaver.save(cfg, "res://data/combat_config.tres")
	ResourceSaver.save(_build_audio(), "res://data/audio_library.tres")
	var roster := Roster.new()
	roster.stages = PackedStringArray(["res://scenes/stages/dojo.tscn"])
	roster.characters.append(_katana())
	roster.characters.append(_naginata())
	roster.characters.append(_ronin())
	roster.characters.append(_nodachi())
	ResourceSaver.save(roster, "res://data/roster.tres")
	print("Data built: %d fighters" % roster.characters.size())
	get_tree().quit()


# ==============================================================================
# Helpers
# ==============================================================================

func hb(off: Vector2, r: float, dmg: float, ang: float, bkb: float, kbg: float, opts: Dictionary = {}) -> HitboxData:
	var h := HitboxData.new()
	h.offset = off * HB_SCALE
	h.radius = r * HB_SCALE
	h.damage = dmg
	h.angle = ang
	h.base_knockback = bkb
	h.knockback_growth = kbg
	for k in opts:
		var v = opts[k]
		if k == "size":
			v = v * HB_SCALE
		h.set(k, v)
	return h


func rect(off: Vector2, size: Vector2, dmg: float, ang: float, bkb: float, kbg: float, opts: Dictionary = {}) -> HitboxData:
	var o := opts.duplicate()
	o["shape"] = HitboxData.Shape.RECT
	o["size"] = size
	return hb(off, 0, dmg, ang, bkb, kbg, o)


## opts keys are MoveData property names, plus:
##   "behaviors": Array[MoveBehavior]   "trail": [center, radius, from_deg, to_deg, width]
func mv(id: String, display: String, s: int, a: int, r: int, boxes: Array, opts: Dictionary = {}) -> MoveData:
	var m := MoveData.new()
	m.id = StringName(id)
	m.display_name = display
	m.startup = s
	m.active = a
	m.recovery = r
	for i in boxes.size():
		var b: HitboxData = boxes[i]
		if not b.get_meta("keep_id", false) and b.id == 0:
			b.id = i
		m.hitboxes.append(b)
	for k in opts:
		match k:
			"behaviors":
				for bh in opts[k]:
					m.behaviors.append(bh)
			"trail":
				var t: Array = opts[k]
				m.trail_center = t[0] * HB_SCALE
				m.trail_radius = t[1] * HB_SCALE
				m.trail_from_deg = t[2]
				m.trail_to_deg = t[3]
				m.trail_width = t[4]
			_:
				m.set(k, opts[k])
	return m


func charge(frame: int, hold: Array, max_frames: int = 60, dmg_mult: float = 1.4, kb_mult: float = 1.0) -> ChargeBehavior:
	var c := ChargeBehavior.new()
	c.charge_frame = frame
	c.max_charge_frames = max_frames
	var acts: Array[StringName] = []
	for h in hold:
		acts.append(StringName(h))
	c.hold_actions = acts
	c.max_damage_mult = dmg_mult
	c.max_knockback_mult = kb_mult
	return c


func motion(from: int, to: int, vel: Vector2, set_x: bool = true, set_y: bool = false, charge_bonus: float = 0.0) -> MotionBehavior:
	var m := MotionBehavior.new()
	m.start_frame = from
	m.end_frame = to
	m.velocity = vel
	m.set_x = set_x
	m.set_y = set_y
	m.charge_bonus = charge_bonus
	return m


func armor(from: int, to: int, max_dmg: float = 0.0) -> ArmorBehavior:
	var a := ArmorBehavior.new()
	a.start_frame = from
	a.end_frame = to
	a.max_damage = max_dmg
	return a


## Common trail shapes (centre, radius, from°, to°, width).
func t_fwd(reach: float, y: float = -90.0) -> Array: return [Vector2(10, y), reach, 75.0, -25.0, 24.0]
func t_up(reach: float) -> Array: return [Vector2(0, -90), reach, 10.0, 170.0, 26.0]
func t_low(reach: float) -> Array: return [Vector2(0, -40), reach, 20.0, -20.0, 20.0]
func t_back(reach: float) -> Array: return [Vector2(-10, -90), reach, 110.0, 215.0, 24.0]
func t_down(reach: float) -> Array: return [Vector2(0, -60), reach, 200.0, 340.0, 26.0]
func t_spin(reach: float) -> Array: return [Vector2(0, -90), reach, 0.0, 330.0, 22.0]


func smash(m: MoveData, frame: int) -> MoveData:
	m.behaviors.append(charge(frame, ["attack", "strong"]))
	m.swing_sfx = &"swing_heavy"
	return m


func aerial(m: MoveData, landing_lag: int) -> MoveData:
	m.is_aerial = true
	m.landing_lag = landing_lag
	return m


func save_move(m: MoveData, char_id: String, slot: String) -> MoveData:
	var dir := "res://data/characters/%s/moves" % char_id
	DirAccess.make_dir_recursive_absolute(dir)
	var path := "%s/%s.tres" % [dir, slot]
	ResourceSaver.save(m, path)
	m.take_over_path(path)
	return m


func frames_for(char_id: String) -> SpriteFrames:
	var info: Dictionary = _meta[char_id]
	var sf := SpriteFrames.new()
	sf.remove_animation(&"default")
	var fps := {"idle": 6.0, "walk": 9.0, "jump": 10.0, "fall": 8.0, "hurt": 8.0,
		"attack_startup": 10.0, "attack_active": 10.0, "attack_recovery": 10.0}
	var loops := ["idle", "walk"]
	for anim in info["frames"]:
		sf.add_animation(anim)
		sf.set_animation_speed(anim, fps.get(anim, 8.0))
		sf.set_animation_loop(anim, anim in loops)
		for fname in info["frames"][anim]:
			sf.add_frame(anim, load("res://assets/characters/%s/%s" % [char_id, fname]))
	var path := "res://data/characters/%s/%s_frames.tres" % [char_id, char_id]
	ResourceSaver.save(sf, path)
	sf.take_over_path(path)
	return sf


func base_character(id: String, display: String, title: String, desc: String, target_height: float) -> CharacterData:
	var info: Dictionary = _meta[id]
	DirAccess.make_dir_recursive_absolute("res://data/characters/%s/moves" % id)
	var c := CharacterData.new()
	c.id = StringName(id)
	c.display_name = display
	c.title = title
	c.description = desc
	c.sprite_frames = frames_for(id)
	var canvas: Array = info["canvas"]
	c.sprite_foot = Vector2(canvas[0] / 2.0, info["foot_y"])
	c.sprite_scale = target_height / float(info["idle_height"])
	var atlas := AtlasTexture.new()
	atlas.atlas = c.sprite_frames.get_frame_texture(&"idle", 0)
	# Portrait: head-and-shoulders crop of the idle frame (head found by tools/extract.py).
	var head: Array = info["head"]
	atlas.region = Rect2(float(head[0]) - 52.0, maxf(float(head[1]) - 8.0, 0.0), 104.0, 104.0)
	var ppath := "res://data/characters/%s/%s_portrait.tres" % [id, id]
	ResourceSaver.save(atlas, ppath)
	atlas.take_over_path(ppath)
	c.portrait = atlas
	c.scene_path = "res://scenes/fighters/%s.tscn" % id
	_write_fighter_scene(id, display)
	return c


func finish(c: CharacterData, moves: Dictionary) -> CharacterData:
	var id := String(c.id)
	for slot in moves:
		c.set(slot, save_move(moves[slot], id, slot))
	var path := "res://data/characters/%s/%s.tres" % [id, id]
	ResourceSaver.save(c, path)
	c.take_over_path(path)
	return c


func _write_fighter_scene(id: String, display: String) -> void:
	# Per-fighter scene inheriting the base fighter. Add custom child nodes here
	# (e.g. a 3D model in a SubViewport, extra particles) without touching code.
	var f := FileAccess.open("res://scenes/fighters/%s.tscn" % id, FileAccess.WRITE)
	f.store_string("[gd_scene load_steps=2 format=3]\n\n[ext_resource type=\"PackedScene\" path=\"res://scenes/fighters/fighter_base.tscn\" id=\"1_base\"]\n\n[node name=\"%s\" instance=ExtResource(\"1_base\")]\n" % display.replace(" ", ""))
	f.close()


# ==============================================================================
# Shared config
# ==============================================================================

func _build_config() -> CombatConfig:
	var cfg := CombatConfig.new()
	var getup := mv("getup_attack", "Get-up Attack", 10, 6, 18, [
		hb(Vector2(60, -35), 42, 6, 35, 55, 50),
		hb(Vector2(-60, -35), 42, 6, 145, 55, 50)], {"trail": t_spin(70)})
	var ledge := mv("ledge_attack", "Ledge Attack", 12, 4, 20, [
		hb(Vector2(70, -45), 46, 8, 40, 60, 45)], {"trail": t_low(85)})
	for pair in [[getup, "getup_attack"], [ledge, "ledge_attack"]]:
		DirAccess.make_dir_recursive_absolute("res://data/moves")
		var p := "res://data/moves/%s.tres" % pair[1]
		ResourceSaver.save(pair[0], p)
		pair[0].take_over_path(p)
	cfg.getup_attack = getup
	cfg.ledge_attack = ledge
	return cfg


func _build_audio() -> AudioLibrary:
	var lib := AudioLibrary.new()
	for ev in ["swing_light", "swing_heavy", "hit_light", "hit_heavy", "clank", "shield_hit", "jump",
			"land", "tech", "ko", "charge", "round_start", "menu_move", "menu_confirm"]:
		lib.events[StringName(ev)] = [load("res://assets/audio/sfx/%s.wav" % ev)]
	lib.volume = {&"land": -8.0, &"menu_move": -10.0, &"jump": -6.0, &"charge": -6.0}
	return lib


# ==============================================================================
# 1. HAYATO — Katana Specialist: fast, precise, strong neutral & edge-guarding.
#    Signature: Iaijutsu Quick Draw (neutral special, chargeable).
# ==============================================================================

func _katana() -> CharacterData:
	var c := base_character("katana", "Hayato", "Katana Specialist",
		"Fast and precise. Wins neutral with quick pokes and closes stocks with a charged quick-draw and a spiking down-air off the ledge.", 196.0)
	c.accent_color = Color(0.85, 0.29, 0.29)
	c.alt_tint = Color(0.8, 0.9, 1.15)
	c.signature_slot = &"neutral_special"
	c.weight = 90
	c.walk_speed = 600
	c.run_speed = 1180
	c.ground_accel = 5200
	c.ground_friction = 4400
	c.air_speed = 720
	c.air_accel = 2800
	c.air_friction = 1000
	c.gravity = 3400
	c.max_fall_speed = 1250
	c.fast_fall_speed = 1900
	c.full_hop_height = 430
	c.short_hop_height = 200
	c.double_jump_height = 410
	c.jump_squat_frames = 3
	c.hurtbox_size = Vector2(58, 170) * HB_SCALE
	c.collision_size = Vector2(44, 120) * HB_SCALE

	var jab3 := mv("jab3", "Jab 3", 4, 3, 20, [hb(Vector2(70, -95), 36, 5, 40, 55, 70)], {"trail": t_fwd(80)})
	var jab2 := mv("jab2", "Jab 2", 3, 2, 14, [hb(Vector2(58, -90), 30, 2.5, 80, 20, 40)],
		{"trail": t_fwd(70), "next_on_attack": jab3, "chain_from_frame": 6})
	var jab := mv("jab", "Jab", 2, 2, 14, [hb(Vector2(55, -95), 30, 2.5, 80, 20, 40)],
		{"trail": t_fwd(65), "next_on_attack": jab2, "chain_from_frame": 5})
	var riposte := mv("riposte", "Riposte", 2, 4, 22, [hb(Vector2(85, -90), 58, 8, 40, 60, 90, {"hit_away_from_center": true, "hitlag_multiplier": 1.4})],
		{"trail": [Vector2(0, -90), 110.0, 60.0, -40.0, 34.0], "swing_sfx": &"swing_heavy"})
	var counter := CounterBehavior.new()
	counter.window = Vector2i(4, 24)
	counter.counter_move = save_move(riposte, "katana", "riposte")
	counter.damage_multiplier = 1.25
	counter.min_damage = 8

	return finish(c, {
		"jab": jab, "dash_attack": mv("dash_attack", "Dash Slash", 6, 5, 20, [hb(Vector2(60, -85), 40, 9, 45, 45, 70)],
			{"trail": t_fwd(85), "behaviors": [motion(1, 10, Vector2(900, 0))]}),
		"forward_tilt": mv("forward_tilt", "Forward Tilt", 6, 3, 18, [hb(Vector2(85, -92), 34, 9, 35, 30, 90), hb(Vector2(40, -92), 28, 8, 35, 30, 85)], {"trail": t_fwd(95)}),
		"up_tilt": mv("up_tilt", "Up Tilt", 5, 5, 16, [hb(Vector2(20, -175), 42, 7, 88, 35, 110), hb(Vector2(55, -135), 30, 7, 85, 35, 105)], {"trail": t_up(95), "pose_tilt": 40.0}),
		"down_tilt": mv("down_tilt", "Down Tilt", 5, 3, 14, [hb(Vector2(75, -22), 32, 6, 78, 40, 60)], {"trail": t_low(85), "pose_active": &"attack_active", "pose_tilt": -12.0}),
		"forward_smash": smash(mv("forward_smash", "Forward Smash", 12, 3, 30, [hb(Vector2(100, -92), 42, 16, 38, 38, 98), hb(Vector2(45, -92), 32, 13, 38, 35, 95)], {"trail": t_fwd(115)}), 9),
		"up_smash": smash(mv("up_smash", "Up Smash", 9, 6, 28, [hb(Vector2(0, -190), 52, 14, 88, 36, 100), hb(Vector2(40, -130), 34, 12, 85, 36, 95)], {"trail": t_up(120), "pose_tilt": 55.0}), 6),
		"down_smash": smash(mv("down_smash", "Down Smash", 7, 3, 30, [hb(Vector2(72, -25), 36, 12, 28, 30, 95), hb(Vector2(-72, -25), 36, 12, 152, 30, 95)], {"trail": [Vector2(0, -40), 80.0, -10.0, 190.0, 20.0], "pose_tilt": -10.0}), 5),
		"neutral_air": aerial(mv("neutral_air", "Neutral Air", 4, 10, 14, [hb(Vector2(0, -95), 62, 8, 45, 25, 90, {"start_frame": 5, "end_frame": 8}), hb(Vector2(0, -95), 58, 5, 45, 20, 70, {"start_frame": 9, "end_frame": 14})], {"trail": t_spin(75)}), 7),
		"forward_air": aerial(mv("forward_air", "Forward Air", 6, 4, 18, [hb(Vector2(80, -105), 40, 10, 42, 30, 95)], {"trail": t_fwd(95, -105)}), 9),
		"back_air": aerial(mv("back_air", "Back Air", 7, 4, 16, [hb(Vector2(-80, -95), 40, 12, 145, 30, 110)], {"trail": t_back(95), "pose_active": &"attack_startup"}), 10),
		"up_air": aerial(mv("up_air", "Up Air", 5, 5, 15, [hb(Vector2(10, -195), 46, 8, 85, 30, 95)], {"trail": t_up(105), "pose_tilt": 60.0}), 8),
		"down_air": aerial(mv("down_air", "Down Air", 8, 6, 20, [hb(Vector2(5, -5), 38, 12, 270, 25, 85), hb(Vector2(5, -45), 30, 9, 290, 25, 75)], {"trail": t_down(80), "pose_tilt": -60.0}), 14),
		"neutral_special": mv("neutral_special", "Iaijutsu: Quick Draw", 14, 4, 26,
			[rect(Vector2(125, -90), Vector2(250, 52), 11, 38, 45, 92, {"hitlag_multiplier": 1.3})],
			{"trail": [Vector2(-40, -90), 230.0, 18.0, -12.0, 30.0], "swing_sfx": &"swing_heavy", "gravity_scale": 0.5,
			 "behaviors": [charge(6, ["special"], 60, 2.0, 1.25), motion(15, 18, Vector2(700, 0), true, false, 1.0)]}),
		"side_special": mv("side_special", "Wind Step", 6, 8, 22, [hb(Vector2(45, -92), 46, 8, 45, 45, 65)],
			{"trail": t_fwd(90), "air_uses": 1, "gravity_scale": 0.0, "allow_drift": false,
			 "behaviors": [motion(6, 14, Vector2(1500, 0), true, true), motion(15, 18, Vector2(300, 0))]}),
		"down_special": mv("down_special", "Iaido Counter", 3, 22, 16, [],
			{"trail_enabled": false, "pose_active": &"attack_startup", "gravity_scale": 0.4, "behaviors": [counter]}),
		"up_special": mv("up_special", "Rising Crescent", 3, 14, 22, [
			hb(Vector2(25, -125), 46, 6, 85, 45, 50, {"start_frame": 4, "end_frame": 9, "group": 0}),
			hb(Vector2(20, -180), 46, 5, 80, 60, 80, {"start_frame": 10, "end_frame": 16, "group": 1})],
			{"trail": t_up(110), "pose_tilt": 50.0, "ends_in_helpless": true, "ledge_grab_from_frame": 8, "helpless_landing_lag": 18,
			 "allow_drift": true, "behaviors": [motion(3, 16, Vector2(250, -1550), true, true)]}),
	})


# ==============================================================================
# 2. TOMOE — Naginata Wielder: long reach, spacing, weak up close.
#    Signature: Whirlwind Arc (neutral special) – a spinning sweep in front and above.
# ==============================================================================

func _naginata() -> CharacterData:
	var c := base_character("naginata", "Tomoe", "Naginata Wielder",
		"Controls space with the longest reach in the dojo. Sour-spots up close, so keep enemies at the blade's tip.", 192.0)
	c.accent_color = Color(0.64, 0.42, 0.85)
	c.alt_tint = Color(1.15, 0.9, 0.8)
	c.signature_slot = &"neutral_special"
	c.weight = 88
	c.walk_speed = 540
	c.run_speed = 1050
	c.ground_accel = 4600
	c.ground_friction = 4000
	c.air_speed = 660
	c.air_accel = 2400
	c.air_friction = 900
	c.gravity = 3200
	c.max_fall_speed = 1150
	c.fast_fall_speed = 1750
	c.full_hop_height = 440
	c.short_hop_height = 200
	c.double_jump_height = 440
	c.hurtbox_size = Vector2(58, 168) * HB_SCALE
	c.collision_size = Vector2(44, 120) * HB_SCALE

	return finish(c, {
		"jab": mv("jab", "Haft Thrust", 5, 3, 18, [hb(Vector2(115, -95), 26, 4, 40, 30, 60), hb(Vector2(45, -95), 22, 2, 60, 15, 30)], {"trail": t_fwd(120)}),
		"dash_attack": mv("dash_attack", "Running Lunge", 8, 5, 24, [hb(Vector2(140, -85), 32, 9, 40, 45, 70), hb(Vector2(60, -85), 26, 5, 50, 30, 40)],
			{"trail": t_fwd(140), "behaviors": [motion(1, 12, Vector2(800, 0))]}),
		"forward_tilt": mv("forward_tilt", "Long Thrust", 8, 4, 22, [hb(Vector2(155, -92), 30, 10, 35, 35, 88), hb(Vector2(65, -92), 24, 5, 40, 20, 50)], {"trail": t_fwd(160)}),
		"up_tilt": mv("up_tilt", "Rising Arc", 8, 8, 20, [hb(Vector2(70, -185), 40, 9, 85, 35, 100), hb(Vector2(-10, -205), 36, 8, 95, 35, 95)], {"trail": t_up(140), "pose_tilt": 35.0}),
		"down_tilt": mv("down_tilt", "Ankle Sweep", 7, 3, 18, [hb(Vector2(145, -20), 28, 8, 20, 40, 55), hb(Vector2(70, -20), 22, 4, 30, 25, 40)], {"trail": t_low(150), "pose_tilt": -10.0}),
		"forward_smash": smash(mv("forward_smash", "Piercing Lunge", 16, 4, 34, [hb(Vector2(170, -90), 38, 17, 35, 40, 98), hb(Vector2(85, -90), 26, 9, 40, 30, 70)], {"trail": t_fwd(180)}), 12),
		"up_smash": smash(mv("up_smash", "Heaven Sweep", 12, 8, 30, [hb(Vector2(0, -215), 56, 15, 90, 38, 100), hb(Vector2(70, -160), 36, 11, 85, 35, 90)], {"trail": t_up(150), "pose_tilt": 50.0}), 9),
		"down_smash": smash(mv("down_smash", "Twin Reap", 10, 4, 32, [hb(Vector2(150, -22), 32, 13, 30, 32, 92), hb(Vector2(-150, -22), 32, 13, 150, 32, 92)], {"trail": [Vector2(0, -40), 150.0, -10.0, 190.0, 22.0], "pose_tilt": -10.0}), 7),
		"neutral_air": aerial(mv("neutral_air", "Pole Spin", 6, 12, 16, [hb(Vector2(0, -95), 78, 7, 45, 30, 80)], {"trail": t_spin(100)}), 9),
		"forward_air": aerial(mv("forward_air", "Air Thrust", 9, 4, 20, [hb(Vector2(135, -100), 32, 11, 38, 32, 92), hb(Vector2(60, -100), 24, 5, 45, 20, 50)], {"trail": t_fwd(145, -100)}), 11),
		"back_air": aerial(mv("back_air", "Butt Strike", 9, 4, 18, [hb(Vector2(-125, -90), 32, 12, 145, 32, 105)], {"trail": t_back(135), "pose_active": &"attack_startup"}), 11),
		"up_air": aerial(mv("up_air", "Sky Arc", 7, 6, 18, [hb(Vector2(20, -215), 44, 10, 88, 30, 95)], {"trail": t_up(140), "pose_tilt": 60.0}), 9),
		"down_air": aerial(mv("down_air", "Earth Pierce", 10, 5, 22, [hb(Vector2(0, 30), 32, 11, 275, 20, 80)], {"trail": t_down(110), "pose_tilt": -65.0}), 15),
		"neutral_special": mv("neutral_special", "Whirlwind Arc", 10, 20, 24, [
			hb(Vector2(140, -50), 44, 3, 70, 45, 20, {"start_frame": 11, "end_frame": 14, "group": 0}),
			hb(Vector2(125, -150), 46, 3, 80, 45, 20, {"start_frame": 15, "end_frame": 18, "group": 1}),
			hb(Vector2(30, -215), 50, 3, 88, 45, 20, {"start_frame": 19, "end_frame": 23, "group": 2}),
			hb(Vector2(60, -200), 50, 8, 80, 60, 95, {"start_frame": 24, "end_frame": 30, "group": 3}),
			hb(Vector2(-50, -185), 46, 8, 80, 60, 95, {"start_frame": 24, "end_frame": 30, "group": 3})],
			{"trail": [Vector2(0, -110), 160.0, -20.0, 200.0, 34.0], "swing_sfx": &"swing_heavy", "gravity_scale": 0.35, "allow_drift": false}),
		"side_special": mv("side_special", "Long Reach Thrust", 13, 4, 26, [
			hb(Vector2(245, -92), 28, 14, 38, 50, 88),
			rect(Vector2(160, -92), Vector2(150, 36), 10, 40, 45, 80)],
			{"trail": t_fwd(230), "air_uses": 1, "swing_sfx": &"swing_heavy", "behaviors": [motion(11, 17, Vector2(800, 0))]}),
		"down_special": mv("down_special", "Guard Sweep", 9, 5, 26, [hb(Vector2(150, -25), 36, 9, 75, 55, 60), hb(Vector2(-150, -25), 36, 9, 105, 55, 60)],
			{"trail": [Vector2(0, -40), 150.0, -10.0, 190.0, 24.0], "pose_tilt": -8.0}),
		"up_special": mv("up_special", "Polevault Ascent", 5, 12, 24, [hb(Vector2(0, -205), 50, 8, 85, 55, 70, {"start_frame": 6, "end_frame": 12})],
			{"trail": t_up(130), "pose_tilt": 55.0, "ends_in_helpless": true, "ledge_grab_from_frame": 9,
			 "behaviors": [motion(5, 16, Vector2(200, -1650), true, true)]}),
	})


# ==============================================================================
# 3. KAGE — Dual-Wield Ronin: aggressive, huge close damage, poor recovery.
#    Signature: Thousand Cuts Rush (side special) – multi-hit rush ending in a launcher.
# ==============================================================================

func _ronin() -> CharacterData:
	var c := base_character("ronin", "Kage", "Dual-Wield Ronin",
		"Relentless up close: frame-fast pokes and the highest damage per opening. His weak double jump and short recovery punish mistakes off-stage.", 186.0)
	c.accent_color = Color(0.35, 0.72, 0.56)
	c.alt_tint = Color(1.15, 0.95, 0.75)
	c.signature_slot = &"side_special"
	c.weight = 85
	c.walk_speed = 640
	c.run_speed = 1280
	c.ground_accel = 5600
	c.ground_friction = 4600
	c.air_speed = 700
	c.air_accel = 3000
	c.air_friction = 1100
	c.gravity = 3700
	c.max_fall_speed = 1380
	c.fast_fall_speed = 2050
	c.full_hop_height = 410
	c.short_hop_height = 190
	c.double_jump_height = 320
	c.hurtbox_size = Vector2(56, 158) * HB_SCALE
	c.collision_size = Vector2(42, 115) * HB_SCALE

	var kunai_hb := hb(Vector2.ZERO, 18, 4, 30, 20, 40)
	var kunai := ProjectileBehavior.new()
	kunai.spawn_frame = 11
	kunai.spawn_offset = Vector2(50, -100) * HB_SCALE
	kunai.velocity = Vector2(1600, 0)
	kunai.lifetime_frames = 36
	kunai.hitbox = kunai_hb
	kunai.color = Color(0.85, 0.88, 0.92)

	var jab3 := mv("jab3", "Twin Cut 3", 3, 3, 18, [hb(Vector2(55, -92), 38, 6, 45, 50, 70)], {"trail": t_fwd(75)})
	var jab2 := mv("jab2", "Twin Cut 2", 2, 2, 12, [hb(Vector2(50, -90), 32, 3, 75, 20, 35)], {"trail": t_fwd(65), "next_on_attack": jab3, "chain_from_frame": 5})
	var jab := mv("jab", "Twin Cut", 2, 2, 12, [hb(Vector2(48, -95), 32, 3, 75, 20, 35)], {"trail": t_fwd(60), "next_on_attack": jab2, "chain_from_frame": 5})

	return finish(c, {
		"jab": jab,
		"dash_attack": mv("dash_attack", "Charging Cross", 5, 6, 20, [hb(Vector2(55, -90), 42, 11, 45, 45, 75)],
			{"trail": t_fwd(80), "behaviors": [motion(1, 11, Vector2(1000, 0))]}),
		"forward_tilt": mv("forward_tilt", "Cross Cut", 5, 4, 14, [hb(Vector2(62, -92), 38, 10, 40, 30, 85)], {"trail": t_fwd(80)}),
		"up_tilt": mv("up_tilt", "Rising Fang", 5, 5, 14, [hb(Vector2(30, -155), 42, 8, 90, 40, 80)], {"trail": t_up(85), "pose_tilt": 40.0}),
		"down_tilt": mv("down_tilt", "Shin Cutter", 4, 3, 12, [hb(Vector2(58, -25), 30, 7, 80, 45, 50)], {"trail": t_low(70), "pose_tilt": -12.0}),
		"forward_smash": smash(mv("forward_smash", "Executioner's X", 11, 4, 28, [hb(Vector2(68, -92), 44, 18, 36, 36, 100)], {"trail": t_fwd(95)}), 8),
		"up_smash": smash(mv("up_smash", "Twin Ascension", 8, 6, 26, [hb(Vector2(0, -170), 52, 16, 88, 36, 100)], {"trail": t_up(100), "pose_tilt": 55.0}), 5),
		"down_smash": smash(mv("down_smash", "Scissor Sweep", 6, 4, 26, [hb(Vector2(58, -25), 38, 14, 30, 32, 95), hb(Vector2(-58, -25), 38, 14, 150, 32, 95)], {"trail": [Vector2(0, -40), 70.0, -10.0, 190.0, 20.0], "pose_tilt": -10.0}), 4),
		"neutral_air": aerial(mv("neutral_air", "Blade Wheel", 4, 8, 12, [hb(Vector2(0, -92), 58, 9, 45, 28, 85)], {"trail": t_spin(70)}), 7),
		"forward_air": aerial(mv("forward_air", "Falling Cross", 5, 4, 14, [hb(Vector2(62, -102), 40, 12, 40, 30, 95)], {"trail": t_fwd(80, -102)}), 8),
		"back_air": aerial(mv("back_air", "Reverse Fang", 6, 3, 14, [hb(Vector2(-62, -95), 40, 13, 145, 30, 108)], {"trail": t_back(80), "pose_active": &"attack_startup"}), 9),
		"up_air": aerial(mv("up_air", "Scissor Sky", 4, 6, 12, [hb(Vector2(5, -178), 46, 10, 88, 30, 92)], {"trail": t_up(95), "pose_tilt": 60.0}), 7),
		"down_air": aerial(mv("down_air", "Double Drop", 9, 8, 18, [hb(Vector2(0, -10), 42, 13, 285, 25, 85)], {"trail": t_down(80), "pose_tilt": -60.0}), 16),
		"neutral_special": mv("neutral_special", "Kunai Toss", 10, 2, 18, [], {"trail_enabled": false, "behaviors": [kunai]}),
		"side_special": mv("side_special", "Thousand Cuts Rush", 8, 34, 26, [
			hb(Vector2(58, -92), 48, 1.6, 20, 0, 100, {"start_frame": 9, "end_frame": 38, "rehit_rate": 4, "set_knockback": 30.0, "hitlag_multiplier": 0.5, "group": 0}),
			hb(Vector2(58, -112), 56, 7, 82, 75, 105, {"start_frame": 40, "end_frame": 43, "group": 1, "hitlag_multiplier": 1.5})],
			{"trail": [Vector2(0, -95), 75.0, 120.0, -120.0, 26.0], "swing_sfx": &"swing_heavy", "air_uses": 1, "ends_in_helpless": true,
			 "gravity_scale": 0.25, "allow_drift": false, "helpless_landing_lag": 22,
			 "behaviors": [motion(9, 38, Vector2(950, 0)), motion(39, 44, Vector2(150, 0))]}),
		"down_special": mv("down_special", "Backstep Slash", 12, 3, 18, [hb(Vector2(78, -92), 44, 10, 40, 40, 85)],
			{"trail": t_fwd(95), "intangible_frames": Vector2i(2, 9),
			 "behaviors": [motion(2, 9, Vector2(-950, 0)), motion(10, 11, Vector2(0, 0)), motion(12, 15, Vector2(650, 0))]}),
		"up_special": mv("up_special", "Rising Twin Fang", 4, 14, 26, [
			hb(Vector2(20, -135), 44, 2, 90, 0, 100, {"start_frame": 5, "end_frame": 14, "rehit_rate": 4, "set_knockback": 30.0, "group": 0}),
			hb(Vector2(20, -180), 48, 5, 80, 55, 80, {"start_frame": 15, "end_frame": 18, "group": 1})],
			{"trail": t_up(95), "pose_tilt": 55.0, "ends_in_helpless": true, "ledge_grab_from_frame": 10, "helpless_landing_lag": 22,
			 "behaviors": [motion(4, 16, Vector2(150, -1250), true, true)]}),
	})


# ==============================================================================
# 4. GOZAN — Nodachi Wielder: heavy, slow, durable, dominant anti-air.
#    Signature: Heaven-Splitting Overhead (down special, grounded) – huge knockback.
# ==============================================================================

func _nodachi() -> CharacterData:
	var c := base_character("nodachi", "Gozan", "Nodachi Wielder",
		"A walking fortress. Slow to start but nearly impossible to approach from the air, and his armored overhead ends stocks absurdly early.", 214.0)
	c.accent_color = Color(0.86, 0.64, 0.25)
	c.alt_tint = Color(0.8, 0.95, 1.15)
	c.signature_slot = &"down_special"
	c.weight = 118
	c.walk_speed = 430
	c.run_speed = 900
	c.ground_accel = 4000
	c.ground_friction = 4200
	c.air_speed = 560
	c.air_accel = 2000
	c.air_friction = 800
	c.gravity = 3800
	c.max_fall_speed = 1420
	c.fast_fall_speed = 2100
	c.full_hop_height = 380
	c.short_hop_height = 175
	c.double_jump_height = 360
	c.jump_squat_frames = 4
	c.landing_frames = 5
	c.hurtbox_size = Vector2(70, 188) * HB_SCALE
	c.collision_size = Vector2(52, 132) * HB_SCALE

	var shock := mv("cleave_shock", "Cleave Shockwave", 1, 4, 26, [hb(Vector2(90, -20), 55, 10, 70, 60, 60), hb(Vector2(-90, -20), 55, 10, 110, 60, 60)],
		{"trail": [Vector2(0, -30), 110.0, -5.0, 185.0, 18.0], "swing_sfx": &"hit_heavy"})
	var landing := LandingFollowupBehavior.new()
	landing.followup = save_move(shock, "nodachi", "cleave_shock")
	landing.from_frame = 8

	return finish(c, {
		"jab": mv("jab", "Pommel Strike", 6, 3, 20, [hb(Vector2(58, -105), 36, 6, 45, 40, 70)], {"trail": t_fwd(75), "pose_active": &"attack_startup"}),
		"dash_attack": mv("dash_attack", "Shoulder Rush", 10, 6, 26, [hb(Vector2(55, -95), 48, 12, 40, 55, 70)],
			{"trail": t_fwd(80), "behaviors": [motion(1, 14, Vector2(800, 0))]}),
		"forward_tilt": mv("forward_tilt", "Horizontal Cleave", 10, 4, 24, [hb(Vector2(135, -90), 40, 13, 38, 35, 92), hb(Vector2(60, -90), 34, 11, 38, 35, 88)], {"trail": t_fwd(145)}),
		"up_tilt": mv("up_tilt", "Sky Splitter", 8, 10, 24, [hb(Vector2(60, -190), 55, 12, 85, 40, 98), hb(Vector2(0, -245), 55, 12, 90, 40, 98)], {"trail": t_up(170), "pose_tilt": 45.0}),
		"down_tilt": mv("down_tilt", "Low Reap", 9, 4, 22, [hb(Vector2(125, -25), 34, 10, 30, 40, 70)], {"trail": t_low(140), "pose_tilt": -12.0}),
		"forward_smash": smash(mv("forward_smash", "Mountain Cleaver", 20, 5, 40, [hb(Vector2(155, -80), 52, 24, 36, 40, 100), hb(Vector2(70, -90), 40, 19, 38, 38, 96)],
			{"trail": [Vector2(0, -90), 165.0, 100.0, -30.0, 40.0]}), 16),
		"up_smash": smash(mv("up_smash", "Heavenward Arc", 14, 8, 36, [hb(Vector2(0, -250), 72, 20, 90, 38, 100), hb(Vector2(70, -170), 46, 15, 85, 36, 95)], {"trail": t_up(190), "pose_tilt": 55.0}), 11),
		"down_smash": smash(mv("down_smash", "Earthsplit Sweep", 13, 5, 38, [hb(Vector2(140, -25), 44, 18, 30, 34, 96), hb(Vector2(-140, -25), 44, 18, 150, 34, 96)], {"trail": [Vector2(0, -40), 145.0, -10.0, 190.0, 30.0], "pose_tilt": -10.0}), 10),
		"neutral_air": aerial(mv("neutral_air", "Iron Circle", 9, 8, 22, [hb(Vector2(0, -95), 82, 12, 45, 30, 90)], {"trail": t_spin(110)}), 13),
		"forward_air": aerial(mv("forward_air", "Falling Cleaver", 13, 5, 24, [hb(Vector2(115, -110), 48, 16, 40, 32, 98)], {"trail": t_fwd(140, -110)}), 16),
		"back_air": aerial(mv("back_air", "Reverse Cleaver", 12, 4, 22, [hb(Vector2(-115, -95), 46, 17, 145, 32, 105)], {"trail": t_back(140), "pose_active": &"attack_startup"}), 15),
		"up_air": aerial(mv("up_air", "Crescent Ceiling", 8, 8, 20, [hb(Vector2(0, -230), 66, 14, 88, 32, 98)], {"trail": t_up(175), "pose_tilt": 60.0}), 12),
		"down_air": aerial(mv("down_air", "Falling Boulder", 15, 6, 28, [hb(Vector2(0, 10), 50, 17, 270, 25, 88)], {"trail": t_down(130), "pose_tilt": -60.0}), 22),
		"neutral_special": mv("neutral_special", "Bulwark Thrust", 14, 5, 30, [rect(Vector2(135, -100), Vector2(210, 52), 12, 40, 50, 90)],
			{"trail": [Vector2(-30, -100), 200.0, 15.0, -10.0, 32.0], "swing_sfx": &"swing_heavy",
			 "behaviors": [charge(8, ["special"], 50, 2.0, 1.2), motion(15, 18, Vector2(500, 0), true, false, 1.0)]}),
		"side_special": mv("side_special", "Avalanche Step", 10, 9, 28, [hb(Vector2(60, -95), 52, 11, 40, 55, 70, {"start_frame": 10, "end_frame": 18})],
			{"trail": t_fwd(90), "air_uses": 1, "behaviors": [armor(4, 16, 12.0), motion(8, 18, Vector2(950, 0))]}),
		"down_special": mv("down_special", "Heaven-Splitting Overhead", 24, 5, 44, [
			hb(Vector2(145, -80), 62, 22, 42, 50, 96, {"hitlag_multiplier": 1.6, "hit_sfx": &"hit_heavy"}),
			hb(Vector2(245, -20), 42, 12, 60, 50, 70)],
			{"trail": [Vector2(20, -110), 175.0, 125.0, -35.0, 46.0], "swing_sfx": &"swing_heavy", "grounded_only": true,
			 "behaviors": [armor(6, 24)]}),
		"down_special_air": mv("down_special_air", "Falling Cleave", 10, 30, 20, [hb(Vector2(40, -40), 52, 14, 280, 30, 80, {"start_frame": 9, "end_frame": 40})],
			{"trail": t_down(120), "pose_tilt": -45.0, "ends_in_helpless": true, "allow_drift": false, "cancel_on_land": false,
			 "behaviors": [motion(1, 8, Vector2(0, -300), true, true), motion(9, 40, Vector2(0, 1800), true, true), landing]}),
		"up_special": mv("up_special", "Mountain Ascent", 7, 12, 28, [hb(Vector2(30, -165), 62, 12, 80, 55, 85, {"start_frame": 8, "end_frame": 14})],
			{"trail": t_up(160), "pose_tilt": 50.0, "ends_in_helpless": true, "ledge_grab_from_frame": 10, "helpless_landing_lag": 24,
			 "behaviors": [motion(7, 18, Vector2(250, -1450), true, true)]}),
	})
