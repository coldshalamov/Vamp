## test_loot_pickup.gd — Feature #2: visible loot drops on kill + walk-over pickups.
##
## A slain enemy (elite guaranteed to drop) spawns a real pickup entity; walking the
## player over it routes the item into inventory (meta.add_item), and a full 40-slot bag
## auto-sells the overflow to coin so the value is never wasted. All deterministic: an
## elite's chance gate is 1.0, so two identical runs produce identical items + coin.
extends GutTest

const DT := 1.0 / 60.0


## Killing an elite leaves a pickup entity on the ground carrying a generated item.
func test_elite_kill_spawns_a_pickup() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var elite := sim.spawn_npc("thug", sim.player.pos + Vector2(40.0, 0.0), { "elite": true })
	var pickups_before := _count_pickups(sim)
	# damage_entity with a lethal hit routes through _on_entity_killed -> _maybe_drop_loot.
	sim.damage_entity(sim.player, elite, 9999.0, { "crit_chance": 0.0 })
	var pickups_after := _count_pickups(sim)
	assert_gt(pickups_after, pickups_before, "an elite kill must spawn a loot pickup")
	# The pickup carries a real generated item, stamped with a rarity/color the renderer reads.
	var pickup := _first_pickup(sim)
	assert_not_null(pickup, "a pickup entity exists after the elite dies")
	if pickup != null:
		var item: Dictionary = pickup.tags.get("item", {})
		assert_false(item.is_empty(), "the pickup carries an item payload")
		assert_true(item.has("rarity") and item.has("color"), "the item is stamped with rarity + color")
		# An elite's rarity floor is 'uncommon' — common should never appear.
		assert_ne(String(item.get("rarity", "common")), "common", "an elite drop is never merely common")
	sim.queue_free()


## Walking the player over a pickup collects it into inventory and removes the pickup.
func test_walking_over_a_pickup_collects_the_item() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	var elite := sim.spawn_npc("thug", sim.player.pos + Vector2(36.0, 0.0), { "elite": true })
	sim.damage_entity(sim.player, elite, 9999.0, { "crit_chance": 0.0 })
	var pickup := _first_pickup(sim)
	assert_not_null(pickup, "a pickup exists to collect")
	var inv_before: int = sim.meta.inventory.size()
	# Stand the player directly on top of the pickup and tick until it is collected.
	sim.player.pos = pickup.pos + Vector2(2.0, 0.0)
	for _i in range(5):
		sim.tick_sim(DT)
	assert_eq(_count_pickups(sim), 0, "the pickup is gone once walked over")
	assert_gt(sim.meta.inventory.size(), inv_before, "the item entered the inventory")
	# The collected item matched the one that was dropped (same rarity).
	var dropped_rarity := String((pickup.tags.get("item", {}) as Dictionary).get("rarity", ""))
	assert_eq(String(sim.meta.inventory.back().get("rarity", "")), dropped_rarity,
		"the collected item is the one that dropped")
	sim.queue_free()


## A full 40-slot bag does not discard the drop: overflow auto-sells to coin instead.
func test_full_bag_auto_sells_overflow_to_coin() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	# Fill the bag to the 40-slot cap with junk, recording the money.
	for _i in range(40):
		sim.meta.inventory.append({ "id": 9000 + _i, "slot": "charm", "rarity": "common",
			"level": 1, "name": "filler", "mods": {}, "affixes": [], "color": "#b8b8c0" })
	var money_before: int = sim.meta.money
	var elite := sim.spawn_npc("thug", sim.player.pos + Vector2(36.0, 0.0), { "elite": true })
	sim.damage_entity(sim.player, elite, 9999.0, { "crit_chance": 0.0 })
	var pickup := _first_pickup(sim)
	assert_not_null(pickup, "a pickup exists to collect")
	sim.player.pos = pickup.pos + Vector2(2.0, 0.0)
	for _i in range(5):
		sim.tick_sim(DT)
	# Bag stays capped, but coin rose — the overflow was auto-sold, not vaporised.
	assert_lte(sim.meta.inventory.size(), 40, "inventory never exceeds the cap")
	assert_gt(sim.meta.money, money_before, "an over-full bag auto-sold the drop for coin")
	sim.queue_free()


