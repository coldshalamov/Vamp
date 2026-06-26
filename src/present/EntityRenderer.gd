## EntityRenderer.gd — presentation manager for articulated humanoids and dynamic entities.
##
## Humanoids are individual CharacterAtlas2D nodes so Godot can interpolate their transforms and
## Y-sort them correctly. Projectiles and vehicles remain batched custom drawing to keep node count
## bounded. This class is a read-only view over Sim.entities.
extends Node2D
class_name EntityRenderer

## Live actor renderer: authored normal/specular atlas sprites (replaces the procedural
## CharacterRig2D "asparagus people"). Same setup/physics_sync/advance_visual/notify_event/
## set_detail_level contract, so this is a drop-in swap. Hero now ships 3D-rendered 192x256
## Blender cells; the remaining archetypes use 96x128 atlases until re-rendered (CharacterAtlas2D
## derives cell size per atlas, so the mix is seamless).
const CharacterRigScript := preload("res://src/present/CharacterAtlas2D.gd")
const TRAIL_POINTS := 8

var _entities: Array[SimEntity] = []
var _rigs: Dictionary = {}
var _projectile_trails: Dictionary = {}
var _time: float = 0.0


func setup(entities: Array[SimEntity]) -> void:
	_entities = entities


func _ready() -> void:
	y_sort_enabled = true
	z_index = 20
	if CueBus != null:
		CueBus.cue_emitted.connect(_on_cue)
	physics_sync(0.0)


## Called by GameRenderer after Sim.tick_sim(), guaranteeing presentation sees the completed tick.
func physics_sync(delta: float) -> void:
	var active_rigs: Dictionary = {}
	var active_projectiles: Dictionary = {}
	var player_pos := Sim.player.pos if Sim != null and Sim.player != null else Vector2.ZERO

	for e in _entities:
		if e == null:
			continue
		if e.kind in ["player", "npc"]:
			if e.kind == "npc" and (e.dead or e.downed):
				continue
			active_rigs[e.id] = true
			var rig = _rigs.get(e.id, null)
			if rig == null or not is_instance_valid(rig):
				rig = CharacterRigScript.new()
				rig.name = "Rig_%s_%d" % [e.type_id, e.id]
				add_child(rig)
				rig.setup(e)
				_rigs[e.id] = rig
			var distance := e.pos.distance_to(player_pos)
			rig.set_detail_level(2 if distance < 520.0 else (1 if distance < 920.0 else 0))
			rig.physics_sync(delta)
			# A cloaked Stalker (ambush_cloaked) is a faint shadow, not invisible — the player CAN spot
			# it with attention, and Auspex (detect) reveals it early in the sim. Render it heavily
			# dimmed so the ambush reads as stealth, not as a normal enemy standing in the open.
			var dim := 0.18 if bool(e.tags.get("cloaked", false)) else 1.0
			rig.modulate.a = dim
		elif e.kind == "projectile" and not e.dead:
			active_projectiles[e.id] = true
			var trail: Array = _projectile_trails.get(e.id, [])
			trail.append(e.pos)
			while trail.size() > TRAIL_POINTS:
				trail.pop_front()
			_projectile_trails[e.id] = trail

	for id in _rigs.keys():
		if not active_rigs.has(id):
			var rig = _rigs[id]
			if is_instance_valid(rig):
				rig.queue_free()
			_rigs.erase(id)
	for id in _projectile_trails.keys():
		if not active_projectiles.has(id):
			_projectile_trails.erase(id)
	queue_redraw()


func _process(delta: float) -> void:
	_time += delta
	for rig in _rigs.values():
		if is_instance_valid(rig):
			rig.advance_visual(delta)
	queue_redraw()


func _on_cue(event_id: String, payload: Dictionary) -> void:
	# One subscription fans semantic events into the affected rigs; dozens of actors do not each
	# subscribe to the global bus.
	var ids: Array[int] = []
	for key in ["entity_id", "target_id", "attacker_id"]:
		var id := int(payload.get(key, 0))
		if id != 0 and not ids.has(id):
			ids.append(id)
	for id in ids:
		var rig = _rigs.get(id, null)
		if rig != null and is_instance_valid(rig):
			rig.notify_event(event_id, payload)
	if event_id == "player.respawn":
		for rig in _rigs.values():
			if is_instance_valid(rig):
				rig.notify_event(event_id, payload)


