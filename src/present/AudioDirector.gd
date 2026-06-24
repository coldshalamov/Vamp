## AudioDirector.gd — the audio backend for the presentation layer (MASTER_PLAN Wave 4 #15-17).
##
## Owns the AudioServer bus graph (Master > Music / SFX / Voice / Ambient / UI) and is the single
## sink CueBus routes sound through. Four responsibilities:
##
##   1. BUS GRAPH + DUCKING — build the bus layout at runtime (so no .tres dependency) and duck
##      Music/Ambient under combat/critical stings, restoring to a stored baseline afterwards.
##   2. ONE-SHOTS — a tiny procedural synth (AudioStreamGenerator) plays short "thump"/"swallow"
##      blips on hit/feed cues so the game is not silent without any audio files shipped.
##   3. FEEDING HEARTBEAT — a continuous procedural heartbeat whose BPM/intensity scale with hunger,
##      started on feed.start, updated on feed.drain, stopped on feed.kill/spare/interrupt.
##   4. AMBIENT BED + FOOTSTEPS — a low drone (wind/hum/distant traffic) loops on the Ambient bus;
##      footstep clicks are synthesised when move.sprint fires.
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

# --- ambient bed voice ---
var _amb_player: AudioStreamPlayer = null
var _amb_playback = null                # AudioStreamGeneratorPlayback or null
var _amb_phase: float = 0.0            # accumulates freely — the drone loops via wrapping

# --- footstep voice ---
# A dedicated voice so footsteps don't steal from the SFX round-robin pool.
var _foot_player_l: AudioStreamPlayer = null   # panned left
var _foot_player_r: AudioStreamPlayer = null   # panned right
var _foot_pb_l = null
var _foot_pb_r = null
var _foot_job_l: Dictionary = {}
var _foot_job_r: Dictionary = {}
var _foot_next_left: bool = true       # alternates L/R each step
var _foot_timer: float = 0.0          # seconds since last footstep click
var _foot_active: bool = false        # true while move.sprint is live this frame
const FOOT_INTERVAL := 0.38           # seconds between clicks at sprint cadence

# Recognised one-shot sample ids → synth recipe. Anything else falls back to a soft generic blip.
# freq = base pitch (Hz), dur = seconds, type = waveform shaping, gain = peak amplitude.
const ONE_SHOTS := {
	"thump":   { "freq": 90.0,  "dur": 0.10, "type": "thump", "gain": 0.55 },
	"swallow": { "freq": 140.0, "dur": 0.09, "type": "gulp",  "gain": 0.40 },
	"sting":   { "freq": 320.0, "dur": 0.14, "type": "sting", "gain": 0.45 },
	"ui":      { "freq": 880.0, "dur": 0.05, "type": "blip",  "gain": 0.25 },
	"swish":   { "freq": 520.0, "dur": 0.08, "type": "sting", "gain": 0.22 },   # melee swing
	"cast":    { "freq": 300.0, "dur": 0.18, "type": "sting", "gain": 0.30 },   # power cast
	"boom":    { "freq": 58.0,  "dur": 0.24, "type": "thump", "gain": 0.62 },   # AoE / heavy impact
	"whoosh":  { "freq": 260.0, "dur": 0.12, "type": "sting", "gain": 0.24 },   # dash
	"thud":    { "freq": 70.0,  "dur": 0.15, "type": "thump", "gain": 0.50 },   # body falls
	"chime":   { "freq": 660.0, "dur": 0.22, "type": "blip",  "gain": 0.32 },   # level up
	"shot":    { "freq": 230.0, "dur": 0.10, "type": "sting", "gain": 0.30 },   # blood bolt
	"impact":  { "freq": 62.0,  "dur": 0.18, "type": "thump", "gain": 0.65 },   # melee hit.connect (normal)
	"impact_crit": { "freq": 48.0, "dur": 0.26, "type": "thump", "gain": 0.82 }, # melee hit.connect (crit)
	"kiss":    { "freq": 160.0, "dur": 0.20, "type": "gulp",  "gain": 0.55 },   # feed.gulp.perfect wet sting
}


func _ready() -> void:
	_build_bus_graph()
	_apply_saved_volumes()   # restore saved cfg levels BEFORE capturing baselines
	_capture_baselines()
	_build_sfx_pool()
	_build_heartbeat_voice()
	_build_ambient_voice()
	_build_footstep_voices()
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


## Public API called by SettingsMenu sliders at runtime and by _apply_saved_volumes at boot.
## For duckable buses (Music, Ambient) we ALSO update _bus_baseline_db so _update_duck doesn't
## overwrite the new level on the very next frame.
func set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var db := linear_to_db(clampf(linear, 0.0, 1.0))
	_set_bus_db(bus_name, db)
	if bus_name in _duck_buses:
		_bus_baseline_db[bus_name] = db


