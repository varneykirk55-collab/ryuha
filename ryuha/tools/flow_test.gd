extends Node
## Menu flow smoke test: Main menu -> Versus setup -> Match -> Pause -> Main menu,
## then Training. godot --headless --fixed-fps 60 res://tools/flow_test.tscn

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_parent().remove_child.call_deferred(self)
	get_tree().root.add_child.call_deferred(self)
	await get_tree().create_timer(0.1).timeout
	await _flow()
	get_tree().quit()


func _btn(text: String) -> Button:
	for b in get_tree().current_scene.find_children("*", "Button", true, false):
		if b.text.begins_with(text):
			return b
	for b in get_tree().root.find_children("*", "Button", true, false):
		if b.text.begins_with(text):
			return b
	return null


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _flow() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
	await _wait(5)
	print("scene: ", get_tree().current_scene.name)
	_btn("Versus").pressed.emit()
	await _wait(5)
	print("scene: ", get_tree().current_scene.name)
	_btn("START").pressed.emit()
	await _wait(200)
	var m = get_tree().current_scene
	print("scene: ", m.name, " fighters: ", m.fighters.size(), " phase: ", m.phase)
	m.pause_menu.open()
	await _wait(3)
	print("paused: ", get_tree().paused)
	_btn("Main menu").pressed.emit()
	await _wait(5)
	print("scene: ", get_tree().current_scene.name, " paused: ", get_tree().paused)
	_btn("Training").pressed.emit()
	await _wait(5)
	_btn("START TRAINING").pressed.emit()
	await _wait(30)
	m = get_tree().current_scene
	print("scene: ", m.name, " training: ", m.is_training(), " dummy: ", m.fighters[1].input_source.display_name())
	m.training.cycle_behavior(); m.training.cycle_di(); m.training.add_dummy_percent(10); m.training.cycle_speed(); m.training.reset_positions()
	await _wait(30)
	print("dummy %: ", m.fighters[1].percent, " speed: ", m.speed_divisor)
	print("FLOW OK")
