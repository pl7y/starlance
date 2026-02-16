#    ___                      __          
#   / _ \___ _    _____  ___ / /____ _____
#  / // / _ \ |/|/ / _ \(_-</ __/ _ `/ __/
# /____/\___/__,__/_//_/___/\__/\_,_/_/   
# (c) Pl7y.com 2026
                                                                                                                                                                            
                                        
## StageDirector — macro layer for level progression.
##
## Owns the sequence of encounter segments that make up a stage/planet run.
## Picks/starts/stops encounters via EncounterRunner.  Controls rail speed,
## transitions, difficulty scaling, and reacts to gate signals.
##
## Does NOT spawn enemies directly — that's EncounterRunner + EnemySpawner.
##
## Scene tree wiring:
##   StageDirector
##     └─ EncounterRunner
##          └─ EnemySpawner
extends Node
class_name StageDirector

# ── Exports ──────────────────────────────────────────────────────────────────

## The EncounterRunner this director drives.
@export var runner: EncounterRunner

## The Player node (used for distance feed and fail detection).
@export var player: Player

## Ordered list of encounter segments that make up this stage.
## Authored in the inspector or built procedurally in start_stage().
@export var segments: Array[Encounter] = []

## Master seed for the run.  0 = randomize.
@export var run_seed: int = 0

## Base rail speed (world-units / second).  Passed to player.speed.
@export var rail_speed: float = 1.0

## Corruption / difficulty multiplier.  Systems can read this to scale HP, fire rate, etc.
@export_range(0.0, 10.0) var corruption: float = 1.0

## Freeform modifiers for the current run (e.g. "high_gravity", "double_fire").
@export var modifiers: PackedStringArray = PackedStringArray()

## If true, automatically starts the first segment on _ready().
@export var autostart: bool = false

## Default clock mode passed to the runner for normal segments.
@export var default_clock: EncounterRunner.ClockMode = EncounterRunner.ClockMode.DISTANCE

# ── Signals ──────────────────────────────────────────────────────────────────

## Emitted when the stage begins.
signal stage_started()

## Emitted when segment_index advances.
signal segment_started(index: int, encounter: Encounter)

## Emitted after a segment's encounter finishes and before the next starts.
signal segment_finished(index: int, encounter: Encounter)

## Emitted when all segments are done.
signal stage_finished()

## Emitted when the rail pauses (gate).
signal rail_paused()

## Emitted when the rail resumes (gate cleared).
signal rail_resumed()

## Emitted when the stage fails (player died, etc.).
signal stage_failed(reason: String)

# ── Internal state ───────────────────────────────────────────────────────────

var _segment_index: int = -1
var _running: bool = false
var _rng := RandomNumberGenerator.new()
var _saved_rail_speed: float = 0.0
var _rail_paused: bool = false

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
  _connect_runner_signals()
  _connect_player_signals()
  if autostart and not segments.is_empty():
    start_stage()


func _connect_runner_signals() -> void:
  if runner == null:
    return
  runner.encounter_finished.connect(_on_encounter_finished)
  runner.encounter_failed.connect(_on_encounter_failed)
  runner.gate_entered.connect(_on_gate_entered)
  runner.gate_cleared.connect(_on_gate_cleared)
  runner.phase_changed.connect(_on_phase_changed)


func _connect_player_signals() -> void:
  if player == null:
    return
  # Feed player distance into the runner (Pattern B: runner pulls from rail).
  if runner != null:
    player.distance_changed.connect(runner._on_distance_changed)

# ── Public API ───────────────────────────────────────────────────────────────

## Start the stage from segment 0.
func start_stage(seed_override: int = 0) -> void:
  if segments.is_empty():
    push_error("StageDirector: no segments to play.")
    return
  if runner == null:
    push_error("StageDirector: no EncounterRunner assigned.")
    return

  # Seed
  var s := seed_override if seed_override != 0 else run_seed
  if s != 0:
    _rng.seed = s
  else:
    _rng.randomize()
    run_seed = _rng.randi()
    _rng.seed = run_seed

  _segment_index = -1
  _running = true
  _rail_paused = false

  # Apply base rail speed
  _set_rail_speed(rail_speed)

  stage_started.emit()
  _play_next_segment()


## Manually advance to next segment (skip current).
func skip_segment() -> void:
  if not _running:
    return
  runner.stop()
  _play_next_segment()


## Stop the entire stage.
func stop_stage() -> void:
  _running = false
  runner.stop()


## Abort with failure.
func fail_stage(reason: String = "player_died") -> void:
  _running = false
  runner.fail(reason)
  stage_failed.emit(reason)


## Pause the rail (and runner) externally.
func pause_rail() -> void:
  if _rail_paused:
    return
  _rail_paused = true
  _saved_rail_speed = _get_rail_speed()
  _set_rail_speed(0.0)
  runner.pause()
  rail_paused.emit()


## Resume the rail (and runner).
func resume_rail() -> void:
  if not _rail_paused:
    return
  _rail_paused = false
  _set_rail_speed(_saved_rail_speed)
  runner.resume()
  rail_resumed.emit()


## Set rail speed at runtime (e.g. for speed ramps, boss arenas).
func set_rail_speed(spd: float) -> void:
  rail_speed = spd
  if not _rail_paused:
    _set_rail_speed(spd)


## Read the current corruption level (for spawners / mutators to query).
func get_corruption() -> float:
  return corruption


## Check if a modifier is active.
func has_modifier(mod: String) -> bool:
  return modifiers.has(mod)


## Current segment index (-1 if not started).
func current_segment_index() -> int:
  return _segment_index


## Is the stage currently running?
func is_running() -> bool:
  return _running

# ── Segment sequencing ───────────────────────────────────────────────────────

func _play_next_segment() -> void:
  _segment_index += 1
  if _segment_index >= segments.size():
    _finish_stage()
    return

  var enc := segments[_segment_index]
  if enc == null:
    push_warning("StageDirector: segment %d is null, skipping." % _segment_index)
    _play_next_segment()
    return

  # Derive a per-segment seed from the run seed
  var seg_seed := _rng.randi()

  segment_started.emit(_segment_index, enc)
  runner.start(enc, seg_seed, default_clock)


func _finish_stage() -> void:
  _running = false
  stage_finished.emit()

# ── Runner signal handlers ───────────────────────────────────────────────────

func _on_encounter_finished(enc: Encounter) -> void:
  if not _running:
    return
  segment_finished.emit(_segment_index, enc)
  _play_next_segment()


func _on_encounter_failed(reason: String) -> void:
  fail_stage(reason)


## Pattern A: runner tells us a gate was hit → we pause the rail.
func _on_gate_entered(gate: GateEvent) -> void:
  pause_rail()
  # Runner is already gated internally; rail speed goes to 0 so distance
  # stops advancing → Pattern B also satisfied.


## Gate cleared → resume the rail.
func _on_gate_cleared(gate: GateEvent) -> void:
  resume_rail()


## Phase changes — override or connect to react (music, camera, etc.).
func _on_phase_changed(phase_name: String) -> void:
  # Subclass or connect a signal to handle phase transitions.
  pass

# ── Rail speed helpers ───────────────────────────────────────────────────────

## Actually apply speed to the player node.
func _set_rail_speed(spd: float) -> void:
  if player != null:
    player.speed = spd


func _get_rail_speed() -> float:
  if player != null:
    return player.speed
  return rail_speed
