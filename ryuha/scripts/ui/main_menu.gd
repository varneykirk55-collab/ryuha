extends Control
## Title screen: Versus · Training · Controls · Quit.

var _controls_panel: PanelContainer
var _menu: VBoxContainer


func _ready() -> void:
	theme = UIStyle.theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_add_background(self)

	var title := UIStyle.label("RYŪHA", 150, UIStyle.PARCHMENT, 18)
	title.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(-700, 70)
	title.size = Vector2(1400, 180)
	add_child(title)
	var sub := UIStyle.label("CLASH OF SCHOOLS  -  ritual combat of the rival clans", 32, UIStyle.GOLD, 8)
	sub.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.position = Vector2(-700, 250)
	sub.size = Vector2(1400, 50)
	add_child(sub)

	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 14)
	_menu.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_menu.position = Vector2(-220, -60)
	_menu.custom_minimum_size = Vector2(440, 0)
	add_child(_menu)
	var versus := UIStyle.button("Versus", func():
		Game.setup.mode = MatchSetup.Mode.VERSUS
		Game.goto(Game.SCENE_VERSUS))
	_menu.add_child(versus)
	_menu.add_child(UIStyle.button("Training", func():
		Game.setup.mode = MatchSetup.Mode.TRAINING
		Game.goto(Game.SCENE_VERSUS)))
	_menu.add_child(UIStyle.button("Controls", _toggle_controls))
	_menu.add_child(UIStyle.button("Quit", func(): get_tree().quit()))

	var foot := UIStyle.label("F1 toggles hitbox view anywhere  |  Arrows/D-pad + Enter/A to navigate", 22, UIStyle.MUTED, 6)
	foot.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	foot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	foot.position = Vector2(-700, -70)
	foot.size = Vector2(1400, 40)
	add_child(foot)

	_controls_panel = PanelContainer.new()
	_controls_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_controls_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_controls_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_controls_panel.custom_minimum_size = Vector2(1280, 0)
	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 10)
	_controls_panel.add_child(col)
	col.add_child(UIStyle.label("CONTROLS", 44))
	for s in ControlSchemes.all():
		if s["kind"] == ControlSchemes.Kind.GAMEPAD and s["device"] > 0:
			continue
		var l := UIStyle.label("%s\n    %s" % [s["name"], s["help"]], 22, UIStyle.PARCHMENT)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
	var tips := UIStyle.label(
		"Tilt = attack + direction.  Smash = smash key, right stick, or flick + attack (hold to charge).\n" +
		"Specials = special + direction (up = recovery).  Shield in the air = air dodge.\n" +
		"Tech: press shield just before hitting the ground while tumbling (hold left/right to tech-roll).\n" +
		"Drop through platforms: tap down.  Fast fall: tap down after your jump peaks.\n" +
		"DI: hold a direction as you are launched to bend your trajectory.", 22, UIStyle.GOLD)
	tips.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(tips)
	var back := UIStyle.button("Back", _toggle_controls)
	col.add_child(back)
	_controls_panel.visible = false
	add_child(_controls_panel)

	versus.call_deferred(&"grab_focus")


func _toggle_controls() -> void:
	_controls_panel.visible = not _controls_panel.visible
	_menu.visible = not _controls_panel.visible
	if _controls_panel.visible:
		_controls_panel.get_child(0).get_child(-1).call_deferred(&"grab_focus")
	else:
		_menu.get_child(2).call_deferred(&"grab_focus")


static func _add_background(parent: Control) -> void:
	var bg := TextureRect.new()
	bg.texture = preload("res://assets/stages/dojo/dojo_reference.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.modulate = Color(0.45, 0.42, 0.4)
	parent.add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.04, 0.03, 0.03, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(shade)


func _unhandled_input(event: InputEvent) -> void:
	if _controls_panel.visible and event.is_action_pressed(&"ui_cancel"):
		_toggle_controls()
