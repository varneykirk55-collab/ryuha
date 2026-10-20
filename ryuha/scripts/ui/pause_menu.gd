class_name PauseMenu
extends CanvasLayer
## Pause overlay (Esc / Start / Backspace). Pauses the scene tree; this layer keeps
## processing. In training it also exposes the training options.

var match_ref: Match
var _root: Control
var _list: VBoxContainer
var _first: Button
var _open_frame := 0


func setup(m: Match) -> void:
	match_ref = m
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(640, 0)
	_root.add_child(panel)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override(&"separation", 10)
	panel.add_child(_list)
	_root.visible = false


func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	_list.add_child(UIStyle.label("PAUSED", 56, UIStyle.PARCHMENT))
	_first = UIStyle.button("Resume", close)
	_list.add_child(_first)
	if match_ref.training:
		for opt in match_ref.training.menu_options():
			var b := UIStyle.button(opt["label"].call(), func(): pass)
			var label_fn: Callable = opt["label"]
			var action: Callable = opt["action"]
			b.pressed.connect(func():
				action.call()
				b.text = label_fn.call())
			_list.add_child(b)
	var hb := UIStyle.button("Hitbox view: %s  (F1)" % ("ON" if Game.show_hitboxes else "OFF"), func(): pass)
	hb.pressed.connect(func():
		Game.toggle_hitboxes()
		hb.text = "Hitbox view: %s  (F1)" % ("ON" if Game.show_hitboxes else "OFF"))
	_list.add_child(hb)
	if not match_ref.is_training():
		_list.add_child(UIStyle.button("Restart set", func():
			Game.setup.reset_progress()
			Game.goto(Game.SCENE_MATCH)))
	_list.add_child(UIStyle.button("Change fighters", func(): Game.goto(Game.SCENE_VERSUS)))
	_list.add_child(UIStyle.button("Main menu", func(): Game.goto(Game.SCENE_MAIN_MENU)))
	var help := UIStyle.label(_controls_help(), 18, UIStyle.MUTED)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(600, 0)
	_list.add_child(help)


func _controls_help() -> String:
	var lines: PackedStringArray = []
	for f in match_ref.fighters:
		if f.input_source is DeviceInput:
			lines.append("P%d: %s" % [f.port + 1, f.input_source.scheme["help"]])
	return "\n".join(lines)


func open() -> void:
	if _root.visible:
		return
	_rebuild()
	_root.visible = true
	get_tree().paused = true
	_open_frame = Engine.get_process_frames()
	_first.call_deferred(&"grab_focus")


func close() -> void:
	_root.visible = false
	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not _root.visible:
		return
	if Engine.get_process_frames() - _open_frame < 5:
		return
	var is_pause_key: bool = event is InputEventKey and event.pressed and not event.echo \
		and event.physical_keycode in [KEY_ESCAPE, KEY_BACKSPACE]
	var is_start: bool = event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_START
	if is_pause_key or is_start:
		close()
		get_viewport().set_input_as_handled()
