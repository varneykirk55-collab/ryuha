class_name DummyInput
extends InputSource
## Training-mode dummy. Performs a fixed behaviour and DIs as configured.

enum Behavior { STAND, CROUCH, JUMP, SHIELD, WALK, CPU }
enum DI { NONE, SURVIVAL, COMBO, RANDOM }

const BEHAVIOR_NAMES := ["Stand", "Crouch", "Jump", "Shield", "Walk", "CPU"]
const DI_NAMES := ["None", "Survival (up & in)", "Combo (down & in)", "Random"]

var behavior: Behavior = Behavior.STAND
var di_mode: DI = DI.NONE
var cpu := CpuInput.new()
var _t := 0
var _prev_held := {}
var _random_di := Vector2.ZERO


func display_name() -> String:
	return "Dummy"


func poll(f) -> InputState:
	_t += 1
	if behavior == Behavior.CPU:
		state = cpu.poll(f)
		_apply_di(f, state)
		return state
	var s := InputState.new()
	var held := {}
	match behavior:
		Behavior.CROUCH:
			s.stick = Vector2(0, -1)
		Behavior.JUMP:
			held[&"jump"] = (_t % 70) < 4
		Behavior.SHIELD:
			held[&"shield"] = true
		Behavior.WALK:
			s.stick = Vector2(1 if (_t / 90) % 2 == 0 else -1, 0) * 0.5
	for a in InputState.ACTIONS:
		s.pressed[a] = held.get(a, false) and not _prev_held.get(a, false)
	s.held = held
	_prev_held = held
	_apply_di(f, s)
	state = s
	return s


func _apply_di(f, s: InputState) -> void:
	if di_mode == DI.NONE or f == null or f.state_name != &"hitstun" or f.state.frame > 0:
		return
	var hit: HitInfo = f.last_hit_taken
	if hit == null or hit.attacker == null:
		return
	var away := signf(f.global_position.x - hit.attacker.global_position.x)
	if away == 0.0:
		away = 1.0
	match di_mode:
		DI.SURVIVAL:
			s.stick = Vector2(-away, 1).normalized()
		DI.COMBO:
			s.stick = Vector2(-away, -1).normalized()
		DI.RANDOM:
			if f.hitstop == 0 or _random_di == Vector2.ZERO:
				_random_di = Vector2.from_angle(randf() * TAU)
			s.stick = _random_di
