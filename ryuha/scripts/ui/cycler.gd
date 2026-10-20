class_name Cycler
extends Button
## A focusable "Label   < value >" button. Left/right (keyboard, d-pad, stick)
## or clicking cycles through options. Works with any input device.

signal changed(index: int)

var caption: String = ""
var options: PackedStringArray = []
var index: int = 0


func _init(p_caption: String = "", p_options: PackedStringArray = [], p_index: int = 0) -> void:
	caption = p_caption
	options = p_options
	index = p_index
	focus_mode = Control.FOCUS_ALL
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	pressed.connect(func(): step(1))
	focus_entered.connect(func(): Sfx.play(&"menu_move"))
	_refresh()


func set_options(p_options: PackedStringArray, p_index: int) -> void:
	options = p_options
	index = clampi(p_index, 0, maxi(options.size() - 1, 0))
	_refresh()


func step(d: int) -> void:
	if options.is_empty():
		return
	index = wrapi(index + d, 0, options.size())
	_refresh()
	Sfx.play(&"menu_move")
	changed.emit(index)


func _gui_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_left"):
		step(-1)
		accept_event()
	elif event.is_action_pressed(&"ui_right"):
		step(1)
		accept_event()


func _refresh() -> void:
	var v := options[index] if index < options.size() else ""
	text = "%s   <  %s  >" % [caption, v]
