extends Node
class_name SystemConnector

var _logger = EchoLogger.new("SystemConnector", "orange", EchoLogger.LogLevel.DEBUG)

@export var encounter_runner: EncounterRunner
@export var stage_director: StageDirector
@export var enemy_spawner: EnemySpawner

func _ready() -> void:
  var player = get_tree().get_first_node_in_group("player") as Player

  if encounter_runner == null:
      push_error("StageDirector: no EncounterRunner assigned.")
      return

  # ── 1. Player distance → Runner ──
  # The encounter_runner needs distance updates to advance its timeline in DISTANCE mode.
  player.distance_changed.connect(encounter_runner._on_distance_changed)

  # ── 2. Runner → Director (encounter lifecycle) ──
  encounter_runner.encounter_started.connect(_on_encounter_started)
  encounter_runner.encounter_finished.connect(_on_encounter_finished)
  encounter_runner.encounter_failed.connect(_on_encounter_failed)

  # ── 3. Runner → Director (gates) ──
  encounter_runner.gate_entered.connect(_on_gate_entered)
  encounter_runner.gate_cleared.connect(_on_gate_cleared)

  # ── 4. Runner → Director (optional: phase/marker/signal for music, camera, UI) ──
  encounter_runner.phase_changed.connect(_on_phase_changed)
  encounter_runner.marker_hit.connect(_on_marker_hit)
  encounter_runner.event_fired.connect(_on_event_fired)

# ── Signal handlers ──────────────────────────────────────────────────────────

func _on_encounter_started(enc: Encounter) -> void:
    _logger.debug("Segment started: %s" % enc.id)


func _on_encounter_finished(enc: Encounter) -> void:
    _logger.debug("Segment finished: %s" % enc.id)
    stage_director._play_next_segment()


func _on_encounter_failed(reason: String) -> void:
    _logger.debug("Encounter failed: %s" % reason)
    stage_director._on_encounter_failed(reason)


## Gate entered: pause the rail so distance stops advancing.
## Since the runner uses distance as its clock, pausing the rail
## also freezes encounter progression (Pattern A+B combined).
func _on_gate_entered(gate: GateEvent) -> void:
    _logger.debug("Gate entered — pausing rail")
    stage_director._pause_rail()


## Gate cleared: resume the rail and let distance flow again.
func _on_gate_cleared(gate: GateEvent) -> void:
    _logger.debug("Gate cleared — resuming rail")
    stage_director._resume_rail()


func _on_phase_changed(phase_name: String) -> void:
    _logger.debug("Phase: %s" % phase_name)
    # Hook: switch music, change camera, update UI
    # e.g. MusicManager.crossfade_to(phase_name)
    # e.g. camera_rig.set_profile(phase_name)


func _on_marker_hit(marker_name: String, payload: Dictionary) -> void:
    _logger.debug("Marker: %s → %s" % [marker_name, payload])
    # Hook: spawn pickups, trigger VFX, show dialogue
    # e.g. if marker_name == "pickup_health": spawn_health_pickup()


func _on_event_fired(event: EncounterEvent) -> void:
    # Low-level hook — fires for EVERY event including spawns.
    # Useful for debug HUD, analytics.
    pass
