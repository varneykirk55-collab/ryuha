class_name Hud
extends CanvasLayer
## In-match HUD: per-player damage %, stocks and portrait; timer; round score;
## centre banners ("ROUND 1", "FIGHT!", "GAME!").

var match_ref: Match
var _cards: Array = []       # [{percent: Label, stocks: StockIcons, name: Label, root}]
var _timer_label: Label
var _round_label: Label
var _banner: Label
var _sub_banner: Label
var _banner_frames := 0
var _shown_percent: Array[float] = [0.0, 0.0]


func setup(m: Match) -> void:
	match_ref = m
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = UIStyle.theme()
	add_child(root)

	_timer_label = UIStyle.label("", 52, UIStyle.PARCHMENT, 10)
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_timer_label.position = Vector2(-150, 18)
	_timer_label.size = Vector2(300, 60)
	root.add_child(_timer_label)
	_round_label = UIStyle.label("", 24, UIStyle.MUTED, 8)
	_round_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_round_label.position = Vector2(-300, 82)
	_round_label.size = Vector2(600, 34)
	root.add_child(_round_label)

	_banner = UIStyle.label("", 132, Color(1, 0.96, 0.88), 22)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = Vector2(-800, -150)
	_banner.size = Vector2(1600, 170)
	root.add_child(_banner)
	_sub_banner = UIStyle.label("", 40, UIStyle.GOLD, 10)
	_sub_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_sub_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sub_banner.position = Vector2(-800, 20)
	_sub_banner.size = Vector2(1600, 60)
	root.add_child(_sub_banner)

	for i in m.fighters.size():
		_cards.append(_make_card(root, m.fighters[i], i))
	refresh_all()


func _make_card(root: Control, f: Fighter, i: int) -> Dictionary:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.custom_minimum_size = Vector2(420, 150)
	panel.position = Vector2((-560 if i == 0 else 140), -190)
	panel.size = Vector2(420, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.05, 0.05, 0.78)
	style.border_color = f.port_color
	style.border_width_bottom = 6
	style.set_corner_radius_all(6)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override(&"panel", style)
	root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	panel.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = f.data.portrait
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if f.port == 1 and f.sprite.material:
		portrait.modulate = (f.sprite.material as ShaderMaterial).get_shader_parameter(&"tint")
	row.add_child(portrait)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 0)
	row.add_child(col)
	var tag := "CPU" if f.input_source is CpuInput else ("DUMMY" if f.input_source is DummyInput else "P%d" % (f.port + 1))
	var name_l := UIStyle.label("%s  %s" % [tag, f.data.display_name.to_upper()], 24, f.port_color.lightened(0.35), 6)
	col.add_child(name_l)
	var pct := UIStyle.label("0%", 72, Color.WHITE, 12)
	col.add_child(pct)
	var stocks := StockIcons.new()
	stocks.color = f.data.accent_color
	stocks.custom_minimum_size = Vector2(200, 22)
	col.add_child(stocks)
	return {"percent": pct, "stocks": stocks, "name": name_l, "fighter": f}


func refresh_all() -> void:
	for c in _cards:
		var f: Fighter = c["fighter"]
		c["stocks"].count = -1 if f.infinite_stocks else f.stocks
		c["stocks"].queue_redraw()
	var s := match_ref.setup
	if match_ref.is_training():
		_round_label.text = "TRAINING"
	else:
		_round_label.text = "Round %d   |   %d - %d   |   first to %d" % [s.round_number, s.wins[0], s.wins[1], s.rounds_to_win]


func tick() -> void:
	# Percent counts up quickly and shakes/reddens with damage.
	for i in _cards.size():
		var c: Dictionary = _cards[i]
		var f: Fighter = c["fighter"]
		var target := f.percent
		var shown := _shown_percent[i]
		var jumped := target > shown + 0.5
		shown = move_toward(shown, target, maxf(absf(target - shown) * 0.35, 1.0)) if jumped or target < shown else target
		_shown_percent[i] = shown
		var lbl: Label = c["percent"]
		lbl.text = "%d%%" % int(round(shown))
		var t := clampf(shown / 160.0, 0.0, 1.0)
		var col := Color.WHITE.lerp(Color(1.0, 0.62, 0.25), clampf(t * 2.0, 0.0, 1.0)).lerp(Color(0.85, 0.1, 0.1), clampf(t * 2.0 - 1.0, 0.0, 1.0))
		lbl.add_theme_color_override(&"font_color", col)
		lbl.position.x = randf_range(-4, 4) if jumped else 0.0
		if f.state_name == &"dead":
			lbl.text = "KO"
	var tf := match_ref.timer_frames
	if match_ref.is_training() or (match_ref.sudden_death and tf == 0):
		_timer_label.text = ""
	elif match_ref.setup.time_seconds > 0:
		var secs := int(ceil(tf / 60.0))
		_timer_label.text = "%d:%02d" % [secs / 60, secs % 60]
		_timer_label.add_theme_color_override(&"font_color", Color(1, 0.4, 0.3) if secs <= 10 else UIStyle.PARCHMENT)
	if _banner_frames > 0:
		_banner_frames -= 1
		var a := clampf(_banner_frames / 12.0, 0.0, 1.0)
		_banner.modulate.a = a
		_sub_banner.modulate.a = a
		if _banner_frames == 0:
			_banner.text = ""
			_sub_banner.text = ""


func show_banner(text: String, sub: String, frames: int) -> void:
	_banner.text = text
	_sub_banner.text = sub
	_banner_frames = frames
	_banner.modulate.a = 1.0
	_sub_banner.modulate.a = 1.0


class StockIcons:
	extends Control
	var count: int = 3
	var color: Color = Color.WHITE

	func _draw() -> void:
		if count < 0:
			draw_string(ThemeDB.fallback_font, Vector2(0, 18), "infinite stocks", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, UIStyle.MUTED)
			return
		for i in count:
			var c := Vector2(11 + i * 26, 11)
			draw_circle(c, 9, color)
			draw_arc(c, 9, 0, TAU, 20, Color(0, 0, 0, 0.8), 2.0)
