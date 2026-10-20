class_name CpuInput
extends InputSource
## A small, readable CPU opponent. It only produces InputState frames — exactly
## like a human — so it can never "cheat" the fighter controller.
## Logic: recover if off-stage, otherwise approach, poke when in range,
## anti-air when the opponent is above, and shield sometimes.

var level: int = 5          ## 1..9: reaction speed and aggression
var _decision_cd := 0
var _plan: Dictionary = {}
var _prev_held := {}
var _hold_frames := 0
var _recover_used_up := false


func display_name() -> String:
	return "CPU Lv%d" % level


func poll(f) -> InputState:
	var s := InputState.new()
	var held := {}
	if f == null or f.match_ref == null:
		state = s
		return s
	var me: Vector2 = f.global_position
	var stage = f.match_ref.stage
	var opp = f.match_ref.get_opponent(f)

	var offstage: bool = me.x < stage.floor_left - 20 or me.x > stage.floor_right + 20 or me.y > stage.floor_y + 60
	if f.grounded:
		_recover_used_up = false

	if offstage and f.state_name != &"ledge":
		# --- Recovery ---
		var to_center := signf(-me.x) if absf(me.x) > 10 else 0.0
		s.stick = Vector2(to_center, 0)
		if f.state_name in [&"air", &"hitstun"] and f.velocity.y > -100:
			if f.air_jumps_left > 0 and me.y > stage.floor_y - 100:
				held[&"jump"] = true
			elif not _recover_used_up and me.y > stage.floor_y - 60:
				s.stick = Vector2(to_center * 0.4, 1)
				held[&"special"] = true
				_recover_used_up = true
	elif f.state_name == &"ledge":
		if f.state.frame > 12 + (10 - level) * 3:
			s.stick = Vector2(signf(-me.x), 0)  # get up
	elif opp != null and opp.visible:
		var d: Vector2 = opp.global_position - me
		var face := signf(d.x) if absf(d.x) > 1 else float(f.facing)
		_decision_cd -= 1
		if _decision_cd <= 0 or _plan.is_empty():
			_decide(f, opp, d)
		match _plan.get("kind", "approach"):
			"approach":
				s.stick = Vector2(face * (1.0 if absf(d.x) > 450 else 0.7), 0)
			"attack":
				s.stick = _plan["stick"]
				held[_plan["button"]] = _hold_frames < int(_plan.get("hold", 2))
				_hold_frames += 1
			"jump_attack":
				s.stick = Vector2(face * 0.6, 0)
				if _hold_frames < 3:
					held[&"jump"] = true
				elif _hold_frames > 8 and _hold_frames < 11:
					s.stick = _plan["stick"]
					held[&"attack"] = true
				_hold_frames += 1
			"shield":
				held[&"shield"] = _hold_frames < 18
				_hold_frames += 1
			"wait":
				s.stick = Vector2(-face * 0.3, 0) if absf(d.x) < 200 else Vector2.ZERO

	for a in InputState.ACTIONS:
		s.pressed[a] = held.get(a, false) and not _prev_held.get(a, false)
	s.held = held
	_prev_held = held
	state = s
	return s


func _decide(f, opp, d: Vector2) -> void:
	_hold_frames = 0
	_decision_cd = int(lerpf(26.0, 8.0, (level - 1) / 8.0)) + randi() % 6
	var dist := absf(d.x)
	var face := signf(d.x) if dist > 1 else float(f.facing)
	var opp_attacking: bool = opp.state_name == &"attack"
	if opp_attacking and dist < 260 and randf() < 0.035 * level:
		_plan = {"kind": "shield"}
		return
	if d.y < -170 and dist < 220:
		if randf() < 0.5:
			_plan = {"kind": "attack", "button": &"attack", "stick": Vector2(0, 1)}
		else:
			_plan = {"kind": "jump_attack", "stick": Vector2(0, 1)}
		return
	if dist < 170:
		var r := randf()
		if r < 0.35:
			_plan = {"kind": "attack", "button": &"attack", "stick": Vector2.ZERO}
		elif r < 0.6:
			_plan = {"kind": "attack", "button": &"attack", "stick": Vector2(face, 0)}
		elif r < 0.75:
			_plan = {"kind": "attack", "button": &"attack", "stick": Vector2(0, -1)}
		elif r < 0.88:
			_plan = {"kind": "attack", "button": &"strong", "stick": Vector2(face, 0), "hold": 2 + randi() % 20}
		else:
			_plan = {"kind": "attack", "button": &"special", "stick": Vector2(face, 0)}
		return
	if dist < 330 and randf() < 0.35:
		_plan = {"kind": "jump_attack", "stick": Vector2(face, 0)}
		return
	if dist < 420 and randf() < 0.15:
		_plan = {"kind": "attack", "button": &"special", "stick": Vector2.ZERO, "hold": 10}
		return
	_plan = {"kind": "approach"} if randf() < 0.85 else {"kind": "wait"}
