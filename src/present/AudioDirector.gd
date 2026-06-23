## AudioDirector.gd — the audio backend for the presentation layer (MASTER_PLAN Wave 4 #15-17).
##
## Owns the AudioServer bus graph (Master > Music / SFX / Voice / Ambient / UI) and is the single
## sink CueBus routes sound through. Three responsibilities:
##
##   1. BUS GRAPH + DUCKING — build the bus layout at runtime (so no .tres dependency) and duck
##      Music/Ambient under combat/critical stings, restoring to a stored baseline afterwards.
##   2. ONE-SHOTS — a tiny procedural synth (AudioStreamGenerator) plays short "thump"/"swallow"
##      blips on hit/feed cues so the game is not silent without any audio files shipped.
##   3. FEEDING HEARTBEAT — a continuous procedural heartbeat whose BPM/intensity scale with hunger,
##      started on feed.start, updated on feed.drain, stopped on feed.kill/spare/interrupt.
##
## This is a VIEW-side autoload: it never touches the Sim. It listens to CueBus.cue_emitted for the
## stateful heartbeat, and CueBus._play_audio() forwards one-shot/sting requests here. Everything is
## null-guarded so the game boots clean headless (no audio device → synthesize nothing, never error).
extends Node
# NOTE: no class_name — this script IS the `AudioDirector` autoload singleton.

# --- bus graph ---
const BUSES := ["Music", "SFX", "Voice", "Ambient", "UI"]

# --- synth config ---
const MIX_RATE := 22050.0           # generator sample rate; low is fine for blips/heartbeat
const TAU := 6.283185307179586

# --- ducking ---
const DUCK_DB := -8.0               # how far Music/Ambient drop under a combat/critical cue
const DUCK_ATTACK := 18.0           # db/sec toward the ducked target
const DUCK_RELEASE := 4.0           # db/sec back to baseline
var _duck_buses := ["Music", "Ambient"]
var _bus_baseline_db: Dictionary = {}   # bus_name -> resting volume_db (what we duck relative to)
var _duck_amount: float = 0.0           # 0 = no duck, 1 = full DUCK_DB
var _duck_target: float = 0.0

# --- procedural one-shot voice (a small pool so overlapping blips don't cut each other) ---
const SFX_VOICES := 4
var _sfx_players: Array = []            # Array[AudioStreamPlayer]
var _sfx_playbacks: Array = []          # Array[AudioStreamGeneratorPlayback or null]
var _sfx_jobs: Array = []               # Array[Dictionary] active synth jobs, parallel to players
var _sfx_round_robin: int = 0

# --- heartbeat voice ---
var _hb_player: AudioStreamPlayer = null
var _hb_playback = null                 # AudioStreamGeneratorPlayback or null
var _hb_active: bool = false
var _hb_phase: float = 0.0              # 0..1 position within the current beat
var _hb_bpm: float = 60.0
var _hb_intensity: float = 0.4          # 0..1 amplitude / "thump" weight
var _hb_hunger: float = 1.0             # latched hunger (0..~5), seeds BPM/intensity

# Recognised one-shot sample ids → synth recipe. Anything else falls back to a soft generic blip.
# freq = base pitch (Hz), dur = seconds, type = waveform shaping, gain = peak amplitude.
const ONE_SHOTS := {
	"thump":   { "freq": 90.0,  "dur": 0.10, "type": "thump", "gain": 0.55 },
	"swallow": { "freq": 140.0, "dur": 0.09, "type": "gulp",  "gain": 0.40 },
	"sting":   { "freq": 320.0, "dur": 0.14, "type": "sting", "gain": 0.45 },
	"ui":      { "freq": 880.0, "dur": 0.05, "type": "blip",  "gain": 0.25 },
}


func _ready() -> void:
	_build_bus_graph()
	_capture_baselines()
	_build_sfx_pool()
	_build_heartbeat_voice()
	_connect_cuebus()
	set_process(true)


# ----------------------------------------------------------------- bus graph

func _build_bus_graph() -> void:
	# Idempotent: GUT may keep this autoload alive across tests; never duplicate a bus.
	# Master (index 0) always exists. Add the children and route each send to Master.
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) != -1:
			continue
		var idx := AudioServer.get_bus_count()
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, "Master")


func _capture_baselines() -> void:
	# Record the resting volume of each duckable bus so ducking is relative (SettingsMenu may have
	# set these). If absent, baseline is 0 dB.
	for bus_name in _duck_buses:
		_bus_baseline_db[bus_name] = _bus_db(bus_name)


func _bus_db(bus_name: String) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 0.0
	return AudioServer.get_bus_volume_db(idx)


