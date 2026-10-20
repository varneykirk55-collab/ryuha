class_name Roster
extends Resource
## The list of selectable fighters. Add a CharacterData here to make it playable.

@export var characters: Array[CharacterData] = []
## Stage scenes selectable in versus (first is default).
@export var stages: PackedStringArray = []


func find_index(id: StringName) -> int:
	for i in characters.size():
		if characters[i].id == id:
			return i
	return -1
