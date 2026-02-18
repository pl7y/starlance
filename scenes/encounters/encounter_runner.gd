## Plays an Encounter resource over time OR distance, firing events
## deterministically.  Supports gates that pause progression until a
## condition is met.
##
## Micro layer: "what spawns happen inside this encounter."
## Does NOT decide which encounter comes next — that's StageDirector's job.
extends Node
class_name EncounterRunner

var _logger = EchoLogger.new("EncounterRunner", "purple", EchoLogger.LogLevel.DEBUG)

# ── Clock mode ───────────────────────────────────────────────────────────────

## How the runner's internal progress counter advances.
enum ClockMode {
  ## Progress = elapsed seconds (good for bosses, arenas).
  TIME,
  ## Progress = distance received from an external source (rail movement).
  DISTANCE,
}

# ── Exports ──────────────────────────────────────────────────────────────────

## The encounter data to play.
@export var encounter: Encounter:
  set(v):
    encounter = v
    if encounter != null:
      encounter.validate()

## If true, playback starts automatically on _ready().
@export var autostart: bool = false

## Injected spawner — the runner never instantiates enemies itself.
@export var spawner: EnemySpawner

## Deterministic seed.  0 = pick a random seed at start.
@export var _seed: int = 0

## Default clock mode (can be overridden per-start via start()).
@export var clock_mode: ClockMode = ClockMode.DISTANCE

# ── Signals (interaction contract) ───────────────────────────────────────────

## Emitted once when the encounter begins playing.
signal encounter_started(enc: Encounter)

## Emitted every time an event fires.
signal event_fired(event: EncounterEvent)

## Emitted when the encounter timeline has been fully consumed or duration reached.
signal encounter_finished(enc: Encounter)

## Emitted on failure / abort (e.g. player died).
signal encounter_failed(reason: String)

## Emitted when a PhaseEvent fires.
signal phase_changed(phase_name: String)

## Emitted when a MarkerEvent fires.
signal marker_hit(marker_name: String, payload: Dictionary)

## Emitted when a SignalEvent fires.
signal custom_signal(signal_name: String, argument: String)

## Emitted when a GateEvent is reached — StageDirector should pause the rail.
signal gate_entered(gate: GateEvent)

## Emitted when the active gate clears — StageDirector should resume the rail.
signal gate_cleared(gate: GateEvent)

# ── Internal state ───────────────────────────────────────────────────────────

## Current progress value (seconds or distance units depending on clock mode).
var _progress: float = 0.0
var _event_index: int = 0
var _running: bool = false
var _paused: bool = false
var _finished: bool = false
var _rng := RandomNumberGenerator.new()
var _active_clock: ClockMode = ClockMode.DISTANCE

## Distance-mode: baseline distance when encounter started.
var _distance_origin: float = 0.0
## Distance-mode: latest absolute distance received from progress source.
var _last_distance: float = 0.0

## Gate state
var _gate_active: bool = false
var _active_gate: GateEvent = null
var _gate_timer: float = 0.0
## Custom gate flags set externally.
var _gate_flags: Dictionary = {}

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
  set_process(false)
  if autostart and encounter != null:
    start()


func _process(delta: float) -> void:
  if not _running or _paused:
    return

  # ── Advance progress (time-driven only; distance is pushed externally) ──
  if _active_clock == ClockMode.TIME:
    _progress += delta

  # ── Gate check ──
  if _gate_active:
    _update_gate(delta)
    return # Don't advance events while gated

  # ── Fire due events ──
  _advance_events()

  # ── End condition ──
  if _progress >= encounter.duration or _all_events_fired():
    _finish()

# ── Public API ───────────────────────────────────────────────────────────────

## Begin (or restart) playback.
## [param enc]       — encounter to play (uses export if null).
## [param run_seed]  — deterministic seed (0 = use export/encounter default).
## [param mode]      — clock mode override.
func start(enc: Encounter = null, run_seed: int = 0, mode: ClockMode = clock_mode) -> void:
  if enc != null:
    encounter = enc
  if encounter == null:
    push_error("EncounterRunner: no encounter resource assigned.")
    return

  encounter.validate()

  _progress = 0.0
  _event_index = 0
  _finished = false
  _paused = false
  _running = true
  _active_clock = mode
  _gate_active = false
  _active_gate = null
  _gate_timer = 0.0
  _gate_flags.clear()
  _distance_origin = _last_distance

  # Seed the RNG
  var effective_seed := run_seed if run_seed != 0 else _seed
  if effective_seed != 0:
    _rng.seed = effective_seed
  elif encounter.seed_hint != 0:
    _rng.seed = encounter.seed_hint
  else:
    _rng.randomize()

  set_process(true)
  _logger.debug("Encounter started: %s" % encounter)
  encounter_started.emit(encounter)


## Feed distance from the rail / player.
## Call this from Player.distance_changed or a RailController.
func set_distance(absolute_distance: float) -> void:
  _last_distance = absolute_distance
  if _running and _active_clock == ClockMode.DISTANCE:
    _progress = absolute_distance - _distance_origin


## Convenience: connect directly to Player.distance_changed.
func _on_distance_changed(distance: float) -> void:
  set_distance(distance)