func _set_bus_db(bus_name: String, db: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx != -1:
		AudioServer.set_bus_volume_db(idx, db)


# ----------------------------------------------------------------- voices

func _make_generator_player(bus_name: String) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.25
	player.stream = gen
	var idx := AudioServer.get_bus_index(bus_name)
	player.bus = bus_name if idx != -1 else "Master"
	add_child(player)
	return player


func _build_sfx_pool() -> void:
	for i in range(SFX_VOICES):
		var p := _make_generator_player("SFX")
		_sfx_players.append(p)
		_sfx_playbacks.append(null)
		_sfx_jobs.append({})


func _build_heartbeat_voice() -> void:
	_hb_player = _make_generator_player("Ambient")


# ----------------------------------------------------------------- CueBus wiring

func _connect_cuebus() -> void:
	if CueBus == null:
		return
	# Stateful heartbeat rides the raw semantic stream (fires before _cue_defs lookup), so feed
	# cues drive it without needing a registered def.
	if not CueBus.cue_emitted.is_connected(_on_cue):
		CueBus.cue_emitted.connect(_on_cue)
	# Register the one-shot audio modalities. define() MERGES keys, so this co-exists with the
	# camera/vfx defs CameraDirector & VisualFX already registered for these events — match their
	# priorities (both COMBAT) so the merged scalar is unchanged.
	CueBus.define("hit.connect", CueBus.Priority.COMBAT, { "audio": "thump", "duration_ms": 200 })
	CueBus.define("feed.gulp.perfect", CueBus.Priority.COMBAT, { "audio": "swallow", "duration_ms": 250 })


func _on_cue(event_id: String, payload: Dictionary) -> void:
	match event_id:
		"feed.start":
			_start_heartbeat(float(payload.get("hunger", _hb_hunger)))
		"feed.drain":
			_update_heartbeat(float(payload.get("hunger", _hb_hunger)))
		"feed.kill", "feed.spare", "feed.interrupt":
			_stop_heartbeat()


# Bridge target for CueBus._play_audio(). priority drives ducking of Music/Ambient.
# Uses a literal threshold (CueBus.Priority.COMBAT == 20) so this stays callable even if CueBus
# is mid-teardown.
const DUCK_PRIORITY := 20
func play_cue_audio(sample_id: String, payload: Dictionary, priority: int) -> void:
	if priority >= DUCK_PRIORITY:
		_trigger_duck()
	play_one_shot(sample_id, payload)


# ----------------------------------------------------------------- ducking

func _trigger_duck() -> void:
	_duck_target = 1.0


func _update_duck(delta: float) -> void:
	# Snap toward whichever direction, then ease target back to 0 so a single sting releases.
	var rate := DUCK_ATTACK if _duck_amount < _duck_target else DUCK_RELEASE
	_duck_amount = move_toward(_duck_amount, _duck_target, rate * delta)
	_duck_target = move_toward(_duck_target, 0.0, DUCK_RELEASE * delta)
	for bus_name in _duck_buses:
		var base: float = _bus_baseline_db.get(bus_name, 0.0)
		_set_bus_db(bus_name, base + DUCK_DB * _duck_amount)


# ----------------------------------------------------------------- one-shots

func play_one_shot(sample_id: String, _payload: Dictionary = {}) -> void:
	var recipe: Dictionary = ONE_SHOTS.get(sample_id, {
		"freq": 220.0, "dur": 0.06, "type": "blip", "gain": 0.30,
	})
	# Pick a voice round-robin so rapid blips layer instead of stealing each other.
	var slot: int = _sfx_round_robin % max(1, _sfx_players.size())
	_sfx_round_robin += 1
	var player: AudioStreamPlayer = _sfx_players[slot] if slot < _sfx_players.size() else null
	if player == null:
		return
	var pb = _ensure_playback(player)
	if pb == null:
		return   # headless / no device → nothing to fill, stay silent
	_sfx_playbacks[slot] = pb
	_sfx_jobs[slot] = {
		"freq": float(recipe.get("freq", 220.0)),
		"dur": float(recipe.get("dur", 0.06)),
		"gain": float(recipe.get("gain", 0.3)),
		"type": String(recipe.get("type", "blip")),
		"t": 0.0,
	}


func _ensure_playback(player: AudioStreamPlayer):
	if player == null:
		return null
	if not player.playing:
		player.play()
	# get_stream_playback() can return null headless / before the mixer is ready — never assume.
	return player.get_stream_playback()


# ----------------------------------------------------------------- heartbeat

func _hunger_to_bpm(h: float) -> float:
	# hunger is ~0..5 (not normalized). Calm pulse when sated, racing when starving.
	var t := clampf(h / 5.0, 0.0, 1.0)
	return lerpf(54.0, 132.0, t)


func _hunger_to_intensity(h: float) -> float:
	var t := clampf(h / 5.0, 0.0, 1.0)
	return lerpf(0.30, 0.85, t)


func _start_heartbeat(hunger: float) -> void:
	_hb_hunger = hunger
	_hb_bpm = _hunger_to_bpm(hunger)
	_hb_intensity = _hunger_to_intensity(hunger)
	_hb_phase = 0.0
	_hb_active = true
	if _hb_player != null:
		_hb_playback = _ensure_playback(_hb_player)
		# _hb_playback may be null headless — _fill_heartbeat guards on it.


func _update_heartbeat(hunger: float) -> void:
	_hb_hunger = hunger
	# Ease toward the new tempo/intensity so drain ticks don't pop.
	_hb_bpm = lerpf(_hb_bpm, _hunger_to_bpm(hunger), 0.5)
	_hb_intensity = lerpf(_hb_intensity, _hunger_to_intensity(hunger), 0.5)
	if _hb_active and _hb_player != null and _hb_playback == null:
		_hb_playback = _ensure_playback(_hb_player)


func _stop_heartbeat() -> void:
	_hb_active = false
	_hb_phase = 0.0
	if _hb_player != null and _hb_player.playing:
		_hb_player.stop()
	_hb_playback = null


# ----------------------------------------------------------------- per-frame synthesis

func _process(delta: float) -> void:
	_update_duck(delta)
	_fill_one_shots()
	_fill_heartbeat()


func _fill_one_shots() -> void:
	for slot in range(_sfx_players.size()):
		var job: Dictionary = _sfx_jobs[slot]
		if job.is_empty():
			continue
		var pb = _sfx_playbacks[slot]
		if pb == null:
			_sfx_jobs[slot] = {}
			continue
		var frames: int = pb.get_frames_available()
		if frames <= 0:
			continue
		var dur: float = job["dur"]
		var freq: float = job["freq"]
		var gain: float = job["gain"]
		var wtype: String = job["type"]
		var t: float = job["t"]
		var step := 1.0 / MIX_RATE
		for _i in range(frames):
			if t >= dur:
				break
			var env := _one_shot_env(t, dur, wtype)
			var s := _wave(wtype, freq, t) * env * gain
			pb.push_frame(Vector2(s, s))
			t += step
		job["t"] = t
		if t >= dur:
			_sfx_jobs[slot] = {}   # done; voice freed for the next blip
		else:
			_sfx_jobs[slot] = job


func _fill_heartbeat() -> void:
	if not _hb_active or _hb_playback == null:
		return
	var frames: int = _hb_playback.get_frames_available()
	if frames <= 0:
		return
	var beat_len: float = 60.0 / max(1.0, _hb_bpm)   # seconds per beat
	var step := 1.0 / MIX_RATE
	for _i in range(frames):
		var s := _heartbeat_sample(_hb_phase) * _hb_intensity
		_hb_playback.push_frame(Vector2(s, s))
		_hb_phase += step / beat_len
		if _hb_phase >= 1.0:
			_hb_phase -= 1.0


# A "lub-dub" — two low thumps early in the beat, then silence. phase is 0..1 across one beat.
func _heartbeat_sample(phase: float) -> float:
	var v := 0.0
	v += _thump(phase, 0.00, 0.09, 46.0, 1.0)    # lub
	v += _thump(phase, 0.16, 0.08, 54.0, 0.75)   # dub
	return clampf(v, -1.0, 1.0)


# One decaying low-frequency thump positioned within the beat.
func _thump(phase: float, start: float, length: float, freq: float, amp: float) -> float:
	if phase < start or phase >= start + length:
		return 0.0
	var local := (phase - start) / length      # 0..1 within the thump
	var env := pow(1.0 - local, 2.2)            # fast decay
	# freq is in Hz but phase here is in "beats"; convert via an approximate beat duration so the
	# pitch reads as a low body-thump regardless of BPM.
	var beat_len: float = 60.0 / max(1.0, _hb_bpm)
	var secs := local * length * beat_len
	return sin(TAU * freq * secs) * env * amp


# ----------------------------------------------------------------- waveform helpers

func _one_shot_env(t: float, dur: float, wtype: String) -> float:
	var x := clampf(t / max(0.0001, dur), 0.0, 1.0)
	match wtype:
		"thump":
			return pow(1.0 - x, 2.5)            # percussive, fast decay
		"gulp":
			# quick swell then cut — a wet "tick"
			return sin(PI * x) * (1.0 - x * 0.4)
		"sting":
			return (1.0 - x)                    # linear fall, sharp attack
		_:
			# blip: short attack, exponential release
			var atk := clampf(x / 0.1, 0.0, 1.0)
			var rel := pow(1.0 - x, 2.0)
			return atk * rel


func _wave(wtype: String, freq: float, t: float) -> float:
	match wtype:
		"gulp":
			# downward pitch sweep gives the "swallow" character
			var f := freq * (1.0 - t * 2.5)
			return sin(TAU * maxf(40.0, f) * t)
		"sting":
			# two stacked partials for a metallic edge
			return sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 1.5 * t) * 0.3
		_:
			return sin(TAU * freq * t)
