class_name HitboxData
extends Resource
## One hitbox inside a move. Pure data: the AttackState turns it on/off by frame,
## the CombatResolver tests it against hurtboxes.
##
## Coordinates are in "facing space": +x is in front of the fighter, -y is up.
## The origin is the fighter's feet.

enum Shape { CIRCLE, RECT }

@export_group("Identity")
## Lower id = higher priority when several hitboxes of one move overlap a target.
@export var id: int = 0
## Hitboxes in the same group share hit-once tracking. Use different groups for
## sequential hits (e.g. a multi-part sweep) so each part can connect.
@export var group: int = 0

@export_group("Timing")
## First and last active frame (1-based, inclusive, counted from move start).
## Leave both at 0 to use the move's own active window.
@export var start_frame: int = 0
@export var end_frame: int = 0
## If > 0 this hitbox may hit the same target again every N frames (multi-hits).
@export var rehit_rate: int = 0

@export_group("Shape")
@export var shape: Shape = Shape.CIRCLE
@export var offset: Vector2 = Vector2(60, -90)
@export var radius: float = 30.0
## Used when shape == RECT.
@export var size: Vector2 = Vector2(60, 40)

@export_group("Damage & Knockback")
@export var damage: float = 5.0
## Launch angle in degrees, facing space: 0 = forward, 90 = up, 180 = back,
## 270 = straight down (spike). 361 = "Sakurai angle" (low on ground, 40° in air).
@export var angle: float = 45.0
@export var base_knockback: float = 30.0
@export var knockback_growth: float = 80.0
## Fixed knockback: if > 0, ignores the target's percent (used for multi-hit drags).
@export var set_knockback: float = 0.0
## Send the target away from the attacker's centre instead of using facing.
@export var hit_away_from_center: bool = false

@export_group("Feel")
@export var hitlag_multiplier: float = 1.0
@export var shield_damage: float = 0.0
## Audio event to play on hit. Empty = chosen from damage (hit_light / hit_heavy).
@export var hit_sfx: StringName = &""


func get_window(move_startup: int, move_active: int) -> Vector2i:
	if start_frame <= 0 and end_frame <= 0:
		return Vector2i(move_startup + 1, move_startup + move_active)
	return Vector2i(start_frame, end_frame)


## World-space centre of this hitbox for an owner at `origin` facing `facing`.
func world_center(origin: Vector2, facing: int) -> Vector2:
	return origin + Vector2(offset.x * facing, offset.y)


## Axis-aligned bounds in world space (rects never rotate).
func world_rect(origin: Vector2, facing: int) -> Rect2:
	var c := world_center(origin, facing)
	if shape == Shape.RECT:
		return Rect2(c - size * 0.5, size)
	return Rect2(c - Vector2(radius, radius), Vector2(radius, radius) * 2.0)
