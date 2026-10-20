extends Control
## Versus / Training setup: pick fighters, controls, CPU, stocks and time.
## Everything is a focusable Cycler, so one keyboard or any gamepad can drive it.

var _cols: Array = []          # per player: {char, scheme, type, portrait, name, info}
var _stocks: Cycler
var _time: Cycler
var _warning: Label
var _start: Button

const STOCK_OPTIONS := [1, 2, 3, 4, 5]
const TIME_OPTIONS := [0, 120, 180, 240, 300, 420]
const CPU_LEVELS := ["Human", "CPU Lv 3", "CPU Lv 5", "CPU Lv 7", "CPU Lv 9"]


func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	preload("res://scripts/ui/main_menu.gd")._add_background(self)
	var training := Game.setup.mode == MatchSetup.Mode.TRAINING

	var title := UIStyle.label("TRAINING SETUP" if training else "VERSUS SETUP", 64, UIStyle.PARCHMENT, 10)
	title.position = Vector2(80, 40)
	add_child(title)

	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 40)
	row.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	row.position = Vector2(-880, -380)
	add_child(row)
	for i in 2:
		_cols.append(_make_player_column(row, i, training))

	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override(&"separation", 24)
	bottom.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	bottom.position = Vector2(-880, -170)
	add_child(bottom)
	if not training:
		_stocks = Cycler.new("Stocks", PackedStringArray(STOCK_OPTIONS.map(func(v): return str(v))), STOCK_OPTIONS.find(Game.setup.stocks))
		_stocks.custom_minimum_size = Vector2(340, 0)
		bottom.add_child(_stocks)
		_time = Cycler.new("Time", PackedStringArray(TIME_OPTIONS.map(func(v): return "Off" if v == 0 else "%d:%02d" % [v / 60, v % 60])), maxi(TIME_OPTIONS.find(Game.setup.time_seconds), 0))
		_time.custom_minimum_size = Vector2(340, 0)
		bottom.add_child(_time)
	_start = UIStyle.button("START  (best of 3)" if not training else "START TRAINING", _on_start)
	_start.custom_minimum_size = Vector2(420, 0)
	bottom.add_child(_start)
	bottom.add_child(UIStyle.button("Back", func(): Game.goto(Game.SCENE_MAIN_MENU)))

	_warning = UIStyle.label("", 24, Color(1, 0.5, 0.4), 6)
	_warning.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_warning.position = Vector2(-880, -100)
	_warning.size = Vector2(1760, 40)
	add_child(_warning)

	for c in _cols:
		_refresh_column(c)
	_validate()
	_cols[0]["char"].call_deferred(&"grab_focus")


func _make_player_column(parent: Control, i: int, training: bool) -> Dictionary:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(860, 640)
	panel.size_flags_horizontal = Control.SIZE_FILL
	parent.add_child(panel)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	panel.add_child(col)
	var header := "PLAYER 1" if i == 0 else ("DUMMY" if training else "PLAYER 2")
	col.add_child(UIStyle.label(header, 30, [Color(0.95, 0.4, 0.35), Color(0.45, 0.65, 1.0)][i]))

	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 18)
	col.add_child(body)
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(300, 330)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	body.add_child(portrait)
	var text := VBoxContainer.new()
	text.custom_minimum_size = Vector2(500, 0)
	body.add_child(text)
	var name_l := UIStyle.label("", 52, UIStyle.PARCHMENT, 6)
	text.add_child(name_l)
	var title_l := UIStyle.label("", 24, UIStyle.GOLD)
	text.add_child(title_l)
	var info := UIStyle.label("", 20, UIStyle.MUTED)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(500, 0)
	text.add_child(info)

	var names := PackedStringArray()
	for cd in Game.roster.characters:
		names.append(cd.display_name)
	var slot: Dictionary = Game.setup.players[i]
	var c_char := Cycler.new("Fighter", names, int(slot["character"]))
	col.add_child(c_char)

	var c_scheme: Cycler = null
	var c_type: Cycler = null
	if not (training and i == 1):
		var schemes := PackedStringArray()
		for s in ControlSchemes.all():
			var label: String = s["name"]
			if s["kind"] == ControlSchemes.Kind.GAMEPAD:
				var dev: int = s["device"]
				label += "  (%s)" % (Input.get_joy_name(dev) if dev in Input.get_connected_joypads() else "not connected")
			schemes.append(label)
		c_scheme = Cycler.new("Controls", schemes, ControlSchemes.index_of(slot["scheme"]))
		col.add_child(c_scheme)
	if i == 1 and not training:
		var lvl := int(slot.get("cpu_level", 5))
		c_type = Cycler.new("Player", PackedStringArray(CPU_LEVELS), 0 if not slot.get("cpu", false) else clampi((lvl - 1) / 2, 1, 4))
		col.add_child(c_type)

	for cy in [c_char, c_scheme, c_type]:
		if cy:
			cy.clip_text = true
			cy.custom_minimum_size = Vector2(810, 0)
	var d := {"i": i, "char": c_char, "scheme": c_scheme, "type": c_type, "portrait": portrait, "name": name_l, "title": title_l, "info": info}
	c_char.changed.connect(func(_x):
		_refresh_column(d)
		_validate())
	if c_scheme:
		c_scheme.changed.connect(func(_x): _validate())
	if c_type:
		c_type.changed.connect(func(_x): _validate())
	return d


