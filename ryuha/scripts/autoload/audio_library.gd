class_name AudioLibrary
extends Resource
## Maps audio event names to one or more streams (one is picked at random).

@export var events: Dictionary = {}      ## StringName -> Array[AudioStream]
@export var volume: Dictionary = {}      ## StringName -> float dB offset


func pick(event: StringName) -> AudioStream:
	var list = events.get(event)
	if list == null or list.is_empty():
		return null
	return list[randi() % list.size()]


func volume_offset(event: StringName) -> float:
	return float(volume.get(event, 0.0))