## Pickups are inert combatants: a swing through a dropped gem neither damages it nor
## blocks the hit from reaching an enemy behind it.
func test_pickup_is_inert_to_combat() -> void:
	var sim := VCSim.new()
	sim.new_game(42, "brujah")
	# Drop a pickup, then stand an enemy behind it along the swing line.
	var elite := sim.spawn_npc("thug", sim.player.pos + Vector2(36.0, 0.0), { "elite": true })
	sim.damage_entity(sim.player, elite, 9999.0, { "crit_chance": 0.0 })
	var pickup := _first_pickup(sim)
	assert_not_null(pickup, "a pickup sits between the player and the target")
	var foe := sim.spawn_npc("thug", sim.player.pos + Vector2(50.0, 0.0), {})
	foe.faction = "gang"
	var hp0 := foe.hp
	# A direct damage_entity call on the pickup returns 0 (it is not a valid target).
	var dealt_to_pickup := sim.damage_entity(sim.player, pickup, 30.0, { "crit_chance": 0.0 })
	assert_eq(dealt_to_pickup, 0.0, "a pickup takes no damage")
	assert_false(pickup.dead, "the pickup is not destroyed by a swing passing through it")
	# And the enemy is still fully hittable (the pickup did not block it).
	var dealt_to_foe := sim.damage_entity(sim.player, foe, 30.0, { "crit_chance": 0.0 })
	assert_gt(dealt_to_foe, 0.0, "the enemy behind the pickup is still damaged")
	assert_lt(foe.hp, hp0, "the enemy lost HP through the pickup")
	sim.queue_free()


## The whole drop+collect loop is deterministic across runs.
func test_loot_loop_is_deterministic() -> void:
	var a := _run_loot(101)
	var b := _run_loot(101)
	assert_eq(a["rarity"], b["rarity"], "same seed -> identical dropped rarity")
	assert_eq(a["name"], b["name"], "same seed -> identical dropped item name")
	assert_eq(a["money"], b["money"], "same seed -> identical coin after a full-bag collect")
	assert_eq(a["inv_size"], b["inv_size"], "same seed -> identical inventory size")


# ----------------------------------------------------------------------------- helpers

func _count_pickups(sim) -> int:
	var n := 0
	for e in sim.entities:
		if e != null and e.kind == "pickup" and not e.dead:
			n += 1
	return n


func _first_pickup(sim) -> SimEntity:
	for e in sim.entities:
		if e != null and e.kind == "pickup" and not e.dead:
			return e
	return null


func _run_loot(seed_value: int) -> Dictionary:
	var sim := VCSim.new()
	sim.new_game(seed_value, "brujah")
	for _i in range(40):
		sim.meta.inventory.append({ "id": 9000 + _i, "slot": "charm", "rarity": "common",
			"level": 1, "name": "filler", "mods": {}, "affixes": [], "color": "#b8b8c0" })
	var money_before: int = sim.meta.money
	var elite := sim.spawn_npc("thug", sim.player.pos + Vector2(36.0, 0.0), { "elite": true })
	sim.damage_entity(sim.player, elite, 9999.0, { "crit_chance": 0.0 })
	var pickup := _first_pickup(sim)
	var rarity := ""
	var name := ""
	if pickup != null:
		var item: Dictionary = pickup.tags.get("item", {})
		rarity = String(item.get("rarity", ""))
		name = String(item.get("name", ""))
		sim.player.pos = pickup.pos + Vector2(2.0, 0.0)
		for _i in range(5):
			sim.tick_sim(DT)
	var result := {
		"rarity": rarity, "name": name,
		"money": sim.meta.money - money_before,
		"inv_size": sim.meta.inventory.size(),
	}
	sim.queue_free()
	return result
