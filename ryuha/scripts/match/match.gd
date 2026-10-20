class_name Match
extends Node2D
## Runs a versus set (best of N rounds) or a training session.
##
## Owns the fixed-step game loop: every physics tick (60 Hz) it advances all
## fighters, projectiles and effects in a fixed order, resolves combat, checks
## blast zones and the round rules. Fighters never tick themselves, which keeps
## hitstop, slow motion and pause trivial and deterministic.

signal round_finished(winner_port: int)

enum Phase { INTRO, FIGHT, ROUND_OVER, MATCH_OVER }

const FIGHTER_BASE := "res://scenes/fighters/fighter_base.tscn"
const INTRO_FRAMES := 110
const ROUND_OVER_FRAMES := 170

var setup: MatchSetup
var stage: Stage
var fighters: Array[Fighter] = []
var projectiles: Array = []
var effects: Array = []
var resolver := CombatResolver.new()
var camera: FightCamera
var hud: Hud
var pause_menu: PauseMenu
var training: TrainingController

var frame: int = 0
var phase: Phase = Phase.INTRO
var phase_frame: int = 0
var timer_frames: int = 0
var sudden_death := false
var speed_divisor: int = 1      ## training slow-motion (1, 2, 4)
var _slow_mo := 0               ## game-end slow motion frames
var _sub_tick := 0

@onready var world: Node2D = $World
@onready var effects_layer: Node2D = $World/Effects
@onready var fighters_layer: Node2D = $World/Fighters


func _ready() -> void:
	setup = Game.setup
	process_mode = Node.PROCESS_MODE_PAUSABLE
	_build_stage()
	_build_fighters()
	camera = FightCamera.new()
	camera.bounds = stage.camera_bounds
	camera.targets = fighters
	world.add_child(camera)
	hud = Hud.new()
	add_child(hud)
	hud.setup(self)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(self)
	if is_training():
		training = TrainingController.new()
		add_child(training)
		training.setup(self)
	resolver.hit_resolved.connect(_on_hit_resolved)
	resolver.clanked.connect(_on_clank)
	start_round()
	camera.snap()


func is_training() -> bool:
	return setup.mode == MatchSetup.Mode.TRAINING


# --- Construction ------------------------------------------------------------------

func _build_stage() -> void:
	var packed: PackedScene = load(setup.stage_path)
	stage = packed.instantiate()
	world.add_child(stage)
	world.move_child(stage, 0)


func _build_fighters() -> void:
	var roster := Game.roster
	for i in 2:
		var slot: Dictionary = setup.players[i]
		var cdata: CharacterData = roster.characters[clampi(int(slot["character"]), 0, roster.characters.size() - 1)]
		var path := cdata.scene_path if cdata.scene_path != "" else FIGHTER_BASE
		var f: Fighter = (load(path) as PackedScene).instantiate()
		fighters_layer.add_child(f)
		var src: InputSource
		if is_training() and i == 1:
			src = DummyInput.new()
		elif bool(slot.get("cpu", false)):
			var cpu := CpuInput.new()
			cpu.level = int(slot.get("cpu_level", 5))
			src = cpu
		else:
			src = DeviceInput.new(slot["scheme"])
		var tint := Color.WHITE
		if i == 1 and int(setup.players[0]["character"]) == int(slot["character"]):
			tint = cdata.alt_tint
		f.setup(cdata, i, src, self, tint)
		f.knocked_out.connect(_on_fighter_ko)
		fighters.append(f)


# --- Round flow -------------------------------------------------------------------

func start_round() -> void:
	for p in projectiles:
		p.queue_free()
	projectiles.clear()
	for i in fighters.size():
		var f := fighters[i]
		f.reset_for_round(stage.spawn_point(i), 1 if i == 0 else -1)
		f.stocks = 1 if sudden_death else setup.stocks
		f.infinite_stocks = is_training()
		if sudden_death:
			f.percent = Game.config.sudden_death_percent
		f.frozen = not is_training()
		f.percent_changed.emit(f)
		f.stocks_changed.emit(f)
	timer_frames = 0 if (is_training() or sudden_death) else setup.time_seconds * 60
	phase = Phase.FIGHT if is_training() else Phase.INTRO
	phase_frame = 0
	_slow_mo = 0
	if not is_training():
		var label := "SUDDEN DEATH" if sudden_death else "ROUND %d" % setup.round_number
		hud.show_banner(label, "", 70)
		Sfx.play(&"round_start")
	hud.refresh_all()


func _physics_process(_delta: float) -> void:
	# Training slow motion: only advance every Nth physics tick.
	_sub_tick += 1
	if _sub_tick % speed_divisor != 0:
		return
	# End-of-game slow motion.
	if _slow_mo > 0:
		_slow_mo -= 1
		if _slow_mo % 3 != 0:
			return
	frame += 1
	phase_frame += 1
	match phase:
		Phase.INTRO:
			_tick_fighters()
			if phase_frame == 70:
				hud.show_banner("FIGHT!", "", 40)
			if phase_frame >= INTRO_FRAMES:
				phase = Phase.FIGHT
				phase_frame = 0
				for f in fighters:
					f.frozen = false
		Phase.FIGHT:
			_tick_game()
			_check_pause()
			if timer_frames > 0:
				timer_frames -= 1
				if timer_frames == 0:
					_on_time_up()
		Phase.ROUND_OVER:
			_tick_game()
			if phase_frame >= ROUND_OVER_FRAMES:
				_next_round()
		Phase.MATCH_OVER:
			_tick_fighters()
	hud.tick()


func _tick_fighters() -> void:
	for f in fighters:
		f.tick(frame)


