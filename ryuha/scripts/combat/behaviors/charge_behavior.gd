class_name ChargeBehavior
extends MoveBehavior
## Hold a button to freeze the move at `charge_frame` and power it up.
## Used by every smash attack and by charged specials (e.g. the quick-draw slash).

@export var charge_frame: int = 4
@export var max_charge_frames: int = 60
## Input actions that keep the charge going (any one held is enough).
@export var hold_actions: Array[StringName] = [&"attack", &"strong"]
@export var max_damage_mult: float = 1.4
@export var max_knockback_mult: float = 1.0
@export var flash_color: Color = Color(1.0, 0.85, 0.45)


func on_start(attack) -> void:
	attack.vars["charge_done"] = false
	attack.vars["charge_max"] = max_charge_frames


func blocks_frame_advance(attack) -> bool:
	if attack.vars.get("charge_done", false) or attack.frame != charge_frame:
		return false
	var held := false
	for action in hold_actions:
		if attack.fighter.input.is_held(action):
			held = true
			break
	if held and attack.charge_frames < max_charge_frames:
		attack.charge_frames += 1
		attack.charging = true
		var t := float(attack.charge_frames) / float(max_charge_frames)
		attack.damage_mult = lerpf(1.0, max_damage_mult, t)
		attack.knockback_mult = lerpf(1.0, max_knockback_mult, t)
		attack.fighter.flash(flash_color, 0.15 + 0.25 * absf(sin(attack.charge_frames * 0.35)))
		if attack.charge_frames == 1:
			Sfx.play(&"charge", attack.fighter.global_position)
		return true
	attack.vars["charge_done"] = true
	attack.charging = false
	return false


func on_end(attack) -> void:
	attack.charging = false
