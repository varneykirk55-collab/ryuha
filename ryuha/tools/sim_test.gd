extends Node
## Headless smoke test: CPU vs CPU versus set. Reports KOs, rounds, errors.
## godot --headless --fixed-fps 60 res://tools/sim_test.tscn

var m: Match
var frames := 0
var kos := 0
var hits := 0
var states_seen := {}
var moves_seen := {}
@export var max_frames := 60 * 240
@export var p1 := 0
@export var p2 := 3


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2:
		p1 = int(args[0]); p2 = int(args[1])
	var stocks := int(args[2]) if args.size() > 2 else 2
	var secs := int(args[3]) if args.size() > 3 else 90
	var lvl := int(args[4]) if args.size() > 4 else 9
	var s := Game.setup
	s.mode = MatchSetup.Mode.VERSUS
	s.players = [{"character": p1, "scheme": &"kb_left", "cpu": true, "cpu_level": lvl},
		{"character": p2, "scheme": &"kb_right", "cpu": true, "cpu_level": lvl}]
	s.stocks = stocks
	s.time_seconds = secs
	s.reset_progress()
	m = load("res://scenes/match/match.tscn").instantiate()
	add_child(m)
	for f in m.fighters:
		f.knocked_out.connect(func(x): kos += 1; print("[f%d] KO: %s  (stocks left %d)" % [frames, x.data.display_name, x.stocks]))
	m.resolver.hit_resolved.connect(func(a, v, h, r): hits += 1)
	m.round_finished.connect(func(w): print("[f%d] ROUND OVER winner=%d wins=%s" % [frames, w, str(s.wins)]))
	m.resolver.clanked.connect(func(a, b, p): print("[f%d] clank" % frames))


func _physics_process(_d: float) -> void:
	frames += 1
	for f in m.fighters:
		states_seen[f.state_name] = true
		if f.state_name == &"attack":
			moves_seen[f.state.move.id] = true
	if m.sudden_death and frames % 120 == 0:
		print("[f%d] sudden death round: %.0f%% vs %.0f%%, stocks %d/%d" % [frames, m.fighters[0].percent, m.fighters[1].percent, m.fighters[0].stocks, m.fighters[1].stocks])
	if frames % 600 == 0:
		var f0 := m.fighters[0]
		var f1 := m.fighters[1]
		print("[f%d] %s %.0f%% %s @%s | %s %.0f%% %s @%s | phase %d" % [frames, f0.data.display_name, f0.percent, f0.state_name, f0.global_position.round(),
			f1.data.display_name, f1.percent, f1.state_name, f1.global_position.round(), m.phase])
	if frames >= max_frames or m.phase == Match.Phase.MATCH_OVER:
		print("DONE frames=%d hits=%d kos=%d wins=%s" % [frames, hits, kos, str(Game.setup.wins)])
		print("states: ", states_seen.keys())
		print("moves: ", moves_seen.keys())
		get_tree().quit()