func _tick_game() -> void:
	_tick_fighters()
	for p in projectiles.duplicate():
		if not p.tick():
			projectiles.erase(p)
			p.queue_free()
	resolver.resolve(fighters, projectiles)
	_push_apart()
	for f in fighters:
		if f.state_name != &"dead" and stage.is_outside_blast_zone(f.global_position):
			_ko_effect(f)
			f.ko()
	for e in effects.duplicate():
		if not e.tick():
			effects.erase(e)
			e.queue_free()


func _check_pause() -> void:
	for f in fighters:
		if f.input_source is DeviceInput and f.input.pause_pressed:
			pause_menu.open()
			return


## Grounded fighters overlapping each other are gently separated.
func _push_apart() -> void:
	if fighters.size() < 2:
		return
	var a := fighters[0]
	var b := fighters[1]
	if not (a.grounded and b.grounded) or not a.visible or not b.visible:
		return
	if a.state_name in [&"dodge", &"ledge"] or b.state_name in [&"dodge", &"ledge"]:
		return
	var dx := b.global_position.x - a.global_position.x
	var min_d := (a.data.collision_size.x + b.data.collision_size.x) * 0.5
	if absf(dx) < min_d and absf(b.global_position.y - a.global_position.y) < 60:
		var push := signf(dx) if absf(dx) > 0.5 else (1.0 if a.facing < 0 else -1.0)
		a.global_position.x -= push * 3.0
		b.global_position.x += push * 3.0


func _on_fighter_ko(f: Fighter) -> void:
	Sfx.play(&"ko", f.global_position)
	add_shake(0.75)
	hud.refresh_all()
	if is_training() or phase != Phase.FIGHT:
		return
	var alive: Array[Fighter] = []
	for g in fighters:
		if not g.eliminated:
			alive.append(g)
	if alive.size() <= 1:
		_end_round(alive[0].port if alive.size() == 1 else -1)


func _on_time_up() -> void:
	var a := fighters[0]
	var b := fighters[1]
	if a.stocks == b.stocks:
		hud.show_banner("TIME!", "Sudden death", 90)
		sudden_death = true
		phase = Phase.ROUND_OVER
		phase_frame = ROUND_OVER_FRAMES - 100
		for f in fighters:
			f.frozen = true
		return
	_end_round(0 if a.stocks > b.stocks else 1, "TIME!")


func _end_round(winner: int, title: String = "GAME!") -> void:
	phase = Phase.ROUND_OVER
	phase_frame = 0
	_slow_mo = 60
	sudden_death = false
	if winner >= 0:
		setup.wins[winner] += 1
		var winner_name := fighters[winner].data.display_name
		hud.show_banner(title, "%s takes the round" % winner_name, 150)
	round_finished.emit(winner)


func _next_round() -> void:
	if sudden_death:
		start_round()
		return
	for i in setup.wins.size():
		if setup.wins[i] >= setup.rounds_to_win:
			_show_results(i)
			return
	setup.round_number += 1
	start_round()


func _show_results(winner: int) -> void:
	phase = Phase.MATCH_OVER
	for f in fighters:
		f.frozen = true
	var results := ResultsScreen.new()
	add_child(results)
	results.setup(self, winner)


# --- Effects & spawning (called by fighters) -----------------------------------

func get_opponent(f: Fighter) -> Fighter:
	for g in fighters:
		if g != f:
			return g
	return null


func spawn_projectile(owner: Fighter, beh: ProjectileBehavior) -> void:
	var p := Projectile.new()
	effects_layer.add_child(p)
	p.setup(owner, beh, stage.floor_y, (stage.floor_right - stage.floor_left) * 0.5)
	projectiles.append(p)


func spawn_trail(f: Fighter, move: MoveData) -> void:
	var t := SlashTrail.new()
	effects_layer.add_child(t)
	t.setup(f, move)
	effects.append(t)


func add_shake(amount: float) -> void:
	if camera:
		camera.add_trauma(amount)


func _on_hit_resolved(attacker: Fighter, victim: Fighter, hit: HitInfo, result: int) -> void:
	var cfg := Game.config
	if result == Fighter.HitResult.HIT:
		var strong := hit.knockback >= cfg.strong_hit_kb
		var spark := HitSpark.new()
		effects_layer.add_child(spark)
		spark.setup(hit.position, hit.knockback, strong, attacker.data.accent_color.lightened(0.5))
		effects.append(spark)
		var sfx := hit.hitbox.hit_sfx
		if sfx == &"":
			sfx = &"hit_heavy" if (strong or hit.damage >= 12.0) else &"hit_light"
		Sfx.play(sfx, hit.position)
		if hit.knockback > cfg.shake_kb_floor:
			add_shake((hit.knockback - cfg.shake_kb_floor) * cfg.shake_per_kb)
		if strong:
			add_shake(0.25)
	if training:
		training.on_hit(attacker, victim, hit, result)
	hud.refresh_all()


func _on_clank(_a: Fighter, _b: Fighter, point: Vector2) -> void:
	Sfx.play(&"clank", point)
	var spark := HitSpark.new()
	effects_layer.add_child(spark)
	spark.setup(point, 60.0, false, Color(0.8, 0.9, 1.0))
	effects.append(spark)
	add_shake(0.15)


func _ko_effect(f: Fighter) -> void:
	var b := stage.blast_zone
	var p := f.global_position
	p.x = clampf(p.x, b.position.x, b.end.x)
	p.y = clampf(p.y, b.position.y, b.end.y)
	var k := KoBurst.new()
	effects_layer.add_child(k)
	k.setup(p, stage.camera_bounds.get_center(), f.port_color.lightened(0.4))
	effects.append(k)
