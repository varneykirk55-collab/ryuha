class_name MoveData
extends Resource
## Everything that defines one attack: frame data, hitboxes, poses, and optional
## behaviours. The generic AttackState runs any MoveData — no move is special-cased
## in code. Character flavour (charging, armour, counters, projectiles, rush
## movement) comes from MoveBehavior resources listed in `behaviors`.

@export var id: StringName = &""
@export var display_name: String = ""

@export_group("Frame Data (60 fps)")
@export var startup: int = 5
@export var active: int = 3
@export var recovery: int = 15
## Aerials: frames of lag if you land during the move.
@export var landing_lag: int = 6
## Frame from which a buffered attack chains into `next_on_attack` (jab combos).
@export var chain_from_frame: int = 0
@export var next_on_attack: MoveData

@export_group("Hitboxes")
@export var hitboxes: Array[HitboxData] = []

@export_group("Movement")
## Multiplies character gravity while the move runs (0 = hover/stall).
@export var gravity_scale: float = 1.0
## Allow air drift while the move runs (true for normal aerials).
@export var allow_drift: bool = true
## Ground friction multiplier during the move.
@export var friction_scale: float = 1.0
## Land-cancel behaviour for aerial moves. If false the move continues on landing.
@export var cancel_on_land: bool = true

@export_group("Rules")
@export var is_aerial: bool = false
## Grounded-only moves cannot be started in the air (the fighter's *_air slot is used).
@export var grounded_only: bool = false
## Times this move may be used before landing (0 = unlimited). Typical for side-B.
@export var air_uses: int = 0
## Enter helpless fall at the end if still airborne (up-specials, some side-specials).
@export var ends_in_helpless: bool = false
@export var helpless_landing_lag: int = 20
## Recovery moves may snap to the ledge from this frame on (0 = never during move).
@export var ledge_grab_from_frame: int = 0
## Fighter is intangible on these frames (inclusive). (0,0) = none.
@export var intangible_frames: Vector2i = Vector2i.ZERO

@export_group("Presentation")
## Animation names from the fighter's SpriteFrames used for each phase.
@export var pose_startup: StringName = &"attack_startup"
@export var pose_active: StringName = &"attack_active"
@export var pose_recovery: StringName = &"attack_recovery"
## Visual tilt of the sprite during the move (degrees, + = nose up). Lets one
## drawn pose read as an up-air / down-air without new art.
@export var pose_tilt: float = 0.0
@export var swing_sfx: StringName = &"swing_light"
## Slash trail drawn while hitboxes are active. Angles in facing space (deg).
@export var trail_enabled: bool = true
@export var trail_center: Vector2 = Vector2(0, -90)
@export var trail_radius: float = 80.0
@export var trail_from_deg: float = 60.0
@export var trail_to_deg: float = -30.0
@export var trail_width: float = 22.0

@export_group("Behaviours")
@export var behaviors: Array[MoveBehavior] = []


func total_frames() -> int:
	return startup + active + recovery


## Last frame on which any hitbox is live (used for phase/pose timing).
func last_active_frame() -> int:
	var last := startup + active
	for hb in hitboxes:
		last = maxi(last, hb.get_window(startup, active).y)
	return last


func first_active_frame() -> int:
	var first := startup + 1
	for hb in hitboxes:
		first = mini(first, hb.get_window(startup, active).x)
	return first
