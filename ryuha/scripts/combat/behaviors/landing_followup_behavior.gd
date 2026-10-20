class_name LandingFollowupBehavior
extends MoveBehavior
## When the fighter lands during the move, switch to another move instead of
## normal landing lag (e.g. a plunging cleave that ends in a shockwave).

@export var followup: MoveData
## Only trigger from this move frame onwards.
@export var from_frame: int = 1


func on_land(attack) -> bool:
	if followup == null or attack.frame < from_frame:
		return false
	attack.fighter.start_move(followup)
	return true
