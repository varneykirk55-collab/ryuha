class_name CombatConfig
extends Resource
## Global combat tuning shared by every fighter. One instance lives at
## res://data/combat_config.tres — tweak game feel there without touching code.

@export_group("Knockback")
## Launch speed (px/s) per point of knockback.
@export var launch_speed_per_kb: float = 16.0
## How fast launch speed bleeds off (px/s²).
@export var launch_decay: float = 1900.0
## Hitstun frames = knockback * this.
@export var hitstun_per_kb: float = 0.4
## Knockback at or above this tumbles (techable, knockdown on missed tech).
@export var tumble_threshold: float = 80.0
## Maximum launch-angle change from Directional Influence (degrees).
@export var di_max_degrees: float = 18.0
@export var default_weight: float = 100.0

@export_group("Hitlag & Shake")
@export var hitlag_base: float = 4.0
@export var hitlag_per_damage: float = 0.45
@export var hitlag_max: int = 22
## Screen shake trauma added per point of knockback above `shake_kb_floor`.
@export var shake_per_kb: float = 0.006
@export var shake_kb_floor: float = 45.0
## Knockback considered a "strong hit" (heavy sfx, big spark, extra shake).
@export var strong_hit_kb: float = 95.0

@export_group("Defense")
@export var tech_window_frames: int = 20
@export var tech_lockout_frames: int = 40
@export var shield_max: float = 50.0
@export var shield_regen_per_frame: float = 0.08
@export var shield_decay_per_frame: float = 0.13
@export var shield_break_stun_frames: int = 200
## Two ground hitboxes clank (both rebound) if their damage differs by <= this.
@export var clank_damage_window: float = 9.0

@export_group("Ledge")
@export var ledge_intangibility_frames: int = 45
@export var ledge_max_hang_frames: int = 300
@export var ledge_regrab_cooldown: int = 30
@export var ledge_getup_frames: int = 26

@export_group("Stocks & Respawn")
@export var respawn_delay_frames: int = 50
@export var respawn_invincibility_frames: int = 150
@export var respawn_platform_max_frames: int = 240
@export var sudden_death_percent: float = 300.0

@export_group("Input")
@export var buffer_frames: int = 7

@export_group("Generic Moves")
## Used if a character doesn't define its own.
@export var getup_attack: MoveData
@export var ledge_attack: MoveData


# --- Knockback maths (Smash formula) ----------------------------------------

## percent_after: victim's percent *after* the hit's damage was applied.
func compute_knockback(percent_after: float, damage: float, weight: float, hb: HitboxData, mult: float) -> float:
	var p := percent_after
	if hb.set_knockback > 0.0:
		p = 10.0
		damage = hb.set_knockback
	var kb := ((p / 10.0 + p * damage / 20.0) * 200.0 / (weight + 100.0) * 1.4 + 18.0)
	kb = kb * hb.knockback_growth / 100.0 + hb.base_knockback
	return kb * mult


func compute_hitlag(damage: float, hb: HitboxData) -> int:
	return clampi(int(floor((hitlag_base + damage * hitlag_per_damage) * hb.hitlag_multiplier)), 2, hitlag_max)
