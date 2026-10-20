extends Node
## Loads every script in the project so parse/compile errors are reported.
## godot --headless res://tools/check_scripts.tscn

func _ready() -> void:
	var bad := 0
	for path in _scan("res://scripts") + _scan("res://tools"):
		var s = load(path)
		if s == null or (s is GDScript and not s.can_instantiate() and not path.ends_with("check_scripts.gd")):
			print("FAILED: ", path)
			bad += 1
	print("Script check done, failures: ", bad)
	get_tree().quit(1 if bad > 0 else 0)


func _scan(dir: String) -> Array:
	var out := []
	var d := DirAccess.open(dir)
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir + "/" + f)
	for sub in d.get_directories():
		out += _scan(dir + "/" + sub)
	return out
