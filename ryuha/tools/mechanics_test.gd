extends Node
## Automated mechanics checks (headless). Prints PASS/FAIL per check.
## godot --headless --fixed-fps 60 res://tools/mechanics_test.tscn

class Scripted extends InputSource:
	## Feed a list of {frames, stick, held:[actions]} steps.
	var steps: Array = []
	var t := 0
	var _prev := {}
	func poll(_f) -> InputState:
		var s := InputState.new()
		var held := {}
		var acc := 0
		for st in steps:
			acc += int(st["frames"])
			if t < acc:
				s.stick = st.get("stick", Vector2.ZERO)
				for a in st.get("held", []):
					held[StringName(a)] = true
				break
		for a in InputState.ACTIONS:
			s.pressed[a] = held.get(a, false) and not _prev.get(a, false)
		var prev_stick: Vector2 = _prev.get("_stick", Vector2.ZERO)
		s.tapped = Vector2i(int(signf(s.stick.x)) if absf(s.stick.x) > 0.6 and absf(prev_stick.x) <= 0.6 else 0,
			int(signf(s.stick.y)) if absf(s.stick.y) > 0.6 and absf(prev_stick.y) <= 0.6 else 0)
		held["_stick"] = s.stick
		s.held = held
		_prev = held
		t += 1
		state = s
		return s

var m: Match
var results: Array = []


func _ready() -> void:
	var s := Game.setup
	s.mode = MatchSetup.Mode.TRAINING
	s.players = [{"character": 0, "scheme": &"kb_solo", "cpu": false}, {"character": 3, "scheme": &"kb_right", "cpu": false}]
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child(m)
	set_physics_process(false)
	await get_tree().physics_frame
	await _run_all()
	var fails := results.filter(func(r): return not r[1])
	print("\n=== %d checks, %d failed ===" % [results.size(), fails.size()])
	get_tree().quit(1 if fails.size() > 0 else 0)


func check(name: String, ok: bool, info: String = "") -> void:
	results.append([name, ok])
	print(("PASS  " if ok else "FAIL  ") + name + ("   (" + info + ")" if info != "" else ""))


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func reset(p1_char: int = 0, p2_char: int = 3) -> Array:
	# Rebuild fighters with new characters by reloading the match.
	m.queue_free()
	await get_tree().process_frame
	Game.setup.players[0]["character"] = p1_char
	Game.setup.players[1]["character"] = p2_char
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child(m)
	await frames(2)
	return [m.fighters[0], m.fighters[1]]


func drive(f: Fighter, steps: Array) -> Scripted:
	var sc := Scripted.new()
	sc.steps = steps
	f.input_source = sc
	return sc


