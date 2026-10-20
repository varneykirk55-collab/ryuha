class_name Projectile
extends Node2D
## Generic straight-flying projectile spawned by ProjectileBehavior.
## Implements the CombatResolver hit-source interface.

var fighter: Fighter
var hitbox: HitboxData
var beh: ProjectileBehavior
var vel: Vector2
var life: int = 0
var dir: int = 1
var _hit := {}
var _ground_y := INF
var _floor_half := 0.0


func setup(owner_fighter: Fighter, b: ProjectileBehavior, ground_y: float, floor_half_width: float) -> void:
	fighter = owner_fighter
	beh = b
	hitbox = b.hitbox
	dir = owner_fighter.facing
	vel = Vector2(b.velocity.x * dir, b.velocity.y)
	life = b.lifetime_frames
	_ground_y = ground_y
	_floor_half = floor_half_width
	global_position = owner_fighter.global_position + Vector2(b.spawn_offset.x * dir, b.spawn_offset.y)


## Advance one game frame. Returns false when finished.
func tick() -> bool:
	life -= 1
	vel.y += beh.gravity * Fighter.DT
	global_position += vel * Fighter.DT
	rotation = vel.angle() if dir > 0 else vel.angle() - PI
	queue_redraw()
	if beh.dies_on_ground and global_position.y > _ground_y and absf(global_position.x) < _floor_half:
		return false
	return life > 0


func _draw() -> void:
	var L := beh.length
	var c := beh.color
	draw_line(Vector2(-L * 0.5 * dir, 0), Vector2(L * 0.5 * dir, 0), c, 4.0)
	var tip := Vector2(L * 0.5 * dir, 0)
	draw_colored_polygon(PackedVector2Array([tip + Vector2(12 * dir, 0), tip + Vector2(0, -6), tip + Vector2(0, 6)]), c)
	draw_circle(Vector2(-L * 0.5 * dir, 0), 5, c.darkened(0.3))
	if Game.show_hitboxes and hitbox:
		draw_arc(Vector2.ZERO, hitbox.radius, 0, TAU, 24, Color(1, 0.2, 0.2), 2.0)


# --- Hit-source interface --------------------------------------------------------

func hit_origin() -> Vector2:
	return global_position - Vector2(hitbox.offset.x * dir, hitbox.offset.y)


func hit_facing() -> int:
	return dir


func can_hit(victim: Node, _hb: HitboxData) -> bool:
	return not _hit.has(victim.get_instance_id())


func register_hit(victim: Node, _hb: HitboxData) -> void:
	_hit[victim.get_instance_id()] = true


func hit_direction(_victim: Node, _hb: HitboxData) -> int:
	return dir


func on_hit(_victim: Node, _hit_info: HitInfo) -> void:
	life = 0
