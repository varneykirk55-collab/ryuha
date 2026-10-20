@tool
class_name Ledge
extends Marker2D
## A grabbable stage corner. Place it exactly on the corner of the floor.
## dir = +1 for a right-hand edge (stage is to the left), -1 for a left edge.

@export_enum("Left edge:-1", "Right edge:1") var dir: int = 1

## Fighter currently hanging here (one at a time).
var occupant: Node = null


func _draw() -> void:
	if Engine.is_editor_hint() or (Game and Game.show_hitboxes):
		draw_circle(Vector2.ZERO, 10, Color(0.2, 0.95, 1.0, 0.8))
		draw_line(Vector2.ZERO, Vector2(dir * 40, 0), Color(0.2, 0.95, 1.0), 3.0)


func _process(_d: float) -> void:
	queue_redraw()
