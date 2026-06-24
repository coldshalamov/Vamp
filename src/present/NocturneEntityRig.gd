## NocturneEntityRig.gd — pooled continuously posed 2.5D view for one SimEntity.
##
## Authoritative state remains in SimEntity. This node interpolates presentation only.
extends "res://src/present/NocturneRigFigure.gd"
class_name NocturneEntityRig

func bind(e: SimEntity) -> void:
	entity = e
	entity_id = e.id
	name = "Entity_%d_%s" % [e.id, e.type_id]
	_facing_target = e.facing
	_facing_visual = e.facing
	_motion_target = e.vel
	_motion_visual = e.vel
	_spawn_age = 0.0
	_death_age = 0.0
	_refresh_palette(true)
	queue_redraw()


func unbind() -> void:
	entity = null
	entity_id = 0
	visible = false
	_palette.clear()
	_palette_key = ""
	_attack_timer = 0.0
	_dash_timer = 0.0
	_hit_timer = 0.0
	_cast_timer = 0.0


## Called once after the authoritative 60 Hz simulation tick.
func sync_physics(e: SimEntity, displacement: Vector2, fixed_dt: float) -> void:
	entity = e
	entity_id = e.id
	visible = true
	_facing_target = e.facing
	_motion_target = displacement / maxf(fixed_dt, EPSILON)
	if displacement.length_squared() > 0.04 and e.kind != "projectile":
		_gait_target += displacement.length() / maxf(e.radius, 5.0) * 2.15
	_death_age = _death_age + fixed_dt if e.dead else 0.0
	_refresh_palette(false)


func set_detail(level: int) -> void:
	detail_level = clampi(level, 0, 2)


func react(event_id: String, payload: Dictionary) -> void:
	if entity == null:
		return
	var source_id := int(payload.get("entity_id", payload.get("attacker_id", 0)))
	var target_id := int(payload.get("target_id", 0))
	match event_id:
		"attack.start":
			if source_id == entity_id:
				_attack_timer = ATTACK_DURATION
		"move.dash":
			if source_id == entity_id:
				_dash_timer = DASH_DURATION
		"damage.dealt", "damage.player", "hit.connect", "projectile.hit", "projectile.aoe":
			if target_id == entity_id:
				_hit_timer = HIT_DURATION
		"power.cast", "power.toggle":
			if entity.kind == "player" or source_id == entity_id:
				_cast_timer = CAST_DURATION
		"projectile.spawn", "npc.spawn", "vehicle.spawn":
			if source_id == entity_id:
				_spawn_age = 0.0


func _process(delta: float) -> void:
	if entity == null:
		return
	_time += delta
	_spawn_age += delta
	_attack_timer = maxf(0.0, _attack_timer - delta)
	_dash_timer = maxf(0.0, _dash_timer - delta)
	_hit_timer = maxf(0.0, _hit_timer - delta)
	_cast_timer = maxf(0.0, _cast_timer - delta)
	_motion_visual = _motion_visual.lerp(_motion_target, 1.0 - exp(-18.0 * delta))
	_facing_visual = lerp_angle(_facing_visual, _facing_target, 1.0 - exp(-24.0 * delta))
	_gait_visual = lerpf(_gait_visual, _gait_target, minf(1.0, delta * 26.0))
	queue_redraw()