func _refresh_column(d: Dictionary) -> void:
	var cd: CharacterData = Game.roster.characters[d["char"].index]
	# Full-body crop of the idle frame (frames share a wide canvas for weapon reach).
	var idle: Texture2D = cd.sprite_frames.get_frame_texture(&"idle", 0) if cd.sprite_frames else null
	if idle:
		var crop := AtlasTexture.new()
		crop.atlas = idle
		crop.region = Rect2(cd.sprite_foot.x - 125.0, 0, 250.0, cd.sprite_foot.y + 4.0)
		d["portrait"].texture = crop
	d["name"].text = cd.display_name.to_upper()
	d["title"].text = cd.title
	var sig: MoveData = cd.get_move(cd.signature_slot)
	d["info"].text = "%s\n\nWeight %d  |  Run %d  |  Jump %d\nSignature: %s" % [
		cd.description, int(cd.weight), int(cd.run_speed), int(cd.full_hop_height),
		sig.display_name if sig else "-"]
	d["name"].add_theme_color_override(&"font_color", cd.accent_color.lightened(0.4))


func _validate() -> void:
	var msg := ""
	var a = _cols[0]["scheme"]
	var b = _cols[1]["scheme"]
	var p2_cpu: bool = _cols[1]["type"] != null and _cols[1]["type"].index > 0
	if a and b and not p2_cpu:
		var sa: Dictionary = ControlSchemes.all()[a.index]
		var sb: Dictionary = ControlSchemes.all()[b.index]
		if sa["id"] == sb["id"]:
			msg = "Both players are using the same controls - pick different ones."
		elif sa["kind"] == ControlSchemes.Kind.KEYBOARD and sb["kind"] == ControlSchemes.Kind.KEYBOARD \
				and (sa["id"] == &"kb_solo" or sb["id"] == &"kb_solo"):
			msg = "Tip: for two players on one keyboard use 'Keyboard L' + 'Keyboard R'."
	_warning.text = msg
	_start.disabled = msg.begins_with("Both")


func _on_start() -> void:
	if _start.disabled:
		return
	var training := Game.setup.mode == MatchSetup.Mode.TRAINING
	for c in _cols:
		var slot: Dictionary = Game.setup.players[c["i"]]
		slot["character"] = c["char"].index
		if c["scheme"]:
			slot["scheme"] = ControlSchemes.all()[c["scheme"].index]["id"]
		slot["cpu"] = false
		if c["type"] and c["type"].index > 0:
			slot["cpu"] = true
			slot["cpu_level"] = [0, 3, 5, 7, 9][c["type"].index]
	if not training:
		Game.setup.stocks = STOCK_OPTIONS[_stocks.index]
		Game.setup.time_seconds = TIME_OPTIONS[_time.index]
		Game.start_versus()
	else:
		Game.start_training()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		Game.goto(Game.SCENE_MAIN_MENU)