func _draw() -> void:
	# Batched non-humanoid entities. Self drawing occurs beneath child rigs, which is desirable for
	# vehicles and projectile shadows; bright projectile cores still read through their additive VFX.
	for e in _entities:
		if e == null:
			continue
		if e.kind == "npc" and (e.dead or e.downed):
			_draw_body(e)
			continue
		if e.dead:
			continue
		if e.kind == "vehicle":
			_draw_vehicle(e)
		elif e.kind == "projectile":
			_draw_projectile(e)
	# Loot pickups draw LAST so they read on top — a reward glowing above the carnage, never hidden
	# behind a corpse or a vehicle. They are inert (no behaviour), so they live in the batched pass.
	for e in _entities:
		if e != null and e.kind == "pickup" and not e.dead:
			_draw_pickup(e)


# ----------------------------------------------------------------------------- inert bodies

func _draw_body(e: SimEntity) -> void:
	var r := maxf(e.radius, 8.0)
	var body := Color("332b32") if e.dead else Color("423849")
	var trim := Color("8b7788") if e.dead else Color("a48ca8")
	var blood := Color(0.52, 0.02, 0.06, 0.40) if e.dead else Color(0.18, 0.02, 0.04, 0.24)
	draw_set_transform(e.pos + Vector2(0, 3), e.facing, Vector2(1.45, 0.42))
	draw_circle(Vector2.ZERO, r, Color(0, 0, 0, 0.36))
	draw_set_transform(e.pos, e.facing + PI * 0.5, Vector2.ONE)
	draw_line(Vector2(-r * 0.90, 0), Vector2(r * 0.74, 0), body, r * 0.92, true)
	draw_circle(Vector2(r * 0.98, 0), r * 0.34, body.lightened(0.12))
	draw_line(Vector2(-r * 0.30, -r * 0.36), Vector2(r * 0.28, r * 0.34), trim, 1.2, true)
	if e.dead:
		draw_circle(Vector2(-r * 0.52, r * 0.12), r * 0.55, blood)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# ----------------------------------------------------------------------------- projectiles

func _draw_projectile(e: SimEntity) -> void:
	# SimProjectile exposes height/vertical_velocity/spin/ballistic as properties on e.behaviour.
	var altitude := 0.0
	var vertical_velocity := 0.0
	var ballistic := false
	if e.behaviour != null:
		var hv = e.behaviour.get("height")
		if hv != null:
			altitude = float(hv)
		var vv = e.behaviour.get("vertical_velocity")
		if vv != null:
			vertical_velocity = float(vv)
		ballistic = bool(e.behaviour.get("ballistic"))
	var lift := Vector2(0.0, -altitude * 0.42)
	var pos := e.pos + lift
	var r := maxf(e.radius, 4.0)
	var kind := String(e.type_id)
	var trail: Array = _projectile_trails.get(e.id, [])

	# Ground shadow scales down and softens as the object rises, making the ballistic arc readable.
	var shadow_scale := clampf(1.0 - altitude / 190.0, 0.25, 1.0)
	draw_set_transform(e.pos + Vector2(0, 2), 0.0, Vector2(1.35 * shadow_scale, 0.42 * shadow_scale))
	draw_circle(Vector2.ZERO, r * 1.15, Color(0, 0, 0, 0.34 * shadow_scale))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	if trail.size() >= 2:
		for i in range(1, trail.size()):
			var p0: Vector2 = trail[i - 1]
			var p1: Vector2 = trail[i]
			var a := float(i) / float(trail.size())
			var projected_lift := lift * a
			var col := Color(0.70, 0.04, 0.13, a * 0.26)
			draw_line(p0 + projected_lift, p1 + projected_lift, col, maxf(1.0, r * a * 0.65), true)

	if kind.contains("flask") or kind.contains("bomb") or kind.contains("potion"):
		_draw_flask(pos, e.facing, r, vertical_velocity, ballistic)
	elif kind.contains("bullet"):
		var forward := Vector2.RIGHT.rotated(e.facing)
		draw_line(pos - forward * r * 3.0, pos, Color(1.0, 0.78, 0.45, 0.62), maxf(1.2, r * 0.55), true)
		draw_circle(pos, r * 0.48, Color(1.0, 0.93, 0.72))
	else:
		var forward := Vector2.RIGHT.rotated(e.facing)
		draw_line(pos - forward * r * 2.8, pos, Color(0.72, 0.035, 0.13, 0.38), r * 0.75, true)
		draw_circle(pos, r + 2.5, Color(0.78, 0.04, 0.15, 0.28))
		draw_circle(pos, r, Color("df1834"))
		draw_circle(pos - forward * r * 0.25, r * 0.40, Color("ffd0d6"))


