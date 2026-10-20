class_name CharacterData
extends Resource
## Everything that makes a fighter unique. The Fighter controller reads ONLY this
## resource — there is no character-specific code anywhere in the core.
## To add a fighter: duplicate an existing .tres, swap the SpriteFrames, edit stats
## and moves, and add it to data/roster.tres. (See README → "Adding a fighter".)

@export_group("Identity")
@export var id: StringName = &""
@export var display_name: String = ""
@export var title: String = ""
@export_multiline var description: String = ""
## Which move slot is the character's signature (shown in menus/training).
@export var signature_slot: StringName = &"neutral_special"
## Fighter scene to instance. Empty = res://scenes/fighters/fighter_base.tscn.
## Stored as a path (not PackedScene) to avoid a resource dependency cycle.
@export_file("*.tscn") var scene_path: String = ""

@export_group("Visuals")
@export var sprite_frames: SpriteFrames
@export var portrait: Texture2D
@export var sprite_scale: float = 1.0
## Pixel position of the feet inside each frame (frames share one canvas size).
@export var sprite_foot: Vector2 = Vector2(128, 256)
@export var accent_color: Color = Color(0.8, 0.2, 0.2)
## Tint used for the second player in a mirror match.
@export var alt_tint: Color = Color(0.75, 0.85, 1.0)

@export_group("Physics")
## ~100 is average. Heavier = launched less far.
@export var weight: float = 100.0
@export var walk_speed: float = 560.0
@export var run_speed: float = 1100.0
@export var ground_accel: float = 5000.0
@export var ground_friction: float = 4200.0
@export var air_speed: float = 680.0
@export var air_accel: float = 2600.0
@export var air_friction: float = 900.0
@export var gravity: float = 3400.0
@export var max_fall_speed: float = 1250.0
@export var fast_fall_speed: float = 1900.0
@export var full_hop_height: float = 420.0
@export var short_hop_height: float = 190.0
@export var double_jump_height: float = 400.0
@export var air_jumps: int = 1
@export var jump_squat_frames: int = 3
@export var landing_frames: int = 4

@export_group("Body")
@export var hurtbox_size: Vector2 = Vector2(60, 165)
## Environment collision box (smaller than the hurtbox so ledges feel fair).
@export var collision_size: Vector2 = Vector2(46, 120)

@export_group("Ground Attacks")
@export var jab: MoveData
@export var dash_attack: MoveData
@export var forward_tilt: MoveData
@export var up_tilt: MoveData
@export var down_tilt: MoveData
@export var forward_smash: MoveData
@export var up_smash: MoveData
@export var down_smash: MoveData

@export_group("Aerials")
@export var neutral_air: MoveData
@export var forward_air: MoveData
@export var back_air: MoveData
@export var up_air: MoveData
@export var down_air: MoveData

@export_group("Specials")
@export var neutral_special: MoveData
@export var side_special: MoveData
@export var down_special: MoveData
## Recovery special (the brief lists three specials; a fourth up-special is
## included so every fighter can return to the ledge).
@export var up_special: MoveData
## Optional aerial versions; if empty the grounded version is used in the air.
@export var neutral_special_air: MoveData
@export var side_special_air: MoveData
@export var down_special_air: MoveData

@export_group("Situational")
@export var getup_attack: MoveData
@export var ledge_attack: MoveData


## Look up a move by slot name (e.g. &"forward_tilt"). Falls back sensibly.
func get_move(slot: StringName) -> MoveData:
	var m = get(slot)
	if m is MoveData:
		return m
	match slot:
		&"dash_attack":
			return forward_tilt
		&"neutral_special_air", &"side_special_air", &"down_special_air":
			return get_move(StringName(String(slot).trim_suffix("_air")))
	return null


func jump_velocity(height: float) -> float:
	return sqrt(2.0 * gravity * height)
