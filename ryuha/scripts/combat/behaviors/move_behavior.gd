class_name MoveBehavior
extends Resource
## Base class for pluggable move logic. Attach any number to MoveData.behaviors.
##
## Resources are shared between every fighter using the move, so NEVER store
## per-use state on the behaviour itself — use `attack.vars` (a Dictionary that
## lives for one execution of the move).
##
## Hooks (all optional to override):
##   on_start(attack)                 – move begins
##   on_frame(attack)                 – every frame, after the frame counter advances
##   on_hurt(attack, hit) -> bool     – fighter is about to be hit; return true to
##                                      consume the hit (armour, counters)
##   on_hit(attack, target, hit)      – one of this move's hitboxes connected
##   on_end(attack)                   – move ends or is interrupted
##   blocks_frame_advance(attack)     – return true to hold the frame (charging)
##   on_land(attack) -> bool          – fighter touched the ground mid-move; return
##                                      true if the behaviour handled it
##
## `attack` is the running AttackState (see scripts/fighter/states/attack_state.gd).
## on_frame runs once per *new* move frame (not while the frame is held).


func on_start(_attack) -> void:
	pass


func on_land(_attack) -> bool:
	return false


func on_frame(_attack) -> void:
	pass


func on_hurt(_attack, _hit: HitInfo) -> bool:
	return false


func on_hit(_attack, _target, _hit: HitInfo) -> void:
	pass


func on_end(_attack) -> void:
	pass


func blocks_frame_advance(_attack) -> bool:
	return false
