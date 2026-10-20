class_name FightCamera
extends Camera2D
## Frames every living fighter with a soft zoom, stays inside the stage's camera
## bounds, and adds trauma-based screen shake.

@export var padding := Vector2(520, 380)
## Smallest area the camera will show (keeps the stage readable when players are close).
@export var min_view := Vector2(1500, 844)
@export var follow_speed := 5.0
@export var zoom_speed := 3.0
@export var max_shake_offset := 38.0

var targets: Array = []
var bounds := Rect2(-1900, -1500, 3800, 2300)
var trauma: float = 0.0
var _goal_pos := Vector2.ZERO
var _goal_zoom := 1.0
var _t := 0.0


func _ready() -> void:
	make_current()
	process_mode = Node.PROCESS_MODE_ALWAYS


func snap() -> void:
	_compute_goal()
	global_position = _goal_pos
	zoom = Vector2.ONE * _goal_zoom


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_compute_goal()
	var k := 1.0 - exp(-follow_speed * delta)
	global_position = global_position.lerp(_goal_pos, k)
	var zk := 1.0 - exp(-zoom_speed * delta)
	zoom = zoom.lerp(Vector2.ONE * _goal_zoom, zk)
	_clamp_to_bounds()
	# Shake (frozen while the game is paused).
	if not get_tree().paused:
		_t += delta
		trauma = maxf(trauma - delta * 1.6, 0.0)
	var s := trauma * trauma
	offset = Vector2(sin(_t * 61.0) * 0.8 + sin(_t * 23.0) * 0.2, cos(_t * 53.0) * 0.8 + sin(_t * 31.0) * 0.2) * max_shake_offset * s


func _compute_goal() -> void:
	var pts: Array[Vector2] = []
	for t in targets:
		if is_instance_valid(t) and t.visible:
			pts.append(t.global_position + Vector2(0, -90))
	if pts.is_empty():
		_goal_pos = bounds.get_center() + Vector2(0, 200)
		return
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	r = r.grow_individual(padding.x, padding.y, padding.x, padding.y * 0.6)
	var view := get_viewport_rect().size
	var need := Vector2(maxf(r.size.x, min_view.x), maxf(r.size.y, min_view.y))
	var z := minf(view.x / need.x, view.y / need.y)
	var max_view_zoom := maxf(view.x / bounds.size.x, view.y / bounds.size.y)
	_goal_zoom = clampf(z, max_view_zoom, view.x / min_view.x)
	_goal_pos = r.get_center()


func _clamp_to_bounds() -> void:
	var half := get_viewport_rect().size / zoom * 0.5
	var minp := bounds.position + half
	var maxp := bounds.end - half
	global_position.x = clampf(global_position.x, minp.x, maxp.x) if minp.x <= maxp.x else bounds.get_center().x
	global_position.y = clampf(global_position.y, minp.y, maxp.y) if minp.y <= maxp.y else bounds.get_center().y