## Read user://settings.cfg [audio] and push all five bus levels into AudioServer.
## Called at boot (before _capture_baselines) so the first frame starts at the saved volume.
func _apply_saved_volumes() -> void:
	const CFG_PATH := "user://settings.cfg"
	const SECTION := "audio"
	var cfg := ConfigFile.new()
	if cfg.load(CFG_PATH) != OK:
		return
	var bus_map := {
		"master":  "Master",
		"music":   "Music",
		"sfx":     "SFX",
		"voice":   "Voice",
		"ambient": "Ambient",
	}
	var defaults := { "master": 1.0, "music": 0.8, "sfx": 1.0, "voice": 1.0, "ambient": 0.8 }
	for key in bus_map:
		var v: float = float(cfg.get_value(SECTION, key, defaults[key]))
		set_bus_volume_linear(bus_map[key], v)


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


func _build_ambient_voice() -> void:
	_amb_player = _make_generator_player("Ambient")
	if _amb_player != null:
		_amb_playback = _ensure_playback(_amb_player)


func _build_footstep_voices() -> void:
	# Two mono players, one per foot. Bus = SFX; subtle gain keeps them under combat SFX.
	_foot_player_l = _make_generator_player("SFX")
	_foot_player_r = _make_generator_player("SFX")
	if _foot_player_l != null:
		_foot_pb_l = _ensure_playback(_foot_player_l)
	if _foot_player_r != null:
		_foot_pb_r = _ensure_playback(_foot_player_r)


# ----------------------------------------------------------------- CueBus wiring

func _connect_cuebus() -> void:
	if CueBus == null:
		return
	# Stateful heartbeat rides the raw semantic stream (fires before _cue_defs lookup), so feed
	# cues drive it without needing a registered def.
	if not CueBus.cue_emitted.is_connected(_on_cue):
		CueBus.cue_emitted.connect(_on_cue)
	# Register audio modalities. define() MERGES keys, co-existing with camera/vfx defs.
	# hit.connect: audio is handled crit-conditionally in _on_cue — no "audio" key here to avoid
	# double-fire (cue_emitted fires _on_cue; define "audio" key would fire play_cue_audio on top).
	CueBus.define("hit.connect", CueBus.Priority.COMBAT, { "duration_ms": 200 })
	# feed.gulp.perfect: "kiss" sting handled in _on_cue for the same reason; keep priority registered.
	CueBus.define("feed.gulp.perfect", CueBus.Priority.COMBAT, { "duration_ms": 250 })


func _on_cue(event_id: String, payload: Dictionary) -> void:
	match event_id:
		"feed.start":
			_start_heartbeat(float(payload.get("hunger", _hb_hunger)))
		"feed.drain":
			_update_heartbeat(float(payload.get("hunger", _hb_hunger)))
		"feed.kill", "feed.spare", "feed.interrupt":
			_stop_heartbeat()
		# hit.connect: crit-conditional impact thud (heavier on crit). Handled here not in define
		# to read payload.crit without double-firing via the "audio" CueBus path.
		"hit.connect":
			var is_crit: bool = bool(payload.get("crit", false))
			play_one_shot("impact_crit" if is_crit else "impact", payload)
		# feed.gulp.perfect: wet "kiss" sting on a perfectly-timed gulp tap.
		"feed.gulp.perfect":
			play_one_shot("kiss", payload)
		# move.sprint: trigger footstep cadence each sprint cue (rate-limited by _foot_timer).
		"move.sprint":
			_foot_active = true
		# Procedural SFX coverage so the game isn't near-silent (no audio files shipped).
		"attack.start":
			play_one_shot("swish", payload)
		"power.cast":
			play_one_shot("cast", payload)
		"damage.dealt":
			play_one_shot("thump", payload)
		"damage.player":
			play_one_shot("boom", payload)
		"move.dash":
			play_one_shot("whoosh", payload)
		"npc.death":
			play_one_shot("thud", payload)
		"power.potence.quake_hit", "power.potence.hit":
			play_one_shot("boom", payload)
		"blood.command":
			play_one_shot("shot", payload)
		"player.level_up", "power.unlocked":
			play_one_shot("chime", payload)


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
	_fill_ambient()
	_fill_footsteps(delta)
	_foot_active = false   # reset per-frame sprint flag; move.sprint re-sets next frame if still running


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


# ----------------------------------------------------------------- ambient bed

