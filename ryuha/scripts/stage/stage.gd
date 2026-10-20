@tool
class_name Stage
extends Node2D
## Stage root. Geometry lives in the scene (StaticBody2D floors, one-way
## platforms in group "platform", Ledge markers); this script just exposes the
## rules: blast zones, camera bounds, spawn and respawn points.
## Make a new stage by duplicating dojo.tscn and moving the pieces.

@export var display_name: String = "Stage"
## Leaving this rectangle = KO.
@export var blast_zone: Rect2 = Rect2(-2300, -1800, 4600, 3000)
## The camera never shows outside this rectangle.
@export var camera_bounds: Rect2 = Rect2(-1900, -1500, 3800, 2300)
## Main floor left/right x and top y (used by AI and projectiles).
@export var floor_left: float = -932.0
@export var floor_right: float = 932.0
@export var floor_y: float = 0.0

var ledges: Array[Ledge] = []


func _ready() -> void:
	ledges.clear()
	for n in find_children("*", "Ledge", true, false):
		ledges.append(n)


func spawn_point(port: int) -> Vector2:
	var n := get_node_or_null("Spawns/P%d" % (port + 1)) as Node2D
	return n.global_position if n else Vector2((port * 2 - 1) * 400, floor_y)


func respawn_point(port: int) -> Vector2:
	var n := get_node_or_null("Respawns/P%d" % (port + 1)) as Node2D
	return n.global_position if n else Vector2((port * 2 - 1) * 240, floor_y - 520)


func is_outside_blast_zone(p: Vector2) -> bool:
	return not blast_zone.has_point(p)


func _process(_d: float) -> void:
	if Engine.is_editor_hint() or Game.show_hitboxes:
		queue_redraw()


func _draw() -> void:
	var debug := Engine.is_editor_hint() or (not Engine.is_editor_hint() and Game.show_hitboxes)
	if not debug:
		return
	draw_rect(blast_zone, Color(1, 0.2, 0.2, 0.9), false, 6.0)
	draw_rect(camera_bounds, Color(0.3, 0.7, 1.0, 0.8), false, 4.0)
	draw_line(Vector2(floor_left, floor_y), Vector2(floor_right, floor_y), Color(0.2, 1, 0.4, 0.8), 3.0)
