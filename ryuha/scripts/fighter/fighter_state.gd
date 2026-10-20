class_name FighterState
extends RefCounted
## Base class for every fighter state. States are small, single-purpose objects
## owned by one Fighter. They never contain character-specific logic — they read
## CharacterData / MoveData through the fighter.
##
## Each state advances its own `frame` counter at the top of tick(); this lets
## states such as AttackState hold a frame (charging) without special cases.

var fighter: Fighter
var frame: int = 0
## Set by the state machine; handy for debug text.
var state_name: StringName = &""


func enter(_msg: Dictionary) -> void:
	pass


func exit() -> void:
	pass


func tick() -> void:
	frame += 1


## Called before damage is applied. Return true to swallow the hit (armour/counter).
func on_hurt(_hit: HitInfo) -> bool:
	return false


## Multiplier on hurtbox height (crouching shrinks it).
func hurtbox_height_scale() -> float:
	return 1.0


## True while the fighter can freely act (used by AI & HUD).
func is_actionable() -> bool:
	return false


## Shield interface (only ShieldState overrides these).
func is_blocking() -> bool:
	return false


func is_bubble_visible() -> bool:
	return false


func block(_hit: HitInfo) -> void:
	pass
