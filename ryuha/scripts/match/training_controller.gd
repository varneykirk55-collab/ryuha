class_name TrainingController
extends CanvasLayer
## Training mode: dummy behaviour/DI, dummy damage controls, position reset,
## slow motion, and a live readout of combos, knockback and frame data.
##
## Hotkeys (also available from the pause menu):
##   F1 hitboxes · F2 reset positions · F3 dummy behaviour · F4 dummy DI
##   F5 dummy +10% · F6 dummy -10% · F7 game speed · F8 reset dummy %

var match_ref: Match
var dummy: DummyInput
var _info: Label
var _combo_hits := 0
var _combo_damage := 0.0
var _last_line := "Hit the dummy to see knockback data."


func setup(m: Match) -> void:
	match_ref = m
	layer = 11
	dummy = m.fighters[1].input_source as DummyInput
	var panel := PanelContainer.new()
	panel.theme = UIStyle.theme()
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-560, 20)
	panel.custom_minimum_size = Vector2(540, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.06, 0.72)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override(&"panel", style)
	add_child(panel)
	_info = UIStyle.label("", 19, UIStyle.PARCHMENT)
	panel.add_child(_info)


func _process(_d: float) -> void:
	if _info == null:
		return
	var p1 := match_ref.fighters[0]
	var d := match_ref.fighters[1]
	var lines: PackedStringArray = []
	lines.append("TRAINING  ·  speed %s" % ["1x", "1/2x", "", "1/4x"][match_ref.speed_divisor - 1])
	lines.append("Dummy: %s   DI: %s" % [DummyInput.BEHAVIOR_NAMES[dummy.behavior], DummyInput.DI_NAMES[dummy.di_mode]])
	lines.append("Dummy damage: %d%%" % int(d.percent))
	lines.append("")
	lines.append("Combo: %d hits, %.1f%%" % [_combo_hits, _combo_damage])
	lines.append(_last_line)
	lines.append("")
	if p1.state_name == &"attack":
		var a = p1.state
		var m: MoveData = a.move
		lines.append("%s  f%d/%d  (startup %d · active %d-%d)" % [m.display_name, a.frame, m.total_frames(), m.first_active_frame() - 1, m.first_active_frame(), m.last_active_frame()])
		if a.charge_frames > 0:
			lines.append("charge %d  dmg x%.2f" % [a.charge_frames, a.damage_mult])
	else:
		lines.append("P1 state: %s" % p1.state_name)
	lines.append("")
	lines.append("F1 hitboxes  F2 reset  F3 behaviour  F4 DI")
	lines.append("F5/F6 dummy +/-10%  F7 speed  F8 dummy 0%")
	_info.text = "\n".join(lines).replace("·", "|")
	if d.state_name != &"hitstun" and d.state_name != &"knockdown" and d.hitstop == 0 and _combo_hits > 0 and d.state.frame > 30:
		_combo_hits = 0
		_combo_damage = 0.0


func on_hit(_attacker: Fighter, victim: Fighter, hit: HitInfo, result: int) -> void:
	if victim != match_ref.fighters[1]:
		return
	if result != Fighter.HitResult.HIT:
		_last_line = "Blocked / absorbed (%.1f dmg)" % hit.damage
		return
	_combo_hits = victim.combo_count
	if _combo_hits <= 1:
		_combo_damage = 0.0
	_combo_damage += hit.damage
	_last_line = "Last: %.1f dmg | KB %.0f | hitstun %d f | %s" % [hit.damage, hit.knockback, hit.hitstun_frames, "TUMBLE" if hit.knockback >= Game.config.tumble_threshold else "flinch"]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.physical_keycode:
		KEY_F2: reset_positions()
		KEY_F3: cycle_behavior()
		KEY_F4: cycle_di()
		KEY_F5: add_dummy_percent(10)
		KEY_F6: add_dummy_percent(-10)
		KEY_F7: cycle_speed()
		KEY_F8: set_dummy_percent(0)
		_: return
	get_viewport().set_input_as_handled()


func reset_positions() -> void:
	var keep := match_ref.fighters[1].percent
	match_ref.start_round()
	set_dummy_percent(keep)


func cycle_behavior() -> void:
	dummy.behavior = ((dummy.behavior + 1) % DummyInput.BEHAVIOR_NAMES.size()) as DummyInput.Behavior


func cycle_di() -> void:
	dummy.di_mode = ((dummy.di_mode + 1) % DummyInput.DI_NAMES.size()) as DummyInput.DI


func add_dummy_percent(v: float) -> void:
	set_dummy_percent(clampf(match_ref.fighters[1].percent + v, 0.0, 999.0))


func set_dummy_percent(v: float) -> void:
	var d := match_ref.fighters[1]
	d.percent = v
	d.percent_changed.emit(d)


func cycle_speed() -> void:
	match_ref.speed_divisor = {1: 2, 2: 4, 4: 1}[match_ref.speed_divisor]


## Entries for the pause menu: label (Callable -> String) + action (Callable).
func menu_options() -> Array:
	return [
		{"label": func(): return "Dummy: %s  (F3)" % DummyInput.BEHAVIOR_NAMES[dummy.behavior], "action": cycle_behavior},
		{"label": func(): return "Dummy DI: %s  (F4)" % DummyInput.DI_NAMES[dummy.di_mode], "action": cycle_di},
		{"label": func(): return "Dummy damage +10%%  (now %d%%)" % int(match_ref.fighters[1].percent), "action": func(): add_dummy_percent(10)},
		{"label": func(): return "Dummy damage -10%%  (now %d%%)" % int(match_ref.fighters[1].percent), "action": func(): add_dummy_percent(-10)},
		{"label": func(): return "Game speed: %s  (F7)" % {1: "1x", 2: "1/2x", 4: "1/4x"}[match_ref.speed_divisor], "action": cycle_speed},
		{"label": func(): return "Reset positions  (F2)", "action": func():
			reset_positions()
			match_ref.pause_menu.close()},
	]
