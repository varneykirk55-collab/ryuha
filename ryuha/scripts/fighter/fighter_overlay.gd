extends Node2D
## Draws everything around a fighter that isn't the sprite: player tag, shield
## bubble, respawn platform, and the toggleable hitbox/hurtbox debug view.
## Drawn in the fighter's local space (origin = feet, never flipped).

const HITBOX_COLOR := Color(1.0, 0.15, 0.15, 0.45)
const HURTBOX_COLOR := Color(1.0, 0.85, 0.1, 0.35)
const INTANGIBLE_COLOR := Color(0.3, 0.6, 1.0, 0.35)
const ECB_COLOR := Color(0.2, 1.0, 0.4, 0.9)
const LEDGE_COLOR := Color(0.2, 0.95, 1.0, 0.6)

@onready var fighter: Fighter = get_parent()


func _draw() -> void:
	var f := fighter
	if f == null or f.data == null or not f.visible:
		return
	var h := f.data.hurtbox_size.y
	var font := ThemeDB.fallback_font

	# Player tag above the head.
	if f.state_name != &"dead":
		var tag_y := -h - 34.0
		var tri := PackedVector2Array([Vector2(-11, tag_y), Vector2(11, tag_y), Vector2(0, tag_y + 13)])
		draw_colored_polygon(tri, f.port_color)
		var label := ("CPU" if f.input_source is CpuInput else "P%d" % (f.port + 1))
		draw_string_outline(font, Vector2(-30, tag_y - 6), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 24, 6, Color(0, 0, 0, 0.8))
		draw_string(font, Vector2(-30, tag_y - 6), label, HORIZONTAL_ALIGNMENT_CENTER, 60, 24, f.port_color.lightened(0.3))

	# Shield bubble.
	if f.state_name == &"shield" and f.state.is_bubble_visible():
		var ratio := clampf(f.shield_hp / Game.config.shield_max, 0.0, 1.0)
		var r := lerpf(26.0, h * 0.52, ratio)
		var c := f.port_color
		c.a = 0.26
		draw_circle(Vector2(0, -h * 0.5), r, c)
		draw_arc(Vector2(0, -h * 0.5), r, 0, TAU, 48, Color(c.r, c.g, c.b, 0.9), 3.0)

	# Respawn platform.
	if f.on_respawn_platform:
		draw_rect(Rect2(-70, 2, 140, 12), Color(0.85, 0.75, 0.55, 0.95))
		draw_rect(Rect2(-70, 2, 140, 12), Color(0.2, 0.12, 0.05), false, 3.0)

	if not Game.show_hitboxes:
		return

	# Hurtbox (yellow, blue if intangible/invincible).
	var hr := f.get_hurtbox_rect()
	hr.position -= f.global_position
	var hc := INTANGIBLE_COLOR if (f.intangible > 0 or f.invincible > 0) else HURTBOX_COLOR
	draw_rect(hr, hc)
	draw_rect(hr, Color(hc.r, hc.g, hc.b, 0.9), false, 2.0)

	# Environment collision box.
	var cs := f.data.collision_size
	draw_rect(Rect2(Vector2(-cs.x * 0.5, -cs.y), cs), ECB_COLOR, false, 2.0)

	# Ledge-grab region (in the air only).
	if not f.grounded:
		var hw := cs.x * 0.5
		draw_rect(Rect2(Vector2(-hw - 52, -h - 24), Vector2(hw * 2 + 104, h + 40)), LEDGE_COLOR, false, 1.0)

	# Active hitboxes.
	for e in f.active_hitboxes:
		var hb: HitboxData = e["hb"]
		_draw_hitbox(hb, f.facing, font)

	# State readout.
	var txt := "%s %d" % [f.state_name, f.state.frame]
	if f.hitstop > 0:
		txt += "  [hitlag %d]" % f.hitstop
	draw_string_outline(font, Vector2(-120, 26), txt, HORIZONTAL_ALIGNMENT_CENTER, 240, 18, 5, Color.BLACK)
	draw_string(font, Vector2(-120, 26), txt, HORIZONTAL_ALIGNMENT_CENTER, 240, 18, Color.WHITE)


func _draw_hitbox(hb: HitboxData, facing: int, font: Font) -> void:
	var c := Vector2(hb.offset.x * facing, hb.offset.y)
	if hb.shape == HitboxData.Shape.RECT:
		var r := Rect2(c - hb.size * 0.5, hb.size)
		draw_rect(r, HITBOX_COLOR)
		draw_rect(r, Color(1, 0.2, 0.2), false, 2.0)
	else:
		draw_circle(c, hb.radius, HITBOX_COLOR)
		draw_arc(c, hb.radius, 0, TAU, 32, Color(1, 0.2, 0.2), 2.0)
	# Launch angle indicator.
	var ang := 40.0 if hb.angle > 360.0 else hb.angle
	var d := Vector2(cos(deg_to_rad(ang)) * facing, -sin(deg_to_rad(ang)))
	draw_line(c, c + d * 36.0, Color.WHITE, 2.0)
	draw_string(font, c + Vector2(-20, 6), "%d" % hb.id, HORIZONTAL_ALIGNMENT_CENTER, 40, 16, Color.WHITE)
