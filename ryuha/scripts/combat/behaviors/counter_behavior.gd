class_name CounterBehavior
extends MoveBehavior
## Counter stance: if struck during the window, negate the hit and immediately
## perform `counter_move`, scaling its damage from the blocked attack.

@export var window: Vector2i = Vector2i(5, 25)
@export var counter_move: MoveData
@export var damage_multiplier: float = 1.2
@export var min_damage: float = 8.0


func on_hurt(attack, hit: HitInfo) -> bool:
	if attack.vars.get("countered", false):
		return false
	if attack.frame < window.x or attack.frame > window.y or counter_move == null:
		return false
	attack.vars["countered"] = true
	var f = attack.fighter
	if hit.attacker and is_instance_valid(hit.attacker):
		var dx: float = hit.attacker.global_position.x - f.global_position.x
		if absf(dx) > 1.0:
			f.facing = 1 if dx > 0.0 else -1
		hit.attacker.hitstop = maxi(hit.attacker.hitstop, 20)
	var base_dmg := 1.0
	if counter_move.hitboxes.size() > 0:
		base_dmg = maxf(counter_move.hitboxes[0].damage, 0.1)
	var dmg := maxf(hit.damage * damage_multiplier, min_damage)
	f.start_move(counter_move, {"damage_mult": dmg / base_dmg, "intangible": 14})
	f.hitstop = 10
	f.flash(Color(0.75, 0.85, 1.0), 1.0)
	Sfx.play(&"clank", f.global_position)
	f.request_shake(0.35)
	return true
