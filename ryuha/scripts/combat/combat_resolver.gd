class_name CombatResolver
extends RefCounted
## Resolves all hits for one game frame, AFTER every fighter has ticked:
##   1. clanks between grounded attacks (priority),
##   2. hitbox-vs-hurtbox overlaps for fighters and projectiles,
##   3. applies every hit at once so simultaneous hits trade.
##
## Hitboxes are data shapes switched on by frame (see AttackState) and tested
## here with direct geometry. Compared to physics Area2D overlap signals this has
## no one-frame lag and is fully deterministic, which matters for frame data.
##
## A "hit source" (AttackState or Projectile) implements:
##   can_hit(victim, hb) / register_hit(victim, hb) / hit_origin() / hit_facing()
##   hit_direction(victim, hb) / on_hit(victim, hit)
## and exposes `fighter` (the owner).

signal hit_resolved(attacker: Fighter, victim: Fighter, hit: HitInfo, result: int)
signal clanked(a: Fighter, b: Fighter, point: Vector2)


func resolve(fighters: Array, projectiles: Array) -> void:
	var skip_sources := _resolve_clanks(fighters)

	var pending: Array = []  # [{entry, victim}]
	var groups: Array = []   # [{owner, source, entries:[{hb, center}]}]
	for f in fighters:
		if f.active_hitboxes.is_empty():
			continue
		var by_source := {}
		for e in f.active_hitboxes:
			var src: Object = e["source"]
			if skip_sources.has(src):
				continue
			if not by_source.has(src):
				by_source[src] = []
			by_source[src].append(e["hb"])
		for src in by_source:
			groups.append({"owner": f, "source": src, "boxes": by_source[src]})
	for p in projectiles:
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			groups.append({"owner": p.fighter, "source": p, "boxes": [p.hitbox]})

	for g in groups:
		var owner: Fighter = g["owner"]
		var src: Object = g["source"]
		var origin: Vector2 = src.hit_origin()
		var face: int = src.hit_facing()
		for victim in fighters:
			if victim == owner or not victim.can_be_hit():
				continue
			var hurt: Rect2 = victim.get_hurtbox_rect()
			var best: HitboxData = null
			for hb in g["boxes"]:
				if not src.can_hit(victim, hb):
					continue
				if best != null and hb.id >= best.id:
					continue
				if overlaps_rect(hb, origin, face, hurt):
					best = hb
			if best:
				pending.append({"owner": owner, "source": src, "hb": best, "victim": victim,
					"point": _contact_point(best, origin, face, hurt)})

	# Apply simultaneously (trades are allowed).
	for p in pending:
		var src: Object = p["source"]
		var hb: HitboxData = p["hb"]
		var victim: Fighter = p["victim"]
		var owner: Fighter = p["owner"]
		if not src.can_hit(victim, hb):
			continue
		src.register_hit(victim, hb)
		var hit := HitInfo.new()
		hit.attacker = owner
		hit.source = src
		hit.hitbox = hb
		var mult := 1.0
		var kbm := 1.0
		if src.get(&"damage_mult") != null:
			mult = src.damage_mult
			kbm = src.knockback_mult
		hit.damage = hb.damage * mult
		hit.knockback_mult = kbm
		hit.direction = src.hit_direction(victim, hb)
		hit.position = p["point"]
		var result: int = victim.receive_hit(hit)
		# Attacker freezes too (not for projectiles) — this is what sells impact.
		if src is FighterState:
			owner.hitstop = maxi(owner.hitstop, Game.config.compute_hitlag(hit.damage, hb))
		src.on_hit(victim, hit)
		hit_resolved.emit(owner, victim, hit, result)


## Ground attacks whose hitboxes touch cancel out ("clank"). If one is much
## stronger it wins and only the weaker attacker rebounds.
func _resolve_clanks(fighters: Array) -> Dictionary:
	var skip := {}
	for i in fighters.size():
		for j in range(i + 1, fighters.size()):
			var a: Fighter = fighters[i]
			var b: Fighter = fighters[j]
			if a.active_hitboxes.is_empty() or b.active_hitboxes.is_empty():
				continue
			if a.state_name != &"attack" or b.state_name != &"attack":
				continue
			var sa = a.state   # AttackState (untyped: base class lacks these methods)
			var sb = b.state
			if not (sa.is_ground_move() and sb.is_ground_move()):
				continue
			var hit_point = null
			var da := 0.0
			var db := 0.0
			for ea in a.active_hitboxes:
				for eb in b.active_hitboxes:
					var ha: HitboxData = ea["hb"]
					var hb: HitboxData = eb["hb"]
					if not (sa.can_hit(b, ha) and sb.can_hit(a, hb)):
						continue
					if ha.world_rect(a.global_position, a.facing).intersects(hb.world_rect(b.global_position, b.facing)):
						da = maxf(da, ha.damage * sa.damage_mult)
						db = maxf(db, hb.damage * sb.damage_mult)
						hit_point = (ha.world_center(a.global_position, a.facing) + hb.world_center(b.global_position, b.facing)) * 0.5
			if hit_point == null:
				continue
			var window := Game.config.clank_damage_window
			skip[sa] = true
			skip[sb] = true
			if da - db > window:
				b.change_state(&"rebound")
			elif db - da > window:
				a.change_state(&"rebound")
			else:
				a.change_state(&"rebound")
				b.change_state(&"rebound")
			a.hitstop = 6
			b.hitstop = 6
			clanked.emit(a, b, hit_point)
	return skip


static func overlaps_rect(hb: HitboxData, origin: Vector2, facing: int, rect: Rect2) -> bool:
	if hb.shape == HitboxData.Shape.RECT:
		return hb.world_rect(origin, facing).intersects(rect)
	var c := hb.world_center(origin, facing)
	var closest := Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
	return c.distance_squared_to(closest) <= hb.radius * hb.radius


static func _contact_point(hb: HitboxData, origin: Vector2, facing: int, rect: Rect2) -> Vector2:
	var c := hb.world_center(origin, facing)
	return Vector2(clampf(c.x, rect.position.x, rect.end.x), clampf(c.y, rect.position.y, rect.end.y))
