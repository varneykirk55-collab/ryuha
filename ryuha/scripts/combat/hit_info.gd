class_name HitInfo
extends RefCounted
## A resolved hit, passed from the CombatResolver to the victim.

var attacker: Node            ## Fighter who owns the hitbox (projectiles report their thrower)
var source: Object            ## AttackState or Projectile that produced the hit
var hitbox: HitboxData
var damage: float = 0.0       ## after charge multipliers
var knockback_mult: float = 1.0
var direction: int = 1        ## +1 / -1: which way "forward" points for the angle
var position: Vector2         ## approximate contact point (for sparks)

# Filled in by the victim when knockback is computed (training mode readout).
var knockback: float = 0.0
var launch_angle_deg: float = 0.0
var hitstun_frames: int = 0
