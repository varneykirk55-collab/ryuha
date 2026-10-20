extends Node
## Global session: roster, combat config, current MatchSetup, debug toggles,
## and scene navigation. Autoloaded as `Game`.

signal hitbox_view_toggled(on: bool)

const ROSTER_PATH := "res://data/roster.tres"
const CONFIG_PATH := "res://data/combat_config.tres"

const SCENE_MAIN_MENU := "res://scenes/menus/main_menu.tscn"
const SCENE_VERSUS := "res://scenes/menus/versus_setup.tscn"
const SCENE_MATCH := "res://scenes/match/match.tscn"

var roster: Roster
var config: CombatConfig
var setup: MatchSetup = MatchSetup.new()
var show_hitboxes: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	roster = load(ROSTER_PATH)
	config = load(CONFIG_PATH)
	if config == null:
		config = CombatConfig.new()


func _unhandled_input(event: InputEvent) -> void:
	# F1 toggles the hitbox / hurtbox debug view anywhere.
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		toggle_hitboxes()
		get_viewport().set_input_as_handled()


func toggle_hitboxes() -> void:
	show_hitboxes = not show_hitboxes
	hitbox_view_toggled.emit(show_hitboxes)


func goto(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(path)


func start_versus() -> void:
	setup.mode = MatchSetup.Mode.VERSUS
	setup.reset_progress()
	goto(SCENE_MATCH)


func start_training() -> void:
	setup.mode = MatchSetup.Mode.TRAINING
	setup.reset_progress()
	goto(SCENE_MATCH)
