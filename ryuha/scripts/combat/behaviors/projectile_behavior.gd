class_name ProjectileBehavior
extends MoveBehavior
## Spawns a simple straight-flying projectile (kunai, shockwave, etc.).

@export var spawn_frame: int = 10
@export var spawn_offset: Vector2 = Vector2(50, -95)
## Facing space, px/s.
@export var velocity: Vector2 = Vector2(1500, 0)
@export var gravity: float = 0.0
@export var lifetime_frames: int = 40
@export var hitbox: HitboxData
@export var color: Color = Color(0.9, 0.9, 1.0)
@export var length: float = 40.0
## Projectile is destroyed when it touches the stage floor.
@export var dies_on_ground: bool = true


func on_frame(attack) -> void:
	if attack.frame == spawn_frame:
		attack.fighter.spawn_projectile(self)