func _run_all() -> void:
	var fs := await reset(0, 3)
	var p1: Fighter = fs[0]
	var p2: Fighter = fs[1]

	# 1. Every move of every character runs to completion without errors.
	for ci in Game.roster.characters.size():
		fs = await reset(ci, 3)
		p1 = fs[0]
		p2 = fs[1]
		p2.global_position = Vector2(800, 0)
		var cd: CharacterData = p1.data
		var ok := true
		for slot in ["jab", "dash_attack", "forward_tilt", "up_tilt", "down_tilt", "forward_smash", "up_smash", "down_smash",
				"neutral_special", "side_special", "down_special", "up_special"]:
			p1.global_position = Vector2(-300, 0)
			p1.change_state(&"idle")
			await frames(2)
			var mv := cd.get_move(slot)
			p1.start_move(mv)
			for i in mv.total_frames() + 80:
				await frames(1)
				if p1.state_name != &"attack":
					break
			if p1.state_name == &"attack":
				ok = false
				print("   stuck in ", slot)
		for slot in ["neutral_air", "forward_air", "back_air", "up_air", "down_air"]:
			p1.global_position = Vector2(-300, -600)
			p1.velocity = Vector2.ZERO
			p1.change_state(&"air")
			await frames(1)
			p1.start_move(cd.get_move(slot))
			await frames(cd.get_move(slot).total_frames() + 2)
			if p1.state_name == &"attack":
				ok = false
		check("%s: all moves complete" % cd.display_name, ok)

	# 2. Hitting the dummy deals damage and knockback scales with percent.
	fs = await reset(0, 3)
	p1 = fs[0]
	p2 = fs[1]
	p1.global_position = Vector2(0, 0)
	p2.global_position = Vector2(120, 0)
	p1.facing = 1
	p2.percent = 0
	p1.start_move(p1.data.forward_smash)
	await frames(60)
	var kb0 := p2.last_hit_taken.knockback if p2.last_hit_taken else 0.0
	check("fsmash hits dummy", p2.percent > 10, "%.1f%%" % p2.percent)
	await frames(120)
	p2.change_state(&"idle"); p2.global_position = Vector2(120, 0); p2.percent = 100
	p1.global_position = Vector2(0, 0); p1.facing = 1
	p1.change_state(&"idle"); await frames(2)
	p1.start_move(p1.data.forward_smash)
	await frames(20)
	var kb100 := p2.last_hit_taken.knockback
	check("knockback grows with percent", kb100 > kb0 * 1.5, "kb0 %.0f kb100 %.0f" % [kb0, kb100])
	await frames(400)

	# 3. KO at very high percent + respawn.
	fs = await reset(3, 0)
	p1 = fs[0]
	p2 = fs[1]
	p1.global_position = Vector2(600, 0); p1.facing = 1
	p2.global_position = Vector2(760, 0); p2.percent = 250
	var stocks_before := p2.stocks
	p1.start_move(p1.data.forward_smash)
	var ko := false
	for i in 400:
		await frames(1)
		if p2.state_name == &"dead" or p2.state_name == &"respawn":
			ko = true
			break
	check("high-percent smash KOs through blast zone", ko)
	await frames(120)
	check("respawn after KO", p2.state_name in [&"respawn", &"air", &"idle", &"landing"], String(p2.state_name))

	# 4. Ledge: falling next to the ledge grabs it, getup returns to stage.
	fs = await reset(0, 3)
	p1 = fs[0]
	p2 = fs[1]
	p2.global_position = Vector2(-600, 0)
	p1.global_position = Vector2(975, -60)
	p1.velocity = Vector2(-50, 0)
	p1.change_state(&"air")
	drive(p1, [{"frames": 400}])
	var grabbed := false
	for i in 90:
		await frames(1)
		if p1.state_name == &"ledge":
			grabbed = true
			break
	check("falling beside ledge grabs it", grabbed, String(p1.state_name))
	await frames(12)
	drive(p1, [{"frames": 3, "stick": Vector2(-1, 0)}, {"frames": 200}])
	await frames(50)
	check("ledge getup lands on stage", p1.grounded and p1.global_position.x < 932, "%s %s" % [p1.state_name, p1.global_position])

	# 5. Tech: tumbling into the floor with shield pressed just before landing techs.
	fs = await reset(0, 3)
	p1 = fs[0]
	p2 = fs[1]
	p2.global_position = Vector2(-150, -40); p2.facing = 1
	p1.global_position = Vector2(0, -400); p1.percent = 80
	p1.change_state(&"air")
	p1.leave_ground()
	var hit := HitInfo.new()
	hit.attacker = p2
	hit.hitbox = HitboxData.new()
	hit.hitbox.angle = 300  # down-forward spike into the ground
	hit.hitbox.base_knockback = 60
	hit.hitbox.knockback_growth = 60
	hit.damage = 5
	hit.direction = 1
	drive(p1, [{"frames": 400}])
	p1.receive_hit(hit)
	var teched := false
	for i in 120:
		await frames(1)
		if p1.state_name == &"hitstun" and p1.global_position.y > -140 and p1.input_source.t < 300:
			drive(p1, [{"frames": 2, "held": ["shield"]}, {"frames": 200}])
		if p1.state_name == &"dodge":
			teched = true
			break
		if p1.state_name == &"knockdown":
			break
	check("tech on landing with shield press", teched, String(p1.state_name))

	# 6. Missed tech -> knockdown.
	await frames(60)
	p1.global_position = Vector2(0, -400); p1.change_state(&"air"); p1.leave_ground(); await frames(1)
	drive(p1, [{"frames": 400}])
	p1.receive_hit(hit)
	var knocked := false
	for i in 120:
		await frames(1)
		if p1.state_name == &"knockdown":
			knocked = true
			break
	check("missed tech knocks down", knocked, String(p1.state_name))

	# 7. DI changes the launch angle.
	await frames(150)
	var angles := []
	for di in [Vector2.ZERO, Vector2(-1, 1)]:
		p1.change_state(&"idle"); p1.global_position = Vector2(0, 0); p1.percent = 60
		await frames(2)
		drive(p1, [{"frames": 100, "stick": di}])
		var h2 := HitInfo.new()
		h2.attacker = p2
		h2.hitbox = HitboxData.new()
		h2.hitbox.angle = 30; h2.hitbox.base_knockback = 50; h2.hitbox.knockback_growth = 90
		h2.damage = 10; h2.direction = 1
		p1.receive_hit(h2)
		await frames(p1.hitstop + 2)
		angles.append(h2.launch_angle_deg)
		await frames(120)
	check("DI alters trajectory", absf(angles[0] - angles[1]) > 5.0, "no DI %.1f°, DI %.1f°" % angles)

	# 8. Input buffer: attack pressed during landing lag still comes out.
	p1.change_state(&"idle"); p1.global_position = Vector2(0, -60); p1.percent = 0
	p1.velocity = Vector2.ZERO
	p1.change_state(&"air")
	drive(p1, [{"frames": 400}])
	var buffered := false
	for i in 60:
		await frames(1)
		if p1.state_name == &"landing":
			drive(p1, [{"frames": 2, "held": ["attack"]}, {"frames": 200}])
			break
	for i in 20:
		await frames(1)
		if p1.state_name == &"attack":
			buffered = true
			break
	check("attack buffered through landing lag", buffered)

	# 9. Jab chains into jab 2 and 3.
	p1.change_state(&"idle"); await frames(30)
	drive(p1, [{"frames": 2, "held": ["attack"]}, {"frames": 3}, {"frames": 2, "held": ["attack"]}, {"frames": 3}, {"frames": 2, "held": ["attack"]}, {"frames": 3}, {"frames": 2, "held": ["attack"]}, {"frames": 60}])
	var seen := {}
	for i in 60:
		await frames(1)
		if p1.state_name == &"attack":
			seen[p1.state.move.id] = true
	check("jab chains 1-2-3", seen.has(&"jab3"), str(seen.keys()))

	# 10. Smash charge boosts damage.
	p1.change_state(&"idle"); p2.change_state(&"idle")
	p1.global_position = Vector2(0, 0); p2.global_position = Vector2(110, 0); p2.percent = 0; p1.facing = 1
	await frames(2)
	drive(p1, [{"frames": 50, "held": ["strong"]}, {"frames": 100}])
	await frames(90)
	check("charged smash deals extra damage", p2.percent > 17.0, "%.1f%%" % p2.percent)

	# 11. Platform drop-through.
	p1.change_state(&"idle"); p1.global_position = Vector2(-353, -240); p1.velocity = Vector2.ZERO
	p1.change_state(&"air"); drive(p1, [{"frames": 400}])
	await frames(40)
	var on_plat := p1.on_platform
	drive(p1, [{"frames": 3, "stick": Vector2(0, -1)}, {"frames": 200}])
	await frames(40)
	check("stand on platform then drop through", on_plat and p1.global_position.y > -50, "on_plat %s y %.0f" % [on_plat, p1.global_position.y])

	# 12. Recovery: each fighter can return from off-stage below the ledge.
	for ci in Game.roster.characters.size():
		fs = await reset(ci, 3)
		p1 = fs[0]
		p2 = fs[1]
		p2.global_position = Vector2(-600, 0)
		p1.global_position = Vector2(1180, 80)
		p1.velocity = Vector2.ZERO
		p1.change_state(&"air")
		drive(p1, [{"frames": 6, "stick": Vector2(-1, 0)}, {"frames": 3, "stick": Vector2(-1, 0), "held": ["jump"]},
			{"frames": 20, "stick": Vector2(-1, 0)}, {"frames": 3, "stick": Vector2(-0.3, 1), "held": ["special"]}, {"frames": 300, "stick": Vector2(-1, 0)}])
		var safe := false
		for i in 240:
			await frames(1)
			if p1.state_name == &"ledge" or (p1.grounded and absf(p1.global_position.x) < 932):
				safe = true
				break
			if p1.state_name == &"dead":
				break
		check("%s recovers from 250px out, below ledge" % p1.data.display_name, safe, "%s %s" % [p1.state_name, p1.global_position.round()])
