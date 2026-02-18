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

# ── Procedural generation (optional) ────────────────────────────────────────

## Stage template for procedural generation.  When set (along with
## encounter_pool), start_stage() builds segments automatically instead
## of using the manual `segments` array.
@export var stage_template: StageTemplate

## Encounter pool to draw from when building procedurally.
@export var encounter_pool: EncounterPool

## Difficulty curve profile.  Null = flat difficulty (no scaling).
@export var difficulty_profile: DifficultyProfile

## Minimum breather gap between adjacent combat encounters.
@export var min_breather_gap: float = 2.0

## Maximum breather gap.
@export var max_breather_gap: float = 6.0

## If true, auto-insert breathers between adjacent combat encounters.
@export var auto_breathers: bool = true

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
var _last_build_result: StageBuilder.BuildResult = null

# ── Segment distance mapping ─────────────────────────────────────────────────

## Absolute distance at which each segment starts.
var _segment_starts: PackedFloat64Array = PackedFloat64Array()

## Total stage distance (sum of all segment durations).
var _total_stage_distance: float = 0.0

## Current absolute distance received from the player.
var _current_distance: float = 0.0

## Whether we're waiting for the player to reach the next segment start.
var _waiting_for_distance: bool = false

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
  # Feed player distance into the runner (micro: events within encounter).
  if runner != null:
    player.distance_changed.connect(runner._on_distance_changed)
  # Feed player distance into the director (macro: which segment is active).
  player.distance_changed.connect(_on_distance_changed)

# ── Public API ───────────────────────────────────────────────────────────────

## Start the stage from segment 0.
## If stage_template + encounter_pool are set, builds segments procedurally.
## Otherwise falls back to the manual `segments` array.
func start_stage(seed_override: int = 0) -> void:
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

  # ── Procedural build (if template + pool are set) ────────────────────
  if stage_template != null and encounter_pool != null:
    var builder := StageBuilder.new(stage_template, encounter_pool, difficulty_profile, _rng)
    builder.min_gap = min_breather_gap
    builder.max_gap = max_breather_gap
    builder.auto_breathers = auto_breathers
    _last_build_result = builder.build(run_seed)
    segments = _last_build_result.segments
    print("StageDirector: built %d segments (filled=%d, skipped=%d, breathers=%d, seed=%d)" % [
      segments.size(),
      _last_build_result.slots_filled,
      _last_build_result.slots_skipped,
      _last_build_result.breathers_inserted,
      _last_build_result.seed_used,
    ])

  if segments.is_empty():
    push_error("StageDirector: no segments to play.")
    return

  # Build the distance map — segments are placed end-to-end on the rail
  _build_distance_map()

  _segment_index = -1
  _current_distance = 0.0
  _waiting_for_distance = false
  _running = true
  _rail_paused = false

  # Record player's current distance as our origin
  if player != null:
    _current_distance = player._distance

  # Apply base rail speed
  _set_rail_speed(rail_speed)

  stage_started.emit()

  # Start first segment immediately
  _start_segment(0)


## Manually advance to next segment (skip current).
func skip_segment() -> void:
  if not _running:
    return
  runner.stop()
  _queue_next_segment()


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


## Returns true if segments were built procedurally (template + pool).
func is_procedural() -> bool:
  return _last_build_result != null


## Returns the last StageBuilder.BuildResult (null if manual segments).
func last_build_result() -> StageBuilder.BuildResult:
  return _last_build_result

# ── Segment distance mapping ─────────────────────────────────────────────────

## Compute absolute start distances for each segment.
## Segments are placed end-to-end: segment[i] starts where segment[i-1] ends.
func _build_distance_map() -> void:
  _segment_starts.clear()
  var cursor: float = 0.0
  for seg in segments:
    _segment_starts.append(cursor)
    if seg.duration <= 0.0:
      push_warning("StageDirector: segment '%s' has zero duration, defaulting to 20.0" % seg.id)
      seg.duration = 20.0
    cursor += seg.duration
  _total_stage_distance = cursor
  print("StageDirector: distance map — %d segments, %.1f total distance" % [segments.size(), _total_stage_distance])
  for i in segments.size():
    print("  [%d] %s starts at %.1f, duration %.1f" % [i, segments[i].id, _segment_starts[i], segments[i].duration])

# ── Segment sequencing ───────────────────────────────────────────────────────

## Called every frame the player moves.  Drives segment transitions.
func _on_distance_changed(distance: float) -> void:
  _current_distance = distance

  if not _running:
    return
  if _rail_paused:
    return

  # Check if we should start the next segment
  if _waiting_for_distance:
    var next_index := _segment_index + 1
    if next_index < segments.size():
      var next_start := _segment_starts[next_index]
      if _current_distance >= next_start:
        _waiting_for_distance = false
        _start_segment(next_index)


## Start a specific segment immediately.
func _start_segment(index: int) -> void:
  if index < 0 or index >= segments.size():
    _finish_stage()
    return

  _segment_index = index
  var enc := segments[_segment_index]

  if enc == null:
    push_warning("StageDirector: segment %d is null, skipping." % _segment_index)
    _queue_next_segment()
    return

  # Derive a per-segment seed from the run seed
  var seg_seed := _rng.randi()

  print("StageDirector: starting segment [%d] '%s' at distance %.1f" % [
    _segment_index, enc.id, _current_distance
  ])

  segment_started.emit(_segment_index, enc)
  runner.start(enc, seg_seed, default_clock)


## Queue the next segment — waits for the player to reach its start distance.
func _queue_next_segment() -> void:
  var next_index := _segment_index + 1
  if next_index >= segments.size():
    _finish_stage()
    return

  var next_start := _segment_starts[next_index]

  # If the player is already past the start point, start immediately.
  if _current_distance >= next_start:
    _start_segment(next_index)
  else:
    _waiting_for_distance = true


func _finish_stage() -> void:
  _running = false
  stage_finished.emit()

# ── Runner signal handlers ───────────────────────────────────────────────────

func _on_encounter_finished(enc: Encounter) -> void:
  if not _running:
    return
  segment_finished.emit(_segment_index, enc)
  _queue_next_segment()


func _on_encounter_failed(reason: String) -> void:
  fail_stage(reason)


## Pattern A: runner tells us a gate was hit → we pause the rail.
func _on_gate_entered(_gate: GateEvent) -> void:
  pause_rail()
  # Runner is already gated internally; rail speed goes to 0 so distance
  # stops advancing → Pattern B also satisfied.


## Gate cleared → resume the rail.
func _on_gate_cleared(_gate: GateEvent) -> void:
  resume_rail()


## Phase changes — override or connect to react (music, camera, etc.).
func _on_phase_changed(_phase_name: String) -> void:
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