func _draw_flask(pos: Vector2, facing: float, r: float, vertical_velocity: float, ballistic: bool) -> void:
	var spin := facing + (_time * 7.0 if ballistic else 0.0) + vertical_velocity * 0.002
	var forward := Vector2.RIGHT.rotated(spin)
	var side := Vector2(-forward.y, forward.x)
	var glass := Color(0.52, 0.72, 0.76, 0.82)
	var liquid := Color(0.66, 0.055, 0.12, 0.92)
	var outline := Color(0.02, 0.03, 0.04, 0.92)
	var body_center := pos - forward * r * 0.25
	var points := PackedVector2Array([
		body_center - forward * r * 0.75 - side * r * 0.55,
		body_center + forward * r * 0.55 - side * r * 0.75,
		body_center + forward * r * 0.95 + side * r * 0.30,
		body_center + forward * r * 0.25 + side * r * 0.82,
		body_center - forward * r * 0.70 + side * r * 0.55,
	])
	draw_colored_polygon(points, outline)
	var inner := PackedVector2Array()
	for p in points:
		inner.append(body_center.lerp(p, 0.78))
	draw_colored_polygon(inner, glass)
	var liquid_center := body_center + side * r * 0.18
	draw_line(liquid_center - forward * r * 0.55, liquid_center + forward * r * 0.35, liquid, r * 0.72, true)
	var neck_a := body_center + forward * r * 0.62
	var neck_b := neck_a + forward * r * 0.92
	draw_line(neck_a, neck_b, outline, r * 0.62, true)
	draw_line(neck_a, neck_b, glass.lightened(0.22), r * 0.36, true)
	draw_line(neck_b - side * r * 0.35, neck_b + side * r * 0.35, Color("c8b49b"), r * 0.42, true)
	draw_line(body_center - side * r * 0.25 - forward * r * 0.35, body_center - side * r * 0.25 + forward * r * 0.20, Color(1, 1, 1, 0.58), maxf(0.8, r * 0.18), true)


# ----------------------------------------------------------------------------- loot pickups

## LOOT DROP visual: a floating, pulsing gem tinted by the item's rarity color (the backend
## stamps the hex onto every generated item). A soft ground shadow sells the hover; the
## gem bobs and pulses so loot catches the eye from across a fight. Draws on top of every
## other entity so a drop is never lost under a body or a vehicle.
func _draw_pickup(e: SimEntity) -> void:
	var color_hex := String(e.tags.get("color", "#b8b8c0"))
	var col := Color.from_string(color_hex, Color("b8b8c0"))
	var r := 9.0
	# Bob + pulse: the gem floats and breathes so a drop is readable at a glance.
	var bob := sin(_time * 3.0 + float(e.id)) * 3.0
	var pulse := 0.5 + 0.5 * sin(_time * 5.0 + float(e.id) * 1.7)
	var center := e.pos + Vector2(0.0, -7.0 + bob)
	# Ground shadow shrinks as the gem rises, mirroring the projectile ballistic shadow.
	var shadow_scale := clampf(1.0 + bob * 0.03, 0.7, 1.1)
	draw_set_transform(e.pos + Vector2(0, 3), 0.0, Vector2(1.3 * shadow_scale, 0.42 * shadow_scale))
	draw_circle(Vector2.ZERO, r * 1.1, Color(0, 0, 0, 0.34))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Outer glow halo (rarity-tinted): the "look here" beacon.
	var glow_alpha := 0.20 + pulse * 0.18
	draw_circle(center, r * (2.6 + pulse * 0.5), Color(col.r, col.g, col.b, glow_alpha * 0.5))
	draw_circle(center, r * (1.9 + pulse * 0.3), Color(col.r, col.g, col.b, glow_alpha))
	# The gem itself: a faceted diamond read.
	var gem := col.lightened(0.18)
	var gem_hi := col.lightened(0.55)
	var gem_lo := col.darkened(0.30)
	var pts := PackedVector2Array([
		center + Vector2(0, -r * 1.15),
		center + Vector2(r * 0.78, 0),
		center + Vector2(0, r * 1.0),
		center + Vector2(-r * 0.78, 0),
	])
	draw_colored_polygon(pts, gem)
	# Facet lines split the diamond into light/dark halves for a cut-gem look.
	draw_line(center + Vector2(0, -r * 1.15), center + Vector2(r * 0.78, 0), gem_hi, 1.2, true)
	draw_line(center + Vector2(0, -r * 1.15), center + Vector2(-r * 0.78, 0), gem_lo, 1.2, true)
	draw_line(center + Vector2(r * 0.78, 0), center + Vector2(0, r * 1.0), gem_lo, 1.0, true)
	# Specular glint rides the pulse — the "shiny" tell.
	var glint_r := r * (0.28 + pulse * 0.12)
	draw_circle(center + Vector2(-r * 0.22, -r * 0.40), glint_r, Color(1, 1, 1, 0.55 + pulse * 0.20))


