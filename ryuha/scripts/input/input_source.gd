class_name InputSource
extends RefCounted
## Anything that can drive a Fighter: a physical device, a training dummy, a CPU.
## Subclasses override poll() and return a fresh InputState every frame.

var state := InputState.new()


func poll(_fighter) -> InputState:
	return state


func display_name() -> String:
	return "None"
