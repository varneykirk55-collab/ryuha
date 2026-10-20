class_name HitSpark
extends Node2D
## Radial burst at a contact point. Size and colour scale with knockback.

var age: int = 0
var life: int = 12
var strength: float = 1.0
var color: Color = Color(1, 0.95, 0.8)
var rays: Array = []


func setup(pos: Vector2, kb: float, strong: bool, tint: Color = Color(1, 0.95, 0.8)) -> void:
	global_position = pos
	strength = clampf(kb / 80.0, 0.5, 2.4)
	life = 14 if strong else 10
	color = tint
	var n := 10 if strong else 7
	for i in n:
		rays.append({"a": randf() * TAU, "len": randf_range(0.6, 1.0)})


func tick() -> bool:
	age += 1
	queue_redraw()
	return age < life


func _draw() -> void:
	var t := float(age) / life
	var r := 40.0 * strength * (0.4 + t)
	var c := color
	c.a = 1.0 - t
	draw_circle(Vector2.ZERO, 26.0 * strength * (1.0 - t), Color(1, 1, 1, (1.0 - t) * 0.8))
	for ray in rays:
		var d := Vector2.from_angle(ray["a"])
		draw_line(d * r * 0.3, d * r * (1.3 + ray["len"]), c, 5.0 * (1.0 - t) + 1.0)
