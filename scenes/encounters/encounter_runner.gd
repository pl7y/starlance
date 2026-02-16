## Plays an Encounter resource over time, firing events deterministically.
##
## Attach as a Node in your scene tree.  Wire `spawner` to an EnemySpawner node.
## Feed it an Encounter resource via `encounter` export or `load_encounter()`.
extends Node
class_name EncounterRunner

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
@export var seed: int = 0

# ── Signals ──────────────────────────────────────────────────────────────────

## Emitted once when the encounter begins playing.
signal encounter_started()

## Emitted every time an event fires.  Listeners can inspect the event type.
signal event_fired(event: EncounterEvent)

## Emitted when the encounter timeline has been fully consumed or duration reached.
signal encounter_finished()

## Emitted when a PhaseEvent fires.
signal phase_changed(phase_name: String)

## Emitted when a MarkerEvent fires.
signal marker_hit(marker_name: String, payload: Dictionary)

## Emitted when a SignalEvent fires.
signal custom_signal(signal_name: String, argument: String)

# ── Internal state ───────────────────────────────────────────────────────────

var _elapsed: float = 0.0
var _event_index: int = 0
var _running: bool = false
var _paused: bool = false
var _finished: bool = false
var _rng := RandomNumberGenerator.new()

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
  set_process(false)
  if autostart and encounter != null:
    start()


func _process(delta: float) -> void:
  if not _running or _paused:
    return

  _elapsed += delta

  # Fire all events whose time has been reached
  _advance_events()

  # Check end condition
  if _elapsed >= encounter.duration or _all_events_fired():
    _finish()

# ── Public API ───────────────────────────────────────────────────────────────

## Begin (or restart) playback from the top.
func start() -> void:
  if encounter == null:
    push_error("EncounterRunner: no encounter resource assigned.")
    return

  encounter.validate()
  _elapsed = 0.0
  _event_index = 0
  _finished = false
  _paused = false
  _running = true

  # Seed the RNG
  if seed != 0:
    _rng.seed = seed
  elif encounter.seed_hint != 0:
    _rng.seed = encounter.seed_hint
  else:
    _rng.randomize()

  set_process(true)
  encounter_started.emit()


## Pause the timeline (events stop firing, elapsed time freezes).
func pause() -> void:
  _paused = true


## Resume after pause.
func resume() -> void:
  _paused = false


## Stop and reset.  Does NOT emit encounter_finished.
func stop() -> void:
  _running = false
  _paused = false
  set_process(false)


## Restart from t = 0 with a fresh RNG state.
func restart() -> void:
  stop()
  start()


## Load a new Encounter resource at runtime and optionally start it.
func load_encounter(enc: Encounter, auto: bool = false) -> void:
  encounter = enc
  if auto:
    start()


## True while the runner is actively playing (including paused).
func is_running() -> bool:
  return _running


## True while paused.
func is_paused() -> bool:
  return _paused


## Current timeline position in seconds.
func elapsed_time() -> float:
  return _elapsed

# ── Internal ─────────────────────────────────────────────────────────────────

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

    # Not yet time
    if ev.time > _elapsed:
      break

    _dispatch(ev)
    _event_index += 1


func _dispatch(ev: EncounterEvent) -> void:
  # Always emit the generic signal
  event_fired.emit(ev)

  if ev is SpawnEvent:
    _handle_spawn(ev as SpawnEvent)
  elif ev is PhaseEvent:
    var pe := ev as PhaseEvent
    phase_changed.emit(pe.phase_name)
  elif ev is MarkerEvent:
    var me := ev as MarkerEvent
    marker_hit.emit(me.marker_name, me.payload)
  elif ev is SignalEvent:
    var se := ev as SignalEvent
    custom_signal.emit(se.signal_name, se.argument)


func _handle_spawn(ev: SpawnEvent) -> void:
  prints("EncounterRunner: handling SpawnEvent for %ss with formation %s" % [ev.count, ev.formation])
  if spawner == null:
    push_error("EncounterRunner: no EnemySpawner assigned — cannot spawn.")
    return

  # Compute formation offsets
  var offsets: Array[Vector2] = []
  if ev.formation != null:
    offsets = ev.formation.get_offsets(ev.count)
  else:
    # No formation → all at origin
    for i in ev.count:
      offsets.append(Vector2.ZERO)

  spawner.spawn_group(ev, offsets, _rng)


func _all_events_fired() -> bool:
  return _event_index >= encounter.events.size()


func _finish() -> void:
  if _finished:
    return
  _finished = true
  _running = false
  set_process(false)
  encounter_finished.emit()
