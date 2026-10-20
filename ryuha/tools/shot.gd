extends Node
## Dev helper: renders a scene for N frames and saves screenshots.
## xvfb-run godot --fixed-fps 60 res://tools/shot.tscn -- <mode> <out_prefix> <frames,...> [p1] [p2] [hitboxes]

var mode := "match"
var out := "/tmp/shot"
var shots: Array = [120]
var frame := 0
var node: Node


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var a := OS.get_cmdline_user_args()
	if a.size() > 0: mode = a[0]
	if a.size() > 1: out = a[1]
	if a.size() > 2: shots = Array(a[2].split(",")).map(func(x): return int(x))
	var s := Game.setup
	s.players = [{"character": int(a[3]) if a.size() > 3 else 0, "scheme": &"kb_left", "cpu": true, "cpu_level": 9},
		{"character": int(a[4]) if a.size() > 4 else 1, "scheme": &"kb_right", "cpu": true, "cpu_level": 9}]
	Game.show_hitboxes = a.size() > 5 and a[5] == "1"
	s.reset_progress()
	match mode:
		"menu": node = load("res://scenes/menus/main_menu.tscn").instantiate()
		"versus":
			s.mode = MatchSetup.Mode.VERSUS
			node = load("res://scenes/menus/versus_setup.tscn").instantiate()
		"pause", "results":
			s.mode = MatchSetup.Mode.VERSUS
			node = load("res://scenes/match/match.tscn").instantiate()
		"training":
			s.mode = MatchSetup.Mode.TRAINING
			s.players[0]["cpu"] = true
			node = load("res://scenes/match/match.tscn").instantiate()
		_:
			s.mode = MatchSetup.Mode.VERSUS
			node = load("res://scenes/match/match.tscn").instantiate()
	add_child(node)
	if mode == "training":
		# Let a CPU drive P1 so the training screen shows action.
		var cpu := CpuInput.new()
		cpu.level = 9
		node.fighters[0].input_source = cpu


func _process(_d: float) -> void:
	frame += 1
	if mode == "pause" and frame == shots[0] - 5:
		node.pause_menu.open()
	if mode == "results" and frame == shots[0] - 5:
		Game.setup.wins = [2, 1]
		node._show_results(0)
	if frame in shots:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s_%d.png" % [out, frame])
	if frame >= shots.max() + 2:
		get_tree().quit()
