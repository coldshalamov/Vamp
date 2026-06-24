## ImpulsePhysics.gd — one deterministic momentum/impact pass that every shove rides.
##
## When two fast bodies overlap, this resolves a real collision: conserved mass-weighted momentum,
## damage to BOTH proportional to closing speed (never a constant), tumble on the struck body, and
## billiard chains. It is the explicit inversion of the rejected anti-pattern ("a frozen sprite
## slides in a straight line at constant speed and does constant damage"). Every knockback, the
## Tether sling, the Maw ejection, and dash shoulder-checks all write the existing knockback_vel
## channel and pass through here.
##
## Determinism: only "dirty" (fast) bodies enter the scan, iteration follows the stable entity order,
## solver runs a FIXED single pass with a hard contact cap (never "until rest"), and all touched
## fields (pos, knockback_vel, hp, tumble_ticks) are already in state_hash(). No RNG.
extends RefCounted
class_name ImpulsePhysics

const RESTITUTION := 0.35
const MAX_CONTACTS := 24        # bounds chain recursion; a runaway pile can't stall the tick
const DIRTY_SPEED2 := 900.0     # (~30 u/s)^2 — below this a body is calm and skips the physical pass
const MIN_CLOSING := 30.0       # need real approach speed to count as an impact (not a gentle touch)


static func resolve(sim) -> void:
	var dirty: Array = []
	for e in sim.entities:
		if e == null or e.dead:
			continue
		var k := String(e.kind)
		if k != "player" and k != "npc":
			continue   # projectiles + vehicles have their own bespoke impact handling
		var v: Vector2 = e.vel + e.knockback_vel
		if v.length_squared() > DIRTY_SPEED2:
			dirty.append(e)
	if dirty.is_empty():
		return   # a calm city pays ~nothing here

	var contacts := 0
	for a in dirty:
		if a.dead:
			continue
		for b in sim.entities:
			if b == null or b == a or b.dead:
				continue
			var kb := String(b.kind)
			if kb != "player" and kb != "npc":
				continue
			var ra := float(a.radius)
			var rb := float(b.radius)
			var apos: Vector2 = a.pos
			var bpos: Vector2 = b.pos
			var rr := ra + rb
			if apos.distance_squared_to(bpos) > rr * rr:
				continue
			contacts += 1
			if contacts > MAX_CONTACTS:
				return
			_resolve_pair(sim, a, b)
			if a.dead:
				break


static func _resolve_pair(sim, a, b) -> void:
	var apos: Vector2 = a.pos
	var bpos: Vector2 = b.pos
	var diff: Vector2 = bpos - apos
	var dist := diff.length()
	var n: Vector2 = diff / dist if dist > 0.001 else Vector2.RIGHT
	var sep := (float(a.radius) + float(b.radius)) - dist
	var va: Vector2 = a.vel + a.knockback_vel
	var vb: Vector2 = b.vel + b.knockback_vel
	var closing := (vb - va).dot(n)   # negative when the bodies are approaching

	var ma := maxf(float(a.mass), 0.1)
	var mb := maxf(float(b.mass), 0.1)

	if closing > -MIN_CLOSING:
		# resting contact: just de-overlap gently so bodies don't stack, no impact
		if sep > 0.0:
			a.pos = apos - n * (sep * 0.5)
			b.pos = bpos + n * (sep * 0.5)
		return

	# conserved, mass-weighted impulse along the contact normal
	var j := -(1.0 + RESTITUTION) * closing / (1.0 / ma + 1.0 / mb)
	var imp: Vector2 = n * j
	var akb: Vector2 = a.knockback_vel
	var bkb: Vector2 = b.knockback_vel
	a.knockback_vel = akb - imp / ma
	b.knockback_vel = bkb + imp / mb

	# positional correction (mass weighted) so they separate cleanly
	if sep > 0.0:
		a.pos = apos - n * (sep * (mb / (ma + mb)))
		b.pos = bpos + n * (sep * (ma / (ma + mb)))

	# damage BOTH, scaled by closing speed and the OTHER body's mass — a nudge tickles, a sling kills
	var speed := absf(closing)
	sim.damage_entity(null, a, _impact_damage(speed, mb, ma), { "cue": "physics.impact", "crit_chance": 0.0, "damage_type": "physical" })
	sim.damage_entity(null, b, _impact_damage(speed, ma, mb), { "cue": "physics.impact", "crit_chance": 0.0, "damage_type": "physical" })

	# tumble (control-loss + cosmetic spin) on NPCs only; the player keeps control
	var tt := clampi(int(speed * 0.25), 8, 50)
	if String(a.kind) == "npc":
		a.tumble_ticks = maxi(int(a.tumble_ticks), tt)
	if String(b.kind) == "npc":
		b.tumble_ticks = maxi(int(b.tumble_ticks), tt)
	sim.emit_cue("physics.impact", { "pos": (apos + bpos) * 0.5, "magnitude": speed, "damage_type": "physical" })


static func _impact_damage(speed: float, other_mass: float, self_mass: float) -> float:
	var d := speed * 0.08 * (other_mass / maxf(self_mass, 0.1))
	return clampf(d, 3.0, 60.0)
