## BallisticLaunch.gd — deterministic helper for thrown bombs, bottles, potions, and grenades.
##
## The authoritative projectile remains SimProjectile. This helper only solves the initial horizontal
## and vertical velocities needed to land at a target after an exact number of physics ticks.
extends RefCounted
class_name BallisticLaunch

const FIXED_DT := 1.0 / 60.0


static func spawn(sim, origin: Vector2, target: Vector2, opts: Dictionary = {}) -> SimEntity:
	if sim == null:
		return null
	var projectile_opts := opts.duplicate(true)
	var flight_ticks := maxi(6, int(projectile_opts.get("flight_ticks", 42)))
	var duration := float(flight_ticks) * FIXED_DT
	var gravity := maxf(1.0, float(projectile_opts.get("gravity", 920.0)))
	var altitude := maxf(0.0, float(projectile_opts.get("altitude", 0.0)))
	# SimProjectile integrates altitude before gravity each tick (semi-implicit Euler). Solve that
	# discrete recurrence exactly so altitude reaches zero on `flight_ticks`, not merely near it.
	var n := float(flight_ticks)
	var vertical_velocity := (0.5 * gravity * FIXED_DT * FIXED_DT * n * (n - 1.0) - altitude) / duration
	var horizontal_velocity := (target - origin) / duration

	projectile_opts["ballistic"] = true
	projectile_opts["altitude"] = altitude
	projectile_opts["vertical_velocity"] = vertical_velocity
	projectile_opts["gravity"] = gravity
	projectile_opts["explode_on_ground"] = bool(projectile_opts.get("explode_on_ground", true))
	projectile_opts["life_ticks"] = maxi(int(projectile_opts.get("life_ticks", 0)), flight_ticks + 45)
	projectile_opts.erase("flight_ticks")
	return sim.spawn_projectile(origin, horizontal_velocity, projectile_opts)
