class_name ResultsScreen
extends CanvasLayer
## End-of-set screen: winner, score, rematch / change fighters / main menu.

func setup(m: Match, winner: int) -> void:
	layer = 15
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	add_child(root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(760, 0)
	root.add_child(panel)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override(&"separation", 14)
	panel.add_child(col)
	var f := m.fighters[winner]
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 24)
	col.add_child(row)
	var portrait := TextureRect.new()
	portrait.texture = f.data.portrait
	portrait.custom_minimum_size = Vector2(200, 200)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(portrait)
	var text := VBoxContainer.new()
	row.add_child(text)
	text.add_child(UIStyle.label("P%d WINS" % (winner + 1), 34, f.port_color.lightened(0.3)))
	text.add_child(UIStyle.label(f.data.display_name.to_upper(), 76, UIStyle.PARCHMENT, 8))
	text.add_child(UIStyle.label(f.data.title, 26, UIStyle.GOLD))
	text.add_child(UIStyle.label("Set score  %d - %d" % [m.setup.wins[0], m.setup.wins[1]], 30, UIStyle.MUTED))
	var rematch := UIStyle.button("Rematch", func():
		Game.setup.reset_progress()
		Game.goto(Game.SCENE_MATCH))
	col.add_child(rematch)
	col.add_child(UIStyle.button("Change fighters", func(): Game.goto(Game.SCENE_VERSUS)))
	col.add_child(UIStyle.button("Main menu", func(): Game.goto(Game.SCENE_MAIN_MENU)))
	rematch.call_deferred(&"grab_focus")
