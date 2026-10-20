extends Node
## Audio hook layer. Gameplay code only ever calls Sfx.play(&"event", position);
## which file plays is decided by data/audio_library.tres (event -> streams).
## Swap in real recordings there without touching code. Missing events are
## silently ignored, so new hooks can be added before audio exists.
##
## Events used by the game: swing_light, swing_heavy, hit_light, hit_heavy,
## clank, shield_hit, jump, land, tech, ko, charge, round_start,
## menu_move, menu_confirm.

const LIBRARY_PATH := "res://data/audio_library.tres"
const VOICES := 12

var library: AudioLibrary
var volume_db: float = -4.0
var _players: Array[AudioStreamPlayer] = []
var _next := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ResourceLoader.exists(LIBRARY_PATH):
		library = load(LIBRARY_PATH)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_players.append(p)


## position is accepted for future positional audio / panning.
func play(event: StringName, _position: Vector2 = Vector2.ZERO, pitch_jitter: float = 0.06) -> void:
	if library == null or event == &"":
		return
	var stream := library.pick(event)
	if stream == null:
		return
	var p := _players[_next]
	_next = (_next + 1) % _players.size()
	p.stream = stream
	p.volume_db = volume_db + library.volume_offset(event)
	p.pitch_scale = 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	p.play()
