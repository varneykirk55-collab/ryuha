class_name MotionBehavior
extends MoveBehavior
## Drives the fighter's velocity during a frame window: dashes, lunges, rising
## recoveries, backsteps. Stack several for multi-segment movement.

@export var start_frame: int = 1
@export var end_frame: int = 1
## Facing space, px/s. +x forward, -y up.
@export var velocity: Vector2 = Vector2.ZERO
@export var set_x: bool = true
@export var set_y: bool = false
## Velocity *= 1 + charge_bonus * charge_ratio (for charged lunges).
@export var charge_bonus: float = 0.0
## Ignore while on the ground (e.g. vertical part of a recovery).
@export var air_only: bool = false


func on_frame(attack) -> void:
	if attack.frame < start_frame or attack.frame > end_frame:
		return
	var f = attack.fighter
	if air_only and f.is_grounded():
		return
	var v: Vector2 = Vector2(velocity.x * f.facing, velocity.y) * (1.0 + charge_bonus * attack.charge_ratio())
	if set_x:
		f.velocity.x = v.x
	if set_y:
		f.velocity.y = v.y
		if v.y < 0.0:
			f.leave_ground()
