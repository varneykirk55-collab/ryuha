class_name SlashTrail
extends Node2D
## Crescent sword trail drawn from a MoveData's trail settings. Follows its
## fighter for the move's active frames, then fades.

const LIFE := 14

var fighter: Fighter
var move: MoveData
var color: Color
var facing: int = 1
var age: int = 0


func setup(f: Fighter, m: MoveData) -> void:
	fighter = f
	move = m
	facing = f.facing
	color = f.data.accent_color.lightened(0.35)
	global_position = f.global_position


func tick() -> bool:
	age += 1
	if is_instance_valid(fighter) and age <= 6:
		global_position = fighter.global_position
	queue_redraw()
	return age < LIFE


func _draw() -> void:
	var reveal := clampf(age / 3.0, 0.0, 1.0)
	var fade := 1.0 - clampf((age - 4) / float(LIFE - 4), 0.0, 1.0)
	if fade <= 0.0:
		return
	var a0 := deg_to_rad(move.trail_from_deg)
	var a1 := lerpf(a0, deg_to_rad(move.trail_to_deg), reveal)
	var steps := 18
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	var center := Vector2(move.trail_center.x * facing, move.trail_center.y)
	for i in steps + 1:
		var t := float(i) / steps
		var a := lerpf(a0, a1, t)
		var dir := Vector2(cos(a) * facing, -sin(a))
		var w := move.trail_width * sin(t * PI) * (0.4 + 0.6 * t)
		outer.append(center + dir * (move.trail_radius + w * 0.5))
		inner.append(center + dir * (move.trail_radius - w * 0.5))
	inner.reverse()
	var poly := outer + inner
	var c := color
	c.a = 0.75 * fade
	draw_colored_polygon(poly, c)
	var edge := Color(1, 1, 1, 0.85 * fade)
	draw_polyline(outer, edge, 2.0, true)
