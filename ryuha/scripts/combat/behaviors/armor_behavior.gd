class_name ArmorBehavior
extends MoveBehavior
## Super/heavy armour: during the window the fighter takes damage but is not
## launched. Gives heavy characters a way to power through pokes.

@export var start_frame: int = 1
@export var end_frame: int = 10
## 0 = super armour (absorbs anything). Otherwise only hits dealing <= this damage.
@export var max_damage: float = 0.0


func on_hurt(attack, hit: HitInfo) -> bool:
	if attack.frame < start_frame or attack.frame > end_frame:
		return false
	if max_damage > 0.0 and hit.damage > max_damage:
		return false
	var f = attack.fighter
	f.add_percent(hit.damage)
	f.hitstop = maxi(f.hitstop, 6)
	f.flash(Color(1.0, 0.55, 0.3), 0.7)
	Sfx.play(&"shield_hit", f.global_position)
	return true
