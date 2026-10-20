class_name MatchSetup
extends RefCounted
## What the menus hand to the Match scene.

enum Mode { VERSUS, TRAINING }

var mode: Mode = Mode.VERSUS
## One entry per player: {character: int (roster index), scheme: StringName, cpu: bool}
var players: Array[Dictionary] = [
	{"character": 0, "scheme": &"kb_left", "cpu": false},
	{"character": 1, "scheme": &"kb_right", "cpu": false},
]
var stocks: int = 3
var time_seconds: int = 240          ## 0 = no timer
var rounds_to_win: int = 2           ## best of 3
var stage_path: String = "res://scenes/stages/dojo.tscn"

# Match progress (persists between rounds of the same set).
var round_number: int = 1
var wins: Array[int] = [0, 0]


func reset_progress() -> void:
	round_number = 1
	wins = [0, 0]
