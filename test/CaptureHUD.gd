## CaptureHUD.gd — Track C feedback evidence harness. Drives the REAL Boot flow, then fires every
## new HUD/feedback beat (feeding meter, damage numbers, enemy health bars, status icons, alert
## indicators, telegraphs, combo text, level-up/XP, loot, heat stars, dawn, cooldown ring, offscreen
## threat arrows, death-with-cause) and screenshots each so they are verified by SEEING, not asserts.
## Run windowed: Godot_v4.7-stable_win64.exe --path . res://test/CaptureHUD.tscn
extends Node

const BootScene := preload("res://scenes/Boot.tscn")
const OUT_DIR := "res://docs/evidence"

var _boot: Node = null


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	_boot = BootScene.instantiate()
	add_child(_boot)
	await get_tree().process_frame
	await get_tree().process_frame
	_run.call_deferred()


func _run() -> void:
	await _settle(95)
	if UIManager != null and UIManager.cb_new_game.is_valid():
		UIManager.cb_new_game.call()
	await _settle(40)
	await _shot("hud_01_spawn")

	# --- FEEDING EXPERIENCE: meter + resonance + victim state + choice + outcome ---
	var prey := _find_feedable()
	if prey != null and Sim != null and Sim.player != null and Sim.player.behaviour != null:
		Sim.player.pos = prey.pos - Vector2(26, 0)
		var b = Sim.player.behaviour
		b.set("feeding_target_id", prey.id)
		b.set("feed_progress", 0.5)
		Sim.emit_cue("feed.start", {
			"entity_id": Sim.player.id, "target_id": prey.id, "pos": prey.pos,
			"hunger": 3, "lethal": true, "seize": true, "resonance": "choleric" })
		Sim.emit_cue("feed.progress", {
			"entity_id": Sim.player.id, "target_id": prey.id,
			"progress_pct": 0.5, "blood_gained": 40.0, "resonance": "choleric" })
		await _settle(16)
		await _shot("hud_02_feed_meter")          # circular drain meter + resonance reveal + "Weakening"
		b.set("feed_progress", 0.78)
		Sim.emit_cue("feed.progress", {
			"entity_id": Sim.player.id, "target_id": prey.id,
			"progress_pct": 0.78, "blood_gained": 70.0, "resonance": "choleric" })
		Sim.emit_cue("feed.choice", {
			"entity_id": Sim.player.id, "target_id": prey.id, "can_spare": true, "blood_pct": 0.78 })
		await _settle(14)
		await _shot("hud_03_feed_choice")         # "Release [F] to spare / Hold to drain" + "Fading"
		Sim.emit_cue("feed.spare", {
			"entity_id": Sim.player.id, "target_id": prey.id, "pos": prey.pos,
			"blood": 72.0, "blood_gained": 72.0, "humanity_kept": true, "gulp_bonus": 0.0,
			"resonance": "choleric" })
		b.set("feeding_target_id", 0)
		Sim.emit_cue("feed.end", { "entity_id": Sim.player.id, "blood_total": 90.0 })
		Sim.emit_cue("feed.resonance", { "humour": "choleric", "pos": Sim.player.pos })
		await _settle(14)
		await _shot("hud_04_feed_spare")          # green "+72 Blood" popup + vial glow/surge

	# --- COMBAT READABILITY: damage numbers, health bar, status icons, alert, telegraph ---
	var thug := _find_hostile()
	if thug != null and Sim != null and Sim.player != null:
		Sim.player.pos = thug.pos - Vector2(34, 0)
		_aim(thug.pos)
		Sim.emit_cue("enemy.alert", { "entity_id": thug.id, "pos": thug.pos, "alert_level": "hostile" })
		await _settle(10)
		for i in range(10):
			_attack()
			await get_tree().process_frame
			await get_tree().process_frame
		# Guarantee a partial health bar even if swings whiffed, and stack status icons.
		thug.hp = thug.max_hp * 0.55
		Sim.emit_cue("status.applied", { "target_id": thug.id, "status": "bleeding", "duration": 300, "source_id": Sim.player.id })
		Sim.emit_cue("status.applied", { "target_id": thug.id, "status": "burning", "duration": 240, "source_id": Sim.player.id })
		Sim.emit_cue("status.applied", { "target_id": thug.id, "status": "stunned", "duration": 90, "source_id": Sim.player.id })
		Sim.emit_cue("damage.dealt", { "entity_id": Sim.player.id, "attacker_id": Sim.player.id, "target_id": thug.id, "amount": 18.0, "pos": thug.pos + Vector2(0, -20), "crit": false, "damage_type": "physical", "overkill": 0.0 })
		Sim.emit_cue("damage.dealt", { "entity_id": Sim.player.id, "attacker_id": Sim.player.id, "target_id": thug.id, "amount": 47.0, "pos": thug.pos + Vector2(8, -28), "crit": true, "damage_type": "physical", "overkill": 0.0 })
		Sim.emit_cue("enemy.telegraph", { "entity_id": thug.id, "pos": thug.pos, "attack_type": "ranged_bolt", "direction": thug.facing, "wind_up_ms": 450 })
		await _settle(8)
		await _shot("hud_05_combat")              # CRIT! + white number + health bar + status icons + telegraph line

		Sim.emit_cue("combo.trigger", { "entity_id": Sim.player.id, "target_id": thug.id, "combo_name": "Hemorrhage", "bonus_damage": 26.0, "pos": thug.pos + Vector2(0, -16) })
		await _settle(8)
		await _shot("hud_06_combo")               # "COMBO: Hemorrhage +26"

	# --- PROGRESSION: XP bar fill, level-up banner ---
	if Sim != null and Sim.player != null:
		Sim.emit_cue("player.xp", { "amount": 35, "pos": Sim.player.pos, "reason": "kill" })
		await _settle(8)
		Sim.emit_cue("player.level_up", { "level": 2, "ups": [] })
		await _settle(16)
		await _shot("hud_07_levelup")             # LEVEL 2 banner + "+1 Skill Point" + XP bar surge

		# --- LOOT / GEAR (surfaced via inventory.equipped) ---
		Sim.emit_cue("inventory.equipped", { "slot": "charm1", "item_id": 1, "name": "Ring of Conflagration" })
		await _settle(12)
		await _shot("hud_08_loot")

		# --- HEAT STARS (GTA-style), shown only when > 0 ---
		Sim.emit_cue("heat.changed", { "old_stars": 0, "new_stars": 3, "stars": 3, "heat": 3.0, "reason": "masquerade" })
		await _settle(10)
		await _shot("hud_09_heat")

		# --- DAWN INDICATOR (subtle, atmospheric) ---
		Sim.emit_cue("dawn.warning", { "clock": 5.0, "day": 1, "caption": "Dawn is close." })
		await _settle(12)
		await _shot("hud_10_dawn")

		# --- COOLDOWN RING on the hotbar ---
		if Sim.meta != null and Sim.meta.get("slots") != null and Sim.player.behaviour != null:
			var slots: Array = Sim.meta.slots
			if slots.size() > 0 and slots[0] != null and String(slots[0]) != "":
				var pid := String(slots[0])
				var cds = Sim.player.behaviour.get("power_cooldowns")
				if cds != null:
					cds[pid] = 150
				Sim.emit_cue("power.cooldown", { "power_id": pid, "remaining": 150 })
				await _settle(10)
				await _shot("hud_11_cooldown")

	# --- OFFSCREEN THREAT ARROWS: shove a hostile far off-screen ---
	var far := _find_hostile()
	if far != null and Sim != null and Sim.player != null:
		far.pos = Sim.player.pos + Vector2(2200, -400)
		far.hostile_to_player = true
		await _settle(12)
		await _shot("hud_12_offscreen")

	# --- DEATH EXPLANATION: who/why ---
	if Sim != null and Sim.player != null:
		var killer_id := thug.id if thug != null else 0
		Sim.emit_cue("player.death", { "cause": "fire", "killer_id": killer_id, "pos": Sim.player.pos, "explanation": "Killed by fire" })
		Sim.player.hp = 0.0
		Sim.player.dead = true
		await _settle(24)
		await _shot("hud_13_death")               # death screen WITH cause/explanation line

	print("[CAPTURE-HUD] done")
	await get_tree().create_timer(0.2).timeout
	get_tree().quit()


