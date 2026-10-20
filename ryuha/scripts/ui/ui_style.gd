class_name UIStyle
extends RefCounted
## Shared look for all menus/HUD: ink-dark panels, parchment text, crimson accent.

const INK := Color(0.07, 0.06, 0.055, 0.92)
const INK_LIGHT := Color(0.16, 0.13, 0.11, 0.95)
const PARCHMENT := Color(0.94, 0.9, 0.82)
const MUTED := Color(0.7, 0.65, 0.58)
const ACCENT := Color(0.78, 0.23, 0.2)
const GOLD := Color(0.86, 0.68, 0.32)


static func theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 30
	var panel := StyleBoxFlat.new()
	panel.bg_color = INK
	panel.border_color = Color(0.45, 0.33, 0.22)
	panel.set_border_width_all(2)
	panel.set_corner_radius_all(6)
	panel.set_content_margin_all(22)
	t.set_stylebox(&"panel", &"PanelContainer", panel)
	t.set_stylebox(&"panel", &"Panel", panel)

	var normal := StyleBoxFlat.new()
	normal.bg_color = INK_LIGHT
	normal.border_color = Color(0.35, 0.27, 0.2)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(4)
	normal.content_margin_left = 26
	normal.content_margin_right = 26
	normal.content_margin_top = 10
	normal.content_margin_bottom = 10
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color(0.34, 0.1, 0.09)
	focus.border_color = GOLD
	focus.set_border_width_all(3)
	var hover := focus.duplicate() as StyleBoxFlat
	var pressed := focus.duplicate() as StyleBoxFlat
	pressed.bg_color = ACCENT
	for k in [&"normal", &"disabled"]:
		t.set_stylebox(k, &"Button", normal)
	t.set_stylebox(&"focus", &"Button", StyleBoxEmpty.new())
	t.set_stylebox(&"hover", &"Button", hover)
	t.set_stylebox(&"pressed", &"Button", pressed)
	t.set_stylebox(&"hover_pressed", &"Button", pressed)
	t.set_color(&"font_color", &"Button", PARCHMENT)
	t.set_color(&"font_hover_color", &"Button", Color.WHITE)
	t.set_color(&"font_focus_color", &"Button", Color.WHITE)
	t.set_color(&"font_pressed_color", &"Button", Color.WHITE)
	t.set_color(&"font_color", &"Label", PARCHMENT)
	t.set_constant(&"outline_size", &"Label", 0)
	# Focused buttons get the "hover" look so keyboard/gamepad users can see focus.
	t.set_stylebox(&"focus", &"Button", focus)
	return t


static func label(text: String, size: int = 30, color: Color = PARCHMENT, outline: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	if outline > 0:
		l.add_theme_constant_override(&"outline_size", outline)
		l.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	return l


static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Sfx.play(&"menu_confirm")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play(&"menu_move"))
	return b