## Pause the timeline (events stop firing, progress freezes).
func pause() -> void:
  _paused = true


## Resume after pause.
func resume() -> void:
  _paused = false


## Stop and reset.  Does NOT emit encounter_finished.
func stop() -> void:
  _running = false
  _paused = false
  _gate_active = false
  _active_gate = null
  set_process(false)


## Restart from progress = 0 with a fresh RNG state.
func restart() -> void:
  stop()
  start()


## Abort with a reason (e.g. player died). Emits encounter_failed.
func fail(reason: String = "aborted") -> void:
  if not _running:
    return
  _running = false
  set_process(false)
  _logger.debug("Encounter failed: %s" % reason)
  encounter_failed.emit(reason)


## Load a new Encounter resource at runtime and optionally start it.
func load_encounter(enc: Encounter, auto: bool = false) -> void:
  encounter = enc
  if auto:
    start()


## Set a custom gate flag. If the active gate condition is CUSTOM and
## the key matches, the gate will clear on the next frame.
func set_gate_flag(key: String) -> void:
  _gate_flags[key] = true


## Apply an array of mutator Callables to the encounter before starting.
## Each callable receives (encounter: Encounter, rng: RandomNumberGenerator).
func apply_mutators(mutators: Array[Callable]) -> void:
  if encounter == null:
    return
  for m in mutators:
    m.call(encounter, _rng)
  encounter.validate()


## True while the runner is actively playing (including paused or gated).
func is_running() -> bool:
  return _running


## True while paused.
func is_paused() -> bool:
  return _paused


## True while a gate is blocking progression.
func is_gated() -> bool:
  return _gate_active


## Current progress value (seconds or distance depending on clock mode).
func progress() -> float:
  return _progress

# ── Internal: event advancement ──────────────────────────────────────────────

func _advance_events() -> void:
  if encounter == null:
    return

  var events := encounter.events
  while _event_index < events.size():
    var ev := events[_event_index]

    # Skip null or disabled events
    if ev == null or not ev.enabled:
      _event_index += 1
      continue

    # Not yet time / distance
    if ev.time > _progress:
      break

    _dispatch(ev)
    _event_index += 1

    # If we just entered a gate, stop advancing further events
    if _gate_active:
      break


func _dispatch(ev: EncounterEvent) -> void:
  _logger.debug("Event fired: %s" % ev)
  event_fired.emit(ev)

  if ev is SpawnEvent:
    _handle_spawn(ev as SpawnEvent)
  elif ev is GateEvent:
    _enter_gate(ev as GateEvent)
  elif ev is PhaseEvent:
    _logger.debug("Phase changed: %s" % (ev as PhaseEvent).phase_name)
    phase_changed.emit((ev as PhaseEvent).phase_name)
  elif ev is MarkerEvent:
    var me := ev as MarkerEvent
    _logger.debug("Marker hit: %s Payload: %s" % [me.marker_name, me.payload])
    marker_hit.emit(me.marker_name, me.payload)
  elif ev is SignalEvent:
    var se := ev as SignalEvent
    _logger.debug("Custom signal: %s Argument: %s" % [se.signal_name, se.argument])
    custom_signal.emit(se.signal_name, se.argument)


func _handle_spawn(ev: SpawnEvent) -> void:
  if spawner == null:
    push_error("EncounterRunner: no EnemySpawner assigned — cannot spawn.")
    return

  var offsets: Array[Vector2] = []
  if ev.formation != null:
    offsets = ev.formation.get_offsets(ev.count)
  else:
    for i in ev.count:
      offsets.append(Vector2.ZERO)

  spawner.spawn_group(ev, offsets, _rng)

# ── Internal: gate logic ─────────────────────────────────────────────────────

func _enter_gate(gate: GateEvent) -> void:
  _gate_active = true
  _active_gate = gate
  _gate_timer = 0.0
  _logger.debug("Gate entered: %s" % gate)


func _update_gate(delta: float) -> void:
  if _active_gate == null:
    _clear_gate()
    return

  match _active_gate.condition:
    GateEvent.Condition.ALL_ENEMIES_DEAD:
      if get_tree().get_nodes_in_group("enemies").size() == 0:
        _clear_gate()

    GateEvent.Condition.WAVE_ENEMIES_DEAD:
      if get_tree().get_nodes_in_group("enemies").size() == 0:
        _clear_gate()

    GateEvent.Condition.TIMER:
      _gate_timer += delta
      if _gate_timer >= _active_gate.hold_time:
        _clear_gate()

    GateEvent.Condition.CUSTOM:
      if _gate_flags.has(_active_gate.custom_key):
        _clear_gate()


func _clear_gate() -> void:
  var cleared := _active_gate
  _gate_active = false
  _active_gate = null
  _gate_timer = 0.0
  if cleared != null:
    _logger.debug("Gate cleared: %s" % cleared)
    gate_cleared.emit(cleared)


func _all_events_fired() -> bool:
  return _event_index >= encounter.events.size()


func _finish() -> void:
  if _finished:
    return
  _finished = true
  _running = false
  set_process(false)
  _logger.debug("Encounter finished: %s" % encounter)
  encounter_finished.emit(encounter)