## Low procedural drone: three detuned sine layers (wind-like hum) + a slow-beating sub oscillator
## for city-night texture. Loops seamlessly — phase wraps mod 1.0 each frame.
## Gain is intentionally quiet (0.16) so it sits under the heartbeat and other SFX.
func _fill_ambient() -> void:
	if _amb_playback == null:
		if _amb_player != null and not _amb_player.playing:
			_amb_playback = _ensure_playback(_amb_player)
		if _amb_playback == null:
			return
	var frames: int = _amb_playback.get_frames_available()
	if frames <= 0:
		return
	var step := 1.0 / MIX_RATE
	for _i in range(frames):
		var t := _amb_phase   # time within the drone cycle (wraps freely)
		# Layer 1: low wind hum at ~55 Hz, very slow amplitude tremolo at 0.11 Hz
		var tremolo1 := 0.5 + 0.5 * sin(TAU * 0.11 * t)
		var layer1 := sin(TAU * 55.0 * t) * tremolo1 * 0.08
		# Layer 2: detuned harmonic at ~82 Hz, slightly different tremolo phase
		var tremolo2 := 0.5 + 0.5 * sin(TAU * 0.13 * t + 1.1)
		var layer2 := sin(TAU * 82.0 * t) * tremolo2 * 0.05
		# Layer 3: distant traffic/ventilation rumble — very low 28 Hz, slow beat at 0.07 Hz
		var beat := 0.4 + 0.6 * sin(TAU * 0.07 * t)
		var layer3 := sin(TAU * 28.0 * t) * beat * 0.06
		var s := layer1 + layer2 + layer3
		# Stereo width: slight L/R phase offset on layer2 gives the ambient a sense of space.
		var s_l := s
		var s_r := s + sin(TAU * 82.0 * (t + 0.003)) * tremolo2 * 0.03
		_amb_playback.push_frame(Vector2(s_l, s_r))
		_amb_phase += step
		# Wrap at a long period (100 s) so sin() args don't drift into float imprecision.
		if _amb_phase >= 100.0:
			_amb_phase -= 100.0


# ----------------------------------------------------------------- footsteps

## Synthesise a single footstep click: a short broadband transient (filtered noise burst) with a
## low-freq body thump underneath, panned full-left or full-right to alternate feet.
## Stereo pan is achieved by pushing to one channel only in a mono-routing player.
func _fill_footstep_job(pb, job: Dictionary, is_left: bool) -> Dictionary:
	if pb == null or job.is_empty():
		return job
	var frames: int = pb.get_frames_available()
	if frames <= 0:
		return job
	var dur: float = 0.055     # short transient
	var t: float = job.get("t", 0.0)
	var step := 1.0 / MIX_RATE
	for _i in range(frames):
		if t >= dur:
			break
		var x := clampf(t / dur, 0.0, 1.0)
		var env := pow(1.0 - x, 3.0)                         # very fast decay
		# Body thump (very low) + click (mid-high noise approximation via sum of primes)
		var thump_s := sin(TAU * 68.0 * t) * env * 0.22
		# Noise-like texture: sum of inharmonic sine partials (deterministic, no randf)
		var click_s := (sin(TAU * 1400.0 * t) + sin(TAU * 2300.0 * t) * 0.6
			+ sin(TAU * 3700.0 * t) * 0.3) * env * 0.10
		var s := thump_s + click_s
		# Pan: left foot → left channel only; right foot → right channel only (subtle, not hard-pan)
		var sv := Vector2(s * 0.8, s * 0.2) if is_left else Vector2(s * 0.2, s * 0.8)
		pb.push_frame(sv)
		t += step
	job["t"] = t
	if t >= dur:
		return {}   # done
	return job


func _fill_footsteps(delta: float) -> void:
	# Advance timer; fire a click at the sprint cadence while _foot_active.
	if _foot_active:
		_foot_timer += delta
		if _foot_timer >= FOOT_INTERVAL:
			_foot_timer -= FOOT_INTERVAL
			# Kick off a new footstep job on whichever foot is next.
			if _foot_next_left:
				if _foot_pb_l == null and _foot_player_l != null:
					_foot_pb_l = _ensure_playback(_foot_player_l)
				if _foot_pb_l != null:
					_foot_job_l = { "t": 0.0 }
			else:
				if _foot_pb_r == null and _foot_player_r != null:
					_foot_pb_r = _ensure_playback(_foot_player_r)
				if _foot_pb_r != null:
					_foot_job_r = { "t": 0.0 }
			_foot_next_left = not _foot_next_left
	else:
		# No sprint this frame; don't advance timer so next sprint starts immediately.
		_foot_timer = 0.0
	# Fill active footstep jobs.
	_foot_job_l = _fill_footstep_job(_foot_pb_l, _foot_job_l, true)
	_foot_job_r = _fill_footstep_job(_foot_pb_r, _foot_job_r, false)


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