func _move(dir: Vector2) -> void:
	if Sim == null:
		return
	var a := InputAction.new(InputAction.Kind.MOVE)
	a.vector = dir
	Sim.apply_input(a)


func _aim(world_pos: Vector2) -> void:
	if Sim == null:
		return
	var a := InputAction.new(InputAction.Kind.AIM)
	a.vector = world_pos
	a.held = true
	Sim.apply_input(a)


func _attack() -> void:
	if Sim == null:
		return
	Sim.apply_input(InputAction.new(InputAction.Kind.ATTACK))


func _find_hostile() -> SimEntity:
	if Sim == null:
		return null
	for e in Sim.entities:
		if e != null and e.kind == "npc" and e.hostile_to_player and not e.dead:
			return e
	return null


func _find_feedable() -> SimEntity:
	if Sim == null:
		return null
	for e in Sim.entities:
		if e != null and e.kind == "npc" and not e.hostile_to_player and not e.dead:
			return e
	# fall back to any living npc
	for e in Sim.entities:
		if e != null and e.kind == "npc" and not e.dead:
			return e
	return null


func _settle(frames: int) -> void:
	for i in range(frames):
		await get_tree().process_frame


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var path := "%s/%s.png" % [OUT_DIR, label]
	var err := img.save_png(path)
	print("[CAPTURE-HUD] saved ", path, " (", err, ")")
