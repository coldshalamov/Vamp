## Boot.gd — minimal boot scene.
##
## Just enough to open the project without error. Phase 1 replaces this with the real
## title/new-game flow. For now it advances the sim deterministically and prints the
## state hash, proving the headless core works.
##
extends Node2D

func _ready() -> void:
	Sim.new_game(42, "brujah")
	print("[boot] sim initialised, seed=42, tick=", Sim.tick, " state_hash=", Sim.state_hash())

func _physics_process(_delta: float) -> void:
	Sim.tick_sim(1.0 / 60.0)