# ----------------------------------------------------------------------------- vehicles

func _draw_vehicle(e: SimEntity) -> void:
	var r := e.radius
	var length := maxf(r * 2.8, 48.0)
	var width := maxf(r * 1.45, 23.0)
	var police := _entity_is_police(e)
	var body := Color("17243a") if police else Color("15171d")
	var trim := Color("8095ba") if police else Color("585d66")
	var glass := Color(0.08, 0.14, 0.20, 0.92)
	draw_set_transform(e.pos, e.facing, Vector2.ONE)
	# Long contact shadow and four wheels keep the vehicle planted.
	draw_rect(Rect2(Vector2(-length * 0.52 + 3, -width * 0.53 + 4), Vector2(length * 1.04, width * 1.06)), Color(0, 0, 0, 0.42))
	for wx in [-length * 0.30, length * 0.30]:
		for wy in [-width * 0.55, width * 0.43]:
			draw_rect(Rect2(Vector2(wx - length * 0.10, wy), Vector2(length * 0.20, width * 0.14)), Color("08090c"))
	# Chamfered body rather than two programmer rectangles.
	draw_colored_polygon(PackedVector2Array([
		Vector2(-length * 0.48, -width * 0.42),
		Vector2(length * 0.38, -width * 0.48),
		Vector2(length * 0.50, -width * 0.25),
		Vector2(length * 0.50, width * 0.25),
		Vector2(length * 0.38, width * 0.48),
		Vector2(-length * 0.48, width * 0.42),
	]), body)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-length * 0.15, -width * 0.34),
		Vector2(length * 0.24, -width * 0.31),
		Vector2(length * 0.30, width * 0.31),
		Vector2(-length * 0.15, width * 0.34),
	]), glass)
	draw_line(Vector2(-length * 0.15, 0), Vector2(length * 0.30, 0), trim.darkened(0.25), 1.2, true)
	draw_line(Vector2(-length * 0.44, -width * 0.38), Vector2(length * 0.38, -width * 0.43), body.lightened(0.16), 1.3, true)
	# Headlights project into the street; police lightbar pulses without touching authoritative time.
	var headlight := Color(1.0, 0.92, 0.68, 0.16)
	draw_colored_polygon(PackedVector2Array([
		Vector2(length * 0.45, -width * 0.31), Vector2(length * 0.45, width * 0.31),
		Vector2(length * 1.18, width * 0.78), Vector2(length * 1.18, -width * 0.78),
	]), headlight)
	if police:
		var pulse := 0.55 + 0.45 * sin(_time * 12.0)
		draw_rect(Rect2(Vector2(-length * 0.02, -width * 0.12), Vector2(length * 0.20, width * 0.24)), Color(0.10, 0.16, 0.22, 0.95))
		draw_circle(Vector2(length * 0.03, -width * 0.15), 2.0, Color(0.25, 0.48, 1.0, pulse))
		draw_circle(Vector2(length * 0.13, width * 0.15), 2.0, Color(1.0, 0.16, 0.18, 1.0 - pulse * 0.5))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _entity_is_police(e: SimEntity) -> bool:
	return e.type_id == "police" or e.faction == "police"
