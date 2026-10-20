class_name KoBurst
extends Node2D
## Big streak at the blast zone edge when a fighter is KO'd.

var age: int = 0
var dir: Vector2 = Vector2.RIGHT
var color: Color = Color.WHITE


func setup(pos: Vector2, from_center: Vector2, c: Color) -> void:
	global_position = pos
	dir = (pos - from_center).normalized()
	color = c


func tick() -> bool:
	age += 1
	queue_redraw()
	return age < 40


func _draw() -> void:
	var t := age / 40.0
	var back := -dir
	var side := dir.orthogonal()
	var len := 1400.0 * (0.3 + t)
	var w := 160.0 * (1.0 - t)
	var c := color
	c.a = 1.0 - t
	draw_colored_polygon(PackedVector2Array([Vector2.ZERO + side * w, back * len, Vector2.ZERO - side * w]), c)
	draw_colored_polygon(PackedVector2Array([side * w * 0.4, back * len * 0.8, -side * w * 0.4]), Color(1, 1, 1, 1.0 - t))
